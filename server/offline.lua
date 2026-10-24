-- sandbox-bridge-lib/server/offline.lua
-- Loaded by server/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Offline players
-- ---------------------------------------------------------------------------

function BuildJobFromAssignments(assignments, citizenid, flags)
    local selected
    if flags and flags.BridgePrimaryJob then
        for _, assignment in ipairs(assignments) do
            if assignment.Id == flags.BridgePrimaryJob then
                selected = assignment
                break
            end
        end
    end

    if not selected then
        for _, assignment in ipairs(assignments) do
            if not IsGangJob(assignment.Id) then
                selected = assignment
                break
            end
        end
    end

    selected = selected or assignments[1]
    if type(selected) ~= 'table' then return DefaultJob() end

    local definition = GetRuntimeJobs()[selected.Id] or {}
    local grade = selected.Grade or {}

    return {
        name = selected.Id,
        label = selected.Name or definition.Name or selected.Id,
        payment = tonumber(definition.Salary) or 0,
        grade = {
            name = grade.Id or 'freelancer',
            label = grade.Name or grade.Id or 'Freelancer',
            level = tonumber(grade.Level) or 0,
            payment = tonumber(definition.Salary) or 0,
        },
        onduty = false,
        isboss = definition.Owner ~= nil and tostring(definition.Owner) == tostring(citizenid),
        type = definition.Type or 'none',
        workplace = selected.Workplace and selected.Workplace.Id or nil,
        workplaceLabel = selected.Workplace and selected.Workplace.Name or nil,
    }
end

function BuildGangFromAssignments(assignments, flags)
    local fallback
    for _, assignment in ipairs(assignments) do
        if IsGangJob(assignment.Id) then
            if flags and flags.BridgePrimaryGang == assignment.Id then
                fallback = assignment
                break
            elseif not fallback then
                fallback = assignment
            end
        end
    end

    if not fallback then
        return {
            name = 'none',
            label = 'No Gang',
            isboss = false,
            grade = { name = 'none', label = 'None', level = 0 },
        }
    end

    local definition = GetRuntimeJobs()[fallback.Id] or {}
    local grade = fallback.Grade or {}

    return {
        name = fallback.Id,
        label = fallback.Name or definition.Name or fallback.Id,
        isboss = definition.Owner ~= nil,
        grade = {
            name = grade.Id or 'none',
            label = grade.Name or grade.Id or 'None',
            level = tonumber(grade.Level) or 0,
        },
    }
end

function BuildOfflineMetadata(data)
    local status = data.Status or {}
    local flags = DecodeFlags(data.Flags)

    local metadata = {
        hunger = tonumber(status.PLAYER_HUNGER) or 100,
        thirst = tonumber(status.PLAYER_THIRST) or 100,
        stress = tonumber(status.PLAYER_STRESS) or 0,
        isdead = false,
        inlaststand = false,
        armor = tonumber(data.Armor) or 0,
        health = tonumber(data.HP) or 200,
        phone = data.Phone,
        callsign = data.Callsign,
        licences = ConvertLicensesToQbox(data.Licenses),
        ishandcuffed = false,
        tracker = false,
        injail = tonumber(data.Jailed) or 0,
        jailitems = {},
        status = status,
        jobrep = {},
    }

    for key, value in pairs(data) do
        if type(value) ~= 'table' and metadata[key] == nil then
            metadata[key] = value
        end
    end

    metadata.optin = flags.BridgeOptin == true
    for key, value in pairs(flags) do
        metadata[key] = value
    end

    return metadata
end

function DecodeOfflineInventory(value)
    if type(value) == 'string' and value ~= '' then
        local ok, decoded = pcall(json.decode, value)
        if ok then value = decoded end
    end

    if type(value) ~= 'table' then return nil, 0 end

    local items = value
    if type(value.items) == 'table' then items = value.items end

    local cash = 0
    for _, item in pairs(items) do
        if type(item) == 'table' and item.name == 'money' then
            cash = cash + (tonumber(item.count) or tonumber(item.amount) or 0)
        end
    end

    return items, cash
end

