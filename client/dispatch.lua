-- sandbox-bridge-lib/client/dispatch.lua
-- Loaded by client/main.lua in the shared bridge environment.
--
-- Unified Dispatch client. Every supported dispatch/tablet resource is wrapped
-- in a small adapter, and a native notification + blip fallback guarantees the
-- alert is visible even when no dispatch resource is running.

SB = SB or {}

Dispatch = {}
SB.Dispatch = Dispatch

local Compat = SandboxBridgeCompat

Dispatch.Callbacks = {}
Dispatch.Sequence = 0
Dispatch.LastAlert = nil

local function DispatchConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Dispatch) or {}
end

local function MDTConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.MDT) or {}
end

function Dispatch.IsEnabled()
    return DispatchConfig().Enabled ~= false
end

function Dispatch.GetAvailableBackends()
    return Compat.GetStarted(Compat.DispatchResources)
end

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

-- ---------------------------------------------------------------------------
-- Native fallback
-- ---------------------------------------------------------------------------

function Dispatch.RemoveBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

function Dispatch.ShowFallback(alert)
    if DispatchConfig().Fallback == false then return end

    local message = ('[%s] %s'):format(tostring(alert.code or '10-80'), tostring(alert.message or 'Dispatch alert'))
    if type(ShowNotification) == 'function' then
        ShowNotification(message, 'warning', alert.time or 15000)
    elseif GetResourceState('ox_lib') == 'started' then
        Compat.SafeCall(function()
            exports.ox_lib:notify({
                title = ('Dispatch %s'):format(tostring(alert.code or '')),
                description = alert.message,
                type = 'warning',
                duration = alert.time or 15000,
            })
        end)
    end

    local coords = Compat.ToCoords(alert.coords)
    if not coords then return end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, tonumber(alert.blip and alert.blip.sprite) or 161)
    SetBlipColour(blip, tonumber(alert.blip and alert.blip.color) or 1)
    SetBlipScale(blip, tonumber(alert.blip and alert.blip.scale) or 0.8)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, alert.blip and alert.blip.flash == true or false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s %s'):format(tostring(alert.code or ''), tostring(alert.message or '')))
    EndTextCommandSetBlipName(blip)

    local duration = tonumber(alert.time) or 30000
    SetTimeout(duration, function()
        Dispatch.RemoveBlip(blip)
    end)

    return blip
end

-- ---------------------------------------------------------------------------
-- Backend adapters
-- ---------------------------------------------------------------------------

local function Street(alert)
    local street = alert.street
    if not street then
        street = Compat.GetStreetName(alert.coords)
    end
    return street or alert.zone or 'Unknown location'
end

local Adapters = {}

Adapters['ps-dispatch'] = function(alert)
    if not Compat.IsStarted('ps-dispatch') then return false end
    if Compat.IsStarted('lb-tablet') then return false end

    return Compat.SafeCall(function()
        exports['ps-dispatch']:CustomAlert({
            message = alert.message,
            code = alert.code,
            icon = alert.icon,
            priority = Compat.PriorityNumber(alert.priority),
            coords = alert.coords,
            vehicle = alert.vehicle and alert.vehicle.entity,
            plate = alert.vehicle and alert.vehicle.plate,
            alertTime = math.max(1, math.floor((alert.time or 30000) / 1000)),
            radius = alert.blip.radius,
            sprite = alert.blip.sprite,
            color = alert.blip.color,
            scale = alert.blip.scale,
            length = 2,
            sound = 'Lose_1st',
            sound2 = 'GTAO_FM_Events_Soundset',
            offset = false,
            flash = alert.blip.flash,
            jobs = alert.jobs,
        })
        return true
    end) == true
end

Adapters['cd_dispatch'] = function(alert)
    if not Compat.IsStarted('cd_dispatch') then return false end
    local playerInfo = Compat.SafeCall(function()
        return exports['cd_dispatch']:GetPlayerInfo()
    end) or {}

    TriggerServerEvent('cd_dispatch:AddNotification', {
        job_table = alert.jobs,
        coords = alert.coords,
        title = alert.title,
        message = alert.message,
        flash = 0,
        unique_id = playerInfo.unique_id,
        sound = 1,
        blip = {
            sprite = alert.blip.sprite,
            scale = alert.blip.scale,
            colour = alert.blip.color,
            flashes = alert.blip.flash,
            text = alert.message,
            time = math.max(1, math.floor((alert.time or 30000) / 1000)),
            radius = alert.blip.radius,
        },
    })
    return true
end

