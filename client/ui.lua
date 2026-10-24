-- sandbox-bridge-lib/client/ui.lua
-- Loaded by client/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Notifications / text UI
-- ---------------------------------------------------------------------------

function ShowNotification(message, notifType, duration)
    notifType = Util.NotifyType(notifType)
    duration = duration or Config.NotifyDuration or 5000

    if Started('sandbox-hud') then
        SafeCall(function()
            exports['sandbox-hud']:Notification(notifType, message, duration)
        end)
        return
    end

    SafeCall(function()
        exports.ox_lib:notify({
            description = message,
            type = notifType == 'info' and 'inform' or notifType,
            duration = duration,
        })
    end)
end

function ShowText(message, duration)
    if Started('sandbox-hud') then
        SafeCall(function()
            exports['sandbox-hud']:ActionShow('sandbox-bridge', message, duration or 60000)
        end)
    else
        SafeCall(function()
            exports.ox_lib:showTextUI(message)
        end)
    end
end

function HideText()
    if Started('sandbox-hud') then
        SafeCall(function()
            exports['sandbox-hud']:ActionHide('sandbox-bridge')
        end)
    else
        SafeCall(function()
            exports.ox_lib:hideTextUI()
        end)
    end
end

