-- sandbox-bridge-lib/server/core.lua
-- Loaded by server/main.lua in the shared bridge environment.

--[[
    sandbox-bridge-lib / server/core.lua

    Exposes QBCore and QBX compatible server APIs on top of the Sandbox
    Framework exports. This resource provides both qb-core and qbx_core, so it
    registers both persona API surfaces from a single runtime.
]]

RESOURCE = GetCurrentResourceName()
Config = SandboxBridgeConfig or {}
Util = SandboxBridgeUtil

-- BuildClientSnapshot is defined in server/events.lua.

SB = {}
SandboxBridge = SB

PERSONA = 'qbx_core'

function IsPrimaryQB()
    return true
end

function IsPrimaryBridge()
    return true
end

function Debug(...)
    if Config.Debug then
        print(('[sandbox-bridge:%s]'):format(RESOURCE), ...)
    end
end

function Started(resource)
    return GetResourceState(resource) == 'started'
end

function SafeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        Debug(('protected call failed: %s'):format(tostring(result)))
        return nil
    end
    return result
end

function GetCharacter(src)
    src = tonumber(src)
    if not src or src <= 0 or not Started('sandbox-characters') then return nil end
    return SafeCall(function()
        return exports['sandbox-characters']:FetchCharacterSource(src)
    end)
end

function GetStateId(src)
    local char = GetCharacter(src)
    if not char then return nil end
    return char:GetData('SID')
end

function GetAccountPlayer(src)
    if not Started('sandbox-base') then return nil end
    return SafeCall(function()
        return exports['sandbox-base']:GetPlayer(src)
    end)
end

---Sandbox stores the `Flags` column as JSON text (it is not in the
---TablesToDecode list), so decode it manually wherever we read it.
---Improved with better error handling, nil safety, and fallback support.
---@param flags any
---@return table
function DecodeFlags(flags)
    if flags == nil then
        return {}
    end
    if type(flags) == 'table' then
        -- Return a shallow copy to prevent mutation issues
        local copy = {}
        for k, v in pairs(flags) do
            copy[k] = v
        end
        return copy
    elseif type(flags) == 'string' and flags ~= '' then
        -- Try to decode JSON
        if json and json.decode then
            local ok, decoded = pcall(json.decode, flags)
            if ok and type(decoded) == 'table' then
                return decoded
            end
            if Config and Config.Debug then
                Debug(('Failed to decode flags JSON: %s'):format(tostring(decoded)))
            end
        else
            -- Fallback if json not available
            if Config and Config.Debug then
                Debug('json.decode not available, flags decoding failed')
            end
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

-- ---------------------------------------------------------------------------
-- Shared caches
-- ---------------------------------------------------------------------------

bankCache = {}
jobCache = { data = nil, time = 0 }
playerObjectCache = {}
loadedPlayers = {}
unloadingPlayers = {}
identityCache = {}
jobsOverlay = {}
gangsOverlay = {}
useableItems = {}
playerBuckets = {}
entityBuckets = {}

IDENTITY_FIELDS = {
    'First', 'Last', 'Phone', 'DOB', 'Gender', 'License', 'SID', 'Origin', 'Callsign', 'Bio',
}

function CacheIdentity(src, char)
    if not char then return end
    local previous = identityCache[src] or {}
    local identity = {}

    for _, field in ipairs(IDENTITY_FIELDS) do
        identity[field] = char:GetData(field) or previous[field]
    end

    identityCache[src] = identity
end

function GetIdentity(src)
    return identityCache[src] or {}
end

function GetJobDefinitions()
    local now = os.time()
    if jobCache.data and (now - jobCache.time) < 5 then
        return jobCache.data
    end

    local jobs = SafeCall(function()
        return exports['sandbox-jobs']:GetAll()
    end)

    if type(jobs) ~= 'table' then jobs = {} end
    jobCache.data = jobs
    jobCache.time = now
    return jobs
end

---Runtime jobs created through qbx_core:CreateJob / CreateJobs.
---@return table
function GetRuntimeJobs()
    local jobs = {}
    for name, definition in pairs(GetJobDefinitions()) do
        jobs[name] = definition
    end
    for name, definition in pairs(jobsOverlay) do
        jobs[name] = definition
    end
    for name, definition in pairs(gangsOverlay) do
        jobs[name] = jobs[name] or definition
    end
    return jobs
end

---Gangs are Sandbox jobs tagged through SandboxBridgeConfig.GangJobs
---or through a `Gang` field / Gang type on the job definition.
---@return table
function GetGangDefinitions()
    local gangs = {}
    for name, definition in pairs(GetRuntimeJobs()) do
        if (Config.GangJobs and Config.GangJobs[name]) or definition.Gang or definition.Type == 'Gang' then
            gangs[name] = definition
        end
    end
    for name, definition in pairs(gangsOverlay) do
        gangs[name] = definition
    end
    return gangs
end

function GetBankAccount(src, refresh)
    local stateId = GetStateId(src)
    if not stateId then
        Debug(('GetBankAccount: no stateId for src %s'):format(tostring(src)))
        return nil
    end

    local cached = bankCache[src]
    if not refresh and cached and cached.account ~= nil and (os.time() - cached.time) < (Config.BankCacheSeconds or 10) then
        return cached.account
    end

    local account = nil
    if Started('Renewed-Banking') then
        account = SafeCall(function()
            return exports['Renewed-Banking']:AccountsGetPersonal(stateId)
        end)
    elseif Config and Config.Debug then
        Debug('Renewed-Banking not started, cannot fetch bank account')
    end

    bankCache[src] = {
        account = account,
        time = os.time(),
    }

    return account
end

function EnsureBankAccount(src)
    local stateId = GetStateId(src)
    if not stateId then return nil end

    local account = GetBankAccount(src, true)
    if account then return account end

    if Started('Renewed-Banking') and exports['Renewed-Banking'].AccountsCreatePersonal then
        local created = SafeCall(function()
            return exports['Renewed-Banking']:AccountsCreatePersonal(stateId)
        end)
        if created then
            StoreBankAccount(src, created)
            if Config and Config.Debug then
                Debug(('Created personal bank account for %s (%s)'):format(tostring(src), tostring(stateId)))
            end
            return created
        end
    end

    return nil
end

function StoreBankAccount(src, account)
    if account then
        bankCache[src] = { account = account, time = os.time() }
    else
        bankCache[src] = nil
    end
end
