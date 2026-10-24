-- sandbox-bridge-lib/server/persona_qbcore.lua
-- QBCore persona exports.

function ExportQBCorePersona()
        _G.QBCore = QBCore

        Util.AddExport('GetCoreObject', function()
            return QBCore
        end)

        return
end
