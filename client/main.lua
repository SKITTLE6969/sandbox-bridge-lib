--[[
    sandbox-bridge-lib / client/main.lua

    Loads the client bridge modules into one shared environment. This file is
    started directly by the sandbox-bridge-lib manifest.

    Module loading order is validated and documented below. Modules are loaded
    with pcall protection, dependency checks, and clear error messages.
]]

local RESOURCE_NAME = 'sandbox-bridge-lib'
local ENV = setmetatable({}, { __index = _G })

ENV._LOADED_MODULES = ENV._LOADED_MODULES or {}
local loadedModules = ENV._LOADED_MODULES

local function Include(modulePath)
    if loadedModules[modulePath] then
        print(('[sandbox-bridge] WARNING: module %s already loaded'):format(modulePath))
        return
    end

    local file = LoadResourceFile(RESOURCE_NAME, modulePath)
    if not file then
        error(("[sandbox-bridge] CRITICAL: missing client module '%s'. Check manifest and file exists."):format(modulePath))
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
        print(('[sandbox-bridge] Loaded client module: %s'):format(modulePath))
    end
end

local LOAD_ORDER = {
    { path = 'client/core.lua', deps = {} },
    { path = 'client/playerdata.lua', deps = {'client/core.lua'} },
    { path = 'client/ui.lua', deps = {'client/core.lua'} },
    { path = 'client/ui_compat.lua', deps = {'client/core.lua', 'client/ui.lua'} },
    { path = 'client/callbacks.lua', deps = {'client/core.lua'} },
    { path = 'client/vehicles.lua', deps = {'client/core.lua'} },
    { path = 'client/vehicle.lua', deps = {'client/core.lua', 'client/vehicles.lua'} },
    { path = 'client/appearance.lua', deps = {'client/core.lua'} },
    { path = 'client/skills.lua', deps = {'client/core.lua'} },
    { path = 'client/dev.lua', deps = {'client/core.lua'} },
    { path = 'client/qbcore.lua', deps = {'client/core.lua', 'client/playerdata.lua'} },
    { path = 'client/shared.lua', deps = {'client/core.lua'} },
    { path = 'client/groups.lua', deps = {'client/core.lua'} },
    { path = 'client/persona_qbx.lua', deps = {'client/qbcore.lua', 'client/playerdata.lua'} },
    { path = 'client/persona_qbcore.lua', deps = {'client/qbcore.lua', 'client/playerdata.lua'} },
    { path = 'client/dispatch.lua', deps = {'client/core.lua'} },
    { path = 'client/target.lua', deps = {'client/core.lua'} },
    { path = 'client/exports.lua', deps = {'client/persona_qbx.lua', 'client/persona_qbcore.lua', 'client/dispatch.lua', 'client/target.lua', 'client/vehicle.lua', 'client/appearance.lua', 'client/skills.lua', 'client/dev.lua', 'client/ui_compat.lua'} },
    { path = 'client/events.lua', deps = {'client/core.lua', 'client/playerdata.lua'} },
    { path = 'client/startup.lua', deps = {'client/core.lua', 'client/events.lua', 'client/playerdata.lua'} },
}

for i = 1, #LOAD_ORDER do
    local module = LOAD_ORDER[i]
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
