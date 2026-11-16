local addonName, addon = ...
local Client, UI, Model = addon.Client, addon.UI, addon.Model
addon.version = "0.1.16"
addon.state = { recipes = {}, query = "", sort = "skill", multiplyByQuantity = true, loading = false, crafting = false }
local state = addon.state
local events = CreateFrame("Frame")
local initialized, refreshPending, openGeneration = false, false, 0

local function Message(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff6bcbbaProfessionator:|r " .. text)
end

local function Visible()
    return UI.frame and UI.frame:IsShown()
end

local function ShouldReplaceNative()
    return not addon.nativeMode and (ProfessionatorDB.replaceNative or Visible() or state.requestedID or addon.adoptingNative or addon.cancelledPendingOpen)
end

local function RestoreNativeOpacity()
    if ProfessionsFrame and addon.nativeAlpha ~= nil then
        ProfessionsFrame:SetAlpha(addon.nativeAlpha)
        addon.nativeAlpha = nil
    end
end

-- Hiding Blizzard's visual frame normally also closes its trade-skill data source.
-- Suppress only that hide callback, briefly, and restore it immediately afterward.
function addon.HideNative()
    local frame = ProfessionsFrame
    if addon.nativeMode or InCombatLockdown() or not frame then return end
    if not frame:IsShown() then RestoreNativeOpacity(); return end
    local onHide = frame:GetScript("OnHide")
    frame:SetScript("OnHide", nil)
    local success, reason = pcall(function()
        HideUIPanel(frame)
        if frame:IsShown() then frame:Hide() end
    end)
    frame:SetScript("OnHide", onHide)
    RestoreNativeOpacity()
    if not success then Message("Could not hide the original window: " .. tostring(reason)) end
end

function addon.Refresh()
    if not Visible() then return end
    local recipes = Client.Read(state.professionID)
    if recipes then
        state.recipes = recipes
        state.loading = false
    else
        state.recipes = {}
        state.loading = true
    end
    UI.Refresh()
end

local function QueueRefresh()
    if refreshPending or not Visible() then return end
    refreshPending = true
    C_Timer.After(0.15, function()
        refreshPending = false
        addon.Refresh()
    end)
end

local function FinishCraft(message)
    local request = state.craftRequest
    state.crafting, state.craftRequest = false, nil
    state.craftFailure = message and {recipeID = request and request.recipeID or state.selected, message = message} or nil
    UI.RefreshCraftButtons()
    QueueRefresh()
end

local function ReadCraftTiming(request)
    local _, _, _, startMilliseconds, endMilliseconds, _, _, _, spellID = UnitCastingInfo("player")
    if spellID == request.recipeID and type(startMilliseconds) == "number" and type(endMilliseconds) == "number" and endMilliseconds > startMilliseconds then
        request.castSeconds = (endMilliseconds - startMilliseconds) / 1000
        request.castEndTime = endMilliseconds / 1000
        request.startedAt = request.startedAt or startMilliseconds / 1000
    end
end

local function QueuedCrafts()
    local readRemaining = C_TradeSkillUI.GetRemainingRecasts
    if type(readRemaining) ~= "function" then return nil end
    local success, remaining = pcall(readRemaining)
    if not success or type(remaining) ~= "number" or (issecretvalue and issecretvalue(remaining)) then return nil end
    if remaining < 0 or remaining == math.huge or remaining ~= math.floor(remaining) then return nil end
    return remaining
end

local craftWatchInterval = 3
local function WatchCraft(request)
    local expectedAt = GetTime() + craftWatchInterval
    C_Timer.After(craftWatchInterval, function()
        -- An older request's timer must never stop a newer batch.
        if state.craftRequest ~= request then return end
        local now = GetTime()
        local queuedCrafts = QueuedCrafts()
        -- A backgrounded client can run an overdue timer before queued cast
        -- events. Start a fresh observation window instead of declaring failure.
        if now - expectedAt > 1 then
            request.idleSince = nil
            addon.Diagnostics.Record("craft-watch-resumed", {timerDelay = now - expectedAt, queuedCrafts = queuedCrafts}, request.recipeID)
            WatchCraft(request)
            return
        end
        -- A batch remains active between individual casts. The native queue is
        -- evidence of that activity even while UnitCastingInfo returns nothing.
        if UnitCastingInfo("player") or UnitChannelInfo("player") or (queuedCrafts and queuedCrafts > 0)
            or now - request.lastActivity < craftWatchInterval then
            request.idleSince = nil
            WatchCraft(request)
            return
        end
        if request.started then
            request.idleSince = request.idleSince or now
            if now - request.idleSince < craftWatchInterval then
                WatchCraft(request)
                return
            end
        end
        addon.Diagnostics.Record("craft-idle-timeout", {recipeID = request.recipeID, count = request.count, started = request.started,
            queuedCrafts = queuedCrafts, idleSeconds = request.idleSince and now - request.idleSince}, request.recipeID)
        FinishCraft(request.started and "Crafting stopped." or "Craft did not start. Try Original window.")
    end)
end

local function AdoptOpenProfession(generation, attempt)
    if generation ~= openGeneration or addon.nativeMode then return end
    local current = Client.OpenInfo()
    if current and (not state.requestedID or current.professionID == state.requestedID) then
        if state.professionID ~= current.professionID then
            state.query, state.selected = "", nil
            if UI.search then UI.search:SetText("") end
        end
        state.professionID = current.professionID
        state.requestedID = nil
        addon.adoptingNative = false
        ProfessionatorDB.lastProfessionID = state.professionID
        UI.Build()
        UI.frame:Show()
        addon.HideNative()
        addon.Refresh()
        -- Some clients announce readiness before populating their recipe list.
        if #state.recipes == 0 and attempt < 8 then
            C_Timer.After(0.25, function() AdoptOpenProfession(generation, attempt + 1) end)
        end
    elseif attempt < 12 then
        C_Timer.After(0.25, function() AdoptOpenProfession(generation, attempt + 1) end)
    else
        state.requestedID = nil
        addon.adoptingNative = false
        state.loading = false
        if Visible() then UI.Refresh(); UI.listEmpty:SetText("This profession did not finish loading. Select it again or use Original window.") end
    end
end

local function ScheduleAdoption()
    addon.adoptingNative = true
    openGeneration = openGeneration + 1
    local generation = openGeneration
    C_Timer.After(0, function() AdoptOpenProfession(generation, 0) end)
end

function addon.Open(professionID)
    if InCombatLockdown() then Message("Open professions after combat."); return end
    if state.crafting then Message("Finish or cancel the current batch before switching professions."); return end
    local professions = Client.Professions()
    local selected
    for _, profession in ipairs(professions) do if profession.id == professionID then selected = profession end end
    if not selected then selected = professions[1] end
    addon.nativeMode = false
    addon.cancelledPendingOpen = false
    state.query, state.selected, state.recipes = "", nil, {}
    state.craftFailure = nil
    state.professionID = selected and selected.id or nil
    state.requestedID = state.professionID
    state.loading = selected ~= nil
    UI.Build()
    UI.search:SetText("")
    UI.offset = 0
    UI.Refresh()
    UI.frame:Show()
    if not selected then UI.listEmpty:SetText("Learn a profession from a trainer first."); return end
    local success, reason = pcall(C_TradeSkillUI.OpenTradeSkill, selected.id)
    if not success then state.loading = false; Message("Could not open profession: " .. tostring(reason)) end
    ScheduleAdoption()
end

function addon.Native()
    if InCombatLockdown() then Message("Switch windows after combat."); return end
    addon.nativeMode = true
    addon.adoptingNative = false
    RestoreNativeOpacity()
    openGeneration = openGeneration + 1
    if Visible() then UI.frame:Hide() end
    if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_Professions") end
    if ProfessionsFrame then
        ShowUIPanel(ProfessionsFrame)
    else
        Message("Open your profession from the spellbook to show its original window.")
    end
end

function addon.Closed()
    if not initialized then return end
    if addon.nativeMode or addon.closingFromEvent then return end
    openGeneration = openGeneration + 1
    addon.cancelledPendingOpen = state.requestedID ~= nil or addon.adoptingNative
    addon.adoptingNative = false
    state.requestedID = nil
    if not InCombatLockdown() then C_TradeSkillUI.CloseTradeSkill() end
end

function addon.Craft(all)
    if state.crafting then return end
    local current = Client.OpenInfo()
    -- Read fresh data on the hardware click; the displayed row may be stale.
    local recipe = current and current.professionID == state.professionID and state.selected and Client.Recipe(state.selected) or nil
    local count = all and recipe and recipe.available or tonumber(UI.quantity:GetText()) or 0
    local valid, reason = Model.CraftAllowed(recipe, count, current and current.professionID, state.professionID, InCombatLockdown())
    addon.Diagnostics.Request(recipe, count, all, valid, reason)
    if not valid then
        state.craftFailure = {recipeID = state.selected, message = reason}
        addon.Refresh()
        return
    end
    state.craftFailure = nil
    local request = {recipeID = recipe.id, count = count, remaining = count, started = false, lastActivity = GetTime(), castSeconds = recipe.castSeconds}
    state.craftRequest = request
    state.crafting = true
    WatchCraft(request)
    UI.quantity:ClearFocus()
    -- Match ProfessionBuddy's Forever Source:Craft path: one direct call from the
    -- hardware click. Keep this action outside pcall/xpcall and timer callbacks.
    -- Client rejection is reported through events, not a Lua return value.
    C_TradeSkillUI.CraftRecipe(recipe.id, count)
    UI.RefreshCraftButtons()
end

local function HookNative()
    -- K and the micro-menu initially open an overview without a trade-skill session.
    -- Route their shared entry point before the native window opens.
    if not addon.nativeToggle and type(ToggleProfessionsBook) == "function" then
        addon.nativeToggle = ToggleProfessionsBook
        ToggleProfessionsBook = function(...)
            if not ProfessionatorDB.replaceNative or addon.nativeMode then return addon.nativeToggle(...) end
            if InCombatLockdown() then Message("Open professions after combat."); return end
            if Visible() then UI.frame:Hide() else addon.Open(ProfessionatorDB.lastProfessionID) end
        end
    end
    if not ProfessionsFrame or addon.nativeHooked then return end
    addon.nativeHooked = true
    ProfessionsFrame:HookScript("OnShow", function(frame)
        if not ShouldReplaceNative() then RestoreNativeOpacity(); return end
        -- Suppress rendering during OnShow itself, before the client paints a frame.
        -- Defer HideUIPanel until its ShowUIPanel call has finished, preserving the live
        -- trade-skill session and avoiding recursive panel-manager changes.
        if not InCombatLockdown() and (Visible() or state.requestedID or addon.adoptingNative or addon.cancelledPendingOpen or Client.OpenInfo()) then
            if addon.nativeAlpha == nil then addon.nativeAlpha = frame:GetAlpha() end
            frame:SetAlpha(0)
        end
        -- Let the normal profession book appear when it is not opening a live craft session.
        C_Timer.After(0, function()
            if ShouldReplaceNative() then
                if addon.cancelledPendingOpen then
                    addon.cancelledPendingOpen = false
                    addon.HideNative()
                    C_TradeSkillUI.CloseTradeSkill()
                elseif Visible() or state.requestedID or addon.adoptingNative or Client.OpenInfo() then
                    addon.HideNative()
                    ScheduleAdoption()
                else RestoreNativeOpacity() end
            else
                RestoreNativeOpacity()
            end
        end)
    end)
end

local function BuildLauncher()
    local button = CreateFrame("Button", "ProfessionatorMinimapButton", Minimap)
    addon.launcher = button
    button:SetSize(30, 30)
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -3, 3)
    button:SetFrameStrata("MEDIUM")
    button:SetNormalTexture("Interface\\Icons\\Trade_Tailoring")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then UI.ToggleSettings()
        elseif Visible() then UI.frame:Hide()
        else addon.Open(ProfessionatorDB.lastProfessionID) end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Professionator")
        GameTooltip:AddLine("Left-click: professions\nRight-click: settings", 0.8, 0.85, 0.9)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Initialize()
    if initialized then return end
    ProfessionatorDB = ProfessionatorDB or {}
    if ProfessionatorDB.replaceNative == nil then ProfessionatorDB.replaceNative = true end
    ProfessionatorDB.vendorPrices = ProfessionatorDB.vendorPrices or {}
    state.sort = ProfessionatorDB.sort == "auction" and "auction" or "skill"
    if type(ProfessionatorDB.multiplyByQuantity) ~= "boolean" then ProfessionatorDB.multiplyByQuantity = true end
    state.multiplyByQuantity = ProfessionatorDB.multiplyByQuantity
    initialized = true
    addon.Diagnostics.Initialize()
    BuildLauncher()
    HookNative()
