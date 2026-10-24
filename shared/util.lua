--[[
    sandbox-bridge-lib / shared/util.lua
    Small shared helpers used by both the server and client portions.
]]

SandboxBridgeUtil = SandboxBridgeUtil or {}

local Util = SandboxBridgeUtil

---Resource names this resource advertises through the manifest `provide` entries.
Util.ProvidedResources = { 'qb-core', 'qbx_core', 'es_extended' }

---Register an export and, on FXServer builds without native provide/export
---support, expose it through the provided resource names as well.
---@param name string
---@param fn function
function Util.AddExport(name, fn)
    exports(name, fn)

    if Citizen and Citizen.Traits and Citizen.Traits.ProvidesExports then
        return
    end

    for i = 1, #Util.ProvidedResources do
        local resource = Util.ProvidedResources[i]
        AddEventHandler(('__cfx_export_%s_%s'):format(resource, name), function(setCB)
            setCB(fn)
        end)
    end
end

function Util.Debug(...)
    if SandboxBridgeConfig and SandboxBridgeConfig.Debug then
        print(('[sandbox-bridge]'):format(), ...)
    end
end

function Util.IsStarted(resource)
    return GetResourceState(resource) == 'started'
end

function Util.Clamp(value, min, max)
    value = tonumber(value) or 0
    if value < min then return min end
    if value > max then return max end
    return value
end

function Util.TableContains(tbl, value)
    if type(tbl) ~= 'table' then return false end
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

function Util.SafeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        if SandboxBridgeConfig and SandboxBridgeConfig.Debug then
            print(('[sandbox-bridge] protected call failed: %s'):format(tostring(result)))
        end
        return nil
    end
    return result
end

---Normalize the many money type names used across frameworks.
---@param account string|nil
---@return string
function Util.NormalizeAccount(account)
    account = tostring(account or 'cash'):lower()
    if account == 'money' or account == 'cash' then return 'cash' end
    if account == 'bank' or account == 'bank_account' then return 'bank' end
    if account == 'crypto' or account == 'cryptocurrency' then return 'crypto' end
    return account
end

---Return a fiveM style item image url.
---@param name string
---@param data table|nil
---@return string
function Util.ItemImage(name, data)
    local image
    if data and data.client and type(data.client) == 'table' then
        image = data.client.image
    end
    if not image then image = name .. '.png' end
    if image:sub(1, 4) == 'nui:' then return image end
    return ('nui://ox_inventory/web/images/%s'):format(image)
end

---Convert a QBCore notification type to a Sandbox HUD type.
---@param notifType string|nil
---@return string
function Util.NotifyType(notifType)
    local t = tostring(notifType or 'info'):lower()
    if t == 'success' then return 'success' end
    if t == 'error' or t == 'danger' then return 'error' end
    if t == 'warning' or t == 'warn' then return 'warning' end
    return 'info'
end

---Format a job grade label from a Sandbox job assignment.
---@param assignment table|nil
---@return string
function Util.GradeLabel(assignment)
    if type(assignment) ~= 'table' then return 'Freelancer' end
    local grade = assignment.Grade
    if type(grade) == 'table' then
        return grade.Name or grade.Id or 'Freelancer'
    end
    return 'Freelancer'
end
