local _, addon = ...
addon.Targets = {}
local Targets = addon.Targets

local function CarriedLocation(location)
    if not location or not location:IsValid() then return false end
    if location:IsEquipmentSlot() then return true end
    if not location:IsBagAndSlot() then return false end
    local bagID = location:GetBagAndSlot()
    return bagID >= 0 and bagID <= (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5)
end

function Targets.Eligible(recipe, equipmentOnly)
    local items = {}
    if not recipe or not recipe.isEnchant or not C_TradeSkillUI.GetEnchantItems then return items end
    -- This is the native enchant picker's eligibility list, including the item's
    -- level restrictions. Never infer eligibility from a name or equipment type.
    for _, itemGUID in ipairs(C_TradeSkillUI.GetEnchantItems(recipe.id) or {}) do
        local location = C_Item.GetItemLocation(itemGUID)
        local itemID = CarriedLocation(location) and C_Item.GetItemID(location)
        if itemID and (not equipmentOnly or location:IsEquipmentSlot()) then
            local item = addon.Client.Item(itemID)
            item.guid, item.location, item.id = itemGUID, location, itemID
            item.equipmentSlot = location:IsEquipmentSlot() and location:GetEquipmentSlot() or nil
            item.link = C_Item.GetItemLink(location) or item.link
            items[#items + 1] = item
        end
    end
    table.sort(items, function(left, right)
        if equipmentOnly and left.equipmentSlot ~= right.equipmentSlot then return left.equipmentSlot < right.equipmentSlot end
        if left.name ~= right.name then return left.name < right.name end
        return left.guid < right.guid
    end)
    return items
end

function Targets.Selected(recipe)
    if not Targets.selectedGUID then return nil end
    for _, item in ipairs(Targets.Eligible(recipe)) do
        if item.guid == Targets.selectedGUID then return item end
    end
end

function Targets.Select(recipe, itemGUID)
    if InCombatLockdown() or addon.state.crafting then return false end
    for _, item in ipairs(Targets.Eligible(recipe)) do
        if item.guid == itemGUID then
            Targets.selectedGUID, Targets.message = itemGUID, nil
            addon.state.craftFailure = nil
            return true
        end
    end
    Targets.message = "That item cannot receive this enchant."
    return false
end

function Targets.Drop(recipe)
    if InCombatLockdown() or addon.state.crafting then return false end
    local location = C_Cursor and C_Cursor.GetCursorItem and C_Cursor.GetCursorItem()
    if not location then return false end
    local itemGUID = C_Item.GetItemGUID(location)
    local selected = itemGUID and Targets.Select(recipe, itemGUID)
    -- Return the cursor item to its original inventory slot. The target holds
    -- only its GUID; choosing a target never moves, equips or consumes the item.
    if selected then ClearCursor() end
    return selected
end

function Targets.Clear()
    if addon.state.crafting then return end
    Targets.selectedGUID, Targets.message = nil, nil
end

function Targets.Validate(recipe)
    if not recipe or not recipe.isEnchant then return true end
    if Targets.message then return false, Targets.message end
    local target = Targets.Selected(recipe)
    if not target then return false, "Choose an item to enchant." end
    if C_Item.IsLocked and C_Item.IsLocked(target.location) then return false, "That item is busy. Try again shortly." end
    return true, nil, target
end

function Targets.ConfirmationVisible()
    return StaticPopup_Visible and not not (StaticPopup_Visible("REPLACE_TRADESKILL_ENCHANT")
        or StaticPopup_Visible("REPLACE_ENCHANT") or StaticPopup_Visible("TRADE_REPLACE_ENCHANT"))
end
