-- Executable client simulation. Loads the complete addon and drives its actual UI callbacks.
Harness = { now = 0, frames = {}, timers = {}, items = {}, recipes = {}, inventory = {}, prices = {}, crafts = {}, messages = {}, checks = {}, snapshots = {}, ready = false, current = 0, closeCount = 0, combat = false, visibleNativeShows = 0 }
local harness = Harness
local methods = {}
local function Widget(kind, name, parent)
    local frame = setmetatable({kind = kind, widgetName = name, parent = parent, shown = true, enabled = true, scripts = {}, hooks = {}, points = {}, width = 0, height = 0}, {__index = methods})
    frame.identifier = #harness.frames + 1
    harness.frames[frame.identifier] = frame
    if name then _G[name] = frame end
    return frame
end
function CreateFrame(kind, name, parent, template)
    local frame = Widget(kind, name, parent)
    frame.template = template
    -- Only simulate template-provided objects consumed by the addon. Artwork stays native in WoW.
    if template == "BasicFrameTemplate" then
        frame.backgroundColor, frame.borderColor = {0.12, 0.10, 0.08}, {0.55, 0.49, 0.37}
        frame.Bg = Widget("Texture", nil, frame)
        frame.TitleText = Widget("FontString", nil, frame)
        frame.TitleText:SetSize(280, 18)
        frame.TitleText:SetPoint("TOP", frame, "TOP", -6, -4)
        frame.TitleText:SetTextColor(1, 0.82, 0)
        frame.TitleText:SetJustifyH("CENTER")
        frame.CloseButton = Widget("Button", nil, frame)
        frame.CloseButton:SetSize(24, 24)
        frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -1)
    elseif template == "UIPanelScrollFrameTemplate" then
        frame.ScrollBar = Widget("Frame", nil, frame)
    elseif template == "UICheckButtonTemplate" then
        frame.backgroundColor, frame.borderColor = {0.12, 0.10, 0.08}, {0.55, 0.49, 0.37}
    elseif template and template:find("UIPanelSquareButton", 1, true) then
        frame.backgroundColor, frame.borderColor = {0.22, 0.22, 0.22}, {0.65, 0.65, 0.65}
        frame.icon = Widget("Texture", nil, frame)
    elseif template and template:find("UIPanelButtonTemplate", 1, true) then
        frame.backgroundColor, frame.borderColor = {0.39, 0.055, 0.045}, {0.55, 0.49, 0.37}
        frame.nativeText = Widget("FontString", nil, frame)
        frame.nativeText:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.nativeText:SetSize(1, 14)
        frame.nativeText:SetFontObject("GameFontNormal")
        frame.nativeText:SetTextColor(1, 0.82, 0)
        frame.nativeText:SetJustifyH("CENTER")
    end
    return frame
end
function methods:SetSize(width, height)
    self.width, self.height = width, height
    if self.nativeText then self.nativeText:SetWidth(width - 12) end
end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height)
    if self.height ~= height then
        self.height = height
        self:Run("OnSizeChanged", self.width, height)
    end
