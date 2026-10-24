-- sandbox-bridge-lib/client/target.lua
-- Loaded by client/main.lua in the shared bridge environment.
--
-- Unified Target API for ox_target, qb-target, sleepless_interact and a small
-- native fallback used on servers without a targeting resource.

SB = SB or {}

Target = {}
SB.Target = Target

local Compat = SandboxBridgeCompat

Target.Zones = {}
Target.InteractIds = {}
Target.Sequence = 0
Target.FallbackZones = {}

local function TargetConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Target) or {}
end

function Target.GetAvailableResources()
    return Compat.GetStarted(Compat.TargetResources)
end

function Target.GetResourceName()
    local config = TargetConfig()
    if config.Enabled == false then return 'disabled' end
    local active = Compat.SelectConfigured(config, Compat.TargetResources)
    return active or 'default'
end

function Target.GetBackend()
    return Target.GetResourceName()
end

function Target.IsAvailable()
    local backend = Target.GetResourceName()
    return backend ~= 'default' and backend ~= 'disabled'
end

-- ---------------------------------------------------------------------------
-- Interaction predicates
-- ---------------------------------------------------------------------------

function Target.CreateCanInteract(callback)
    if type(callback) ~= 'function' then return nil end
    Target.Sequence = Target.Sequence + 1
    local id = ('target:%d:%d'):format(GetGameTimer(), Target.Sequence)
    Target.InteractIds[id] = callback
    return id
end

function Target.GetCanInteract(id)
    return Target.InteractIds[id]
end

function Target.CanInteract(id, ...)
    local callback = Target.InteractIds[id]
    if not callback then return true end
    local ok, result = pcall(callback, ...)
    return ok and result == true
end

-- ---------------------------------------------------------------------------
-- Option conversion
-- ---------------------------------------------------------------------------

local function WrapAction(action)
    if type(action) ~= 'function' then return nil end
    return function(entityOrData, ...)
        local entity = entityOrData
        if type(entityOrData) == 'table' then
            entity = entityOrData.entity or entityOrData
        end
        return action(entity, ...)
    end
end

---Normalise options so the same table works with every target resource.
function Target.FixOptions(options)
    if type(options) ~= 'table' then return {} end

    for _, option in pairs(options) do
        if type(option) == 'table' then
            local action = option.onSelect or option.action
            if action then
                option.onSelect = WrapAction(action)
            end

            option.groups = option.groups or option.job
            option.job = option.job or option.groups

            if option.canInteract and type(option.canInteract) == 'function' then
                local id = Target.CreateCanInteract(option.canInteract)
                option.canInteract = function(...)
                    return Target.CanInteract(id, ...)
                end
            end

            if not option.distance then
                option.distance = option.dist or 2.5
            end
        end
    end

    return options
end

-- ---------------------------------------------------------------------------
-- Native fallback
-- ---------------------------------------------------------------------------

local function EnsureFallbackLoop()
    if Target.FallbackStarted then return end
    Target.FallbackStarted = true

    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)

            for _, zone in pairs(Target.FallbackZones) do
                local distance = #(playerCoords - zone.coords)
                if distance < (zone.radius or 2.0) then
                    sleep = 0
                    if not zone.inside then
                        zone.inside = true
                        if zone.onEnter then zone.onEnter(zone) end
                    end

                    if type(ShowText) == 'function' then
                        ShowText(zone.label or 'Interact', 100)
                    end

                    if IsControlJustPressed(0, 38) then -- E
                        if zone.onSelect then zone.onSelect(zone) end
                    end
                elseif zone.inside then
                    zone.inside = false
                    if zone.onExit then zone.onExit(zone) end
                    if type(HideText) == 'function' then HideText() end
                end
            end

            Wait(sleep)
        end
    end)
end

local function AddFallbackZone(name, coords, radius, options)
    local fixed = Target.FixOptions(options)
    local first
    for _, option in pairs(fixed) do
        first = first or option
        if not first then break end
    end

    local zone = {
        name = name,
        coords = Compat.ToCoords(coords),
        radius = tonumber(radius) or 2.0,
        label = first and (first.label or first.name) or 'Interact',
        options = fixed,
        onSelect = first and first.onSelect or nil,
        inside = false,
    }
    Target.FallbackZones[name] = zone
    EnsureFallbackLoop()
    return name
end

-- ---------------------------------------------------------------------------
-- ox_target / sleepless adapters
-- ---------------------------------------------------------------------------

local function OxOrSleepless(resource)
    local backend = exports[resource]
    return backend
end

local function AddGlobalPlayer(options)
    local backend = Target.GetResourceName()
    options = Target.FixOptions(options)

    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):addGlobalPlayer(options) end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):addGlobalPlayer(options) end)
    elseif backend == 'qb-target' then
        local fixed = Target.FixOptions(options)
        return Compat.SafeCall(function()
            exports['qb-target']:AddGlobalPlayer({ options = fixed, distance = 2.5 })
        end)
    end

    return false
