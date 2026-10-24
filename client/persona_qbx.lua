-- sandbox-bridge-lib/client/persona_qbx.lua
-- QBX Core client exports.

function ExportQbxPersona()
        _G.QBox = {
            GetPlayerData = GetPlayerData,
            GetJobs = function() return QBCore.Shared.Jobs end,
            GetGangs = function() return QBCore.Shared.Gangs end,
            GetJob = function(name) return QBCore.Shared.Jobs[name] end,
            GetGang = function(name) return QBCore.Shared.Gangs[name] end,
            Notify = QBoxNotify,
            GetPlayer = function(source) return QBCore.Functions.GetPlayer(source) end,
            GetGroups = function() return GetClientGroups() end,
            HasGroup = function(filter) return ClientMatchesGroupFilter(filter, GetClientGroups(), GetClientCitizenId()) end,
            HasPrimaryGroup = function(filter) return ClientMatchesGroupFilter(filter, GetClientPrimaryGroups(), GetClientCitizenId()) end,
        }

        Util.AddExport('GetPlayerData', function() return GetPlayerData() end)
        Util.AddExport('GetJobs', function() return QBCore.Shared.Jobs end)
        Util.AddExport('GetGangs', function() return QBCore.Shared.Gangs end)
        Util.AddExport('GetJob', function(name) return QBCore.Shared.Jobs[name] end)
        Util.AddExport('GetGang', function(name) return QBCore.Shared.Gangs[name] end)
        QBCore.Shared.Vehicles = GetClientVehicleCatalog()
        QBCore.Shared.VehicleHashes = GetClientVehicleHashes()

        Util.AddExport('GetVehiclesByName', function(vehicle)
            local catalog = GetClientVehicleCatalog()
            return vehicle and catalog[vehicle] or catalog
        end)
        Util.AddExport('GetVehiclesByHash', function(vehicle)
            local hashes = GetClientVehicleHashes()
            return vehicle and hashes[tonumber(vehicle) or vehicle] or hashes
        end)
        Util.AddExport('GetVehiclesByCategory', function() return GetClientVehicleCategories() end)
        Util.AddExport('GetWeapons', function(weapon)
            return weapon and QBCore.Shared.Weapons[weapon] or QBCore.Shared.Weapons
        end)
        Util.AddExport('GetLocations', function() return QBCore.Shared.Locations end)

        Util.AddExport('HasPrimaryGroup', function(filter)
            return ClientMatchesGroupFilter(filter, GetClientPrimaryGroups(), GetClientCitizenId())
        end)
        Util.AddExport('HasGroup', function(filter)
            return ClientMatchesGroupFilter(filter, GetClientGroups(), GetClientCitizenId())
        end)
        Util.AddExport('GetGroups', function() return GetClientGroups() end)
        Util.AddExport('GetPlayer', function(source) return QBCore.Functions.GetPlayer(source) end)
        return
end
