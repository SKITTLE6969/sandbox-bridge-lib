-- sandbox-bridge-lib/client/appearance.lua
-- Loaded by client/main.lua in the shared bridge environment.
--
-- Clothing compatibility. Provides one appearance API over illenium-appearance,
-- fivem-appearance, rcore_clothing, qb-clothing and esx_skin, with a native
-- ped-component fallback so Sandbox scripts can still store/apply outfits.

SB = SB or {}

Clothing = {}
SB.Clothing = Clothing

local Compat = SandboxBridgeCompat

Clothing.Backup = {}
Clothing.Opened = false

local function ClothingConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Clothing) or {}
end

function Clothing.GetAvailableResources()
    return Compat.GetStarted(Compat.ClothingResources)
end

function Clothing.GetResourceName()
    local config = ClothingConfig()
    if config.Enabled == false then return 'disabled' end
    local active = Compat.SelectConfigured(config, Compat.ClothingResources)
    return active or 'default'
end

function Clothing.GetBackend()
    return Clothing.GetResourceName()
end

function Clothing.IsAvailable()
    local backend = Clothing.GetResourceName()
    return backend ~= 'default' and backend ~= 'disabled'
end

function Clothing.IsMale(entity)
    entity = tonumber(entity) or PlayerPedId()
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    return GetEntityModel(entity) == GetHashKey('mp_m_freemode_01')
end

-- ---------------------------------------------------------------------------
-- QBCore skin table <-> ped components
-- ---------------------------------------------------------------------------

-- QBCore clothing key -> ped component id.
Clothing.ComponentMap = {
    mask_1 = 1,
    arms = 3,
    pants_1 = 4,
    bags_1 = 5,
    shoes_1 = 6,
    chain_1 = 7,
    tshirt_1 = 8,
    bproof_1 = 9,
    decals_1 = 10,
    torso_1 = 11,
}

-- QBCore clothing key -> prop id.
Clothing.PropMap = {
    helmet_1 = 0,
    glasses_1 = 1,
    ears_1 = 2,
    watch_1 = 6,
    bracelets_1 = 7,
}

local function SafeNumber(value)
    return tonumber(value) or 0
end

---Convert a QBCore style skin table into { components, props }.
function Clothing.FromQBSkin(skin)
    skin = type(skin) == 'table' and skin or {}
    local components, props = {}, {}

    for key, componentId in pairs(Clothing.ComponentMap) do
        local drawable = skin[key]
        if drawable ~= nil then
            local textureKey = key:gsub('_1$', '_2')
            components[#components + 1] = {
                component_id = componentId,
                drawable = SafeNumber(drawable),
                texture = SafeNumber(skin[textureKey]),
            }
        end
    end

    for key, propId in pairs(Clothing.PropMap) do
        local drawable = skin[key]
        if drawable ~= nil and SafeNumber(drawable) ~= -1 then
            local textureKey = key:gsub('_1$', '_2')
            props[#props + 1] = {
                prop_id = propId,
                drawable = SafeNumber(drawable),
                texture = SafeNumber(skin[textureKey]),
            }
        end
    end

    return { components = components, props = props, model = skin.model }
end

---Convert { components, props } into a QBCore style skin table.
function Clothing.ToQBSkin(skin)
    skin = type(skin) == 'table' and skin or {}
    local result = {}

    for _, component in ipairs(skin.components or {}) do
        for key, id in pairs(Clothing.ComponentMap) do
            if id == SafeNumber(component.component_id) then
                result[key] = SafeNumber(component.drawable)
                result[key:gsub('_1$', '_2')] = SafeNumber(component.texture)
            end
        end
    end

    for _, prop in ipairs(skin.props or {}) do
        for key, id in pairs(Clothing.PropMap) do
            if id == SafeNumber(prop.prop_id) then
                result[key] = SafeNumber(prop.drawable)
                result[key:gsub('_1$', '_2')] = SafeNumber(prop.texture)
            end
        end
    end

    return result
end

-- ---------------------------------------------------------------------------
-- Native appearance
-- ---------------------------------------------------------------------------

local function GetNativeAppearance(entity)
    entity = tonumber(entity) or PlayerPedId()
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    local data = {
        model = GetEntityModel(entity),
        components = {},
        props = {},
    }

    for id = 0, 11 do
        data.components[#data.components + 1] = {
            component_id = id,
            drawable = GetPedDrawableVariation(entity, id),
            texture = GetPedTextureVariation(entity, id),
            palette = GetPedPaletteVariation(entity, id),
        }
    end

    for id = 0, 13 do
        data.props[#data.props + 1] = {
            prop_id = id,
            drawable = GetPedPropIndex(entity, id),
            texture = GetPedPropTextureIndex(entity, id),
        }
    end

    return data
end

local function SetNativeAppearance(entity, data)
    entity = tonumber(entity) or PlayerPedId()
    if not entity or entity == 0 or not DoesEntityExist(entity) or type(data) ~= 'table' then
        return false
    end

    -- Accept QBCore skins transparently.
    if not data.components and not data.props then
        data = Clothing.FromQBSkin(data)
    end

    for _, component in ipairs(data.components or {}) do
        local id = tonumber(component.component_id) or tonumber(component.id)
        if id then
            SetPedComponentVariation(
                entity,
                id,
                SafeNumber(component.drawable),
                SafeNumber(component.texture),
                SafeNumber(component.palette)
            )
        end
    end

    for _, prop in ipairs(data.props or {}) do
        local id = tonumber(prop.prop_id) or tonumber(prop.id)
        if id then
            local drawable = SafeNumber(prop.drawable)
            if drawable < 0 then
                ClearPedProp(entity, id)
            else
                SetPedPropIndex(entity, id, drawable, SafeNumber(prop.texture), true)
            end
        end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Resource adapters
