-- sandbox-bridge-lib/client/vehicle.lua
-- Loaded by client/main.lua in the shared bridge environment.
--
-- VehicleKey and Fuel compatibility. Both modules auto-detect the installed
-- resource, expose a single API (GiveKeys/RemoveKeys, GetFuel/SetFuel) and fall
-- back to native GTA behaviour when no supported resource is running.

SB = SB or {}

local Compat = SandboxBridgeCompat

-- ---------------------------------------------------------------------------
-- Vehicle resolution helpers
-- ---------------------------------------------------------------------------

local function NormalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:gsub('^%s+', ''):gsub('%s+$', ''):upper()
    if plate == '' then return nil end
    return plate
end

---Find a vehicle entity from any of the common inputs.
---@param vehicle number|table|nil Entity handle or { entity = handle }
---@param plate string|nil
---@return number|nil
local function ResolveVehicle(vehicle, plate)
    if type(vehicle) == 'table' then
        vehicle = vehicle.entity or vehicle.vehicle or vehicle.handle or vehicle.netId
    end

    vehicle = tonumber(vehicle)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end

    plate = NormalizePlate(plate)
    if not plate then return nil end

    local vehicles = type(GetGamePool) == 'function' and GetGamePool('CVehicle') or {}
    for _, entity in ipairs(vehicles) do
        if DoesEntityExist(entity) and NormalizePlate(GetVehicleNumberPlateText(entity)) == plate then
            return entity
        end
    end

    return nil
end

local function GetModelName(entity)
    if not entity or not DoesEntityExist(entity) then return nil end
    return GetDisplayNameFromVehicleModel(GetEntityModel(entity))
end

-- ---------------------------------------------------------------------------
-- Vehicle keys
-- ---------------------------------------------------------------------------

VehicleKey = {}
SB.VehicleKey = VehicleKey

VehicleKey.Providers = {}
VehicleKey.Keys = {}
VehicleKey.ResolveVehicle = ResolveVehicle

local function VehicleKeyConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.VehicleKey) or {}
end

function VehicleKey.GetAvailableResources()
    return Compat.GetStarted(Compat.VehicleKeyResources)
end

function VehicleKey.GetResourceName()
    local config = VehicleKeyConfig()
    if config.Enabled == false then return 'disabled' end
    local active = Compat.SelectConfigured(config, Compat.VehicleKeyResources)
    return active or 'default'
end

function VehicleKey.GetBackend()
    return VehicleKey.GetResourceName()
end

function VehicleKey.IsAvailable()
    local backend = VehicleKey.GetResourceName()
    return backend ~= 'default' and backend ~= 'disabled'
end

---Register a custom key provider.
---@param name string
---@param give function|nil function(entity|nil, plate, model)
---@param remove function|nil function(entity|nil, plate, model)
function VehicleKey.RegisterProvider(name, give, remove)
    if type(name) ~= 'string' then return false end
    VehicleKey.Providers[name] = { give = give, remove = remove }
    return true
end

---Run a provider without hiding a deliberate `false` return value.
local function RunProvider(callback, entity, plate, model)
    if type(callback) ~= 'function' then return false end
    local ok, result = pcall(callback, entity, plate, model)
    if not ok then
        if SandboxBridgeConfig and SandboxBridgeConfig.Debug then
            print(('[sandbox-bridge] vehicle key provider failed: %s'):format(tostring(result)))
        end
        return false
    end
    return result ~= false
end

local function ServerId()
    return GetPlayerServerId(PlayerId())
end

-- Default providers are registered in one place so servers can inspect or
-- replace them at runtime through VehicleKey.RegisterProvider.
VehicleKey.RegisterProvider('qbx_vehiclekeys',
    function(_, plate)
        TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
    end,
    function(_, plate)
        TriggerEvent('qb-vehiclekeys:client:RemoveKeys', plate)
    end
)

