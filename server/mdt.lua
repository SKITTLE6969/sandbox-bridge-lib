-- sandbox-bridge-lib/server/mdt.lua
-- Loaded by server/main.lua in the shared bridge environment.
--
-- Sandbox aware MDT data layer. It exposes Sandbox character/job/vehicle data
-- in a tablet friendly shape and keeps lightweight reports, warrants, notes and
-- BOLOs for scripts that do not ship their own MDT database.

MDT = {}
SB.MDT = MDT

local Compat = SandboxBridgeCompat
local Dispatch = SB.Dispatch

MDT.Reports = {}
MDT.Warrants = {}
MDT.Notes = {}
MDT.Bolos = {}
MDT.Sequence = {}

local function trimMDTList(list)
    if type(list) ~= 'table' then return end
    local max = (MaxResults() or 100) * 10
    while #list > max do
        table.remove(list, 1)
    end
end

-- ---------------------------------------------------------------------------
-- Configuration / detection
-- ---------------------------------------------------------------------------

local function MDTConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.MDT) or {}
end

local function MaxResults()
    return tonumber(MDTConfig().MaxResults) or 100
end

function MDT.IsEnabled()
    return MDTConfig().Enabled ~= false
end

function MDT.GetAvailableResources()
    return Compat.GetStarted(Compat.MDTResources)
end

function MDT.GetResourceName()
    if not MDT.IsEnabled() then return 'disabled' end
    local active = Compat.SelectConfigured(MDTConfig(), Compat.MDTResources)
    return active or 'default'
end

function MDT.GetBackend()
    return MDT.GetResourceName()
end

function MDT.IsAvailable()
    local backend = MDT.GetResourceName()
    return backend ~= 'default' and backend ~= 'disabled'
end

function MDT.GetDispatchResourceName()
    return Dispatch and Dispatch.GetResourceName() or 'default'
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function NextId(prefix)
    MDT.Sequence[prefix] = (MDT.Sequence[prefix] or 0) + 1
    return ('%s-%06d'):format(prefix, MDT.Sequence[prefix])
end

local function Now()
    return os.time and os.time() or 0
end

local function ResolveAuthor(author)
    if type(author) == 'table' then
        return {
            source = author.source,
            name = author.name,
            citizenid = author.citizenid,
            callsign = author.callsign,
        }
    end

    local src = tonumber(author)
    if src then
        local data = SB.BuildPlayerData(src)
        if data then
            return {
                source = src,
                name = data.name,
                citizenid = data.citizenid,
                callsign = data.metadata and data.metadata.callsign or nil,
                job = data.job and data.job.name or nil,
            }
        end
    end

    return { name = type(author) == 'string' and author or 'System' }
end

local function CopyRow(row)
    if type(row) ~= 'table' then return nil end
    local copy = Compat.Copy(row)
    copy.raw = nil
    return copy
end

local function CharacterRow(citizenid)
    citizenid = tostring(citizenid or '')
    if citizenid == '' then return nil end
    return Compat.SafeCall(function()
        return exports['sandbox-characters']:BridgeGetCharacterRow(citizenid)
            or exports['sandbox-characters']:BridgeGetCharacterRow(tonumber(citizenid))
    end)
end

local function BuildSummary(data)
    if type(data) ~= 'table' then return nil end
    local charinfo = data.charinfo or {}
    local job = data.job or {}
    local metadata = data.metadata or {}

    return {
        source = data.source,
        citizenid = tostring(data.citizenid or data.cid or ''),
        name = data.name or ('%s %s'):format(charinfo.firstname or 'Unknown', charinfo.lastname or 'Unknown'),
        firstname = charinfo.firstname,
        lastname = charinfo.lastname,
        phone = charinfo.phone or metadata.phone,
        dob = charinfo.birthdate,
        gender = charinfo.gender,
        job = job.name,
        jobLabel = job.label,
        grade = job.grade and job.grade.level or 0,
        gradeLabel = job.grade and job.grade.label or '',
        onDuty = job.onduty == true,
        callsign = metadata.callsign,
        license = data.license,
        offline = data.offline == true,
        lastSeen = data.lastLoggedOut or nil,
        position = data.position,
    }
end

