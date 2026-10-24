--[[
    sandbox-bridge-lib / shared/compat.lua

    Shared helpers for the compatibility modules (Dispatch, MDT, Target,
    Doorlock, VehicleKey, Fuel, Clothing, ProgressBar, Notify, Weather,
    Skills and the developer tools).

    Everything in this file must stay side agnostic: it is loaded by both the
    client and the server bridge environment.
]]

SandboxBridgeCompat = SandboxBridgeCompat or {}

local Compat = SandboxBridgeCompat

-- ---------------------------------------------------------------------------
-- Resource catalogues
-- ---------------------------------------------------------------------------

-- Dispatch/MDT resources in the order the bridge prefers them. The active
-- resource is still selected with SandboxBridgeConfig.Dispatch.Priority; this
-- list is used as the default and by GetAvailableBackends.
Compat.DispatchResources = {
    'ps-dispatch',
    'cd_dispatch',
    'lb-tablet',
    'bub-mdt',
    'qs-dispatch',
    'tk_dispatch',
    'wasabi_mdt',
    'kartik-mdt',
    'redutzu-mdt',
    'fd_dispatch',
    'origen_police',
    'piotreq_gpt',
    'linden_outlawalert',
    'emergencydispatch',
}

Compat.MDTResources = {
    'lb-tablet',
    'bub-mdt',
    'wasabi_mdt',
    'redutzu-mdt',
    'kartik-mdt',
    'ps-mdt',
    'cd_mdt',
    'tk_mdt',
}

Compat.TargetResources = {
    'ox_target',
    'qb-target',
    'sleepless_interact',
}

Compat.DoorlockResources = {
    'ox_doorlock',
    'qb-doorlock',
    'rcore_doorlock',
    'jacksams-doorlock',
    'doors_creator',
}

Compat.VehicleKeyResources = {
    'qbx_vehiclekeys',
    'qb-vehiclekeys',
    'qs-vehiclekeys',
    'Renewed-Vehiclekeys',
    'wasabi_carlock',
    'mk_vehiclekeys',
    'MrNewbVehicleKeys',
    'okokGarage',
    'mVehicle',
    'jaksams_VehiclesKeys',
    'F_RealCarKeysSystem',
    't1ger_keys',
    'cd_garage',
}

Compat.FuelResources = {
    'ox_fuel',
    'ps-fuel',
    'LegacyFuel',
    'cdn-fuel',
    'qb-fuel',
    'qs-fuelstations',
    'Renewed-Fuel',
    'lc_fuel',
    'ti_fuel',
    'x-fuel',
    'esx-sna-fuel',
    'okokGasStation',
    'BigDaddy-Fuel',
}

Compat.ClothingResources = {
    'illenium-appearance',
    'fivem-appearance',
    'rcore_clothing',
    'qb-clothing',
    'esx_skin',
}

Compat.ProgressBarResources = {
    'ox_lib',
    'progressbar',
    'keep-progressbar',
    'lation_ui',
    'wasabi_uikit',
    'ZSX_UIV2',
    'msk_core',
}

Compat.NotifyResources = {
    'ox_lib',
    'wasabi_notify',
    'okokNotify',
    'lation_ui',
    'mythic_notify',
    'pNotify',
    't-notify',
    'r_notify',
    'brutal_notify',
    'solaire_notify',
    'FL-Notify',
    'msk_core',
    'ZSX_UIV2',
}

Compat.ResourceAliases['fl-notify'] = 'FL-Notify'

Compat.WeatherResources = {
    'sandbox-weather',
    'qb-weathersync',
    'cd_easytime',
    'Renewed-Weathersync',
}

-- Some resources are published with more than one spelling. Keep a map from
-- the alternate name to the resource name used by the adapters.
Compat.ResourceAliases = {
    ['bub_mdt'] = 'bub-mdt',
    ['bubmdt'] = 'bub-mdt',
    ['wasabi-mdt'] = 'wasabi_mdt',
    ['wasabimdt'] = 'wasabi_mdt',
    ['legacyfuel'] = 'LegacyFuel',
    ['renewed-vehiclekeys'] = 'Renewed-Vehiclekeys',
    ['renewed-fuel'] = 'Renewed-Fuel',
    ['renewed-weathersync'] = 'Renewed-Weathersync',
    ['jacksams_doorlock'] = 'jacksams-doorlock',
    ['jacksams-vehiclekeys'] = 'jaksams_VehiclesKeys',
    ['jaksams-vehiclekeys'] = 'jaksams_VehiclesKeys',
}

-- ---------------------------------------------------------------------------
-- Generic helpers
-- ---------------------------------------------------------------------------

