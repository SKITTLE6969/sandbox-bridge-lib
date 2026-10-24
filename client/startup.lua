-- sandbox-bridge-lib/client/startup.lua
-- Loaded by client/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Startup / polling
-- ---------------------------------------------------------------------------

CreateThread(function()
    if not Started('sandbox-base') then return end

    Wait(1500)
    RefreshSharedItems()
    RequestSharedData()

    CreateThread(function()
        while true do
            Wait(10000)
            if LocalPlayer.state.loggedIn and not next(QBCore.Shared.Jobs) then
                RequestSharedData()
            end
        end
    end)

    CreateThread(function()
        while true do
            Wait(60000)
            RefreshSharedItems()
        end
    end)

    CreateThread(function()
        local interval = math.max(1, Config.ClientRefreshSeconds or 2) * 1000
        while true do
            Wait(interval)
            if LocalPlayer.state.loggedIn then
                RefreshPlayerData()
            end
        end
    end)
end)

print(('[sandbox-bridge] %s client persona ready'):format(RESOURCE))
