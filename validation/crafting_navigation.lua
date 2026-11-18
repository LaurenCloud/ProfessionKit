-- Exercise real profession buttons while an independently identified batch runs.
-- The simulated data-source handoff deliberately includes early and late close
-- notifications; it does not establish native client's protected-call behavior.
local harness, addon = Harness, ProfessionatorAddon
local UI = addon.UI
harness.Event("ADDON_LOADED", "Professionator")
addon.Open(186); harness.Advance(1)
addon.state.selected = 2657; UI.RefreshList()
UI.quantity:SetText("6"); UI.create:Click()
local request = addon.state.craftRequest
local panelHeight = UI.craftingPanel:GetHeight()
local closeCount, openCount = harness.closeCount, 0
local openTradeSkill = C_TradeSkillUI.OpenTradeSkill
C_TradeSkillUI.OpenTradeSkill = function(professionID)
    openCount = openCount + 1
    harness.Event("TRADE_SKILL_CLOSE")
    openTradeSkill(professionID)
end
local function SelectProfession(professionID)
    for _, button in ipairs(UI.professionButtons) do
        if button.profession and button.profession.id == professionID then button:Click(); return end
    end
    error("Profession button not found: " .. professionID)
end

SelectProfession(197)
harness.Check("Switching during a batch immediately clears the old recipe list but retains active progress", addon.state.loading
    and #addon.state.recipes == 0 and UI.selectedRecipe == nil and addon.state.craftRequest == request and UI.craftingPanel:IsVisible())
harness.Advance(1)
harness.Check("Tailoring can be browsed while the captured Mining batch remains active", addon.state.professionID == 197
    and UI.title:GetText() == "Tailoring" and #UI.rows == 13 and request.professionID == 186 and request.recipeID == 2657)
harness.Check("Cross-profession panel consistently names the original recipe", UI.craftName:IsVisible() and UI.craftName:GetText() == "Smelt Copper"
    and UI.craftIcon.texture == request.icon and UI.craftingPanel:GetHeight() == panelHeight and UI.craftingPanel:GetPoint() == "BOTTOMRIGHT")
harness.Check("Navigation never closes the data source or calls CraftRecipe again", #harness.crafts == 1 and harness.closeCount == closeCount
    and harness.visibleNativeShows == 0)
UI.create:Click(); UI.createAll:Click(); addon.Craft(true)
harness.Check("Browsing cannot start or queue a second craft", not UI.create.enabled and not UI.createAll.enabled
    and #harness.crafts == 1 and request.remaining == 6)
harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "unrelated", 2963)
harness.Event("UNIT_SPELLCAST_INTERRUPTED", "player", "unrelated", 2963)
harness.Check("Events from the browsed recipe do not alter the active batch", addon.state.craftRequest == request and request.remaining == 6)

harness.Event("UPDATE_TRADESKILL_CAST_STOPPED")
harness.Advance(.2)
harness.Check("A recipe-less stop notification cannot erase an actual running cast", addon.state.craftRequest == request and UI.craftProgress:IsVisible())
harness.Event("TRADE_SKILL_CLOSE"); harness.Advance(.2)
harness.Check("Late source-close notification keeps the active batch and browser visible", UI.frame:IsShown()
    and addon.state.craftRequest == request and UI.title:GetText() == "Tailoring")
local beforeSameTab = openCount
SelectProfession(197)
harness.Check("Clicking the selected profession avoids reopening its native source", openCount == beforeSameTab and addon.state.craftRequest == request)
harness.casting, harness.remainingRecasts = false, 5
harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "first-copper", 2657)
harness.Event("UPDATE_TRADESKILL_CAST_STOPPED")
harness.Advance(3.2)
harness.Check("Between-cast queue and matching success survive another profession being selected", addon.state.craftRequest == request
    and request.remaining == 5 and UI.craftStatus:GetText():find("Crafting 2/6", 1, true))
harness.Snapshot("crafting-while-browsing-tailoring")
SelectProfession(186); harness.Advance(1)
harness.Check("Returning to the crafting profession retains its original count and panel geometry", addon.state.craftRequest == request
    and request.remaining == 5 and UI.craftingPanel:GetHeight() == panelHeight)
SelectProfession(185); harness.Advance(1)
harness.Check("A profession with no loaded recipes still retains the active crafting panel", addon.state.professionID == 185
    and #UI.rows == 0 and UI.craftName:GetText() == "Smelt Copper" and UI.craftingPanel:IsVisible())
harness.remainingRecasts = 0
for index = 1, 5 do harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "remaining-copper-" .. index, 2657) end
harness.Event("UPDATE_TRADESKILL_CAST_STOPPED")
harness.Check("Completing the original batch clears the one panel without changing the browsed profession", not addon.state.crafting
    and not UI.craftingPanel:IsShown() and addon.state.professionID == 185 and not addon.state.craftFailure and #harness.crafts == 1)

SelectProfession(197); harness.Advance(1)
UI.quantity:SetText("1"); UI.create:Click()
harness.Check("Crafting in the browsed profession is enabled once the previous batch finishes", #harness.crafts == 2
    and addon.state.craftRequest.professionID == 197)
local tailoringRecipeID = addon.state.craftRequest.recipeID
SelectProfession(186); harness.Advance(1)
harness.casting = false
harness.Event("UNIT_SPELLCAST_INTERRUPTED", "player", "interrupted-tailoring", tailoringRecipeID)
harness.Check("A real interruption ends the active batch even while browsing elsewhere", not addon.state.crafting and not UI.craftingPanel:IsShown()
    and addon.state.craftFailure.recipeID == tailoringRecipeID and addon.state.professionID == 186)
local beforeCombat = openCount
harness.combat = true; SelectProfession(197)
harness.Check("Combat still prevents protected profession switching", openCount == beforeCombat and addon.state.professionID == 186)
harness.combat = false
local switchTrace
for _, entry in ipairs(ProfessionatorDB.craftDiagnostics.entries) do
    if entry.kind == "browse-profession-during-craft" then switchTrace = entry end
end
harness.Check("Switch diagnostics distinguish the viewed and actively crafting professions", switchTrace
    and switchTrace.details.toProfessionID == 186 and switchTrace.context.craftingProfessionID == 197)
