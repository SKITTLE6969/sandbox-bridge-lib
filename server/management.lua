-- sandbox-bridge-lib/server/management.lua
-- Runtime job/gang management and shared export helpers.

-- sandbox-bridge-lib/server/exports.lua
-- Loaded by server/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Exports per persona
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- QBX management helpers
-- ---------------------------------------------------------------------------

function CopyDefinition(definition)
    local copy = {}
    if type(definition) ~= 'table' then return copy end
    for key, value in pairs(definition) do copy[key] = value end
    return copy
end

function GetOverlayJob(jobName)
    if not jobsOverlay[jobName] then
        local base = GetJobDefinitions()[jobName]
        jobsOverlay[jobName] = CopyDefinition(base or {})
    end
    return jobsOverlay[jobName]
end

function GetOverlayGang(gangName)
    if not gangsOverlay[gangName] then
        local base = GetGangDefinitions()[gangName]
        gangsOverlay[gangName] = CopyDefinition(base or {})
    end
    return gangsOverlay[gangName]
end

function OverlayGrades(definition, workplaceId)
    if workplaceId and type(definition.Workplaces) == 'table' then
        for _, workplace in ipairs(definition.Workplaces) do
            if workplace.Id == workplaceId then return workplace.Grades end
        end
    end
    if type(definition.Grades) == 'table' then return definition.Grades end
    if type(definition.Workplaces) == 'table' and definition.Workplaces[1] then
        return definition.Workplaces[1].Grades
    end
    return nil
end

function SB.SetPlayerPrimaryJob(citizenid, jobName)
    local char = SafeCall(function()
        return exports['sandbox-characters']:FetchBySID(tonumber(citizenid))
    end)
    if not char then return false end

    local hasJob = false
    for _, assignment in ipairs(char:GetData('Jobs') or {}) do
        if assignment.Id == jobName then hasJob = true break end
    end
    if not hasJob then return false end

    local flags = DecodeFlags(char:GetData('Flags'))
    flags.BridgePrimaryJob = jobName
    char:SetData('Flags', flags)
    TriggerEvent('Jobs:Server:JobUpdate', char:GetData('Source'))
    return true
end

function SB.AddPlayerToJob(citizenid, jobName, grade)
    local char = SafeCall(function()
        return exports['sandbox-characters']:FetchBySID(tonumber(citizenid))
    end)
    if not char then return false end

    local definition = GetRuntimeJobs()[jobName]
    if not definition then return false end

    local workplace, selectedGrade = ResolveJobGrade(definition, grade)
    if not selectedGrade then return false end

    local result = SafeCall(function()
        return exports['sandbox-jobs']:GiveJob(
            char:GetData('SID'),
            jobName,
            workplace and workplace.Id or nil,
            selectedGrade.Id,
            false
        )
    end)

    return result == true
end

function SB.RemovePlayerFromJob(citizenid, jobName)
    local char = SafeCall(function()
        return exports['sandbox-characters']:FetchBySID(tonumber(citizenid))
    end)
    if not char then return false end

    local result = SafeCall(function()
        return exports['sandbox-jobs']:RemoveJob(char:GetData('SID'), jobName)
    end)

    if result == true then
        local source = char:GetData('Source')
        TriggerEvent('qbx_core:server:onGroupUpdate', source, jobName, nil)
        TriggerClientEvent('qbx_core:client:onGroupUpdate', source, jobName, nil)

        local flags = DecodeFlags(char:GetData('Flags'))
        if flags.BridgePrimaryJob == jobName then
            local nextJob
            for _, assignment in ipairs(char:GetData('Jobs') or {}) do
                if not IsGangJob(assignment.Id) then nextJob = assignment break end
            end
            flags.BridgePrimaryJob = nextJob and nextJob.Id or nil
        end
        if flags.BridgePrimaryGang == jobName then
            flags.BridgePrimaryGang = nil
        end
        char:SetData('Flags', flags)
        TriggerEvent('Jobs:Server:JobUpdate', source)
        return true
    end

    return false
end

