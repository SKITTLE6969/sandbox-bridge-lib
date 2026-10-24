-- sandbox-bridge-lib/client/skills.lua
-- Loaded by client/main.lua in the shared bridge environment.
--
-- Client side of the Skills API. Levels live on the Sandbox character metadata
-- (managed by server/compat.lua); this module keeps a local cache so UI code can
-- read skill values without a round-trip on every frame.

SB = SB or {}

Skills = {}
SB.Skills = Skills

Skills.All = {}
Skills.Cache = {}
Skills.Stats = {}
Skills.Callbacks = {}
Skills.Sequence = 0

local function SkillsConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Skills) or {}
end

function Skills.GetResourceName()
    return 'sandbox'
end

function Skills.GetXPForLevel(level)
    level = tonumber(level) or 1
    if level <= 1 then return 0 end
    if not Skills.Stats[level] then
        local xp = 0
        for index = 1, level - 1 do
            xp = xp + math.floor(index + 300 * (2 ^ (index / 7)))
        end
        Skills.Stats[level] = math.floor(xp / 4)
    end
    return Skills.Stats[level]
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
    Skills.All[name] = {
        name = name,
        maxLevel = tonumber(maxLevel) or SkillsConfig().MaxLevel or 99,
        baseXP = tonumber(baseXP) or 50,
    }
    return Skills.All[name]
end

function Skills.GetDefinition(name)
    return Skills.All[name]
end

function Skills.GetDefinitions()
    return SandboxBridgeCompat.Copy(Skills.All)
end

---Read a cached skill (never blocks).
---@param name string
---@return table
function Skills.Get(name)
    local skill = Skills.Cache[name]
    if type(skill) ~= 'table' then skill = { currentXP = 0, level = 1 } end
    return SandboxBridgeCompat.Copy(skill)
end

function Skills.GetAll()
    return SandboxBridgeCompat.Copy(Skills.Cache)
end

function Skills.GetSkillLevel(name)
    return tonumber(Skills.Get(name).level) or 1
end

function Skills.GetXP(name)
    return tonumber(Skills.Get(name).currentXP) or 0
end

function Skills.GetProgress(name)
    local level = Skills.GetSkillLevel(name)
    local xp = Skills.GetXP(name)
    local required = Skills.GetXPRequiredForLevel(level + 1)
    return {
        name = name,
        level = level,
        xp = xp,
        required = required,
        percent = required > 0 and SandboxBridgeCompat.Round((xp / required) * 100, 1) or 0,
    }
end

---Request fresh skill data from the server.
---@param callback function|nil function(data)
---@param name string|nil include the progress for one skill
---@return string requestId
function Skills.Refresh(callback, name)
    Skills.Sequence = Skills.Sequence + 1
    local requestId = ('skills-%d-%d'):format(GetGameTimer(), Skills.Sequence)
    Skills.Callbacks[requestId] = callback
    TriggerServerEvent('sandbox_bridge:server:skills:get', requestId, name)
    return requestId
end

Skills.Request = Skills.Refresh

---Ask the server to add XP to a skill.
function Skills.AddXP(name, amount)
    TriggerServerEvent('sandbox_bridge:server:skills:add', name, amount)
end

Skills.AddXp = Skills.AddXP

RegisterNetEvent('sandbox_bridge:client:skills:response', function(requestId, data)
    if type(data) == 'table' and type(data.all) == 'table' then
        Skills.Cache = data.all
    end

    local callback = Skills.Callbacks[requestId]
    Skills.Callbacks[requestId] = nil
    if callback then callback(data) end

    TriggerEvent('sandbox_bridge:client:skills:updated', Skills.Cache, data)
end)

-- Prime the cache once the player has loaded.
CreateThread(function()
    Wait(2000)
    Skills.Refresh()
end)

return { Skills = Skills }
