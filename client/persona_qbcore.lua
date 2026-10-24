-- sandbox-bridge-lib/client/persona_qbcore.lua
-- QBCore client exports.

function ExportQBCorePersona()
        _G.QBCore = QBCore

        Util.AddExport('GetCoreObject', function()
            return QBCore
        end)
        Util.AddExport('DrawText', function(message, position, icon)
            ShowText(message)
        end)
        Util.AddExport('HideText', function()
            HideText()
        end)
        return
end
