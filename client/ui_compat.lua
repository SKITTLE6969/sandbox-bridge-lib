-- sandbox-bridge-lib/client/ui_compat.lua
-- Loaded by client/main.lua in the shared bridge environment.
--
-- ProgressBar, Notify and Weather compatibility. Each module picks the first
-- started resource from its configured priority list and falls back to the
-- Sandbox/bridge UI when no third-party resource is available.

SB = SB or {}

local Compat = SandboxBridgeCompat

-- ---------------------------------------------------------------------------
-- Progress bar
-- ---------------------------------------------------------------------------

ProgressBar = {}
SB.ProgressBar = ProgressBar

local function ProgressConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.ProgressBar) or {}
end

function ProgressBar.GetAvailableResources()
    return Compat.GetStarted(Compat.ProgressBarResources)
end

function ProgressBar.GetResourceName()
    local config = ProgressConfig()
    if config.Enabled == false then return 'disabled' end
    local active = Compat.SelectConfigured(config, Compat.ProgressBarResources)
    return active or 'default'
end

function ProgressBar.GetBackend()
    return ProgressBar.GetResourceName()
end

---Convert QB and ox progress options into one internal ox-style table.
---@param options table|nil
---@param isQBInput boolean|nil
---@return table
function ProgressBar.Normalize(options, isQBInput)
    options = type(options) == 'table' and options or {}

    local qb = isQBInput == true
        or options.controlDisables ~= nil
        or options.animation ~= nil
        or (options.prop ~= nil and options.prop.model ~= nil)

    local normalized = {
        duration = tonumber(options.duration) or 5000,
        label = options.label or options.text or options.name or 'Working...',
        position = options.position or 'bottom',
        useWhileDead = options.useWhileDead == true,
        canCancel = options.canCancel ~= false,
        forceOverride = options.forceOverride == true,
        style = options.style or 'bar',
        icon = options.icon,
        description = options.description,
    }

    if qb then
        local controls = options.controlDisables or options.disable or {}
        normalized.disable = {
            move = controls.disableMovement == true or controls.move == true,
            car = controls.disableCarMovement == true or controls.car == true,
            combat = controls.disableCombat == true or controls.combat == true,
            mouse = controls.disableMouse == true or controls.mouse == true,
        }

        local animation = options.animation or options.anim or {}
        normalized.anim = {
            dict = animation.animDict or animation.dict,
            clip = animation.anim or animation.clip,
            flag = animation.flags or animation.flag or 49,
        }

        local props = {}
        if type(options.prop) == 'table' and options.prop.model then
            props[#props + 1] = {
                model = options.prop.model,
                bone = options.prop.bone,
                pos = options.prop.coords,
                rot = options.prop.rotation,
            }
        end
        if type(options.propTwo) == 'table' and options.propTwo.model then
            props[#props + 1] = {
                model = options.propTwo.model,
                bone = options.propTwo.bone,
                pos = options.propTwo.coords,
                rot = options.propTwo.rotation,
            }
        end
        normalized.prop = props
    else
        normalized.disable = options.disable or {}
        normalized.anim = options.anim or {}
        normalized.prop = options.prop or {}
        if normalized.anim and normalized.anim.dict == nil then
            normalized.anim.dict = normalized.anim.animDict
        end
        if normalized.anim and normalized.anim.clip == nil then
            normalized.anim.clip = normalized.anim.anim
        end
    end

    return normalized
end

