-- Drive the real craft buttons, client events and watchdog with low-frequency
-- between-cast snapshots and timers delivered before events after suspension.
local harness, addon = Harness, ProfessionatorAddon
local UI = addon.UI
harness.Event("ADDON_LOADED", "Professionator")
addon.Open(186); harness.Advance(1)
addon.state.selected = 2657; UI.RefreshList()
UI.quantity:SetText("6")
UI.create:Click()
local request = addon.state.craftRequest
harness.casting, harness.remainingRecasts = false, 5
harness.Advance(3.2)
harness.Check("Queued crafts prevent a false stop between casts", addon.state.craftRequest == request and addon.state.crafting and not addon.state.craftFailure and UI.craftProgress:IsShown())
harness.Advance(9)
harness.Check("Repeated empty cast snapshots do not override the native batch queue", addon.state.craftRequest == request and UI.craftProgress:IsShown())
harness.Check("Watchdog observation never invents completions or issues another craft", request.remaining == 6 and #harness.crafts == 1)

harness.casting = true
harness.Event("UNIT_SPELLCAST_START", "player", "resumed-cast", 2657)
harness.casting, harness.remainingRecasts = false, 4
harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "resumed-cast", 2657)
UI.craftProgress:Run("OnUpdate", 0.1)
harness.Check("Delayed success still advances the original batch exactly once", request.remaining == 5 and UI.craftStatus:GetText():find("Crafting 2/6", 1, true))

-- The batch may finish on the server while the client is not servicing UI
-- events. Its queue reads empty on return, but completion events arrive later.
harness.remainingRecasts = 0
harness.ResumeAfter(30)
harness.Check("An overdue watchdog cannot stop the batch before delayed events arrive", addon.state.craftRequest == request and not addon.state.craftFailure)
local resumed = false
for _, entry in ipairs(ProfessionatorDB.craftDiagnostics.entries) do
    if entry.kind == "craft-watch-resumed" and entry.details.timerDelay > 1 then resumed = true end
end
harness.Check("Delayed timer recovery is recorded for live diagnosis", resumed)
for index = 1, 5 do harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "queued-success-" .. index, 2657) end
harness.Check("Deferred completion events finish the batch and clear its countdown", not addon.state.crafting and not UI.craftProgress:IsShown() and UI.craftRemaining:GetText() == "" and not addon.state.craftFailure)
harness.Check("Background recovery never restarts crafting", #harness.crafts == 1)

UI.quantity:SetText("3"); UI.create:Click()
request = addon.state.craftRequest
harness.casting = false
harness.Advance(3.2)
harness.Check("One idle observation cannot stop a confirmed batch", addon.state.craftRequest == request)
harness.casting = true
harness.Event("UNIT_SPELLCAST_START", "player", "next-cast", 2657)
harness.Check("A new cast clears the pending idle observation", request.idleSince == nil)
harness.casting = false
harness.Event("UNIT_SPELLCAST_INTERRUPTED", "player", "cancelled-cast", 2657)
harness.Check("A real interruption still clears progress immediately", not addon.state.crafting and not UI.craftProgress:IsShown() and UI.recipeStatus:GetText() == "Crafting interrupted.")

UI.create:Click(); harness.casting = false
harness.Advance(6.2)
harness.Check("Repeated idle observations still release a genuinely stalled batch", not addon.state.crafting and UI.recipeStatus:GetText() == "Crafting stopped." and UI.create.enabled)
local timeout
for _, entry in ipairs(ProfessionatorDB.craftDiagnostics.entries) do if entry.kind == "craft-idle-timeout" then timeout = entry end end
harness.Check("Idle-stop diagnostics include both queue state and observation duration", timeout and timeout.details.queuedCrafts == 0 and timeout.details.idleSeconds >= 3)

local nativeRemaining = C_TradeSkillUI.GetRemainingRecasts
C_TradeSkillUI.GetRemainingRecasts = nil
UI.create:Click(); harness.casting = false
request = addon.state.craftRequest
harness.Advance(3.2)
harness.Check("Missing queue API still receives the confirmed-craft grace period", addon.state.craftRequest == request)
harness.Advance(3.1)
harness.Check("Missing queue API does not leave a stopped batch locked forever", not addon.state.crafting and UI.create.enabled)
C_TradeSkillUI.GetRemainingRecasts = nativeRemaining
