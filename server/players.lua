-- sandbox-bridge-lib/server/players.lua
-- Loaded by server/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Player objects (QBCore / QBX shape)
-- ---------------------------------------------------------------------------

function AttachPlayerFunctions(player, src)
    local functions = player.Functions
    if not functions then
        functions = {}
        player.Functions = functions
    end

    functions.AddMoney = function(account, amount, reason)
        return SB.AddMoney(src, account, amount, reason)
    end

    functions.RemoveMoney = function(account, amount, reason)
        return SB.RemoveMoney(src, account, amount, reason)
    end

    functions.SetMoney = function(account, amount, reason)
        return SB.SetMoney(src, account, amount, reason)
    end

    functions.GetMoney = function(account)
        return SB.GetMoney(src, account)
    end

    functions.SetMetaData = function(key, value)
        return SB.SetMetadata(src, key, value)
    end

    functions.SetJob = function(job, grade, duty)
        local success = SB.SetJob(src, job, grade)
        if success and duty ~= nil then
            SB.SetDuty(src, duty, job)
        end
        return success
    end

    functions.SetJobDuty = function(duty)
        return SB.SetDuty(src, duty)
    end

    functions.AddItem = function(item, amount, slot, metadata)
        return SB.AddItem(src, item, amount, slot, metadata)
    end

    functions.RemoveItem = function(item, amount, slot, metadata)
        return SB.RemoveItem(src, item, amount, slot, metadata)
    end

    functions.GetItemByName = function(item)
        return SB.GetItem(src, item)
    end

    functions.GetItemsByName = functions.GetItemByName

    functions.GetItemBySlot = function(slot)
        return SB.GetItemBySlot(src, slot)
    end

    functions.SetPlayerData = function(key, value)
        return SB.SetMetadata(src, key, value)
    end

    functions.Save = function()
        return true
    end

    return player
end

function SB.GetPlayer(src)
    if type(src) == 'string' and tonumber(src) == nil then
        src = SB.ResolveSource(src)
    end

    src = tonumber(src)
    if not src then return nil end

    local data = SB.BuildPlayerData(src)
    if not data then
        playerObjectCache[src] = nil
        return nil
    end

    local player = playerObjectCache[src]
    if not player then
        player = {}
        playerObjectCache[src] = player
    end

    player.PlayerData = data
    player.Functions = player.Functions or {}
    AttachPlayerFunctions(player, src)

    return player
end

function SB.GetQBPlayers()
    local players = {}
    if not Started('sandbox-base') then return players end

    local all = SafeCall(function()
        return exports['sandbox-base']:GetAllPlayers()
    end) or {}

    for src in pairs(all) do
        local player = SB.GetPlayer(src)
        if player then players[src] = player end
    end
    return players
end

