local _, addon = ...
addon.Diagnostics = {}
local Diagnostics = addon.Diagnostics
local maximumEntries = 160
local lastCraftTime, lastRecipeID, sessionStarted

-- SavedVariables contain only bounded, serializable copies. Never retain live API tables.
local function Copy(value, depth)
    local valueType = type(value)
    if valueType == "nil" then return "<nil>" end
    if valueType == "string" then return value:sub(1, 512) end
    if valueType == "number" or valueType == "boolean" then return value end
    if valueType ~= "table" then return "<" .. valueType .. ">" end
    if depth >= 6 then return "<depth limit>" end
    local result, count = {}, 0
    for key, item in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            count = count + 1
            if count > 80 then result.truncated = true; break end
            result[key] = Copy(item, depth + 1)
        end
    end
    return result
end

local function Read(callback, ...)
    if type(callback) ~= "function" then return "<unavailable>" end
    local success, value = pcall(callback, ...)
    if not success then return {error = tostring(value)} end
    return value
end

local function Context(recipeID)
    local api = C_TradeSkillUI
    local schematic = recipeID and Read(api.GetRecipeSchematic, recipeID, false)
    local context = {
        ready = Read(api.IsTradeSkillReady), changing = Read(api.IsDataSourceChanging), linked = Read(api.IsTradeSkillLinked),
        profession = Read(api.GetBaseProfessionInfo), childProfession = Read(api.GetChildProfessionInfo),
        selectedProfessionID = addon.state.professionID, selectedRecipeID = addon.state.selected,
        nativeVisible = ProfessionsFrame and ProfessionsFrame:IsShown() or false,
        nativeAlpha = ProfessionsFrame and ProfessionsFrame:GetAlpha(),
        playerCasting = UnitCastingInfo("player"), playerChanneling = UnitChannelInfo("player"),
        remainingRecasts = Read(api.GetRemainingRecasts),
        recipeInfo = recipeID and Read(api.GetRecipeInfo, recipeID), schematic = schematic,
        craftableCount = recipeID and Read(api.GetCraftableCount, recipeID),
        requirements = recipeID and Read(api.GetRecipeRequirements, recipeID), materials = {},
        cooldown = recipeID and Read(addon.Client.Cooldown, recipeID),
        enchantTargetGUID = addon.Targets.selectedGUID,
    }
    for _, slot in ipairs(type(schematic) == "table" and schematic.reagentSlotSchematics or {}) do
        for _, reagent in ipairs(slot.reagents or {}) do
            if reagent.itemID then
                context.materials[#context.materials + 1] = {itemID = reagent.itemID, required = slot.quantityRequired,
                    owned = Read(C_Item.GetItemCount, reagent.itemID, false, false, false)}
            end
        end
    end
    local form = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
    if form then
        context.nativeRecipeInfo = Read(form.GetRecipeInfo, form)
        context.nativeRecipeLevel = Read(form.GetCurrentRecipeLevel, form)
    end
    return context
end

