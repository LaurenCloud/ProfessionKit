-- Drive the complete addon through a deliberately silent rejection and a native craft.
-- These fixtures verify observability, not the cause of the real client's failure.
local harness, addon = Harness, ProfessionKitAddon
local UI = addon.UI
local trace = ProfessionKitDB.craftDiagnostics
local function Last(kind)
    for index = #trace.entries, 1, -1 do
        if trace.entries[index].kind == kind then return trace.entries[index] end
    end
end

local messagesBefore = #harness.messages
UI.quantity:SetText("1")
harness.silentCraft = true
local estimateSize, estimateColor = UI.recipeStatus.fontSize, UI.recipeStatus.textColor
local estimateTop = select(5, UI.recipeStatus:GetPoint())

UI.create:Click()
harness.Event("UNIT_SPELLCAST_FAILED", "player", "mounted-cast", 2657)
harness.Check("Failed craft unlocks Create immediately", UI.create.enabled and UI.recipeStatus:GetText() == "Crafting failed.")
harness.Event("UI_ERROR_MESSAGE", 57, "You are mounted.")
addon.Refresh()
harness.Check("Mounted rejection from the saved Forever event sequence survives refresh", UI.recipeStatus:GetText() == "You are mounted.")
harness.Check("Craft rejection uses larger type and the red requirement color", UI.recipeStatus.fontSize > estimateSize
    and UI.recipeStatus.textColor[1] == UI.requirements.textColor[1] and UI.recipeStatus.textColor[2] == UI.requirements.textColor[2]
    and UI.recipeStatus.textColor[3] == UI.requirements.textColor[3])
local _, _, _, failureLeft, failureTop = UI.recipeStatus:GetPoint()
local controlsBottom = -select(5, UI.create:GetPoint()) + UI.create:GetHeight()
harness.Check("Craft failure is centered beneath the controls with padding above and below", UI.recipeStatus.justify == "CENTER"
    and failureLeft * 2 + UI.recipeStatus:GetWidth() == UI.detail:GetWidth() and -failureTop - controlsBottom == 16
    and UI.detail:GetHeight() + failureTop - UI.recipeStatus:GetStringHeight() == 16)
harness.Snapshot("mining-craft-failure")
harness.Event("UI_ERROR_MESSAGE", 0, "Unrelated error")
harness.Check("Another UI error keeps the displayed craft reason intact", UI.recipeStatus:GetText() == "You are mounted.")
UI.quantity:SetText("2")
harness.Check("Clearing the failure restores the muted craft estimate", UI.recipeStatus:GetText():find("est.", 1, true)
    and UI.recipeStatus.justify == "LEFT" and select(5, UI.recipeStatus:GetPoint()) == estimateTop
    and UI.recipeStatus.fontSize == estimateSize and UI.recipeStatus.textColor[1] == estimateColor[1]
    and UI.recipeStatus.textColor[2] == estimateColor[2] and UI.recipeStatus.textColor[3] == estimateColor[3])
UI.quantity:SetText("1")

UI.create:Click()
harness.Event("UNIT_SPELLCAST_START", "player", "failed-cast", 2657)
harness.Event("UI_ERROR_MESSAGE", 0, "Missing reagent")
harness.Event("UNIT_SPELLCAST_FAILED", "player", "failed-cast", 2657)
harness.Check("A confirmed cast displays a client error delivered before failure", UI.recipeStatus:GetText() == "Missing reagent")

UI.create:Click()
harness.Event("UI_ERROR_MESSAGE", 0, "Unrelated loot error")
harness.Advance(1)
harness.Event("UNIT_SPELLCAST_FAILED", "player", "silent-failure", 2657)
harness.Advance(1)
harness.Event("UI_ERROR_MESSAGE", 0, "Unrelated bag error")
harness.Check("A failure without a nearby message keeps its plain fallback", UI.recipeStatus:GetText() == "Crafting failed.")

