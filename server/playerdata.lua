-- sandbox-bridge-lib/server/playerdata.lua
-- Loaded by server/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Player data
-- ---------------------------------------------------------------------------

function GetGroupMapsFromAssignments(assignments)
    local jobs, gangs = {}, {}
    for _, assignment in ipairs(assignments or {}) do
        local level = assignment.Grade and tonumber(assignment.Grade.Level) or 0
        if IsGangJob(assignment.Id) then
            gangs[assignment.Id] = level
        else
            jobs[assignment.Id] = level
        end
    end
    return jobs, gangs
end

function BuildMetadata(src, char)
    local status = char:GetData('Status') or {}
    local player = Player(src)
    local ped = GetPlayerPed(src)
    local deadData = player and player.state.deadData
    local identity = GetIdentity(src)

    local metadata = {
        hunger = tonumber(status.PLAYER_HUNGER) or 100,
        thirst = tonumber(status.PLAYER_THIRST) or 100,
        stress = tonumber(status.PLAYER_STRESS) or 0,
        isdead = player and player.state.isDead or false,
        inlaststand = deadData and deadData.isMinor or false,
        armor = ped > 0 and GetPedArmour(ped) or 0,
        health = ped > 0 and GetEntityHealth(ped) or 200,
        phone = char:GetData('Phone') or identity.Phone,
        callsign = char:GetData('Callsign') or identity.Callsign,
        licences = ConvertLicensesToQbox(char:GetData('Licenses')),
        ishandcuffed = false,
        tracker = false,
        injail = 0,
        jailitems = {},
        status = status,
        jobrep = {},
    }

    -- Expose scalar character fields as metadata so QB scripts can read
    -- custom keys without any migration.
    for key, value in pairs(char:GetData() or {}) do
        if type(value) ~= 'table' and metadata[key] == nil then
            metadata[key] = value
        end
    end

    local flags = DecodeFlags(char:GetData('Flags'))
    metadata.optin = flags.BridgeOptin == true
    for key, value in pairs(flags) do
        metadata[key] = value
    end

    return metadata
end

function SB.BuildPlayerData(src)
    src = tonumber(src)
    local char = GetCharacter(src)
    if not char then return nil end

    local accountPlayer = GetAccountPlayer(src)
    local accountData = accountPlayer and accountPlayer:GetData() or {}
    local stateId = char:GetData('SID')
    local identity = GetIdentity(src)

    local first = char:GetData('First') or identity.First or 'Unknown'
    local last = char:GetData('Last') or identity.Last or 'Unknown'
    local phone = char:GetData('Phone') or identity.Phone or '000-000-0000'
    local dob = char:GetData('DOB') or identity.DOB or '01/01/2000'
    local gender = tonumber(char:GetData('Gender') or identity.Gender) or 0
    local origin = char:GetData('Origin') or identity.Origin
    local license = accountData.Identifier or identity.License

    if not license then
        license = exports['sandbox-base']:GetPlayerLicense(src) or ''
    end

    local assignments = char:GetData('Jobs') or {}
    local jobs, gangs = GetGroupMapsFromAssignments(assignments)
    local flags = DecodeFlags(char:GetData('Flags'))

    local ped = GetPlayerPed(src)
    local coords = ped > 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    local heading = ped > 0 and GetEntityHeading(ped) or 0.0

    return {
        source = src,
        citizenid = tostring(stateId or identity.SID or ''),
        cid = tonumber(stateId or identity.SID) or 0,
        license = license,
        name = ('%s %s'):format(first, last),
        charinfo = {
            firstname = first,
            lastname = last,
            birthdate = dob,
            gender = gender,
            phone = phone,
            nationality = GetNationality(origin),
            cid = tostring(stateId or identity.SID or ''),
            backstory = char:GetData('Bio') or '',
            account = char:GetData('BankAccount'),
        },
        money = {
            cash = SB.GetCash(src),
            bank = SB.GetBank(src),
            crypto = 0,
        },
        job = SB.GetPrimaryJob(src),
        jobs = jobs,
        gang = SB.GetGang(src),
        gangs = gangs,
        metadata = BuildMetadata(src, char),
        items = SB.GetInventory(src),
        _inventoryLoaded = true,
        status = char:GetData('Status') or {},
        position = vector4(coords.x, coords.y, coords.z, heading),
        lastLoggedOut = tonumber(char:GetData('LastPlayed')) or 0,
        optin = flags.BridgeOptin == true,
        accountId = accountData.AccountID,
        userId = accountData.AccountID,
        groups = accountData.Groups or {},
    }
end

SB.GetPlayerData = SB.BuildPlayerData
