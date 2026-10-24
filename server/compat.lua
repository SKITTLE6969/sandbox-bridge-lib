-- sandbox-bridge-lib/server/compat.lua
-- Loaded by server/main.lua in the shared bridge environment.
--
-- Server side adapters for Doorlock, VehicleKey and Skills. These are the
-- modules that need persistence or server-side resource exports; the remaining
-- compatibility modules live on the client.

local Compat = SandboxBridgeCompat

-- ---------------------------------------------------------------------------
-- Doorlock
-- ---------------------------------------------------------------------------

Doorlock = {}
SB.Doorlock = Doorlock

Doorlock.States = {}
Doorlock.Registered = {}

local function DoorlockConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Doorlock) or {}
end

function Doorlock.GetAvailableResources()
    return Compat.GetStarted(Compat.DoorlockResources)
end

function Doorlock.GetResourceName()
    local config = DoorlockConfig()
    if config.Enabled == false then return 'disabled' end
    local active = Compat.SelectConfigured(config, Compat.DoorlockResources)
    return active or 'default'
end

function Doorlock.GetBackend()
    return Doorlock.GetResourceName()
end

function Doorlock.IsAvailable()
    local backend = Doorlock.GetResourceName()
    return backend ~= 'default' and backend ~= 'disabled'
end

---Register a door so the fallback backend can track it.
function Doorlock.RegisterDoor(door)
    if type(door) ~= 'table' then return false end
    local id = door.id or door.name or door.door
    if id == nil then return false end
    Doorlock.Registered[tostring(id)] = door
    return true
end

function Doorlock.GetRegistered()
    return Compat.Copy(Doorlock.Registered)
end

---@param doorID string|number
---@param toggle boolean true = locked
---@return boolean
function Doorlock.ToggleDoorLock(doorID, toggle)
    if doorID == nil then return false end
    local backend = Doorlock.GetResourceName()
    local state = toggle == true
    local key = tostring(doorID)

    local delivered = false

    if backend == 'ox_doorlock' then
        delivered = Compat.SafeCall(function()
            exports.ox_doorlock:setDoorState(tonumber(doorID) or doorID, state and 1 or 0)
            return true
        end) == true
    elseif backend == 'qb-doorlock' then
        delivered = Compat.SafeCall(function()
            TriggerClientEvent('qb-doorlock:client:setState', -1, 0, doorID, state, false, false, false)
            return true
        end) == true
    elseif backend == 'rcore_doorlock' then
        delivered = Compat.SafeCall(function()
            exports.rcore_doorlock:changeDoorState(doorID, state and 0 or 1)
            return true
        end) == true
    elseif backend == 'doors_creator' then
        delivered = Compat.SafeCall(function()
            exports['doors_creator']:setDoorState(doorID, state and 1 or 0)
            return true
        end) == true
    elseif backend == 'jacksams-doorlock' then
        local attempts = {
            function() exports['jacksams-doorlock']:setDoorState(doorID, state and 1 or 0) end,
            function() exports['jacksams-doorlock']:SetDoorState(doorID, state) end,
            function() TriggerEvent('jacksams-doorlock:server:setDoorState', doorID, state) end,
        }
        for _, attempt in ipairs(attempts) do
            -- pcall, not SafeCall: a successful call may legitimately return nil.
            local ok = pcall(attempt)
            if ok then
                delivered = true
                break
            end
        end
    elseif backend == 'default' and DoorlockConfig().Fallback ~= false then
        -- Pure bridge fallback: keep state in memory so Sandbox scripts can
        -- implement their own door logic without an external resource.
        delivered = true
    end

    if delivered then
        Doorlock.States[key] = state
        TriggerEvent('sandbox_bridge:server:doorlock:state', doorID, state, backend)
    end
    return delivered
end

function Doorlock.SetDoorState(doorID, state)
    return Doorlock.ToggleDoorLock(doorID, state)
end

function Doorlock.UnlockDoor(doorID)
    return Doorlock.ToggleDoorLock(doorID, false)
end

function Doorlock.LockDoor(doorID)
    return Doorlock.ToggleDoorLock(doorID, true)
end

function Doorlock.IsLocked(doorID)
    local key = tostring(doorID)
    if Doorlock.States[key] ~= nil then return Doorlock.States[key] end

    if Doorlock.GetResourceName() == 'ox_doorlock' then
        local state = Compat.SafeCall(function()
            return exports.ox_doorlock:getDoorState(tonumber(doorID) or doorID)
        end)
        if state ~= nil then return state == 1 end
    end

    return nil
end

function Doorlock.GetDoorState(doorID)
    return Doorlock.IsLocked(doorID)
