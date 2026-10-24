-- Adapted from qbx_core/modules/hooks.lua (GPL-3.0).
-- Event hooks allow third-party resources to add behaviour without editing the
-- resource that triggers the hook.

assert(lib.checkDependency('ox_lib', '3.8.0', true))

local eventHooks = {}
local microtime = os.microtime
local CURRENT_RESOURCE = GetCurrentResourceName()

local function addExport(name, fn)
    exports(name, fn)

    if CURRENT_RESOURCE ~= 'sandbox-bridge-lib' then return end
    if Citizen and Citizen.Traits and Citizen.Traits.ProvidesExports then return end

    local event = ('__cfx_export_qbx_core_%s'):format(name)
    AddEventHandler(event, function(setCB) setCB(fn) end)

    event = ('__cfx_export_qb-core_%s'):format(name)
    AddEventHandler(event, function(setCB) setCB(fn) end)
end

local function triggerEventHooks(event, payload)
    local hooks = eventHooks[event]
    if not hooks then return true end

    for i = 1, #hooks do
        local hook = hooks[i]
        local start = microtime()
        local _, response = pcall(hooks[i], payload)
        local executionTime = microtime() - start

        if executionTime >= 100000 then
            warn(('Execution of event hook "%s:%s:%s" took %.2fms.'):format(hook.resource, event, i, executionTime / 1e3))
        end

        if response == false then
            return false
        end
    end

    return true
end

local hookId = 0

addExport('registerHook', function(event, cb)
    if type(event) ~= 'string' or type(cb) ~= 'function' then return end

    local mt = getmetatable(cb)
    if mt then
        mt.__index = nil
        mt.__newindex = nil
    end

    eventHooks[event] = eventHooks[event] or {}
    hookId = hookId + 1
    cb.resource = GetInvokingResource()
    cb.hookId = hookId

    eventHooks[event][#eventHooks[event] + 1] = cb
    return hookId
end)

local function removeResourceHooks(resource, id)
    for _, hooks in pairs(eventHooks) do
        for i = #hooks, 1, -1 do
            local hook = hooks[i]
            if hook.resource == resource and (not id or hook.hookId == id) then
                table.remove(hooks, i)
            end
        end
    end
end

AddEventHandler('onResourceStop', function(resource)
    removeResourceHooks(resource)
end)

addExport('removeHooks', function(id)
    removeResourceHooks(GetInvokingResource() or GetCurrentResourceName(), id)
end)

return triggerEventHooks