local function BuildProfile(data)
    if type(data) ~= 'table' then return nil end
    local summary = BuildSummary(data)
    if not summary then return nil end

    local metadata = data.metadata or {}
    local citizenid = summary.citizenid

    summary.charinfo = data.charinfo
    summary.money = data.money
    summary.jobs = data.jobs
    summary.gang = data.gang
    summary.gangs = data.gangs
    summary.metadata = metadata
    summary.licenses = metadata.licences or metadata.licenses or {}
    summary.status = data.status
    summary.vehicles = MDT.GetVehicles(citizenid)
    summary.reports = MDT.GetReports({ citizenid = citizenid })
    summary.warrants = MDT.GetWarrants({ citizenid = citizenid })
    summary.notes = MDT.GetNotes({ citizenid = citizenid })
    summary.bolos = MDT.GetBolos({ citizenid = citizenid })
    summary.calls = Dispatch and Dispatch.GetCalls({ query = citizenid }) or {}
    return summary
end

-- ---------------------------------------------------------------------------
-- Characters / profiles
-- ---------------------------------------------------------------------------

---Get a full MDT profile for an online source or a citizenid.
---@param identifier number|string|table
---@return table|nil
function MDT.GetProfile(identifier)
    if type(identifier) == 'table' then
        if identifier.citizenid then identifier = identifier.citizenid
        elseif identifier.source then identifier = identifier.source end
    end

    local src = tonumber(identifier)
    if src then
        local data = SB.BuildPlayerData(src)
        if data then return BuildProfile(data) end

        -- Numeric citizen ids and sources can overlap. Fall through to the
        -- offline character lookup when the source is not online.
        local player = SB.GetOfflinePlayer(src)
        if player and player.PlayerData then return BuildProfile(player.PlayerData) end
        return nil
    end

    local player = SB.GetOfflinePlayer(tostring(identifier or ''))
    if player and player.PlayerData then return BuildProfile(player.PlayerData) end

    local row = CharacterRow(identifier)
    if row then
        local data = BuildOfflinePlayerData(row, true)
        if data then return BuildProfile(data) end
    end
    return nil
end

MDT.GetPlayer = MDT.GetProfile