function SB.GetPlayers()
    local players = {}
    for src in pairs(SB.GetQBPlayers()) do
        players[#players + 1] = src
    end
    return players
end

function SB.GetPlayerByCitizenId(citizenid)
    local id = tonumber(citizenid)
    if not id then return nil end
    local char = SafeCall(function()
        return exports['sandbox-characters']:FetchBySID(id)
    end)
    if not char then return nil end
    return SB.GetPlayer(char:GetData('Source'))
end

function SB.GetPlayerByPhone(phone)
    for src, identity in pairs(identityCache) do
        if identity.Phone == phone and GetCharacter(src) then
            return SB.GetPlayer(src)
        end
    end

    local char = SafeCall(function()
        return exports['sandbox-characters']:FetchCharacterData('Phone', phone)
    end)
    if not char then return nil end
    return SB.GetPlayer(char:GetData('Source'))
end

function FindPlayerByAccountField(field, value)
    if not Started('sandbox-base') then return nil end
    local all = SafeCall(function()
        return exports['sandbox-base']:GetAllPlayers()
    end) or {}

    for src, player in pairs(all) do
        if player:GetData(field) == value then
            return SB.GetPlayer(src)
        end
    end
    return nil
end

function SB.GetPlayerByAccountId(accountId)
    return FindPlayerByAccountField('AccountID', tonumber(accountId) or accountId)
end

function SB.GetPlayerByLicense(license)
    for src, identity in pairs(identityCache) do
        if identity.License == license and GetCharacter(src) then
            return SB.GetPlayer(src)
        end
    end

    if not Started('sandbox-characters') then return nil end
    local characters = SafeCall(function()
        return exports['sandbox-characters']:FetchAllCharacters()
    end) or {}

    for _, char in pairs(characters) do
        if char:GetData('License') == license then
            return SB.GetPlayer(char:GetData('Source'))
        end
    end
    return nil
end

function SB.GetPermissionGroup(src)
    local player = GetAccountPlayer(src)
    if player and player.Permissions then
        if player.Permissions:IsAdmin() then return 'admin' end
        if player.Permissions:IsStaff() then return 'staff' end
    end
    return 'user'
end

function SB.HasPermission(src, permission)
    src = tonumber(src)
    if not src or src <= 0 then return false end
    if not permission or permission == '' or permission == 'user' then return true end

    permission = tostring(permission):lower()
    local mapped = Config.AdminPermissions[permission]

    local group = SB.GetPermissionGroup(src)
    if mapped == 'admin' or permission == 'admin' or permission == 'god' or permission == 'owner' then
        return group == 'admin' or IsPlayerAceAllowed(src, 'admin')
    end
    if mapped == 'staff' or permission == 'staff' or permission == 'mod' then
        return group == 'admin' or group == 'staff' or IsPlayerAceAllowed(src, 'admin')
    end

    return IsPlayerAceAllowed(src, permission) or IsPlayerAceAllowed(src, ('command.%s'):format(permission))
end

function SB.GetPlayerIdentifiers(src)
    local identifiers = GetPlayerIdentifiers(src)
    return identifiers or {}
end

function SB.GetIdentifier(src, idType)
    for _, identifier in ipairs(SB.GetPlayerIdentifiers(src)) do
        if identifier:sub(1, #idType + 1) == idType .. ':' then
            return identifier
        end
    end
    return nil
end

---Resolve a source/citizenid/identifier to a server id.
---@param identifier string|number
---@return number?
function SB.ResolveSource(identifier)
    if identifier == nil then return nil end

    local numeric = tonumber(identifier)
    if numeric then
        if GetCharacter(numeric) then return numeric end
        local player = SB.GetPlayerByCitizenId(numeric) or SB.GetPlayerByAccountId(numeric)
        if player then return player.PlayerData.source end
    end

    if type(identifier) == 'string' then
        local player = SB.GetPlayerByCitizenId(identifier) or SB.GetPlayerByLicense(identifier)
        if player then return player.PlayerData.source end

        for src in pairs(SB.GetQBPlayers()) do
            for _, id in ipairs(SB.GetPlayerIdentifiers(src)) do
                if id == identifier then return src end
            end
        end
    end

    return nil
end

---Combined jobs/gangs for a player keyed by group name -> grade level.
---@param source number
---@return table<string, number>
function SB.GetGroups(source)
    local groups = {}
    local char = GetCharacter(source)
    if not char then return groups end

    for _, assignment in ipairs(char:GetData('Jobs') or {}) do
        groups[assignment.Id] = tonumber(assignment.Grade and assignment.Grade.Level) or 0
    end

    return groups
end

function MatchesGroupFilter(filter, groups, citizenid)
    if type(filter) == 'string' then
        return groups[filter] ~= nil or citizenid == filter
    end

    if type(filter) ~= 'table' then return false end

    if filter[1] ~= nil then
        for _, name in ipairs(filter) do
            if groups[name] ~= nil or citizenid == name then return true end
        end
        return false
    end

    for group, level in pairs(filter) do
        if groups[group] ~= nil then
            if level == nil or groups[group] >= (tonumber(level) or 0) then
                return true
            end
        elseif citizenid == group then
            return true
        end
    end

    return false
end

function SB.HasGroup(source, filter)
    local groups = SB.GetGroups(source)
    local char = GetCharacter(source)
    local citizenid = char and tostring(char:GetData('SID')) or nil
    return MatchesGroupFilter(filter, groups, citizenid)
end

function SB.HasPrimaryGroup(source, filter)
    local job = SB.GetPrimaryJob(source)
    local gang = SB.GetGang(source)
    local groups = { [job.name] = job.grade.level }

    if gang.name ~= 'none' then
        groups[gang.name] = gang.grade.level
    end

    local char = GetCharacter(source)
    local citizenid = char and tostring(char:GetData('SID')) or nil
    return MatchesGroupFilter(filter, groups, citizenid)
end

function IsBossGrade(grades, grade)
    if type(grades) ~= 'table' then return false end
    for _, candidate in ipairs(grades) do
        if tostring(candidate.Level) == tostring(grade)
            or tostring(candidate.Id) == tostring(grade)
            or tostring(candidate.Name) == tostring(grade)
        then
            return candidate.IsBoss == true
                or candidate.isboss == true
                or tostring(candidate.Name):lower() == 'boss'
                or tostring(candidate.Name):lower() == 'leader'
                or (tonumber(candidate.Level) or 0) >= 99
        end
    end
    return false
end

function SB.IsGradeBoss(group, grade)
    local definition = GetRuntimeJobs()[group] or GetGangDefinitions()[group]
    if not definition then return false end

    if IsBossGrade(definition.Grades, grade) then return true end
    for _, workplace in ipairs(definition.Workplaces or {}) do
        if IsBossGrade(workplace.Grades, grade) then return true end
    end
    return false
end

function SB.GetGroupMembers(group, _type)
    local members = {}
    local seen = {}

    for src in pairs(SB.GetQBPlayers()) do
        local char = GetCharacter(src)
        if char then
            local citizenid = tostring(char:GetData('SID'))
            for _, assignment in ipairs(char:GetData('Jobs') or {}) do
                if assignment.Id == group then
                    members[citizenid] = tonumber(assignment.Grade and assignment.Grade.Level) or 0
                    seen[citizenid] = true
                    break
                end
            end
        end
    end

    local rows = SafeCall(function()
        return exports['sandbox-characters']:BridgeGetAllCharacterRows()
    end) or {}

    for _, row in ipairs(rows) do
        local citizenid = tostring(row.SID or '')
        if citizenid ~= '' and not seen[citizenid] then
            for _, assignment in ipairs(row.Jobs or {}) do
                if assignment.Id == group then
                    members[citizenid] = tonumber(assignment.Grade and assignment.Grade.Level) or 0
                    break
                end
            end
        end
    end

    return members
end

function RandomString(length)
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    local out = {}
    for i = 1, length do
        local index = math.random(1, #chars)
        out[i] = chars:sub(index, index)
    end
    return table.concat(out)
end

function SB.GenerateUniqueIdentifier(identifierType)
    identifierType = tostring(identifierType or 'citizenid')

    if identifierType == 'citizenid' then
        local sequence = SafeCall(function()
            return exports['sandbox-base']:SequenceGet('Character')
        end)
        return tostring(sequence or math.random(100000, 999999))
    end

    if identifierType == 'AccountNumber' then
        return math.random(100000, 999999)
    end

    if identifierType == 'PhoneNumber' then
        if Started('sandbox-phone') then
            local phone = SafeCall(function()
                return exports['sandbox-phone']:GeneratePhoneNumber()
            end)
            if phone then return phone end
        end
        return ('555-%s'):format(math.random(1000, 9999))
    end

    if identifierType == 'FingerId' then return RandomString(6) end
    if identifierType == 'WalletId' then return RandomString(16) end
    if identifierType == 'SerialNumber' then return RandomString(8) end

    return RandomString(8)
end

CHAR_INFO_FIELDS = {
    firstname = 'First',
    lastname = 'Last',
    birthdate = 'DOB',
    gender = 'Gender',
    phone = 'Phone',
    nationality = 'Origin',
    backstory = 'Bio',
    account = 'BankAccount',
    cid = 'SID',
}

function SB.SetCharInfo(source, charInfo, value)
    source = SB.ResolveSource(source)
    if not source then return false end

    local field = CHAR_INFO_FIELDS[tostring(charInfo)]
    if not field then return false end

    local char = GetCharacter(source)
    if not char then return false end

    if field == 'Gender' or field == 'BankAccount' then value = tonumber(value) or value end

    if field == 'Origin' and type(value) ~= 'table' then
        value = { label = tostring(value), code = '' }
    end

    char:SetData(field, value)

    local identity = identityCache[source]
    if identity then identity[field] = value end

    return true
end

function ResolveMetadataValue(metadata, key)
    local value = metadata
    for part in key:gmatch('[^%.]+') do
        if type(value) ~= 'table' then return nil end
        value = value[part]
    end
    return value
end

function MatchesMetadataFilters(metadata, filters)
    local strict = filters.metadata.strict == true

    for key, expected in pairs(filters.metadata) do
        if key ~= 'strict' then
            local actual = ResolveMetadataValue(metadata, key)
            local matches

            if type(expected) == 'number' and not strict then
                matches = type(actual) == 'number' and actual >= expected
            else
                matches = actual == expected
            end

            if not matches then return false end
        end
    end

    return true
end

function SB.SearchPlayers(filters)
    filters = filters or {}
    local results = {}
    local seen = {}

    for src, player in pairs(SB.GetQBPlayers()) do
        local data = player.PlayerData
        local matches = true

        if filters.license then
            matches = data.license == filters.license
            if not matches then
                for _, identifier in ipairs(SB.GetPlayerIdentifiers(src)) do
                    if identifier == filters.license then matches = true break end
                end
            end
        end

        if matches and filters.job then
            matches = data.job.name == filters.job
        end

        if matches and filters.gang then
            matches = data.gang.name == filters.gang
        end

        if matches and type(filters.metadata) == 'table' then
            matches = MatchesMetadataFilters(data.metadata, filters)
        end

        if matches then
            results[#results + 1] = player
            seen[data.citizenid] = true
        end
    end

    local rows = SafeCall(function()
        return exports['sandbox-characters']:BridgeGetAllCharacterRows()
    end) or {}

    for _, row in ipairs(rows) do
        local citizenid = tostring(row.SID or '')
        if citizenid ~= '' and not seen[citizenid] then
            local data = BuildOfflinePlayerData(row, true)
            if data then
                local matches = true

                if filters.license then
                    matches = data.license == filters.license
                end

                if matches and filters.job then
                    matches = data.job.name == filters.job
                end

                if matches and filters.gang then
                    matches = data.gang.name == filters.gang
                end

                if matches and type(filters.metadata) == 'table' then
                    matches = MatchesMetadataFilters(data.metadata, filters)
                end

                if matches then
                    local fullData = BuildOfflinePlayerData(row) or data
                    local player = BuildOfflinePlayerObjectFromData(fullData)
                    if player then results[#results + 1] = player end
                    seen[citizenid] = true
                end
            end
        end
    end

    return results
end

