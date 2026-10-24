-- sandbox-bridge-lib/server/dispatch.lua
-- Loaded by server/main.lua in the shared bridge environment.
--
-- Unified Dispatch/MDT foundation. It keeps a Sandbox aware call registry and
-- adapts alerts to every supported dispatch/tablet resource, with a guaranteed
-- notification/blip fallback.

Dispatch = {}
SB.Dispatch = Dispatch

local Compat = SandboxBridgeCompat

Dispatch.Backends = {}
Dispatch.Calls = {}
Dispatch.History = {}
Dispatch.Sequence = 0
Dispatch.LastAlert = {}
Dispatch.StartedAt = os.time and os.time() or 0

-- ---------------------------------------------------------------------------
-- Configuration / detection
-- ---------------------------------------------------------------------------

local function DispatchConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Dispatch) or {}
end

local function MDTConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.MDT) or {}
end

function Dispatch.IsEnabled()
    return DispatchConfig().Enabled ~= false
end

---@return table
function Dispatch.GetAvailableBackends()
    local available = {}
    local catalogue = Compat.DispatchResources
    for _, resource in ipairs(catalogue) do
        if Compat.IsStarted(resource) then available[#available + 1] = resource end
    end
    return available
end

---The active backend resource, or "default" when none is started.
---@return string
function Dispatch.GetResourceName()
    if not Dispatch.IsEnabled() then return 'disabled' end
    local active = Compat.SelectConfigured(
        DispatchConfig(),
        Compat.DispatchResources,
        DispatchConfig().Exclusions
    )
    return active or 'default'
end

function Dispatch.GetBackend()
    return Dispatch.GetResourceName()
end

function Dispatch.IsAvailable()
    local backend = Dispatch.GetResourceName()
    return backend ~= 'default' and backend ~= 'disabled'
end

function Dispatch.GetMDTResourceName()
    if MDTConfig().Enabled == false then return 'disabled' end
    local active = Compat.SelectConfigured(MDTConfig(), Compat.MDTResources)
    return active or 'default'
end

---Register a custom server-side backend. The handler receives the normalized
---alert and must return true when it accepted it.
---@param name string
---@param handler function
function Dispatch.RegisterBackend(name, handler)
    if type(name) ~= 'string' or type(handler) ~= 'function' then return false end
    Dispatch.Backends[name] = handler
    return true
end

function Dispatch.UnregisterBackend(name)
    Dispatch.Backends[name] = nil
end

-- ---------------------------------------------------------------------------
-- Sandbox job/duty helpers
-- ---------------------------------------------------------------------------

local function IsSourceOnline(src)
    src = tonumber(src)
    if not src or src <= 0 then return false end
    return GetPlayerName(src) ~= nil
end

function Dispatch.GetJobAssignments(src)
    local char = GetCharacter(src)
    if not char then return {} end
    local assignments = char:GetData('Jobs') or {}
    return type(assignments) == 'table' and assignments or {}
end

function Dispatch.IsJobMember(src, jobs)
    if type(jobs) == 'string' then jobs = { [jobs] = true } end
    if type(jobs) ~= 'table' then return false end

    for _, assignment in ipairs(Dispatch.GetJobAssignments(src)) do
        if jobs[assignment.Id] then return true, assignment.Id end
    end
    return false
end

function Dispatch.IsOnDuty(src, jobId)
    jobId = jobId or SB.GetPrimaryJob(src).name
    return SB.GetDuty(src, jobId) == true
end

---Return the source ids that belong to any of the passed jobs.
---@param jobs table|string
---@param onDutyOnly boolean|nil
---@return table
function Dispatch.GetRecipients(jobs, onDutyOnly)
    if type(jobs) == 'string' then jobs = { jobs } end

    local wanted = {}
    for _, job in ipairs(jobs or {}) do wanted[job] = true end
    if next(wanted) == nil then
        for _, job in ipairs(DispatchConfig().DefaultJobs or { 'police' }) do wanted[job] = true end
    end

    local recipients, seen = {}, {}
    for _, src in ipairs(SB.GetPlayers()) do
        local member, jobId = Dispatch.IsJobMember(src, wanted)
        if member and (not onDutyOnly or Dispatch.IsOnDuty(src, jobId)) and not seen[src] then
            seen[src] = true
            recipients[#recipients + 1] = src
        end
    end
    return recipients
end

function Dispatch.GetOfficers(filters)
    filters = filters or {}
    local lawJobs = MDTConfig().LawJobs or {}
    local officers = {}

    for _, src in ipairs(SB.GetPlayers()) do
        local data = SB.BuildPlayerData(src)
        if data then
            local job = data.job or {}
            local include = filters.all == true
                or (filters.job and job.name == filters.job)
                or (not filters.job and lawJobs[job.name])

            if include then
                local coords = data.position
                officers[#officers + 1] = {
                    source = src,
                    citizenid = data.citizenid,
                    name = data.name,
                    callsign = data.metadata and data.metadata.callsign or nil,
                    job = job.name,
                    jobLabel = job.label,
                    grade = job.grade and job.grade.level or 0,
                    gradeLabel = job.grade and job.grade.label or '',
                    onDuty = job.onduty == true,
                    phone = data.charinfo and data.charinfo.phone or nil,
                    coords = coords,
                    lastSeen = os.time and os.time() or 0,
                }
            end
        end
    end

    table.sort(officers, function(a, b)
        if a.onDuty ~= b.onDuty then return a.onDuty end
        return tostring(a.name or '') < tostring(b.name or '')
    end)

    return officers
end

-- ---------------------------------------------------------------------------
-- Call registry
-- ---------------------------------------------------------------------------

local function NextCallId()
    Dispatch.Sequence = Dispatch.Sequence + 1
    return ('DSP-%06d'):format(Dispatch.Sequence)
end

local function CopyAlert(alert)
    if not alert then return nil end
    local copy = Compat.Copy(alert)
    -- Do not persist the entire raw payload, it can hold entity handles.
    copy.raw = nil
    return copy
end

function Dispatch.RecordAlert(alert, backend)
    if DispatchConfig().KeepCalls == false then return nil end

    alert = alert or {}
    alert.id = alert.id or NextCallId()
    alert.backend = backend or alert.backend or Dispatch.GetResourceName()
    alert.createdAt = alert.createdAt or (os.time and os.time() or 0)
    alert.updatedAt = alert.createdAt
    alert.status = alert.status or 'active'

    if not alert.coords then
        alert.coords = Compat.ToCoords(DispatchConfig().DefaultCoords, vector3 and vector3(0.0, 0.0, 0.0) or { x = 0, y = 0, z = 0 })
    end

    local call = CopyAlert(alert)
    Dispatch.Calls[#Dispatch.Calls + 1] = call
    Dispatch.History[#Dispatch.History + 1] = call

    local maxCalls = tonumber(DispatchConfig().MaxCalls) or 250
    while #Dispatch.Calls > maxCalls do table.remove(Dispatch.Calls, 1) end
    while #Dispatch.History > maxCalls * 2 do table.remove(Dispatch.History, 1) end

    TriggerEvent('sandbox_bridge:server:dispatch:created', call)
    return call
end

function Dispatch.GetCall(callId)
    callId = tostring(callId or '')
    for _, call in ipairs(Dispatch.Calls) do
        if tostring(call.id) == callId then return call end
    end
    return nil
end

function Dispatch.GetCalls(filters)
    filters = type(filters) == 'table' and filters or {}
    local results = {}
    local maxResults = tonumber(DispatchConfig().MaxCalls) or 250

    for _, call in ipairs(Dispatch.Calls) do
        local matches = true
        if filters.active == true and call.status ~= 'active' then matches = false end
        if filters.status and call.status ~= filters.status then matches = false end
        if filters.job and Compat and Compat.TableContains then
            if not Compat.TableContains(call.jobs or {}, filters.job) then matches = false end
        elseif filters.job and type(call.jobs) == 'table' then
            local hasJob = false
            if type(filters.job) == 'table' then
                for i=1,#filters.job do
                    for j=1,#call.jobs do
                        if call.jobs[j] == filters.job[i] then hasJob = true break end
                    end
                    if hasJob then break end
                end
            else
                for j=1,#call.jobs do
                    if call.jobs[j] == filters.job then hasJob = true break end
                end
            end
            if not hasJob then matches = false end
        elseif filters.job then
            matches = false
        end
        if matches and filters.code and tostring(call.code or '') ~= tostring(filters.code) then matches = false end
        if matches and filters.source and tonumber(call.source) ~= tonumber(filters.source) then matches = false end
        if matches and filters.query and Compat and Compat.Matches then
            if not (
                Compat.Matches(call.message, filters.query)
                or Compat.Matches(call.code, filters.query)
                or Compat.Matches(call.street, filters.query)
            ) then matches = false end
        end

        if matches then
            results[#results + 1] = call
            if #results >= maxResults then break end
        end
    end

    if Compat and Compat.SortByCreatedAt then
        Compat.SortByCreatedAt(results, true)
    end
    if filters.limit then
        local limit = tonumber(filters.limit)
        if limit and limit > 0 and #results > limit then
            while #results > limit do table.remove(results) end
        end
    end
    return results
end

function Dispatch.UpdateCall(callId, patch)
    local call = Dispatch.GetCall(callId)
    if not call or type(patch) ~= 'table' then return false end

    for key, value in pairs(patch) do
        if key ~= 'id' and key ~= 'createdAt' then call[key] = value end
    end
    call.updatedAt = os.time and os.time() or call.updatedAt

    TriggerEvent('sandbox_bridge:server:dispatch:updated', call)
    return true
end

function Dispatch.CloseCall(callId, reason)
    local call = Dispatch.GetCall(callId)
    if not call then return false end

    call.status = 'closed'
    call.closedAt = os.time and os.time() or 0
    call.closedBy = reason or call.closedBy
    call.updatedAt = call.closedAt

    TriggerEvent('sandbox_bridge:server:dispatch:closed', call)
    return true
end

function Dispatch.AssignCall(callId, src, callsign)
    local call = Dispatch.GetCall(callId)
    if not call then return false end
    call.assignedTo = tonumber(src) or src
    call.assignedCallsign = callsign
    call.assignedAt = os.time and os.time() or 0
    call.updatedAt = call.assignedAt
    TriggerEvent('sandbox_bridge:server:dispatch:updated', call)
    return true
end

function Dispatch.GetHistory(filters)
    filters = filters or {}
    local results = {}
    for _, call in ipairs(Dispatch.History) do
        local matches = true
        if filters.job and not Compat.TableContains(call.jobs or {}, filters.job) then matches = false end
        if filters.status and call.status ~= filters.status then matches = false end
        if filters.query and not (
            Compat.Matches(call.message, filters.query)
            or Compat.Matches(call.code, filters.query)
        ) then matches = false end
        if matches then results[#results + 1] = call end
    end
    Compat.SortByCreatedAt(results, true)
    return results
end

function Dispatch.GetStats()
    local stats = {
        total = #Dispatch.Calls,
        active = 0,
        closed = 0,
        byCode = {},
        byJob = {},
    }
    for _, call in ipairs(Dispatch.Calls) do
        if call.status == 'active' then stats.active = stats.active + 1 else stats.closed = stats.closed + 1 end
        stats.byCode[tostring(call.code)] = (stats.byCode[tostring(call.code)] or 0) + 1
        for _, job in ipairs(call.jobs or {}) do
            stats.byJob[job] = (stats.byJob[job] or 0) + 1
        end
    end
    return stats
end

---Alias used by scripts that create a call directly.
function Dispatch.CreateCall(data, source)
    return Dispatch.SendAlert(data, { source = source, recordOnly = true })
end

-- ---------------------------------------------------------------------------
-- Backend adapters (server side)
-- ---------------------------------------------------------------------------

local function AlertTitle(alert) return alert.title or alert.message or 'Dispatch Alert' end
local function AlertDescription(alert) return alert.message or alert.description or '' end

local function Vec2(coords)
    coords = Compat.ToCoords(coords)
    if not coords then return vec2 and vec2(0.0, 0.0) or { x = 0.0, y = 0.0 } end
    if vec2 then return vec2(coords.x, coords.y) end
    if vector2 then return vector2(coords.x, coords.y) end
    return { x = coords.x, y = coords.y }
end

local ServerAdapters = {}

ServerAdapters['lb-tablet'] = function(alert)
    if not Compat.IsStarted('lb-tablet') then return false end
    return Compat.SafeCall(function()
        exports['lb-tablet']:AddDispatch({
            priority = Compat.PriorityLabel(alert.priority),
            code = alert.code,
            title = 'Dispatch Alert!',
            description = AlertDescription(alert),
            location = {
                label = alert.street or alert.zone or 'Unknown location',
                coords = Vec2(alert.coords or vector3(0.0, 0.0, 0.0)),
            },
            time = alert.time,
            job = alert.job,
            jobs = alert.jobs,
        })
        return true
    end) == true
end

ServerAdapters['redutzu-mdt'] = function(alert)
    if not Compat.IsStarted('redutzu-mdt') then return false end
    return Compat.SafeCall(function()
        TriggerEvent('redutzu-mdt:server:addDispatchToMDT', {
            code = alert.code,
            title = AlertTitle(alert),
            street = alert.street,
            duration = alert.time,
            coords = alert.coords,
            jobs = alert.jobs,
        })
        return true
    end) == true
end

ServerAdapters['piotreq_gpt'] = function(alert)
    if not Compat.IsStarted('piotreq_gpt') then return false end
    return Compat.SafeCall(function()
        exports['piotreq_gpt']:SendAlert(alert.source, {
            title = AlertTitle(alert),
            code = alert.code,
            icon = alert.icon or 'fa-solid fa-question',
            info = {
                { icon = 'fa-solid fa-road', isStreet = true },
                { icon = alert.icon or 'fa-solid fa-question', data = AlertDescription(alert) },
            },
            blip = {
                scale = alert.blip.scale,
                sprite = alert.blip.sprite,
                category = 1,
                color = alert.blip.color,
                hidden = false,
                priority = alert.priority or 5,
                short = true,
                alpha = 200,
                name = AlertTitle(alert),
            },
            type = 'normal',
            canAnswer = false,
            maxOfficers = 6,
            time = math.max(1, math.floor((alert.time or 30000) / 60000)),
            notifyTime = math.min(alert.time or 8000, 8000),
        })
        return true
    end) == true
end

ServerAdapters['fd_dispatch'] = function(alert)
    if not Compat.IsStarted('fd_dispatch') then return false end
    return Compat.SafeCall(function()
        exports.fd_dispatch:addAlert({
            source = alert.source,
            title = AlertTitle(alert),
            description = AlertDescription(alert),
            groups = alert.jobs,
            code = alert.code,
            priority = alert.priority,
            metadata = alert.metadata or {},
            blip = {
                title = AlertTitle(alert),
                coords = alert.coords,
                radius = alert.blip.radius,
                sprite = alert.blip.sprite,
                color = alert.blip.color,
                scale = alert.blip.scale,
                flashes = alert.blip.flash,
                time = alert.time,
            },
        })
        return true
    end) == true
end

-- These two resources expose server exports in some versions. The pcall keeps
-- older/newer versions from breaking the dispatch chain.
ServerAdapters['bub-mdt'] = function(alert)
    if not Compat.IsStarted('bub-mdt') then return false end
    return Compat.SafeCall(function()
        exports['bub-mdt']:CustomAlert({
            code = alert.code,
            offense = AlertTitle(alert),
            coords = alert.coords,
            info = { label = alert.code, icon = alert.icon },
            blip = alert.blip.sprite,
            isEmergency = alert.priority == 1,
            blipCoords = alert.coords,
            jobs = alert.jobs,
        })
        return true
    end) == true
end

ServerAdapters['wasabi_mdt'] = function(alert)
    if not Compat.IsStarted('wasabi_mdt') then return false end
    local coords = Compat.ToCoordTable(alert.coords) or { x = 0, y = 0, z = 0 }
    return Compat.SafeCall(function()
        exports.wasabi_mdt:CreateDispatch({
            type = alert.code,
            title = AlertTitle(alert),
            description = AlertDescription(alert),
            location = { coords.x, coords.y, coords.z },
            coords = { coords.x, coords.y, coords.z },
            jobs = alert.jobs,
        })
        return true
    end) == true
end

ServerAdapters['kartik-mdt'] = function(alert)
    if not Compat.IsStarted('kartik-mdt') then return false end
    local jobs = {}
    for _, job in ipairs(alert.jobs or {}) do jobs[job] = true end
    return Compat.SafeCall(function()
        exports['kartik-mdt']:CustomAlert({
            title = AlertTitle(alert),
            code = alert.code,
            description = AlertDescription(alert),
            type = 'Alert',
            coords = alert.coords,
            blip = {
                radius = alert.blip.radius,
                sprite = alert.blip.sprite,
                color = alert.blip.color,
                scale = alert.blip.scale,
                length = 2,
            },
            jobs = jobs,
        })
        return true
    end) == true
end

ServerAdapters['emergencydispatch'] = function(alert)
    if not Compat.IsStarted('emergencydispatch') then return false end
    return Compat.SafeCall(function()
        TriggerEvent('emergencydispatch:emergencycall:new', alert.job, AlertTitle(alert), alert.coords, true)
        return true
    end) == true
end

---Invoke a named server backend.
---@param resource string
---@param alert table
---@return boolean
function Dispatch.InvokeBackend(resource, alert)
    if not resource or resource == 'default' or resource == 'disabled' then return false end

    local custom = Dispatch.Backends[resource]
    if custom then
        local ok, result = pcall(custom, alert)
        return ok and result == true
    end

    local adapter = ServerAdapters[resource]
    if adapter then
        local ok, result = pcall(adapter, alert)
        return ok and result == true
    end

    return false
end

---Server-side backends only return true here. Client-only backends are relayed
---to a recipient client by SendAlert.
function Dispatch.HasServerAdapter(resource)
    return ServerAdapters[resource] ~= nil or Dispatch.Backends[resource] ~= nil
end

-- ---------------------------------------------------------------------------
-- Delivery
-- ---------------------------------------------------------------------------

function Dispatch.BroadcastFallback(alert, options)
    options = options or {}
    if DispatchConfig().Fallback == false then return 0 end

    local recipients = Dispatch.GetRecipients(alert.jobs)
    local sent = 0
    for _, src in ipairs(recipients) do
        if tonumber(src) ~= tonumber(options.exclude) then
            TriggerClientEvent('sandbox_bridge:client:dispatchFallback', src, alert)
            sent = sent + 1
        end
    end

    if sent == 0 and DispatchConfig().NotifyCaller ~= false then
        local source = tonumber(alert.source)
        if source and IsSourceOnline(source) and source ~= tonumber(options.exclude) then
            TriggerClientEvent('sandbox_bridge:client:dispatchFallback', source, alert)
            sent = sent + 1
        end
    end

    if sent > 0 then
        TriggerEvent('sandbox_bridge:server:dispatch:fallback', alert, recipients)
    end
    return sent
end

---Relay an alert to a client so a client-only backend can deliver it.
function Dispatch.RelayToClient(alert)
    if DispatchConfig().RelayToClient == false then return false end

    local recipients = Dispatch.GetRecipients(alert.jobs)
    local target = tonumber(alert.source)
    if target and not IsSourceOnline(target) then target = nil end
    if not target or not Compat.TableContains(recipients, target) then
        target = recipients[1]
    end

    if not target then return false end

    alert.relayed = true
    TriggerClientEvent('sandbox_bridge:client:dispatchAlert', target, alert)
    return true
end

---Send an alert from trusted server code.
---@param data table|string
---@param options table|nil
---@return table|nil alert
---@return boolean delivered
function Dispatch.SendAlert(data, options)
    options = options or {}
    if not Dispatch.IsEnabled() then return nil, false end

    local alert = Compat.NormalizeAlert(data, options.source or (type(data) == 'table' and data.source))
    local backend = options.backend or Dispatch.GetResourceName()

    if options.recordOnly then
        return Dispatch.RecordAlert(alert, backend), false
    end

    local call = Dispatch.RecordAlert(alert, backend)
    if call then alert.id = call.id end

    local delivered = Dispatch.InvokeBackend(backend, alert)
    if not delivered and backend ~= 'default' then
        delivered = Dispatch.RelayToClient(alert)
    end

    if not delivered then
        Dispatch.BroadcastFallback(alert)
    end

    if call and delivered then
        TriggerEvent('sandbox_bridge:server:dispatch:delivered', call, backend)
    end

    return call or alert, delivered
end

Dispatch.Send = Dispatch.SendAlert

-- ---------------------------------------------------------------------------
-- Net events
-- ---------------------------------------------------------------------------

local function CanCreateAlert(src)
    local killswitch = DispatchConfig().RateLimitSeconds or 1
    local now = os.time and os.time() or 0
    local last = Dispatch.LastAlert[src]
    if last and (now - last) < killswitch then return false end
    Dispatch.LastAlert[src] = now
    return true
end

RegisterNetEvent('sandbox_bridge:server:dispatch:record', function(data, delivered, backend)
    local src = source
    if not Dispatch.IsEnabled() then return end
    if not CanCreateAlert(src) then return end

    local alert = Compat.NormalizeAlert(data, src)
    alert.source = src

    local call = Dispatch.RecordAlert(alert, backend)
    if call then alert.id = call.id end

    if delivered ~= true then
        Dispatch.BroadcastFallback(alert, { exclude = src })
    end

    TriggerEvent('sandbox_bridge:server:dispatch:clientAlert', alert, src)
end)

RegisterNetEvent('sandbox_bridge:server:dispatch:backend', function(resource, data)
    local src = source
    if not Dispatch.IsEnabled() then return end
    if not CanCreateAlert(src) then return end

    local alert = Compat.NormalizeAlert(data, src)
    alert.source = src

    local ok = Dispatch.InvokeBackend(resource, alert)
    if not ok then
        Dispatch.BroadcastFallback(alert, { exclude = src })
    end
end)

RegisterNetEvent('sandbox_bridge:server:dispatch:relayFailed', function(alertId)
    local call = Dispatch.GetCall(alertId)
    if not call then return end
    local alert = Compat.Copy(call)
    alert.source = source
    Dispatch.BroadcastFallback(alert, { exclude = source })
end)

RegisterNetEvent('sandbox_bridge:server:dispatch:request', function(requestId, filters)
    local src = source
    local payload = {
        calls = Dispatch.GetCalls(filters),
        stats = Dispatch.GetStats(),
        backend = Dispatch.GetResourceName(),
        mdt = Dispatch.GetMDTResourceName(),
    }
    TriggerClientEvent('sandbox_bridge:client:dispatch:response', src, requestId, payload)
end)

RegisterNetEvent('sandbox_bridge:server:dispatch:recipients', function(requestId, jobs, onDutyOnly)
    local src = source
    local recipients = Dispatch.IsEnabled() and Dispatch.GetRecipients(jobs, onDutyOnly) or {}
    TriggerClientEvent('sandbox_bridge:client:dispatch:recipients', src, requestId, recipients)
end)

---Expose the dispatch event names so Sandbox resources can consume them without
---depending on the bridge internals.
function Dispatch.GetEvents()
    return {
        created = 'sandbox_bridge:server:dispatch:created',
        updated = 'sandbox_bridge:server:dispatch:updated',
        closed = 'sandbox_bridge:server:dispatch:closed',
        delivered = 'sandbox_bridge:server:dispatch:delivered',
        fallback = 'sandbox_bridge:server:dispatch:fallback',
    }
end

return Dispatch