---Search online and offline Sandbox characters.
---@param query string|nil
---@param filters table|nil
---@return table
function MDT.Search(query, filters)
    filters = filters or {}
    if type(query) == 'table' then
        filters = query
        query = filters.query
    end

    local results, seen = {}, {}

    local function Add(data)
        if type(data) ~= 'table' then return end
        local citizenid = tostring(data.citizenid or '')
        if citizenid == '' or seen[citizenid] then return end

        local summary = BuildSummary(data)
        if not summary then return end

        local matches = true
        if filters.job and summary.job ~= filters.job then matches = false end
        if filters.online == true and summary.offline then matches = false end
        if filters.offline == true and not summary.offline then matches = false end

        if matches and query and query ~= '' then
            matches = Compat.Matches(summary.name, query)
                or Compat.Matches(summary.citizenid, query)
                or Compat.Matches(summary.phone, query)
                or Compat.Matches(summary.callsign, query)
                or Compat.Matches(summary.license, query)
        end

        if matches then
            seen[citizenid] = true
            results[#results + 1] = summary
        end
    end

    for _, src in ipairs(SB.GetPlayers()) do
        Add(SB.BuildPlayerData(src))
    end

    local rows = Compat.SafeCall(function()
        return exports['sandbox-characters']:BridgeGetAllCharacterRows()
    end) or {}

    for _, row in ipairs(rows) do
        Add(BuildOfflinePlayerData(row, true))
    end

    Compat.SortByCreatedAt(results, false)
    table.sort(results, function(a, b)
        if a.offline ~= b.offline then return not a.offline end
        return tostring(a.name or '') < tostring(b.name or '')
    end)

    local limit = tonumber(filters.limit) or MaxResults()
    while #results > limit do table.remove(results) end
    return results
end

function MDT.SearchProfiles(query, filters)
    filters = filters or {}
    local summaries = MDT.Search(query, filters)
    local profiles = {}
    for _, summary in ipairs(summaries) do
        local profile = MDT.GetProfile(summary.source or summary.citizenid)
        profiles[#profiles + 1] = profile or summary
    end
    return profiles
end

---All law-enforcement players, optionally filtered by job/source/duty.
function MDT.GetOfficers(filters)
    return Dispatch.GetOfficers(filters)
end

MDT.GetUnits = MDT.GetOfficers

function MDT.GetLicenses(identifier)
    local profile = MDT.GetProfile(identifier)
    return profile and profile.licenses or {}
end

-- ---------------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------------

---Read owned vehicles for a citizen from the Sandbox `vehicles` table.
---@param citizenid string|number
---@return table
function MDT.GetVehicles(citizenid)
    citizenid = tostring(citizenid or '')
    if citizenid == '' or type(MySQL) ~= 'table' then return {} end

    local numeric = tonumber(citizenid)
    local rows = Compat.SafeCall(function()
        if numeric then
            return MySQL.query.await(
                'SELECT * FROM vehicles WHERE OwnerId = ? OR OwnerId = ?',
                { citizenid, numeric }
            ) or {}
        end
        return MySQL.query.await('SELECT * FROM vehicles WHERE OwnerId = ?', { citizenid }) or {}
    end) or {}

    local vehicles = {}
    for _, row in ipairs(rows) do
        local coords = nil
        if row.Coords then
            local decoded = Compat.SafeCall(function() return json.decode(row.Coords) end)
            coords = Compat.ToCoordTable(decoded)
        end

        vehicles[#vehicles + 1] = {
            id = row.ID or row.Id or row.id,
            vin = row.VIN or row.vin,
            owner = row.OwnerId or row.owner,
            ownerType = row.OwnerType,
            model = row.Model or row.model or row.vehicle,
            plate = row.RegisteredPlate or row.Plate or row.plate,
            state = row.State or row.state,
            color = row.Color or row.color,
            fuel = row.Fuel or row.fuel,
            mileage = row.Mileage or row.mileage or row.Odometer,
            garage = row.Garage or row.garage,
            impounded = row.Impounded == true or row.impounded == true,
            coords = coords,
        }
    end

    return vehicles
end

MDT.GetPlayerVehicles = MDT.GetVehicles

-- ---------------------------------------------------------------------------
-- Reports
-- ---------------------------------------------------------------------------

local function StoreList(name)
    if name == 'reports' then return MDT.Reports end
    if name == 'warrants' then return MDT.Warrants end
    if name == 'notes' then return MDT.Notes end
    if name == 'bolos' then return MDT.Bolos end
    return {}
end

local function FilterList(list, filters, searchFields)
    filters = filters or {}
    local results = {}

    for _, entry in ipairs(list) do
        local matches = true
        if filters.citizenid and tostring(entry.citizenid) ~= tostring(filters.citizenid) then matches = false end
        if filters.author and not Compat.Matches(entry.author and entry.author.name, filters.author) then matches = false end
        if filters.status and entry.status ~= filters.status then matches = false end
        if filters.type and entry.type ~= filters.type then matches = false end
        if filters.query and filters.query ~= '' then
            local found = false
            for _, field in ipairs(searchFields or { 'title', 'description', 'citizenid' }) do
                if Compat.Matches(entry[field], filters.query) then found = true break end
            end
            if not found then matches = false end
        end
        if matches then results[#results + 1] = CopyRow(entry) end
    end

    Compat.SortByCreatedAt(results, true)
    local limit = tonumber(filters.limit) or MaxResults()
    while #results > limit do table.remove(results) end
    return results
end

function MDT.GetReports(filters)
    return FilterList(MDT.Reports, filters, { 'title', 'description', 'citizenid', 'type' })
end

function MDT.GetReport(reportId)
    for _, report in ipairs(MDT.Reports) do
        if tostring(report.id) == tostring(reportId) then return CopyRow(report) end
    end
    return nil
end

function MDT.CreateReport(data, author)
    data = type(data) == 'table' and data or {}
    local report = {
        id = NextId('RPT'),
        type = data.type or 'report',
        title = Compat.Trim(data.title or data.subject or 'Untitled report'),
        description = Compat.Trim(data.description or data.message or ''),
        citizenid = data.citizenid and tostring(data.citizenid) or nil,
        suspect = data.suspect,
        charges = type(data.charges) == 'table' and data.charges or {},
        evidence = type(data.evidence) == 'table' and data.evidence or {},
        location = data.location,
        status = data.status or 'open',
        author = ResolveAuthor(author or data.author or data.source),
        createdAt = Now(),
        updatedAt = Now(),
    }
    report.author.name = report.author.name or 'System'

    MDT.Reports[#MDT.Reports + 1] = report
    trimMDTList(MDT.Reports)
    TriggerEvent('sandbox_bridge:server:mdt:reportCreated', CopyRow(report))
    return CopyRow(report)
end

function MDT.UpdateReport(reportId, patch)
    for _, report in ipairs(MDT.Reports) do
        if tostring(report.id) == tostring(reportId) then
            for key, value in pairs(patch or {}) do
                if key ~= 'id' and key ~= 'createdAt' then report[key] = value end
            end
            report.updatedAt = Now()
            TriggerEvent('sandbox_bridge:server:mdt:reportUpdated', CopyRow(report))
            return CopyRow(report)
        end
    end
    return nil
end

function MDT.DeleteReport(reportId)
    for index, report in ipairs(MDT.Reports) do
        if tostring(report.id) == tostring(reportId) then
            table.remove(MDT.Reports, index)
            TriggerEvent('sandbox_bridge:server:mdt:reportDeleted', report.id)
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Warrants
-- ---------------------------------------------------------------------------

function MDT.GetWarrants(filters)
    return FilterList(MDT.Warrants, filters, { 'reason', 'citizenid', 'charges' })
end

function MDT.GetWarrant(warrantId)
    for _, warrant in ipairs(MDT.Warrants) do
        if tostring(warrant.id) == tostring(warrantId) then return CopyRow(warrant) end
    end
    return nil
end

function MDT.CreateWarrant(data, author)
    data = type(data) == 'table' and data or {}
    local warrant = {
        id = NextId('WAR'),
        citizenid = data.citizenid and tostring(data.citizenid) or nil,
        suspect = data.suspect,
        reason = Compat.Trim(data.reason or data.description or data.title or 'Warrant'),
        charges = type(data.charges) == 'table' and data.charges or {},
        evidence = type(data.evidence) == 'table' and data.evidence or {},
        status = data.status or 'active',
        expiresAt = tonumber(data.expiresAt),
        author = ResolveAuthor(author or data.author or data.source),
        createdAt = Now(),
        updatedAt = Now(),
    }

    MDT.Warrants[#MDT.Warrants + 1] = warrant
    trimMDTList(MDT.Warrants)
    TriggerEvent('sandbox_bridge:server:mdt:warrantCreated', CopyRow(warrant))
    return CopyRow(warrant)
end

function MDT.UpdateWarrant(warrantId, patch)
    for _, warrant in ipairs(MDT.Warrants) do
        if tostring(warrant.id) == tostring(warrantId) then
            for key, value in pairs(patch or {}) do
                if key ~= 'id' and key ~= 'createdAt' then warrant[key] = value end
            end
            warrant.updatedAt = Now()
            TriggerEvent('sandbox_bridge:server:mdt:warrantUpdated', CopyRow(warrant))
            return CopyRow(warrant)
        end
    end
    return nil
end

function MDT.DeleteWarrant(warrantId)
    for index, warrant in ipairs(MDT.Warrants) do
        if tostring(warrant.id) == tostring(warrantId) then
            table.remove(MDT.Warrants, index)
            TriggerEvent('sandbox_bridge:server:mdt:warrantDeleted', warrant.id)
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Notes / BOLOs
-- ---------------------------------------------------------------------------

function MDT.GetNotes(filters)
    return FilterList(MDT.Notes, filters, { 'text', 'citizenid' })
end

function MDT.CreateNote(data, author)
    data = type(data) == 'table' and data or {}
    local note = {
        id = NextId('NOTE'),
        citizenid = data.citizenid and tostring(data.citizenid) or nil,
        text = Compat.Trim(data.text or data.note or data.description or ''),
        pinned = data.pinned == true,
        author = ResolveAuthor(author or data.author or data.source),
        createdAt = Now(),
        updatedAt = Now(),
    }
    MDT.Notes[#MDT.Notes + 1] = note
    trimMDTList(MDT.Notes)
    TriggerEvent('sandbox_bridge:server:mdt:noteCreated', CopyRow(note))
    return CopyRow(note)
end

function MDT.DeleteNote(noteId)
    for index, note in ipairs(MDT.Notes) do
        if tostring(note.id) == tostring(noteId) then
            table.remove(MDT.Notes, index)
            TriggerEvent('sandbox_bridge:server:mdt:noteDeleted', note.id)
            return true
        end
    end
    return false
end

function MDT.GetBolos(filters)
    return FilterList(MDT.Bolos, filters, { 'description', 'citizenid', 'plate', 'model' })
end

function MDT.CreateBolo(data, author)
    data = type(data) == 'table' and data or {}
    local bolo = {
        id = NextId('BOLO'),
        citizenid = data.citizenid and tostring(data.citizenid) or nil,
        description = Compat.Trim(data.description or data.reason or data.text or ''),
        plate = data.plate,
        model = data.model,
        color = data.color,
        lastSeen = data.lastSeen,
        status = data.status or 'active',
        author = ResolveAuthor(author or data.author or data.source),
        createdAt = Now(),
        updatedAt = Now(),
    }
    MDT.Bolos[#MDT.Bolos + 1] = bolo
    trimMDTList(MDT.Bolos)
    TriggerEvent('sandbox_bridge:server:mdt:boloCreated', CopyRow(bolo))
    return CopyRow(bolo)
end

function MDT.CloseBolo(boloId)
    for _, bolo in ipairs(MDT.Bolos) do
        if tostring(bolo.id) == tostring(boloId) then
            bolo.status = 'closed'
            bolo.updatedAt = Now()
            TriggerEvent('sandbox_bridge:server:mdt:boloUpdated', CopyRow(bolo))
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Calls / dispatch integration
-- ---------------------------------------------------------------------------

function MDT.GetCalls(filters)
    return Dispatch.GetCalls(filters)
end

function MDT.GetCall(callId)
    return Dispatch.GetCall(callId)
end

function MDT.CreateCall(data, source)
    return Dispatch.SendAlert(data, { source = source })
end

function MDT.UpdateCall(callId, patch)
    return Dispatch.UpdateCall(callId, patch)
end

function MDT.CloseCall(callId, reason)
    return Dispatch.CloseCall(callId, reason)
end

function MDT.GetStats()
    return {
        reports = #MDT.Reports,
        warrants = #MDT.Warrants,
        notes = #MDT.Notes,
        bolos = #MDT.Bolos,
        calls = Dispatch.GetStats(),
        backend = MDT.GetResourceName(),
        dispatch = Dispatch.GetResourceName(),
    }
end

---Clear the in-memory MDT store (useful for tests or /refresh commands).
function MDT.Clear()
    MDT.Reports = {}
    MDT.Warrants = {}
    MDT.Notes = {}
    MDT.Bolos = {}
end

---Expose the MDT events for external resources.
function MDT.GetEvents()
    return {
        reportCreated = 'sandbox_bridge:server:mdt:reportCreated',
        reportUpdated = 'sandbox_bridge:server:mdt:reportUpdated',
        reportDeleted = 'sandbox_bridge:server:mdt:reportDeleted',
        warrantCreated = 'sandbox_bridge:server:mdt:warrantCreated',
        warrantUpdated = 'sandbox_bridge:server:mdt:warrantUpdated',
        warrantDeleted = 'sandbox_bridge:server:mdt:warrantDeleted',
        noteCreated = 'sandbox_bridge:server:mdt:noteCreated',
        noteDeleted = 'sandbox_bridge:server:mdt:noteDeleted',
        boloCreated = 'sandbox_bridge:server:mdt:boloCreated',
    }
end

-- ---------------------------------------------------------------------------
-- Net events (for MDT scripts/tablets that want to use the bridge data)
-- ---------------------------------------------------------------------------

local function Reply(src, requestId, data)
    TriggerClientEvent('sandbox_bridge:client:mdt:response', src, requestId, data)
end

RegisterNetEvent('sandbox_bridge:server:mdt:profile', function(requestId, identifier)
    Reply(source, requestId, MDT.GetProfile(identifier or source))
end)

RegisterNetEvent('sandbox_bridge:server:mdt:search', function(requestId, query, filters)
    Reply(source, requestId, MDT.Search(query, filters))
end)

RegisterNetEvent('sandbox_bridge:server:mdt:officers', function(requestId, filters)
    Reply(source, requestId, MDT.GetOfficers(filters))
end)

RegisterNetEvent('sandbox_bridge:server:mdt:calls', function(requestId, filters)
    Reply(source, requestId, MDT.GetCalls(filters))
end)

RegisterNetEvent('sandbox_bridge:server:mdt:stats', function(requestId)
    Reply(source, requestId, MDT.GetStats())
end)

return MDT