function BuildOfflinePlayerData(data, skipAccount)
    if type(data) ~= 'table' then return nil end

    local citizenid = tostring(data.SID or data.ID or data.citizenid or '')
    local assignments = data.Jobs or {}
    local flags = DecodeFlags(data.Flags)
    local jobs, gangs = GetGroupMapsFromAssignments(assignments)
    local items, inventoryCash = DecodeOfflineInventory(data.Inventory)
    local inventoryLoaded = items ~= nil
    local cash = inventoryCash or 0
    if cash <= 0 then cash = tonumber(data.Cash) or 0 end

    local account
    if not skipAccount then
        account = SafeCall(function()
            return exports['Renewed-Banking']:AccountsGetPersonal(data.SID)
        end)
    end

    local first = data.First or 'Unknown'
    local last = data.Last or 'Unknown'
    local dob = data.DOB or '01/01/2000'
    local gender = tonumber(data.Gender) or 0
    local origin = data.Origin or 'San Andreas'

    return {
        citizenid = citizenid,
        cid = tonumber(data.SID) or 0,
        license = data.License,
        name = ('%s %s'):format(first, last),
        charinfo = {
            firstname = first,
            lastname = last,
            birthdate = dob,
            gender = gender,
            phone = data.Phone or '000-000-0000',
            nationality = GetNationality(origin),
            cid = citizenid,
            backstory = data.Bio or '',
            account = data.BankAccount,
        },
        money = {
            cash = cash,
            bank = account and (tonumber(account.Balance) or 0) or 0,
            crypto = 0,
        },
        job = BuildJobFromAssignments(assignments, data.SID, flags),
        jobs = jobs,
        gang = BuildGangFromAssignments(assignments, flags),
        gangs = gangs,
        metadata = BuildOfflineMetadata(data),
        items = items or {},
        _inventoryLoaded = inventoryLoaded,
        status = data.Status or {},
        position = vector4(0.0, 0.0, 0.0, 0.0),
        lastLoggedOut = tonumber(data.LastPlayed) or 0,
        optin = flags.BridgeOptin == true,
        accountId = data.User,
        userId = data.User,
        groups = {},
        offline = true,
    }
end

function BuildOfflinePlayerObjectFromData(playerData)
    if type(playerData) ~= 'table' then return nil end

    local player = {
        PlayerData = playerData,
        Offline = true,
        Functions = {},
    }

    player.Functions.GetMoney = function(account)
        local normalized = Util.NormalizeAccount(account)
        return playerData.money[normalized] or 0
    end

    player.Functions.SetMoney = function(account, amount)
        local normalized = Util.NormalizeAccount(account)
        playerData.money[normalized] = tonumber(amount) or 0
        return SB.SaveOffline(playerData)
    end

    player.Functions.AddMoney = function(account, amount)
        local normalized = Util.NormalizeAccount(account)
        playerData.money[normalized] = (playerData.money[normalized] or 0) + (tonumber(amount) or 0)
        return SB.SaveOffline(playerData)
    end

    player.Functions.RemoveMoney = function(account, amount)
        local normalized = Util.NormalizeAccount(account)
        playerData.money[normalized] = (playerData.money[normalized] or 0) - (tonumber(amount) or 0)
        return SB.SaveOffline(playerData)
    end

    player.Functions.SetMetaData = function(key, value)
        playerData.metadata[key] = value
        return SB.SaveOffline(playerData)
    end

    player.Functions.Save = function()
        return SB.SaveOffline(playerData)
    end

    return player
end

function SB.GetOfflinePlayer(citizenid)
    if not citizenid then return nil end

    local online = SB.GetPlayerByCitizenId(citizenid)
    if online then return online end

    local data = exports['sandbox-characters']:BridgeGetCharacterRow(citizenid)
    if not data then return nil end

    return BuildOfflinePlayerObjectFromData(BuildOfflinePlayerData(data))
end

function SB.CreatePlayer(playerData, offline)
    if type(playerData) ~= 'table' then return nil end

    local source = tonumber(playerData.source)
    local doc = exports['sandbox-characters']:BridgeCreateCharacter(source, playerData)
    if not doc then return nil end

    if source and not offline then
        local loaded = exports['sandbox-characters']:BridgeLoadCharacter(source, doc.ID)
        if loaded then return SB.GetPlayer(source) end
    end

    local data = exports['sandbox-characters']:BridgeGetCharacterRow(doc.ID)
    if not data then return nil end

    return BuildOfflinePlayerObjectFromData(BuildOfflinePlayerData(data))
end

function SB.SaveOffline(playerData)
    if type(playerData) ~= 'table' or not playerData.citizenid then return false end
    return exports['sandbox-characters']:BridgeSaveCharacter(playerData.citizenid, playerData) == true
end

function SB.Login(source, citizenid, newData)
    source = tonumber(source)
    if not source or source <= 0 then return false end
    if GetCharacter(source) then return true end

    local data
    if citizenid then
        data = exports['sandbox-characters']:BridgeLoadCharacter(source, citizenid)
    elseif newData then
        local doc = exports['sandbox-characters']:BridgeCreateCharacter(source, newData)
        if doc then
            data = exports['sandbox-characters']:BridgeLoadCharacter(source, doc.ID)
        end
    end

    if not data then return false end

    local ok, config = pcall(require, '@sandbox-characters.shared.config')
    local spawn = (ok and type(config) == 'table' and config.DefaultSpawns and config.DefaultSpawns[1]) or {
        id = 1,
        label = 'Default',
        location = { x = -1044.84, y = -2749.85, z = 21.36, h = 0.0 },
    }

    if ok and type(config) == 'table' then
        local jailed = data.JailedData
        if data.Jailed and type(jailed) == 'table' and not jailed.Released and config.PrisonSpawn then
            spawn = config.PrisonSpawn
        elseif data.ICU and type(data.ICU) == 'table' and not data.ICU.Released and config.ICUSpawn then
            spawn = config.ICUSpawn
        end
    end

    local payload = {}
    for key, value in pairs(data) do payload[key] = value end
    payload.spawn = spawn

    TriggerClientEvent('sandbox_bridge:client:spawnCharacter', source, payload)
    return true
end

