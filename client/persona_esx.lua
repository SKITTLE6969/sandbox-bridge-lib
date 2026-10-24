-- sandbox-bridge-lib/client/persona_esx.lua
-- ESX Legacy (es_extended) persona exports, client side.
--
-- The bridge translates Sandbox character/status/job data into `ESX.PlayerData`
-- and provides the helpers ESX scripts call: notifications, text UI, help text,
-- progress bars and server callbacks.

ESX = ESX or {}
ESX.PlayerData = ESX.PlayerData or {}

local progressbar = nil

local function GetProgressbar()
    if progressbar then return progressbar end
    if SB and SB.ProgressBar then progressbar = SB.ProgressBar end
    return progressbar
end

local function BuildESXPlayerData()
    local data = nil
    if GetPlayerData then
        local ok, result = pcall(GetPlayerData)
        if ok then data = result end
    end
    if not data and BuildPlayerData then
        local ok, result = pcall(BuildPlayerData)
        if ok then data = result end
    end
    if not data then return nil end

    local job = data.job or {}
    local cash = (data.money and data.money.cash) or (GetCash and GetCash()) or (Cache and Cache.data and Cache.data.money and Cache.data.money.cash) or 0
    local bank = (data.money and data.money.bank) or (Cache and Cache.bank) or 0

    return {
        source = data.source,
        identifier = data.citizenid,
        license = data.license,
        name = data.name,
        firstName = data.charinfo and data.charinfo.firstname or '',
        lastName = data.charinfo and data.charinfo.lastname or '',
        dateofbirth = data.charinfo and data.charinfo.birthdate or '',
        sex = data.charinfo and data.charinfo.gender or 0,
        height = data.charinfo and data.charinfo.height or 0,
        phoneNumber = data.charinfo and data.charinfo.phone or '',
        job = {
            id = job.name or 'unemployed',
            name = job.name or 'unemployed',
            label = job.label or 'Unemployed',
            grade = (job.grade and job.grade.level) or 0,
            grade_name = (job.grade and job.grade.name) or 'freelancer',
            grade_label = (job.grade and job.grade.label) or 'Freelancer',
            grade_salary = (job.grade and job.grade.payment) or 0,
            duty = job.onduty and true or false,
            onduty = job.onduty and true or false,
            isboss = job.isboss or false,
        },
        money = cash,
        bank = bank,
        accounts = {
            money = cash,
            bank = bank,
            black_money = 0,
        },
        inventory = data.items or {},
        metadata = data.metadata or {},
        coords = data.position and { x = data.position.x, y = data.position.y, z = data.position.z } or nil,
    }
end

function ESX.SetPlayerData(key, value)
    if type(key) == 'table' then
        for k, v in pairs(key) do
            ESX.PlayerData[k] = v
        end
    elseif key ~= nil then
        ESX.PlayerData[key] = value
    end
    return ESX.PlayerData
end

function ESX.GetPlayerData()
    ESX.PlayerData = ESX.PlayerData or {}
    if not ESX.PlayerData.source then
        local fresh = BuildESXPlayerData()
        if fresh then
            ESX.PlayerData = fresh
        else
            return ESX.PlayerData
        end
    else
        local fresh = BuildESXPlayerData()
        if fresh then
            for k, v in pairs(fresh) do
                ESX.PlayerData[k] = v
            end
            if not ESX.PlayerData.accounts then
                ESX.PlayerData.accounts = {
                    money = ESX.PlayerData.money or 0,
                    bank = ESX.PlayerData.bank or 0,
                    black_money = 0,
                }
            end
        end
    end
    return ESX.PlayerData
end

function ESX.IsPlayerLoaded()
    return ESX.PlayerData.source ~= nil
end

function ESX.TriggerServerCallback(name, callback, ...)
    return TriggerServerCallback(name, callback, ...)
end

function ESX.RegisterServerCallback(name, handler)
    if type(name) ~= 'string' or type(handler) ~= 'function' then return false end
    RegisterNetEvent('esx:clientCallback:' .. name)
    AddEventHandler('esx:clientCallback:' .. name, function(requestId, ...)
        handler(function(value)
            TriggerServerEvent('esx:clientCallbackResponse:' .. name, requestId, value)
        end, ...)
    end)
    return true
end

function ESX.ShowNotification(message, type, duration)
    return ShowNotification(message, type or 'info', duration or 5000)
