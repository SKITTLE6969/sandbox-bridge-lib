-- sandbox-bridge-lib/server/events.lua
-- Loaded by server/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Events / lifecycle
-- ---------------------------------------------------------------------------

-- Local server event: refresh both framework personas when Renewed changes a personal account.
AddEventHandler('Renewed-Banking:server:personalBalanceChanged', function(citizenid)
    local src = SB.ResolveSource(citizenid)
    if not src then return end
    bankCache[src] = nil
    playerObjectCache[src] = nil
    TriggerClientEvent('sandbox_bridge:client:sync', src, BuildClientSnapshot(src))
end)

function BuildClientSnapshot(src)
    local jobTypes, gangJobs = GetJobMeta()
    return {
        bank = SB.GetBank(src, true),
        jobTypes = jobTypes,
        gangJobs = gangJobs,
        defaultJob = Config.DefaultJob,
    }
end

function OnPlayerLoaded(src)
    src = tonumber(src)
    if not src then return end

    loadedPlayers[src] = true
    unloadingPlayers[src] = nil
    playerObjectCache[src] = nil

    -- Snapshot the character identity. Sandbox's save routine clears several
    -- identity fields from the live store (First, Last, Phone, DOB, Gender,
    -- License) when it flushes a character, so keep our own copy.
    CacheIdentity(src, GetCharacter(src))

    -- Make sure admin/staff players get the ACE principal matching the
    -- Sandbox group. This is what the QBX/QBCore admin checks read.
    if IsPrimaryBridge() then
        local accountPlayer = GetAccountPlayer(src)
        if accountPlayer and accountPlayer.Permissions then
            local group
            if accountPlayer.Permissions:IsAdmin() then
                group = 'admin'
            elseif accountPlayer.Permissions:IsStaff() then
                group = 'staff'
            end

            if group then
                local license = SafeCall(function()
                    return exports['sandbox-base']:GetPlayerLicense(src)
                end)
                if license then
                    ExecuteCommand(('add_principal identifier.%s group.%s'):format(license, group))
                end
            end
        end

        TriggerEvent('QBCore:Server:OnPermissionUpdate', src)
        TriggerClientEvent('QBCore:Client:OnPermissionUpdate', src)
    end

    if IsPrimaryQB() then
        local player = SB.GetPlayer(src)
        TriggerEvent('QBCore:Server:OnPlayerLoaded', src)
        TriggerEvent('QBCore:Server:PlayerLoaded', player)
    end

    -- ESX lifecycle: scripts listen for esx:playerLoaded with the xPlayer.
    if ESX and ESX.GetPlayerFromId then
        local xPlayer = ESX.GetPlayerFromId(src)
        TriggerEvent('esx:playerLoaded', src, xPlayer)
        TriggerClientEvent('esx:playerLoaded', src, xPlayer)
    end

    if IsPrimaryBridge() then
        TriggerClientEvent('sandbox_bridge:client:sync', src, BuildClientSnapshot(src))
    end
    Debug(('player %s loaded'):format(src))
end

function OnPlayerUnloaded(src)
    src = tonumber(src)
    if not src then return end
    if unloadingPlayers[src] then return end
    unloadingPlayers[src] = true

    loadedPlayers[src] = nil
    playerObjectCache[src] = nil
    bankCache[src] = nil
    identityCache[src] = nil

    if IsPrimaryQB() then
        TriggerEvent('QBCore:Server:OnPlayerUnload', src)
        TriggerClientEvent('qbx_core:client:playerLoggedOut', src)
    end
    TriggerEvent('esx:playerDropped', src)
    TriggerClientEvent('esx:playerDropped', src)
    Debug(('player %s unloaded'):format(src))

    Citizen.SetTimeout(10000, function()
        unloadingPlayers[src] = nil
    end)
end

