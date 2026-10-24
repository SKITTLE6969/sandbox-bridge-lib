
-- ESX server callback support
local esxCallbacks = {}

function ESX.RegisterServerCallback(name, handler)
    esxCallbacks[name] = handler
    RegisterNetEvent('esx:serverCallback:' .. name)
    AddEventHandler('esx:serverCallback:' .. name, function(requestId, ...)
        local src = source
        if type(esxCallbacks[name]) ~= 'function' then
            TriggerClientEvent('esx:serverCallbackResponse:' .. (GetCurrentResourceName() or 'sandbox-bridge-lib'), src, requestId, nil)
            return
        end
        local ok, result = pcall(esxCallbacks[name], src, function(response)
            TriggerClientEvent('esx:serverCallbackResponse:' .. (GetCurrentResourceName() or 'sandbox-bridge-lib'), src, requestId, response)
        end, ...)
        if not ok then
            TriggerClientEvent('esx:serverCallbackResponse:' .. (GetCurrentResourceName() or 'sandbox-bridge-lib'), src, requestId, nil)
        end
    end)
end

RegisterNetEvent('esx:clientCallbackResponse:' .. GetCurrentResourceName(), function() end)