-- ---------------------------------------------------------------------------

local AppearanceAdapters = {}

AppearanceAdapters['illenium-appearance'] = {
    get = function(entity)
        return exports['illenium-appearance']:getPedAppearance(entity)
    end,
    set = function(entity, data)
        if data.components or data.props then
            exports['illenium-appearance']:setPedAppearance(entity, data)
        else
            exports['illenium-appearance']:setPlayerAppearance(data)
        end
        return true
    end,
    open = function()
        TriggerEvent('qb-clothing:client:openMenu')
        TriggerEvent('illenium-appearance:client:openClothingMenu')
    end,
}

AppearanceAdapters['fivem-appearance'] = {
    get = function(entity)
        return exports['fivem-appearance']:getPedAppearance(entity)
    end,
    set = function(entity, data)
        if data.components or data.props then
            exports['fivem-appearance']:setPedAppearance(entity, data)
        else
            exports['fivem-appearance']:setPlayerAppearance(data)
        end
        return true
    end,
    open = function()
        TriggerEvent('fivem-appearance:client:openClothingMenu')
    end,
}

AppearanceAdapters['rcore_clothing'] = {
    get = function(entity)
        return exports['rcore_clothing']:getPedAppearance(entity)
    end,
    set = function(entity, data)
        exports['rcore_clothing']:setPedAppearance(entity, data)
        return true
    end,
    open = function()
        TriggerEvent('rcore_clothing:openClothingMenu')
    end,
}

AppearanceAdapters['qb-clothing'] = {
    get = GetNativeAppearance,
    set = SetNativeAppearance,
    open = function()
        TriggerEvent('qb-clothing:client:openMenu')
    end,
}

AppearanceAdapters['esx_skin'] = {
    get = GetNativeAppearance,
    set = SetNativeAppearance,
    open = function()
        TriggerEvent('esx_skin:openSaveableMenu')
    end,
}

---Read the appearance of a ped and store it as the restore point.
---@param entity number|nil
---@return table|nil
function Clothing.GetAppearance(entity)
    entity = tonumber(entity) or PlayerPedId()
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    local backend = Clothing.GetResourceName()
    local adapter = AppearanceAdapters[backend]
    local appearance

    if adapter and adapter.get then
        local ok, result = pcall(adapter.get, entity)
        if ok and type(result) == 'table' then appearance = result end
    end

    appearance = appearance or GetNativeAppearance(entity)
    Clothing.Backup[entity] = appearance
    return appearance
end

Clothing.GetSkin = Clothing.GetAppearance

---Apply appearance data to a ped.
---@param entity number|nil
---@param data table
---@return boolean
function Clothing.SetAppearance(entity, data)
    entity = tonumber(entity) or PlayerPedId()
    if not entity or entity == 0 or not DoesEntityExist(entity) or type(data) ~= 'table' then
        return false
    end

    local backend = Clothing.GetResourceName()
    local adapter = AppearanceAdapters[backend]

    if adapter and adapter.set then
        local ok, result = pcall(adapter.set, entity, data)
        if ok and result ~= false then
            TriggerEvent('sandbox_bridge:client:clothing:changed', entity, backend)
            return true
        end
    end

    local applied = SetNativeAppearance(entity, data)
    if applied then
        TriggerEvent('sandbox_bridge:client:clothing:changed', entity, 'native')
    end
    return applied
end

Clothing.SetSkin = Clothing.SetAppearance

---Restore the last appearance read through Clothing.GetAppearance.
---@param entity number|nil
---@return boolean
function Clothing.RestoreAppearance(entity)
    entity = tonumber(entity) or PlayerPedId()
    local backup = Clothing.Backup[entity]
    if not backup then return false end

    local restored = Clothing.SetAppearance(entity, backup)
    Clothing.Backup[entity] = nil
    return restored
end

---Open the active clothing menu.
---@return boolean
function Clothing.OpenMenu()
    local backend = Clothing.GetResourceName()
    local adapter = AppearanceAdapters[backend]
    if not adapter or not adapter.open then return false end

    local ok = pcall(adapter.open)
    if ok then Clothing.Opened = true end
    return ok
end

Clothing.Open = Clothing.OpenMenu

---Alias kept for Community Bridge callers.
function Clothing.IsMalePed(entity)
    return Clothing.IsMale(entity)
end

---Server relays for scripts that drive appearance from the server.
RegisterNetEvent('sandbox_bridge:client:clothing:set', function(data)
    Clothing.SetAppearance(PlayerPedId(), data)
end)

RegisterNetEvent('sandbox_bridge:client:clothing:get', function(requestId)
    TriggerServerEvent('sandbox_bridge:server:clothing:response', requestId, Clothing.GetAppearance(PlayerPedId()))
end)

RegisterNetEvent('sandbox_bridge:client:clothing:restore', function()
    Clothing.RestoreAppearance(PlayerPedId())
end)

RegisterNetEvent('sandbox_bridge:client:clothing:open', function()
    Clothing.OpenMenu()
end)

return { Clothing = Clothing }
