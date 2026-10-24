-- sandbox-bridge-lib/client/dev.lua
-- Loaded by client/main.lua in the shared bridge environment.
--
-- Developer helpers used by Sandbox resources: 3D interaction points, cutscenes,
-- particles, scaleforms, DUI screens and object placement. None of these need a
-- third-party resource; they are thin, guarded wrappers around GTA natives with
-- the bookkeeping (threads, handles, cleanup) handled once.

SB = SB or {}

local Compat = SandboxBridgeCompat

local function DevConfig()
    return (SandboxBridgeConfig and SandboxBridgeConfig.Dev) or {}
end

Dev = {}
SB.Dev = Dev

function Dev.IsDebug()
    return DevConfig().Debug == true
end

function Dev.GetPointDistance()
    return tonumber(DevConfig().PointDistance) or 2.0
end

-- ---------------------------------------------------------------------------
-- 3D interaction points
-- ---------------------------------------------------------------------------

Points = {}
SB.Points = Points

Points.All = {}
Points.Sequence = 0
Points.Started = false

local function PointDistance(point, coords)
    return #(coords - point.coords)
end

local function StartPointLoop()
    if Points.Started then return end
    Points.Started = true

    CreateThread(function()
        while true do
            local sleep = 750
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local nearestDistance = math.huge

            for id, point in pairs(Points.All) do
                local distance = PointDistance(point, coords)
                if distance < nearestDistance then nearestDistance = distance end

                if distance <= point.distance then
                    sleep = 0
                    point.inside = true

                    if point.marker then
                        DrawMarker(
                            point.marker.type or 1,
                            point.coords.x, point.coords.y, point.coords.z,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            point.marker.scale or 0.35,
                            point.marker.scale or 0.35,
                            point.marker.scale or 0.35,
                            point.marker.r or 255,
                            point.marker.g or 255,
                            point.marker.b or 255,
                            point.marker.a or 150,
                            false, true, 2, false, nil, nil, false
                        )
                    end

                    if point.entity and DoesEntityExist(point.entity) then
                        local entityCoords = GetEntityCoords(point.entity)
                        if type(ShowText) == 'function' then
                            ShowText(point.label or 'Interact', 500)
                        end
                        if IsControlJustPressed(0, 38) then
                            if point.onSelect then point.onSelect(point.entity, point) end
                        end
                        point.coords = entityCoords
                    else
                        if type(ShowText) == 'function' then
                            ShowText(point.label or 'Interact', 500)
                        end
                        if IsControlJustPressed(0, 38) then
                            if point.onSelect then point.onSelect(point) end
                        end
                    end
                elseif point.inside then
                    point.inside = false
                    if point.onExit then pcall(point.onExit, point.entity, point) end
                    if type(HideText) == 'function' then HideText() end
                end
            end

            if sleep == 0 and nearestDistance > 10.0 then sleep = 500 end
            Wait(sleep)
        end
    end)
end

---Register a 3D interaction point.
--- Accepts either the options table form or the positional form used by older
--- Sandbox scripts: Register(id, coords, distance, label, onSelect).
---@param id string|number|nil
---@param coords any
---@param options table|number|nil
---@param label string|nil
---@param onSelect function|nil
---@return string id
function Points.Register(id, coords, options, label, onSelect)
    if type(options) ~= 'table' then
        options = {
            distance = tonumber(options),
            label = label,
            onSelect = onSelect,
        }
    end

    if id == nil then
        Points.Sequence = Points.Sequence + 1
        id = ('point-%d'):format(Points.Sequence)
    end
    id = tostring(id)

    local point = {
        id = id,
        coords = Compat.ToCoords(coords) or vector3(0.0, 0.0, 0.0),
        distance = tonumber(options.distance or options.radius) or Dev.GetPointDistance(),
        label = options.label or options.name or 'Interact',
        marker = options.marker or (Dev.IsDebug() and { type = 1 } or nil),
        entity = tonumber(options.entity),
        onEnter = options.onEnter,
        onExit = options.onExit,
        onSelect = options.onSelect or options.action,
        onRemove = options.onRemove,
        data = options.data,
        inside = false,
    }

    Points.All[id] = point
    StartPointLoop()
    return id
