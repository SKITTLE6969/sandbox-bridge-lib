-- sandbox-bridge-lib/server/jobs.lua
-- Loaded by server/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Jobs / permissions / metadata
-- ---------------------------------------------------------------------------

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

function IsGangJob(name)
    if not name then return false end
    if gangsOverlay[name] then return true end
    if Config.GangJobs and Config.GangJobs[name] then return true end
    local definition = GetRuntimeJobs()[name]
    return definition ~= nil and (definition.Gang == true or definition.Type == 'Gang')
end

function SB.GetPrimaryJob(src)
    local char = GetCharacter(src)
    if not char then return DefaultJob() end

    local assignments = char:GetData('Jobs') or {}
    local assignment

    local flags = DecodeFlags(char:GetData('Flags'))
    if flags.BridgePrimaryJob and not IsGangJob(flags.BridgePrimaryJob) then
        for _, candidate in ipairs(assignments) do
            if candidate.Id == flags.BridgePrimaryJob then
                assignment = candidate
                break
            end
        end
    end

    if not assignment then
        for _, candidate in ipairs(assignments) do
            if not IsGangJob(candidate.Id) then
                assignment = candidate
                break
            end
        end
    end

    assignment = assignment or assignments[1]
    if type(assignment) ~= 'table' then return DefaultJob() end

    local definition = GetRuntimeJobs()[assignment.Id] or {}
    local grade = assignment.Grade or {}
    local duty = SafeCall(function()
        return exports['sandbox-jobs']:DutyGet(src, assignment.Id)
    end)

    local isBoss = false
    if definition.Owner ~= nil then
        isBoss = tostring(definition.Owner) == tostring(char:GetData('SID'))
    end

    return {
        name = assignment.Id,
        label = assignment.Name or definition.Name or assignment.Id,
        payment = tonumber(definition.Salary) or 0,
        grade = {
            name = grade.Id or 'freelancer',
            label = grade.Name or grade.Id or 'Freelancer',
            level = tonumber(grade.Level) or 0,
            payment = tonumber(definition.Salary) or 0,
        },
        onduty = duty ~= nil and duty ~= false,
        isboss = isBoss,
        type = definition.Type or 'none',
        workplace = assignment.Workplace and assignment.Workplace.Id or nil,
        workplaceLabel = assignment.Workplace and assignment.Workplace.Name or nil,
    }
end

