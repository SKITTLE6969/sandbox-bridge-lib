-- sandbox-bridge-lib/client/shared.lua
-- Loaded by client/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Shared tables
-- ---------------------------------------------------------------------------

function RefreshSharedItems()
    local items = SafeCall(function()
        return exports.ox_inventory:Items()
    end)
    if type(items) ~= 'table' then return end

    local qbItems = {}

    for name, item in pairs(items) do
        if type(item) == 'table' and type(name) == 'string' then
            qbItems[name] = {
                name = name,
                label = item.label or name,
                weight = item.weight or 0,
                description = item.description or '',
                image = Util.ItemImage(name, item),
                unique = item.stack == false,
                useable = true,
                shouldClose = true,
            }
        end
    end

    QBCore.Shared.Items = qbItems
end

function RequestSharedData()
    if not Started('sandbox-base') then return end
    exports['sandbox-base']:ServerCallback('sandbox_bridge:server:getShared', {}, function(result)
        if type(result) ~= 'table' then return end
        if result.jobs then QBCore.Shared.Jobs = result.jobs end
        if result.gangs then QBCore.Shared.Gangs = result.gangs end
        if result.items and not next(QBCore.Shared.Items) then QBCore.Shared.Items = result.items end
        if result.weapons then QBCore.Shared.Weapons = result.weapons end
        if result.locations then QBCore.Shared.Locations = result.locations end
        if result.jobTypes then Cache.jobTypes = result.jobTypes end
        if result.gangJobs then Cache.gangJobs = result.gangJobs end
        RefreshPlayerData()
    end)
end