UI.createAll:Click()
harness.Advance(3.3)
local request, call, timeout = Last("craft-request"), Last("craft-api-call"), Last("craft-idle-timeout")
harness.Check("Silent rejection records request, exact API arguments and timeout", request.details.count == 6 and request.details.valid
    and call.details.argumentCount == 2 and call.details.craftingReagents == "<nil>" and timeout.context.ready and not addon.state.crafting)
harness.Check("Craft trace includes live material and recipe evidence", request.context.materials[1].itemID == 2770
    and request.context.materials[1].owned == 6 and request.context.recipeInfo.recipeID == 2657)
harness.Event("UI_ERROR_MESSAGE", 123, "Simulated craft rejection")
harness.Event("ADDON_ACTION_BLOCKED", "ProfessionKit", "CraftRecipe")
harness.Check("Client errors and blocked actions are captured", Last("UI_ERROR_MESSAGE").details.message == "Simulated craft rejection"
    and Last("ADDON_ACTION_BLOCKED").details.action == "CraftRecipe")
harness.silentCraft = false

addon.Native()
local priorCalls = #harness.crafts
C_TradeSkillUI.CraftRecipe(2657, 1, {}, 1, nil, false)
call = Last("craft-api-call")
harness.Check("Native comparison preserves empty reagents, nil order and false concentration", call.source == "original-window"
    and call.details.argumentCount == 6 and type(call.details.craftingReagents) == "table" and next(call.details.craftingReagents) == nil
    and call.details.recipeLevel == 1 and call.details.orderID == "<nil>" and call.details.applyConcentration == false)
harness.Check("Observation does not add or repeat craft calls", #harness.crafts == priorCalls + 1 and harness.crafts[#harness.crafts].count == 1)
harness.Check("Native cast-start event is recorded", Last("UNIT_SPELLCAST_START").details.spellID == 2657)
harness.inventory[2770] = 5
harness.inventory[2840] = (harness.inventory[2840] or 0) + 1
harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "simulation-cast", 2657)
harness.Event("TRADE_SKILL_ITEM_CRAFTED_RESULT", {itemID = 2840, quantity = 1})
harness.casting = false
harness.Event("UPDATE_TRADESKILL_CAST_STOPPED")
harness.Check("Successful comparison records result and changed material count", Last("TRADE_SKILL_ITEM_CRAFTED_RESULT").details.itemID == 2840
    and Last("UPDATE_TRADESKILL_CAST_STOPPED").context.materials[1].owned == 5)
harness.Advance(16)
local entriesBefore = #trace.entries
harness.Event("UI_ERROR_MESSAGE", 999, "Unrelated error after capture window")
harness.Event("UNIT_SPELLCAST_START", "party1", "unrelated-cast", 100)
harness.Check("Unrelated errors and other players' casts are not recorded", #trace.entries == entriesBefore)
harness.combat = true
harness.Event("ADDON_ACTION_BLOCKED", "UnrelatedAddon", "ProtectedAction()")
local blocked = Last("ADDON_ACTION_BLOCKED")
harness.Check("Blocked actions outside crafting retain the client's addon attribution", blocked.details.addon == "UnrelatedAddon"
    and blocked.details.action == "ProtectedAction()" and blocked.details.inCombat and not blocked.details.windowVisible and blocked.context == nil)
harness.combat = false
harness.Event("ADDON_ACTION_FORBIDDEN", "UNKNOWN", "UnknownAction()")
harness.Check("Unattributed forbidden actions are captured without naming a culprit", Last("ADDON_ACTION_FORBIDDEN").details.addon == "UNKNOWN"
    and not Last("ADDON_ACTION_FORBIDDEN").details.inCombat and not addon.state.crafting and #harness.crafts == priorCalls + 1)
harness.Check("Automatic diagnostics do not write chat messages", #harness.messages == messagesBefore)
harness.Event("PLAYER_LOGOUT")
harness.Check("Logout records the final material snapshot", Last("saved").context.materials[1].owned == 5)
harness.Check("Diagnostic observers remained healthy", trace.recordingError == nil)
harness.result.craftDiagnostics = trace
