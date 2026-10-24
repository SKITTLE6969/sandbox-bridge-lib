# Sandbox Framework Bridge

QBCore / QBX / ESX compatibility layer for the **Sandbox RP Framework**.

The Sandbox Framework uses its own export API (`sandbox-base`, `sandbox-characters`,
`sandbox-jobs`, `sandbox-finance`, `sandbox-status`, `ox_inventory`). This bridge
exposes the same data through the framework APIs that QBCore, QBX and ESX scripts
expect, without replacing any Sandbox resource.

Any external resource that consumes the standard QBCore, QBX or ESX APIs will
detect the server as `qbx_core`, `qb-core` or `es_extended`. Community Bridge is
**not** bundled with this server; the bridge ships its own equivalent
Dispatch/MDT, Target, Doorlock, VehicleKey, Fuel, Clothing, ProgressBar,
Notify, Weather, Skills and developer-tool compatibility layer (see
[Compatibility modules](#compatibility-modules)).

---

## Resources

`qbx_core`, `qb-core` and `es_extended` have been merged into `sandbox-bridge-lib`. It is the
only framework resource and provides all three names:

```lua
provide 'qb-core'
provide 'qbx_core'
provide 'es_extended'
```

Scripts that declare `dependencies { 'qb-core' }` or
`dependencies { 'qbx_core' }` therefore resolve to `sandbox-bridge-lib`, and
`GetResourceState('qb-core')` / `GetResourceState('qbx_core')` / `GetResourceState('es_extended')` report it as
started.

Both framework export sets are registered by the same resource. On FXServer
builds without native `provide` export support, the bridge also registers the
`__cfx_export_<providedName>_<exportName>` handlers, so calls such as
`exports['qb-core']:GetCoreObject()` and `exports.qbx_core:GetPlayer(src)`
keep working.

---

## Module layout

`sandbox-bridge-lib/server/main.lua` and `sandbox-bridge-lib/client/main.lua`
are small loaders. They execute the feature modules in order inside one private
shared environment, so the modules can use the same helpers and caches without
polluting the global environment of the resource.

Shared modules:

| File | Contents |
| --- | --- |
| `shared/config.lua` | Bridge configuration table. |
| `shared/util.lua` | Shared helpers and the `AddExport` wrapper that also exposes exports through the provided names. |
| `shared/compat.lua` | Resource catalogues, auto-detection, alert/vector normalisation and search helpers used by the compatibility modules. |
| `shared/vehicles.lua` | Qbox vehicle catalog (`QBXVehicles`). |
| `modules/lib.lua` | Qbox `qbx` utility library. |

Server modules:

| File | Contents |
| --- | --- |
| `server/core.lua` | Shared config, caches, identity helpers, job/gang lookups and bank cache |
| `server/money.lua` | Cash / bank / crypto money helpers |
| `server/inventory.lua` | ox_inventory wrappers and item helpers |
| `server/jobs.lua` | Jobs, duty, groups, metadata getters/setters and notifications |
| `server/playerdata.lua` | `PlayerData` builder and group maps |
| `server/offline.lua` | Offline players, `Login`, `CreatePlayer`, `SaveOffline` |
| `server/players.lua` | Player objects, lookups, permissions, groups, `SearchPlayers` |
| `server/vehicles.lua` | Vehicle catalog, vehicle utilities and routing buckets |
| `server/qbcore.lua` | QBCore object |
| `server/management.lua` | Runtime job/gang management and shared export helpers |
| `server/persona_qbx.lua` | QBX Core export set |
| `server/persona_qbcore.lua` | QBCore export set |
| `server/dispatch.lua` | Dispatch backend registry, call history, Sandbox job recipients, all server dispatch adapters and fallback delivery |
| `server/mdt.lua` | MDT profiles, search, officers, vehicles, reports, warrants, notes, BOLOs and stats |
| `server/compat.lua` | Server Doorlock, VehicleKey, Clothing and Skills APIs |
| `server/exports.lua` | Registers both export sets and the shared `GetBridge` export |
| `server/events.lua` | Lifecycle events, money/job hooks and bridge callbacks |
| `server/startup.lua` | Startup wait loop, init and background sync threads |

Client modules:

| File | Contents |
| --- | --- |
| `client/core.lua` | Shared config, caches and base tables |
| `client/playerdata.lua` | Cached `PlayerData`, jobs/gangs and local inventory |
| `client/ui.lua` | Notifications and text UI |
| `client/ui_compat.lua` | ProgressBar, Notify and Weather adapters with native fallbacks |
| `client/callbacks.lua` | Server callback wrapper |
| `client/vehicles.lua` | Vehicle spawn/properties helpers |
| `client/vehicle.lua` | VehicleKey and Fuel adapters with native fallbacks |
| `client/appearance.lua` | Clothing adapters plus native ped-component appearance |
| `client/skills.lua` | Client Skills cache and progress helpers |
| `client/dev.lua` | 3D points, cutscenes, particles, scaleforms, DUI and object placement |
| `client/qbcore.lua` | QBCore client functions |
| `client/shared.lua` | Shared job/item/weapon/location data |
| `client/groups.lua` | Group filters and vehicle catalog helpers |
| `client/persona_qbx.lua` | QBX Core client export set |
| `client/persona_qbcore.lua` | QBCore client export set |
| `client/dispatch.lua` | Dispatch/MDT client adapters, call requests and native fallback |
| `client/target.lua` | Target adapters (`ox_target`, `qb-target`, `sleepless_interact`) and fallback zones |
| `client/exports.lua` | Registers both client export sets, `Notify`, `GetBridge` and the compatibility getters |
| `client/events.lua` | Lifecycle events and the framework Login spawn flow |
| `client/startup.lua` | Startup and polling threads |

Qbox modules (loaded directly from the manifest):

| File | Contents |
| --- | --- |
| `modules/lib.lua` | Global `qbx` utilities (`qbx.table`, `qbx.string`, `qbx.spawnVehicle`, ...). |
| `modules/hooks.lua` | Server `registerHook` / `removeHooks` exports. |
| `modules/logger.lua` | Logger module used by Qbox scripts. |
| `modules/playerdata.lua` | Client global `QBX.PlayerData`. |

Keep the include order in the two `main.lua` files unchanged unless you also
move the related definitions.

---

## Start order

The resource is already added to `server/config/resources.cfg`:

```cfg
# Framework Compatibility (Sandbox -> QBCore / QBX)
ensure sandbox-bridge-lib
```

The resource declares `dependencies` on `sandbox-base`, `sandbox-characters`,
`sandbox-jobs`, `sandbox-status`, `ox_inventory`, `oxmysql` and `ox_lib`, so
FiveM starts them in a safe order even if the `ensure` line moves. It provides
`qb-core`, `qbx_core` and `es_extended` for maximum compatibility.

---

## What is bridged

### Server

- **Player object** – `PlayerData` in QBCore/QBX shape.
- **Money** – `cash` maps to Sandbox's `money` inventory item; `bank` maps to the
  character's personal `sandbox-finance` bank account.
- **Jobs** – Sandbox multi-job assignments are exposed as a primary job plus
  grade, duty, workplace and boss flag.
- **Inventory** – ox_inventory slots, counts, metadata and weights.
- **Metadata** – hunger, thirst, stress, health, armour, dead / last-stand and
  arbitrary persisted character keys.
- **Nodes/events** – player loaded / unloaded, job update, duty update.
- **Callbacks** – QB callbacks over `sandbox-base` callbacks.
- **Commands** – QB command registration wired into `mChat`.
- **Usable items** – registered through `ox_inventory:RegisterUse`.
- **Permissions** – Sandbox groups map to `admin` / `staff` / `user`.

### Client

- `QBCore.Functions.GetPlayerData`, `TriggerCallback`, `HasItem`, `Notify`,
  `DrawText`, closest-entity helpers, vehicle properties and vehicle spawn
  helpers.
- `QBox.GetPlayerData`, `GetJobs`, `Notify`.
- `Characters:Client:Spawn` / `Logout` / `Updated` and Sandbox status/duty events
  are translated into `QBCore:Client:OnPlayerLoaded`,
  `QBCore:Client:OnPlayerUnload` and `QBCore:Client:OnJobUpdate`.

### Community Bridge style compatibility

Community Bridge is **not** included with this server. The bridge ships its own
implementation of the same module surface, so Sandbox resources can call
`Dispatch`, `MDT`, `Target`, `Doorlock`, `VehicleKey`, `Fuel`, `Clothing`,
`ProgressBar`, `Notify`, `Weather`, `Skills` and the developer helpers without
installing Community Bridge.

If you install Community Bridge separately, its framework module still detects
`qbx_core` or `qb-core` and uses the bridge automatically.

The bridge implements every framework function Community Bridge calls, including
`GetPlayer`, `GetPlayerData`, `GetPlayerJobData`, `GetPlayerMetadata`,
`GetPlayerInventory`, `GetAccountBalance`, `AddAccountBalance`,
`RemoveAccountBalance`, `SetPlayerJob`, `SetPlayerDuty`, `AddItem`, `RemoveItem`,
`SetMetadata`, `RegisterUsableItem`, `GetFrameworkJobs`, `GetPlayers`,
`GetPlayerIdentifier`, `GetPlayerName`, `GetPlayerDob`, `GetPlayerPhone`,
`GetPlayerGang`, `HasItem`, `GetItemCount`, `GetItemInfo`, `GetItemBySlot`,
`GetIsPlayerDead`, `RevivePlayer`, `AddStress`, `RemoveStress`, `AddHunger`,
`AddThirst`, `GetHunger`, `GetThirst`, job-count helpers and command helpers.

---

## Compatibility modules

`shared/compat.lua` holds the resource catalogues, auto-detection and alert
normalisation. Every module selects the first **started** resource from its
configured priority list. Pin a resource with `Force` or disable a module with
`Enabled = false` in `shared/config.lua`.

```lua
SandboxBridgeConfig.Dispatch.Force = 'ps-dispatch'
SandboxBridgeConfig.Fuel.Force = 'ox_fuel'
SandboxBridgeConfig.Target.Enabled = false -- always use the native fallback
```

### Dispatch / MDT

Supported dispatch resources: `ps-dispatch`, `cd_dispatch`, `lb-tablet`,
`bub-mdt`, `qs-dispatch`, `tk_dispatch`, `wasabi_mdt`, `kartik-mdt`,
`redutzu-mdt`, `fd_dispatch`, `origen_police`, `piotreq_gpt`,
`linden_outlawalert` and `emergencydispatch`.

Supported tablet/MDT resources: `lb-tablet`, `bub-mdt`, `wasabi_mdt`,
`redutzu-mdt`, `kartik-mdt`, `ps-mdt`, `cd_mdt` and `tk_mdt`.

Server-side adapters cover `lb-tablet`, `redutzu-mdt`, `piotreq_gpt`,
`fd_dispatch`, `bub-mdt`, `wasabi_mdt`, `kartik-mdt` and `emergencydispatch`;
the remaining backends are delivered by the client adapter. If a backend is
unavailable, the bridge relays the alert to a recipient client and finally
broadcasts a notification + blip to the target jobs, so delivery is guaranteed.

```lua
-- Server: create a call. Works on exports['qb-core'], exports.qbx_core and
-- exports['sandbox-bridge-lib'].
local call, delivered = exports['sandbox-bridge-lib']:SendDispatch({
    message = 'Shots fired',
    code = '10-71',
    priority = 3,
    jobs = { 'police', 'sheriff' },
    coords = vector3(100.0, 200.0, 30.0),
    blip = { sprite = 161, color = 1, scale = 0.8, flash = true },
})

local active = exports['sandbox-bridge-lib']:GetDispatchCalls({ active = true })
local stats = exports['sandbox-bridge-lib']:GetDispatchStats()
```

```lua
-- Client: local alert or server-backed call list.
SB.Dispatch.SendAlert({
    message = 'Vehicle theft in progress',
    code = '10-60',
    priority = 2,
    jobs = { 'police' },
})

SB.Dispatch.GetCalls(function(payload)
    print(('backend=%s active=%d'):format(payload.backend, payload.stats.active))
end)

SB.Dispatch.GetRecipients({ 'police' }, function(srcs)
    print(('recipients: %d'):format(#srcs))
end)
```

The MDT module returns Sandbox characters in a tablet-friendly shape and keeps
reports, warrants, notes and BOLOs in memory (bounded by
`SandboxBridgeConfig.Dispatch.MaxCalls` for calls). It never invents a database
schema; persist these records in your own MDT resource if you need them across
restarts.

```lua
local mdt = exports['sandbox-bridge-lib']:GetMDT()

local profile = mdt.GetProfile(1)          -- online source
local offline = mdt.GetProfile('SID0001')  -- offline citizenid
local matches = mdt.Search('Smith', { job = 'police', limit = 25 })
local officers = mdt.GetOfficers({ onDuty = true })

mdt.CreateReport({ title = 'Burglary', description = '...', citizenid = 'SID0001' }, 1)
mdt.CreateWarrant({ citizenid = 'SID0001', reason = 'Armed robbery' }, 1)
mdt.CreateBolo({ description = 'Black Sultan', plate = 'ABC123' }, 1)
```

Client helpers: `SB.MDT.Open(payload)`, `SB.MDT.GetProfile(id, cb)`,
`SB.MDT.Search(query, cb)`, `SB.MDT.GetOfficers(cb)`, `SB.MDT.GetCalls(cb)` and
`SB.MDT.GetStats(cb)`.

### Target

Supported: `ox_target`, `qb-target` and `sleepless_interact`. Without one of
them, `client/target.lua` runs a native zone loop with help text and the `E`
control. `canInteract` callbacks are normalised across resources and cached for
one second like Community Bridge.

```lua
local target = exports['sandbox-bridge-lib']:GetTarget()

target.AddBoxZone('bank_front', vector3(150.0, -1040.0, 29.0), { x = 2.5, y = 2.5, z = 2.0 }, 0.0, {
    {
        label = 'Open bank',
        icon = 'fas fa-building-columns',
        onSelect = function() TriggerEvent('bank:open') end,
        canInteract = function() return true end,
    },
})

target.AddSphereZone('atm', vector3(147.0, -1035.0, 29.0), 1.5, {
    { label = 'Use ATM', onSelect = function() TriggerEvent('atm:open') end },
}, true) -- debug = true
```

Also exposed: `AddGlobalPlayer`, `RemoveGlobalPlayer`, `AddGlobalPed`,
`AddGlobalVehicle`, `AddLocalEntity`, `AddNetworkedEntity`, `AddModel`,
`RemoveZone` and `DisableTargeting`.

### Doorlock

Supported: `ox_doorlock`, `qb-doorlock`, `rcore_doorlock`,
`jacksams-doorlock` and `doors_creator`. When no resource is started the bridge
keeps door state in memory (`Doorlock.Fallback = true`) so Sandbox scripts can
drive their own doors.

```lua
local doors = exports['sandbox-bridge-lib']:GetDoorlock()

doors.LockDoor('bank_vault')
doors.UnlockDoor('bank_vault')
local locked = doors.IsLocked('bank_vault')
doors.RegisterDoor({ id = 'bank_vault', label = 'Vault' })
```

### Vehicle keys

Supported: `qbx_vehiclekeys`, `qb-vehiclekeys`, `qs-vehiclekeys`,
`Renewed-Vehiclekeys`, `wasabi_carlock`, `mk_vehiclekeys`,
`MrNewbVehicleKeys`, `okokGarage`, `mVehicle`, `jaksams_VehiclesKeys`,
`F_RealCarKeysSystem`, `t1ger_keys` and `cd_garage`.

The client API accepts an entity, `{ entity = ... }`, or a plate. If only a
plate is passed, the bridge finds the closest pool vehicle with that plate.

```lua
local keys = exports['sandbox-bridge-lib']:GetVehicleKey()
keys.GiveKeys(vehicle)                -- local client
keys.GiveKeys(nil, 'ABC123')          -- by plate
keys.RemoveKeys(vehicle)
keys.SetLocked(vehicle, true)
```

Server relay (for garage/ownership scripts):

```lua
local keys = exports['sandbox-bridge-lib']:GetVehicleKey()
keys.GiveKeys(source, 'ABC123', NetworkGetNetworkIdFromEntity(vehicle))
keys.RemoveKeys(source, 'ABC123')
```

New key resources can be added at runtime with
`keys.RegisterProvider(name, giveFn, removeFn)`.

### Fuel

Supported: `ox_fuel`, `ps-fuel`, `LegacyFuel`, `cdn-fuel`, `qb-fuel`,
`qs-fuelstations`, `Renewed-Fuel`, `lc_fuel`, `ti_fuel`, `x-fuel`,
`esx-sna-fuel`, `okokGasStation` and `BigDaddy-Fuel`. Falls back to
`GetVehicleFuelLevel` / `SetVehicleFuelLevel`.

```lua
local fuel = exports['sandbox-bridge-lib']:GetFuel()

local level = fuel.GetFuel(vehicle)
fuel.SetFuel(vehicle, 75.0)        -- absolute, 0-100
fuel.AddFuel(vehicle, -10.0)       -- drain
fuel.SetFuel(vehicle, 50.0, 'RON95') -- ti_fuel fuel type
```

`fuel.RegisterProvider(name, getFn, setFn)` adds a custom resource.

### Clothing

Supported: `illenium-appearance`, `fivem-appearance`, `rcore_clothing`,
`qb-clothing` and `esx_skin`. The native fallback reads and writes ped
components/props, and `FromQBSkin` / `ToQBSkin` convert QBCore skin tables.

```lua
-- Client
local clothing = exports['sandbox-bridge-lib']:GetClothing()
local skin = clothing.GetAppearance(PlayerPedId())
clothing.SetAppearance(PlayerPedId(), skin)
clothing.RestoreAppearance(PlayerPedId())
clothing.OpenMenu()

-- Convert legacy QBCore clothing tables
local components = clothing.FromQBSkin(qbSkin)
local qbSkinAgain = clothing.ToQBSkin(components)

-- Server
local clothing = exports['sandbox-bridge-lib']:GetClothing()
clothing.SetAppearance(source, qbSkin)
clothing.OpenMenu(source)
```

### Progress bar, notifications and weather

Progress bars: `ox_lib`, `progressbar` (qb-progressbar), `keep-progressbar`,
`lation_ui`, `wasabi_uikit`, `ZSX_UIV2` and `msk_core`.
Notifications: `ox_lib`, `wasabi_notify`, `okokNotify`, `lation_ui`,
`mythic_notify`, `pNotify`, `t-notify`, `r_notify`, `brutal_notify`,
`solaire_notify`, `fl-notify`, `msk_core` and `ZSX_UIV2`.
Weather: `sandbox-weather`, `qb-weathersync`, `cd_easytime` and
`Renewed-Weathersync` (native weather/time is always applied as a fallback).

```lua
local progress = exports['sandbox-bridge-lib']:GetProgressBar()

-- ox-style options
local success = progress.Open({
    label = 'Repairing vehicle',
    duration = 5000,
    canCancel = true,
    disable = { move = true, car = true, combat = true },
    anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
})

-- QBCore style options are accepted with the third argument set to true
progress.Open(qbOptions, function(done) print(done) end, true)

local notify = exports['sandbox-bridge-lib']:GetNotify()
notify.SendNotification('Garage', 'Your vehicle is ready', 'success', 5000)
notify.SendNotify('Saved', 'success', 3000)

local weather = exports['sandbox-bridge-lib']:GetWeather()
weather.ToggleSync(false)
weather.SetWeather('RAIN', 10)
weather.SetTime(22, 30)
```

### Skills

Skills are persisted in the Sandbox character metadata key
`community_bridge_skills` (configurable) using the same RuneScape-style XP
curve as Community Bridge. The server is authoritative; the client keeps a
cache and can request a refresh.

```lua
-- Server
local skills = exports['sandbox-bridge-lib']:GetSkills()

skills.Create('mining', 99, 50)
skills.AddXP(source, 'mining', 120)
local level = skills.GetSkillLevel(source, 'mining')
local progress = skills.GetProgress(source, 'mining')
skills.SetSkillLevel(source, 'mining', 10)
skills.RemoveXP(source, 'mining', 25)

-- Client
local skills = exports['sandbox-bridge-lib']:GetSkills()
skills.Refresh(function(data) print(data.all) end, 'mining')
print(skills.GetSkillLevel('mining'), skills.GetXP('mining'))
skills.AddXP('mining', 50) -- asks the server
```

### Developer tools

All helpers are client-side and return handles or data; they clean themselves
up when the resource stops.

```lua
local dev = exports['sandbox-bridge-lib']:GetDev()

-- 3D interaction point
local id = dev.Points.Register('garage_door', vector3(215.0, -810.0, 30.0), {
    distance = 2.5,
    label = 'Open garage',
    marker = { type = 1, scale = 0.35 },
    onSelect = function() TriggerEvent('garage:open') end,
})

-- Cutscene
dev.Cutscene.Play('mp_intro_concat', vector3(0.0, 0.0, 70.0), 0.0, { duration = 8 })

-- Particle effect (milliseconds; 0 keeps it alive until Stop)
local fx = dev.Particles.Play('scr_rcbarry2', 'scr_clown_appears', vector3(0.0, 0.0, 70.0), nil, 1.0, 3000)

-- Scaleform
local scaleform = dev.Scaleform.Request('MP_BIG_MESSAGE_FREEMODE')
dev.Scaleform.Call(scaleform, 'SHOW_SHARD_WASTED_MP_MESSAGE', 'WASTED', 'You died')
dev.Scaleform.DrawFullscreen(scaleform)

-- DUI
local dui = dev.DUI.Create('https://example.com/overlay.html', 1280, 720)
dev.DUI.Send(dui, { type = 'update', value = 42 })
dev.DUI.Draw(dui, 0.5, 0.5, 0.4, 0.25, 255)

-- Object placement (E confirms, Backspace cancels)
local placement = dev.Placeable.Start('prop_bench_01a', {
    distance = 3.0,
    onConfirm = function(data) print(data.coords, data.heading) end,
})
```

`dev.IsDebug()` follows `SandboxBridgeConfig.Dev.Debug`; registered points draw
markers automatically in debug mode.

### Compatibility exports

All getters are registered on `sandbox-bridge-lib` and, through the provided
names, on `qb-core` / `qbx_core`.

| Export | Side | Returns |
| --- | --- | --- |
| `GetBridge` | both | QBCore/QBX bridge object (`SB` on the server) |
| `GetSandboxBridge` | client | `SB` table with every module |
| `GetDispatch` | both | Dispatch module |
| `SendDispatch(data, options)` | server | `call, delivered` |
| `GetDispatchCalls(filters)` | server | Call list |
| `GetDispatchStats()` | server | Call statistics |
| `GetMDT` | server | MDT module |
| `GetTarget` | client | Target module |
| `GetDoorlock` | server | Doorlock module |
| `GetVehicleKey` | both | VehicleKey module |
| `GetFuel` | client | Fuel module |
| `GetClothing` | both | Clothing module |
| `GetProgressBar` | client | ProgressBar module |
| `GetNotify` | client | Notify module |
| `GetWeather` | client | Weather module |
| `GetSkills` | both | Skills module |
| `GetDev` | client | Developer tools module |

### Error handling

- Every third-party export/event call is wrapped in `pcall`; a missing or
  changed export falls through to the next backend and finally to the native
  fallback. Nothing in the compatibility layer throws into the calling resource.
- Dispatch delivery order is: active backend -> client relay -> job broadcast
  -> caller notification. A call is still recorded even when delivery fails.
- `SetVehicleFuelLevel`, `SetVehicleDoorsLocked` and ped-component natives are
  the last resort for fuel, keys and clothing.
- Enable `SandboxBridgeConfig.Debug` to print protected-call failures.

---

## Configuration

Edit `sandbox-bridge-lib/shared/config.lua`:

| Option | Description |
| --- | --- |
| `Debug` | Prints adapter diagnostics. |
| `BankCacheSeconds` | How long a bank balance is cached. |
| `BankSyncSeconds` | How often the server pushes bank balances to clients. |
| `ClientRefreshSeconds` | Client-side player data refresh interval. |
| `DefaultJob` | Job returned when a character has no Sandbox job. |
| `GangJobs` | Sandbox job ids that should be exposed as QBCore gangs. |
| `Dispatch.*` | Dispatch backend priority/force, jobs, blip defaults, rate limit and call history limit. |
| `MDT.*` | Tablet priority/force, law jobs, open events and result limit. |
| `Target`, `Doorlock`, `VehicleKey`, `Fuel`, `Clothing`, `ProgressBar`, `Notify`, `Weather` | `Priority`, `Force` and `Enabled` per compatibility module. |
| `Skills.MetadataKey` / `Skills.MaxLevel` | Sandbox metadata key and maximum skill level. |
| `Dev.*` | Point distance, debug markers and maximum DUI handles. |

### Gang jobs

Sandbox stores gangs as normal jobs (`Type = "Company"`). To expose one as a
gang, add it to `GangJobs`:

```lua
SandboxBridgeConfig.GangJobs = {
    nines = true,
    ballers = true,
    lostmc = true,
}
```

### Bank accounts

Sandbox creates a personal bank account when the character is loaded / created
(`sandbox-finance:AccountsCreatePersonal`). The bridge uses
`AccountsGetPersonal(SID)` and falls back to creating the account if it is
missing.

---

## QBX Core / ESX Legacy compatibility

The bridge follows the documented Qbox API under the `qbx_core` name and ESX Legacy
API under `es_extended`/`ESX`:

- **ESX shared/server** - `ESX.GetPlayerFromId`, `ESX.GetPlayerFromIdentifier`,
  `ESX.GetExtendedPlayers`, `ESX.RegisterServerCallback`, `ESX.RegisterUsableItem`
  and the `xPlayer` object with `getJob`, `setJob`, `addMoney`, `removeMoney`,
  `addAccountMoney`, `getInventoryItem`, `addInventoryItem`, etc. Exports also
  available as `exports['es_extended']:getSharedObject()` / `exports['sandbox-bridge-lib']:GetPlayerFromId`.
- **ESX client** - `ESX.GetPlayerData`, `ESX.TriggerServerCallback`,
  `ESX.ShowNotification`, `ESX.Progressbar`, `ESX.Game`, `ESX.PlayerData`
  with `esx:playerLoaded`, `esx:setJob`, `esx:setAccountMoney` events.

Qbox details:

- **Shared exports** – `GetJobs`, `GetGangs`, `GetJob`, `GetGang`,
  `GetVehiclesByName`, `GetVehiclesByHash`, `GetVehiclesByCategory`,
  `GetWeapons`, `GetLocations`.
- **Server exports** – player lookup, job/gang management, metadata, money,
  duty, buckets, hooks, vehicle persistence, `SearchPlayers`, character
  save/logout helpers and the rest of the Qbox server export list.
- **Client exports** – `Notify`, `HasPrimaryGroup`, `HasGroup`, `GetGroups`.
- **Events** – `QBCore:Server:OnPlayerLoaded`, `OnPlayerUnload`,
  `OnJobUpdate`, `OnGangUpdate`, `SetDuty`, `OnMoneyChange`,
  `onSetMetaData`, `onGroupUpdate`, and the matching client events.
- **Modules** – `modules/playerdata.lua` (global `QBX.PlayerData`),
  `modules/hooks.lua` (`registerHook` / `removeHooks`),
  `modules/logger.lua`, and `modules/lib.lua` (global `qbx` utilities).

The modules can be required directly from the bridge:

```lua
local triggerEventHooks = require '@sandbox-bridge-lib.modules.hooks'
local logger = require '@sandbox-bridge-lib.modules.logger'
local qbx = require '@sandbox-bridge-lib.modules.lib'
```

`modules/playerdata.lua` can be added to a client resource's
`client_scripts` to get the `QBX.PlayerData` global.

Character lifecycle exports are backed by `sandbox-characters`:

- `Login` loads an existing character (or creates one from `newData`) and starts
  the normal Sandbox spawn flow.
- `CreatePlayer` inserts a character through the Sandbox creation pipeline.
- `GetOfflinePlayer` builds a Qbox `Player` object from the `characters` table.
- `SaveOffline` writes the `PlayerData` back to the `characters` table.
- `SearchPlayers` returns both online and offline players.
- Money, metadata, char-info, job and gang exports accept either a source or a
  citizenid; offline writes are persisted through `SaveOffline`.
- `IsWhitelisted`, `IsPlayerBanned`, `IsOptin` and `ToggleOptin` use the Sandbox
  queue, punishment and character flag systems.

The vehicle catalog exports use the official Qbox `shared/vehicles.lua` data, so
`GetVehiclesByName`, `GetVehiclesByHash` and `GetVehiclesByCategory` return the
same data as Qbox (including custom vehicles only if you add them to the file).

Remaining differences:

- Runtime-only `CreateJob` / `CreateGangs` overlays are kept in memory; they are
  not written to the Sandbox `jobs` table.
- `qbx.spawnVehicle` uses server-side vehicle creation; vehicle properties are
  best-effort.

## Optional: vehicle ownership compatibility

Community Bridge's (optional) `Framework.GetOwnedVehicles` and
`Framework.IsVehicleOwnedByPlayer` query the QBCore `player_vehicles` table.
Sandbox stores vehicles in its own `vehicles` table.

If you need those two functions, create a read-only compatibility view. **Do not
run this if a `player_vehicles` table already exists.**

```sql
CREATE OR REPLACE VIEW `player_vehicles` AS
SELECT
    `VIN`             AS `id`,
    `Model`           AS `vehicle`,
    `RegisteredPlate` AS `plate`,
    `OwnerId`         AS `citizenid`
FROM `vehicles`
WHERE `OwnerType` = 0;
```

---

## Security notes

- All money and item mutations happen server-side. Client shims only read cached
  values.
- Callbacks validate `source` and use Sandbox character stores, never the client
  payload.
- `SetJob`/`SetDuty` require a loaded Sandbox character.
- Admin permission checks use the Sandbox group permissions first, then ACE.

---

## Troubleshooting

**`sandbox-bridge-lib` could not start / missing includes**
Make sure `sandbox-bridge-lib` is `ensure`d once and that no old `qb-core` or
`qbx_core` resource folders are left in the resources directory.

**No jobs / `Shared.Jobs` is empty**
`sandbox-jobs` populates its job cache one second after start. The bridge waits
up to 15 seconds for that cache and refreshes every 60 seconds.

**Bank balance is 0**
Check that `sandbox-finance` is started and that the character has a personal
bank account. The bridge will create one on the first bank mutation.

**Admin is false in a QBX script**
Add the compatibility ACEs from `config/permissions.cfg`:

```cfg
add_ace group.admin admin allow
add_ace group.staff admin allow
```

The bridge also adds the correct `group.admin` / `group.staff` principal when a
character loads.

**Multiple frameworks fighting**
Do **not** install a real `qb-core` or `qbx_core` resource next to
`sandbox-bridge-lib` — the provided names would collide. Remove the bridge and
its `provide` lines first if you ever migrate to a real framework.

**An external bridge does not detect the framework**
Check `GetResourceState('qbx_core')`, `GetResourceState('qb-core')` or
`GetResourceState('es_extended')`. A started `sandbox-bridge-lib` satisfies all
through its `provide` entries.

**Exports break after restarting the bridge**
On FXServer builds without native `provide` export support, scripts that already
resolved `exports['qb-core']` / `exports.qbx_core` cache the old function. Restart
the dependent resource (or reconnect the client) after restarting
`sandbox-bridge-lib`; a full server restart is the cleanest option.

---

## API coverage / limitations

- Sandbox characters can have multiple jobs. The bridge exposes the **first**
  job as the QBCore `job`; `GetJobs()` returns all of them.
- Sandbox SID is used as `citizenid`. Scripts that expect a random alphanumeric
  citizen id will still work as long as they treat it as an opaque string.
- Sandbox gangs are not tagged in the database. Configure `GangJobs` to expose
  them.
- `Shared.Items` is built from the ox_inventory item list.
- Sandbox's status values are 0-100 and map directly to QB metadata.
- Dispatch calls and MDT reports/warrants/notes/BOLOs are in-memory. The call
  history is bounded by `SandboxBridgeConfig.Dispatch.MaxCalls`; use a real
  MDT/database resource if you need long-term persistence.
- ESX Legacy scripts are supported via `es_extended`/`ESX` (xPlayer, callbacks,
  events). Money maps to cash/bank via ox_inventory and Renewed-Banking; some
  ESX-specific account types may not be fully persisted.
- If you install Community Bridge separately, disable its `dispatch`, `target`,
  `doorlock`, `vehiclekey`, `fuel`, `clothing`, `progressbar`, `notify`,
  `weather`, `skills` and `dev` modules (or leave them on — the bridge's own
  modules do not register conflicting globals or exports).

---

## Credits

- Community Bridge by The Order of the Sacred Framework — GPL-3.0,
  <https://github.com/TheOrderFivem/community_bridge>.
- Sandbox RP Framework by AutLaaw (original Mythic Framework by Alzar & Dr Nick).
