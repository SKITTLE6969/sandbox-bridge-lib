--[[
    sandbox-bridge-lib / shared/config.lua
    Shared configuration for the Sandbox -> QBCore / QBX compatibility layer.
]]

SandboxBridgeConfig = SandboxBridgeConfig or {}

-- Print extra diagnostics from the bridge itself.
SandboxBridgeConfig.Debug = false

-- How long (in seconds) a personal bank balance is cached before it is read again.
SandboxBridgeConfig.BankCacheSeconds = 10

-- How often (in seconds) the server pushes a fresh bank balance to logged in clients.
SandboxBridgeConfig.BankSyncSeconds = 30

-- How often (in seconds) the client refreshes its local player data.
SandboxBridgeConfig.ClientRefreshSeconds = 2

-- Default QBCore style job used when a character has no Sandbox job.
SandboxBridgeConfig.DefaultJob = {
    name = 'unemployed',
    label = 'Unemployed',
    grade = 'freelancer',
    gradeLabel = 'Freelancer',
    gradeLevel = 0,
    payment = 0,
}

-- Sandbox does not tag jobs as gangs. Add Sandbox job ids here if you want
-- Framework.GetPlayerGang / QBCore playerData.gang to resolve them.
-- Example: SandboxBridgeConfig.GangJobs = { nines = true, ballers = true }
SandboxBridgeConfig.GangJobs = SandboxBridgeConfig.GangJobs or {}

-- Default notification duration (milliseconds) used by the framework shims.
SandboxBridgeConfig.NotifyDuration = 5000

-- Sandbox permission level -> framework permission mapping.
SandboxBridgeConfig.AdminPermissions = {
    god = 'admin',
    admin = 'admin',
    owner = 'admin',
    superadmin = 'admin',
    staff = 'staff',
    mod = 'staff',
    moderator = 'staff',
}

-- If true, the bridge logs missing optional resources instead of silently falling back.
SandboxBridgeConfig.WarnMissingResources = false

--[[
    Compatibility modules
    ------------------------------------------------------------------------
    The tables below are consumed by the optional compatibility layer. Every
    option is optional: the defaults work on a stock Sandbox server and any
    supported third-party resource is detected automatically.
]]

-- Dispatch / MDT -------------------------------------------------------------

SandboxBridgeConfig.Dispatch = SandboxBridgeConfig.Dispatch or {}

---Master switch for the Dispatch/MDT module.
SandboxBridgeConfig.Dispatch.Enabled = true

---Resources are tried from left to right.
SandboxBridgeConfig.Dispatch.Priority = {
    'ps-dispatch',
    'cd_dispatch',
    'lb-tablet',
    'bub-mdt',
    'qs-dispatch',
    'tk_dispatch',
    'wasabi_mdt',
    'kartik-mdt',
    'redutzu-mdt',
    'fd_dispatch',
    'origen_police',
    'piotreq_gpt',
    'linden_outlawalert',
    'emergencydispatch',
}

---Force one backend even if it is lower in the priority list.
---Example: SandboxBridgeConfig.Dispatch.Force = 'ps-dispatch'
SandboxBridgeConfig.Dispatch.Force = nil

---Backends that cannot be active together. The key is skipped when any of
---the conflicting resources is started (this matches the behaviour of the
---original Community Bridge).
SandboxBridgeConfig.Dispatch.Exclusions = {
    ['ps-dispatch'] = { ['lb-tablet'] = true },
    ['fd_dispatch'] = { ['lb-tablet'] = true },
}

---Jobs that receive an alert when the caller does not pass one.
SandboxBridgeConfig.Dispatch.DefaultJobs = { 'police' }

---Default priority (1 = low, 3 = high).
SandboxBridgeConfig.Dispatch.DefaultPriority = 2

---Default alert lifetime in milliseconds.
SandboxBridgeConfig.Dispatch.DefaultTime = 30000

---Fallback blip styling used when no dispatch resource handled the alert.
SandboxBridgeConfig.Dispatch.DefaultBlip = {
    sprite = 161,
    color = 1,
    scale = 0.8,
    radius = 0.0,
    flash = false,
}