end

local function RemoveGlobalPlayer()
    local backend = Target.GetResourceName()
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):removeGlobalPlayer() end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):removeGlobalPlayer() end)
    elseif backend == 'qb-target' then
        return Compat.SafeCall(function() exports['qb-target']:RemoveGlobalPlayer() end)
    end
    return false
end

local function AddGlobalPed(options)
    local backend = Target.GetResourceName()
    options = Target.FixOptions(options)
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):addGlobalPed(options) end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):addGlobalPed(options) end)
    elseif backend == 'qb-target' then
        return Compat.SafeCall(function()
            exports['qb-target']:AddGlobalPed({ options = options, distance = 2.5 })
        end)
    end
    return false
end

local function RemoveGlobalPed(options)
    local backend = Target.GetResourceName()
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):removeGlobalPed(options) end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):removeGlobalPed(options) end)
    elseif backend == 'qb-target' then
        return Compat.SafeCall(function() exports['qb-target']:RemoveGlobalPed(options) end)
    end
    return false
end

local function AddGlobalVehicle(options)
    local backend = Target.GetResourceName()
    options = Target.FixOptions(options)
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):addGlobalVehicle(options) end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):addGlobalVehicle(options) end)
    elseif backend == 'qb-target' then
        return Compat.SafeCall(function()
            exports['qb-target']:AddGlobalVehicle({ options = options, distance = 2.5 })
        end)
    end
    return false
end

local function RemoveGlobalVehicle(options)
    local backend = Target.GetResourceName()
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):removeGlobalVehicle(options) end)
    elseif backend == 'sleepless_interact' then
        local labels = {}
        for _, option in pairs(options or {}) do labels[#labels + 1] = option.name end
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):removeGlobalVehicle(labels) end)
    elseif backend == 'qb-target' then
        local labels = {}
        for _, option in pairs(options or {}) do labels[#labels + 1] = option.label or option.name end
        return Compat.SafeCall(function() exports['qb-target']:RemoveGlobalVehicle(labels) end)
    end
    return false
end

local function AddLocalEntity(entities, options)
    local backend = Target.GetResourceName()
    options = Target.FixOptions(options)
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):addLocalEntity(entities, options) end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):addLocalEntity(entities, options) end)
    elseif backend == 'qb-target' then
        return Compat.SafeCall(function()
            exports['qb-target']:AddTargetEntity(entities, { options = options, distance = 2.5 })
        end)
    end
    return false
end

local function RemoveLocalEntity(entities, labels)
    local backend = Target.GetResourceName()
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):removeLocalEntity(entities, labels) end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):removeLocalEntity(entities, labels) end)
    elseif backend == 'qb-target' then
        return Compat.SafeCall(function() exports['qb-target']:RemoveTargetEntity(entities, labels) end)
    end
    return false
end

local function AddNetworkedEntity(netids, options)
    local backend = Target.GetResourceName()
    options = Target.FixOptions(options)
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):addEntity(netids, options) end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):addEntity(netids, options) end)
    elseif backend == 'qb-target' then
        return Compat.SafeCall(function()
            exports['qb-target']:AddTargetEntity(netids, { options = options, distance = 2.5 })
        end)
    end
    return false
end

local function RemoveNetworkedEntity(netids, labels)
    local backend = Target.GetResourceName()
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):removeEntity(netids, labels) end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):removeEntity(netids, labels) end)
    elseif backend == 'qb-target' then
        return Compat.SafeCall(function() exports['qb-target']:RemoveTargetEntity(netids, labels) end)
    end
    return false
end

local function AddModel(models, options)
    local backend = Target.GetResourceName()
    options = Target.FixOptions(options)
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):addModel(models, options) end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):addModel(models, options) end)
    elseif backend == 'qb-target' then
        return Compat.SafeCall(function()
            exports['qb-target']:AddTargetModel(models, { options = options, distance = 2.5 })
        end)
    end
    return false
end

local function RemoveModel(models)
    local backend = Target.GetResourceName()
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):removeModel(models) end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):removeModel(models) end)
    elseif backend == 'qb-target' then
        return Compat.SafeCall(function() exports['qb-target']:RemoveTargetModel(models) end)
    end
    return false
end

