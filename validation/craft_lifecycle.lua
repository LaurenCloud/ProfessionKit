-- Exercise client event sequences through the real Create buttons and event handlers.
local harness, addon = Harness, ProfessionatorAddon
local UI = addon.UI
local originalOre = harness.inventory[2770]
UI.quantity:SetText("1")
harness.blockCraft = true
UI.create:Click()
harness.blockCraft = false
harness.Check("Blocked action ends the request immediately", not addon.state.crafting and addon.state.craftRequest == nil
    and UI.craftStatus:GetText() == "WoW blocked crafting. Use Original window.")
for _, frame in ipairs(harness.frames) do if frame.scripts.OnUpdate then frame:Run("OnUpdate", 1.1) end end
harness.Advance(0.2)
harness.Check("Blocked-action explanation survives routine refresh", UI.craftStatus:GetText() == "WoW blocked crafting. Use Original window.")

harness.silentCraft = true
UI.create:Click()
harness.Check("Unacknowledged request says Starting instead of Crafting", UI.craftStatus:GetText() == "Starting craft…")
harness.Check("Unacknowledged request cannot show simulated crafting progress", not UI.craftProgress:IsShown())
harness.Event("UNIT_SPELLCAST_FAILED", "player", "unrelated", 999)
harness.Check("Unrelated player spells do not stop the craft request", addon.state.crafting)
harness.Advance(3.2)
harness.Check("No-response timeout explains failure and unlocks controls", UI.create.enabled and not addon.state.crafting
    and UI.craftStatus:GetText() == "Craft did not start. Try Original window.")
harness.silentCraft = false

UI.quantity:SetText("3")
local callsBefore = #harness.crafts
UI.create:Click()
harness.Check("Actual cast start confirms Crafting status", UI.craftStatus:GetText():find("Crafting 1/3", 1, true) and addon.state.craftRequest.started)
-- The real successful native trace uses SPELLCAST_SUCCEEDED, with no batch-stop event.
for craftIndex = 1, 3 do
    harness.Advance(2)
    harness.inventory[2770] = harness.inventory[2770] - 1
    harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "batch-cast", 2657)
    harness.Event("TRADE_SKILL_ITEM_CRAFTED_RESULT", {itemID = 2840, quantity = 1})
    harness.Event("BAG_UPDATE_DELAYED")
    if craftIndex < 3 then
        harness.Check("Batch remains active after craft " .. craftIndex, addon.state.crafting and addon.state.craftRequest.remaining == 3 - craftIndex)
        UI.craftProgress:Run("OnUpdate", 0.1)
        harness.Check("Batch progress survives craft " .. craftIndex, UI.craftProgress:IsShown() and UI.craftProgress:GetValue() > 0 and UI.craftProgress:GetValue() < 1)
        harness.Event("UNIT_SPELLCAST_START", "player", "batch-cast", 2657)
    end
end
harness.casting = false
harness.Advance(0.2)
harness.Check("Spellcast completion unlocks controls without batch-stop event", not addon.state.crafting and UI.create.enabled)
harness.Check("The client batch needs one API call and no automatic recasts", #harness.crafts == callsBefore + 1 and harness.crafts[#harness.crafts].count == 3)

UI.quantity:SetText("1")
UI.create:Click()
harness.casting = false
harness.Event("UNIT_SPELLCAST_INTERRUPTED", "player", "interrupted-cast", 2657)
harness.Check("Movement cancellation clears only the tracked craft", not addon.state.crafting and UI.craftStatus:GetText() == "Crafting interrupted.")
UI.create:Click()
local request = addon.state.craftRequest
harness.Advance(2.2)
harness.Check("Older batch watchdogs cannot end a newer request", addon.state.craftRequest == request and addon.state.crafting)
harness.casting = false
harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "new-cast", 2657)
harness.Advance(0.2)
harness.inventory[2770] = originalOre
addon.Refresh()