VehicleKey.RegisterProvider('qb-vehiclekeys',
    function(_, plate)
        TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
    end,
    function(_, plate)
        TriggerEvent('qb-vehiclekeys:client:RemoveKeys', plate)
    end
)

VehicleKey.RegisterProvider('qs-vehiclekeys',
    function(entity, plate)
        return exports['qs-vehiclekeys']:GiveKeys(plate, GetModelName(entity), true)
    end,
    function(entity, plate)
        return exports['qs-vehiclekeys']:RemoveKeys(plate, GetModelName(entity))
    end
)

VehicleKey.RegisterProvider('Renewed-Vehiclekeys',
    function(_, plate) return exports['Renewed-Vehiclekeys']:addKey(plate) end,
    function(_, plate) return exports['Renewed-Vehiclekeys']:removeKey(plate) end
)

VehicleKey.RegisterProvider('wasabi_carlock',
    function(_, plate) exports.wasabi_carlock:GiveKey(plate) end,
    function(_, plate) exports.wasabi_carlock:RemoveKey(plate) end
)

VehicleKey.RegisterProvider('mk_vehiclekeys',
    function(entity) exports['mk_vehiclekeys']:AddKey(entity) end,
    function(entity) exports['mk_vehiclekeys']:RemoveKey(entity) end
)

VehicleKey.RegisterProvider('MrNewbVehicleKeys',
    function(_, plate) return exports.MrNewbVehicleKeys:GiveKeysByPlate(plate) end,
    function(_, plate) return exports.MrNewbVehicleKeys:RemoveKeysByPlate(plate) end
)

VehicleKey.RegisterProvider('okokGarage',
    function(_, plate) TriggerServerEvent('okokGarage:GiveKeys', plate) end,
    function(_, plate) TriggerServerEvent('okokGarage:RemoveKeys', plate, ServerId()) end
)

VehicleKey.RegisterProvider('mVehicle',
    function(entity) exports.mVehicle:AddTemporalVehicleClient(entity) end,
    nil -- mVehicle does not expose key removal.
)

VehicleKey.RegisterProvider('jaksams_VehiclesKeys',
    function(_, plate) TriggerServerEvent('vehicles_keys:selfGiveVehicleKeys', plate) end,
    function(_, plate) TriggerServerEvent('vehicles_keys:selfRemoveKeys', plate) end
)

VehicleKey.RegisterProvider('F_RealCarKeysSystem',
    function(_, plate) TriggerServerEvent('F_RealCarKeysSystem:generateVehicleKeys', plate) end,
    function(_, plate) TriggerServerEvent('F_RealCarKeysSystem:removeVehicleKeysByPlate', plate) end
)

VehicleKey.RegisterProvider('t1ger_keys',
    function(entity, plate) return exports['t1ger_keys']:GiveTemporaryKeys(plate, GetModelName(entity), '') end,
    nil -- t1ger_keys does not expose key removal.
)

VehicleKey.RegisterProvider('cd_garage',
    function(_, plate) TriggerEvent('cd_garage:AddKeys', plate) end,
    nil
)

---Give the local player the keys of a vehicle.
---@param vehicle number|table|nil
---@param plate string|nil
---@return boolean success
---@return string backend
function VehicleKey.GiveKeys(vehicle, plate)
    local backend = VehicleKey.GetResourceName()
    local entity = ResolveVehicle(vehicle, plate)
    plate = NormalizePlate(plate) or (entity and NormalizePlate(GetVehicleNumberPlateText(entity))) or nil

    if not plate then return false, backend end
    local model = GetModelName(entity)

    local provider = VehicleKey.Providers[backend]
    local success = backend ~= 'default' and backend ~= 'disabled'
        and RunProvider(provider and provider.give, entity, plate, model)

    if not success then
        -- Native fallback: remember the plate locally and unlock the doors.
        VehicleKey.Keys[plate] = true
        if entity then SetVehicleDoorsLocked(entity, 1) end
        success = true
    end

    TriggerServerEvent('sandbox_bridge:server:vehicleKeys:given', plate)
    TriggerEvent('sandbox_bridge:client:vehicleKeys:given', plate, backend)
    return success, backend