local function AddBoxZone(name, coords, size, heading, options, debug)
    local backend = Target.GetResourceName()
    options = Target.FixOptions(options or {})
    coords = Compat.ToCoords(coords)

    if backend == 'ox_target' then
        local id = Compat.SafeCall(function()
            return OxOrSleepless('ox_target'):addBoxZone({
                name = name,
                coords = coords,
                size = size,
                rotation = heading,
                debug = debug == true,
                options = options,
            })
        end)
        if id then
            Target.Zones[id] = { name = name, backend = backend, id = id }
            return id
        end
    elseif backend == 'sleepless_interact' then
        local id = Compat.SafeCall(function()
            return OxOrSleepless('sleepless_interact'):addCoords({ name = name, coords = coords, options = options })
        end)
        if id then
            Target.Zones[id] = { name = name, backend = backend, id = id }
            return id
        end
    elseif backend == 'qb-target' then
        size = size or { x = 2.0, y = 2.0, z = 2.0 }
        Compat.SafeCall(function()
            exports['qb-target']:AddBoxZone(name, coords, size.x, size.y, {
                name = name,
                debugPoly = debug == true,
                heading = heading,
                minZ = coords.z - (size.z * 0.5),
                maxZ = coords.z + (size.z * 0.5),
            }, {
                options = options,
                distance = 2.5,
            })
        end)
        Target.Zones[name] = { name = name, backend = backend }
        return name
    end

    return AddFallbackZone(name, coords, tonumber(size and size.x) or 2.0, options)
end

local function AddSphereZone(name, coords, radius, options, debug)
    local backend = Target.GetResourceName()
    options = Target.FixOptions(options or {})
    coords = Compat.ToCoords(coords)

    if backend == 'ox_target' then
        local id = Compat.SafeCall(function()
            return OxOrSleepless('ox_target'):addSphereZone({
                name = name,
                coords = coords,
                radius = radius,
                debug = debug == true,
                options = options,
            })
        end)
        if id then
            Target.Zones[id] = { name = name, backend = backend, id = id }
            return id
        end
    elseif backend == 'sleepless_interact' then
        local id = Compat.SafeCall(function()
            return OxOrSleepless('sleepless_interact'):addSphereZone({
                name = name,
                coords = coords,
                radius = radius,
                debug = debug == true,
                options = options,
            })
        end)
        if id then
            Target.Zones[id] = { name = name, backend = backend, id = id }
            return id
        end
    elseif backend == 'qb-target' then
        Compat.SafeCall(function()
            exports['qb-target']:AddCircleZone(name, coords, radius, {
                name = name,
                debugPoly = debug == true,
            }, {
                options = options,
                distance = 2.5,
            })
        end)
        Target.Zones[name] = { name = name, backend = backend }
        return name
    end

    return AddFallbackZone(name, coords, tonumber(radius) or 2.0, options)
end

local function RemoveZone(name)
    if not name then return false end
    local backend = Target.GetResourceName()

    for key, zone in pairs(Target.Zones) do
        if zone.name == name or key == name then
            if backend == 'ox_target' then
                Compat.SafeCall(function() OxOrSleepless('ox_target'):removeZone(zone.id or name) end)
            elseif backend == 'sleepless_interact' then
                Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):removeCoords(zone.id or name) end)
            elseif backend == 'qb-target' then
                Compat.SafeCall(function() exports['qb-target']:RemoveZone(zone.name or name) end)
            end
            Target.Zones[key] = nil
            return true
        end
    end

    if Target.FallbackZones[name] then
        Target.FallbackZones[name] = nil
        return true
    end
    return false
end

function Target.DisableTargeting(disable)
    local backend = Target.GetResourceName()
    if backend == 'ox_target' then
        return Compat.SafeCall(function() OxOrSleepless('ox_target'):disableTargeting(disable == true) end)
    elseif backend == 'sleepless_interact' then
        return Compat.SafeCall(function() OxOrSleepless('sleepless_interact'):disableInteract(disable == true) end)
    elseif backend == 'qb-target' then
        return Compat.SafeCall(function() exports['qb-target']:AllowTargeting(not disable) end)
    end
    return false
end

-- Public method table --------------------------------------------------------

Target.AddGlobalPlayer = AddGlobalPlayer
Target.RemoveGlobalPlayer = RemoveGlobalPlayer
Target.AddGlobalPed = AddGlobalPed
Target.RemoveGlobalPed = RemoveGlobalPed
Target.AddGlobalVehicle = AddGlobalVehicle
Target.RemoveGlobalVehicle = RemoveGlobalVehicle
Target.AddLocalEntity = AddLocalEntity
Target.RemoveLocalEntity = RemoveLocalEntity
Target.AddNetworkedEntity = AddNetworkedEntity
Target.RemoveNetworkedEntity = RemoveNetworkedEntity
Target.AddModel = AddModel
Target.RemoveModel = RemoveModel
Target.AddBoxZone = AddBoxZone
Target.AddSphereZone = AddSphereZone
Target.AddCircleZone = AddSphereZone
Target.RemoveZone = RemoveZone

-- Clean up zones owned by this resource when it stops.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for name in pairs(Target.FallbackZones) do
        Target.FallbackZones[name] = nil
    end
    if type(HideText) == 'function' then HideText() end
end)

return Target
