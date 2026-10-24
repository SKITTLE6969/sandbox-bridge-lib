-- sandbox-bridge-lib/server/inventory.lua
-- Loaded by server/main.lua in the shared bridge environment.

-- ---------------------------------------------------------------------------
-- Inventory / items
-- ---------------------------------------------------------------------------

function NormalizeItem(item, amount)
    local metadata = item.metadata or item.info or {}
    local count = item.count or item.amount or amount or 0
    return {
        name = item.name or item.Name,
        label = item.label or item.name or item.Name,
        count = count,
        amount = count,
        slot = item.slot or item.Slot,
        metadata = metadata,
        info = metadata,
        weight = item.weight or 0,
        stack = item.stack ~= false,
        unique = item.stack == false,
        description = item.description or '',
        useable = true,
        shouldClose = true,
    }
end

function SB.GetInventory(src)
    if not src or not Started('ox_inventory') then return {} end
    local items = SafeCall(function()
        return exports.ox_inventory:GetInventoryItems(src)
    end)
    if type(items) ~= 'table' then return {} end

    local result = {}
    for _, item in pairs(items) do
        if type(item) == 'table' and item.name then
            result[#result + 1] = NormalizeItem(item)
        end
    end
    return result
end

function SB.GetItemCount(src, item, metadata)
    if not src or not item or not Started('ox_inventory') then return 0 end
    local count = SafeCall(function()
        return exports.ox_inventory:GetItemCount(src, item, metadata)
    end)
    return tonumber(count) or 0
end

function SB.HasItem(src, item, amount)
    return SB.GetItemCount(src, item) >= (tonumber(amount) or 1)
end

function SB.AddItem(src, item, amount, slot, metadata)
    if not src or not item or not Started('ox_inventory') then return false end
    amount = math.max(1, tonumber(amount) or 1)
    local ok = SafeCall(function()
        return exports.ox_inventory:AddItem(src, item, amount, metadata or {}, slot)
    end)
    return ok == true
end

function SB.RemoveItem(src, item, amount, slot, metadata)
    if not src or not item or not Started('ox_inventory') then return false end
    amount = math.max(1, tonumber(amount) or 1)
    local ok = SafeCall(function()
        return exports.ox_inventory:RemoveItem(src, item, amount, metadata or {}, slot)
    end)
    return ok == true
end

function SB.GetItemInfo(item)
    if not item then return {} end
    local data = SafeCall(function()
        return exports.ox_inventory:Items(item)
    end)
    if type(data) ~= 'table' then return {} end

    return {
        name = data.name or item,
        label = data.label or item,
        weight = data.weight or 0,
        stack = data.stack ~= false,
        description = data.description or '',
        image = Util.ItemImage(data.name or item, data),
        unique = data.stack == false,
        useable = true,
        shouldClose = true,
    }
end

function SB.GetItem(src, item, metadata)
    local result = {}
    for _, invItem in ipairs(SB.GetInventory(src)) do
        if invItem.name == item then
            if not metadata or invItem.metadata == metadata then
                result[#result + 1] = invItem
            end
        end
    end
    return result
end

function SB.GetItemBySlot(src, slot)
    for _, item in ipairs(SB.GetInventory(src)) do
        if item.slot == slot then return item end
    end
    return nil
end