function Diagnostics.Record(kind, details, recipeID)
    if not ProfessionatorDB or not ProfessionatorDB.craftDiagnostics then return end
    -- Observation must never interrupt a craft, including when an API is unavailable.
    local success, failure = pcall(function()
        local trace = ProfessionatorDB.craftDiagnostics
        local entry = {kind = kind, timestamp = time(), elapsed = GetTime(), sessionStarted = sessionStarted,
            version = addon.version, source = addon.nativeMode and "original-window" or "professionator", details = details}
        if recipeID then entry.context = Context(recipeID) end
        trace.entries[#trace.entries + 1] = Copy(entry, 0)
        while #trace.entries > maximumEntries do table.remove(trace.entries, 1) end
    end)
    if not success then ProfessionatorDB.craftDiagnostics.recordingError = tostring(failure) end
end

function Diagnostics.Request(recipe, count, all, valid, reason)
    lastCraftTime = GetTime()
    lastRecipeID = recipe and recipe.id or addon.state.selected
    Diagnostics.Record("craft-request", {recipeID = lastRecipeID, count = count, createAll = all, valid = valid, reason = reason}, lastRecipeID)
end

local professionEvents = {
    TRADE_SKILL_CRAFT_BEGIN = true, TRADE_SKILL_ITEM_CRAFTED_RESULT = true, UPDATE_TRADESKILL_CAST_STOPPED = true,
    TRADE_SKILL_SHOW = true, TRADE_SKILL_CLOSE = true, TRADE_SKILL_DATA_SOURCE_CHANGED = true,
}

function Diagnostics.Event(event, firstArgument, secondArgument, thirdArgument)
    if event == "TRADE_SKILL_CRAFT_BEGIN" then
        lastCraftTime, lastRecipeID = GetTime(), firstArgument
    end
    local recentCraft = lastCraftTime and GetTime() - lastCraftTime <= 15
    local details
    if professionEvents[event] then
        details = {}
        if event == "TRADE_SKILL_CRAFT_BEGIN" then details.recipeID = firstArgument end
        if event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" and type(firstArgument) == "table" then
            details.itemID, details.quantity = firstArgument.itemID, firstArgument.quantity
        end
    elseif event:match("^UNIT_SPELLCAST_") and firstArgument == "player" and recentCraft then
        details = {spellID = thirdArgument}
    elseif event == "UI_ERROR_MESSAGE" and recentCraft then
        details = {errorID = firstArgument, message = secondArgument}
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        -- A warning while travelling can come from any addon, far outside a craft's capture window.
        -- Preserve the client's attribution without assuming that this observer caused the block.
        details = {addon = firstArgument, action = secondArgument, inCombat = InCombatLockdown(),
            windowVisible = addon.UI.frame and addon.UI.frame:IsShown() or false}
    elseif event == "PLAYER_LOGOUT" then
        Diagnostics.Record("saved", {}, lastRecipeID)
    end
    if details then Diagnostics.Record(event, details, recentCraft and lastRecipeID or nil) end
end

function Diagnostics.Initialize()
    local trace = ProfessionatorDB.craftDiagnostics
    if type(trace) ~= "table" or trace.schema ~= 1 then trace = {schema = 1, entries = {}} end
    ProfessionatorDB.craftDiagnostics = trace
    sessionStarted = time()
    Diagnostics.Record("loaded", {build = GetBuildInfo()})
    -- A secure post-hook observes both buttons without replacing or changing CraftRecipe.
    hooksecurefunc(C_TradeSkillUI, "CraftRecipe", function(...)
        local recipeID, count, craftingReagents, recipeLevel, orderID, applyConcentration = ...
        lastCraftTime, lastRecipeID = GetTime(), recipeID
        Diagnostics.Record("craft-api-call", {argumentCount = select("#", ...), recipeID = recipeID, count = count,
            craftingReagents = Copy(craftingReagents, 0), recipeLevel = Copy(recipeLevel, 0),
            orderID = Copy(orderID, 0), applyConcentration = Copy(applyConcentration, 0)}, recipeID)
    end)
    if C_TradeSkillUI.CraftEnchant then
        hooksecurefunc(C_TradeSkillUI, "CraftEnchant", function(recipeID, count, _, location)
            lastCraftTime, lastRecipeID = GetTime(), recipeID
            Diagnostics.Record("enchant-api-call", {recipeID = recipeID, count = count,
                targetGUID = location and Read(C_Item.GetItemGUID, location)}, recipeID)
        end)
    end
    local events = CreateFrame("Frame")
    events:SetScript("OnEvent", function(_, ...) Diagnostics.Event(...) end)
    for event in pairs(professionEvents) do events:RegisterEvent(event) end
    for _, event in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UI_ERROR_MESSAGE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "PLAYER_LOGOUT"}) do events:RegisterEvent(event) end
end
