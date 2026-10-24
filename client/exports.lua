-- sandbox-bridge-lib/client/exports.lua
-- Registers the QBCore and QBX client export sets from this single resource.

SB = SB or {}

function ExportPersona()
    ExportQbxPersona()
    ExportQBCorePersona()

    Util.AddExport('GetBridge', function() return QBCore end)

    -- Compatibility modules for Sandbox resources --------------------------
    Util.AddExport('GetSandboxBridge', function() return SB end)
    Util.AddExport('GetDispatch', function() return SB.Dispatch end)
    Util.AddExport('GetTarget', function() return SB.Target end)
    Util.AddExport('GetVehicleKey', function() return SB.VehicleKey end)
    Util.AddExport('GetFuel', function() return SB.Fuel end)
    Util.AddExport('GetClothing', function() return SB.Clothing end)
    Util.AddExport('GetProgressBar', function() return SB.ProgressBar end)
    Util.AddExport('GetNotify', function() return SB.Notify end)
    Util.AddExport('GetWeather', function() return SB.Weather end)
    Util.AddExport('GetSkills', function() return SB.Skills end)
    Util.AddExport('GetDev', function() return SB.Dev end)

    -- QBox passes a table, QBCore passes a string; accept both signatures.
    Util.AddExport('Notify', function(text, notifyType, duration, ...)
        if type(text) == 'table' then
            return QBoxNotify(text, notifyType, duration, ...)
        end
        return ShowNotification(text, notifyType, duration)
    end)

    -- ESX client compatibility
    ExportESXPersona()
end

ExportPersona()