end

-- ---------------------------------------------------------------------------
-- Vehicle keys
-- ---------------------------------------------------------------------------

VehicleKey = {}
SB.VehicleKey = VehicleKey

local function VehicleKeyConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.VehicleKey) or {}
end

function VehicleKey.GetAvailableResources()
    return Compat.GetStarted(Compat.VehicleKeyResources)
end

function VehicleKey.GetResourceName()
    local config = VehicleKeyConfig()
    if config.Enabled == false then return 'disabled' end
    local active = Compat.SelectConfigured(config, Compat.VehicleKeyResources)
    return active or 'default'
end

function VehicleKey.GetBackend()
    return VehicleKey.GetResourceName()
end

function VehicleKey.IsAvailable()
    local backend = VehicleKey.GetResourceName()
    return backend ~= 'default' and backend ~= 'disabled'
end

---Ask a player's client to hand keys to itself. The client performs the actual
---resource specific call because most key resources expose client exports.
---@param src number
---@param plate string
---@param netId number|nil
function VehicleKey.GiveKeys(src, plate, netId)
    src = tonumber(src)
    if not src or type(plate) ~= 'string' then return false end
    TriggerClientEvent('sandbox_bridge:client:vehicleKeys:give', src, plate, netId)
    TriggerEvent('sandbox_bridge:server:vehiclekey:given', src, plate)
    return true
end

function VehicleKey.RemoveKeys(src, plate, netId)
    src = tonumber(src)
    if not src or type(plate) ~= 'string' then return false end
    TriggerClientEvent('sandbox_bridge:client:vehicleKeys:remove', src, plate, netId)
    TriggerEvent('sandbox_bridge:server:vehiclekey:removed', src, plate)
    return true
end

function VehicleKey.HasKeys(src, plate)
    -- Key resources do not expose a consistent ownership API. The bridge keeps
    -- the last successful request per player as a best-effort answer.
    VehicleKey.Keys = VehicleKey.Keys or {}
    local owned = VehicleKey.Keys[src]
    return owned ~= nil and owned[plate] == true
end

RegisterNetEvent('sandbox_bridge:server:vehicleKeys:given', function(plate)
    local src = source
    VehicleKey.Keys = VehicleKey.Keys or {}
    VehicleKey.Keys[src] = VehicleKey.Keys[src] or {}
    VehicleKey.Keys[src][tostring(plate)] = true
end)

RegisterNetEvent('sandbox_bridge:server:vehicleKeys:removed', function(plate)
    local src = source
    if VehicleKey.Keys and VehicleKey.Keys[src] then
        VehicleKey.Keys[src][tostring(plate)] = nil
    end
end)

-- ---------------------------------------------------------------------------
-- Clothing (server -> client relays)
-- ---------------------------------------------------------------------------

Clothing = {}
SB.Clothing = Clothing

---Apply appearance data to an online player. The client resolves the active
---clothing resource (or falls back to native ped components).
---@param src number
---@param data table
---@return boolean
function Clothing.SetAppearance(src, data)
    src = tonumber(src)
    if not src or type(data) ~= 'table' then return false end
    TriggerClientEvent('sandbox_bridge:client:clothing:set', src, data)
    return true
end

---Open the active clothing menu for an online player.
function Clothing.OpenMenu(src)
    src = tonumber(src)
    if not src then return false end
    TriggerClientEvent('sandbox_bridge:client:clothing:open', src)
    return true
end

---Restore the player's last stored appearance.
function Clothing.RestoreAppearance(src)
    src = tonumber(src)
    if not src then return false end
    TriggerClientEvent('sandbox_bridge:client:clothing:restore', src)
    return true
end

---Ask a player's client for its current appearance.
---@param src number
function Clothing.GetAppearance(src)
    src = tonumber(src)
    if not src then return false end
    TriggerClientEvent('sandbox_bridge:client:clothing:get', src, ('clothing-%d-%d'):format(src, os.time and os.time() or 0))
    return true
end

RegisterNetEvent('sandbox_bridge:server:clothing:response', function(requestId, data)
    TriggerEvent('sandbox_bridge:server:clothing:data', source, requestId, data)
end)

-- ---------------------------------------------------------------------------
-- Skills
-- ---------------------------------------------------------------------------

Skills = {}
SB.Skills = Skills

Skills.All = {}
Skills.Cache = {}

local function SkillsConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Skills) or {}
end

local function MetadataKey()
    return SkillsConfig().MetadataKey or 'community_bridge_skills'
end

function Skills.GetResourceName()
    return 'sandbox'
end