Adapters['bub-mdt'] = function(alert)
    if not Compat.IsStarted('bub-mdt') then return false end
    return Compat.SafeCall(function()
        exports['bub-mdt']:CustomAlert({
            code = alert.code,
            offense = alert.message,
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

Adapters['qs-dispatch'] = function(alert)
    if not Compat.IsStarted('qs-dispatch') then return false end
    local playerData = Compat.SafeCall(function()
        return exports['qs-dispatch']:GetPlayerInfo()
    end)
    if not playerData then return false end

    local customData = {
        job = alert.jobs,
        callLocation = alert.coords,
        callCode = { code = alert.code, snippet = alert.title or 'General Alert' },
        message = alert.message,
        flashes = false,
        image = nil,
        blip = {
            sprite = alert.blip.sprite,
            scale = alert.blip.scale,
            colour = alert.blip.color,
            flashes = alert.blip.flash,
            text = alert.message,
            time = alert.time,
        },
        otherData = {
            { text = alert.title or 'N/A', icon = alert.icon },
        },
    }

    local ok = Compat.SafeCall(function()
        exports['qs-dispatch']:getSSURL(function(image)
            customData.image = image or customData.image
            TriggerServerEvent('qs-dispatch:server:CreateDispatchCall', customData)
        end)
        return true
    end) == true

    if ok then return true end
    TriggerServerEvent('qs-dispatch:server:CreateDispatchCall', customData)
    return true
end

Adapters['tk_dispatch'] = function(alert)
    if not Compat.IsStarted('tk_dispatch') then return false end
    return Compat.SafeCall(function()
        exports.tk_dispatch:addCall({
            title = alert.message,
            code = alert.code,
            priority = ('Priority %d'):format(alert.priority),
            coords = alert.coords,
            showLocation = true,
            showGender = false,
            playSound = true,
            blip = {
                color = alert.blip.color,
                sprite = alert.blip.sprite,
                scale = alert.blip.scale,
            },
            jobs = alert.jobs,
        })
        return true
    end) == true
end

Adapters['wasabi_mdt'] = function(alert)
    if not Compat.IsStarted('wasabi_mdt') then return false end
    local coords = Compat.ToCoordTable(alert.coords) or { x = 0.0, y = 0.0, z = 0.0 }
    return Compat.SafeCall(function()
        exports.wasabi_mdt:CreateDispatch({
            type = alert.code,
            title = alert.title,
            description = alert.message,
            location = { coords.x, coords.y, coords.z },
            coords = { coords.x, coords.y, coords.z },
            jobs = alert.jobs,
        })
        return true
    end) == true
end

Adapters['kartik-mdt'] = function(alert)
    if not Compat.IsStarted('kartik-mdt') then return false end
    local jobs = {}
    for _, job in ipairs(alert.jobs or {}) do jobs[job] = true end
    return Compat.SafeCall(function()
        exports['kartik-mdt']:CustomAlert({
            title = alert.title,
            code = alert.code,
            description = alert.message,
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

Adapters['lb-tablet'] = function(alert)
    if not Compat.IsStarted('lb-tablet') then return false end
    -- The tablet stores the call server side.
    TriggerServerEvent('sandbox_bridge:server:dispatch:backend', 'lb-tablet', alert)
    return true
end

Adapters['redutzu-mdt'] = function(alert)
    if not Compat.IsStarted('redutzu-mdt') then return false end
    TriggerServerEvent('sandbox_bridge:server:dispatch:backend', 'redutzu-mdt', alert)
    return true
end

Adapters['fd_dispatch'] = function(alert)
    if not Compat.IsStarted('fd_dispatch') then return false end
    if Compat.IsStarted('lb-tablet') then return false end
    return Compat.SafeCall(function()
        exports.fd_dispatch:CustomAlert({
            title = alert.title,
            description = alert.message,
            groups = alert.jobs,
            location = { coords = alert.coords, street = Street(alert) },
            code = alert.code,
            priority = alert.priority,
            metadata = alert.metadata,
            blip = {
                radius = alert.blip.radius,
                sprite = alert.blip.sprite,
                color = alert.blip.color,
                scale = alert.blip.scale,
                time = alert.time,
            },
        })
        return true
    end) == true
end

Adapters['origen_police'] = function(alert)
    if not Compat.IsStarted('origen_police') then return false end
    local metadata = { model = alert.vehicle and alert.vehicle.model or nil, plate = alert.vehicle and alert.vehicle.plate or nil }
    TriggerServerEvent('SendAlert:police', {
        coords = alert.coords,
        title = ('Alert %s'):format(alert.code),
        message = alert.message,
        job = alert.job,
        metadata = metadata,
    })
    return true
end

Adapters['piotreq_gpt'] = function(alert)
    if not Compat.IsStarted('piotreq_gpt') then return false end
    TriggerServerEvent('sandbox_bridge:server:dispatch:backend', 'piotreq_gpt', alert)
    return true
end

Adapters['linden_outlawalert'] = function(alert)
    if not Compat.IsStarted('linden_outlawalert') then return false end
    TriggerServerEvent('wf-alerts:svNotify', {
        dispatchData = {
            displayCode = alert.code,
            description = alert.message,
            isImportant = 0,
            recipientList = alert.jobs,
            length = alert.time,
            infoM = alert.icon,
            info = alert.message,
        },
        caller = 'Anonymous',
        coords = alert.coords,
    })
    return true
end

Adapters['emergencydispatch'] = function(alert)
    if not Compat.IsStarted('emergencydispatch') then return false end
    TriggerServerEvent('emergencydispatch:emergencycall:new', alert.job, alert.message, alert.coords, true)
    return true
end

---Run the adapter for one resource.
---@param backend string
---@param alert table
---@return boolean
function Dispatch.InvokeBackend(backend, alert)
    local adapter = Adapters[backend]
    if not adapter then return false end
    local ok, result = pcall(adapter, alert)
    return ok and result == true
end

function Dispatch.HasAdapter(backend)
    return Adapters[backend] ~= nil
end

-- ---------------------------------------------------------------------------
-- Public send API
-- ---------------------------------------------------------------------------

local function Deliver(alert)
    local backend = Dispatch.GetResourceName()
    if backend == 'default' or backend == 'disabled' then return false, backend end
    return Dispatch.InvokeBackend(backend, alert), backend
end

---Send a dispatch alert from this client.
---@param data table|string
---@param options table|nil
---@return boolean delivered
---@return string backend
function Dispatch.SendAlert(data, options)
    options = options or {}
    if not Dispatch.IsEnabled() then return false, 'disabled' end

    local alert = Compat.NormalizeAlert(data)
    alert.source = GetPlayerServerId(PlayerId())

    local delivered, backend = Deliver(alert)
    if options.fromServer then
        if not delivered then Dispatch.ShowFallback(alert) end
        return delivered, backend
    end

    Dispatch.LastAlert = alert
    TriggerServerEvent('sandbox_bridge:server:dispatch:record', alert, delivered, backend)

    return delivered, backend
end

Dispatch.Send = Dispatch.SendAlert
Dispatch.CreateCall = Dispatch.SendAlert

---Request the server call registry.
---@param callback function|nil
---@param filters table|nil
function Dispatch.GetCalls(filters, callback)
    if type(filters) == 'function' then
        callback = filters
        filters = nil
    end

    Dispatch.Sequence = Dispatch.Sequence + 1
    local requestId = ('dispatch-%d-%d'):format(GetGameTimer(), Dispatch.Sequence)
    Dispatch.Callbacks[requestId] = callback

    TriggerServerEvent('sandbox_bridge:server:dispatch:request', requestId, filters or {})
    return requestId
end

Dispatch.RequestCalls = Dispatch.GetCalls

---Get the local recipient list for a job set (server aware).
function Dispatch.GetRecipients(jobs, callback)
    if type(jobs) == 'function' then
        callback = jobs
        jobs = nil
    end
    if type(jobs) == 'string' then jobs = { jobs } end

    -- The bridge does not duplicate the server job cache on the client; use a
    -- callback so callers get the authoritative Sandbox assignment.
    Dispatch.Sequence = Dispatch.Sequence + 1
    local requestId = ('recipients-%d-%d'):format(GetGameTimer(), Dispatch.Sequence)
    Dispatch.Callbacks[requestId] = callback
    TriggerServerEvent('sandbox_bridge:server:dispatch:recipients', requestId, jobs or {})
    return requestId
end

RegisterNetEvent('sandbox_bridge:client:dispatch:response', function(requestId, payload)
    local callback = Dispatch.Callbacks[requestId]
    Dispatch.Callbacks[requestId] = nil
    if callback then callback(payload) end
    TriggerEvent('sandbox_bridge:client:dispatch:data', requestId, payload)
end)

RegisterNetEvent('sandbox_bridge:client:dispatch:recipients', function(requestId, recipients)
    local callback = Dispatch.Callbacks[requestId]
    Dispatch.Callbacks[requestId] = nil
    if callback then callback(recipients or {}) end
    TriggerEvent('sandbox_bridge:client:dispatch:recipientData', requestId, recipients or {})
end)

RegisterNetEvent('sandbox_bridge:client:dispatchAlert', function(alert)
    if type(alert) ~= 'table' then return end
    local delivered = Dispatch.InvokeBackend(Dispatch.GetResourceName(), Compat.NormalizeAlert(alert))
    if not delivered then
        Dispatch.ShowFallback(alert)
        TriggerServerEvent('sandbox_bridge:server:dispatch:relayFailed', alert.id)
    end
end)

RegisterNetEvent('sandbox_bridge:client:dispatchFallback', function(alert)
    if type(alert) ~= 'table' then return end
    Dispatch.ShowFallback(alert)
end)

RegisterNetEvent('sandbox_bridge:client:dispatch:created', function(call)
    TriggerEvent('sandbox_bridge:client:dispatch:new', call)
end)

RegisterNetEvent('sandbox_bridge:client:dispatch:closed', function(call)
    TriggerEvent('sandbox_bridge:client:dispatch:callClosed', call)
end)

-- ---------------------------------------------------------------------------
-- MDT client
-- ---------------------------------------------------------------------------

MDT = {}
SB.MDT = MDT

MDT.Callbacks = {}
MDT.Sequence = 0

local function MDT_Config()
    return (SandboxBridgeConfig and SandboxBridgeConfig.MDT) or {}
end

function MDT.GetAvailableResources()
    return Compat.GetStarted(Compat.MDTResources)
end

function MDT.GetResourceName()
    local config = MDT_Config()
    if config.Enabled == false then return 'disabled' end
    local active = Compat.SelectConfigured(config, Compat.MDTResources)
    return active or 'default'
end

function MDT.GetBackend()
    return MDT.GetResourceName()
end

function MDT.IsAvailable()
    local backend = MDT.GetResourceName()
    return backend ~= 'default' and backend ~= 'disabled'
end

---Open the active MDT/tablet. Returns true when an event or export accepted the
---request. Custom tablets can be added through Config.MDT.OpenEvents.
---@param payload table|nil
---@return boolean
function MDT.Open(payload)
    payload = type(payload) == 'table' and payload or {}
    local resource = MDT.GetResourceName()
    if resource == 'default' or resource == 'disabled' then return false end

    -- Prefer an explicit export when the resource provides one.
    local ok, result = pcall(function()
        return exports[resource]:OpenMDT(payload)
    end)
    if ok and result ~= false then return true end

    local events = (MDT_Config().OpenEvents or {})[resource] or {}
    for _, eventName in ipairs(events) do
        TriggerEvent(eventName, payload)
    end

    -- Common fallbacks used by several tablets.
    for _, eventName in ipairs({
        'MDT:Client:Open',
        'mdt:client:open',
        ('%s:client:open'):format(resource),
    }) do
        TriggerEvent(eventName, payload)
    end

    return #events > 0
end

function MDT.OpenProfile(citizenid)
    return MDT.Open({ citizenid = tostring(citizenid or '') })
end

function MDT.OpenCall(callId)
    return MDT.Open({ callId = callId })
end

local function Request(kind, payload, callback)
    MDT.Sequence = MDT.Sequence + 1
    local requestId = ('mdt-%s-%d-%d'):format(kind, GetGameTimer(), MDT.Sequence)
    MDT.Callbacks[requestId] = callback
    TriggerServerEvent(('sandbox_bridge:server:mdt:%s'):format(kind), requestId, table.unpack(payload or {}))
    return requestId
end

function MDT.GetProfile(identifier, callback)
    return Request('profile', { identifier }, callback)
end

function MDT.Search(query, callback, filters)
    if type(query) == 'table' then
        filters = query
        query = filters.query
    end
    return Request('search', { query, filters or {} }, callback)
end

function MDT.GetOfficers(callback, filters)
    return Request('officers', { filters or {} }, callback)
end

function MDT.GetCalls(callback, filters)
    return Request('calls', { filters or {} }, callback)
end

function MDT.GetStats(callback)
    return Request('stats', {}, callback)
end

RegisterNetEvent('sandbox_bridge:client:mdt:response', function(requestId, data)
    local callback = MDT.Callbacks[requestId]
    MDT.Callbacks[requestId] = nil
    if callback then callback(data) end
    TriggerEvent('sandbox_bridge:client:mdt:data', requestId, data)
end)

RegisterNetEvent('sandbox_bridge:client:skills:response', function(requestId, data)
    local callback = MDT.Callbacks[requestId]
    MDT.Callbacks[requestId] = nil
    if callback then callback(data) end
end)

return Dispatch
