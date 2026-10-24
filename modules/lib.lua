-- Qbox-compatible `qbx` utility library for Sandbox.
-- Shared module; client-only functions are guarded by IsDuplicityVersion().

qbx = qbx or {}

qbx.string = qbx.string or {}
qbx.math = qbx.math or {}
qbx.table = qbx.table or {}
qbx.array = qbx.array or {}

qbx.armsWithoutGloves = qbx.armsWithoutGloves or {
    male = {},
    female = {},
}

-- string --------------------------------------------------------------------

function qbx.string.trim(str)
    return (tostring(str):gsub('^%s+', ''):gsub('%s+$', ''))
end

function qbx.string.capitalize(str)
    str = tostring(str)
    return str:sub(1, 1):upper() .. str:sub(2)
end

-- math ----------------------------------------------------------------------

function qbx.math.round(num, decimalPlaces)
    local mult = 10 ^ (decimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- table ---------------------------------------------------------------------

function qbx.table.size(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

function qbx.table.mapBySubfield(tbl, subfield)
    local mapped = {}
    for _, value in pairs(tbl or {}) do
        local key = value[subfield]
        if key ~= nil then
            mapped[key] = mapped[key] or {}
            mapped[key][#mapped[key] + 1] = value
        end
    end
    return mapped
end

-- array ---------------------------------------------------------------------

function qbx.array.contains(arr, value)
    for _, entry in pairs(arr or {}) do
        if entry == value then return true end
    end
    return false
end

-- shared vehicle / direction ------------------------------------------------

function qbx.getVehiclePlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    local ok, plate = pcall(GetVehicleNumberPlateText, vehicle)
    if ok and plate and plate ~= '' then return plate end
    return nil
end

function qbx.generateRandomPlate(pattern)
    if lib and lib.string and lib.string.random then
        return lib.string.random(pattern or '........')
    end

    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    local out = {}
    for i = 1, 8 do
        local index = math.random(1, #chars)
        out[i] = chars:sub(index, index)
    end
    return table.concat(out)
end

function qbx.getCardinalDirection(entity)
    local heading = GetEntityHeading(entity) % 360.0
    if heading >= 315.0 or heading < 45.0 then return 'North' end
    if heading >= 45.0 and heading < 135.0 then return 'East' end
    if heading >= 135.0 and heading < 225.0 then return 'South' end
    return 'West'
end

-- server --------------------------------------------------------------------

if IsDuplicityVersion() then
    function qbx.spawnVehicle(params)
        if type(params) ~= 'table' or not params.model then return end

        local spawnSource = params.spawnSource
        local coords, heading = vector3(0.0, 0.0, 0.0), 0.0

        if type(spawnSource) == 'number' then
            coords = GetEntityCoords(spawnSource)
            heading = GetEntityHeading(spawnSource)
        elseif type(spawnSource) == 'vector4' then
            coords = vector3(spawnSource.x, spawnSource.y, spawnSource.z)
            heading = spawnSource.w or 0.0
        elseif type(spawnSource) == 'vector3' or type(spawnSource) == 'table' then
            coords = vector3(spawnSource.x or 0.0, spawnSource.y or 0.0, spawnSource.z or 0.0)
            heading = spawnSource.w or spawnSource.h or 0.0
        end

        local entity = select(2, pcall(CreateVehicle, params.model, coords.x, coords.y, coords.z, heading, true, true))
        if not entity or entity == 0 then
            entity = select(2, pcall(CreateVehicleServerSetter, params.model, 'automobile', coords.x, coords.y, coords.z, heading))
        end
        if not entity or entity == 0 then return end

        local netId = NetworkGetNetworkIdFromEntity(entity)

        if params.props then
            TriggerClientEvent('qbx_core:client:setVehicleProperties', -1, netId, params.props)
        end

        if params.warp then
            local ped = params.warp == true and spawnSource or params.warp
            if type(ped) == 'number' and ped > 0 then
                SetPedIntoVehicle(ped, entity, -1)
            end
        end

        if params.bucket then
            SetEntityRoutingBucket(entity, params.bucket)
        end

        local netId = NetworkGetNetworkIdFromEntity(entity)
        return netId, entity
    end

    return qbx
end

-- client --------------------------------------------------------------------

local function DrawTextEntry(text, x, y, scale, font, color, width, height, center, dropShadow, outline)
    SetTextFont(font or 4)
    SetTextScale(scale or 0.35, scale or 0.35)
    SetTextColour(color and color.x * 255 or 255, color and color.y * 255 or 255, color and color.z * 255 or 255, color and color.w * 255 or 255)
    SetTextCentre(center == true)
    SetTextDropShadow(dropShadow and 1 or 0)
    SetTextOutline(outline and 1 or 0)
    SetTextWrap(0.0, 1.0)
    SetTextEntry('STRING')
    AddTextComponentString(tostring(text))
    DrawText(x, y)
end

function qbx.drawText2d(params)
    if type(params) ~= 'table' then return end
    local coords = params.coords or vector2(0.5, 0.5)
    DrawTextEntry(
        params.text,
        coords.x,
        coords.y,
        params.scale,
        params.font,
        params.color,
        params.width,
        params.height,
        true,
        params.enableDropShadow,
        params.enableOutline
    )
end

function qbx.drawText3d(params)
    if type(params) ~= 'table' then return end
    local coords = params.coords or vector3(0.0, 0.0, 0.0)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    DrawTextEntry(
        params.text,
        0.0,
        0.0,
        type(params.scale) == 'table' and params.scale.x or params.scale,
        params.font,
        params.color,
        params.width,
        params.height,
        true,
        params.enableDropShadow,
        params.enableOutline
    )
    ClearDrawOrigin()
end

function qbx.getEntityAndNetIdFromBagName(bagName)
    local ok, entity = pcall(GetEntityFromStateBagName, bagName)
    if ok and entity and entity ~= 0 then
        return entity, NetworkGetNetworkIdFromEntity(entity)
    end
    return 0, 0
end

function qbx.entityStateHandler(keyFilter, cb)
    return AddStateBagChangeHandler(keyFilter, nil, function(bagName, key, value)
        local entity, netId = qbx.getEntityAndNetIdFromBagName(bagName)
        if entity ~= 0 then cb(entity, netId, value, bagName) end
    end)
end

function qbx.deleteVehicle(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
    return true
end

function qbx.getVehicleDisplayName(vehicle)
    if not vehicle then return '' end
    local model = GetEntityModel(vehicle)
    local name = GetDisplayNameFromVehicleModel(model)
    return GetLabelText(name)
end

function qbx.getVehicleMakeName(vehicle)
    if not vehicle then return '' end
    local make = GetMakeNameFromVehicleModel(GetEntityModel(vehicle))
    return GetLabelText(make)
end

function qbx.getVehicleModName(vehicle, modType, modIndex)
    local label = GetModTextLabel(vehicle, modType, modIndex)
    if not label or label == '' then return '' end
    return GetLabelText(label)
end

function qbx.getVehicleLiveryName(vehicle, liveryIndex)
    local label = GetLiveryName(vehicle, liveryIndex)
    if not label or label == '' then return '' end
    return GetLabelText(label)
end

function qbx.getStreetName(coords)
    local mainHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return {
        main = GetStreetNameFromHashKey(mainHash),
        cross = GetStreetNameFromHashKey(crossHash),
    }
end

function qbx.getZoneName(coords)
    return GetNameOfZone(coords.x, coords.y, coords.z)
end

function qbx.setVehicleExtra(vehicle, extra, enable)
    SetVehicleExtra(vehicle, extra, enable and 0 or 1)
end

function qbx.resetVehicleExtras(vehicle)
    for extra = 1, 20 do
        SetVehicleExtra(vehicle, extra, 0)
    end
end

function qbx.setVehicleExtras(vehicle, extras)
    for extra, enabled in pairs(extras or {}) do
        SetVehicleExtra(vehicle, extra, enabled and 0 or 1)
    end
end

function qbx.isWearingGloves()
    local ped = PlayerPedId()
    local drawable = GetPedDrawableVariation(ped, 3)
    local model = GetEntityModel(ped)
    local isMale = GetPedType(ped) == 4
    local list = isMale and qbx.armsWithoutGloves.male or qbx.armsWithoutGloves.female
    return not list[drawable]
end

function qbx.isWearingDuffelbag()
    local ped = PlayerPedId()
    return GetPedDrawableVariation(ped, 5) ~= 0
end

function qbx.loadAudioBank(audioBank, timeout)
    local ok = RequestScriptAudioBank(audioBank, false)
    local deadline = GetGameTimer() + (timeout or 1000)
    while not ok and GetGameTimer() < deadline do
        Wait(0)
        ok = RequestScriptAudioBank(audioBank, false)
    end
    return ok == true
end

function qbx.playAudio(params)
    if type(params) ~= 'table' then return end

    local audioName = params.audioName
    local audioRef = params.audioRef
    if not audioName or not audioRef then return end

    local soundId
    if type(params.audioSource) == 'number' then
        soundId = GetSoundId()
        PlaySoundFromEntity(soundId, audioName, params.audioSource, audioRef, false, 0)
    else
        local coords = params.audioSource or GetEntityCoords(PlayerPedId())
        soundId = GetSoundId()
        PlaySoundFromCoord(soundId, audioName, coords.x, coords.y, coords.z, audioRef, false, params.range or 10.0, false)
    end

    if not params.returnSoundId then
        ReleaseSoundId(soundId)
        return
    end

    return soundId
end

return qbx
