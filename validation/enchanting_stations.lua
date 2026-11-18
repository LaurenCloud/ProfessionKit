-- Full-addon scenarios: actual frame callbacks, native-shaped inventory locations,
-- enchant eligibility, confirmations, recipe cooldowns and moving between stations.
local harness, addon = Harness, ProfessionatorAddon
local UI = addon.UI
Enum.TradeskillRecipeType = {Item = 1, Salvage = 2, Enchant = 3, Gathering = 4}
Enum.RecipeRequirementType = {SpellFocus = 0, Totem = 1, Area = 2}
Enum.Profession = {Mining = 2, Blacksmithing = 3, Cooking = 4, Engineering = 5}
local instances, eligible = {}, {}
local function Location(bagID, slotIndex, equipmentSlot)
    local location = {bagID = bagID, slotIndex = slotIndex, equipmentSlot = equipmentSlot}
    function location:IsBagAndSlot() return self.bagID ~= nil end
    function location:IsEquipmentSlot() return self.equipmentSlot ~= nil end
    function location:GetBagAndSlot() return self.bagID, self.slotIndex end
    function location:GetEquipmentSlot() return self.equipmentSlot end
    function location:IsValid() return self.present ~= false end
    return location
end
local function Instance(guid, itemID, location)
    instances[guid] = {guid = guid, id = itemID, location = location}
    location.guid = guid
end
C_Item.GetItemLocation = function(guid) return instances[guid] and instances[guid].location end
C_Item.GetItemGUID = function(location) return location.guid end
C_Item.GetItemID = function(location) return instances[location.guid].id end
C_Item.GetItemLink = function(location) return "item:" .. instances[location.guid].id .. ":15" end
C_Item.IsLocked = function(location) return location.locked == true end
C_Cursor = {GetCursorItem = function() return harness.cursor end}
function ClearCursor() harness.cursor = nil end
function OpenAllBags() harness.bagsOpen = true end
function StaticPopup_Visible(name) return harness.confirmEnchant and name == "REPLACE_TRADESKILL_ENCHANT" and 1 or nil end
C_TradeSkillUI.GetEnchantItems = function(id) return eligible[id] or {} end
C_TradeSkillUI.CraftEnchant = function(id, count, reagents, location)
    harness.lastEnchant = {id = id, count = count, location = location, guid = location.guid}
    if harness.askConfirmation then harness.confirmEnchant = true; return end
    harness.casting = true
    harness.Event("UNIT_SPELLCAST_START", "player", "enchant-cast", id)
end
local spellCooldowns, spellCharges = {}, {}
C_Spell.GetSpellCooldown = function(id) return spellCooldowns[id] end
C_Spell.GetSpellCharges = function(id) return spellCharges[id] end
C_Spell.GetSpellDescription = function() return "Permanently increases the stamina of a pair of bracers by 3." end
C_TradeSkillUI.GetRecipeCooldown = function(id)
    local recipe = harness.recipes[id]
    return recipe.cooldown, false, recipe.charges, recipe.maximumCharges
end
C_TradeSkillUI.IsNearProfessionSpellFocus = function(profession) return harness.nearStation == profession end
local function Select(id)
    addon.state.selected = id
    UI.RefreshList()
end
local function Finish()
    harness.casting, harness.confirmEnchant = false, false
    harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "enchant-cast", 7457)
    harness.Advance(0.2)
end

harness.professions[2] = {name = "Enchanting", id = 333, rank = 50, maximum = 150}
harness.Item(10940, "Strange Dust", 0, 20, 180)
harness.Item(11101, "Linen Bracers", 50, 1)
harness.Item(11102, "Worn Leather Bracers", 50, 1)
harness.Recipe(7457, 333, "Enchant Bracer - Minor Stamina", nil, 1, 90, 1, {{10940, 2}})
harness.recipes[7457].schematic.recipeType = 3
harness.recipes[7457].info.canCreateMultiple = true -- Enchanting gear must still be single cast.
Instance("bag-bracers", 11101, Location(1, 4))
Instance("worn-bracers", 11102, Location(nil, nil, 9))
Instance("same-item-another-stack", 11101, Location(2, 6))
Instance("bank-bracers", 11101, Location(7, 3))
eligible[7457] = {"bag-bracers", "worn-bracers", "same-item-another-stack", "bank-bracers"}
harness.Event("ADDON_LOADED", "Professionator")
addon.Open(333); harness.Advance(1)
harness.Check("Enchant recipe without an output item is supported", UI.selectedRecipe.isEnchant and not UI.selectedRecipe.unsupported)
harness.Check("Enchant details replace sale output with target and real spell effect", UI.targetPanel:IsShown() and not UI.outputRow:IsShown()
    and not UI.vendorHeading:IsShown() and UI.enchantEffect:GetText():find("stamina"))
harness.Check("Enchant requires an item and hides every batching control", not UI.create.enabled and not UI.createAll:IsShown()
    and not UI.quantity.background:IsShown() and UI.create.label:GetText() == "Enchant")
