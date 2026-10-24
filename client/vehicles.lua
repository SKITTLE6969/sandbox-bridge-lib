-- sandbox-bridge-lib/client/vehicles.lua
-- Loaded by client/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Vehicle helpers
-- ---------------------------------------------------------------------------

MOD_KEYS = {
    'modSpoilers', 'modFrontBumper', 'modRearBumper', 'modSideSkirt', 'modExhaust',
    'modFrame', 'modGrille', 'modHood', 'modFender', 'modRightFender', 'modRoof',
    'modEngine', 'modBrakes', 'modTransmission', 'modHorns', 'modSuspension',
    'modArmor', 'modTurbo', 'modSmokeEnabled', 'modXenon', 'modFrontWheels',
    'modBackWheels', 'modCustomTiresF', 'modCustomTiresR', 'modPlateHolder',
    'modVanityPlate', 'modTrimA', 'modOrnaments', 'modDashboard', 'modDial',
    'modDoorSpeaker', 'modSeats', 'modSteeringWheel', 'modShifterLeavers',
    'modAPlate', 'modSpeakers', 'modTrunk', 'modHydrolic', 'modEngineBlock',
    'modAirFilter', 'modStruts', 'modArchCover', 'modAerials', 'modTrimB',
    'modTank', 'modWindows', 'modLivery', 'modRoofLivery',
}

function GetVehicleProperties(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return {} end

    local properties = {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        fuelLevel = GetVehicleFuelLevel(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        oilLevel = GetVehicleOilLevel(vehicle),
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        livery = GetVehicleMod(vehicle, 48),
        roofLivery = GetVehicleMod(vehicle, 49),
        xenon = IsToggleModOn(vehicle, 22),
        xenonColor = GetVehicleHeadlightsColour(vehicle),
    }

    local color1, color2 = GetVehicleColours(vehicle)
    properties.color1 = color1
    properties.color2 = color2

    local pearlescent, wheelColor = GetVehicleExtraColours(vehicle)
    properties.pearlescentColor = pearlescent
    properties.wheelColor = wheelColor

    local smokeR, smokeG, smokeB = GetVehicleTyreSmokeColor(vehicle)
    properties.tyreSmokeColor = { r = smokeR, g = smokeG, b = smokeB }

    local neonR, neonG, neonB = GetVehicleNeonLightsColour(vehicle)
    properties.neonColor = { r = neonR, g = neonG, b = neonB }
    properties.neonEnabled = {
        GetVehicleNeonLightsOn(vehicle, 0),
        GetVehicleNeonLightsOn(vehicle, 1),
        GetVehicleNeonLightsOn(vehicle, 2),
        GetVehicleNeonLightsOn(vehicle, 3),
    }

    local dashR, dashG, dashB = GetVehicleDashboardColour(vehicle)
    properties.dashColour = { r = dashR, g = dashG, b = dashB }

    local interiorR, interiorG, interiorB = GetVehicleInteriorColour(vehicle)
    properties.interiorColour = { r = interiorR, g = interiorG, b = interiorB }

    for index, key in ipairs(MOD_KEYS) do
        properties[key] = GetVehicleMod(vehicle, index - 1)
    end

    return properties
end

function SetVehicleProperties(vehicle, properties)
    if not vehicle or not DoesEntityExist(vehicle) or type(properties) ~= 'table' then return false end

    if properties.plate then SetVehicleNumberPlateText(vehicle, properties.plate) end
    if properties.color1 and properties.color2 then
        SetVehicleColours(vehicle, properties.color1, properties.color2)
    end
    if properties.pearlescentColor and properties.wheelColor then
        SetVehicleExtraColours(vehicle, properties.pearlescentColor, properties.wheelColor)
    end
    if properties.wheels then SetVehicleWheelType(vehicle, properties.wheels) end
    if properties.windowTint then SetVehicleWindowTint(vehicle, properties.windowTint) end
    if properties.livery then SetVehicleMod(vehicle, 48, properties.livery, false) end
    if properties.roofLivery then SetVehicleMod(vehicle, 49, properties.roofLivery, false) end

    for index, key in ipairs(MOD_KEYS) do
        if properties[key] then
            SetVehicleMod(vehicle, index - 1, properties[key], false)
        end
    end

    if properties.tyreSmokeColor then
        local color = properties.tyreSmokeColor
        SetVehicleTyreSmokeColor(vehicle, color.r or 255, color.g or 255, color.b or 255)
    end

    if properties.neonColor then
        local color = properties.neonColor
        SetVehicleNeonLightsColour(vehicle, color.r or 255, color.g or 255, color.b or 255)
    end

    if properties.neonEnabled then
        for index = 1, 4 do
            SetVehicleNeonLightEnabled(vehicle, index - 1, properties.neonEnabled[index] == true)
        end
    end

    if properties.xenon ~= nil then
        ToggleVehicleMod(vehicle, 22, properties.xenon == true)
    end

    if properties.xenonColor then SetVehicleHeadlightsColour(vehicle, properties.xenonColor) end
    if properties.engineHealth then SetVehicleEngineHealth(vehicle, properties.engineHealth + 0.0) end
    if properties.bodyHealth then SetVehicleBodyHealth(vehicle, properties.bodyHealth + 0.0) end
    if properties.fuelLevel then SetVehicleFuelLevel(vehicle, properties.fuelLevel + 0.0) end
    if properties.dirtLevel then SetVehicleDirtLevel(vehicle, properties.dirtLevel + 0.0) end
    if properties.oilLevel then SetVehicleOilLevel(vehicle, properties.oilLevel + 0.0) end

    return true
end