end

function ESX.ShowAdvancedNotification(title, subject, message, icon, duration)
    return ShowNotification(message, 'info', duration or 5000)
end

function ESX.TextUI(message, position)
    return ShowText(message, position or 'right')
end

function ESX.HideUI()
    return HideText()
end

function ESX.ShowHelpNotification(message)
    AddTextEntry('ESX_Help', message)
    BeginTextCommandDisplayHelp('ESX_Help')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function ESX.ShowSubtitle(message, duration)
    AddTextEntry('ESX_Subtitle', message)
    BeginTextCommandPrint('ESX_Subtitle')
    local remaining = math.floor((tonumber(duration) or 5000) / 1000)
    while remaining > 0 do
        Wait(1000)
        remaining = remaining - 1
    end
    EndTextCommandPrint()
end

function ESX.Progressbar(message, duration, options, callback)
    local bar = GetProgressbar()
    if bar and bar.Open then
        duration = tonumber(duration) or 5000
        return bar.Open({
            label = message,
            duration = duration,
            canCancel = options and options.canCancel or false,
            disable = options and options.disable or nil,
        }, function(done)
            if callback then callback(done) end
        end)
    end

    if callback then callback(true) end
    return true
end

function ESX.Streaming.RequestModel(model)
    if type(model) == 'string' then model = GetHashKey(model) end
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    return model
end

ESX.Game = ESX.Game or {}

function ESX.Game.GetClosestPlayer(coords)
    local playerPed = PlayerPedId()
    local playerCoords = coords or GetEntityCoords(playerPed)
    local closest, closestDist = -1, 999.0
    for _, src in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(src)
        if targetPed ~= playerPed then
            local dist = #(playerCoords - GetEntityCoords(targetPed))
            if dist < closestDist then
                closest, closestDist = src, dist
            end
        end
    end
    return closest, closestDist
end

function ESX.Game.GetClosestObject(coords)
    local coords = coords or GetEntityCoords(PlayerPedId())
    local handle, entity = FindFirstObject()
    local closest, closestDist = 0, 999.0
    repeat
        if entity ~= 0 then
            local dist = #(coords - GetEntityCoords(entity))
            if dist < closestDist then
                closest, closestDist = entity, dist
            end
        end
        local ok, nextEntity = FindNextObject(handle)
        entity = nextEntity
    until not ok
    EndFindObject(handle)
    return closest, closestDist
end

function ESX.Game.GetClosestVehicle(coords)
    local coords = coords or GetEntityCoords(PlayerPedId())
    local handle, entity = FindFirstVehicle()
    local closest, closestDist = 0, 999.0
    repeat
        if entity ~= 0 then
            local dist = #(coords - GetEntityCoords(entity))
            if dist < closestDist then
                closest, closestDist = entity, dist
            end
        end
        local ok, nextEntity = FindNextVehicle(handle)
        entity = nextEntity
    until not ok
    EndFindVehicle(handle)
    return closest, closestDist
end

function ESX.Game.GetPlayers()
    return GetActivePlayers()
end

function ESX.Game.DeleteVehicle(vehicle)
    if vehicle and vehicle ~= 0 then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end
end

function ESX.Game.SpawnVehicle(model, coords, heading, callback)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    ESX.Streaming.RequestModel(hash)
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading or 0.0, true, false)
    SetModelAsNoLongerNeeded(hash)
    if callback then callback(veh) end
    return veh
end

function ExportESXPersona()
    _G.ESX = ESX

    Util.AddExport('getSharedObject', function() return ESX end)
    Util.AddExport('GetSharedObject', function() return ESX end)

    for name, fn in pairs({
        GetPlayerData = ESX.GetPlayerData,
        SetPlayerData = ESX.SetPlayerData,
        IsPlayerLoaded = ESX.IsPlayerLoaded,
        TriggerServerCallback = ESX.TriggerServerCallback,
        RegisterServerCallback = ESX.RegisterServerCallback,
        ShowNotification = ESX.ShowNotification,
        ShowAdvancedNotification = ESX.ShowAdvancedNotification,
        ShowHelpNotification = ESX.ShowHelpNotification,
        TextUI = ESX.TextUI,
        HideUI = ESX.HideUI,
        Progressbar = ESX.Progressbar,
    }) do
        Util.AddExport(name, fn)
    end
end