end
function methods:SetResizable(resizable) self.resizable = resizable end
function methods:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    self.resizeBounds = {minWidth = minWidth, minHeight = minHeight, maxWidth = maxWidth, maxHeight = maxHeight}
end
function methods:StartSizing(edge) self.sizingEdge = edge end
function methods:StopMovingOrSizing() self.sizingEdge = nil end
function methods:GetWidth() return self.width end
function methods:GetParent() return self.parent end
function methods:SetParent(parent) self.parent = parent end
function methods:GetHeight() return self.height end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == "number" then x, y, relative, relativePoint = relative, relativePoint, self.parent, point
    elseif relative == nil then relative, relativePoint, x, y = self.parent, point, 0, 0 end
    self.points[#self.points + 1] = {point, relative and relative.identifier, relativePoint, x or 0, y or 0}
end
function methods:GetPoint()
    local point = self.points[1]
    return point[1], harness.frames[point[2]], point[3], point[4], point[5]
end
function methods:ClearAllPoints() self.points = {} end
function methods:SetAllPoints(relative)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", relative, "TOPLEFT", 0, 0)
    self:SetPoint("BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0)
end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, callback) self.hooks[event] = self.hooks[event] or {}; table.insert(self.hooks[event], callback) end
function methods:Run(event, ...)
    if self.scripts[event] then self.scripts[event](self, ...) end
    for _, callback in ipairs(self.hooks[event] or {}) do callback(self, ...) end
end
function methods:Hide() if self.shown then self.shown = false; self:Run("OnHide") end end
function methods:Show()
    if not self.shown then
        self.shown = true
        self:Run("OnShow")
        if self == ProfessionsFrame and self:IsVisible() and self:GetAlpha() > 0 then
            harness.visibleNativeShows = harness.visibleNativeShows + 1
        end
    end
end
function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:SetChecked(checked) self.checked = not not checked end
function methods:GetChecked() return self.checked end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:GetAlpha() return self.alpha or 1 end
function methods:CreateFontString(name) return Widget("FontString", name, self) end
function methods:CreateTexture(name) return Widget("Texture", name, self) end
function methods:SetText(text)
    if self.nativeText then self.nativeText:SetText(text) else self.text = text; self:Run("OnTextChanged") end
end
function methods:GetFontString() return self.nativeText end
function methods:GetText() return self.text or "" end
function methods:GetStringWidth()
    return math.min(self:GetWidth(), self:GetUnboundedStringWidth())
end
function methods:GetUnboundedStringWidth()
    local text = self:GetText():gsub("|T.-|t", "..")
    return #text * (self.fontSize or 13) * 0.53
end
function methods:GetStringHeight()
    local lines = 0
    for line in (self:GetText() .. "\n"):gmatch("(.-)\n") do
        lines = lines + math.max(1, math.ceil(#line * (self.fontSize or 13) * 0.53 / math.max(1, self.width)))
    end
    return lines * ((self.fontSize or 13) + 2)
end
function methods:SetDesaturated(value) self.desaturated = value end
function methods:SetFont(path, size) self.fontSize = size end
function methods:SetFontObject() self.fontSize = 13 end
function methods:SetTextColor(...) self.textColor = {...} end
function methods:SetShadowColor(...) self.shadowColor = {...} end
function methods:SetShadowOffset(horizontal, vertical) self.shadowOffset = {horizontal, vertical} end
function methods:SetJustifyH(value) self.justify = value end
function methods:SetWordWrap(value) self.wrap = value end
function methods:SetBackdropColor(...) self.backgroundColor = {...} end
function methods:SetBackdropBorderColor(...) self.borderColor = {...} end
function methods:SetBackdrop(backdrop) self.backdrop = backdrop end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetStatusBarTexture(texture) self.statusBarTexture = texture end
function methods:SetStatusBarColor(...) self.statusBarColor = {...} end
function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function methods:SetValue(value) self.value = value end
function methods:GetValue() return self.value end
function methods:SetRotation(rotation) self.rotation = rotation end
function methods:SetTexCoord(left, right, top, bottom) self.textureCoordinates = {left, right, top, bottom} end
function methods:SetAtlas(atlas, useAtlasSize)
    self.atlas = atlas
    if useAtlasSize then self.width, self.height = 16, 16 end
end
function methods:SetNormalTexture(texture) self.texture = texture end
function methods:SetPushedTexture(texture) self.pushedTexture = texture end
function methods:SetClipsChildren(enabled) self.clipsChildren = enabled end
function methods:SetHitRectInsets(left, right, top, bottom) self.hitInsets = {left, right, top, bottom} end
function methods:SetScale(scale) self.scale = scale end
function methods:SetScrollChild(child) self.scrollChild = child end
function methods:SetVerticalScroll(value) self.verticalScroll = value end
function methods:CreateLine(name) return Widget("Line", name, self) end
function methods:SetThickness(value) self.thickness = value end
function methods:SetColorTexture(...) self.lineColor = {...} end
function methods:SetStartPoint(anchor, relative, x, y) self.startPoint = {relative.identifier, x, y} end
function methods:SetEndPoint(anchor, relative, x, y) self.endPoint = {relative.identifier, x, y} end
function methods:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function methods:Click(button)
    if not self.enabled then return end
    if self.kind == "CheckButton" then self.checked = not self.checked end
    self:Run("OnClick", button or "LeftButton")
end
for _, method in ipairs({"SetHighlightTexture", "SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag", "StartMoving", "SetAutoFocus", "ClearFocus", "EnableMouseWheel", "SetNumeric", "SetMaxLetters", "RegisterForClicks", "SetOwner", "SetHyperlink", "AddLine"}) do methods[method] = function() end end

UIParent = CreateFrame("Frame", "UIParent"); UIParent:SetSize(1440, 900)
Minimap = CreateFrame("Frame", "Minimap", UIParent); Minimap:SetSize(140, 140)
Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -24)
GameTooltip = CreateFrame("Frame", "GameTooltip", UIParent); GameTooltip:Hide()
function GameTooltip:SetOwner(frame) self.owner = frame end
function GameTooltip:IsOwned(frame) return self.owner == frame end
function GameTooltip:SetHyperlink(link) self.hyperlink = link end
GameTooltip:SetScript("OnHide", function(self) self.owner, self.hyperlink = nil, nil end)
ProfessionsFrame = CreateFrame("Frame", "ProfessionsFrame", UIParent); ProfessionsFrame:Hide()
ProfessionsFrame:SetScript("OnHide", function() C_TradeSkillUI.CloseTradeSkill() end)
STANDARD_TEXT_FONT, UISpecialFrames, SlashCmdList = "FrizQuadrata", {}, {}
tinsert, time = table.insert, function() return 1794787200 end
function GetTime() return harness.now end
function GetBuildInfo() return "Forever simulation", "16001", "2026-11-15", 16001 end
function hooksecurefunc(target, name, callback)
    local original = target[name]
    target[name] = function(...)
        original(...)
        callback(...)
    end
end
DEFAULT_CHAT_FRAME = {AddMessage = function(_, text) table.insert(harness.messages, text) end}
function HideUIPanel(frame) frame:Hide() end
function ShowUIPanel(frame) frame:Show() end
function SetTextureWithAddressModeOptions(texture, asset) texture.asset = asset end
function GetMoneyString(copper)
    local gold, silver, coins = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    local function Add(value, metal) table.insert(parts, value .. "|TInterface\\MoneyFrame\\UI-" .. metal .. "Icon:13:13:2:0|t") end
    if gold > 0 then Add(gold, "Gold") end
    if silver > 0 then Add(silver, "Silver") end
    if coins > 0 or #parts == 0 then Add(coins, "Copper") end
    return table.concat(parts, " ")
end
function InCombatLockdown() return harness.combat end
function UnitCastingInfo()
    if not harness.casting then return nil end
    return "Craft", "Craft", 136249, (harness.castStart or harness.now) * 1000, (harness.castEnd or harness.now + 3) * 1000, true, "simulation-cast", false, harness.castSpellID
end
function UnitChannelInfo() return nil end
C_Timer = {After = function(delay, callback) table.insert(harness.timers, {at = harness.now + delay, callback = callback}) end}
C_AddOns = {LoadAddOn = function(name)
    if name == "Blizzard_Professions" and not ProfessionsFrame then
        ProfessionsFrame = CreateFrame("Frame", "ProfessionsFrame", UIParent)
        ProfessionsFrame:Hide()
        ProfessionsFrame:SetScript("OnHide", function() C_TradeSkillUI.CloseTradeSkill() end)
        harness.Event("ADDON_LOADED", name)
    end
end}
function ToggleProfessionsBook()
    C_AddOns.LoadAddOn("Blizzard_Professions")
    if ProfessionsFrame:IsShown() then ProfessionsFrame:Hide() else ProfessionsFrame:Show() end
end
ProfessionMicroButton = CreateFrame("Button", "ProfessionMicroButton", UIParent)
ProfessionMicroButton:SetScript("OnClick", function() ToggleProfessionsBook() end)
Enum = {CraftingReagentType = {Basic = 1}}

function harness.Advance(seconds)
    local target, executions = harness.now + seconds, 0
    while true do
        table.sort(harness.timers, function(left, right) return left.at < right.at end)
        if not harness.timers[1] or harness.timers[1].at > target then break end
        local timer = table.remove(harness.timers, 1)
        harness.now = timer.at; timer.callback(); executions = executions + 1
        assert(executions < 500, "Runaway timer scheduling")
    end
    harness.now = target
end
function harness.ResumeAfter(seconds)
    -- Model a client that does not service timers while suspended. Overdue
    -- callbacks all resume at the current clock, before delayed event delivery.
    harness.now = harness.now + seconds
    local executions = 0
    while true do
        table.sort(harness.timers, function(left, right) return left.at < right.at end)
        if not harness.timers[1] or harness.timers[1].at > harness.now then break end
        local timer = table.remove(harness.timers, 1)
        timer.callback(); executions = executions + 1
        assert(executions < 500, "Runaway resumed timer scheduling")
    end
end
function harness.Event(event, ...)
    local unit, _, spellID = ...
    if event == "UNIT_SPELLCAST_START" and unit == "player" then
        harness.castStart, harness.castEnd, harness.castSpellID = harness.now, harness.now + (harness.castDuration or 3), spellID
    end
    local listeners = {}
    for _, frame in ipairs(harness.frames) do if frame.events and frame.events[event] then table.insert(listeners, frame) end end
    for _, frame in ipairs(listeners) do frame:Run("OnEvent", event, ...) end
end
function harness.Check(name, condition, detail)
    table.insert(harness.checks, {name = name, passed = not not condition, detail = detail or ""})
    assert(condition, name .. ": " .. (detail or "failed"))
end
function harness.Snapshot(name)
    local rows = {}
    for _, frame in ipairs(harness.frames) do
        if frame:IsVisible() then
            table.insert(rows, {identifier = frame.identifier, parent = frame.parent and frame.parent.identifier, kind = frame.kind,
                name = frame.widgetName, width = frame.width, height = frame.height, points = frame.points, text = frame.text,
                fontSize = frame.fontSize, textColor = frame.textColor, backgroundColor = frame.backgroundColor, clipsChildren = frame.clipsChildren,
                shadowColor = frame.shadowColor, shadowOffset = frame.shadowOffset,
                borderColor = frame.borderColor, texture = frame.texture, textureCoordinates = frame.textureCoordinates, rotation = frame.rotation,
                statusBarTexture = frame.statusBarTexture, statusBarColor = frame.statusBarColor,
                minimum = frame.minimum, maximum = frame.maximum, value = frame.kind == "StatusBar" and frame.value or nil,
                atlas = frame.atlas, justify = frame.justify, wrap = frame.wrap, alpha = frame.alpha,
                template = frame.template, backdrop = frame.backdrop, checked = frame.checked, lineColor = frame.lineColor, startPoint = frame.startPoint, endPoint = frame.endPoint, thickness = frame.thickness})
        end
    end
    harness.snapshots[name] = rows
end

harness.professions = {
    {name = "Mining", id = 186, rank = 65, maximum = 150},
    {name = "Tailoring", id = 197, rank = 55, maximum = 150},
    {name = "Cooking", id = 185, rank = 25, maximum = 75},
    {name = "Fishing", id = 356, rank = 1, maximum = 75},
    {name = "First Aid", id = 129, rank = 45, maximum = 75},
}
function GetProfessions() return 1, 2, nil, 4, 3, 5 end
function GetProfessionInfo(index)
    local profession = harness.professions[index]
    return profession.name, 136249, profession.rank, profession.maximum, 0, 0, profession.id
end
function harness.Item(id, name, sell, count, price)
    harness.items[id] = {name = name, sell = sell}
    harness.inventory[id] = count or 0
    harness.prices[id] = price
end
function harness.Recipe(id, profession, name, output, difficulty, gray, yield, materials, category)
    local slots = {}
    for _, material in ipairs(materials) do
        table.insert(slots, {required = true, reagentType = 1, quantityRequired = material[2], reagents = {{itemID = material[1]}}})
    end
    harness.recipes[id] = {profession = profession,
        info = {recipeID = id, name = name, learned = true, relativeDifficulty = difficulty, canSkillUp = difficulty < 3,
            maxTrivialLevel = gray, numSkillUps = 1, icon = 136249, categoryID = category or 1},
        schematic = {outputItemID = output, quantityMin = yield, quantityMax = yield, reagentSlotSchematics = slots},
        requirements = profession == 186 and {{name = "Forge", met = true}} or {}}
end
C_Item = {
    GetItemInfo = function(id)
        local item = harness.items[id]
        if not item or item.uncached then return nil end
        return item.name, "item:" .. id, 1, 1, 1, "Trade Goods", "Other", 20, "", 136249, item.sell, 7, 0, item.bound and 1 or 0
    end,
    GetItemCount = function(id) return harness.inventory[id] or 0 end,
    RequestLoadItemDataByID = function(id) harness.lastItemRequested = id end,
}
C_Spell = {GetSpellInfo = function(id)
    if harness.missingSpellData then return nil end
    return harness.recipes[id] and {spellID = id, castTime = harness.spellCastMilliseconds or 3000}
end}
C_TradeSkillUI = {
    GetRemainingRecasts = function() return harness.remainingRecasts or 0 end,
    IsTradeSkillReady = function() return harness.ready end,
    IsDataSourceChanging = function() return not harness.ready end,
    IsTradeSkillLinked = function() return harness.linked end,
    GetBaseProfessionInfo = function()
        for _, profession in ipairs(harness.professions) do
            if profession.id == harness.current then return {professionID = profession.id, professionName = profession.name, skillLevel = profession.rank, maxSkillLevel = profession.maximum} end
        end
        return {professionID = 0}
    end,
    GetChildProfessionInfo = function() return {professionID = 0} end,
    GetRecipeInfo = function(id) local recipe = harness.recipes[id]; return recipe and recipe.info end,
    GetRecipeSchematic = function(id) local recipe = harness.recipes[id]; return recipe and recipe.schematic end,
    GetCategoryInfo = function(id) return {name = id == 2717 and "Camping" or (id == 2 and "Bags" or (id == 3 and "Materials" or "Cloth armor"))} end,
    GetRecipeRequirements = function(id) return harness.recipes[id].requirements end,
    GetRecipeCooldown = function(id) return harness.recipes[id].cooldown end,
    GetCraftableCount = function(id)
        local available = math.huge
        for _, slot in ipairs(harness.recipes[id].schematic.reagentSlotSchematics) do
            available = math.min(available, math.floor((harness.inventory[slot.reagents[1].itemID] or 0) / slot.quantityRequired))
        end
        return available
    end,
    GetAllRecipeIDs = function()
        local ids = {}
        for id in pairs(harness.recipes) do table.insert(ids, id) end
        table.sort(ids)
        return ids
    end,
    IsRecipeInSkillLine = function(id, profession) return harness.recipes[id].profession == profession end,
    OpenTradeSkill = function(profession)
        C_AddOns.LoadAddOn("Blizzard_Professions")
        harness.ready = false
        harness.Event("TRADE_SKILL_SHOW")
        if harness.showNativeBeforeReady then ProfessionsFrame:Show() end
        C_Timer.After(0.25, function()
            harness.current = profession; harness.ready = true
            ProfessionsFrame:Show()
            harness.Event("TRADE_SKILL_DATA_SOURCE_CHANGED")
            harness.Event("TRADE_SKILL_LIST_UPDATE")
        end)
    end,
    CloseTradeSkill = function()
        harness.closeCount = harness.closeCount + 1
        harness.ready = false
        harness.Event("TRADE_SKILL_CLOSE")
    end,
    CraftRecipe = function(id, count)
        if harness.rejectCraft then harness.Event("UI_ERROR_MESSAGE", 123, "Client rejected this craft"); return end
        if harness.blockCraft then harness.Event("ADDON_ACTION_BLOCKED", "ProfessionKit", "UNKNOWN()"); return end
        table.insert(harness.crafts, {id = id, count = count})
        if harness.silentCraft then return end
        harness.casting = true
        harness.Event("TRADE_SKILL_CRAFT_BEGIN", id)
        harness.Event("UNIT_SPELLCAST_START", "player", "simulation-cast", id)
    end,
}
Auctionator = {API = {v1 = {
    GetAuctionPriceByItemID = function(_, id) return harness.prices[id] end,
    GetAuctionAgeByItemID = function(_, id) return harness.prices[id] and 1 end,
}}, Database = {GetPriceHistory = function(_, id) return harness.prices[tonumber(id)] and {{available = 126}} or {} end}}
function GetMerchantNumItems() return 1 end
function GetMerchantItemLink() return "item:2320" end
C_MerchantFrame = {GetItemInfo = function() return {name = "Coarse Thread", texture = 136249, price = 10, stackCount = 1, numAvailable = -1, isPurchasable = true, hasExtendedCost = false} end}

-- Classic recipe shapes and quantities; prices and inventory are controlled scenarios, not live market quotes.
harness.Item(2589, "Linen Cloth", 13, 80, 20)
harness.Item(2996, "Bolt of Linen Cloth", 40, 24, 90)
harness.Item(2320, "Coarse Thread", 2, 12, 18)
harness.Item(2604, "Red Dye", 3, 2, 60)
harness.Item(2997, "Bolt of Woolen Cloth", 100, 0, 240)
harness.Item(2770, "Copper Ore", 5, 28, 63)
harness.Item(2771, "Tin Ore", 25, 8, 100)
harness.Item(2840, "Copper Bar", 10, 8, 68)
harness.Item(3576, "Tin Bar", 35, 0, 130)
harness.Item(2841, "Bronze Bar", 50, 0, 115)
harness.Recipe(2657, 186, "Smelt Copper", 2840, 2, 70, 1, {{2770, 1}}, 3)
harness.Recipe(3304, 186, "Smelt Tin", 3576, 0, 100, 1, {{2771, 1}}, 3)
harness.Recipe(2659, 186, "Smelt Bronze", 2841, 0, 115, 2, {{2840, 1}, {3576, 1}}, 3)
harness.Recipe(2963, 197, "Bolt of Linen Cloth", 2996, 3, 50, 1, {{2589, 2}}, 3)
local tailoring = {
    {2386, 2569, "Linen Boots", 2, 85, 2, 1, 140},
    {2385, 2568, "Brown Linen Vest", 3, 55, 1, 1, 110},
    {2387, 2570, "Linen Cloak", 3, 50, 1, 1, 90},
    {2389, 2572, "Red Linen Robe", 0, 95, 3, 2, 900, true},
    {2392, 2575, "Red Linen Shirt", 1, 85, 2, 1, 700, true},
    {2393, 2576, "White Linen Shirt", 1, 80, 1, 1, 170},
    {2394, 2577, "Blue Linen Shirt", 1, 90, 2, 1, nil},
    {2395, 2578, "Barbaric Linen Vest", 1, 100, 3, 1, 220},
    {7623, 6238, "Brown Linen Robe", 0, 90, 3, 1, 250},
    {7624, 6241, "White Linen Robe", 0, 95, 3, 1, 280},
    {3840, 4307, "Heavy Linen Gloves", 0, 110, 2, 1, 350},
    {3755, 4238, "Linen Bag", 0, 95, 3, 3, 600},
}
for _, entry in ipairs(tailoring) do
    harness.Item(entry[2], entry[3], 50, 0, entry[8])
    local materials = {{2996, entry[6]}, {2320, entry[7]}}
    if entry[9] then table.insert(materials, {2604, 1}) end
    harness.Recipe(entry[1], 197, entry[3], entry[2], entry[4], entry[5], 1, materials, entry[2] == 4238 and 2 or 1)
end
