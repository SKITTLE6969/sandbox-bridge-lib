-- sandbox-bridge-lib/server/persona_qbx.lua
-- QBX Core persona exports.

function ExportQbxPersona()
        _G.QBox = SB

        -- Shared exports -----------------------------------------------------
        Util.AddExport('GetJobs', function() return SB.GetSharedJobs() end)
        Util.AddExport('GetGangs', function() return SB.GetSharedGangs() end)
        Util.AddExport('GetJob', function(name) return SB.GetSharedJobs()[name] end)
        Util.AddExport('GetGang', function(name) return SB.GetSharedGangs()[name] end)
        Util.AddExport('GetVehiclesByName', function(vehicle) return SB.GetVehiclesByName(vehicle) end)
        Util.AddExport('GetVehiclesByHash', function(vehicle) return SB.GetVehiclesByHash(vehicle) end)
        Util.AddExport('GetVehiclesByCategory', function() return SB.GetVehiclesByCategory() end)
        Util.AddExport('GetWeapons', function(weapon)
            local weapons = SB.GetSharedWeapons()
            return weapon and weapons[weapon] or weapons
        end)
        Util.AddExport('GetLocations', function() return SB.GetLocations() end)

        -- Player / server exports -------------------------------------------
        Util.AddExport('GetPlayer', function(src) return SB.GetPlayer(src) end)
        Util.AddExport('GetPlayerByCitizenId', function(citizenid) return SB.GetPlayerByCitizenId(citizenid) end)
        Util.AddExport('GetPlayerByUserId', function(userId)
            return SB.GetPlayerByAccountId(userId) or SB.GetPlayerByCitizenId(userId)
        end)
        Util.AddExport('GetPlayerByPhone', function(phone) return SB.GetPlayerByPhone(phone) end)
        Util.AddExport('GetPlayerByAccountId', function(accountId) return SB.GetPlayerByAccountId(accountId) end)
        Util.AddExport('GetPlayerByLicense', function(license) return SB.GetPlayerByLicense(license) end)
        Util.AddExport('GetPlayers', function() return SB.GetPlayers() end)
        Util.AddExport('GetQBPlayers', function() return SB.GetQBPlayers() end)
        Util.AddExport('GetPlayersData', function() return SB.GetPlayersData() end)
        Util.AddExport('SetPlayerData', function(identifier, key, value)
            local src = SB.ResolveSource(identifier)
            if src then return SB.SetPlayerData(src, key, value) end

            local data = ResolveOfflinePlayerData(identifier)
            if not data then return false end
            data[key] = value
            return SB.SaveOffline(data)
        end)
        Util.AddExport('UpdatePlayerData', function(identifier)
            local src = SB.ResolveSource(identifier)
            if src then return SB.UpdatePlayerData(src) end
            return ResolveOfflinePlayerData(identifier) ~= nil
        end)
        Util.AddExport('GetMetadata', function(identifier, metadata)
            local src = SB.ResolveSource(identifier)
            if src then return SB.GetMetadata(src, metadata) end

            local data = ResolveOfflinePlayerData(identifier)
            return data and ResolveMetadataValue(data.metadata, metadata) or nil
        end)
        Util.AddExport('SetMetadata', function(identifier, metadata, value)
            local src = SB.ResolveSource(identifier)
            if src then return SB.SetMetadata(src, metadata, value) end

            local data = ResolveOfflinePlayerData(identifier)
            if not data then return false end

            SetOfflineMetadataValue(data, metadata, value)
            if metadata == 'optin' then data.optin = value == true end
            return SB.SaveOffline(data)
        end)
        Util.AddExport('SetCharInfo', function(identifier, charInfo, value)
            local src = SB.ResolveSource(identifier)
            if src then return SB.SetCharInfo(src, charInfo, value) end

            local data = ResolveOfflinePlayerData(identifier)
            if not data then return false end

            local field = CHAR_INFO_FIELDS[charInfo]
            if not field then return false end

            local map = {
                First = 'firstname',
                Last = 'lastname',
                DOB = 'birthdate',
                Gender = 'gender',
                Phone = 'phone',
                Origin = 'nationality',
                Bio = 'backstory',
                BankAccount = 'account',
                SID = 'cid',
            }

            local key = map[field]
            if not key then return false end

            data.charinfo[key] = value
            return SB.SaveOffline(data)
        end)
        Util.AddExport('GetSource', function(identifier) return SB.GetSource(identifier) end)
        Util.AddExport('GetUserId', function(identifier) return SB.GetUserId(identifier) end)
        Util.AddExport('GetCoreVersion', function() return SB.GetCoreVersion() end)
        Util.AddExport('ExploitBan', function(playerId, origin) SB.ExploitBan(playerId, origin) end)
        Util.AddExport('IsWhitelisted', function(src) return SB.IsWhitelisted(src) end)
        Util.AddExport('IsPlayerBanned', function(src) return SB.IsPlayerBanned(src) end)
        Util.AddExport('IsOptin', function(src) return SB.IsOptin(src) end)
        Util.AddExport('ToggleOptin', function(src) return SB.ToggleOptin(src) end)
        Util.AddExport('GetPermission', function(src) return SB.GetPermission(src) end)
        Util.AddExport('HasPermission', function(src, permission) return SB.HasPermission(src, permission) end)
        Util.AddExport('AddPermission', function(src, permission) return QBCore.Functions.AddPermission(src, permission) end)
        Util.AddExport('RemovePermission', function(src, permission) return QBCore.Functions.RemovePermission(src, permission) end)
        Util.AddExport('Notify', function(src, text, notifyType, duration, subTitle, notifyPosition, notifyStyle, notifyIcon, notifyIconColor)
            SB.NotifyFull(src, text, notifyType, duration, subTitle, notifyPosition, notifyStyle, notifyIcon, notifyIconColor)
        end)

        Util.AddExport('GetDutyCountJob', function(job) return SB.GetDutyCountJob(job) end)
        Util.AddExport('GetDutyCountType', function(jobType) return SB.GetDutyCountType(jobType) end)
        Util.AddExport('GetBucketObjects', function() return SB.GetBucketObjects() end)
        Util.AddExport('SetPlayerBucket', function(source, bucket) return SB.SetPlayerBucket(source, bucket) end)
        Util.AddExport('SetEntityBucket', function(entity, bucket) return SB.SetEntityBucket(entity, bucket) end)
        Util.AddExport('GetPlayersInBucket', function(bucket) return SB.GetPlayersInBucket(bucket) end)
        Util.AddExport('GetEntitiesInBucket', function(bucket) return SB.GetEntitiesInBucket(bucket) end)

        Util.AddExport('CreateUseableItem', function(itemName, callback) return RegisterUseableItem(itemName, callback) end)
        Util.AddExport('CanUseItem', function(itemName) return useableItems[itemName] end)

        Util.AddExport('Login', function(source, citizenid, newData) return SB.Login(source, citizenid, newData) end)
        Util.AddExport('Logout', function(source) return SB.Logout(source) end)
        Util.AddExport('CreatePlayer', function(playerData, offline) return SB.CreatePlayer(playerData, offline) end)
        Util.AddExport('GetOfflinePlayer', function(citizenid) return SB.GetOfflinePlayer(citizenid) end)
        Util.AddExport('Save', function(source) return SB.Save(source) end)
        Util.AddExport('SaveOffline', function(playerData) return SB.SaveOffline(playerData) end)
        Util.AddExport('DeleteCharacter', function(citizenid) return SB.DeleteCharacter(citizenid) end)
        Util.AddExport('GenerateUniqueIdentifier', function(identifierType) return SB.GenerateUniqueIdentifier(identifierType) end)

        -- Job / gang management --------------------------------------------
        Util.AddExport('CreateJob', function(jobName, job) return SB.CreateJob(jobName, job) end)
        Util.AddExport('CreateJobs', function(jobs) return SB.CreateJobs(jobs) end)
        Util.AddExport('RemoveJob', function(jobName) return SB.RemoveJob(jobName) end)
        Util.AddExport('CreateGangs', function(gangs) return SB.CreateGangs(gangs) end)
        Util.AddExport('RemoveGang', function(gangName) return SB.RemoveGang(gangName) end)
        Util.AddExport('UpsertJobData', function(jobName, data) return SB.UpsertJobData(jobName, data) end)
        Util.AddExport('UpsertGangData', function(gangName, data) return SB.UpsertGangData(gangName, data) end)
        Util.AddExport('UpsertJobGrade', function(jobName, grade, data) return SB.UpsertJobGrade(jobName, grade, data) end)
        Util.AddExport('UpsertGangGrade', function(gangName, grade, data) return SB.UpsertGangGrade(gangName, grade, data) end)
        Util.AddExport('RemoveJobGrade', function(jobName, grade) return SB.RemoveJobGrade(jobName, grade) end)
        Util.AddExport('RemoveGangGrade', function(gangName, grade) return SB.RemoveGangGrade(gangName, grade) end)
        Util.AddExport('SetJob', function(identifier, jobName, grade) return SB.SetJobByIdentifier(identifier, jobName, grade) end)
        Util.AddExport('SetJobDuty', function(identifier, onDuty)
            local src = SB.ResolveSource(identifier)
            if src then return SB.SetJobDuty(src, onDuty) end

            local data = ResolveOfflinePlayerData(identifier)
            if not data then return false end
            data.job.onduty = onDuty and true or false
            return SB.SaveOffline(data)
        end)
        Util.AddExport('SetPlayerPrimaryJob', function(citizenid, jobName)
            local src = SB.ResolveSource(citizenid)
            if src then return SB.SetPlayerPrimaryJob(citizenid, jobName) end

            local data = ResolveOfflinePlayerData(citizenid)
            if not data then return false end

            local grade = data.jobs[jobName]
            if grade == nil then return false end

            local built = BuildOfflineJobEntry(data, jobName, grade)
            if not built then return false end

            data.job = built.entry
            return SB.SaveOffline(data)
        end)
        Util.AddExport('AddPlayerToJob', function(citizenid, jobName, grade)
            local src = SB.ResolveSource(citizenid)
            if src then return SB.AddPlayerToJob(citizenid, jobName, grade) end

            local data = ResolveOfflinePlayerData(citizenid)
            if not data then return false end

            local built = BuildOfflineJobEntry(data, jobName, grade)
            if not built then return false end

            data.jobs[jobName] = built.level
            if data.job.name == 'unemployed' or data.job.name == jobName then
                data.job = built.entry
            end
            return SB.SaveOffline(data)
        end)
        Util.AddExport('RemovePlayerFromJob', function(citizenid, jobName)
            local src = SB.ResolveSource(citizenid)
            if src then return SB.RemovePlayerFromJob(citizenid, jobName) end

            local data = ResolveOfflinePlayerData(citizenid)
            if not data then return false end

            data.jobs[jobName] = nil
            if data.job.name == jobName then data.job = DefaultJob() end
            return SB.SaveOffline(data)
        end)
        Util.AddExport('SetGang', function(identifier, gangName, grade) return SB.SetGang(identifier, gangName, grade) end)
        Util.AddExport('SetPlayerPrimaryGang', function(citizenid, gangName)
            local src = SB.ResolveSource(citizenid)
            if src then return SB.SetPlayerPrimaryGang(citizenid, gangName) end

            local data = ResolveOfflinePlayerData(citizenid)
            if not data then return false end

            local grade = data.gangs[gangName]
            if grade == nil then return false end

            local built = BuildOfflineGangEntry(data, gangName, grade)
            if not built then return false end

            data.gang = built.entry
            return SB.SaveOffline(data)
        end)
        Util.AddExport('AddPlayerToGang', function(citizenid, gangName, grade)
            local src = SB.ResolveSource(citizenid)
            if src then return SB.AddPlayerToGang(citizenid, gangName, grade) end

            local data = ResolveOfflinePlayerData(citizenid)
            if not data then return false end

            local built = BuildOfflineGangEntry(data, gangName, grade)
            if not built then return false end

            data.gangs[gangName] = built.level
            if data.gang.name == 'none' or data.gang.name == gangName then
                data.gang = built.entry
            end
            return SB.SaveOffline(data)
        end)
        Util.AddExport('RemovePlayerFromGang', function(citizenid, gangName)
            local src = SB.ResolveSource(citizenid)
            if src then return SB.RemovePlayerFromGang(citizenid, gangName) end

            local data = ResolveOfflinePlayerData(citizenid)
            if not data then return false end

            data.gangs[gangName] = nil
            if data.gang.name == gangName then
                data.gang = {
                    name = 'none',
                    label = 'No Gang',
                    isboss = false,
                    grade = { name = 'none', label = 'None', level = 0 },
                }
            end
            return SB.SaveOffline(data)
        end)
        Util.AddExport('HasPrimaryGroup', function(source, filter) return SB.HasPrimaryGroup(source, filter) end)
        Util.AddExport('HasGroup', function(source, filter) return SB.HasGroup(source, filter) end)
        Util.AddExport('GetGroups', function(source) return SB.GetGroups(source) end)
        Util.AddExport('IsGradeBoss', function(group, grade) return SB.IsGradeBoss(group, grade) end)
        Util.AddExport('GetGroupMembers', function(group, groupType) return SB.GetGroupMembers(group, groupType) end)

        -- Vehicles / players ------------------------------------------------
        Util.AddExport('DeleteVehicle', function(entity) return SB.DeleteVehicle(entity) end)
        Util.AddExport('EnablePersistence', function(entity) return SB.EnablePersistence(entity) end)
        Util.AddExport('DisablePersistence', function(entity) return SB.DisablePersistence(entity) end)
        Util.AddExport('GetVehicleClass', function(hash) return SB.GetVehicleClass(hash) end)
        Util.AddExport('CreateSessionId', function(entity) return SB.CreateSessionId(entity) end)
        Util.AddExport('SearchPlayers', function(filters) return SB.SearchPlayers(filters) end)

        Util.AddExport('GetMoney', function(identifier, moneyType)
            local src = SB.ResolveSource(identifier)
            if src then return SB.GetMoney(src, moneyType) end

            local data = ResolveOfflinePlayerData(identifier)
            if not data then return false end
            return data.money[Util.NormalizeAccount(moneyType)] or 0
        end)
        Util.AddExport('AddMoney', function(identifier, moneyType, amount, reason)
            local src = SB.ResolveSource(identifier)
            if src then return SB.AddMoney(src, moneyType, amount, reason) end

            local data = ResolveOfflinePlayerData(identifier)
            if not data then return false end

            local account = Util.NormalizeAccount(moneyType)
            amount = tonumber(amount) or 0
            if amount <= 0 then return false end

            data.money[account] = (data.money[account] or 0) + amount
            return SB.SaveOffline(data)
        end)
        Util.AddExport('RemoveMoney', function(identifier, moneyType, amount, reason)
            local src = SB.ResolveSource(identifier)
            if src then return SB.RemoveMoney(src, moneyType, amount, reason) end

            local data = ResolveOfflinePlayerData(identifier)
            if not data then return false end

            local account = Util.NormalizeAccount(moneyType)
            amount = tonumber(amount) or 0
            if amount <= 0 then return false end

            data.money[account] = (data.money[account] or 0) - amount
            return SB.SaveOffline(data)
        end)
        Util.AddExport('SetMoney', function(identifier, moneyType, amount, reason)
            local src = SB.ResolveSource(identifier)
            if src then return SB.SetMoney(src, moneyType, amount, reason) end

            local data = ResolveOfflinePlayerData(identifier)
            if not data then return false end

            data.money[Util.NormalizeAccount(moneyType)] = tonumber(amount) or 0
            return SB.SaveOffline(data)
        end)

        -- Extra convenience exports used by the bridge / community scripts --
        Util.AddExport('GetPlayerData', function(src) return SB.BuildPlayerData(src) end)
        Util.AddExport('GetPlayerIdentifier', function(src)
            local data = SB.BuildPlayerData(src)
            return data and data.citizenid or nil
        end)
        Util.AddExport('GetPlayerName', function(src)
            local data = SB.BuildPlayerData(src)
            if not data then return 'Unknown' end
            return data.charinfo.firstname, data.charinfo.lastname
        end)
        Util.AddExport('GetPlayerCoords', function(src)
            local ped = GetPlayerPed(src)
            return ped > 0 and GetEntityCoords(ped) or nil
        end)
        return
end