end

---Alias matching Community Bridge's Point module.
Point = Points

function Points.Get(id)
    return Points.All[tostring(id)]
end

function Points.Remove(id)
    id = tostring(id)
    local point = Points.All[id]
    if not point then return false end
    Points.All[id] = nil
    if point.onRemove then pcall(point.onRemove, point) end
    return true
end

function Points.Clear()
    for id in pairs(Points.All) do Points.Remove(id) end
end

function Points.Has(id)
    return Points.All[tostring(id)] ~= nil
end

Points.Add = Points.Register

-- ---------------------------------------------------------------------------
-- Cutscenes
-- ---------------------------------------------------------------------------

Cutscene = {}
SB.Cutscene = Cutscene

Cutscene.Active = false

local function LoadCutscene(name)
    if type(RequestCutscene) ~= 'function' then return false end
    RequestCutscene(name, 8)

    local deadline = GetGameTimer() + 10000
    while not HasCutsceneLoaded() do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

---Play a GTA cutscene. Returns immediately; the scene stops itself after
---`options.duration` (or when the cutscene finishes when `options.await` is set).
---@param name string
---@param coords any|nil
---@param heading number|nil
---@param options table|nil
---@return boolean started
function Cutscene.Play(name, coords, heading, options)
    if type(name) ~= 'string' or name == '' then return false end
    options = type(options) == 'table' and options or {}
    if Cutscene.Active then return false end
    if not LoadCutscene(name) then return false end

    coords = Compat.ToCoords(coords)
    Cutscene.Active = true

    if coords then
        StartCutsceneAtCoords(coords.x, coords.y, coords.z, 8)
        if heading then SetEntityHeading(PlayerPedId(), heading + 0.0) end
    else
        StartCutscene(8)
    end

    CreateThread(function()
        local deadline = options.duration and (GetGameTimer() + tonumber(options.duration) * 1000) or nil
        while Cutscene.Active do
            Wait(0)
            if HasCutsceneFinished() then break end
            if deadline and GetGameTimer() > deadline then break end
        end

        StopCutscene()
        RemoveCutscene()
        Cutscene.Active = false
        if options.onFinish then options.onFinish() end
    end)

    return true
end

---Play a cutscene and block until it finishes.
function Cutscene.PlayAndWait(name, coords, heading, options)
    options = type(options) == 'table' and options or {}
    options.await = true
    if not Cutscene.Play(name, coords, heading, options) then return false end
    while Cutscene.Active do Wait(0) end
    return true
end

function Cutscene.Stop()
    if not Cutscene.Active then return false end
    Cutscene.Active = false
    StopCutscene()
    RemoveCutscene()
    return true
end

-- ---------------------------------------------------------------------------
-- Particles
-- ---------------------------------------------------------------------------

Particles = {}
SB.Particles = Particles

Particles.Active = {}

local function LoadPtfx(dict)
    if type(RequestNamedPtfxAsset) ~= 'function' then return false end
    RequestNamedPtfxAsset(dict)

    local deadline = GetGameTimer() + 5000
    while not HasNamedPtfxAssetLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

