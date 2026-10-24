-- sandbox-bridge-lib/server/vehicles.lua
-- Loaded by server/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Vehicle / bucket utilities (QBX server exports)
-- ---------------------------------------------------------------------------

function SB.DeleteVehicle(entity)
    if not entity or not DoesEntityExist(entity) then return false end
    SB.DisablePersistence(entity)
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
    return true
end

function SB.EnablePersistence(entity)
    if not entity or not DoesEntityExist(entity) then return false end
    local ok = pcall(function()
        Entity(entity).state:set('persistent', true, true)
    end)
    return ok
end

function SB.DisablePersistence(entity)
    if not entity or not DoesEntityExist(entity) then return false end
    local ok = pcall(function()
        Entity(entity).state:set('persistent', false, true)
    end)
    return ok
end

function SB.GetVehicleClass(hash)
    if not vehicleClasses then
        local players = GetPlayers()
        if #players == 0 then return 0 end

        local playerId = tonumber(players[math.random(#players)])
        local ok, result = pcall(function()
            return lib.callback.await('sandbox_bridge:client:getVehicleClasses', playerId)
        end)

        if ok and type(result) == 'table' then
            vehicleClasses = result
        end
    end

    return vehicleClasses and tonumber(vehicleClasses[hash]) or 0
end

function SB.CreateSessionId(entity)
    if not entity or not DoesEntityExist(entity) then return nil end

    local existing = Entity(entity).state.sessionId
    if existing then return existing end

    local sessionId = math.random(100000, 999999)
    pcall(function()
        Entity(entity).state:set('sessionId', sessionId, true)
    end)
    return sessionId
end

function SB.SetPlayerBucket(source, bucket)
    if source == nil or bucket == nil then return false end
    SetPlayerRoutingBucket(source, bucket)
    playerBuckets[source] = bucket
    return true
end

function SB.SetEntityBucket(entity, bucket)
    if entity == nil or bucket == nil then return false end
    SetEntityRoutingBucket(entity, bucket)
    entityBuckets[entity] = bucket
    return true
end

function SB.GetBucketObjects()
    return playerBuckets, entityBuckets
end

function SB.GetPlayersInBucket(bucket)
    local players = {}
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        if GetPlayerRoutingBucket(src) == bucket then
            players[#players + 1] = src
        end
    end
    return players
end

function SB.GetEntitiesInBucket(bucket)
    local entities = {}
    for entity, entityBucket in pairs(entityBuckets) do
        if entityBucket == bucket then entities[#entities + 1] = entity end
    end
    return entities
end

function BuildSharedGroup(definition, name)
    local grades = {}

    if type(definition.Grades) == 'table' then
        for index, grade in ipairs(definition.Grades) do
            grades[index] = {
                name = grade.Id,
                label = grade.Name,
                level = tonumber(grade.Level) or index,
                payment = tonumber(definition.Salary) or 0,
                isBoss = grade.IsBoss == true or grade.isboss == true
                    or tostring(grade.Name):lower() == 'boss'
                    or tostring(grade.Name):lower() == 'leader'
                    or (tonumber(grade.Level) or 0) >= 99,
            }
        end
    end

    if type(definition.Workplaces) == 'table' then
        for _, workplace in ipairs(definition.Workplaces) do
            if type(workplace.Grades) == 'table' then
                for _, grade in ipairs(workplace.Grades) do
                    grades[#grades + 1] = {
                        name = grade.Id,
                        label = grade.Name,
                        level = tonumber(grade.Level) or #grades + 1,
                        payment = tonumber(definition.Salary) or 0,
                        workplace = workplace.Id,
                        isBoss = grade.IsBoss == true or grade.isboss == true
                            or tostring(grade.Name):lower() == 'boss'
                            or tostring(grade.Name):lower() == 'leader'
                            or (tonumber(grade.Level) or 0) >= 99,
                    }
                end
            end
        end
    end

    return {
        name = name,
        label = definition.Name or name,
        type = definition.Type or 'none',
        grades = grades,
    }
end

function SB.GetSharedJobs()
    local jobs = {}
    for name, definition in pairs(GetRuntimeJobs()) do
        jobs[name] = BuildSharedGroup(definition, name)
    end
    return jobs
end

function SB.GetSharedGangs()
    local gangs = {}
    for name, definition in pairs(GetGangDefinitions()) do
        gangs[name] = BuildSharedGroup(definition, name)
    end
    return gangs
end

function SB.GetSharedWeapons()
    local weapons = {}
    local items = SafeCall(function()
        return exports.ox_inventory:Items()
    end)
    if type(items) ~= 'table' then return weapons end

    for name, data in pairs(items) do
        if type(name) == 'string' and name:lower():sub(1, 7) == 'weapon_' then
            local hash = SafeCall(function() return joaat(name:upper()) end)
                or SafeCall(function() return GetHashKey(name:upper()) end)
                or 0
            weapons[hash] = {
                name = name,
                label = data.label or name,
                weight = data.weight or 0,
                hash = hash,
                description = data.description or '',
                image = Util.ItemImage(name, data),
            }
        end
    end
    return weapons
end

function SB.GetLocations()
    if not Started('sandbox-jobs') then return {} end
    local spawns = SafeCall(function()
        return exports['sandbox-jobs']:GetJobSpawns()
    end)
    if type(spawns) == 'table' then return spawns end
    return {}
end

function GetVehicleCatalog()
    local catalog = _G.QBXVehicles
    if type(catalog) ~= 'table' then return {} end
    return catalog
end

function GetVehicleHashMap()
    if vehicleHashCache then return vehicleHashCache end

    vehicleHashCache = {}
    for _, vehicle in pairs(GetVehicleCatalog()) do
        local hash = vehicle.hash
        if type(hash) ~= 'number' then
            hash = SafeCall(function() return joaat(tostring(hash)) end) or 0
        end
        vehicleHashCache[hash] = vehicle
    end
    return vehicleHashCache
end

function GetVehicleCategoryMap()
    if vehicleCategoryCache then return vehicleCategoryCache end

    vehicleCategoryCache = {}
    for _, vehicle in pairs(GetVehicleCatalog()) do
        local category = vehicle.category or 'unknown'
        local list = vehicleCategoryCache[category]
        if not list then
            list = {}
            vehicleCategoryCache[category] = list
        end
        list[#list + 1] = vehicle
    end
    return vehicleCategoryCache
end

function SB.GetVehiclesByName(vehicle)
    local catalog = GetVehicleCatalog()
    return vehicle and catalog[vehicle] or catalog
end

function SB.GetVehiclesByHash(vehicle)
    local hashes = GetVehicleHashMap()
    return vehicle and hashes[tonumber(vehicle) or vehicle] or hashes
end

function SB.GetVehiclesByCategory()
    return GetVehicleCategoryMap()
end

function GetJobMeta()
    local jobTypes = {}
    local gangJobs = {}
    for name, definition in pairs(GetRuntimeJobs()) do
        jobTypes[name] = definition.Type or 'none'
        if gangsOverlay[name] or (Config.GangJobs and Config.GangJobs[name]) or definition.Gang or definition.Type == 'Gang' then
            gangJobs[name] = true
        end
    end
    return jobTypes, gangJobs
end