local function ToQB(options)
    local prop = type(options.prop) == 'table' and (options.prop[1] or options.prop) or {}
    local propTwo = type(options.prop) == 'table' and options.prop[2] or nil
    local disable = options.disable or {}
    local anim = options.anim or {}

    return {
        name = options.label,
        label = options.label,
        duration = options.duration,
        useWhileDead = options.useWhileDead,
        canCancel = options.canCancel,
        controlDisables = {
            disableMovement = disable.move == true,
            disableCarMovement = disable.car == true,
            disableMouse = disable.mouse == true,
            disableCombat = disable.combat == true,
        },
        animation = {
            animDict = anim.dict,
            anim = anim.clip,
            flags = anim.flag or 49,
            task = anim.task,
            playEnter = anim.playEnter,
        },
        prop = {
            model = prop.model,
            bone = prop.bone,
            coords = prop.pos,
            rotation = prop.rot,
        },
        propTwo = propTwo and {
            model = propTwo.model,
            bone = propTwo.bone,
            coords = propTwo.pos,
            rotation = propTwo.rot,
        } or nil,
    }
end

local function ToLation(options)
    local qb = ToQB(options)
    qb.description = options.description
    qb.icon = options.icon
    qb.position = options.position
    return qb
end

local function ToZSX(options)
    local qb = ToQB(options)
    local disable = options.disable or {}
    return {
        label = options.label,
        duration = options.duration or 5000,
        canCancel = options.canCancel,
        disableControls = {
            disable_mouse = disable.mouse == true,
            disable_walk = disable.move == true,
            disable_driving = disable.car == true,
            disable_combat = disable.combat == true,
        },
        anim = options.anim and {
            dict = options.anim.dict,
            clip = options.anim.clip,
            flag = options.anim.flag or 49,
        } or nil,
        prop1 = qb.prop and qb.prop.model and {
            model = qb.prop.model,
            bone = qb.prop.bone,
            pos = qb.prop.coords,
            rot = qb.prop.rotation,
        } or nil,
        prop2 = qb.propTwo and qb.propTwo.model and {
            model = qb.propTwo.model,
            bone = qb.propTwo.bone,
            pos = qb.propTwo.coords,
            rot = qb.propTwo.rotation,
        } or nil,
    }
end

local function ToMsk(options)
    local disable = options.disable or {}
    local anim = options.anim or {}
    return {
        duration = options.duration,
        text = options.label,
        disable = {
            move = disable.move == true,
            vehicle = disable.car == true,
            combat = disable.combat == true,
            mouse = disable.mouse == true,
        },
        animation = (anim.dict and anim.clip) and {
            dict = anim.dict,
            anim = anim.clip,
            flag = anim.flag or 49,
        } or nil,
        forceOverride = options.forceOverride == true,
    }
end

local function AwaitCallback(invoke)
    if type(promise) ~= 'table' or type(Citizen) ~= 'table' or type(Citizen.Await) ~= 'function' then
        invoke(function() end)
        return true
    end

    local wait = promise.new()
    invoke(function(success) wait:resolve(success == true) end)
    return Citizen.Await(wait)
end

local ProgressAdapters = {}

ProgressAdapters['ox_lib'] = function(options, callback)
    local success
    if options.style == 'circle' then
        success = exports.ox_lib:progressCircle(options)
    else
        success = exports.ox_lib:progressBar(options)
    end
    if callback then callback(success == true) end
    return success == true
end

ProgressAdapters['keep-progressbar'] = function(options, callback)
    local success = exports['keep-progressbar']:ox_lib_progressBar(options)
    if callback then callback(success == true) end
    return success == true
end

ProgressAdapters['progressbar'] = function(options, callback)
    return AwaitCallback(function(done)
        exports['progressbar']:Progress(ToQB(options), function(cancelled)
            local success = cancelled ~= true
            if callback then callback(success) end
            done(success)
        end)
    end)
end

ProgressAdapters['lation_ui'] = function(options, callback)
    local success = exports.lation_ui:progressBar(ToLation(options))
    if callback then callback(success ~= false) end
    return success ~= false
end

ProgressAdapters['wasabi_uikit'] = function(options, callback)
    local style = options.style == 'circle' and 'circle' or 'bar'
    local success = exports.wasabi_uikit:ProgressBar(options, style)
    if callback then callback(success ~= false) end
    return success ~= false
end