---Play a particle effect.
---@param dict string
---@param effect string
---@param coords any
---@param rotation any|nil
---@param scale number|nil
---@param duration number|nil milliseconds (0 = stay until Particles.Stop)
---@param options table|nil loop=false, nonLooped=false
---@return table|nil handle
function Particles.Play(dict, effect, coords, rotation, scale, duration, options)
    if type(dict) ~= 'string' or type(effect) ~= 'string' then return nil end
    options = type(options) == 'table' and options or {}
    coords = Compat.ToCoords(coords)
    if not coords then return nil end
    if not LoadPtfx(dict) then return nil end

    local rot = Compat.ToCoords(rotation) or vector3(0.0, 0.0, 0.0)
    local handle = {
        dict = dict,
        effect = effect,
        coords = coords,
        active = true,
    }

    UseParticleFxAssetNextCall(dict)
    if options.nonLooped then
        handle.ptfx = StartParticleFxNonLoopedAtCoord(
            effect,
            coords.x, coords.y, coords.z,
            rot.x, rot.y, rot.z,
            tonumber(scale) or 1.0,
            false, false, false
        )
    else
        handle.ptfx = StartParticleFxLoopedAtCoord(
            effect,
            coords.x, coords.y, coords.z,
            rot.x, rot.y, rot.z,
            tonumber(scale) or 1.0,
            options.xAxis == true,
            options.yAxis == true,
            options.zAxis == true,
            false
        )
    end

    Particles.Active[handle.ptfx or ('ptfx-%d'):format(#Particles.Active + 1)] = handle
    handle.key = handle.ptfx or ('ptfx-%d'):format(#Particles.Active)
    duration = tonumber(duration) or 0

    if duration > 0 then
        CreateThread(function()
            Wait(duration)
            Particles.Stop(handle)
        end)
    end

    return handle
end

---Stop a particle handle returned by Particles.Play.
function Particles.Stop(handle)
    if type(handle) ~= 'table' then return false end
    if not handle.active then return false end
    handle.active = false

    if handle.ptfx and handle.ptfx ~= 0 and type(StopParticleFxLooped) == 'function' then
        pcall(StopParticleFxLooped, handle.ptfx, false)
    end

    Particles.Active[handle.key] = nil
    return true
end

function Particles.StopAll()
    for _, handle in pairs(Particles.Active) do
        Particles.Stop(handle)
    end
    Particles.Active = {}
end

-- ---------------------------------------------------------------------------
-- Scaleforms
-- ---------------------------------------------------------------------------

Scaleform = {}
SB.Scaleform = Scaleform

Scaleform.Active = {}

---Request a scaleform movie.
---@param name string
---@param timeout number|nil milliseconds
---@return number|nil handle
function Scaleform.Request(name, timeout)
    if type(name) ~= 'string' then return nil end

    local handle = RequestScaleformMovie(name)
    local deadline = GetGameTimer() + (tonumber(timeout) or 5000)
    while not HasScaleformMovieLoaded(handle) do
        if GetGameTimer() > deadline then return nil end
        Wait(0)
    end

    Scaleform.Active[handle] = name
    return handle
end

---Call a scaleform method, for example:
---Scaleform.Call(handle, 'SET_DETAIL_TEXT', 'Hello')
---@param handle number
---@param method string
---@param ... any
function Scaleform.Call(handle, method, ...)
    if not handle or not HasScaleformMovieLoaded(handle) then return false end

    BeginScaleformMovieMethod(handle, method)
    for index = 1, select('#', ...) do
        local value = select(index, ...)
        local valueType = type(value)
        if valueType == 'number' then
            ScaleformMovieMethodAddParamInt(math.floor(value))
        elseif valueType == 'boolean' then
            ScaleformMovieMethodAddParamBool(value)
        else
            ScaleformMovieMethodAddParamPlayerNameString(tostring(value))
        end
    end
    EndScaleformMovieMethod()
    return true
end

function Scaleform.Draw(handle, x, y, width, height)
    if not handle or not HasScaleformMovieLoaded(handle) then return false end
    DrawScaleformMovie(handle, x or 0.5, y or 0.5, width or 1.0, height or 1.0, 255, 255, 255, 255, 0)
    return true
end

function Scaleform.DrawFullscreen(handle)
    if not handle or not HasScaleformMovieLoaded(handle) then return false end
    DrawScaleformMovieFullscreen(handle, 255, 255, 255, 255, 0)
    return true
end

function Scaleform.Release(handle)
    if not handle then return false end
    if HasScaleformMovieLoaded(handle) then
        SetScaleformMovieAsNoLongerNeeded(handle)
    end
    Scaleform.Active[handle] = nil
    return true
end

-- ---------------------------------------------------------------------------
-- DUI
-- ---------------------------------------------------------------------------

DUI = {}
SB.DUI = DUI

DUI.Active = {}
DUI.Sequence = 0

local function MaxDui()
    return tonumber(DevConfig().MaxDui) or 16
end

---Create a DUI screen plus a runtime texture that can be drawn.
---@param url string
---@param width number|nil
---@param height number|nil
---@return table|nil dui
function DUI.Create(url, width, height)
    if type(url) ~= 'string' or url == '' then return nil end
    if type(CreateDui) ~= 'function' then return nil end

    local count = 0
    for _ in pairs(DUI.Active) do count = count + 1 end
    if count >= MaxDui() then return nil end

    width = tonumber(width) or 1280
    height = tonumber(height) or 720

    local handle = CreateDui(url, width, height)
    if not handle or handle == 0 then return nil end

    DUI.Sequence = DUI.Sequence + 1
    local index = DUI.Sequence
    local dui = {
        index = index,
        dui = handle,
        url = url,
        width = width,
        height = height,
        handle = GetDuiHandle(handle),
        txd = ('sb_dui_txd_%d'):format(index),
        txn = ('sb_dui_tex_%d'):format(index),
    }

    dui.texture = CreateRuntimeTextureFromDuiHandle(dui.txd, dui.txn, dui.handle)
    DUI.Active[index] = dui
    return dui
end

---Send a JSON message to a DUI screen.
function DUI.Send(dui, message)
    if type(dui) ~= 'table' or not dui.dui then return false end
    if type(message) == 'table' then message = json.encode(message) end
    return pcall(SendDuiMessage, dui.dui, tostring(message or ''))
end

---Change the URL of an existing DUI screen.
function DUI.SetUrl(dui, url)
    if type(dui) ~= 'table' or not dui.dui or type(url) ~= 'string' then return false end
    dui.url = url
    return pcall(function()
        RequestDuiUpdate(dui.dui)
    end)
end

---Draw a DUI screen as a sprite.
function DUI.Draw(dui, x, y, width, height, alpha)
    if type(dui) ~= 'table' or not dui.txd then return false end
    DrawSprite(dui.txd, dui.txn, x, y, width, height, 255, 255, 255, alpha or 255)
    return true
end

function DUI.Remove(dui)
    if type(dui) ~= 'table' or not dui.dui then return false end
    pcall(DestroyDui, dui.dui)
    DUI.Active[dui.index] = nil
    return true
end

function DUI.RemoveAll()
    for _, dui in pairs(DUI.Active) do DUI.Remove(dui) end
    DUI.Active = {}
end

-- ---------------------------------------------------------------------------
-- Object placement
-- ---------------------------------------------------------------------------

Placeable = {}
SB.Placeable = Placeable

Placeable.Active = {}
Placeable.Sequence = 0

local function PlacementCoords(distance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local target = coords + forward * distance

    local found, groundZ = GetGroundZFor_3dCoord(target.x, target.y, target.z + 5.0, false)
    if found then target = vector3(target.x, target.y, groundZ) end
    return target
end

---Start an object placement preview.
---@param model string|number
---@param options table|nil { distance, heading, rotation, onConfirm, onCancel }
---@return table|nil state
function Placeable.Start(model, options)
    options = type(options) == 'table' and options or {}
    if model == nil then return nil end

    local hash = type(model) == 'number' and model or GetHashKey(model)
    RequestModel(hash)

    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(0)
    end

    local distance = tonumber(options.distance) or 3.0
    local coords = PlacementCoords(distance)
    local entity = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    if not entity or entity == 0 then return nil end

    Placeable.Sequence = Placeable.Sequence + 1
    local state = {
        id = Placeable.Sequence,
        entity = entity,
        model = hash,
        distance = distance,
        heading = tonumber(options.heading) or GetEntityHeading(PlayerPedId()),
        rotation = Compat.ToCoords(options.rotation) or vector3(0.0, 0.0, 0.0),
        onConfirm = options.onConfirm,
        onCancel = options.onCancel,
        active = true,
    }

    SetEntityAlpha(entity, 170, false)
    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, true)
    SetEntityRotation(entity, state.rotation.x, state.rotation.y, state.heading, 2, true)

    Placeable.Active[state.id] = state

    CreateThread(function()
        while state.active and DoesEntityExist(entity) do
            Wait(0)
            local playerPed = PlayerPedId()
            local location = PlacementCoords(state.distance)

            if IsControlPressed(0, 174) then -- left arrow
                state.heading = state.heading - 2.0
            elseif IsControlPressed(0, 175) then -- right arrow
                state.heading = state.heading + 2.0
            end

            SetEntityCoords(entity, location.x, location.y, location.z, false, false, false, false)
            SetEntityRotation(entity, state.rotation.x, state.rotation.y, state.heading, 2, true)

            if IsControlJustPressed(0, 38) then -- E
                Placeable.Confirm(state)
            elseif IsControlJustPressed(0, 177) then -- Backspace
                Placeable.Cancel(state)
            end
        end
    end)

    return state
end

---Finish placement and return the spawned object data.
---@param state table
---@return table|nil placement { entity, model, coords, rotation, heading }
function Placeable.Confirm(state)
    if type(state) ~= 'table' or not state.active then return nil end
    state.active = false

    local entity = state.entity
    local coords = DoesEntityExist(entity) and GetEntityCoords(entity) or nil
    local rotation = DoesEntityExist(entity) and GetEntityRotation(entity, 2) or vector3(0.0, 0.0, 0.0)

    if DoesEntityExist(entity) then
        SetEntityAlpha(entity, 255, false)
        SetEntityCollision(entity, true, true)
        FreezeEntityPosition(entity, false)
    end

    Placeable.Active[state.id] = nil

    local placement = {
        entity = entity,
        model = state.model,
        coords = coords or state.rotation,
        rotation = rotation,
        heading = state.heading,
    }

    if state.onConfirm then pcall(state.onConfirm, placement) end
    TriggerEvent('sandbox_bridge:client:placeable:confirmed', placement)
    return placement
end

---Cancel placement and delete the preview object.
function Placeable.Cancel(state)
    if type(state) ~= 'table' or not state.active then return false end
    state.active = false

    if DoesEntityExist(state.entity) then DeleteEntity(state.entity) end
    Placeable.Active[state.id] = nil

    if state.onCancel then pcall(state.onCancel, state) end
    TriggerEvent('sandbox_bridge:client:placeable:cancelled', state)
    return true
end

function Placeable.IsActive(state)
    return type(state) == 'table' and state.active == true
end

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Points.Clear()
    Particles.StopAll()
    DUI.RemoveAll()
    for _, state in pairs(Placeable.Active) do Placeable.Cancel(state) end
    for handle in pairs(Scaleform.Active) do Scaleform.Release(handle) end
    Cutscene.Stop()
end)

-- Aggregate table for scripts that prefer one developer namespace.
Dev.Points = Points
Dev.Cutscene = Cutscene
Dev.Particles = Particles
Dev.Scaleform = Scaleform
Dev.DUI = DUI
Dev.Placeable = Placeable

return {
    Points = Points,
    Cutscene = Cutscene,
    Particles = Particles,
    Scaleform = Scaleform,
    DUI = DUI,
    Placeable = Placeable,
}
