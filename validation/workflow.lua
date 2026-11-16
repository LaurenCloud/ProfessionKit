local harness, addon = Harness, ProfessionatorAddon
local UI = addon.UI
local function Check(...) harness.Check(...) end
local function Select(recipeID)
    addon.state.selected = recipeID
    UI.RefreshList()
end

harness.Event("ADDON_LOADED", "Professionator")
Check("Original-window replacement is enabled by default", ProfessionatorDB.replaceNative == true)
addon.Open(197)
Check("Loading window cannot craft", not UI.create.enabled)
harness.Advance(1)
Check("Opens Tailoring after delayed data", UI.frame:IsShown() and addon.state.professionID == 197 and #addon.state.recipes == 13)
Check("Custom window preserves live trade-skill session", harness.ready and harness.closeCount == 0 and not ProfessionsFrame:IsShown())
Check("Five professions survive nil GetProfessions slots", #addon.Client.Professions() == 5)
Check("Skill-ups considers craftable batch size", UI.rows[1].name == "Heavy Linen Gloves" and UI.rows[1].skillEstimate == 12)
Check("Gray recipes have no skill-up score", addon.Client.Recipe(2963).skillEstimate == 0)
harness.Snapshot("tailoring-skill-ups")
Check("Recipe list fits the screen without scaling the text down", UI.frame.scale == 1 and UI.frame:GetHeight() <= UIParent:GetHeight() - 60)

UI.priceSort:Click()
Check("Prices considers batch rather than highest unit price", UI.rows[1].name == "Heavy Linen Gloves" and UI.rows[1].batchPrice == 4200)
Check("Unknown price stays unknown and sorts last", UI.rows[#UI.rows].name == "Blue Linen Shirt" and UI.rows[#UI.rows].batchPrice == nil)
harness.Snapshot("tailoring-prices")
UI.search:SetText("bag")
Check("Search filters by name and category", #UI.rows == 1 and UI.rows[1].name == "Linen Bag")
UI.search:SetText("not a recipe")
Check("No-match search clears selection and disables crafting", #UI.rows == 0 and not UI.create.enabled and not UI.createAll.enabled)
UI.search:SetText("")
UI.list:Run("OnMouseWheel", -3)
Check("Long recipe list scrolls", UI.offset == 13 - UI.visibleRecipeCount and UI.recipeButtons[1].recipe == UI.rows[UI.offset + 1])
UI.list:Run("OnMouseWheel", 3)

Select(3755)
harness.Event("MERCHANT_SHOW"); harness.Advance(0.2)
Check("Observed vendor buying price is distinct from sale value", addon.Client.Item(2320).vendorBuy == 10 and addon.Client.Item(2320).vendorSell == 2)
UI.quantity:SetText("1.5")
Check("Fractional craft quantity rejected", not UI.create.enabled)
UI.quantity:SetText("5")
Check("Excess craft quantity rejected", not UI.create.enabled)
UI.quantity:SetText("2")
UI.create:Click()
Check("Create issues one explicit recipe-and-count call", #harness.crafts == 1 and harness.crafts[1].id == 3755 and harness.crafts[1].count == 2)
UI.createAll:Click()
Check("Crafting prevents overlapping batch clicks", #harness.crafts == 1 and not UI.create.enabled and not UI.createAll.enabled)
harness.casting = false
harness.Event("UPDATE_TRADESKILL_CAST_STOPPED"); harness.Advance(0.2)
Check("End of batch re-enables controls", UI.create.enabled and not addon.state.crafting)

local originalThreadCount = harness.inventory[2320]
harness.inventory[2320] = 0
-- Deliberately click before the bag-update event: the click must re-read inventory.
UI.create:Click()
Check("Stale displayed inventory cannot trigger a craft", #harness.crafts == 1 and not UI.create.enabled)
UI.multiplyByQuantity:Click()
Check("Quantity weighting never hides recipes without thread", #UI.rows == 13 and not addon.state.multiplyByQuantity)
harness.inventory[2320] = originalThreadCount
harness.Event("BAG_UPDATE_DELAYED"); harness.Advance(0.2)
UI.multiplyByQuantity:Click(); Select(3755)
harness.combat = true; harness.Event("PLAYER_REGEN_DISABLED"); harness.Advance(0.2)
Check("Combat disables craft controls", not UI.create.enabled and not UI.createAll.enabled)
harness.combat = false; harness.Event("PLAYER_REGEN_ENABLED"); harness.Advance(0.2)
harness.rejectCraft = true; UI.create:Click()
Check("Rejected client craft unlocks controls with reason", not addon.state.crafting and UI.craftStatus:GetText():find("rejected"))
harness.rejectCraft = false

harness.showNativeBeforeReady = true
UI.professionButtons[1]:Click()
Check("Profession switch immediately clears stale recipe and buttons", addon.state.professionID == 186 and #addon.state.recipes == 0 and not UI.create.enabled)
harness.Advance(0)
Check("Native window stays hidden before profession data is ready", not ProfessionsFrame:IsShown() and not harness.ready and harness.visibleNativeShows == 0)
harness.Advance(1)
harness.showNativeBeforeReady = false
Check("Mining contains only mining recipes", #addon.state.recipes == 3 and addon.state.recipes[1].id == 2657)
Select(2657)
Check("Skill estimate cannot exceed gray threshold", UI.selectedRecipe.skillEstimate == 5)
harness.recipes[2657].requirements[1].met = false
for _, frame in ipairs(harness.frames) do if frame.scripts.OnUpdate then frame:Run("OnUpdate", 1.1) end end
Check("Walking away from forge disables crafting", not UI.create.enabled)
Check("Missing forge replaces crafting controls once", not UI.create:IsShown() and not UI.createAll:IsShown() and UI.requirements:IsShown() and UI.requirements:GetText() == "Requires: Forge" and UI.craftStatus:GetText() == "")
harness.Snapshot("mining-away-from-forge")
harness.recipes[2657].requirements[1].met = true
harness.inventory[3576] = 4
harness.Event("BAG_UPDATE_DELAYED"); harness.Advance(0.2)
Select(2659)
Check("Returning to forge restores crafting controls", UI.create:IsShown() and UI.createAll:IsShown() and not UI.requirements:IsShown())
Check("Prices includes multiple outputs per craft", UI.selectedRecipe.available == 4 and UI.selectedRecipe.auctionTotal == 230 and UI.selectedRecipe.batchPrice == 920)
UI.quantity:SetText("1"); UI.createAll:Click()
Check("Create all uses freshly available count", #harness.crafts == 2 and harness.crafts[2].count == 4)
harness.casting = false; harness.Event("UPDATE_TRADESKILL_CAST_STOPPED"); harness.Advance(0.2)
Select(2657)
Check("Original window does not paint during profession switches", harness.visibleNativeShows == 0)
Check("Single material compacts viewport and hides scrollbar", UI.materialScroll:GetHeight() == UI.materialRows[1]:GetHeight() and not UI.materialScroll.ScrollBar:IsShown())
harness.Check("Single-line skillup rows use native difficulty art", UI.recipeButtons[1].skillIcon.atlas ~= nil)
harness.Snapshot("mining")

-- A recipe with more than four materials keeps the flow compact and enables its scrollbar.
local originalSlots = harness.recipes[2657].schematic.reagentSlotSchematics
harness.recipes[2657].schematic.reagentSlotSchematics = {}
for index = 1, 6 do
    harness.recipes[2657].schematic.reagentSlotSchematics[index] = {required = true, reagentType = 1, quantityRequired = 1, reagents = {{itemID = 2770}}}
end
addon.Refresh()
Check("Many-material recipe scrolls within compact detail section", UI.materialScroll:GetHeight() == 220 and UI.materialContent:GetHeight() == 336 and UI.materialScroll.ScrollBar:IsShown())
harness.recipes[2657].schematic.reagentSlotSchematics = originalSlots
addon.Refresh()

addon.Native()
Check("Original window fallback preserves active profession", not UI.frame:IsShown() and ProfessionsFrame:IsShown() and harness.ready and harness.closeCount == 0)
Check("Original window fallback restores its opacity", ProfessionsFrame:GetAlpha() == 1 and harness.visibleNativeShows == 1)
addon.Open(197); harness.Advance(1)
UI.frame:Hide(); harness.Advance(1)
Check("Closing custom window closes session once without reopening", not UI.frame:IsShown() and not harness.ready and harness.closeCount == 1)
addon.Open(197)
UI.frame:Hide(); harness.Advance(4)
Check("Closing during delayed load cancels pending adoption", not UI.frame:IsShown())

addon.Open(197); harness.Advance(1)
harness.items[4238].uncached = true; Select(3755); addon.Refresh()
Check("Uncached item requests data and leaves prices unknown", harness.lastItemRequested == 4238 and UI.selectedRecipe.auction == nil)
harness.items[4238].uncached = false; harness.Event("ITEM_DATA_LOAD_RESULT", 4238); harness.Advance(0.2)
Check("Item-data arrival fills missing prices", UI.selectedRecipe.auction == 600)
local auctionator = Auctionator
Auctionator = nil; addon.Refresh()
Check("Addon functions without Auctionator", #UI.rows == 13 and UI.selectedRecipe.auction == nil and UI.create.enabled)
Auctionator = auctionator
harness.items[4238].bound = true; addon.Refresh()
Check("Soulbound output has no auction value", UI.selectedRecipe.auction == nil and UI.outputRow.auction:GetText() == "Soulbound")
harness.items[4238].bound = false
harness.recipes[3755].schematic.reagentSlotSchematics[1].reagents[2] = {itemID = 2997}
addon.Refresh()
Check("Unsupported choice-of-reagent recipe routes to original window", UI.selectedRecipe.unsupported and not UI.create.enabled)
harness.recipes[3755].schematic.reagentSlotSchematics[1].reagents[2] = nil
addon.Refresh()
SlashCmdList.PROFESSIONATOR("report")
Check("Diagnostic stores inspectable recipe and session data", ProfessionatorDB.diagnostic.recipeCount == 13 and ProfessionatorDB.diagnostic.liveProfessionID == 197)
harness.Event("PLAYER_LOGOUT")
Check("Sort preference persists", ProfessionatorDB.sort == "auction")

-- Exercise a short Mining list and two-profession layout.
GetProfessions = function() return 1, nil, nil, nil, 3 end
harness.professions[1].rank, harness.professions[1].maximum = 41, 75
harness.inventory[2770] = 6
harness.recipes[2657].info.relativeDifficulty = 1
harness.recipes[2659], harness.recipes[3304] = nil, nil
harness.Item(279960, "Lodestone", 0, 0, nil)
harness.Item(2835, "Rough Stone", 2, 0, 3)
harness.Recipe(1230161, 186, "Lodestone", 279960, 3, 1, 1, {{2835, 1}, {2840, 1}}, 2717)
harness.inventory[2771] = 0
addon.state.sort = "skill"
addon.Open(186); harness.Advance(1)
local recipeButton, materialRow = UI.recipeButtons[1], UI.materialRows[1]
local _, _, _, iconInset = recipeButton.icon:GetPoint()
local _, _, _, materialInset = materialRow.icon:GetPoint()
Check("Recipe tiles use narrower sides and more vertical room; material padding stays balanced", iconInset == 8 and recipeButton:GetHeight() == 58 and materialInset == (materialRow:GetHeight() - materialRow.icon:GetHeight()) / 2)
Check("Short Mining list puts the skillup estimate below its name and quantity", recipeButton.count:GetText() == "[6]" and recipeButton.name:GetText() == "Smelt Copper" and recipeButton.summary:GetText():find("est. 3 skillups", 1, true))
harness.inventory[2770] = 9
addon.Refresh()
Check("Displayed skillups round down while ranking preserves fractions", recipeButton.count:GetText() == "[9]" and recipeButton.summary:GetText():find("est. 4 skillups", 1, true) and UI.rows[1].skillEstimate == 4.5)
harness.inventory[2770] = 6
addon.Refresh()
harness.Snapshot("mining-short-list")

-- Live-state summaries for the inspectable report.
harness.result = {checks = harness.checks, crafts = harness.crafts, diagnostic = ProfessionatorDB.diagnostic,
    scope = "Complete addon executed under Lua 5.1 with simulated game frames, events, recipes, inventory and auction data. No game files or character inventory modified."}
