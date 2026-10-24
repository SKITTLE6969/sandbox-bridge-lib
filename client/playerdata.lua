-- sandbox-bridge-lib/client/playerdata.lua
-- Loaded by client/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Player data
-- ---------------------------------------------------------------------------

function GetCharacter()
    if not Started('sandbox-base') then return nil end
    return SafeCall(function()
        return exports['sandbox-base']:GetCharacterData()
    end)
end

function GetLocalInventory()
    if not Started('ox_inventory') then return {} end
    local items = SafeCall(function()
        return exports.ox_inventory:GetPlayerItems()
    end)
    if type(items) ~= 'table' then return {} end

    local result = {}
    for _, item in pairs(items) do
        if type(item) == 'table' and item.name then
            local metadata = item.metadata or item.info or {}
            local count = item.count or item.amount or 0
            result[#result + 1] = {
                name = item.name,
                label = item.label or item.name,
                count = count,
                amount = count,
                slot = item.slot,
                metadata = metadata,
                info = metadata,
                weight = item.weight or 0,
                stack = item.stack ~= false,
                unique = item.stack == false,
                description = item.description or '',
                useable = true,
                shouldClose = true,
            }
        end
    end
    return result
end

function GetCash()
    if not Started('ox_inventory') then return 0 end
    local count = SafeCall(function()
        return exports.ox_inventory:GetItemCount('money')
    end)
    return tonumber(count) or 0
end

function DefaultJob()
    local default = Config.DefaultJob or {}
    return {
        name = default.name or 'unemployed',
        label = default.label or 'Unemployed',
        payment = tonumber(default.payment) or 0,
        grade = {
            name = default.grade or 'freelancer',
            label = default.gradeLabel or 'Freelancer',
            level = tonumber(default.gradeLevel) or 0,
            payment = tonumber(default.payment) or 0,
        },
        onduty = false,
        isboss = false,
        type = 'none',
    }
end

function BuildJob(character, assignments)
    local assignment
    local flags = DecodeFlags(character and character.Flags)
    if type(assignments) == 'table' and flags.BridgePrimaryJob then
        for _, candidate in ipairs(assignments) do
            if candidate.Id == flags.BridgePrimaryJob then
                assignment = candidate
                break
            end
        end
    end
    assignment = assignment or (assignments and assignments[1])
    if not assignment then return DefaultJob() end

    local grade = assignment.Grade or {}
    local duty = false
    if Started('sandbox-jobs') then
        local result = SafeCall(function()
            return exports['sandbox-jobs']:DutyGet(assignment.Id)
        end)
        duty = result ~= nil and result ~= false
    end

    return {
        name = assignment.Id,
        label = assignment.Name or assignment.Id,
        payment = 0,
        grade = {
            name = grade.Id or 'freelancer',
            label = grade.Name or grade.Id or 'Freelancer',
            level = tonumber(grade.Level) or 0,
            payment = 0,
        },
        onduty = duty,
        isboss = false,
        type = Cache.jobTypes[assignment.Id] or 'none',
        workplace = assignment.Workplace and assignment.Workplace.Id or nil,
        workplaceLabel = assignment.Workplace and assignment.Workplace.Name or nil,
    }
end

function BuildGang(character, assignments)
    if type(assignments) == 'table' then
        local flags = DecodeFlags(character and character.Flags)
        local fallback

        for _, assignment in ipairs(assignments) do
            if Cache.gangJobs[assignment.Id] then
                if flags.BridgePrimaryGang == assignment.Id then
                    fallback = assignment
                    break
                elseif not fallback then
                    fallback = assignment
                end
            end
        end

        if fallback then
            local grade = fallback.Grade or {}
            return {
                name = fallback.Id,
                label = fallback.Name or fallback.Id,
                isboss = false,
                grade = {
                    name = grade.Id or 'none',
                    label = grade.Name or grade.Id or 'None',
                    level = tonumber(grade.Level) or 0,
                },
            }
        end
    end
    return {
        name = 'none',
        label = 'No Gang',
        isboss = false,
        grade = { name = 'none', label = 'None', level = 0 },
    }
end

function BuildPlayerData()
    if not LocalPlayer.state.loggedIn then return nil end

    local character = GetCharacter()
    if type(character) ~= 'table' then return nil end

    local assignments = character.Jobs or {}
    local status = character.Status or {}
    local ped = PlayerPedId()
    local deadData = LocalPlayer.state.deadData
    local first = character.First or 'Unknown'
    local last = character.Last or 'Unknown'

    local metadata = {
        hunger = tonumber(status.PLAYER_HUNGER) or 100,
        thirst = tonumber(status.PLAYER_THIRST) or 100,
        stress = tonumber(status.PLAYER_STRESS) or 0,
        isdead = LocalPlayer.state.isDead or false,
        inlaststand = deadData and deadData.isMinor or false,
        armor = GetPedArmour(ped),
        health = GetEntityHealth(ped),
        phone = character.Phone,
        callsign = character.Callsign,
        licences = ConvertLicensesToQbox(character.Licenses),
        ishandcuffed = false,
        tracker = false,
        injail = 0,
        jailitems = {},
        status = status,
        jobrep = {},
    }

    for key, value in pairs(character) do
        if type(value) ~= 'table' and metadata[key] == nil then
            metadata[key] = value
        end
    end

    local flags = DecodeFlags(character.Flags)
    metadata.optin = flags.BridgeOptin == true
    for key, value in pairs(flags) do
        metadata[key] = value
    end

    local jobs, gangs = GetGroupMapsFromAssignments(assignments)

    return {
        source = GetPlayerServerId(PlayerId()),
        citizenid = tostring(character.SID or ''),
        cid = tonumber(character.SID) or 0,
        name = ('%s %s'):format(first, last),
        charinfo = {
            firstname = first,
            lastname = last,
            birthdate = character.DOB or '01/01/2000',
            gender = tonumber(character.Gender) or 0,
            phone = character.Phone or '000-000-0000',
            nationality = GetNationality(character.Origin),
            cid = tostring(character.SID or ''),
            backstory = character.Bio or '',
            account = character.BankAccount,
        },
        money = {
            cash = GetCash(),
            bank = Cache.bank,
            crypto = 0,
        },
        job = BuildJob(character, assignments),
        jobs = jobs,
        gang = BuildGang(character, assignments),
        gangs = gangs,
        metadata = metadata,
        items = GetLocalInventory(),
        status = status,
        position = GetEntityCoords(ped),
        lastLoggedOut = tonumber(character.LastPlayed) or 0,
        optin = flags.BridgeOptin == true,
        groups = {},
    }
end

function JobSignature(data)
    if not data or not data.job then return nil end
    return ('%s:%s:%s:%s'):format(
        data.job.name,
        tostring(data.job.grade.level),
        tostring(data.job.onduty),
        tostring(data.job.isboss)
    )
end

function RefreshPlayerData(force)
    if not LocalPlayer.state.loggedIn then
        Cache.data = nil
        return nil
    end

    local data = BuildPlayerData()
    if data then
        Cache.data = data
        Cache.lastRefresh = GetGameTimer()
        Cache.lastJobSignature = Cache.lastJobSignature or JobSignature(data)
        TriggerEvent('QBCore:Player:SetPlayerData', data)
    end
    return data
end

function GetPlayerData()
    if Cache.data then return Cache.data end
    return RefreshPlayerData()
end

