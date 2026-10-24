-- sandbox-bridge-lib/client/core.lua
-- Loaded by client/main.lua in the shared bridge environment.

--[[
    sandbox-bridge-lib / client/core.lua

    Client side of the Sandbox -> QBCore / QBX compatibility layer.
    This resource provides both qb-core and qbx_core from one runtime.
]]

RESOURCE = GetCurrentResourceName()
Config = SandboxBridgeConfig or {}
Util = SandboxBridgeUtil

PERSONA = 'qbx_core'

function IsPrimaryQB()
    return true
end

function IsPrimaryBridge()
    return true
end

function Started(resource)
    return GetResourceState(resource) == 'started'
end

function Debug(...)
    if Config.Debug then
        print(('[sandbox-bridge:%s]'):format(RESOURCE), ...)
    end
end

function SafeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        Debug(('protected call failed: %s'):format(tostring(result)))
        return nil
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Local caches
-- ---------------------------------------------------------------------------

Cache = {
    data = nil,
    bank = 0,
    jobTypes = {},
    gangJobs = {},
    lastJobSignature = nil,
    lastRefresh = 0,
}

QBCore = {
    Shared = {
        Jobs = {},
        Gangs = {},
        Items = {},
        Vehicles = {},
        Weapons = {},
        Locations = {},
    },
    Functions = {},
    Commands = {},
    Config = {},
}

function DecodeFlags(flags)
    if flags == nil then
        return {}
    end
    if type(flags) == 'table' then
        local copy = {}
        for k, v in pairs(flags) do
            copy[k] = v
        end
        return copy
    elseif type(flags) == 'string' and flags ~= '' then
        if json and json.decode then
            local ok, decoded = pcall(json.decode, flags)
            if ok and type(decoded) == 'table' then
                return decoded
            end
            if Config and Config.Debug then
                Debug(('Failed to decode flags JSON: %s'):format(tostring(decoded)))
            end
        elseif Config and Config.Debug then
            Debug('json.decode not available, flags decoding failed')
        end
    elseif type(flags) == 'string' and flags == '' then
        return {}
    end
    return {}
end

function GetNationality(origin)
    if type(origin) == 'table' then
        return origin.label or origin.name or origin.nationality or origin.code or 'San Andreas'
    end
    return type(origin) == 'string' and origin or 'San Andreas'
end

CLIENT_LICENSE_FIELDS = {
    driver = 'Drivers',
    weapon = 'Weapons',
    hunting = 'Hunting',
    fishing = 'Fishing',
    pilot = 'Pilot',
    drift = 'Drift',
}

function ConvertLicensesToQbox(licenses)
    local result = { id = true }
    licenses = type(licenses) == 'table' and licenses or {}

    for qbKey, sandboxKey in pairs(CLIENT_LICENSE_FIELDS) do
        local value = licenses[sandboxKey]
        result[qbKey] = type(value) == 'table' and value.Active == true or false
    end

    return result
end

function GetGroupMapsFromAssignments(assignments)
    local jobs, gangs = {}, {}
    for _, assignment in ipairs(assignments or {}) do
        local level = assignment.Grade and tonumber(assignment.Grade.Level) or 0
        if Cache.gangJobs[assignment.Id] then
            gangs[assignment.Id] = level
        else
            jobs[assignment.Id] = level
        end
    end
    return jobs, gangs
end