function SB.GetGang(src)
    local char = GetCharacter(src)
    if char then
        local assignments = char:GetData('Jobs') or {}
        local flags = DecodeFlags(char:GetData('Flags'))
        local fallback

        for _, assignment in ipairs(assignments) do
            if IsGangJob(assignment.Id) then
                if flags.BridgePrimaryGang == assignment.Id then
                    fallback = assignment
                    break
                elseif not fallback then
                    fallback = assignment
                end
            end
        end

        if fallback then
            local assignment = fallback
            local definition = GetRuntimeJobs()[assignment.Id] or {}
            local grade = assignment.Grade or {}
            return {
                name = assignment.Id,
                label = assignment.Name or definition.Name or assignment.Id,
                isboss = definition.Owner ~= nil,
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

function ResolveJobGrade(definition, grade, workplaceId)
    local workplace
    local grades

    if workplaceId and definition.Workplaces then
        for _, wp in ipairs(definition.Workplaces) do
            if wp.Id == workplaceId then
                workplace = wp
                grades = wp.Grades
                break
            end
        end
    end

    if not workplace and definition.Workplaces and #definition.Workplaces > 0 then
        workplace = definition.Workplaces[1]
        grades = workplace.Grades
    end

    if not grades then grades = definition.Grades end
    if type(grades) ~= 'table' or #grades == 0 then return nil, nil end

    -- Default to the lowest grade instead of the first entry (Sandbox job
    -- configs usually list the highest rank first).
    local selected = grades[1]
    for _, candidate in ipairs(grades) do
        if (tonumber(candidate.Level) or 0) < (tonumber(selected.Level) or 0) then
            selected = candidate
        end
    end

    if grade ~= nil then
        local found = false
        for _, candidate in ipairs(grades) do
            if tostring(candidate.Id) == tostring(grade)
                or tostring(candidate.Name) == tostring(grade)
                or (tonumber(grade) ~= nil and tonumber(candidate.Level) == tonumber(grade))
            then
                selected = candidate
                found = true
                break
            end
        end

        -- QBCore grade numbers do not always line up with Sandbox level
        -- values. Pick the closest level rather than falling back to the top
        -- rank (which would silently promote the player).
        local numeric = tonumber(grade)
        if not found and numeric ~= nil then
            local bestDiff
            for _, candidate in ipairs(grades) do
                local diff = math.abs((tonumber(candidate.Level) or 0) - numeric)
                if not bestDiff or diff < bestDiff then
                    selected = candidate
                    bestDiff = diff
                end
            end
        end
    end

    return workplace, selected
end

function SB.SetJob(src, name, grade, workplaceId)
    local char = GetCharacter(src)
    if not char then return false end

    local definition = GetRuntimeJobs()[name]
    if not definition then return false end

    local workplace, selectedGrade = ResolveJobGrade(definition, grade, workplaceId)
    if not selectedGrade then return false end

    local flags = DecodeFlags(char:GetData('Flags'))
    local previousPrimary = flags.BridgePrimaryJob
    flags.BridgePrimaryJob = name
    char:SetData('Flags', flags)

    local result = SafeCall(function()
        return exports['sandbox-jobs']:GiveJob(
            char:GetData('SID'),
            name,
            workplace and workplace.Id or nil,
            selectedGrade.Id,
            false
        )
    end)

    if result ~= true then
        flags.BridgePrimaryJob = previousPrimary
        char:SetData('Flags', flags)
        return false
    end

    return true
end

function SB.GetDuty(src, jobId)
    if not Started('sandbox-jobs') then return false end
    local duty = SafeCall(function()
        return exports['sandbox-jobs']:DutyGet(src, jobId)
    end)
    return duty ~= nil and duty ~= false
end

function SB.SetDuty(src, duty, jobId)
    if not Started('sandbox-jobs') or not GetCharacter(src) then return false end
    jobId = jobId or SB.GetPrimaryJob(src).name

    if duty then
        if SB.GetDuty(src, jobId) then return true end
        local result = SafeCall(function()
            return exports['sandbox-jobs']:DutyOn(src, jobId, true)
        end)
        return result ~= nil and result ~= false
    end

    if not SB.GetDuty(src, jobId) then return true end
    local result = SafeCall(function()
        return exports['sandbox-jobs']:DutyOff(src, jobId, true)
    end)
    return result ~= nil and result ~= false
end

STATUS_KEYS = {
    hunger = 'PLAYER_HUNGER',
    thirst = 'PLAYER_THIRST',
    stress = 'PLAYER_STRESS',
}

SANDBOX_LICENSE_FIELDS = {
    driver = 'Drivers',
    weapon = 'Weapons',
    hunting = 'Hunting',
    fishing = 'Fishing',
    pilot = 'Pilot',
    drift = 'Drift',
}

function ConvertLicensesToQbox(licenses)
    local result = { id = true }
    licenses = type(licenses) == 'table' and licenses or {}

    for qbKey, sandboxKey in pairs(SANDBOX_LICENSE_FIELDS) do
        local value = licenses[sandboxKey]
        result[qbKey] = type(value) == 'table' and value.Active == true or false
    end

    return result
end

function GetMetadataStore(char)
    return DecodeFlags(char:GetData('Flags'))
end

function SB.GetMetadata(src, key)
    if type(key) ~= 'string' then return nil end

    local char = GetCharacter(src)
    if not char then return nil end

    if key == 'optin' then
        return DecodeFlags(char:GetData('Flags')).BridgeOptin == true
    end

    if key == 'licences' or key == 'licenses' then
        return ConvertLicensesToQbox(char:GetData('Licenses'))
    end

    if key:match('%.') then
        local parent, child = key:match('([^%.]+)%.(.+)')
        local value = SB.GetMetadata(src, parent)
        if type(value) == 'table' then return value[child] end
        return nil
    end

    local statusKey = STATUS_KEYS[key]
    if statusKey then
        local status = char:GetData('Status') or {}
        if key == 'hunger' or key == 'thirst' then
            return tonumber(status[statusKey]) or 100
        end
        return tonumber(status[statusKey]) or 0
    end

    if key == 'isdead' then
        local player = Player(src)
        return player and player.state.isDead or false
    end

    if key == 'inlaststand' then
        local player = Player(src)
        local deadData = player and player.state.deadData
        return deadData and deadData.isMinor or false
    end

    if key == 'armor' then
        local ped = GetPlayerPed(src)
        return ped > 0 and GetPedArmour(ped) or 0
    end

    if key == 'health' then
        local ped = GetPlayerPed(src)
        return ped > 0 and GetEntityHealth(ped) or 200
    end

    if key == 'phone' then return char:GetData('Phone') end
    if key == 'callsign' then return char:GetData('Callsign') end

    local store = GetMetadataStore(char)
    if store[key] ~= nil then return store[key] end

    return char:GetData(key)
end

function TriggerMetadataChange(src, key, oldValue, newValue)
    TriggerEvent('qbx_core:server:onSetMetaData', key, oldValue, newValue, src)
    TriggerClientEvent('qbx_core:client:onSetMetaData', src, key, oldValue, newValue)
end

function SB.SetMetadata(src, key, value)
    if type(key) ~= 'string' then return false end

    if key:match('%.') then
        local parent, child = key:match('([^%.]+)%.(.+)')
        local parentValue = SB.GetMetadata(src, parent)
        if type(parentValue) ~= 'table' then return false end

        local char = GetCharacter(src)
        if not char then return false end

        local oldValue = parentValue[child]
        parentValue[child] = value

        if parent == 'licences' or parent == 'licenses' then
            local sandboxKey = SANDBOX_LICENSE_FIELDS[child]
            if not sandboxKey then return false end

            local licenses = char:GetData('Licenses') or {}
            local license = licenses[sandboxKey] or { Active = false, Points = 0, Suspended = false }
            license.Active = value == true
            licenses[sandboxKey] = license
            char:SetData('Licenses', licenses)
        else
            local store = GetMetadataStore(char)
            store[parent] = parentValue
            char:SetData('Flags', store)
        end

        TriggerMetadataChange(src, parent, oldValue, value)
        return true
    end

    if key == 'optin' then
        local char = GetCharacter(src)
        if not char then return false end

        local flags = GetMetadataStore(char)
        local oldValue = flags.BridgeOptin == true
        flags.BridgeOptin = value == true
        char:SetData('Flags', flags)
        TriggerMetadataChange(src, key, oldValue, flags.BridgeOptin)
        return true
    end

    local oldValue = SB.GetMetadata(src, key)
    local statusKey = STATUS_KEYS[key]
    if statusKey then
        if Started('sandbox-status') then
            SafeCall(function()
                exports['sandbox-status']:Set(src, statusKey, Util.Clamp(value, 0, 100))
            end)
            TriggerMetadataChange(src, key, oldValue, value)
            return true
        end
        return false
    end

    if key == 'isdead' then
        local player = Player(src)
        if player then
            player.state.isDead = value and true or false
            TriggerMetadataChange(src, key, oldValue, value)
            return true
        end
        return false
    end

    if key == 'armor' then
        local ped = GetPlayerPed(src)
        if ped > 0 then
            SetPedArmour(ped, Util.Clamp(value, 0, 100))
            TriggerMetadataChange(src, key, oldValue, value)
            return true
        end
        return false
    end

    if key == 'health' then
        local ped = GetPlayerPed(src)
        if ped > 0 then
            SetEntityHealth(ped, Util.Clamp(value, 0, GetEntityMaxHealth(ped)))
            TriggerMetadataChange(src, key, oldValue, value)
            return true
        end
        return false
    end

    local char = GetCharacter(src)
    if not char then return false end

    -- Store unknown QB metadata in the existing `Flags` JSON column instead of
    -- creating arbitrary character keys. Sandbox persists `Flags` as JSON and
    -- it is not used by the framework itself.
    local store = GetMetadataStore(char)
    store[key] = value
    char:SetData('Flags', store)
    TriggerMetadataChange(src, key, oldValue, value)
    return true
end

function SB.Revive(src)
    if not src then return false end
    TriggerClientEvent('sandbox_bridge:client:revive', src)
    return true
end

function SB.Notify(src, message, notifType, duration)
    notifType = Util.NotifyType(notifType)
    duration = duration or Config.NotifyDuration or 5000

    if Started('sandbox-hud') then
        SafeCall(function()
            exports['sandbox-hud']:Notification(src, notifType, message, duration)
        end)
        return
    end

    TriggerClientEvent('sandbox_bridge:client:notify', src, message, notifType, duration)
end
