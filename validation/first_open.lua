-- Fresh client with Blizzard_Professions still unloaded and no live trade skill.
local harness, addon = Harness, ProfessionKitAddon
local UI = addon.UI
ProfessionsFrame = nil
harness.Event("ADDON_LOADED", "ProfessionKit")
ProfessionKitDB.lastProfessionID = 197
if harness.openFromMenu then ProfessionMicroButton:Click() else ToggleProfessionsBook() end
harness.Advance(1)
local entry = harness.openFromMenu and "Menu button" or "K binding"
harness.Check(entry .. " opens ProfessionKit on the first use after reload", UI.frame and UI.frame:IsShown() and addon.state.professionID == 197 and harness.ready)
harness.Check(entry .. " avoids the native overview and flash", not ProfessionsFrame:IsShown() and harness.visibleNativeShows == 0)
ToggleProfessionsBook(); harness.Advance(0.2)
harness.Check(entry .. " toggles the custom window closed", not UI.frame:IsShown() and not harness.ready)
ProfessionMicroButton:Click(); harness.Advance(1)
harness.Check(entry .. " reopens the remembered profession", UI.frame:IsShown() and addon.state.professionID == 197)
addon.Native()
ToggleProfessionsBook(); harness.Advance(0.2)
harness.Check(entry .. " lets K close an explicit native fallback", not ProfessionsFrame:IsShown() and not UI.frame:IsShown())
ToggleProfessionsBook(); harness.Advance(1)
harness.Check(entry .. " restores custom routing after native fallback", UI.frame:IsShown())
UI.frame:Hide(); harness.Advance(0.2)
ProfessionKitDB.replaceNative = false
ProfessionMicroButton:Click()
harness.Check(entry .. " honors disabled replacement for the overview", ProfessionsFrame:IsShown() and not UI.frame:IsShown())