function Compat.Copy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, entry in pairs(value) do
        copy[key] = Compat.Copy(entry)
    end
    return copy
end

function Compat.Trim(value)
    return (tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

function Compat.Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function Compat.Round(value, decimals)
    local mult = 10 ^ (tonumber(decimals) or 0)
    return math.floor((tonumber(value) or 0) * mult + 0.5) / mult
end

function Compat.SafeCall(callback, ...)
    local ok, result = pcall(callback, ...)
    if not ok then
        if SandboxBridgeConfig and SandboxBridgeConfig.Debug then
            print(('[sandbox-bridge] protected call failed: %s'):format(tostring(result)))
        end
        return nil
    end
    return result
end

function Compat.IsStarted(resource)
    if type(resource) ~= 'string' or resource == '' then return false end
    return GetResourceState(resource) == 'started'
end

---Check whether a value exists in an array (or is a truthy key in a map).
function Compat.TableContains(tbl, value)
    if type(tbl) ~= 'table' then return false end
    if tbl[value] then return true end
    for _, entry in pairs(tbl) do
        if entry == value then return true end
    end
    return false
end

function Compat.ResolveResourceName(resource)
    if type(resource) ~= 'string' then return resource end
    return Compat.ResourceAliases[resource] or resource
end

---Return a stable, de-duplicated list of started resources from a catalogue.
---@param catalogue table
---@return table
function Compat.GetStarted(catalogue)
    local started = {}
    for _, resource in ipairs(catalogue or {}) do
        if Compat.IsStarted(resource) then
            started[#started + 1] = resource
        end
    end
    return started
end

---Pick the first started resource from `priority`.
---@param priority table
---@param exclusions table|nil  Map of resource -> { conflictingResource = true }
---@return string|nil
function Compat.SelectResource(priority, exclusions)
    for _, resource in ipairs(priority or {}) do
        resource = Compat.ResolveResourceName(resource)
        local blocked = false
        local conflicts = exclusions and exclusions[resource]
        if conflicts then
            for conflict in pairs(conflicts) do
                if Compat.IsStarted(conflict) then
                    blocked = true
                    break
                end
            end
        end

        if not blocked and Compat.IsStarted(resource) then
            return resource
        end
    end
    return nil
end

---Audit a compatibility module against its catalogue. Reports every supported
---resource, which ones are started, and which one the bridge would select.
---This turns an opaque integration failure into a readable diagnostic.
---@param label string
---@param catalogue table
---@param config table|nil
---@param exclusions table|nil
---@return table
function Compat.AuditModule(label, catalogue, config, exclusions)
    config = config or {}
    local started, missing = {}, {}
    for _, resource in ipairs(catalogue or {}) do
        if Compat.IsStarted(resource) then
            started[#started + 1] = resource
        else
            missing[#missing + 1] = resource
        end
    end

    local selected
    if config.Enabled == false then
        selected = 'disabled'
    else
        selected = Compat.SelectConfigured(config, catalogue, exclusions) or 'fallback'
    end

    return {
        module = label,
        enabled = config.Enabled ~= false,
        forced = config.Force,
        selected = selected,
        started = started,
        missing = missing,
        supported = #(catalogue or {}),
    }
end

---Run AuditModule over a map of module name -> {catalogue, config, exclusions}.
---@param modules table
---@return table
function Compat.AuditAll(modules)
    local report = { modules = {}, problems = {} }
    for label, spec in pairs(modules or {}) do
        local entry = Compat.AuditModule(label, spec.catalogue, spec.config, spec.exclusions)
        report.modules[label] = entry
        if entry.enabled and entry.selected == 'fallback' and #entry.started == 0 then
            report.problems[#report.problems + 1] = ('%s: no supported resource started, using fallback'):format(label)
        end
        if spec.config and spec.config.Force and not Compat.IsStarted(Compat.ResolveResourceName(spec.config.Force)) then
            report.problems[#report.problems + 1] = ('%s: forced resource %s is not started'):format(label, tostring(spec.config.Force))
        end
    end
    return report
end

---Return the first configured value that is a started resource. This lets an
---administrator force a resource through `Config.*.Force`.
---@param config table|nil
---@param catalogue table
---@param exclusions table|nil
---@return string|nil
function Compat.SelectConfigured(config, catalogue, exclusions)
    config = config or {}
    if config.Disabled then return nil end

    if type(config.Force) == 'string' and config.Force ~= '' then
        local forced = Compat.ResolveResourceName(config.Force)
        if Compat.IsStarted(forced) then return forced end
    end

    local priority = config.Priority
    if type(priority) ~= 'table' or #priority == 0 then priority = catalogue end
    return Compat.SelectResource(priority, exclusions)
end

-- ---------------------------------------------------------------------------
-- Coordinates / vectors
-- ---------------------------------------------------------------------------

---Convert coordinates of any common shape into a vector3/table.
---@param value any
---@param fallback any
---@return any
function Compat.ToCoords(value, fallback)
    if type(value) == 'vector3' or type(value) == 'vector4' then return value end

    if type(value) == 'table' then
        local x = tonumber(value.x or value[1])
        local y = tonumber(value.y or value[2])
        local z = tonumber(value.z or value[3])
        if x and y and z then
            if vector3 then return vector3(x, y, z) end
            return { x = x, y = y, z = z }
        end
    end

    return fallback
end

---Return a plain {x,y,z} table (safe for JSON and MySQL).
---@param value any
---@return table|nil
function Compat.ToCoordTable(value)
    local coords = Compat.ToCoords(value)
    if not coords then return nil end
    return {
        x = tonumber(coords.x) or 0.0,
        y = tonumber(coords.y) or 0.0,
        z = tonumber(coords.z) or 0.0,
    }
end

function Compat.Distance(a, b)
    local first = Compat.ToCoords(a)
    local second = Compat.ToCoords(b)
    if not first or not second then return 0.0 end
    local dx = (first.x or 0) - (second.x or 0)
    local dy = (first.y or 0) - (second.y or 0)
    local dz = (first.z or 0) - (second.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---Street/zone lookup. Only available on the client.
---@param coords any
---@return string|nil street
---@return string|nil zone
function Compat.GetStreetName(coords)
    coords = Compat.ToCoords(coords)
    if not coords then return nil, nil end
    if type(GetStreetNameAtCoord) ~= 'function' then return nil, nil end

    local mainHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local main = mainHash and GetStreetNameFromHashKey(mainHash) or nil
    local cross = crossHash and GetStreetNameFromHashKey(crossHash) or nil
    local street = main
    if cross and cross ~= '' and cross ~= main then
        street = ('%s / %s'):format(main or '', cross)
    end
    if type(GetNameOfZone) == 'function' then
        return street, GetNameOfZone(coords.x, coords.y, coords.z)
    end
    return street, nil
end

-- ---------------------------------------------------------------------------
-- Dispatch alert normalisation
-- ---------------------------------------------------------------------------

---Normalise the job input used by every dispatch/MDT resource.
---@param jobs any
---@param fallback table|string|nil
---@return table
function Compat.NormalizeJobs(jobs, fallback)
    if type(jobs) == 'string' then jobs = { jobs } end
    if type(jobs) ~= 'table' then jobs = fallback end
    if type(jobs) == 'string' then jobs = { jobs } end

    local result, seen = {}, {}
    if type(jobs) == 'table' then
        -- Array form: { 'police', 'ambulance' }
        for _, value in ipairs(jobs) do
            if type(value) == 'string' and value ~= '' and not seen[value] then
                seen[value] = true
                result[#result + 1] = value
            end
        end

        -- Boolean map form: { police = true, ambulance = true }
        for key, value in pairs(jobs) do
            if type(key) == 'string' and type(value) ~= 'number'
                and not seen[key] and (value == true or value == 1)
            then
                seen[key] = true
                result[#result + 1] = key
            end
        end
    end

    if #result == 0 then
        local defaults = SandboxBridgeConfig.Dispatch and SandboxBridgeConfig.Dispatch.DefaultJobs
        if type(defaults) == 'string' then defaults = { defaults } end
        for _, job in ipairs(defaults or { 'police' }) do
            if type(job) == 'string' and not seen[job] then
                seen[job] = true
                result[#result + 1] = job
            end
        end
    end

    return result
end

local function readFirst(source, keys)
    if type(source) ~= 'table' then return nil end
    for _, key in ipairs(keys) do
        if source[key] ~= nil then return source[key] end
    end
    return nil
end

---@param value any
---@param default number
---@return number
function Compat.NormalizePriority(value, default)
    value = tonumber(value) or default or 2
    if value < 1 then value = 1 end
    if value > 5 then value = 5 end
    return value
end

---Build one alert object accepted by every backend.
---@param data table|string
---@param source number|nil
---@return table
function Compat.NormalizeAlert(data, source)
    if type(data) == 'string' then data = { message = data } end
    if type(data) ~= 'table' then data = {} end

    local dispatchConfig = SandboxBridgeConfig.Dispatch or {}
    local blip = readFirst(data, { 'blipData', 'blip', 'blipDataTable' })
    if type(blip) ~= 'table' then blip = {} end

    local defaults = dispatchConfig.DefaultBlip or {}
    local coords = Compat.ToCoords(
        readFirst(data, { 'coords', 'location', 'callLocation', 'position' }),
        nil
    )

    if not coords and source and type(GetEntityCoords) == 'function' then
        local ped = GetPlayerPed(source)
        if ped and ped > 0 then coords = GetEntityCoords(ped) end
    end

    local jobs = Compat.NormalizeJobs(
        readFirst(data, { 'jobs', 'job', 'jobTable', 'groups' }),
        dispatchConfig.DefaultJobs or { 'police' }
    )

    local message = readFirst(data, { 'message', 'description', 'title', 'text', 'offense' })
    message = Compat.Trim(message)
    if message == '' then message = 'Dispatch alert' end
    local title = Compat.Trim(readFirst(data, { 'title', 'subject' }))
    if title == '' then title = message end

    local code = tostring(readFirst(data, { 'code', 'callCode', 'type' }) or '10-80')
    local icon = tostring(readFirst(data, { 'icon' }) or 'fas fa-question')
    local time = tonumber(readFirst(data, { 'time', 'duration', 'alertTime', 'length' }))
        or dispatchConfig.DefaultTime
        or 30000
    if time > 0 and time < 1000 then time = time * 1000 end

    local vehicle = data.vehicle
    if type(vehicle) == 'table' then
        vehicle = {
            model = vehicle.model or vehicle.name,
            plate = vehicle.plate,
            color = vehicle.color or vehicle.colour,
            speed = vehicle.speed,
        }
    elseif vehicle ~= nil then
        vehicle = { entity = vehicle, plate = data.plate }
    end

    local alert = {
        id = data.id,
        source = tonumber(source or data.source),
        code = code,
        title = title,
        message = message,
        description = Compat.Trim(readFirst(data, { 'description' })) ~= ''
            and Compat.Trim(data.description) or message,
        icon = icon,
        priority = Compat.NormalizePriority(
            readFirst(data, { 'priority', 'severity' }),
            dispatchConfig.DefaultPriority
        ),
        jobs = jobs,
        job = jobs[1],
        coords = coords or Compat.ToCoords(dispatchConfig.DefaultCoords, vector3 and vector3(0.0, 0.0, 0.0) or { x = 0, y = 0, z = 0 }),
        vehicle = vehicle,
        blip = {
            sprite = tonumber(blip.sprite or blip.icon) or tonumber(defaults.sprite) or 161,
            color = tonumber(blip.color or blip.colour) or tonumber(defaults.color) or 1,
            scale = tonumber(blip.scale) or tonumber(defaults.scale) or 0.8,
            radius = tonumber(blip.radius) or tonumber(defaults.radius) or 0.0,
            flash = blip.flash == true or blip.flashes == true or defaults.flash == true,
            time = tonumber(blip.time) or time,
        },
        time = time,
        metadata = type(data.metadata) == 'table' and data.metadata or {},
        raw = data,
        createdAt = os.time and os.time() or 0,
    }

    local street, zone = Compat.GetStreetName(alert.coords)
    alert.street = data.street or street
    alert.zone = data.zone or zone
    alert.location = {
        label = alert.street or alert.zone or 'Unknown location',
        street = alert.street,
        zone = alert.zone,
        coords = alert.coords,
    }

    return alert
end

---Return a human readable priority used by tablet/MDT resources.
function Compat.PriorityLabel(priority)
    priority = Compat.NormalizePriority(priority, 2)
    if priority == 1 then return 'low' end
    if priority >= 4 then return 'high' end
    return 'medium'
end

---Convert a priority number to the 1-3 range used by ps-dispatch.
function Compat.PriorityNumber(priority)
    priority = Compat.NormalizePriority(priority, 2)
    if priority == 1 then return 1 end
    if priority >= 4 then return 3 end
    return 2
end

-- ---------------------------------------------------------------------------
-- Search helpers (MDT)
-- ---------------------------------------------------------------------------

---Case-insensitive substring test used by MDT search.
function Compat.Matches(value, query)
    if query == nil or query == '' then return true end
    return tostring(value or ''):lower():find(tostring(query):lower(), 1, true) ~= nil
end

---Safe sort helper used by MDT lists.
function Compat.SortByCreatedAt(list, descending)
    table.sort(list or {}, function(a, b)
        local first = tonumber(a and (a.createdAt or a.updatedAt or a.time)) or 0
        local second = tonumber(b and (b.createdAt or b.updatedAt or b.time)) or 0
        if descending then return first > second end
        return first < second
    end)
    return list
end

return Compat
