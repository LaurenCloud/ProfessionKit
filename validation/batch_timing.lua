local harness, addon = Harness, ProfessionatorAddon
local UI = addon.UI
UI.quantity:SetText("3")
addon.Refresh()
harness.Check("Create all preview uses live recipe cast time and inventory", UI.craftStatus:GetText() == "Create all: est. 18s total")
harness.Check("Idle estimates do not display a running progress bar", not UI.craftProgress:IsShown())
harness.Check("Quantity controls are square with centered readable symbols", UI.minus:GetWidth() == UI.minus:GetHeight() and UI.plus:GetWidth() == UI.plus:GetHeight()
    and UI.minus.label.fontSize == 18 and UI.plus.label.fontSize == 18 and UI.plus.label:GetPoint() == "CENTER")
UI.plus:Click(); harness.Check("Plus still increases the requested quantity", UI.quantity:GetText() == "4")
UI.minus:Click(); harness.Check("Minus still decreases the requested quantity", UI.quantity:GetText() == "3")
harness.Check("Recipe tiles use native item or recipe icons", UI.recipeButtons[1].icon.texture == UI.recipeButtons[1].recipe.icon)
harness.Check("Compact search is separate from sort and checkbox filter", UI.search.background:GetHeight() == 28 and UI.filter.kind == "CheckButton")
local _, _, _, _, ageTop = UI.market:GetPoint()
harness.Check("AH age sits in the header and cost/margin text is removed", ageTop == -14 and UI.cost == nil and UI.market:GetText() == "AH prices\n1 day old")

UI.create:Click()
harness.Check("Batch start displays total and remaining time", UI.craftStatus:GetText() == "Crafting 1/3\nest. 9s left / 9s total")
harness.Check("Confirmed batch starts its progress bar at zero", UI.craftProgress:IsShown() and UI.craftProgress:GetValue() == 0)
harness.Advance(1)
UI.craftProgress:Run("OnUpdate", 0.1)
harness.Check("Countdown subtracts elapsed time from the active cast", UI.craftStatus:GetText() == "Crafting 1/3\nest. 8s left / 9s total")
harness.Check("Progress covers the entire batch and updates without a recipe refresh", math.abs(UI.craftProgress:GetValue() - 1 / 9) < 0.0001)
harness.Snapshot("mining-batch-timer")
harness.castEnd = harness.castEnd + 1
harness.Event("UNIT_SPELLCAST_DELAYED", "player", "delayed-cast", 2657)
harness.Check("Cast delay updates the remaining-time estimate", UI.craftStatus:GetText() == "Crafting 1/3\nest. 11s left / 12s total")
harness.Check("Cast delay also corrects estimated batch progress", math.abs(UI.craftProgress:GetValue() - 1 / 12) < 0.0001)
harness.casting = false
harness.Event("UNIT_SPELLCAST_INTERRUPTED", "player", "interrupted-cast", 2657)
harness.Check("Cancellation removes the countdown and progress bar", UI.craftStatus:GetText() == "Crafting interrupted." and addon.state.craftRequest == nil and not UI.craftProgress:IsShown())

harness.missingSpellData = true
UI.quantity:SetText("1"); addon.Refresh()
harness.Check("Missing spell data does not invent a duration or progress", UI.selectedRecipe.castSeconds == nil and UI.craftStatus:GetText() == "" and not UI.craftProgress:IsShown())
harness.castDuration = 2
UI.create:Click()
harness.Check("Actual cast timing can supply missing recipe duration", UI.craftStatus:GetText() == "Crafting 1/1\nest. 2s left / 2s total" and UI.craftProgress:IsShown())
harness.casting = false
harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "finished-cast", 2657)
harness.missingSpellData, harness.castDuration = nil, nil
addon.Refresh()
harness.Check("Completed batch clears countdown and restores preview", UI.craftStatus:GetText() == "Create all: est. 18s total" and not UI.craftProgress:IsShown())