function OnJobChanged(src)
    src = tonumber(src)
    if not src or not GetCharacter(src) then return end

    SB.GetPlayer(src)

    local job = SB.GetPrimaryJob(src)
    local gang = SB.GetGang(src)

    if IsPrimaryQB() then
        TriggerEvent('QBCore:Server:OnJobUpdate', src, {
            name = job.name,
            label = job.label,
            grade = job.grade,
            onduty = job.onduty,
            isboss = job.isboss,
            type = job.type,
        })
        TriggerEvent('QBCore:Server:SetDuty', src, job.onduty)
        if gang.name ~= 'none' then
            TriggerEvent('QBCore:Server:OnGangUpdate', src, gang)
        end
        TriggerEvent('qbx_core:server:onGroupUpdate', src, job.name, job.grade.level)
        if gang.name ~= 'none' then
            TriggerEvent('qbx_core:server:onGroupUpdate', src, gang.name, gang.grade.level)
        end

        TriggerClientEvent('QBCore:Client:OnJobUpdate', src, job)
        TriggerClientEvent('QBCore:Client:SetDuty', src, job.onduty)
        if gang.name ~= 'none' then
            TriggerClientEvent('QBCore:Client:OnGangUpdate', src, gang)
        end
        TriggerClientEvent('qbx_core:client:onGroupUpdate', src, job.name, job.grade.level)
        if gang.name ~= 'none' then
            TriggerClientEvent('qbx_core:client:onGroupUpdate', src, gang.name, gang.grade.level)
        end
    end

    -- ESX job update event carries the new xPlayer job table.
    if ESX and ESX.GetPlayerFromId then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            TriggerEvent('esx:setJob', src, xPlayer.job, xPlayer)
            TriggerClientEvent('esx:setJob', src, xPlayer.job)
        end
    end
end

function OnDutyChanged(src)
    src = tonumber(src)
    if not src or not GetCharacter(src) then return end

    local job = SB.GetPrimaryJob(src)

    if IsPrimaryQB() then
        TriggerEvent('QBCore:Server:SetDuty', src, job.onduty)
        TriggerClientEvent('QBCore:Client:SetDuty', src, job.onduty)
    end

end

AddEventHandler('Jobs:Server:JobUpdate', function(source)
    OnJobChanged(source)
end)

AddEventHandler('Job:Server:DutyAdd', function(_, source)
    OnDutyChanged(source)
end)

AddEventHandler('Job:Server:DutyRemove', function(_, source)
    OnDutyChanged(source)
end)

AddEventHandler('Characters:Server:PlayerLoggedOut', function(source)
    OnPlayerUnloaded(source)
end)

AddEventHandler('Characters:Server:PlayerDropped', function(source)
    OnPlayerUnloaded(source)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    if Started('sandbox-base') then
        SafeCall(function()
            exports['sandbox-base']:DeleteStore('Bridge', 'Jobs')
        end)
    end
end)

-- ---------------------------------------------------------------------------
-- Bridge callbacks
-- ---------------------------------------------------------------------------

function RegisterCallbacks()
    exports['sandbox-base']:RegisterServerCallback('sandbox_bridge:server:getShared', function(_, _, cb)
        local jobTypes, gangJobs = GetJobMeta()
        cb({
            jobs = QBCore.Shared.Jobs,
            gangs = SB.GetSharedGangs(),
            items = QBCore.Shared.Items,
            weapons = SB.GetSharedWeapons(),
            locations = SB.GetLocations(),
            jobTypes = jobTypes,
            gangJobs = gangJobs,
            defaultJob = Config.DefaultJob,
        })
    end)

    exports['sandbox-base']:RegisterServerCallback('sandbox_bridge:server:getPlayerData', function(source, _, cb)
        cb(SB.BuildPlayerData(source))
    end)

    exports['sandbox-base']:RegisterServerCallback('sandbox_bridge:server:getBank', function(source, _, cb)
        cb(SB.GetBank(source, true))
    end)

    exports['sandbox-base']:RegisterServerCallback('sandbox_bridge:server:setJob', function(source, data, cb)
        cb(SB.SetJob(source, data.job, data.grade, data.workplace))
    end)

    exports['sandbox-base']:RegisterServerCallback('sandbox_bridge:server:setDuty', function(source, data, cb)
        cb(SB.SetDuty(source, data.duty, data.job))
    end)
end