---When every backend fails, broadcast a notification and blip to the players
---in the target jobs. This is the safety net that guarantees delivery.
SandboxBridgeConfig.Dispatch.Fallback = true

---Send the fallback to the player who created the alert when they are not in
---one of the target jobs.
SandboxBridgeConfig.Dispatch.NotifyCaller = true

---Minimum number of seconds between alerts created by the same player.
SandboxBridgeConfig.Dispatch.RateLimitSeconds = 1

---Keep a bounded in-memory call history for the MDT API.
SandboxBridgeConfig.Dispatch.KeepCalls = true
SandboxBridgeConfig.Dispatch.MaxCalls = 250
SandboxBridgeConfig.Dispatch.CallTimeout = 900

---Relay server-side alerts to a client when the selected backend only
---implements a client adapter.
SandboxBridgeConfig.Dispatch.RelayToClient = true

-- MDT ------------------------------------------------------------------------

SandboxBridgeConfig.MDT = SandboxBridgeConfig.MDT or {}

SandboxBridgeConfig.MDT.Enabled = true

---Resources that provide an MDT/tablet UI.
SandboxBridgeConfig.MDT.Priority = {
    'lb-tablet',
    'bub-mdt',
    'wasabi_mdt',
    'redutzu-mdt',
    'kartik-mdt',
    'ps-mdt',
    'cd_mdt',
}

SandboxBridgeConfig.MDT.Force = nil

---Jobs considered law enforcement by the default officer list. Override this
---with your Sandbox job ids.
SandboxBridgeConfig.MDT.LawJobs = {
    police = true,
    sheriff = true,
    sahp = true,
    bcso = true,
    statepolice = true,
    ranger = true,
}

---Events attempted by the client OpenMDT helper. Add your custom tablet event
---under the resource key if you use a fork.
SandboxBridgeConfig.MDT.OpenEvents = {
    ['lb-tablet'] = { 'lb-tablet:client:openTablet' },
    ['bub-mdt'] = { 'bub-mdt:client:openMDT', 'bub-mdt:client:openMdt' },
    ['wasabi_mdt'] = { 'wasabi_mdt:client:openMDT', 'wasabi_mdt:client:open' },
    ['redutzu-mdt'] = { 'redutzu-mdt:client:openMDT', 'redutzu-mdt:client:open' },
    ['kartik-mdt'] = { 'kartik-mdt:client:openMDT', 'kartik-mdt:client:open' },
    ['ps-mdt'] = { 'ps-mdt:client:openMDT' },
    ['cd_mdt'] = { 'cd_mdt:client:openMDT' },
}

---Maximum number of rows returned by MDT search/getters.
SandboxBridgeConfig.MDT.MaxResults = 100

-- Target ---------------------------------------------------------------------

SandboxBridgeConfig.Target = SandboxBridgeConfig.Target or {}
SandboxBridgeConfig.Target.Enabled = true
SandboxBridgeConfig.Target.Priority = {
    'ox_target',
    'qb-target',
    'sleepless_interact',
}
SandboxBridgeConfig.Target.Force = nil

-- Doorlock -------------------------------------------------------------------

SandboxBridgeConfig.Doorlock = SandboxBridgeConfig.Doorlock or {}
SandboxBridgeConfig.Doorlock.Enabled = true
---Keep door state in memory and let Sandbox code implement the actual door
---when no supported doorlock resource is running.
SandboxBridgeConfig.Doorlock.Fallback = true
SandboxBridgeConfig.Doorlock.Priority = {
    'ox_doorlock',
    'qb-doorlock',
    'rcore_doorlock',
    'jacksams-doorlock',
    'doors_creator',
}
SandboxBridgeConfig.Doorlock.Force = nil

-- Vehicle keys ---------------------------------------------------------------

