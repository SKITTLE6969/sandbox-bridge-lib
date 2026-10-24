-- sandbox-bridge-lib/server/qbcore.lua
-- Loaded by server/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- QBCore object
-- ---------------------------------------------------------------------------

QBCore = {
    Shared = {
        Jobs = {},
        Items = {},
        Vehicles = {},
        Locations = {},
    },
    Functions = {},
    Commands = {},
    Config = {},
}

function RefreshSharedItems()
    local items = SafeCall(function()
        return exports.ox_inventory:Items()
    end)

    if type(items) ~= 'table' then return end

    local qbItems = {}
    for name, item in pairs(items) do
        if type(item) == 'table' and type(name) == 'string' then
            qbItems[name] = {
                name = name,
                label = item.label or name,
                weight = item.weight or 0,
                description = item.description or '',
                image = Util.ItemImage(name, item),
                unique = item.stack == false,
                useable = true,
                shouldClose = true,
            }
        end
    end

    QBCore.Shared.Items = qbItems
end

function RefreshSharedJobs()
    QBCore.Shared.Jobs = SB.GetSharedJobs()
end

function RegisterUseableItem(itemName, callback)
    if not Started('ox_inventory') then return false end

    useableItems[itemName] = callback

    local ok = pcall(function()
        return exports.ox_inventory:RegisterUse(itemName, RESOURCE, function(source, itemData)
            local data = itemData or {}
            local payload = {
                name = data.Name or data.name or itemName,
                label = data.label or data.Name or itemName,
                amount = data.Count or data.count or 1,
                count = data.Count or data.count or 1,
                metadata = data.MetaData or data.metadata or {},
                info = data.MetaData or data.metadata or {},
                slot = data.Slot or data.slot,
            }
            pcall(callback, source, payload)
        end)
    end)

    return ok
end

QBCore.Functions.GetPlayer = function(src)
    return SB.GetPlayer(src)
end

QBCore.Functions.GetPlayers = function()
    return SB.GetPlayers()
end

QBCore.Functions.GetDutyCountJob = function(jobName)
    return #QBCore.Functions.GetPlayersOnDuty(jobName)
end

QBCore.Functions.GetPlayerByCitizenId = function(citizenid)
    return SB.GetPlayerByCitizenId(citizenid)
end

QBCore.Functions.GetPlayerByPhone = function(phone)
    return SB.GetPlayerByPhone(phone)
end

QBCore.Functions.GetPlayerByAccountId = function(accountId)
    return SB.GetPlayerByAccountId(accountId)
end

QBCore.Functions.GetPlayerByLicense = function(license)
    return SB.GetPlayerByLicense(license)
end

QBCore.Functions.GetPlayerBySteam = function(steam)
    for src, identity in pairs(identityCache) do
        local license = identity.License
        if type(license) == 'string' and license:find(steam, 1, true) and GetCharacter(src) then
            return SB.GetPlayer(src)
        end
    end
    return nil
end

QBCore.Functions.GetPlayersByJob = function(job)
    local players = {}
    for src in pairs(SB.GetQBPlayers()) do
        if SB.GetPrimaryJob(src).name == job then
            players[#players + 1] = src
        end
    end
    return players
end

QBCore.Functions.GetPlayersOnDuty = function(job)
    local players = {}
    for src in pairs(SB.GetQBPlayers()) do
        if SB.GetPrimaryJob(src).name == job and SB.GetDuty(src, job) then
            players[#players + 1] = src
        end
    end
    return players
end

QBCore.Functions.HasPermission = function(src, permission)
    return SB.HasPermission(src, permission)
end

QBCore.Functions.AddPermission = function(src, permission)
    local license = SafeCall(function()
        return exports['sandbox-base']:GetPlayerLicense(src)
    end)
    if license then
        ExecuteCommand(('add_principal identifier.%s group.%s'):format(license, permission))
        TriggerEvent('QBCore:Server:OnPermissionUpdate', src)
        TriggerClientEvent('QBCore:Client:OnPermissionUpdate', src)
        return true
    end
    return false
end

QBCore.Functions.RemovePermission = function(src, permission)
    local license = SafeCall(function()
        return exports['sandbox-base']:GetPlayerLicense(src)
    end)
    if license then
        ExecuteCommand(('remove_principal identifier.%s group.%s'):format(license, permission))
        TriggerEvent('QBCore:Server:OnPermissionUpdate', src)
        TriggerClientEvent('QBCore:Client:OnPermissionUpdate', src)
        return true
    end
    return false
end

QBCore.Functions.IsPlayerWhitelisted = function()
    return true
end

QBCore.Functions.IsWhitelisted = function()
    return true
end

QBCore.Functions.GetIdentifier = function(src, idType)
    if idType == 'license' then idType = 'license2' end
    return SB.GetIdentifier(src, idType or 'license2')
end

QBCore.Functions.GetPlayerIdentifiers = function(src)
    return SB.GetPlayerIdentifiers(src)
end

QBCore.Functions.GetPlayerName = function(src)
    local data = SB.BuildPlayerData(src)
    if not data then return 'Unknown' end
    return data.charinfo.firstname, data.charinfo.lastname
end

QBCore.Functions.GetPlayerSource = function(citizenid)
    local player = SB.GetPlayerByCitizenId(citizenid)
    return player and player.PlayerData.source or nil
end

QBCore.Functions.Notify = function(src, message, notifType, duration)
    SB.Notify(src, message, notifType, duration)
end

QBCore.Functions.CreateUseableItem = function(itemName, callback)
    return RegisterUseableItem(itemName, callback)
end

QBCore.Functions.CreateCallback = function(name, callback)
    exports['sandbox-base']:RegisterServerCallback(name, function(source, data, cb)
        local args = type(data) == 'table' and data.__bridgeArgs or {}
        callback(source, cb, table.unpack(args, 1, args.n or #args))
    end)
end

QBCore.Functions.CreateCallbackAsync = QBCore.Functions.CreateCallback

QBCore.Commands.Add = function(name, help, arguments, argsrequired, callback, permission)
    local handler = function(source, args, rawCommand)
        if permission and permission ~= 'user' and not SB.HasPermission(source, permission) then
            SB.Notify(source, 'You do not have permission to use this command.', 'error')
            return
        end
        callback(source, args, rawCommand)
    end

    if Started('mChat') then
        SafeCall(function()
            exports['mChat']:RegisterCommand(
                name,
                handler,
                { help = help or '', params = arguments or {} },
                argsrequired and #(arguments or {}) or -1
            )
        end)
    else
        RegisterCommand(name, handler, false)
    end
end

QBCore.Commands.Refresh = function() end

QBCore.Commands.List = {}