end

---Give keys using only a plate (server relay friendly).
function VehicleKey.GiveKeysByPlate(plate)
    return VehicleKey.GiveKeys(nil, plate)
end

---Remove the local player's keys for a vehicle.
---@param vehicle number|table|nil
---@param plate string|nil
---@return boolean success
---@return string backend
function VehicleKey.RemoveKeys(vehicle, plate)
    local backend = VehicleKey.GetResourceName()
    local entity = ResolveVehicle(vehicle, plate)
    plate = NormalizePlate(plate) or (entity and NormalizePlate(GetVehicleNumberPlateText(entity))) or nil

    if not plate then return false, backend end
    local model = GetModelName(entity)

    local provider = VehicleKey.Providers[backend]
    local success = backend ~= 'default' and backend ~= 'disabled'
        and provider ~= nil and provider.remove ~= nil
        and RunProvider(provider.remove, entity, plate, model)

    VehicleKey.Keys[plate] = nil
    if not success then
        -- Nothing to remove when the resource does not support it. Report true
        -- because the local ownership table was cleared.
        success = true
    end

    TriggerServerEvent('sandbox_bridge:server:vehicleKeys:removed', plate)
    TriggerEvent('sandbox_bridge:client:vehicleKeys:removed', plate, backend)
    return success, backend
end

function VehicleKey.RemoveKeysByPlate(plate)
    return VehicleKey.RemoveKeys(nil, plate)
end

---Best-effort local ownership check.
function VehicleKey.HasKeys(plate)
    plate = NormalizePlate(plate)
    if not plate then return false end
    return VehicleKey.Keys[plate] == true
end

---Lock or unlock a vehicle with the local key used by the active resource.
function VehicleKey.SetLocked(vehicle, locked)
    local entity = ResolveVehicle(vehicle)
    if not entity then return false end
    SetVehicleDoorsLocked(entity, locked and 2 or 1)
    return true
end

-- Server relays --------------------------------------------------------------

RegisterNetEvent('sandbox_bridge:client:vehicleKeys:give', function(plate, netId)
    local entity = netId and NetToVeh(tonumber(netId) or 0) or nil
    if not entity or entity == 0 then entity = ResolveVehicle(nil, plate) end
    VehicleKey.GiveKeys(entity, plate)
end)

RegisterNetEvent('sandbox_bridge:client:vehicleKeys:remove', function(plate, netId)
    local entity = netId and NetToVeh(tonumber(netId) or 0) or nil
    if not entity or entity == 0 then entity = ResolveVehicle(nil, plate) end
    VehicleKey.RemoveKeys(entity, plate)
end)

-- ---------------------------------------------------------------------------
-- Fuel
-- ---------------------------------------------------------------------------

Fuel = {}
SB.Fuel = Fuel

Fuel.Providers = {}

local function FuelConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Fuel) or {}
end

function Fuel.GetAvailableResources()
    return Compat.GetStarted(Compat.FuelResources)
end

function Fuel.GetResourceName()
    local config = FuelConfig()
    if config.Enabled == false then return 'disabled' end
    local active = Compat.SelectConfigured(config, Compat.FuelResources)
    return active or 'default'
end

function Fuel.GetBackend()
    return Fuel.GetResourceName()
end

function Fuel.IsAvailable()
    local backend = Fuel.GetResourceName()
    return backend ~= 'default' and backend ~= 'disabled'
end

---Register a custom fuel provider.
---@param name string
---@param get function function(vehicle) -> number
---@param set function function(vehicle, fuel, fuelType)
function Fuel.RegisterProvider(name, get, set)
    if type(name) ~= 'string' then return false end
    Fuel.Providers[name] = { get = get, set = set }
    return true
end

local function EntityState(entity)
    if type(Entity) ~= 'function' then return nil end
    local ok, state = pcall(Entity, entity)
    if not ok then return nil end
    return state and state.state or nil
