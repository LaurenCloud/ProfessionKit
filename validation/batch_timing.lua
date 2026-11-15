local harness, addon = Harness, ProfessionatorAddon
local UI = addon.UI
UI.quantity:SetText("3")
addon.Refresh()
harness.Check("Create all preview uses live recipe cast time and inventory", UI.craftStatus:GetText() == "Create all: est. 18s total")
harness.Check("Recipe tiles use native item or recipe icons", UI.recipeButtons[1].icon.texture == UI.recipeButtons[1].recipe.icon)
harness.Check("Compact search is separate from sort and checkbox filter", UI.search.background:GetHeight() == 28 and UI.filter.kind == "CheckButton")
local _, _, _, _, ageTop = UI.market:GetPoint()
harness.Check("AH age sits in the header and cost/margin text is removed", ageTop == -14 and UI.cost == nil and UI.market:GetText() == "AH prices\n1 day old")

UI.create:Click()
harness.Check("Batch start displays total and remaining time", UI.craftStatus:GetText() == "Crafting 1/3 · est. 9s left / 9s total")
harness.Advance(1)
UI.RefreshCraftButtons()
harness.Check("Countdown subtracts elapsed time from the active cast", UI.craftStatus:GetText() == "Crafting 1/3 · est. 8s left / 9s total")
harness.Snapshot("mining-batch-timer")
harness.castEnd = harness.castEnd + 1
harness.Event("UNIT_SPELLCAST_DELAYED", "player", "delayed-cast", 2657)
harness.Check("Cast delay updates the remaining-time estimate", UI.craftStatus:GetText() == "Crafting 1/3 · est. 11s left / 12s total")
harness.casting = false
harness.Event("UNIT_SPELLCAST_INTERRUPTED", "player", "interrupted-cast", 2657)
harness.Check("Cancellation removes the countdown", UI.craftStatus:GetText() == "Crafting interrupted." and addon.state.craftRequest == nil)

harness.missingSpellData = true
UI.quantity:SetText("1"); addon.Refresh()
harness.Check("Missing spell data does not invent a duration", UI.selectedRecipe.castSeconds == nil and UI.craftStatus:GetText() == "")
harness.castDuration = 2
UI.create:Click()
harness.Check("Actual cast timing can supply missing recipe duration", UI.craftStatus:GetText() == "Crafting 1/1 · est. 2s left / 2s total")
harness.casting = false
harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "finished-cast", 2657)
harness.missingSpellData, harness.castDuration = nil, nil
addon.Refresh()
harness.Check("Completed batch clears countdown and restores preview", UI.craftStatus:GetText() == "Create all: est. 18s total")
