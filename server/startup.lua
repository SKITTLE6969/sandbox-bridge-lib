-- sandbox-bridge-lib/server/startup.lua
-- Loaded by server/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------

initialized = false

function Init()
    if initialized then return end
    initialized = true

    -- sandbox-jobs populates JOB_CACHE one second after it starts. Give it a
    -- moment so QBCore.Shared.Jobs are not empty on first use.
    local waited = 0
    while not next(GetJobDefinitions()) and waited < 15000 do
        Wait(500)
        waited = waited + 500
        jobCache.time = 0
    end

    RefreshSharedItems()
    RefreshSharedJobs()

    QBCore.Shared.Vehicles = GetVehicleCatalog()
    QBCore.Shared.VehicleHashes = GetVehicleHashMap()

    exports['sandbox-base']:MiddlewareAdd('Characters:CharacterSelected', function(source)
        OnPlayerLoaded(source)
    end, 1)

    exports['sandbox-base']:MiddlewareAdd('Characters:Logout', function(source)
        OnPlayerUnloaded(source)
    end, 1)

    exports['sandbox-base']:MiddlewareAdd('playerDropped', function(source)
        OnPlayerUnloaded(source)
    end, 1)

    RegisterCallbacks()

    -- Keep the shared job/item tables warm for QBCore/QBX scripts.
    CreateThread(function()
        while true do
            Wait(60000)
            RefreshSharedJobs()
            RefreshSharedItems()
            jobCache.time = 0
        end
    end)

    -- Push fresh bank balances so client side UI code has accurate numbers.
    -- Only the primary persona sends this because the client event is global
    -- and every persona client listens to the same event name.
    CreateThread(function()
        local interval = math.max(5, Config.BankSyncSeconds or 30) * 1000
        while true do
            Wait(interval)
            if IsPrimaryBridge() and Started('sandbox-base') then
                local all = SafeCall(function()
                    return exports['sandbox-base']:GetAllPlayers()
                end) or {}

                for src in pairs(all) do
                    if GetCharacter(src) then
                        TriggerClientEvent('sandbox_bridge:client:sync', src, { bank = SB.GetBank(src, true) })
                    end
                end
            end
        end
    end)

    print(('[sandbox-bridge] %s ready - providing qb-core and qbx_core'):format(RESOURCE))

    -- Run the integration audit at startup so a missing backend or a broken
    -- forced resource is logged instead of silently falling back. It always
    -- prints problems; the full per-module report only prints in debug mode.
    CreateThread(function()
        Wait(2000)
        local report = SB.Audit and SB.Audit()
        if not report then return end
        if Config.Debug then
            SB.PrintAudit()
        elseif #report.problems > 0 then
            for _, problem in ipairs(report.problems) do
                print(('[sandbox-bridge] integration warning: %s'):format(problem))
            end
            print('[sandbox-bridge] run /bridgeaudit for the full integration report')
        end
    end)

    RegisterCommand('bridgeinfo', function(source)
        local jobCount = 0
        for _ in pairs(SB.GetSharedJobs()) do jobCount = jobCount + 1 end
        local players = SB.GetPlayers()
        local message = ('[sandbox-bridge] persona=%s jobs=%s players=%s'):format(
            RESOURCE,
            jobCount,
            #players
        )
        print(message)
        if source and tonumber(source) and tonumber(source) > 0 then
            SB.Notify(source, message, 'info', 10000)
        end
    end, true)

    RegisterCommand('bridgeaudit', function(source)
        local report = SB.PrintAudit()
        if source and tonumber(source) and tonumber(source) > 0 then
            local lines = { ('audit: %d problem(s)'):format(#report.problems) }
            for label, entry in pairs(report.modules) do
                lines[#lines + 1] = ('%s=%s (%d/%d)'):format(label, tostring(entry.selected), #entry.started, entry.supported)
            end
            for _, problem in ipairs(report.problems) do
                lines[#lines + 1] = 'PROBLEM: ' .. problem
            end
            SB.Notify(source, table.concat(lines, '\n'), #report.problems > 0 and 'warning' or 'success', 15000)
        end
    end, true)
end

CreateThread(function()
    if not Started('sandbox-base') then
        print(('[sandbox-bridge] %s could not start: sandbox-base is not running.'):format(RESOURCE))
        return
    end

    -- Renewed-Banking is optional: the bridge boots without it and bank
    -- mutations degrade gracefully (see EnsureBankAccount and money.lua).
    -- Only hard dependencies block startup.
    while not Started('sandbox-characters')
        or not Started('sandbox-jobs')
        or not Started('ox_inventory') do
        Wait(1000)
    end

    Wait(1000)
    Init()
end)