end

events:SetScript("OnEvent", function(_, event, firstArgument, secondArgument, thirdArgument)
    if event == "ADDON_LOADED" then
        if firstArgument == addonName then Initialize() end
        if initialized then HookNative() end
        return
    end
    if not initialized then return end
    if event == "PLAYER_LOGOUT" then
        ProfessionatorDB.sort = state.sort
        ProfessionatorDB.multiplyByQuantity = state.multiplyByQuantity
    elseif event == "TRADE_SKILL_SHOW" then
        addon.cancelledPendingOpen = false
        if ShouldReplaceNative() then ScheduleAdoption() end
    elseif event == "TRADE_SKILL_CLOSE" then
        if state.requestedID then return end
        openGeneration = openGeneration + 1
        addon.adoptingNative = false
        state.crafting = false
        state.craftRequest, state.craftFailure = nil, nil
        addon.closingFromEvent = true
        if Visible() then UI.frame:Hide() end
        addon.closingFromEvent = false
        -- Original window is a fallback for this session, not a permanent preference.
        addon.nativeMode = false
    elseif event == "TRADE_SKILL_CRAFT_BEGIN" then
        if state.craftRequest and state.craftRequest.recipeID == firstArgument then
            state.craftRequest.lastActivity = GetTime()
            state.craftRequest.idleSince = nil
        end
    elseif event:match("^UNIT_SPELLCAST_") then
        local request = state.craftRequest
        if request and firstArgument == "player" and thirdArgument == request.recipeID then
            request.lastActivity = GetTime()
            request.idleSince = nil
            if event == "UNIT_SPELLCAST_START" then
                request.started = true
                ReadCraftTiming(request)
                request.startedAt = request.startedAt or GetTime()
                UI.RefreshCraftButtons()
            elseif event == "UNIT_SPELLCAST_DELAYED" then
                ReadCraftTiming(request)
                UI.RefreshCraftButtons()
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                request.castEndTime = nil
                request.remaining = request.remaining - 1
                if request.remaining <= 0 then FinishCraft() else QueueRefresh() end
            elseif event == "UNIT_SPELLCAST_FAILED" then FinishCraft("Crafting failed. Check the game's error message.")
            elseif event == "UNIT_SPELLCAST_INTERRUPTED" then FinishCraft("Crafting interrupted.") end
        end
    elseif event == "UPDATE_TRADESKILL_CAST_STOPPED" then
        if state.craftRequest then FinishCraft() end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if state.craftRequest and firstArgument == addonName then FinishCraft("WoW blocked crafting. Use Original window.") end
    elseif event == "UI_ERROR_MESSAGE" then
        if state.craftRequest and not state.craftRequest.started then FinishCraft(secondArgument or "Craft did not start.") end
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        Client.RecordVendor()
        QueueRefresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if Visible() then addon.HideNative(); QueueRefresh() end
    else
        QueueRefresh()
    end
end)