UI.targetSlot:Click()
harness.Check("Clicking empty item slot opens bags without crafting", harness.bagsOpen and not harness.lastEnchant)
harness.Snapshot("enchanting-choose-item")
harness.cursor = instances["bag-bracers"].location
UI.targetSlot:Run("OnReceiveDrag")
harness.Check("Dropping eligible item selects its identity and returns cursor", addon.Targets.selectedGUID == "bag-bracers" and harness.cursor == nil and UI.create.enabled)
harness.Check("Target selection does not consume inventory", harness.inventory[10940] == 20 and harness.inventory[11101] == 1)
Instance("invalid-boots", 11101, Location(0, 3))
harness.cursor = instances["invalid-boots"].location
UI.targetSlot:Run("OnReceiveDrag")
harness.Check("Invalid drop stays on cursor and explains rejection", harness.cursor ~= nil and not UI.create.enabled and UI.recipeStatus:GetText():find("cannot receive"))
ClearCursor()
UI.targetSlot:Click("RightButton")
harness.Check("Right-click clears enchant target", addon.Targets.selectedGUID == nil and not UI.create.enabled)
UI.equipped:Click()
harness.Check("Equipped picker excludes bag and bank items", UI.equippedPicker:IsShown() and UI.equippedPicker.buttons[1].item.guid == "worn-bracers" and #UI.equippedPicker.buttons == 1)
harness.Snapshot("enchanting-equipped-picker")
UI.equippedPicker.buttons[1]:Click()
harness.Check("Equipped selection does not unequip the item", addon.Targets.selectedGUID == "worn-bracers" and instances["worn-bracers"].location:IsEquipmentSlot() and not UI.equippedPicker:IsShown())
UI.quantity:SetText("7")
UI.create:Click()
harness.Check("Enchant dispatches exactly one native targeted cast", harness.lastEnchant.id == 7457 and harness.lastEnchant.count == 1 and harness.lastEnchant.guid == "worn-bracers")
harness.Check("Enchant records diagnostic call and confirms progress from cast event", addon.state.craftRequest.started and UI.craftProgress:IsShown())
Finish()
harness.Check("Finished enchant retains the target for repeat casting", addon.Targets.selectedGUID == "worn-bracers" and UI.create.enabled)
harness.Snapshot("enchanting-equipped-selected")
addon.Targets.Select(UI.selectedRecipe, "bag-bracers")
Instance("bag-bracers", 11101, Location(3, 2))
UI.create:Click()
harness.Check("Moved target resolves current slot without substituting an identical item", harness.lastEnchant.guid == "bag-bracers" and harness.lastEnchant.location.bagID == 3)
Finish()
instances["bag-bracers"].location.present = false
harness.lastEnchant = nil
UI.create:Click()
harness.Check("Removed target cannot cast using its old bag slot", harness.lastEnchant == nil and not UI.create.enabled)
addon.Targets.Select(UI.selectedRecipe, "worn-bracers")
UI.Detail(UI.selectedRecipe)
instances["worn-bracers"].location.locked = true
UI.create:Click()
harness.Check("Locked target is rejected on the actual craft click", harness.lastEnchant == nil and UI.recipeStatus:GetText():find("busy"))
instances["worn-bracers"].location.locked = false
addon.state.craftFailure = nil; UI.Detail(UI.selectedRecipe)
harness.askConfirmation = true
UI.create:Click()
harness.Advance(12)
harness.Check("Overwrite dialog keeps request pending without fake progress", addon.state.craftRequest and not addon.state.craftRequest.started and not UI.craftProgress:IsShown()
    and UI.craftStatus:GetText():find("Confirm"))
harness.confirmEnchant = false
harness.casting = true
harness.Event("UNIT_SPELLCAST_START", "player", "enchant-cast", 7457)
harness.Check("Accepting native overwrite starts the real progress bar", UI.craftProgress:IsShown())
Finish()
UI.create:Click(); harness.Advance(3.1)
harness.confirmEnchant = false; harness.Advance(6)
harness.Check("Canceling native overwrite releases controls and names cancellation", not addon.state.crafting and UI.recipeStatus:GetText() == "Enchant canceled.")
harness.askConfirmation = false
eligible[7457] = {"same-item-another-stack"}
UI.Detail(UI.selectedRecipe); UI.equipped:Click()
harness.Check("No eligible equipped gear has an explicit empty state", UI.equippedPicker.empty:IsShown() and not UI.equippedPicker.scroll:IsShown())
UI.equippedPicker:Hide()

addon.Open(186); harness.Advance(1); Select(2657)
local copper = harness.recipes[2657]
copper.info.canCreateMultiple = false
addon.Refresh()
harness.Check("Native single-craft recipes hide quantity and Create all", not UI.createAll:IsShown() and not UI.minus:IsShown() and not UI.quantity.background:IsShown())
local before = #harness.crafts
addon.Craft(true)
harness.Check("Hidden Create all cannot enqueue a single-craft recipe", #harness.crafts == before)
addon.state.craftFailure = nil; UI.RefreshCraftButtons(); UI.create:Click()
harness.Check("Single craft ignores stale quantity from previous recipe", harness.crafts[#harness.crafts].count == 1)
harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "single-copper", 2657)
harness.casting = false; harness.Event("UPDATE_TRADESKILL_CAST_STOPPED"); harness.Advance(.2)
copper.info.canCreateMultiple = true
copper.cooldown = 180; addon.Refresh()
harness.Check("Native recipe cooldown blocks craft with duration", not UI.create.enabled and UI.recipeStatus:GetText():find("3m"))
harness.Snapshot("recipe-cooldown")
copper.charges, copper.maximumCharges = 2, 3
addon.Refresh(); UI.createAll:Click()
harness.Check("Recharging recipe allows only its remaining charges", harness.crafts[#harness.crafts].count == 2)
for index = 1, 2 do harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "charged-copper-" .. index, 2657) end
harness.casting = false; harness.Event("UPDATE_TRADESKILL_CAST_STOPPED"); harness.Advance(.2)
copper.charges = 0; addon.Refresh()
harness.Check("Exhausted recipe charges block crafting while recharging", not UI.create.enabled and not UI.createAll.enabled)
copper.charges, copper.maximumCharges, copper.cooldown = nil, nil, nil
local nativeCooldown = C_TradeSkillUI.GetRecipeCooldown
C_TradeSkillUI.GetRecipeCooldown = nil
spellCooldowns[2657] = {startTime = harness.now, duration = 60}
UI.quantity:SetText("1"); addon.Refresh()
harness.Check("Spell cooldown fallback works without legacy recipe API", not UI.create.enabled and UI.recipeStatus:GetText():find("1m"))
harness.Advance(61); addon.Refresh()
harness.Check("Expired cooldown re-enables the craft", UI.create.enabled)
spellCooldowns[2657] = {startTime = harness.now, duration = 1.5}
spellCooldowns[61304] = {startTime = harness.now, duration = 1.5}
addon.Refresh()
harness.Check("GCD alone is not mistaken for a recipe cooldown", UI.create.enabled)
spellCooldowns[2657], spellCooldowns[61304] = nil, nil
spellCharges[2657] = {currentCharges = 1, maxCharges = 3, cooldownStartTime = harness.now, cooldownDuration = 30}
addon.Refresh(); UI.createAll:Click()
harness.Check("Spell charge fallback caps Create all", harness.crafts[#harness.crafts].count == 1)
harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "charged-copper", 2657)
harness.casting = false; harness.Event("UPDATE_TRADESKILL_CAST_STOPPED"); harness.Advance(.2)
spellCharges[2657] = nil
C_TradeSkillUI.GetRecipeCooldown = nativeCooldown
copper.info.disabled, copper.info.disabledReason = true, "Requires a specialization."
addon.Refresh()
harness.Check("Client-disabled recipe preserves its explanation", not UI.create.enabled and UI.recipeStatus:GetText() == "Requires a specialization.")
copper.info.disabled, copper.info.disabledReason = false, nil
copper.info.craftable = false; addon.Refresh()
harness.Check("Uncraftable client recipe cannot dispatch despite sufficient materials", not UI.create.enabled)
copper.info.craftable = true
copper.info.isGatheringRecipe = true; addon.Refresh()
harness.Check("Gathering entry never exposes fake Create controls", not UI.create:IsShown() and not UI.createAll:IsShown())
copper.info.isGatheringRecipe = false

for _, recipe in pairs(harness.recipes) do
    for _, requirement in ipairs(recipe.requirements) do requirement.type = 0; requirement.met = false end
end
copper.requirements[1].met = true
addon.Refresh()
local mining = UI.professionButtons[1].station
harness.Check("Known nearby forge lights Mining badge", mining:IsShown() and not mining.icon.desaturated)
copper.requirements[1].met = false
UI.RefreshStations()
harness.Check("Walking away dims station badge without switching professions", mining.icon.desaturated)
harness.nearStation = Enum.Profession.Cooking
UI.RefreshStations()
harness.Check("Unopened Cooking can show native station proximity", UI.professionButtons[3].station:IsShown() and not UI.professionButtons[3].station.icon.desaturated)
harness.Check("Profession without station requirement has no badge", not UI.professionButtons[2].station:IsShown())
copper.requirements[1].met = true
harness.recipes[3304].requirements = {{name = "Black Forge", type = 0, met = false}, {name = "Blacksmith Hammer", type = 1, met = false}}
addon.Refresh()
local status = addon.Stations.Read({id = 186, icon = 136249})
harness.Check("Station tooltip distinguishes special stations and excludes carried tools", status.tooltip:find("Forge: nearby") and status.tooltip:find("Black Forge: not nearby") and not status.tooltip:find("Blacksmith Hammer"))
local readRequirements = C_TradeSkillUI.GetRecipeRequirements
C_TradeSkillUI.GetRecipeRequirements = function() return nil end
UI.RefreshStations()
harness.Check("Unavailable station data never retains a stale green badge", mining.icon.desaturated)
C_TradeSkillUI.GetRecipeRequirements = readRequirements
UI.RefreshStations()
harness.Snapshot("profession-station-badges")