ProgressAdapters['ZSX_UIV2'] = function(options, callback)
    return AwaitCallback(function(done)
        local data = ToZSX(options)
        exports['ZSX_UIV2']:ProgressBar(
            'fas fa-circle-notch',
            data.label,
            data.duration,
            function()
                if callback then callback(true) end
                done(true)
            end,
            function()
                if callback then callback(false) end
                done(false)
            end,
            data.canCancel,
            data.disableControls,
            data.anim,
            data.prop1,
            data.prop2
        )
    end)
end

ProgressAdapters['msk_core'] = function(options, callback)
    exports.msk_core:Progressbar(ToMsk(options))
    local success = exports.msk_core:ProgressActive() ~= true
    if callback then callback(success) end
    return success
end

---Run a progress bar and block until it finishes.
---@param options table
---@param callback function|nil receives the success boolean
---@param isQBInput boolean|nil set when `options` uses QBCore's progressbar shape
---@return boolean success
function ProgressBar.Open(options, callback, isQBInput)
    local normalized = ProgressBar.Normalize(options, isQBInput)
    local backend = ProgressBar.GetResourceName()
    local adapter = ProgressAdapters[backend]

    if adapter then
        local ok, success = pcall(adapter, normalized, callback)
        if ok and success ~= nil then return success == true end
    end

    -- Native fallback: honour the duration and the cancel control.
    local duration = math.max(0, tonumber(normalized.duration) or 0)
    local deadline = GetGameTimer() + duration
    local success = true

    if normalized.canCancel and duration > 0 then
        while GetGameTimer() < deadline do
            Wait(0)
            DisableControlAction(0, 200, true) -- ESC / pause menu
            if IsControlJustPressed(0, 200) then
                success = false
                break
            end
        end
    elseif duration > 0 then
        Wait(duration)
    end

    if callback then callback(success) end
    return success
end

ProgressBar.Start = ProgressBar.Open

---Open a circular bar when the backend supports it.
function ProgressBar.Circle(options, callback, isQBInput)
    options = type(options) == 'table' and options or {}
    options.style = 'circle'
    return ProgressBar.Open(options, callback, isQBInput)
end

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------

Notify = {}
SB.Notify = Notify

local function NotifyConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Notify) or {}
end

local function NotifyResources()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Notify and SandboxBridgeConfig.Notify.Priority)
        or Compat.NotifyResources
end

function Notify.GetAvailableResources()
    return Compat.GetStarted(NotifyResources())
end

function Notify.GetResourceName()
    local config = NotifyConfig()
    if config.Enabled == false then return 'disabled' end
    local active = Compat.SelectConfigured(config, NotifyResources())
    return active or 'default'
end

function Notify.GetBackend()
    return Notify.GetResourceName()
end

local function NormalizeType(notifType)
    local value = tostring(notifType or 'info'):lower()
    if value == 'inform' or value == 'primary' then return 'info' end
    if value == 'danger' or value == 'error' then return 'error' end
    if value == 'warn' then return 'warning' end
    return value
end

local NotifyAdapters = {}

NotifyAdapters['ox_lib'] = function(title, message, notifType, duration)
    exports.ox_lib:notify({
        title = title,
        description = message,
        type = notifType,
        duration = duration,
        position = 'top-right',
    })
end

NotifyAdapters['wasabi_notify'] = function(title, message, notifType, duration)
    exports.wasabi_notify:notify(notifType, message, duration, notifType)
end

NotifyAdapters['okokNotify'] = function(title, message, notifType, duration)
    local okokType = notifType == 'error' and 'Error'
        or notifType == 'warning' and 'Warning'
        or notifType == 'info' and 'Info'
        or 'Success'
    exports['okokNotify']:Alert(title or 'Notification', message, duration, okokType, false)
end

NotifyAdapters['lation_ui'] = function(title, message, notifType, duration)
    exports.lation_ui:notify({
        title = title,
        message = message,
        type = notifType,
        duration = duration,
        position = 'top-right',
    })
