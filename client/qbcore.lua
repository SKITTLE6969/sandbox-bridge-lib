-- sandbox-bridge-lib/client/qbcore.lua
-- Loaded by client/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- QBCore client functions
-- ---------------------------------------------------------------------------

QBCore.Functions.GetPlayerData = function()
    return GetPlayerData()
end

QBCore.Functions.TriggerCallback = function(name, callback, ...)
    TriggerServerCallback(name, callback, ...)
end

QBCore.Functions.TriggerServerCallback = QBCore.Functions.TriggerCallback

QBCore.Functions.HasItem = function(item, amount)
    if not Started('ox_inventory') then return false end
    local count = SafeCall(function()
        return exports.ox_inventory:GetItemCount(item)
    end)
    return (tonumber(count) or 0) >= (tonumber(amount) or 1)
end

QBCore.Functions.GetItemByName = function(item)
    local data = GetPlayerData()
    if not data then return {} end
    local items = {}
    for _, invItem in ipairs(data.items) do
        if invItem.name == item then items[#items + 1] = invItem end
    end
    return items
end

QBCore.Functions.Notify = function(message, notifType, duration)
    ShowNotification(message, notifType, duration)
end

QBCore.Functions.DrawText = function(message, position, icon)
    ShowText(message)
end

QBCore.Functions.HideText = function()
    HideText()
end

QBCore.Functions.GetPlayers = function()
    local players = {}
    for _, playerId in ipairs(GetActivePlayers()) do
        players[#players + 1] = GetPlayerServerId(playerId)
    end
    return players
end

QBCore.Functions.GetCoords = function(entity)
    if not entity then return vector3(0.0, 0.0, 0.0) end
    return GetEntityCoords(entity)
end

QBCore.Functions.GetPlate = function(vehicle)
    if not vehicle then return '' end
    return GetVehicleNumberPlateText(vehicle)
end

QBCore.Functions.GetVehicleProperties = GetVehicleProperties
QBCore.Functions.SetVehicleProperties = SetVehicleProperties

QBCore.Functions.GetPlayer = function(source)
    if source == GetPlayerServerId(PlayerId()) then
        local data = GetPlayerData()
        if not data then return nil end
        return { PlayerData = data, Functions = {} }
    end
    return nil
end

function GetClosestPlayer(includeLocal)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closest, closestDistance = -1, -1

    for _, playerId in ipairs(GetActivePlayers()) do
        if includeLocal or playerId ~= PlayerId() then
            local target = GetPlayerPed(playerId)
            if target ~= 0 then
                local distance = #(coords - GetEntityCoords(target))
                if closest == -1 or distance < closestDistance then
                    closest = playerId
                    closestDistance = distance
                end
            end
        end
    end

    return closest, closestDistance
end

QBCore.Functions.GetClosestPlayer = function(coords)
    if coords then
        local ped = PlayerPedId()
        local myCoords = GetEntityCoords(ped)
        local closest, closestDistance = -1, -1
        for _, playerId in ipairs(GetActivePlayers()) do
            local target = GetPlayerPed(playerId)
            if target ~= 0 then
                local distance = #(vector3(coords.x, coords.y, coords.z) - GetEntityCoords(target))
                if closest == -1 or distance < closestDistance then
                    closest = playerId
                    closestDistance = distance
                end
            end
        end
        return closest, closestDistance
    end
    return GetClosestPlayer(false)
end

function GetClosestFromPool(pool)
    local coords = GetEntityCoords(PlayerPedId())
    local closest, closestDistance = 0, -1
    for _, entity in ipairs(GetGamePool(pool)) do
        if DoesEntityExist(entity) then
            local distance = #(coords - GetEntityCoords(entity))
            if closest == 0 or distance < closestDistance then
                closest = entity
                closestDistance = distance
            end
        end
    end
    return closest, closestDistance
end

QBCore.Functions.GetClosestPed = function()
    return GetClosestFromPool('CPed')
end

QBCore.Functions.GetClosestVehicle = function()
    return GetClosestFromPool('CVehicle')
end

QBCore.Functions.GetClosestObject = function()
    return GetClosestFromPool('CObject')
end

QBCore.Functions.GetPlayersFromCoords = function(coords, distance)
    local players = {}
    local origin = coords and vector3(coords.x, coords.y, coords.z) or GetEntityCoords(PlayerPedId())
    distance = distance or 5.0

    for _, playerId in ipairs(GetActivePlayers()) do
        local target = GetPlayerPed(playerId)
        if target ~= 0 and #(origin - GetEntityCoords(target)) <= distance then
            players[#players + 1] = GetPlayerServerId(playerId)
        end
    end
    return players
end

QBCore.Functions.Progressbar = function(name, label, duration, useWhileDead, canCancel, disableControls, animation, prop, propTwo, onFinish, onCancel)
    if Started('sandbox-hud') then
        local action = {
            name = name or 'qb-progress',
            label = label or 'Working...',
            duration = duration or 5000,
            useWhileDead = useWhileDead == true,
            canCancel = canCancel ~= false,
            controlDisables = disableControls or {},
            disarm = disableControls and disableControls.disableCombat or false,
        }

        if type(animation) == 'table' then
            action.animation = {
                animDict = animation.dict or animation.animDict,
                anim = animation.clip or animation.anim,
                flags = animation.flag or animation.flags,
                task = animation.task,
            }
        end

        exports['sandbox-hud']:Progress(action, function(cancelled)
            if cancelled then
                if onCancel then pcall(onCancel) end
            else
                if onFinish then pcall(onFinish) end
            end
        end)
        return
    end

    SafeCall(function()
        local success = exports.ox_lib:progressBar({
            duration = duration or 5000,
            label = label or 'Working...',
            canCancel = canCancel ~= false,
            useWhileDead = useWhileDead == true,
            disable = disableControls,
        })

        if success then
            if onFinish then pcall(onFinish) end
        elseif onCancel then
            pcall(onCancel)
        end
    end)
end

QBCore.Functions.RequestModel = function(model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    return true
end

QBCore.Functions.HasLoadedModel = function(model)
    return HasModelLoaded(model)
end

QBCore.Functions.SpawnVehicle = function(model, coords, heading, isNetworked)
    local hash = type(model) == 'string' and joaat(model) or model
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    if not HasModelLoaded(hash) then return nil end

    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading or 0.0, isNetworked ~= false, false)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleOnGroundProperly(vehicle)
    return vehicle
end

QBCore.Functions.DeleteVehicle = function(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end
end

QBCore.Commands.Refresh = function() end