function SB.CreateJob(jobName, job)
    if type(jobName) ~= 'string' or type(job) ~= 'table' then return false, 'invalid_job_name' end
    job.Id = job.Id or jobName
    job.Name = job.Name or jobName
    jobsOverlay[jobName] = job
    RefreshSharedJobs()
    return true, 'success'
end

function SB.CreateJobs(jobs)
    if type(jobs) ~= 'table' then return false, 'invalid_job_name' end
    for name, job in pairs(jobs) do SB.CreateJob(name, job) end
    return true, 'success'
end

function SB.RemoveJob(jobName)
    if type(jobName) ~= 'string' then return false, 'invalid_job_name' end
    if not jobsOverlay[jobName] then return false, 'job_not_exists' end
    jobsOverlay[jobName] = nil
    RefreshSharedJobs()
    return true, 'success'
end

function SB.CreateGangs(gangs)
    if type(gangs) ~= 'table' then return false end
    for name, gang in pairs(gangs) do
        if type(name) == 'string' and type(gang) == 'table' then
            gang.Id = gang.Id or name
            gang.Name = gang.Name or name
            gangsOverlay[name] = gang
        end
    end
    RefreshSharedJobs()
    return true
end

function SB.RemoveGang(gangName)
    if type(gangName) ~= 'string' then return false, 'invalid_gang_name' end
    if not gangsOverlay[gangName] then return false, 'gang_not_exists' end
    gangsOverlay[gangName] = nil
    RefreshSharedJobs()
    return true, 'success'
end

function SB.UpsertJobData(jobName, data)
    if type(data) ~= 'table' then return false end
    local definition = GetOverlayJob(jobName)
    for key, value in pairs(data) do definition[key] = value end
    RefreshSharedJobs()
    return true
end

function SB.UpsertGangData(gangName, data)
    if type(data) ~= 'table' then return false end
    local definition = GetOverlayGang(gangName)
    for key, value in pairs(data) do definition[key] = value end
    RefreshSharedJobs()
    return true
end

function SB.UpsertJobGrade(jobName, grade, data)
    local definition = GetOverlayJob(jobName)
    local grades = OverlayGrades(definition)
    if type(grades) ~= 'table' or type(data) ~= 'table' then return false end

    for _, candidate in ipairs(grades) do
        if tostring(candidate.Level) == tostring(grade)
            or tostring(candidate.Id) == tostring(grade)
            or tostring(candidate.Name) == tostring(grade)
        then
            for key, value in pairs(data) do candidate[key] = value end
            RefreshSharedJobs()
            return true
        end
    end
    return false
end

function SB.UpsertGangGrade(gangName, grade, data)
    local definition = GetOverlayGang(gangName)
    local grades = OverlayGrades(definition)
    if type(grades) ~= 'table' or type(data) ~= 'table' then return false end

    for _, candidate in ipairs(grades) do
        if tostring(candidate.Level) == tostring(grade)
            or tostring(candidate.Id) == tostring(grade)
            or tostring(candidate.Name) == tostring(grade)
        then
            for key, value in pairs(data) do candidate[key] = value end
            RefreshSharedJobs()
            return true
        end
    end
    return false
end

function RemoveGradeFrom(grades, grade)
    if type(grades) ~= 'table' then return false end
    for index = #grades, 1, -1 do
        local candidate = grades[index]
        if tostring(candidate.Level) == tostring(grade)
            or tostring(candidate.Id) == tostring(grade)
            or tostring(candidate.Name) == tostring(grade)
        then
            table.remove(grades, index)
            return true
        end
    end
    return false
end

function SB.RemoveJobGrade(jobName, grade)
    local definition = GetOverlayJob(jobName)
    if RemoveGradeFrom(OverlayGrades(definition), grade) then
        RefreshSharedJobs()
        return true
    end
    return false
end

function SB.RemoveGangGrade(gangName, grade)
    local definition = GetOverlayGang(gangName)
    if RemoveGradeFrom(OverlayGrades(definition), grade) then
        RefreshSharedJobs()
        return true
    end
    return false
end