end

NotifyAdapters['mythic_notify'] = function(_, message, notifType, duration)
    exports['mythic_notify']:DoHudText(notifType, message, duration)
end

NotifyAdapters['pNotify'] = function(_, message, notifType, duration)
    exports.pNotify:SendNotification({
        text = message,
        type = notifType,
        timeout = duration,
        layout = 'centerRight',
    })
end

NotifyAdapters['t-notify'] = function(title, message, notifType, duration)
    exports['t-notify']:Alert({
        title = title,
        style = notifType,
        message = message,
        duration = duration,
    })
end

NotifyAdapters['r_notify'] = function(title, message, notifType, duration)
    exports.r_notify:notify({
        title = title or 'Notification',
        content = message,
        type = notifType,
        icon = 'fas fa-check',
        duration = duration,
        position = 'top-right',
        sound = false,
    })
end

NotifyAdapters['brutal_notify'] = function(title, message, notifType, duration)
    exports['brutal_notify']:SendAlert(title or 'Notification', message, duration, notifType, false)
end

NotifyAdapters['solaire_notify'] = function(title, message, notifType, duration, props)
    props = props or {}
    exports.solaire_notify:Notify({
        type = notifType,
        title = title,
        message = message,
        duration = duration,
        position = props.position or 'top-right',
        sound = props.sound,
        item = props.item,
        volume = props.volume,
    })
end

NotifyAdapters['FL-Notify'] = function(title, message, notifType, duration)
    local flType = (notifType == 'error' or notifType == 'info') and 1
        or notifType == 'success' and 2
        or notifType == 'warning' and 3
        or 2
    exports['FL-Notify']:Notify('Notification', '', message, duration, flType, 0)
end

NotifyAdapters['msk_core'] = function(title, message, notifType, duration)
    exports.msk_core:Notify(title, message, notifType, duration)
end

NotifyAdapters['ZSX_UIV2'] = function(title, message, notifType, duration)
    local icon = notifType == 'success' and 'check-circle'
        or notifType == 'error' and 'times-circle'
        or notifType == 'warning' and 'exclamation-triangle'
        or 'info'
    exports['ZSX_UIV2']:Notification(title or 'Notification', message, icon, duration)
end

---Send a notification through the active notification resource.
---@param title string|nil
---@param message string
---@param notifType string|nil
---@param duration number|nil
---@param props table|nil
---@return boolean
function Notify.SendNotification(title, message, notifType, duration, props)
    message = tostring(message or '')
    notifType = NormalizeType(notifType)
    duration = tonumber(duration) or tonumber(SandboxBridgeConfig and SandboxBridgeConfig.NotifyDuration) or 5000

    local backend = Notify.GetResourceName()
    local adapter = NotifyAdapters[backend]
    if adapter then
        local ok = pcall(adapter, title, message, notifType, duration, props)
        if ok then return true end
    end

    -- Sandbox HUD / ox_lib fallback.
    if type(ShowNotification) == 'function' then
        ShowNotification(message, notifType, duration)
        return true
    end

    local ok = pcall(function()
        exports['sandbox-hud']:Notification(notifType, message, duration)
    end)
    return ok
end

---Community Bridge compatible short notification.
function Notify.SendNotify(message, notifType, duration)
    return Notify.SendNotification(nil, message, notifType, duration)
end

Notify.Send = Notify.SendNotification
Notify.Show = Notify.SendNotification

-- Server relay used by Dispatch and other server modules.
RegisterNetEvent('sandbox_bridge:client:notify', function(title, message, notifType, duration)
    Notify.SendNotification(title, message, notifType, duration)
end)

-- ---------------------------------------------------------------------------
-- Weather / time
-- ---------------------------------------------------------------------------

Weather = {}
SB.Weather = Weather

Weather.Current = nil
Weather.SyncEnabled = true

local function WeatherConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Weather) or {}
end

