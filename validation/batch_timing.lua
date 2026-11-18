local harness, addon = Harness, ProfessionatorAddon
local UI = addon.UI
UI.quantity:SetText("3")
addon.Refresh()
harness.Check("Create all preview uses live recipe cast time and inventory", UI.recipeStatus:GetText() == "Create all: est. 18s total")
harness.Check("Idle estimates do not display a running progress bar", not UI.craftProgress:IsShown())
harness.Check("Quantity controls use native square artwork with centered readable symbols", UI.minus.template == "UIPanelSquareButton,BackdropTemplate" and UI.plus.template == UI.minus.template
    and UI.minus:GetWidth() == UI.minus:GetHeight() and UI.plus:GetWidth() == UI.plus:GetHeight()
    and UI.minus.label.fontSize == 18 and UI.plus.label.fontSize == 18 and UI.plus.label:GetPoint() == "CENTER")
UI.plus:Click(); harness.Check("Plus still increases the requested quantity", UI.quantity:GetText() == "4")
UI.minus:Click(); harness.Check("Minus still decreases the requested quantity", UI.quantity:GetText() == "3")
harness.Check("Recipe tiles use native item or recipe icons", UI.recipeButtons[1].icon.texture == UI.recipeButtons[1].recipe.icon)
harness.Check("Compact search is separate from sort and the quantity modifier", UI.search.background:GetHeight() == 28 and UI.multiplyByQuantity.kind == "CheckButton")
local _, _, _, _, ageTop = UI.market:GetPoint()
harness.Check("AH age sits in the header and cost/margin text is removed", ageTop == -14 and UI.cost == nil and UI.market:GetText() == "AH prices\n1 day old")

UI.create:Click()
harness.Check("Batch start separates total time from the countdown on the bar", UI.craftStatus:GetText() == "Crafting 1/3\nest. 9s total" and UI.craftRemaining:GetText() == "9s left")
harness.Check("Remaining time is centered white text on the progress bar", UI.craftRemaining.parent == UI.craftProgress and UI.craftRemaining:GetPoint() == "CENTER"
    and UI.craftRemaining.textColor[1] == 1 and UI.craftRemaining.textColor[2] == 1 and UI.craftRemaining.textColor[3] == 1)
harness.Check("Confirmed batch starts its progress bar at zero", UI.craftProgress:IsShown() and UI.craftProgress:GetValue() == 0)
harness.Advance(1)
UI.craftProgress:Run("OnUpdate", 0.1)
harness.Check("Countdown subtracts elapsed time from the active cast", UI.craftStatus:GetText() == "Crafting 1/3\nest. 9s total" and UI.craftRemaining:GetText() == "8s left")
harness.Check("Progress covers the entire batch and updates without a recipe refresh", math.abs(UI.craftProgress:GetValue() - 1 / 9) < 0.0001)
harness.Snapshot("mining-batch-timer")

local request, craftCalls = addon.state.craftRequest, #harness.crafts
local function SelectRecipe(recipeID)
    for _, button in ipairs(UI.recipeButtons) do
        if button:IsShown() and button.recipe.id == recipeID then button:Click(); return end
    end
    error("Recipe button is not visible: " .. recipeID)
end
local function BatchPanelClearsDetails()
    local _, _, _, _, detailTop = UI.detail:GetPoint()
    local _, _, _, _, bottomInset = UI.craftingPanel:GetPoint()
    local panelTop = UI.workspace:GetHeight() - bottomInset - UI.craftingPanel:GetHeight()
    return panelTop - (-detailTop + UI.detail:GetHeight()) >= 12
end
local anchor, parent, relativeAnchor, rightInset, bottomInset = UI.craftingPanel:GetPoint()
harness.Check("Active batch owns a separate panel anchored at the workspace bottom right", UI.craftingPanel.parent == UI.workspace
    and UI.craftProgress.parent == UI.craftingPanel and UI.craftStatus.parent == UI.craftingPanel
    and anchor == "BOTTOMRIGHT" and parent == UI.workspace and relativeAnchor == "BOTTOMRIGHT" and rightInset == -12 and bottomInset == 12)
harness.Check("Active recipe always has its identity in the dedicated crafting panel", UI.craftName:IsVisible() and UI.craftIcon:IsVisible()
    and UI.craftName:GetText() == "Smelt Copper" and BatchPanelClearsDetails())
local craftingPanelHeight = UI.craftingPanel:GetHeight()
harness.Check("Countdown keeps seven units of vertical room on each side", (UI.craftProgress:GetHeight() - UI.craftRemaining:GetHeight()) / 2 == 7)
SelectRecipe(1230161)
harness.Check("Browsing another recipe shows the actual active recipe name and icon", UI.selectedRecipe.name == "Lodestone"
    and UI.craftName:IsVisible() and UI.craftName:GetText() == "Smelt Copper" and UI.craftIcon.texture == harness.recipes[2657].info.icon)
