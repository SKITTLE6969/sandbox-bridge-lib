-- sandbox-bridge-lib/client/events.lua
-- Loaded by client/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

function OnPlayerLoaded()
    LocalPlayer.state.loggedIn = true
    LocalPlayer.state.isLoggedIn = true
    Cache.lastJobSignature = nil
    Cache.data = nil
    RefreshPlayerData()

    if Started('sandbox-base') then
        exports['sandbox-base']:ServerCallback('sandbox_bridge:server:getBank', {}, function(bank)
            Cache.bank = tonumber(bank) or 0
            RefreshPlayerData()
        end)
    end

    if IsPrimaryQB() then
        TriggerEvent('QBCore:Client:OnPlayerLoaded')
    end
end

function OnPlayerUnloaded()
    LocalPlayer.state.loggedIn = false
    LocalPlayer.state.isLoggedIn = false
    Cache.data = nil
    Cache.bank = 0
    Cache.lastJobSignature = nil

    if IsPrimaryQB() then
        TriggerEvent('QBCore:Client:OnPlayerUnload')
    end
end

AddEventHandler('Characters:Client:Spawn', function()
    OnPlayerLoaded()
end)

AddEventHandler('Characters:Client:Logout', function()
    OnPlayerUnloaded()
end)

lib.callback.register('sandbox_bridge:client:getVehicleClasses', function()
    local classes = {}

    for _, model in ipairs(GetAllVehicleModels()) do
        local hash = joaat(model)
        classes[hash] = GetVehicleClassFromName(hash) or 0
    end

    return classes
end)

---Starts the normal Sandbox spawn flow for a character selected through the
---framework Login export (instead of the Sandbox character NUI).
RegisterNetEvent('sandbox_bridge:client:spawnCharacter', function(cData)
    if not IsPrimaryBridge() then return end
    if type(cData) ~= 'table' or not cData.spawn then return end
    if LocalPlayer.state.loggedIn then return end
    if GetResourceState('sandbox-ped') ~= 'started' then return end

    local function finishSpawn()
        LocalPlayer.state.Char = cData.ID
        LocalPlayer.state:set('SID', cData.SID, true)
        TriggerServerEvent('Characters:Server:Spawning')
        LocalPlayer.state.loggedIn = true
    end

    TriggerEvent('Characters:Client:SetData', -1, cData, function()
        exports['sandbox-ped']:SpawnToWorld(cData, function()
            local spawnEvent = cData.spawn and cData.spawn.event
            if spawnEvent then
                exports['sandbox-base']:ServerCallback(spawnEvent, cData.spawn, finishSpawn)
            else
                finishSpawn()
            end
        end)
    end)
end)

AddEventHandler('Characters:Client:Updated', function(key)
    if not LocalPlayer.state.loggedIn then return end
    RefreshPlayerData()
end)

RegisterNetEvent('Status:Client:Update', function()
    if not LocalPlayer.state.loggedIn then return end
    RefreshPlayerData()
end)

RegisterNetEvent('Job:Client:DutyChanged', function()
    if not LocalPlayer.state.loggedIn then return end
    RefreshPlayerData()
end)

RegisterNetEvent('sandbox_bridge:client:sync', function(payload)
    if type(payload) ~= 'table' then return end
    if payload.bank ~= nil then Cache.bank = tonumber(payload.bank) or Cache.bank end
    if payload.jobTypes then Cache.jobTypes = payload.jobTypes end
    if payload.gangJobs then Cache.gangJobs = payload.gangJobs end
    if LocalPlayer.state.loggedIn then
        RefreshPlayerData()
    end
end)

RegisterNetEvent('sandbox_bridge:client:notify', function(message, notifType, duration)
    if not IsPrimaryBridge() then return end
    ShowNotification(message, notifType, duration)
end)

RegisterNetEvent('sandbox_bridge:client:revive', function()
    if not IsPrimaryBridge() then return end
    if Started('sandbox-damage') then
        SafeCall(function()
            exports['sandbox-damage']:Revive()
        end)
    end
end)

if IsPrimaryQB() then
    RegisterNetEvent('QBCore:Notify', function(message, notifType, duration)
        ShowNotification(message, notifType, duration)
    end)
end

-- QBX event bridge: keep local data fresh and let external scripts listen to
-- the same events they would get from a real qbx_core.
if IsPrimaryQB() then
    RegisterNetEvent('QBCore:Client:SetDuty', function()
        if LocalPlayer.state.loggedIn then RefreshPlayerData() end
    end)

    RegisterNetEvent('QBCore:Client:OnPermissionUpdate', function()
        if LocalPlayer.state.loggedIn then RefreshPlayerData() end
    end)

    RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
        if LocalPlayer.state.loggedIn then RefreshPlayerData() end
    end)

    RegisterNetEvent('QBCore:Client:OnGangUpdate', function()
        if LocalPlayer.state.loggedIn then RefreshPlayerData() end
    end)

    RegisterNetEvent('qbx_core:client:onGroupUpdate', function()
        if LocalPlayer.state.loggedIn then RefreshPlayerData() end
    end)

    RegisterNetEvent('QBCore:Client:OnMoneyChange', function()
        if LocalPlayer.state.loggedIn then RefreshPlayerData() end
    end)

    RegisterNetEvent('qbx_core:client:onSetMetaData', function()
        if LocalPlayer.state.loggedIn then RefreshPlayerData() end
    end)

    RegisterNetEvent('QBCore:Player:SetPlayerData', function(value)
        if type(value) == 'table' then Cache.data = value end
    end)

    RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
        LocalPlayer.state.loggedIn = false
        LocalPlayer.state.isLoggedIn = false
        Cache.data = nil
    end)
end
