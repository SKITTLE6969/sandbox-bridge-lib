--[[
    sandbox-bridge-lib / server/main.lua

    Loads the server bridge modules into one shared environment. This file is
    started directly by the sandbox-bridge-lib manifest.

    Module loading order is validated and documented below. Modules are loaded
    with pcall protection, dependency checks, and clear error messages.
]]

local RESOURCE_NAME = 'sandbox-bridge-lib'
local ENV = setmetatable({}, { __index = _G })

-- Track loaded modules for dependency validation
ENV._LOADED_MODULES = ENV._LOADED_MODULES or {}
local loadedModules = ENV._LOADED_MODULES

local function Include(modulePath)
    if loadedModules[modulePath] then
        print(('[sandbox-bridge] WARNING: module %s already loaded'):format(modulePath))
        return
    end

    local file = LoadResourceFile(RESOURCE_NAME, modulePath)
    if not file then
        error(("[sandbox-bridge] CRITICAL: missing server module '%s'. Check manifest and file exists."):format(modulePath))
    end

    local chunk, compileError = load(file, ('@@%s/%s'):format(RESOURCE_NAME, modulePath), 't', ENV)
    if not chunk then
        error(("[sandbox-bridge] CRITICAL: failed to compile '%s':\n%s"):format(modulePath, tostring(compileError)))
    end

    local ok, runtimeError = pcall(chunk)
    if not ok then
        error(("[sandbox-bridge] CRITICAL: failed to run '%s':\n%s"):format(modulePath, tostring(runtimeError)))
    end

    loadedModules[modulePath] = true
    if ENV.Config and ENV.Config.Debug then
        print(('[sandbox-bridge] Loaded server module: %s'):format(modulePath))
    end
end

-- Define load order with dependencies
local LOAD_ORDER = {
    { path = 'server/core.lua', deps = {} }, -- Core must load first - defines shared state/helpers
    { path = 'server/money.lua', deps = {'server/core.lua'} },
    { path = 'server/inventory.lua', deps = {'server/core.lua'} },
    { path = 'server/jobs.lua', deps = {'server/core.lua', 'server/money.lua'} },
    { path = 'server/playerdata.lua', deps = {'server/core.lua', 'server/jobs.lua', 'server/money.lua', 'server/inventory.lua'} },
    { path = 'server/offline.lua', deps = {'server/core.lua', 'server/playerdata.lua'} },
    { path = 'server/players.lua', deps = {'server/core.lua', 'server/playerdata.lua'} },
    { path = 'server/vehicles.lua', deps = {'server/core.lua'} },
    { path = 'server/qbcore.lua', deps = {'server/core.lua', 'server/playerdata.lua'} },
    { path = 'server/management.lua', deps = {'server/core.lua', 'server/jobs.lua'} },
    { path = 'server/persona_qbx.lua', deps = {'server/qbcore.lua', 'server/playerdata.lua'} },
    { path = 'server/persona_qbcore.lua', deps = {'server/qbcore.lua', 'server/playerdata.lua'} },
    { path = 'server/dispatch.lua', deps = {'server/core.lua'} },
    { path = 'server/mdt.lua', deps = {'server/core.lua', 'server/playerdata.lua'} },
    { path = 'server/compat.lua', deps = {'server/core.lua', 'server/dispatch.lua'} },
    { path = 'server/exports.lua', deps = {'server/persona_qbx.lua', 'server/persona_qbcore.lua', 'server/dispatch.lua', 'server/mdt.lua'} },
    { path = 'server/events.lua', deps = {'server/core.lua', 'server/playerdata.lua'} },
    { path = 'server/startup.lua', deps = {'server/core.lua', 'server/events.lua'} },
}

-- Load modules in order with dependency validation
for i = 1, #LOAD_ORDER do
    local module = LOAD_ORDER[i]
    -- Validate dependencies
    if module.deps then
        for j = 1, #module.deps do
            local dep = module.deps[j]
            if not loadedModules[dep] then
                error(("[sandbox-bridge] CRITICAL: module '%s' requires '%s' to be loaded first. Check LOAD_ORDER."):format(module.path, dep))
            end
        end
    end
    Include(module.path)
end

_G.SandboxBridge = ENV.SB
