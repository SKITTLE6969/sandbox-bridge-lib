-- sandbox-bridge-lib/client/groups.lua
-- Client group filters and vehicle catalog helpers.

-- sandbox-bridge-lib/client/groups.lua
-- Loaded by client/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- QBX group helpers
-- ---------------------------------------------------------------------------

function GetClientGroups()
    local data = GetPlayerData()
    local groups = {}
    if not data then return groups end

    if data.job and data.job.name then
        groups[data.job.name] = data.job.grade and data.job.grade.level or 0
    end
    if data.gang and data.gang.name and data.gang.name ~= 'none' then
        groups[data.gang.name] = data.gang.grade and data.gang.grade.level or 0
    end

    return groups
end

function ClientMatchesGroupFilter(filter, groups, citizenid)
    if type(filter) == 'string' then
        return groups[filter] ~= nil or citizenid == filter
    end
    if type(filter) ~= 'table' then return false end

    if filter[1] ~= nil then
        for _, name in ipairs(filter) do
            if groups[name] ~= nil or citizenid == name then return true end
        end
        return false
    end

    for group, level in pairs(filter) do
        if groups[group] ~= nil then
            if level == nil or groups[group] >= (tonumber(level) or 0) then return true end
        elseif citizenid == group then
            return true
        end
    end

    return false
end

function GetClientPrimaryGroups()
    return GetClientGroups()
end

function GetClientCitizenId()
    local data = GetPlayerData()
    return data and data.citizenid or nil
end

function QBoxNotify(text, notifyType, duration, subTitle, notifyPosition, notifyStyle, notifyIcon, notifyIconColor)
    local message = type(text) == 'table' and (text.text or text.caption) or text
    local description = type(text) == 'table' and text.caption or subTitle

    if Started('ox_lib') then
        SafeCall(function()
            exports.ox_lib:notify({
                title = message,
                description = description,
                type = notifyType or 'inform',
                duration = duration or Config.NotifyDuration or 5000,
                position = notifyPosition,
                style = notifyStyle,
                icon = notifyIcon,
                iconColor = notifyIconColor,
            })
        end)
        return
    end

    ShowNotification(message or '', notifyType, duration)
end

function GetClientVehicleCatalog()
    local catalog = _G.QBXVehicles
    if type(catalog) ~= 'table' then return {} end
    return catalog
end

function GetClientVehicleHashes()
    if clientVehicleHashes then return clientVehicleHashes end
    clientVehicleHashes = {}
    for _, vehicle in pairs(GetClientVehicleCatalog()) do
        local hash = vehicle.hash
        if type(hash) ~= 'number' then
            hash = SafeCall(function() return joaat(tostring(hash)) end) or 0
        end
        clientVehicleHashes[hash] = vehicle
    end
    return clientVehicleHashes
end

function GetClientVehicleCategories()
    if clientVehicleCategories then return clientVehicleCategories end
    clientVehicleCategories = {}
    for _, vehicle in pairs(GetClientVehicleCatalog()) do
        local category = vehicle.category or 'unknown'
        local list = clientVehicleCategories[category]
        if not list then
            list = {}
            clientVehicleCategories[category] = list
        end
        list[#list + 1] = vehicle
    end
    return clientVehicleCategories
end