function Skills.GetXPForLevel(level)
    level = tonumber(level) or 1
    if level <= 1 then return 0 end

    if not Skills.Cache[level] then
        local xp = 0
        for index = 1, level - 1 do
            xp = xp + math.floor(index + 300 * (2 ^ (index / 7)))
        end
        Skills.Cache[level] = math.floor(xp / 4)
    end
    return Skills.Cache[level]
end

function Skills.GetXPRequiredForLevel(level)
    level = tonumber(level) or 1
    if level <= 1 then return 83 end
    return Skills.GetXPForLevel(level)
end

function Skills.GetScaledXP(baseXP, playerLevel)
    baseXP = tonumber(baseXP) or 50
    playerLevel = tonumber(playerLevel) or 1
    return math.floor(baseXP * (1 + playerLevel * 0.05))
end

function Skills.Create(name, maxLevel, baseXP)
    if type(name) ~= 'string' then return nil end
    local skill = {
        name = name,
        maxLevel = tonumber(maxLevel) or SkillsConfig().MaxLevel or 99,
        baseXP = tonumber(baseXP) or 50,
    }
    Skills.All[name] = skill
    return skill
end

function Skills.GetDefinition(name)
    return Skills.All[name]
end

function Skills.GetDefinitions()
    return Compat.Copy(Skills.All)
end

local function GetPlayerSkills(src, create)
    src = tonumber(src)
    if not src then return {} end

    local stored = SB.GetMetadata(src, MetadataKey())
    if type(stored) ~= 'table' then stored = {} end

    if create and stored then
        -- Ensure the metadata table is present for the first mutation.
    end
    return stored
end

local function SavePlayerSkills(src, skills)
    return SB.SetMetadata(src, MetadataKey(), skills)
end

local function GetSkill(src, name)
    local skills = GetPlayerSkills(src)
    local skill = skills[name]
    if type(skill) ~= 'table' then
        skill = { currentXP = 0, level = 1 }
    end
    return skill, skills
end

function Skills.Get(src, name)
    local skill = GetSkill(src, name)
    return Compat.Copy(skill)
end

function Skills.GetAll(src)
    return Compat.Copy(GetPlayerSkills(src))
end

function Skills.GetSkillLevel(src, name)
    local skill = GetSkill(src, name)
    return tonumber(skill.level) or 1
end

function Skills.GetXP(src, name)
    local skill = GetSkill(src, name)
    return tonumber(skill.currentXP) or 0
end

function Skills.GetProgress(src, name)
    local level = Skills.GetSkillLevel(src, name)
    local xp = Skills.GetXP(src, name)
    local needed = Skills.GetXPRequiredForLevel(level + 1)
    return {
        name = name,
        level = level,
        xp = xp,
        required = needed,
        percent = needed > 0 and Compat.Round((xp / needed) * 100, 1) or 0,
    }
end

function Skills.AddXP(src, name, amount)
    if type(name) ~= 'string' then return false, 1, 0 end

    local skill, skills = GetSkill(src, name)
    local level = tonumber(skill.level) or 1
    local current = tonumber(skill.currentXP) or 0
    amount = tonumber(amount) or Skills.GetScaledXP(50, level)
    if amount <= 0 then return false, level, current end

    local maxLevel = (Skills.All[name] and Skills.All[name].maxLevel)
        or SkillsConfig().MaxLevel
        or 99

    current = current + amount
    local required = Skills.GetXPRequiredForLevel(level + 1)
    while current >= required and level < maxLevel do
        current = current - required
        level = level + 1
        required = Skills.GetXPRequiredForLevel(level + 1)
    end

    if level >= maxLevel then
        level = maxLevel
        current = 0
    end

    skill.level = level
    skill.currentXP = current
    skills[name] = skill
    SavePlayerSkills(src, skills)

    TriggerEvent('sandbox_bridge:server:skills:changed', src, name, level, current)
    return true, level, current
end

function Skills.RemoveXP(src, name, amount)
    if type(name) ~= 'string' then return false, 1, 0 end

    local skill, skills = GetSkill(src, name)
    local level = tonumber(skill.level) or 1
    local current = (tonumber(skill.currentXP) or 0) - (tonumber(amount) or 0)

    while current < 0 and level > 1 do
        level = level - 1
        current = current + Skills.GetXPRequiredForLevel(level + 1)
    end
    if current < 0 then current = 0 end

    skill.level = level
    skill.currentXP = current
    skills[name] = skill
    SavePlayerSkills(src, skills)

    TriggerEvent('sandbox_bridge:server:skills:changed', src, name, level, current)
    return true, level, current
end

