
-- ESX server callback support
local esxCallbacks = {}

function ESX.RegisterServerCallback(name, handler)
    esxCallbacks[name] = handler
    RegisterNetEvent('esx:serverCallback:' .. name)
    AddEventHandler('esx:serverCallback:' .. name, function(requestId, ...)
        local src = tonumber(source)
        if not src or src <= 0 then
            return
        end
        if type(requestId) ~= 'number' and type(requestId) ~= 'string' then
            return
        end
        if type(esxCallbacks[name]) ~= 'function' then
            TriggerClientEvent('esx:serverCallbackResponse:' .. (GetCurrentResourceName() or 'sandbox-bridge-lib'), src, requestId, nil)
            return
        end
        local ok, result = pcall(esxCallbacks[name], src, function(response)
            if not src or src <= 0 then return end
            TriggerClientEvent('esx:serverCallbackResponse:' .. (GetCurrentResourceName() or 'sandbox-bridge-lib'), src, requestId, response)
        end, ...)
        if not ok then
            if src and src > 0 then
                TriggerClientEvent('esx:serverCallbackResponse:' .. (GetCurrentResourceName() or 'sandbox-bridge-lib'), src, requestId, nil)
            end
        end
    end)
end

RegisterNetEvent('esx:clientCallbackResponse:' .. GetCurrentResourceName(), function() end)