for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGOUT", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_DETAILS_UPDATE", "TRADE_SKILL_NAME_UPDATE", "TRADE_SKILL_CRAFT_BEGIN",
    "TRADE_SKILL_ITEM_CRAFTED_RESULT", "UPDATE_TRADESKILL_CAST_STOPPED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
    "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "ITEM_DATA_LOAD_RESULT", "MERCHANT_SHOW", "MERCHANT_UPDATE", "AUCTION_HOUSE_CLOSED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end

-- Station proximity can change without a recipe-list event. Refresh only the selected
-- recipe once per second while visible; avoid repeatedly scanning the entire recipe list.
local elapsedSinceCheck = 0
events:SetScript("OnUpdate", function(_, elapsed)
    if not Visible() then return end
    elapsedSinceCheck = elapsedSinceCheck + elapsed
    if elapsedSinceCheck < 1 then return end
    elapsedSinceCheck = 0
    local current = Client.OpenInfo()
    if current and current.professionID == state.professionID and state.selected then
        local recipe = Client.Recipe(state.selected)
        if recipe then UI.Detail(recipe) end
    else UI.RefreshCraftButtons() end
end)

SLASH_PROFESSIONATOR1 = "/professionator"
SlashCmdList.PROFESSIONATOR = function(command)
    command = (command or ""):lower():match("^%s*(.-)%s*$")
    if command == "native" then addon.Native()
    elseif command == "report" then
        local current = Client.OpenInfo()
        ProfessionatorDB.diagnostic = {
            timestamp = time(), version = addon.version, selectedProfessionID = state.professionID,
            liveProfessionID = current and current.professionID, loading = state.loading,
            recipeCount = #state.recipes, selectedRecipe = state.selected, crafting = state.crafting,
            auctionator = Auctionator and Auctionator.API ~= nil or false, recipes = {},
        }
        for _, recipe in ipairs(state.recipes) do
            tinsert(ProfessionatorDB.diagnostic.recipes, {id = recipe.id, name = recipe.name, available = recipe.available,
                skillEstimate = recipe.skillEstimate, batchPrice = recipe.batchPrice})
        end
        Message("Diagnostic captured. /reload saves it to Professionator's settings file.")
    elseif command == "" then
        if Visible() then UI.frame:Hide() else addon.Open(ProfessionatorDB.lastProfessionID) end
    else Message("/professionator opens the window; /professionator native opens the original; /professionator report captures a diagnostic.") end
end