SandboxBridgeConfig.VehicleKey = SandboxBridgeConfig.VehicleKey or {}
SandboxBridgeConfig.VehicleKey.Enabled = true
SandboxBridgeConfig.VehicleKey.Priority = {
    'qbx_vehiclekeys',
    'qb-vehiclekeys',
    'qs-vehiclekeys',
    'Renewed-Vehiclekeys',
    'wasabi_carlock',
    'mk_vehiclekeys',
    'MrNewbVehicleKeys',
    'okokGarage',
    'mVehicle',
    'jaksams_VehiclesKeys',
    'F_RealCarKeysSystem',
    't1ger_keys',
    'cd_garage',
}
SandboxBridgeConfig.VehicleKey.Force = nil

-- Fuel -----------------------------------------------------------------------

SandboxBridgeConfig.Fuel = SandboxBridgeConfig.Fuel or {}
SandboxBridgeConfig.Fuel.Enabled = true
SandboxBridgeConfig.Fuel.Priority = {
    'ox_fuel',
    'ps-fuel',
    'LegacyFuel',
    'cdn-fuel',
    'qb-fuel',
    'qs-fuelstations',
    'Renewed-Fuel',
    'lc_fuel',
    'ti_fuel',
    'x-fuel',
    'esx-sna-fuel',
    'okokGasStation',
    'BigDaddy-Fuel',
}
SandboxBridgeConfig.Fuel.Force = nil

-- Clothing -------------------------------------------------------------------

SandboxBridgeConfig.Clothing = SandboxBridgeConfig.Clothing or {}
SandboxBridgeConfig.Clothing.Enabled = true
SandboxBridgeConfig.Clothing.Priority = {
    'illenium-appearance',
    'fivem-appearance',
    'rcore_clothing',
    'qb-clothing',
    'esx_skin',
}
SandboxBridgeConfig.Clothing.Force = nil

-- Progress bar / notifications ----------------------------------------------

SandboxBridgeConfig.ProgressBar = SandboxBridgeConfig.ProgressBar or {}
SandboxBridgeConfig.ProgressBar.Enabled = true
SandboxBridgeConfig.ProgressBar.Priority = {
    'ox_lib',
    'progressbar',
    'keep-progressbar',
    'lation_ui',
    'wasabi_uikit',
    'ZSX_UIV2',
    'msk_core',
}
SandboxBridgeConfig.ProgressBar.Force = nil

SandboxBridgeConfig.Notify = SandboxBridgeConfig.Notify or {}
SandboxBridgeConfig.Notify.Enabled = true
SandboxBridgeConfig.Notify.Force = nil
---Notification resources tried from left to right.
SandboxBridgeConfig.Notify.Priority = {
    'ox_lib',
    'wasabi_notify',
    'okokNotify',
    'lation_ui',
    'mythic_notify',
    'pNotify',
    't-notify',
    'r_notify',
    'brutal_notify',
    'solaire_notify',
    'FL-Notify',
    'msk_core',
    'ZSX_UIV2',
}

-- Weather --------------------------------------------------------------------

SandboxBridgeConfig.Weather = SandboxBridgeConfig.Weather or {}
SandboxBridgeConfig.Weather.Enabled = true
SandboxBridgeConfig.Weather.Priority = {
    'sandbox-weather',
    'qb-weathersync',
    'cd_easytime',
    'Renewed-Weathersync',
}
SandboxBridgeConfig.Weather.Force = nil

-- Skills ---------------------------------------------------------------------

SandboxBridgeConfig.Skills = SandboxBridgeConfig.Skills or {}
SandboxBridgeConfig.Skills.Enabled = true
---Metadata key used to persist the skill table on the Sandbox character.
SandboxBridgeConfig.Skills.MetadataKey = 'community_bridge_skills'
SandboxBridgeConfig.Skills.MaxLevel = 99

-- Developer tools ------------------------------------------------------------

SandboxBridgeConfig.Dev = SandboxBridgeConfig.Dev or {}
---Draw debugging markers for registered points/zones.
SandboxBridgeConfig.Dev.Debug = false
---Default interaction distance for 3D points.
SandboxBridgeConfig.Dev.PointDistance = 2.0
---Maximum number of DUI handles kept alive at once.
SandboxBridgeConfig.Dev.MaxDui = 16