function SB.GetPlayersData()
    local data = {}
    for _, player in pairs(SB.GetQBPlayers()) do
        data[#data + 1] = player.PlayerData
    end
    return data
end

function SB.GetCoreVersion()
    return GetResourceMetadata(RESOURCE, 'version', 0) or '1.0.0'
end

function SB.ExploitBan(playerId, origin)
    local ok = pcall(function()
        return exports['sandbox-base']:PunishmentBanSource(playerId, -1, origin or 'Exploit', 'Bridge')
    end)
    if not ok then
        DropPlayer(tostring(playerId), ('Banned: %s'):format(origin or 'Exploit'))
    end
end

function SB.GetSource(identifier)
    return SB.ResolveSource(identifier) or 0
end

function SB.GetUserId(identifier)
    local source = SB.ResolveSource(identifier)
    if not source then return 0 end
    local player = GetAccountPlayer(source)
    local accountId = player and player:GetData('AccountID')
    return tonumber(accountId) or accountId or 0
end

function SB.SetPlayerData(identifier, key, value)
    local source = SB.ResolveSource(identifier)
    if not source then return false end

    if key == 'money' and type(value) == 'table' then
        for account, amount in pairs(value) do SB.SetMoney(source, account, amount, 'SetPlayerData') end
        return true
    end

    if key == 'job' and type(value) == 'table' then
        return SB.SetJob(source, value.name, value.grade and value.grade.level or value.grade)
    end

    if key == 'gang' and type(value) == 'table' then
        return SB.SetGang(source, value.name, value.grade and value.grade.level or value.grade)
    end

    if key == 'charinfo' and type(value) == 'table' then
        for field, fieldValue in pairs(value) do SB.SetCharInfo(source, field, fieldValue) end
        return true
    end

    return SB.SetMetadata(source, key, value)
end

function SB.UpdatePlayerData(identifier)
    local source = SB.ResolveSource(identifier)
    if not source then return false end

    local data = SB.BuildPlayerData(source)
    if not data then return false end

    TriggerClientEvent('QBCore:Player:SetPlayerData', source, data)
    TriggerClientEvent('sandbox_bridge:client:sync', source, BuildClientSnapshot(source))
    return true
end

function SB.Logout(source)
    source = SB.ResolveSource(source)
    if not source then return false end
    TriggerClientEvent('Characters:Client:Logout:Event', source)
    return true
end

function SB.Save(source)
    source = SB.ResolveSource(source)
    if not source then return false end
    if Started('sandbox-base') then
        exports['sandbox-base']:MiddlewareTriggerEvent('Characters:ForceStore', source)
    end
    return true
end

function SB.DeleteCharacter(citizenid)
    if not citizenid then return false end
    local result = SafeCall(function()
        return MySQL.update.await('UPDATE characters SET Deleted = 1 WHERE SID = ?', { tonumber(citizenid) })
    end)
    return result ~= nil and result > 0
end

function SB.GetDutyCountJob(job)
    local players = {}
    for src in pairs(SB.GetQBPlayers()) do
        if SB.GetDuty(src, job) then players[#players + 1] = src end
    end
    return #players, players
end

function SB.GetDutyCountType(jobType)
    local players = {}
    for src in pairs(SB.GetQBPlayers()) do
        local duty = SafeCall(function()
            return exports['sandbox-jobs']:DutyGet(src)
        end)
        if duty and duty.Id then
            local definition = GetRuntimeJobs()[duty.Id]
            if definition and definition.Type == jobType then
                players[#players + 1] = src
            end
        end
    end
    return #players, players
end

function SB.GetPermission(src)
    local group = SB.GetPermissionGroup(src)
    return {
        admin = group == 'admin',
        staff = group == 'staff' or group == 'admin',
        user = true,
    }
end

function SB.IsWhitelisted(source)
    source = tonumber(source)
    if not source then return false end
    if not Started('sandbox-queue') then return true end

    local player = Player(source)
    local state = player and player.state
    if state and state.whitelisted ~= nil then
        return state.whitelisted == true
    end

    -- The queue only lets whitelisted players connect, so a connected player
    -- without the state bag (e.g. resource restarted mid-session) is allowed.
    return true
end

function SB.IsPlayerBanned(source)
    source = tonumber(source)
    if not source then return false, '' end

    local player = GetAccountPlayer(source)
    local accountId = player and player:GetData('AccountID')
    local identifier = player and player:GetData('Identifier')

    local ban
    if accountId then
        ban = SafeCall(function()
            return exports['sandbox-base']:PunishmentCheckBan('account', accountId)
        end)
    end

    if not ban and identifier then
        ban = SafeCall(function()
            return exports['sandbox-base']:PunishmentCheckBan('identifier', identifier)
        end)
    end

    if ban then return true, ban.reason or 'Banned' end
    return false, ''
end

function SB.IsOptin(source)
    if not SB.HasPermission(source, 'admin') then return false end
    local char = GetCharacter(source)
    if not char then return false end
    return DecodeFlags(char:GetData('Flags')).BridgeOptin == true
end

function SB.ToggleOptin(source)
    if not SB.HasPermission(source, 'admin') then return false end
    local char = GetCharacter(source)
    if not char then return false end

    local flags = DecodeFlags(char:GetData('Flags'))
    flags.BridgeOptin = not (flags.BridgeOptin == true)
    char:SetData('Flags', flags)
    return flags.BridgeOptin
end

function SB.NotifyFull(src, text, notifyType, duration, subTitle, notifyPosition, notifyStyle, notifyIcon, notifyIconColor)
    local message = type(text) == 'table' and (text.text or text.caption) or text
    local description = type(text) == 'table' and text.caption or nil

    if Started('ox_lib') then
        SafeCall(function()
            exports.ox_lib:notify(src, {
                title = message,
                description = description or subTitle,
                type = notifyType or 'inform',
                duration = duration or Config.NotifyDuration or 5000,
                position = notifyPosition,
                style = notifyStyle,
                icon = notifyIcon,
                iconColor = notifyIconColor,
            })
        end)
        return
    end

    SB.Notify(src, message or '', notifyType, duration)
end

function ResolveOfflinePlayerData(identifier)
    if identifier == nil then return nil end
    if SB.ResolveSource(identifier) then return nil end

    local row = exports['sandbox-characters']:BridgeGetCharacterRow(identifier)
    if not row then return nil end
    return BuildOfflinePlayerData(row)
end

function SetOfflineMetadataValue(data, key, value)
    local statusKey = STATUS_KEYS[key]
    if statusKey then
        data.status = data.status or {}
        data.status[statusKey] = tonumber(value) or value
    end

    local parent, child = key:match('([^%.]+)%.(.+)')
    if parent then
        local nested = data.metadata[parent]
        if type(nested) ~= 'table' then
            nested = {}
            data.metadata[parent] = nested
        end
        nested[child] = value
    else
        data.metadata[key] = value
    end
end

function SB.SetJobByIdentifier(identifier, jobName, grade)
    local source = SB.ResolveSource(identifier)
    if source then return SB.SetJob(source, jobName, grade) end

    local data = ResolveOfflinePlayerData(identifier)
    if not data then return false end

    local definition = GetRuntimeJobs()[jobName]
    if not definition then return false end

    local _, selectedGrade = ResolveJobGrade(definition, grade)
    if not selectedGrade then return false end

    local level = tonumber(selectedGrade.Level) or 0
    data.jobs[jobName] = level
    data.job = {
        name = jobName,
        label = definition.Name or jobName,
        payment = tonumber(definition.Salary) or 0,
        grade = {
            name = selectedGrade.Id or 'freelancer',
            label = selectedGrade.Name or selectedGrade.Id or 'Freelancer',
            level = level,
            payment = tonumber(definition.Salary) or 0,
        },
        onduty = data.job and data.job.onduty or false,
        isboss = definition.Owner ~= nil,
        type = definition.Type or 'none',
    }
    return SB.SaveOffline(data)
end

function SB.SetJobDuty(identifier, onDuty)
    local source = SB.ResolveSource(identifier)
    if not source then return false end
    return SB.SetDuty(source, onDuty)
end

function SB.SetGang(identifier, gangName, grade)
    local source = SB.ResolveSource(identifier)
    if not source then
        local data = ResolveOfflinePlayerData(identifier)
        if not data then return false end

        local offlineDefinition = GetGangDefinitions()[gangName] or GetRuntimeJobs()[gangName]
        if not offlineDefinition then return false end

        local _, offlineGrade = ResolveJobGrade(offlineDefinition, grade)
        if not offlineGrade then return false end

        local level = tonumber(offlineGrade.Level) or 0
        data.gangs[gangName] = level
        data.gang = {
            name = gangName,
            label = offlineDefinition.Name or gangName,
            isboss = offlineDefinition.Owner ~= nil,
            grade = {
                name = offlineGrade.Id or 'none',
                label = offlineGrade.Name or offlineGrade.Id or 'None',
                level = level,
            },
        }
        return SB.SaveOffline(data)
    end

    local char = GetCharacter(source)
    if not char then return false end

    local definition = GetGangDefinitions()[gangName] or GetRuntimeJobs()[gangName]
    if not definition then return false end

    local workplace, selectedGrade = ResolveJobGrade(definition, grade)
    if not selectedGrade then return false end

    local flags = DecodeFlags(char:GetData('Flags'))
    local previousPrimary = flags.BridgePrimaryGang
    flags.BridgePrimaryGang = gangName
    char:SetData('Flags', flags)

    local result = SafeCall(function()
        return exports['sandbox-jobs']:GiveJob(
            char:GetData('SID'),
            gangName,
            workplace and workplace.Id or nil,
            selectedGrade.Id,
            false
        )
    end)

    if result ~= true then
        flags.BridgePrimaryGang = previousPrimary
        char:SetData('Flags', flags)
        return false
    end

    return true
end

function SB.SetPlayerPrimaryGang(citizenid, gangName)
    local char = SafeCall(function()
        return exports['sandbox-characters']:FetchBySID(tonumber(citizenid))
    end)
    if not char then return false end

    local hasGang = false
    for _, assignment in ipairs(char:GetData('Jobs') or {}) do
        if assignment.Id == gangName and IsGangJob(gangName) then hasGang = true break end
    end
    if not hasGang then return false end

    local flags = DecodeFlags(char:GetData('Flags'))
    flags.BridgePrimaryGang = gangName
    char:SetData('Flags', flags)
    TriggerEvent('Jobs:Server:JobUpdate', char:GetData('Source'))
    return true
end

function SB.AddPlayerToGang(citizenid, gangName, grade)
    return SB.AddPlayerToJob(citizenid, gangName, grade)
end

function SB.RemovePlayerFromGang(citizenid, gangName)
    return SB.RemovePlayerFromJob(citizenid, gangName)
end

function BuildOfflineJobEntry(data, jobName, grade)
    local definition = GetRuntimeJobs()[jobName]
    if not definition then return nil end

    local _, selectedGrade = ResolveJobGrade(definition, grade)
    if not selectedGrade then return nil end

    local level = tonumber(selectedGrade.Level) or 0
    return {
        level = level,
        entry = {
            name = jobName,
            label = definition.Name or jobName,
            payment = tonumber(definition.Salary) or 0,
            grade = {
                name = selectedGrade.Id or 'freelancer',
                label = selectedGrade.Name or selectedGrade.Id or 'Freelancer',
                level = level,
                payment = tonumber(definition.Salary) or 0,
            },
            onduty = data.job and data.job.onduty or false,
            isboss = definition.Owner ~= nil,
            type = definition.Type or 'none',
        },
    }
end

function BuildOfflineGangEntry(data, gangName, grade)
    local definition = GetGangDefinitions()[gangName] or GetRuntimeJobs()[gangName]
    if not definition then return nil end

    local _, selectedGrade = ResolveJobGrade(definition, grade)
    if not selectedGrade then return nil end

    local level = tonumber(selectedGrade.Level) or 0
    return {
        level = level,
        entry = {
            name = gangName,
            label = definition.Name or gangName,
            isboss = definition.Owner ~= nil,
            grade = {
                name = selectedGrade.Id or 'none',
                label = selectedGrade.Name or selectedGrade.Id or 'None',
                level = level,
            },
        },
    }
end

