-- sandbox-bridge-lib/server/persona_esx.lua
-- ESX Legacy (es_extended) persona exports.
--
-- Sandbox stores characters as SIDs with job assignments and money split
-- between the `money` inventory item and a personal bank account. This file
-- exposes that data through the ESX `ESX` object and the xPlayer methods that
-- ESX scripts expect, without replacing any Sandbox resource.

ESX = ESX or {}

-- ESX accounts map onto the bridge money types.
local ESX_ACCOUNTS = {
    money = 'cash',
    cash = 'cash',
    bank = 'bank',
    black_money = 'crypto',
}

local function AccountsFor(src)
    return {
        money = SB.GetCash(src),
        bank = SB.GetBank(src),
        black_money = 0,
    }
end

local function BuildESXPlayer(src)
    local data = SB.BuildPlayerData(src)
    if not data then return nil end

    local job = SB.GetPrimaryJob(src) or {}
    local accounts = AccountsFor(src)

    local xPlayer = {
        source = src,
        identifier = data.citizenid,
        license = data.license,
        name = data.name,
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
        accounts = accounts,
        inventory = data.items or {},
        metadata = data.metadata or {},
        variables = {
            job = job.name or 'unemployed',
            gang = data.gang and data.gang.name or nil,
        },
    }

    -- Account helpers ------------------------------------------------------

    function xPlayer.getAccount(account)
        account = ESX_ACCOUNTS[account] and account or 'money'
        return { name = account, money = accounts[account] or 0 }
    end

    function xPlayer.getAccounts()
        local list = {}
        for account in pairs(ESX_ACCOUNTS) do
            list[#list + 1] = { name = account, money = accounts[account] or 0 }
        end
        return list
    end

    function xPlayer.getMoney()
        return accounts.money or 0
    end

    function xPlayer.getBank()
        return accounts.bank or 0
    end

    function xPlayer.addAccountMoney(account, amount)
        account = ESX_ACCOUNTS[account] and account or 'money'
        local target = account == 'money' and 'cash' or account == 'bank' and 'bank' or 'crypto'
        local ok = SB.AddMoney(src, target, amount, 'esx:addAccountMoney')
        if ok then accounts[account] = (accounts[account] or 0) + (tonumber(amount) or 0) end
        return ok
    end

    function xPlayer.removeAccountMoney(account, amount)
        account = ESX_ACCOUNTS[account] and account or 'money'
        local target = account == 'money' and 'cash' or account == 'bank' and 'bank' or 'crypto'
        local ok = SB.RemoveMoney(src, target, amount, 'esx:removeAccountMoney')
        if ok then accounts[account] = math.max(0, (accounts[account] or 0) - (tonumber(amount) or 0)) end
        return ok
    end

    function xPlayer.setAccountMoney(account, amount)
        account = ESX_ACCOUNTS[account] and account or 'money'
        local target = account == 'money' and 'cash' or account == 'bank' and 'bank' or 'crypto'
        local ok = SB.SetMoney(src, target, amount, 'esx:setAccountMoney')
        if ok then accounts[account] = tonumber(amount) or 0 end
        return ok
    end

    function xPlayer.addMoney(amount, reason)
        return xPlayer.addAccountMoney('money', amount)
    end

    function xPlayer.removeMoney(amount, reason)
        return xPlayer.removeAccountMoney('money', amount)
    end

    -- Job helpers ----------------------------------------------------------

    function xPlayer.getJob()
        return xPlayer.job
    end

    function xPlayer.setJob(name, grade)
        local ok = SB.SetJob(src, name, grade)
        if ok then
            local updated = SB.GetPrimaryJob(src) or {}
            xPlayer.job = {
                id = updated.name or name,
                name = updated.name or name,
                label = updated.label or name,
                grade = (updated.grade and updated.grade.level) or tonumber(grade) or 0,
                grade_name = (updated.grade and updated.grade.name) or 'freelancer',
                grade_label = (updated.grade and updated.grade.label) or 'Freelancer',
                grade_salary = (updated.grade and updated.grade.payment) or 0,
                duty = updated.onduty and true or false,
                onduty = updated.onduty and true or false,
                isboss = updated.isboss or false,
            }
            xPlayer.variables.job = xPlayer.job.name
        end
        return ok
    end

    function xPlayer.getJobName()
        return xPlayer.job.name
    end

    function xPlayer.setJobDuty(duty)
        return SB.SetDuty(src, duty)
    end

    -- Inventory helpers ----------------------------------------------------

    local function esxItem(entry)
        return {
            name = entry.name,
            label = entry.label or entry.name,
            count = entry.count or entry.amount or 1,
            weight = entry.weight or 0,
            metadata = entry.metadata or entry.info or {},
            slot = entry.slot,
        }
    end

    function xPlayer.addInventoryItem(name, amount, metadata, slot)
        return SB.AddItem(src, name, amount, slot, metadata)
    end

    function xPlayer.removeInventoryItem(name, amount, metadata, slot)
        return SB.RemoveItem(src, name, amount, slot, metadata)
    end

    function xPlayer.getInventoryItem(name)
        local items = SB.GetItem(src, name)
        if not items or #items == 0 then return { name = name, count = 0 } end
        return esxItem(items[1])
    end

    function xPlayer.getInventory()
        local list = {}
        for _, item in ipairs(SB.GetInventory(src)) do
            list[#list + 1] = esxItem(item)
        end
        return list
    end

    function xPlayer.getInventoryItemCount(name)
        return SB.GetItemCount(src, name)
    end

    function xPlayer.hasItem(name, amount)
        return SB.HasItem(src, name, amount)
    end

    -- Misc helpers ---------------------------------------------------------

    function xPlayer.getIdentifier()
        return xPlayer.identifier
    end

    function xPlayer.getName()
        return xPlayer.name
    end

    function xPlayer.getMetadata()
        return SB.GetMetadata(src, 'metadata') or xPlayer.metadata
    end

    function xPlayer.setMetadata(key, value)
        xPlayer.metadata[key] = value
        return SB.SetMetadata(src, key, value)
    end

    function xPlayer.triggerEvent(eventName, ...)
        TriggerClientEvent(eventName, src, ...)
    end

    function xPlayer.showNotification(message, type, duration)
        SB.Notify(src, message, type, duration)
    end

    function xPlayer.kick(reason)
        DropPlayer(src, reason or 'Kicked')
    end

    function xPlayer.setCoords(coords)
        TriggerClientEvent('esx:teleport', src, coords)
    end

    return xPlayer
end

function ESX.GetPlayerFromId(src)
    src = tonumber(src)
    if not src then return nil end
    if not GetCharacter(src) then return nil end
    local cached = playerObjectCache[src] and playerObjectCache[src]._esx
    if cached then
        -- Refresh the cached player data before returning.
        return BuildESXPlayer(src)
    end
    local xPlayer = BuildESXPlayer(src)
    if xPlayer and playerObjectCache[src] then
        playerObjectCache[src]._esx = xPlayer
    end
    return xPlayer
end

function ESX.GetPlayerFromIdentifier(identifier)
    if identifier == nil then return nil end
    local id = tostring(identifier)
    -- SIDs are numeric; only accept a numeric identifier here.
    if not tonumber(id) then return nil end
    local char = SafeCall(function()
        return exports['sandbox-characters']:FetchBySID(tonumber(id))
    end)
    if not char then return nil end
    return ESX.GetPlayerFromId(char:GetData('Source'))
end

function ESX.GetExtendedPlayers(key, value)
    local result = {}
    for _, src in ipairs(SB.GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            if key == nil then
                result[#result + 1] = xPlayer
            elseif key == 'job' and xPlayer.job.name == value then
                result[#result + 1] = xPlayer
            elseif xPlayer.variables[key] == value then
                result[#result + 1] = xPlayer
            end
        end
    end
    return result
end

function ESX.GetPlayers()
    return SB.GetPlayers()
end

function ESX.GetConfig()
    return Config or {}
end

function ESX.RegisterServerCallback(name, handler)
    if type(name) ~= 'string' or type(handler) ~= 'function' then return false end
    if _G.ESX and _G.ESX.RegisterServerCallback ~= ESX.RegisterServerCallback then
        return _G.ESX.RegisterServerCallback(name, handler)
    end
    RegisterNetEvent('esx:serverCallback:' .. name)
    AddEventHandler('esx:serverCallback:' .. name, function(requestId, ...)
        local src = source
        local ok, result = pcall(handler, src, function(value)
            TriggerClientEvent('esx:serverCallbackResponse:' .. name, src, requestId, value)
        end, ...)
        if not ok then
            TriggerClientEvent('esx:serverCallbackResponse:' .. name, src, requestId, nil)
        end
    end)
    return true
end

function ESX.RegisterUsableItem(name, handler)
    return RegisterUseableItem(name, handler)
end

function ExportESXPersona()
    _G.ESX = ESX

    Util.AddExport('getSharedObject', function() return ESX end)
    Util.AddExport('GetSharedObject', function() return ESX end)

    for name, fn in pairs({
        GetPlayerFromId = ESX.GetPlayerFromId,
        GetPlayerFromIdentifier = ESX.GetPlayerFromIdentifier,
        GetExtendedPlayers = ESX.GetExtendedPlayers,
        GetPlayers = ESX.GetPlayers,
        GetConfig = ESX.GetConfig,
        RegisterServerCallback = ESX.RegisterServerCallback,
        RegisterUsableItem = ESX.RegisterUsableItem,
    }) do
        Util.AddExport(name, fn)
    end
end