harness.Check("Browsing does not restart or retime the batch", addon.state.craftRequest == request and #harness.crafts == craftCalls
    and UI.craftStatus:GetText() == "Crafting 1/3\nest. 9s total" and UI.craftRemaining:GetText() == "8s left" and BatchPanelClearsDetails())
harness.Snapshot("mining-batch-browsing")
harness.recipes[1230161].requirements[1].met = false
addon.Refresh()
harness.Check("Another recipe's unmet forge does not hide active progress", UI.requirements:GetText() == "Requires: Forge"
    and not UI.create:IsShown() and UI.craftingPanel:IsVisible() and UI.craftProgress:IsVisible() and UI.craftName:GetText() == "Smelt Copper")
UI.search:SetText("no matching recipe")
UI.craftProgress:Run("OnUpdate", 0.1)
harness.Check("Empty search retains the batch identity and live countdown", UI.selectedRecipe == nil and UI.craftingPanel:IsVisible()
    and UI.craftName:GetText() == "Smelt Copper" and UI.craftRemaining:GetText() == "8s left")
harness.recipes[1230161].requirements[1].met = true
UI.search:SetText("")
SelectRecipe(2657)
harness.Check("Returning to the active recipe retains the same crafting panel layout", UI.craftName:IsVisible() and UI.craftIcon:IsVisible() and UI.craftingPanel:GetHeight() == craftingPanelHeight
    and UI.craftProgress:IsVisible() and addon.state.craftRequest == request and #harness.crafts == craftCalls)

-- Scroll a larger real recipe fixture while a different recipe is crafting.
for index = 1, 12 do harness.Recipe(90000 + index, 186, "Extra smelting recipe " .. index, 2840, 3, 1, 1, {{2771, 1}}, 3) end
addon.Refresh()
local screenHeight = UIParent:GetHeight()
UIParent:SetHeight(720)
UI.RefreshList()
UI.list:Run("OnMouseWheel", -100)
UI.recipeButtons[UI.visibleRecipeCount]:Click()
harness.Check("A low selected tab stays above active progress on a smaller screen", UI.craftingPanel:IsVisible() and BatchPanelClearsDetails()
    and UI.frame.scale == 1 and UI.frame:GetHeight() <= UIParent:GetHeight() - 60 and UI.visibleRecipeCount < #UI.rows)
harness.Snapshot("mining-batch-scrolled-small-screen")
for index = 1, 12 do harness.recipes[90000 + index] = nil end
UIParent:SetHeight(screenHeight)
addon.Refresh()
SelectRecipe(2657)

harness.castEnd = harness.castEnd + 1
harness.Event("UNIT_SPELLCAST_DELAYED", "player", "delayed-cast", 2657)
harness.Check("Cast delay updates both displayed time estimates", UI.craftStatus:GetText() == "Crafting 1/3\nest. 12s total" and UI.craftRemaining:GetText() == "11s left")
harness.Check("Cast delay also corrects estimated batch progress", math.abs(UI.craftProgress:GetValue() - 1 / 12) < 0.0001)
harness.casting = false
harness.Event("UNIT_SPELLCAST_INTERRUPTED", "player", "interrupted-cast", 2657)
harness.Check("Cancellation removes the entire batch panel and leaves the recipe failure", UI.recipeStatus:GetText() == "Crafting interrupted." and addon.state.craftRequest == nil and not UI.craftProgress:IsShown() and not UI.craftingPanel:IsShown())

harness.missingSpellData = true
UI.quantity:SetText("1"); addon.Refresh()
harness.Check("Missing spell data does not invent a duration or progress", UI.selectedRecipe.castSeconds == nil and UI.recipeStatus:GetText() == "" and not UI.craftProgress:IsShown())
harness.silentCraft = true
UI.create:Click()
harness.Event("UNIT_SPELLCAST_START", "player", "untimed-cast", 2657)
harness.Check("Confirmed crafting without timing keeps its batch count but omits the estimate and bar", UI.craftingPanel:IsVisible()
    and UI.craftStatus:GetText() == "Crafting 1/1" and not UI.craftProgress:IsShown() and UI.craftRemaining:GetText() == "")
harness.Event("UNIT_SPELLCAST_INTERRUPTED", "player", "untimed-cast", 2657)
harness.silentCraft = false
harness.castDuration = 2
UI.create:Click()
harness.Check("Actual cast timing can supply missing recipe duration", UI.craftStatus:GetText() == "Crafting 1/1\nest. 2s total" and UI.craftRemaining:GetText() == "2s left" and UI.craftProgress:IsShown())
harness.casting = false
harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "finished-cast", 2657)
harness.missingSpellData, harness.castDuration = nil, nil
addon.Refresh()
harness.Check("Completed batch clears its panel and restores preview", UI.recipeStatus:GetText() == "Create all: est. 18s total" and not UI.craftProgress:IsShown() and not UI.craftingPanel:IsShown())