function Skills.SetSkillLevel(src, name, level)
    if type(name) ~= 'string' then return false end
    level = Compat.Clamp(level, 1, Skills.All[name] and Skills.All[name].maxLevel or SkillsConfig().MaxLevel or 99)

    local skill, skills = GetSkill(src, name)
    skill.level = math.floor(level)
    skill.currentXP = 0
    skills[name] = skill
    SavePlayerSkills(src, skills)

    TriggerEvent('sandbox_bridge:server:skills:changed', src, name, skill.level, 0)
    return true
end

function Skills.SetXP(src, name, xp)
    if type(name) ~= 'string' then return false end
    local skill, skills = GetSkill(src, name)
    skill.currentXP = math.max(0, tonumber(xp) or 0)
    skills[name] = skill
    SavePlayerSkills(src, skills)
    TriggerEvent('sandbox_bridge:server:skills:changed', src, name, skill.level or 1, skill.currentXP)
    return true
end

function Skills.Reset(src, name)
    local skills = GetPlayerSkills(src)
    if name then
        skills[name] = nil
    else
        skills = {}
    end
    SavePlayerSkills(src, skills)
    return true
end

function Skills.IsMaxLevel(src, name)
    local maxLevel = Skills.All[name] and Skills.All[name].maxLevel
        or SkillsConfig().MaxLevel
        or 99
    return Skills.GetSkillLevel(src, name) >= maxLevel
end

RegisterNetEvent('sandbox_bridge:server:skills:add', function(name, amount)
    if not tonumber(source) then return end
    Skills.AddXP(source, name, amount)
end)

RegisterNetEvent('sandbox_bridge:server:skills:get', function(requestId, name)
    TriggerClientEvent('sandbox_bridge:client:skills:response', source, requestId, {
        all = Skills.GetAll(source),
        progress = name and Skills.GetProgress(source, name) or nil,
    })
end)

-- ---------------------------------------------------------------------------
-- Integration audit
-- ---------------------------------------------------------------------------
-- Large compatibility surface means many optional resources and exports. This
-- audit probes every module plus the core resource dependencies so a broken
-- integration is visible instead of silently falling back.

function SB.Audit()
    local config = SandboxBridgeConfig or {}
    local report = Compat.AuditAll({
        Dispatch = { catalogue = Compat.DispatchResources, config = config.Dispatch, exclusions = config.Dispatch and config.Dispatch.Exclusions },
        MDT = { catalogue = Compat.MDTResources, config = config.MDT },
        Target = { catalogue = Compat.TargetResources, config = config.Target },
        Doorlock = { catalogue = Compat.DoorlockResources, config = config.Doorlock },
        VehicleKey = { catalogue = Compat.VehicleKeyResources, config = config.VehicleKey },
        Fuel = { catalogue = Compat.FuelResources, config = config.Fuel },
        Clothing = { catalogue = Compat.ClothingResources, config = config.Clothing },
        ProgressBar = { catalogue = Compat.ProgressBarResources, config = config.ProgressBar },
        Notify = { catalogue = Compat.NotifyResources, config = config.Notify },
        Weather = { catalogue = Compat.WeatherResources, config = config.Weather },
    })

    report.dependencies = {}
    local required = { 'sandbox-base', 'sandbox-characters', 'sandbox-jobs', 'sandbox-status', 'ox_inventory', 'oxmysql', 'ox_lib' }
    for _, resource in ipairs(required) do
        local state = GetResourceState(resource)
        report.dependencies[resource] = state
        if state ~= 'started' then
            report.problems[#report.problems + 1] = ('dependency %s is %s'):format(resource, tostring(state))
        end
    end

    report.optional = {}
    local optional = { 'Renewed-Banking' }
    for _, resource in ipairs(optional) do
        local state = GetResourceState(resource)
        report.optional[resource] = state
        if state ~= 'started' then
            report.problems[#report.problems + 1] = ('optional dependency %s is %s (bank operations may not persist)'):format(resource, tostring(state))
        end
    end

    return report
end

function SB.PrintAudit()
    local report = SB.Audit()
    print('[sandbox-bridge] ===== integration audit =====')
    for label, entry in pairs(report.modules) do
        print(('[sandbox-bridge] %-12s selected=%s started=%d/%d'):format(
            label, tostring(entry.selected), #entry.started, entry.supported))
    end
    for _, problem in ipairs(report.problems) do
        print(('[sandbox-bridge] PROBLEM: %s'):format(problem))
    end
    print(('[sandbox-bridge] ===== %d problem(s) ====='):format(#report.problems))
    return report
end

return {
    Doorlock = Doorlock,
    VehicleKey = VehicleKey,
    Clothing = Clothing,
    Skills = Skills,
}
