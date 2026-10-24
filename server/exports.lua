-- sandbox-bridge-lib/server/exports.lua
-- Registers the QBCore and QBX export sets from this single resource.

function ExportPersona()
    ExportQbxPersona()
    ExportQBCorePersona()

    -- Both provided names resolve to this resource, so expose one bridge
    -- object that also carries the QBCore object and its shared tables.
    SB.Shared = QBCore.Shared
    SB.Functions = QBCore.Functions
    SB.Commands = QBCore.Commands
    SB.Config = QBCore.Config

    Util.AddExport('GetBridge', function() return SB end)

    -- Compatibility modules for Sandbox resources --------------------------
    Util.AddExport('GetDispatch', function() return SB.Dispatch end)
    Util.AddExport('GetMDT', function() return SB.MDT end)
    Util.AddExport('GetDoorlock', function() return SB.Doorlock end)
    Util.AddExport('GetVehicleKey', function() return SB.VehicleKey end)
    Util.AddExport('GetClothing', function() return SB.Clothing end)
    Util.AddExport('GetSkills', function() return SB.Skills end)

    Util.AddExport('SendDispatch', function(data, options)
        return SB.Dispatch.SendAlert(data, options)
    end)

    Util.AddExport('GetDispatchCalls', function(filters)
        return SB.Dispatch.GetCalls(filters)
    end)

    Util.AddExport('GetDispatchStats', function()
        return SB.Dispatch.GetStats()
    end)

    Util.AddExport('GetAudit', function()
        return SB.Audit and SB.Audit() or nil
    end)

    ExportESXPersona()

    -- Some ESX scripts call exports.es_extended:GetPlayerFromId
    Util.AddExport('GetPlayerFromId', function(src)
        if ESX and ESX.GetPlayerFromId then return ESX.GetPlayerFromId(src) end
        return nil
    end)
    Util.AddExport('GetPlayerFromIdentifier', function(identifier)
        if ESX and ESX.GetPlayerFromIdentifier then return ESX.GetPlayerFromIdentifier(identifier) end
        return nil
    end)
    Util.AddExport('GetExtendedPlayers', function(key, value)
        if ESX and ESX.GetExtendedPlayers then return ESX.GetExtendedPlayers(key, value) end
        return {}
    end)
end

ExportPersona()
