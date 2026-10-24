-- sandbox-bridge-lib/client/callbacks.lua
-- Loaded by client/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Callbacks
-- ---------------------------------------------------------------------------

function TriggerServerCallback(name, callback, ...)
    if type(name) ~= 'string' then return false end
    if type(callback) == 'function' then
        local args = { n = select('#', ...), ... }
        exports['sandbox-base']:ServerCallback(name, { __bridgeArgs = args }, callback)
        return true
    else
        -- Allow ESX style: TriggerServerCallback(name, ...) where callback is passed differently
        local args = { n = select('#', callback), callback, ... }
        -- If second param isn't function, shift - but ESX uses callback as 2nd arg
        -- Try to detect: if callback is function, we already handled; else pass as is
        if type(callback) ~= 'function' then
            -- Try old style
            local cb = select(2, ...)
            if type(cb) == 'function' then
                local args2 = { n = select('#', ...) - 1, select(3, ...) }
                exports['sandbox-base']:ServerCallback(name, { __bridgeArgs = args2 }, cb)
                return true
            end
        end
    end
    return false
end

-- ESX client callback bridge
RegisterNetEvent('esx:serverCallbackResponse:' .. (GetCurrentResourceName() or ''), function(requestId, result)
    -- Handled by individual callbacks; this is a fallback
end)

-- Support generic ESX callback requests
AddEventHandler('__cfx_internal:esx_cb', function() end)


-- ESX callback support
local esxCallbackRequests = {}
local esxCallbackId = 0

function ESX.TriggerServerCallback(name, callback, ...)
    if type(name) ~= 'string' then return end
    local cb = callback
    if type(cb) ~= 'function' then
        for i=1, select('#', callback, ...) do
            local v = select(i, callback, ...)
            if type(v) == 'function' then cb = v break end
        end
    end
    esxCallbackId = esxCallbackId + 1
    local requestId = esxCallbackId
    if type(cb) == 'function' then
        esxCallbackRequests[requestId] = cb
    end

    local args = {}
    for i=1, select('#', callback, ...) do
        local v = select(i, callback, ...)
        if type(v) ~= 'function' then args[#args + 1] = v end
    end

    TriggerServerEvent('esx:serverCallback:' .. name, requestId, table.unpack(args))
end

RegisterNetEvent('esx:serverCallbackResponse:' .. GetCurrentResourceName(), function(requestId, result)
    if esxCallbackRequests[requestId] then
        local cback = esxCallbackRequests[requestId]
        esxCallbackRequests[requestId] = nil
        cback(result)
    end
end)