function Weather.GetAvailableResources()
    return Compat.GetStarted(Compat.WeatherResources)
end

function Weather.GetResourceName()
    local config = WeatherConfig()
    if config.Enabled == false then return 'disabled' end
    local active = Compat.SelectConfigured(config, Compat.WeatherResources)
    return active or 'default'
end

function Weather.GetBackend()
    return Weather.GetResourceName()
end

---Toggle time/weather synchronisation for the local player.
---@param toggle boolean
---@return boolean
function Weather.ToggleSync(toggle)
    toggle = toggle == true
    local backend = Weather.GetResourceName()

    local ok = false
    if backend == 'qb-weathersync' then
        ok = pcall(function()
            TriggerEvent(toggle and 'qb-weathersync:client:EnableSync' or 'qb-weathersync:client:DisableSync')
        end)
    elseif backend == 'cd_easytime' then
        ok = pcall(function() TriggerEvent('cd_easytime:PauseSync', toggle) end)
    elseif backend == 'sandbox-weather' then
        ok = pcall(function()
            TriggerEvent(toggle and 'sandbox-weather:client:enableSync' or 'sandbox-weather:client:disableSync')
        end)
    elseif backend == 'Renewed-Weathersync' then
        ok = pcall(function()
            TriggerEvent(toggle and 'Renewed-Weathersync:client:EnableSync' or 'Renewed-Weathersync:client:DisableSync')
        end)
    end

    if not ok then
        ok = pcall(function() TriggerEvent('qb-weathersync:client:EnableSync') end) or not toggle
    end

    Weather.SyncEnabled = toggle
    return ok
end

local VALID_WEATHER = {
    EXTRASUNNY = true, CLEAR = true, CLOUDS = true, OVERCAST = true,
    RAIN = true, CLEARING = true, THUNDER = true, SMOG = true,
    FOGGY = true, XMAS = true, SNOW = true, SNOWLIGHT = true,
    BLIZZARD = true, HALLOWEEN = true,
}

---Set the weather locally and notify the active sync resource.
---@param weatherType string
---@param transition number|nil seconds
---@return boolean
function Weather.SetWeather(weatherType, transition)
    weatherType = tostring(weatherType or ''):upper()
    if not VALID_WEATHER[weatherType] then return false end
    transition = tonumber(transition) or 15

    local backend = Weather.GetResourceName()
    if backend == 'qb-weathersync' then
        pcall(function() TriggerServerEvent('qb-weathersync:server:setWeather', weatherType) end)
    elseif backend == 'cd_easytime' then
        pcall(function() TriggerEvent('cd_easytime:SetWeather', weatherType) end)
    elseif backend == 'sandbox-weather' then
        pcall(function() TriggerEvent('sandbox-weather:client:setWeather', weatherType, transition) end)
    end

    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypeOverTime(weatherType, transition + 0.0)
    Weather.Current = weatherType

    CreateThread(function()
        Wait(math.max(0, transition * 1000))
        SetWeatherTypeNowPersist(weatherType)
    end)

    return true
end

function Weather.SetTime(hour, minute, second)
    hour = Compat.Clamp(hour, 0, 23)
    minute = Compat.Clamp(minute, 0, 59)
    second = Compat.Clamp(second, 0, 59)

    local backend = Weather.GetResourceName()
    if backend == 'qb-weathersync' then
        pcall(function() TriggerServerEvent('qb-weathersync:server:setTime', hour, minute) end)
    elseif backend == 'cd_easytime' then
        pcall(function() TriggerEvent('cd_easytime:SetTime', hour, minute) end)
    end

    NetworkOverrideClockTime(hour, minute, second)
    return true
end

function Weather.GetTime()
    return GetClockHours(), GetClockMinutes(), GetClockSeconds()
end

function Weather.GetWeather()
    return Weather.Current or 'UNKNOWN'
end

return {
    ProgressBar = ProgressBar,
    Notify = Notify,
    Weather = Weather,
}