end

Fuel.RegisterProvider('ox_fuel',
    function(vehicle)
        local state = EntityState(vehicle)
        return state and tonumber(state.fuel) or GetVehicleFuelLevel(vehicle)
    end,
    function(vehicle, fuel)
        local state = EntityState(vehicle)
        if state then state.fuel = fuel end
        SetVehicleFuelLevel(vehicle, fuel + 0.0)
    end
)

for _, resource in ipairs({
    'ps-fuel', 'LegacyFuel', 'cdn-fuel', 'qb-fuel',
    'Renewed-Fuel', 'qs-fuelstations', 'lc_fuel',
}) do
    local resourceName = resource
    Fuel.RegisterProvider(resourceName,
        function(vehicle) return exports[resourceName]:GetFuel(vehicle) end,
        function(vehicle, fuel) exports[resourceName]:SetFuel(vehicle, fuel) end
    )
end

for _, resource in ipairs({ 'ti_fuel', 'x-fuel', 'esx-sna-fuel', 'okokGasStation', 'BigDaddy-Fuel' }) do
    local resourceName = resource
    Fuel.RegisterProvider(resourceName,
        function(vehicle)
            local level = exports[resourceName]:getFuel(vehicle)
            if type(level) == 'table' then level = level.fuel or level.level or level[1] end
            return level
        end,
        function(vehicle, fuel, fuelType)
            if resourceName == 'ti_fuel' then
                return exports[resourceName]:setFuel(vehicle, fuel, fuelType or 'RON91')
            end
            return exports[resourceName]:SetFuel(vehicle, fuel)
        end
    )
end

local function ClampFuel(value)
    value = tonumber(value) or 0.0
    if value < 0.0 then return 0.0 end
    if value > 100.0 then return 100.0 end
    return value
end

---Read a vehicle's fuel level (0-100).
---@param vehicle number
---@return number
function Fuel.GetFuel(vehicle)
    vehicle = tonumber(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0.0 end

    local backend = Fuel.GetResourceName()
    local provider = Fuel.Providers[backend]
    if provider and provider.get then
        local ok, value = pcall(provider.get, vehicle)
        if ok and tonumber(value) then return ClampFuel(value) end
    end

    return ClampFuel(GetVehicleFuelLevel(vehicle))
end

---Set a vehicle's fuel level (0-100).
---@param vehicle number
---@param fuel number
---@param fuelType string|nil only used by ti_fuel
---@return boolean
function Fuel.SetFuel(vehicle, fuel, fuelType)
    vehicle = tonumber(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    fuel = ClampFuel(fuel)
    local backend = Fuel.GetResourceName()
    local provider = Fuel.Providers[backend]
    if provider and provider.set then
        local ok, result = pcall(provider.set, vehicle, fuel, fuelType)
        if ok and result ~= false then
            TriggerEvent('sandbox_bridge:client:fuel:changed', vehicle, fuel, backend)
            return true
        end
    end

    SetVehicleFuelLevel(vehicle, fuel + 0.0)
    TriggerEvent('sandbox_bridge:client:fuel:changed', vehicle, fuel, 'native')
    return true
end

---Add (or remove, with a negative amount) fuel.
---@param vehicle number
---@param amount number
---@param fuelType string|nil
---@return boolean
function Fuel.AddFuel(vehicle, amount, fuelType)
    amount = tonumber(amount)
    if not amount then return false end
    return Fuel.SetFuel(vehicle, Fuel.GetFuel(vehicle) + amount, fuelType)
end

function Fuel.GetFuelType(vehicle)
    local backend = Fuel.GetResourceName()
    if backend == 'ti_fuel' and type(exports) == 'table' then
        local ok, _, fuelType = pcall(function()
            return exports['ti_fuel']:getFuel(tonumber(vehicle) or 0)
        end)
        if ok then return fuelType or 'RON91' end
    end
    return 'RON91'
end

return { VehicleKey = VehicleKey, Fuel = Fuel }
