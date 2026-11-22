local _, addon = ...
local Model = addon.Model
addon.UI = {}
local UI = addon.UI
-- Panels share an inset; recipe tiles use narrower sides to leave room for names.
local padding = 12
local craftFailurePadding = 16
local navigationWidth = 164
local recipeListWidth = 354
local detailWidth = 406
local workspaceWidth = recipeListWidth + detailWidth + padding * 3
local windowWidth = navigationWidth + workspaceWidth + padding * 2
local workspaceTop = 24 + padding
local recipeListTop = 124
local materialsTop = 88
local defaultMaximumVisibleRecipes = 12
local recipeHorizontalPadding = 8
local recipeTileWidth = recipeListWidth - padding * 2
local recipeRowHeight = 58
local craftWheelFramesPerMode = 64
local recipeRowGap = 6
local recipeRowStride = recipeRowHeight + recipeRowGap
local recipeSectionHeight = 18 + recipeRowGap
local recipeSectionGap = 8
local pinButtonWidth = 60
local materialRowHeight = 22 + padding * 2
local materialRowStride = materialRowHeight + padding
local professionRowHeight = 28 + padding * 2
local professionRowStride = professionRowHeight + padding
local professionListTop = 16 + padding * 2
local controlHeight = 16 + padding * 2
local craftProgressHeight = 28
local craftIdentityHeight = 28
local craftingPanelHeight = craftIdentityHeight + craftProgressHeight + padding * 2
local vendorColumn = 214
local auctionColumn = 302
local skillAtlases = {[0] = "Professions-Icon-Skill-High", [1] = "Professions-Icon-Skill-Medium", [2] = "Professions-Icon-Skill-Low"}
local colors = {
    panel = {0.65, 0.60, 0.51, 1}, inset = {0.34, 0.31, 0.27, 1},
    selected = {0.055, 0.055, 0.055, 1},
    border = {0.56, 0.51, 0.40, 1}, text = {1, 0.97, 0.90},
    muted = {0.74, 0.70, 0.61}, accent = {1, 0.82, 0}, error = {1, 0.35, 0.30},
    materialsAvailable = {0.49, 0.85, 0.47}, materialsMissing = {1, 0.38, 0.32},
}
local panelBackdrop = {
    bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 64, edgeSize = 12,
    insets = {left = 3, right = 3, top = 3, bottom = 3},
}
local selectedPanelBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = panelBackdrop.edgeFile, edgeSize = panelBackdrop.edgeSize,
    insets = panelBackdrop.insets,
}

local function Panel(parent, width, height, x, y, color, backdrop)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    frame:SetBackdrop(backdrop or panelBackdrop)
    frame:SetBackdropColor(unpack(color or colors.panel))
    frame:SetBackdropBorderColor(unpack(colors.border))
    return frame
end

local function Text(parent, value, width, x, y, size, color)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, size or 13, "")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetTextColor(unpack(color or colors.text))
    text:SetText(value or "")
    return text
end

local function Hint(frame, title, body)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(body, 0.8, 0.85, 0.9, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Button(parent, label, width, height, x, y, callback, style)
    local isRow = style == "row"
    local isQuantity = style == "quantity"
    local template = isRow and "BackdropTemplate" or (isQuantity and "UIPanelSquareButton,BackdropTemplate" or "UIPanelButtonTemplate,BackdropTemplate")
    local button = CreateFrame("Button", nil, parent, template)
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    if isRow then
        button:SetBackdrop(panelBackdrop)
        button:SetBackdropColor(unpack(colors.inset))
        button:SetBackdropBorderColor(unpack(colors.border))
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button.label = Text(button, label, width - 12, 6, (height - 14) / 2, 13)
        button.label:SetJustifyH("CENTER")
    elseif isQuantity then
        -- Square artwork keeps its proportions; the ordinary red button uses
        -- wide-button textures that look squeezed at this width.
        button.icon:Hide()
        button.label = Text(button, label, 24, 0, 0, 18, colors.accent)
        button.label:ClearAllPoints()
        button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.label:SetHeight(22)
        button.label:SetJustifyH("CENTER")
        button.label:SetWordWrap(false)
    else
        -- Retain Blizzard's red button art, pressed/disabled states and font behavior.
        button:SetText(label)
        button.label = button:GetFontString()
        button:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
        button:SetBackdropBorderColor(1, 0.82, 0, 0)
    end
    button:SetScript("OnClick", callback)
    function button:Active(active)
        if isRow then
            self:SetBackdrop(active and selectedPanelBackdrop or panelBackdrop)
            self:SetBackdropBorderColor(unpack(active and colors.accent or colors.border))
            self:SetBackdropColor(unpack(active and colors.selected or colors.inset))
            self.label:SetTextColor(unpack(active and colors.accent or colors.text))
        else
            self:SetBackdropBorderColor(1, 0.82, 0, active and 1 or 0)
            self.label:SetTextColor(unpack(colors.accent))
        end
    end
    function button:Available(available)
        self:SetEnabled(available)
        self:SetAlpha(available and 1 or 0.4)
    end
    return button
end

local function CreateTabConnector(button)
    -- Cover the tab's right edge and the adjacent content panel's left border.
    local connector = CreateFrame("Frame", nil, button, "BackdropTemplate")
    connector:SetSize(12, button:GetHeight() - 6)
    connector:SetPoint("TOPRIGHT", button, "TOPRIGHT", 6, -3)
    connector:SetBackdrop({bgFile = selectedPanelBackdrop.bgFile})
    connector:SetBackdropColor(unpack(colors.selected))
    connector:Hide()
    return connector
end

local function Edit(parent, width, height, x, y, inset)
    inset = inset or padding
    local background = Panel(parent, width, height, x, y, colors.inset)
    local edit = CreateFrame("EditBox", nil, background)
    edit:SetPoint("TOPLEFT", inset, -inset)
    edit:SetPoint("BOTTOMRIGHT", -inset, inset)
    edit:SetFontObject("GameFontHighlight")
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit.background = background
    return edit
end

local function Place(frame, parent, x, y)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
end

local function CenterText(text, parent, x, verticalOffset)
    text:ClearAllPoints()
    text:SetPoint("LEFT", parent, "LEFT", x, verticalOffset or 0)
    text:SetHeight(16)
end

local function SkillEstimate(recipe)
    return tostring(math.floor(recipe.skillEstimate))
end

local function CreateCraftWheel(parent)
    local wheel = CreateFrame("Frame", nil, parent)
    wheel:SetSize(30, 30)
    wheel:EnableMouse(false)
    wheel.artwork = wheel:CreateTexture(nil, "OVERLAY")
    wheel.artwork:SetSize(wheel:GetWidth(), wheel:GetHeight())
    wheel.artwork:SetPoint("CENTER", wheel, "CENTER", 0, 0)
    wheel.artwork:SetTexture("Interface\\AddOns\\ProfessionKit\\CraftWheel.tga", nil, nil, "TRILINEAR")
    wheel:Hide()
    return wheel
end

local function PaintCraftWheel(progress)
    local wheel = UI.craftWheel
    if not wheel:IsShown() then return end
    -- With no duration, rotate a short arc to show activity without estimating completion.
    local frame
    if progress then
        frame = math.floor(progress * (craftWheelFramesPerMode - 1))
    else
        frame = craftWheelFramesPerMode + math.floor(GetTime() * 40) % craftWheelFramesPerMode
    end
    if wheel.frameIndex == frame then return end
    wheel.frameIndex = frame
    local column, row = frame % 16, math.floor(frame / 16)
    wheel.artwork:SetTexCoord(column / 16, (column + 1) / 16, row / 8, (row + 1) / 8)
end

local function ShowLinkTooltip(frame)
    if not frame.tooltipLink then return end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(frame.tooltipLink)
    GameTooltip:Show()
end

local function HideLinkTooltip(frame)
    if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
end

local function SetTooltipLink(frame, link)
    frame:SetScript("OnEnter", ShowLinkTooltip)
    frame:SetScript("OnLeave", HideLinkTooltip)
    if frame.tooltipLink == link then return end
    frame.tooltipLink = link
    if GameTooltip:IsOwned(frame) then
        if link then ShowLinkTooltip(frame) else GameTooltip:Hide() end
    end
end

local function CreateRecipeButton(index)
    local button = Button(UI.recipeListContent, "", recipeTileWidth, recipeRowHeight, padding, padding + (index - 1) * recipeRowStride, function(self)
        addon.state.selected = self.recipe.id
        UI.RefreshList()
    end, "row")
    button.label:Hide()
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(22, 22)
    button.icon:SetPoint("LEFT", recipeHorizontalPadding, 10)
    button.skillIcon = button:CreateTexture(nil, "ARTWORK")
    button.count = Text(button, "", 40, 0, 0, 12)
    button.name = Text(button, "", 250, 0, 0, 12)
    button.skillEstimate = Text(button, "", 100, 0, 0, 11, colors.muted)
    button.prices = Text(button, "", 200, 0, 0, 11, colors.muted)
    button.prices:SetJustifyH("RIGHT")
    button.count:SetWordWrap(false)
    button.name:SetWordWrap(false)
    button.skillEstimate:SetWordWrap(false)
    button.prices:SetWordWrap(false)
    button.connector = CreateTabConnector(button)
    UI.recipeButtons[index] = button
end

function UI.Build()
    if UI.frame then return end
    local frame = CreateFrame("Frame", "ProfessionKitFrame", UIParent, "BasicFrameTemplate")
    UI.frame = frame
    frame:Hide()
    frame:SetSize(windowWidth, 500)
    frame:SetPoint("CENTER")
    frame:SetScale(math.min(1, (UIParent:GetWidth() - 40) / windowWidth, (UIParent:GetHeight() - 60) / 500))
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    local function SavePosition()
        local point, _, relativePoint, x, y = frame:GetPoint()
        ProfessionKitDB.position = {point, relativePoint, x, y}
    end
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame.TitleText:SetText("ProfessionKit")
    SetTextureWithAddressModeOptions(frame.Bg, "Profession-Background-Overview")
    frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
    if ProfessionKitDB.position then
        local position = ProfessionKitDB.position
        frame:ClearAllPoints()
        frame:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    end
    tinsert(UISpecialFrames, "ProfessionKitFrame")
    UI.native = Button(frame, "Original window", 132, 22, windowWidth - 168, 2, function() addon.Native() end)

    UI.workspace = Panel(frame, workspaceWidth, 450, navigationWidth + padding, workspaceTop, colors.selected, selectedPanelBackdrop)
    UI.navigation = Panel(frame, navigationWidth, 450, padding, workspaceTop)
    Text(UI.navigation, "Professions", navigationWidth - padding * 2, padding, padding, 13, colors.accent)
    UI.professionButtons = {}
    for index = 1, 7 do
        local button = Button(UI.navigation, "", navigationWidth - padding * 2, professionRowHeight, padding, professionListTop + (index - 1) * professionRowStride, function(self) addon.Open(self.profession.id) end, "row")
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(24, 24)
        button.icon:SetPoint("LEFT", padding, 0)
        button.label:ClearAllPoints()
        button.label:SetPoint("TOPLEFT", 48, -padding)
        button.label:SetWidth(navigationWidth - padding * 3 - 48)
        button.label:SetWordWrap(false)
        button.label:SetJustifyH("LEFT")
        button.rank = Text(button, "", navigationWidth - padding * 3 - 48, 48, padding + 18, 10, colors.muted)
        button.connector = CreateTabConnector(button)
        button.station = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.station:SetSize(20, 20)
        button.station:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -padding, 5)
        button.station:SetBackdrop({edgeFile = panelBackdrop.edgeFile, edgeSize = 8})
        button.station:EnableMouse(true)
        button.station.icon = button.station:CreateTexture(nil, "ARTWORK")
        button.station.icon:SetSize(16, 16)
        button.station.icon:SetPoint("CENTER", button.station, "CENTER", 0, 0)
        button.station:Hide()
        UI.professionButtons[index] = button
    end
    UI.title = Text(UI.workspace, "Choose a profession", recipeListWidth - 110, padding, padding, 21, colors.accent)
    UI.rank = Text(UI.workspace, "", 98, recipeListWidth - 86, padding + 4, 13, colors.accent)
    UI.rank:SetJustifyH("RIGHT")
    UI.search = Edit(UI.workspace, recipeListWidth, 28, padding, 44, 6)
    UI.searchPlaceholder = Text(UI.search.background, "Search recipes", recipeListWidth - 12, 6, 6, 11, colors.muted)
    UI.search:SetScript("OnTextChanged", function(self)
        addon.state.query = self:GetText()
        UI.searchPlaceholder:SetShown(self:GetText() == "")
        UI.recipeScrollOffset = 0
        UI.RefreshList()
    end)
    Text(UI.workspace, "Sort", 28, padding, 91, 11, colors.muted)
    UI.skillSort = Button(UI.workspace, "Skill-ups", 78, 28, 44, 84, function() addon.state.sort = "skill"; UI.recipeScrollOffset = 0; UI.RefreshList() end, "row")
    UI.priceSort = Button(UI.workspace, "Prices", 62, 28, 128, 84, function() addon.state.sort = "auction"; UI.recipeScrollOffset = 0; UI.RefreshList() end, "row")
    Hint(UI.skillSort, "Estimated skill-ups", "Ranks one craft, or all available crafts when × Quantity is checked. Ranking weights: orange 1, yellow 0.5, green 0.2 per craft. These are estimates, not measured probabilities. Capped by your trained skill limit and the recipe's gray threshold when known. Row estimates always show the total from your available materials.")
    Hint(UI.priceSort, "Auction value", "Ranks the outputs of one craft, or all available crafts when × Quantity is checked. Uses minimum output for variable yields. This is gross listing value, not profit or guaranteed sales. Row totals always use your available materials; each is per output item. Missing prices sort last.")
    UI.multiplyByQuantity = CreateFrame("CheckButton", nil, UI.workspace, "UICheckButtonTemplate")
    UI.multiplyByQuantity:SetSize(24, 24)
    UI.multiplyByQuantity:SetPoint("TOPLEFT", 208, -86)
    UI.multiplyByQuantity:SetHitRectInsets(0, -108, 0, 0)
    Text(UI.workspace, "× Quantity", 108, 234, 91, 11)
    UI.multiplyByQuantity:SetScript("OnClick", function(self)
        addon.state.multiplyByQuantity = self:GetChecked()
        UI.recipeScrollOffset = 0
        UI.RefreshList()
    end)
    Hint(UI.multiplyByQuantity, "Multiply ranking by quantity", "Checked: rank the full batch your materials can supply. Unchecked: rank one craft, including all items it produces. All learned recipes stay visible. Tied scores still sort by available quantity. Counts and row totals continue to describe your available materials.")
    UI.list = Panel(UI.workspace, recipeListWidth, 490, padding, recipeListTop, colors.inset)
    UI.list:EnableMouseWheel(true)
    UI.list:SetScript("OnMouseWheel", function(_, delta)
        UI.recipeScrollOffset = (UI.recipeScrollOffset or 0) - delta * 2 * recipeRowStride
        UI.LayoutWindow()
    end)
    UI.recipeViewport = CreateFrame("Frame", nil, UI.list)
    UI.recipeViewport:SetPoint("TOPLEFT", UI.list, "TOPLEFT", 0, -padding)
    -- Clip vertically while leaving room for the selected tab to meet the detail panel.
    UI.recipeViewport:SetWidth(recipeListWidth + padding + 6)
    UI.recipeViewport:SetClipsChildren(true)
    UI.recipeListContent = CreateFrame("Frame", nil, UI.recipeViewport)
    UI.recipeListContent:SetAllPoints(UI.recipeViewport)
    UI.recipeButtons = {}
    UI.recipeHeadings = {}
    for _, section in ipairs({"Pinned", "Recipes", "Camping"}) do
        UI.recipeHeadings[section] = Text(UI.recipeListContent, section, recipeListWidth - padding * 2, padding, padding, 13, colors.accent)
    end
    for index = 1, defaultMaximumVisibleRecipes do CreateRecipeButton(index) end
    UI.craftWheel = CreateCraftWheel(UI.list)
    UI.listEmpty = Text(UI.list, "Open a profession to load recipes.", recipeListWidth - 32, 16, 16, 13, colors.muted)
    UI.listCount = Text(UI.workspace, "", recipeListWidth, 14, 620, 10, colors.muted)
    UI.detail = Panel(UI.workspace, detailWidth, 366, recipeListWidth + padding * 2, padding, colors.selected, selectedPanelBackdrop)
    UI.outputIcon = UI.detail:CreateTexture(nil, "ARTWORK")
    UI.outputIcon:SetSize(38, 38)
    UI.outputIcon:SetPoint("TOPLEFT", 12, -12)
    UI.recipeTitle = Text(UI.detail, "Select a recipe", auctionColumn - 62 - padding, 62, 12, 19, colors.accent)
    UI.recipeTitle:SetWordWrap(false)
    UI.recipeCategory = Text(UI.detail, "", auctionColumn - 62 - padding, 62, 38, 11, colors.muted)
    UI.recipeCategory:SetWordWrap(false)
    UI.market = Text(UI.detail, "", detailWidth - auctionColumn - padding, auctionColumn, 14, 11, colors.muted)
    UI.market:SetJustifyH("RIGHT")
    UI.pinRecipe = Button(UI.detail, "Pin", pinButtonWidth, 20, detailWidth - padding - pinButtonWidth, 40, function()
        local recipe = UI.selectedRecipe
        if not recipe then return end
        local pinnedRecipes = ProfessionKitDB.pinnedRecipes
        if pinnedRecipes[recipe.id] then pinnedRecipes[recipe.id] = nil else pinnedRecipes[recipe.id] = true end
        UI.RefreshList(true)
    end)
    Text(UI.detail, "Materials · owned / needed", vendorColumn - padding * 2, padding, 62, 11, colors.muted)
    Text(UI.detail, "Vendor buy", 76, vendorColumn, 62, 11, colors.muted)
    Text(UI.detail, "Auction", 80, auctionColumn, 62, 11, colors.muted)
    UI.materialScroll = CreateFrame("ScrollFrame", nil, UI.detail, "UIPanelScrollFrameTemplate")
    UI.materialScroll:SetSize(detailWidth - padding * 2, materialRowHeight)
    UI.materialScroll:SetPoint("TOPLEFT", 12, -materialsTop)
    UI.materialContent = CreateFrame("Frame", nil, UI.materialScroll)
    UI.materialContent:SetSize(detailWidth - padding * 2, materialRowHeight)
    UI.materialScroll:SetScrollChild(UI.materialContent)
    UI.materialRows = {}
    UI.conversionArrow = CreateFrame("Frame", nil, UI.detail)
    UI.conversionArrow:SetSize(36, 36)
    local arrow = UI.conversionArrow:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(34, 34)
    arrow:SetPoint("CENTER", UI.conversionArrow, "CENTER", 0, 0)
    arrow:SetTexture("Interface\\MINIMAP\\MiniMap-QuestArrow")
    -- Trim transparent margins so the gold arrow fills the existing connector space.
    arrow:SetTexCoord(4 / 32, 27 / 32, 4 / 32, 27 / 32)
    arrow:SetRotation(math.pi)
    UI.requirements = Text(UI.detail, "", detailWidth - padding * 2, padding, 248, 13, colors.error)
    UI.outputHeading = Text(UI.detail, "Output · per craft", vendorColumn - padding * 2, padding, 152, 11, colors.muted)
    UI.vendorHeading = Text(UI.detail, "Vendor sell", 76, vendorColumn, 152, 11, colors.muted)
    UI.auctionHeading = Text(UI.detail, "Auction", 80, auctionColumn, 152, 11, colors.muted)
    UI.outputRow = UI.MakeItemRow(UI.detail, 12, 168)
    UI.targetPanel = Panel(UI.detail, detailWidth - padding * 2, 74, padding, 168)
    UI.targetSlot = Button(UI.targetPanel, "", 46, 46, 8, 8, function(_, mouseButton)
        if addon.state.crafting or InCombatLockdown() then return end
        if mouseButton == "RightButton" then addon.Targets.Clear()
        elseif C_Cursor and C_Cursor.GetCursorItem and C_Cursor.GetCursorItem() then addon.Targets.Drop(UI.selectedRecipe)
        else OpenAllBags() end
        UI.Detail(UI.selectedRecipe)
    end, "row")
    UI.targetSlot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    UI.targetSlot:SetScript("OnReceiveDrag", function()
        addon.Targets.Drop(UI.selectedRecipe)
        UI.Detail(UI.selectedRecipe)
    end)
    UI.targetIcon = UI.targetSlot:CreateTexture(nil, "ARTWORK")
    UI.targetIcon:SetSize(38, 38)
    UI.targetIcon:SetPoint("CENTER", UI.targetSlot, "CENTER", 0, 0)
    UI.targetName = Text(UI.targetPanel, "", detailWidth - 96, 62, 10, 12, colors.text)
    UI.targetName:SetWordWrap(false)
    UI.targetHint = Text(UI.targetPanel, "Click slot to open bags.\nDrag an item here.", 196, 62, 32, 10, colors.muted)
    UI.equipped = Button(UI.targetPanel, "Equipped…", 88, 26, detailWidth - padding * 3 - 88, 40, function() UI.ToggleEquippedPicker() end)
    UI.enchantEffect = Text(UI.detail, "", detailWidth - padding * 2, padding, 250, 12, colors.text)
    UI.targetPanel:Hide()
    UI.enchantEffect:Hide()
    UI.createAll = Button(UI.detail, "Create all", 120, controlHeight, padding, 248, function() addon.Craft(true) end)
    UI.create = Button(UI.detail, "Create", 82, controlHeight, 144, 248, function() addon.Craft(false) end)
    UI.minus = Button(UI.detail, "−", controlHeight, controlHeight, 238, 248, function() UI.SetQuantity((tonumber(UI.quantity:GetText()) or 1) - 1) end, "quantity")
    UI.quantity = Edit(UI.detail, 52, controlHeight, 290, 248, 6)
    UI.quantity:SetNumeric(true)
    UI.quantity:SetMaxLetters(5)
    UI.quantity:SetText("1")
    UI.quantity:SetScript("OnTextChanged", function() addon.state.craftFailure = nil; UI.RefreshCraftButtons() end)
    UI.plus = Button(UI.detail, "+", controlHeight, controlHeight, 354, 248, function() UI.SetQuantity((tonumber(UI.quantity:GetText()) or 1) + 1) end, "quantity")
    UI.recipeStatus = Text(UI.detail, "", detailWidth - padding * 2, padding, 286, 11, colors.muted)
    UI.craftingPanel = Panel(UI.workspace, detailWidth, craftingPanelHeight, 0, 0)
    UI.craftingPanel:SetBackdropBorderColor(unpack(colors.accent))
    UI.craftingPanel:ClearAllPoints()
    UI.craftingPanel:SetPoint("BOTTOMRIGHT", UI.workspace, "BOTTOMRIGHT", -padding, padding)
    UI.craftingPanel:Hide()
    UI.craftIcon = UI.craftingPanel:CreateTexture(nil, "ARTWORK")
    UI.craftIcon:SetSize(22, 22)
    UI.craftIcon:SetPoint("TOPLEFT", padding, -padding)
    UI.craftName = Text(UI.craftingPanel, "", detailWidth - padding * 2 - 28, padding + 28, padding + 4, 12, colors.accent)
    UI.craftName:SetWordWrap(false)
    UI.craftStatus = Text(UI.craftingPanel, "", detailWidth - padding * 2, padding, padding, 11, colors.text)
    UI.craftProgress = CreateFrame("StatusBar", nil, UI.craftingPanel, "BackdropTemplate")
    UI.craftProgress:SetSize(116, craftProgressHeight)
    UI.craftProgress:SetBackdrop(panelBackdrop)
    UI.craftProgress:SetBackdropColor(0.08, 0.06, 0.03, 1)
    UI.craftProgress:SetBackdropBorderColor(unpack(colors.border))
    UI.craftProgress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    UI.craftProgress:SetStatusBarColor(1, 0.72, 0.12)
    UI.craftProgress:SetMinMaxValues(0, 1)
    UI.craftProgress:SetValue(0)
    UI.craftRemaining = Text(UI.craftProgress, "", 104, 0, 0, 11, {1, 1, 1})
    UI.craftRemaining:ClearAllPoints()
    UI.craftRemaining:SetPoint("CENTER", UI.craftProgress, "CENTER", 0, 0)
    UI.craftRemaining:SetHeight(14)
    UI.craftRemaining:SetJustifyH("CENTER")
    UI.craftRemaining:SetWordWrap(false)
    UI.craftRemaining:SetShadowColor(0, 0, 0, 1)
    UI.craftRemaining:SetShadowOffset(1, -1)
    UI.craftProgress:Hide()
    UI.craftingPanel:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.05 then return end
        self.elapsed = 0
        UI.RefreshCraftProgress()
    end)
    Hint(UI.craftProgress, "Batch progress", "Estimated progress through the entire batch, including the current craft. Uses the same live cast timing as the remaining-time estimate.")
    local grip = CreateFrame("Button", nil, frame)
    UI.heightGrip = grip
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    Hint(grip, "Resize height", "Drag up or down to change the window height.")
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function()
        UI.resizeStartHeight = frame:GetHeight()
        frame:StartSizing("BOTTOM")
    end)
    local function FinishResize()
        if not UI.resizeStartHeight then return end
        frame:StopMovingOrSizing()
        local height = math.floor(frame:GetHeight() + 0.5)
        if height ~= math.floor(UI.resizeStartHeight + 0.5) then
            ProfessionKitDB.windowHeight = height
            SavePosition()
        end
        UI.resizeStartHeight = nil
        UI.LayoutWindow()
    end
    grip:SetScript("OnDragStop", FinishResize)
    frame:HookScript("OnSizeChanged", function()
        if UI.resizeStartHeight then UI.LayoutWindow() end
    end)
    frame:SetScript("OnHide", function()
        FinishResize()
        addon.Closed()
    end)
end

function UI.MakeItemRow(parent, x, y)
    local row = Panel(parent, detailWidth - padding * 2, materialRowHeight, x, y, colors.inset)
    row:EnableMouse(true)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", padding, 0)
    row.name = Text(row, "", vendorColumn - 70, 46, padding, 11)
    row.name:SetWordWrap(false)
    row.vendor = Text(row, "", 76, vendorColumn - padding, padding, 11)
    row.auction = Text(row, "", 80, auctionColumn - padding, padding, 11)
    CenterText(row.name, row, 46)
    CenterText(row.vendor, row, vendorColumn - padding)
    CenterText(row.auction, row, auctionColumn - padding)
    row.vendor:SetWordWrap(false)
    row.auction:SetWordWrap(false)
    return row
end

function UI.SetQuantity(value)
    UI.quantity:SetText(tostring(math.max(1, math.floor(value))))
end

function UI.ToggleSettings()
    if not UI.settings then
        local frame = CreateFrame("Frame", "ProfessionKitSettingsFrame", UIParent, "BasicFrameTemplate")
        UI.settings = frame
        frame:Hide()
        frame:SetSize(356, 132)
        frame:SetPoint("TOPRIGHT", addon.launcher, "BOTTOMLEFT", -padding, -padding)
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame.TitleText:SetText("ProfessionKit settings")
        SetTextureWithAddressModeOptions(frame.Bg, "Profession-Background-Overview")
        frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
        tinsert(UISpecialFrames, "ProfessionKitSettingsFrame")

        local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        UI.replaceNativeCheckbox = checkbox
        checkbox:SetSize(26, 26)
        checkbox:SetPoint("TOPLEFT", padding, -40)
        checkbox:SetHitRectInsets(0, -300, 0, 0)
        local label = Text(frame, "Replace the normal professions window", 300, 44, 45, 12)
        label:SetWordWrap(false)
        checkbox:SetScript("OnClick", function(self)
            ProfessionKitDB.replaceNative = self:GetChecked() and true or false
        end)
        Text(frame, "Applies the next time you open a profession.\nLeft-click the minimap icon to open ProfessionKit anytime.", 332, padding, 78, 11, colors.muted)
    end
    UI.replaceNativeCheckbox:SetChecked(ProfessionKitDB.replaceNative)
    UI.settings:SetShown(not UI.settings:IsShown())
end

local function MaximumWindowHeight()
    local widthScale = math.min(1, (UIParent:GetWidth() - 40) / windowWidth)
    return (UIParent:GetHeight() - 60) / widthScale
end

local function PreferredWindowHeight()
    if UI.resizeStartHeight then return UI.frame:GetHeight() end
    return ProfessionKitDB.windowHeight
end

function UI.LayoutWindow()
    local navigationBottom = professionListTop + (UI.professionCount or 0) * professionRowStride
    local craftingHeight = addon.state.craftRequest and craftingPanelHeight + padding or 0
    local minimumHeight = workspaceTop + padding + math.max(210, UI.detailContentHeight + padding * 2 + craftingHeight, navigationBottom)
    local maximumHeight = math.max(minimumHeight, MaximumWindowHeight())
    if UI.minimumWindowHeight ~= minimumHeight or UI.maximumWindowHeight ~= maximumHeight then
        UI.minimumWindowHeight, UI.maximumWindowHeight = minimumHeight, maximumHeight
        UI.frame:SetResizeBounds(windowWidth, minimumHeight, windowWidth, maximumHeight)
    end
    local contentHeight = UI.recipeContentHeight
    local automaticListHeight = math.min(contentHeight, padding * 2 + defaultMaximumVisibleRecipes * recipeRowStride - recipeRowGap + UI.recipeHeadingSpace)
    local automaticHeight = workspaceTop + padding + recipeListTop + automaticListHeight + padding
    local windowHeight = math.max(minimumHeight, math.min(PreferredWindowHeight() or automaticHeight, maximumHeight))
    local workspaceHeight = windowHeight - workspaceTop - padding
    local availableListHeight = workspaceHeight - recipeListTop - padding
    local canScroll = contentHeight > availableListHeight
    local listHeight = canScroll and availableListHeight - 14 - padding or contentHeight
    UI.list:SetHeight(listHeight)
    UI.recipeViewport:SetHeight(listHeight - padding * 2)
    Place(UI.listCount, UI.workspace, padding, recipeListTop + listHeight + padding)
    UI.listCount:SetShown(canScroll)
    local maximumDetailHeight = workspaceHeight - padding * 2 - craftingHeight
    UI.RenderRecipeRows(maximumDetailHeight)
    UI.detail:SetHeight(math.max(UI.detailContentHeight, UI.selectedRecipeBottom or 0))
    UI.workspace:SetHeight(workspaceHeight)
    UI.navigation:SetHeight(workspaceHeight)
    if not UI.resizeStartHeight then UI.frame:SetHeight(windowHeight) end
    UI.frame:SetScale(math.min(1, (UIParent:GetWidth() - 40) / windowWidth, (UIParent:GetHeight() - 60) / windowHeight))
    UI.RefreshCraftPanel()
end

function UI.Layout(recipe, statusPadding)
    local reagentCount = recipe and #recipe.reagents or 0
    local materialGap = materialRowStride - materialRowHeight
    local contentHeight = math.max(materialRowHeight, reagentCount * materialRowStride - materialGap)
    local materialsHeight = math.min(contentHeight, materialRowStride * 4 - materialGap)
    local materialWidth = detailWidth - padding * 2 - (contentHeight > materialsHeight and padding * 2 or 0)
    UI.materialScroll:SetWidth(materialWidth)
    UI.materialContent:SetWidth(materialWidth)
    for _, row in ipairs(UI.materialRows) do
        row:SetWidth(materialWidth)
        row.auction:SetWidth(materialWidth - (auctionColumn - padding) - padding)
    end
    UI.materialScroll:SetHeight(materialsHeight)
    UI.materialContent:SetHeight(contentHeight)
    if UI.materialScroll.ScrollBar then UI.materialScroll.ScrollBar:SetShown(contentHeight > materialsHeight) end

    local arrowTop = materialsTop + materialsHeight + padding
    Place(UI.conversionArrow, UI.detail, (detailWidth - UI.conversionArrow:GetWidth()) / 2, arrowTop)
    local outputHeadingTop = arrowTop + UI.conversionArrow:GetHeight() + padding
    Place(UI.outputHeading, UI.detail, padding, outputHeadingTop)
    Place(UI.vendorHeading, UI.detail, vendorColumn, outputHeadingTop)
    Place(UI.auctionHeading, UI.detail, auctionColumn, outputHeadingTop)
    Place(UI.outputRow, UI.detail, padding, outputHeadingTop + 14 + padding)
    Place(UI.targetPanel, UI.detail, padding, outputHeadingTop + 14 + padding)
    local hasAge = recipe and recipe.auction and recipe.age ~= nil
    UI.market:SetShown(not not hasAge)
    local controlsTop = outputHeadingTop + 14 + padding + materialRowHeight + padding
    if recipe and recipe.isEnchant then
        local effectTop = outputHeadingTop + 14 + padding + UI.targetPanel:GetHeight() + padding
        Place(UI.enchantEffect, UI.detail, padding, effectTop)
        local effectHeight = math.min(84, math.max(28, UI.enchantEffect:GetStringHeight()))
        UI.enchantEffect:SetHeight(effectHeight)
        controlsTop = effectTop + effectHeight + padding
    end
    Place(UI.createAll, UI.detail, padding, controlsTop)
    Place(UI.create, UI.detail, recipe and not recipe.canCreateMultiple and padding or 144, controlsTop)
    Place(UI.minus, UI.detail, 238, controlsTop)
    Place(UI.quantity.background, UI.detail, 290, controlsTop)
    Place(UI.plus, UI.detail, 354, controlsTop)
    Place(UI.requirements, UI.detail, padding, controlsTop + padding)
    local statusTop = controlsTop + controlHeight + statusPadding
    Place(UI.recipeStatus, UI.detail, padding, statusTop)
    local detailHeight = statusTop
    if UI.recipeStatus:GetText() ~= "" then
        detailHeight = detailHeight + math.max(14, UI.recipeStatus:GetStringHeight()) + statusPadding
    end
    UI.detailContentHeight = detailHeight
    UI.LayoutWindow()
end

local function CraftStatus(request)
    if not request.started then return request.isEnchant and addon.Targets.ConfirmationVisible() and "Confirm the enchant in WoW's dialog." or "Starting craft…", nil end
    local status = "Crafting " .. (request.count - request.remaining + 1) .. "/" .. request.count
    local totalSeconds, remainingSeconds = Model.BatchTiming(request, GetTime())
    if totalSeconds and totalSeconds > 0 and remainingSeconds then
        status = status .. "\nest. " .. Model.Duration(totalSeconds) .. " total"
        return status, math.max(0, math.min(1, 1 - remainingSeconds / totalSeconds)), Model.Duration(remainingSeconds) .. " left"
    end
    return status, nil
end

function UI.RefreshCraftProgress()
    local request = addon.state.craftRequest
    if not request or not request.started then return end
    local status, progress, remainingText = CraftStatus(request)
    PaintCraftWheel(progress)
    if progress ~= nil then
        UI.craftProgress:SetValue(progress)
        UI.craftStatus:SetText(status)
        UI.craftRemaining:SetText(remainingText)
    end
end

function UI.RefreshCraftPanel()
    local request = addon.state.craftRequest
    local status, progress, remainingText = "", nil, nil
    if request then status, progress, remainingText = CraftStatus(request) end
    local activeButton
    if request and request.started and request.professionID == addon.state.professionID then
        for _, button in ipairs(UI.recipeButtons) do
            if button.recipe and button.recipe.id == request.recipeID then activeButton = button; break end
        end
    end
    local wheel = UI.craftWheel
    if activeButton and wheel:GetParent() ~= activeButton then
        wheel:SetParent(activeButton)
        wheel:ClearAllPoints()
        wheel:SetPoint("CENTER", activeButton.icon, "CENTER", 0, 0)
    end
    wheel:SetShown(activeButton ~= nil)
    PaintCraftWheel(progress)
    UI.craftingPanel:SetShown(request ~= nil)
    UI.craftName:SetText(request and request.recipeName or "")
    UI.craftIcon:SetTexture(request and request.icon or nil)
    UI.craftProgress:SetShown(progress ~= nil)
    UI.craftProgress:SetValue(progress or 0)
    UI.craftRemaining:SetText(remainingText or "")
    UI.craftStatus:SetText(status)

    local progressTop = padding + craftIdentityHeight
    local statusLeft = progress ~= nil and padding + UI.craftProgress:GetWidth() + padding or padding
    Place(UI.craftProgress, UI.craftingPanel, padding, progressTop)
    Place(UI.craftStatus, UI.craftingPanel, statusLeft, progressTop + (progress == nil and 7 or 0))
    UI.craftStatus:SetWidth(detailWidth - statusLeft - padding)
end

function UI.RefreshCraftButtons()
    if not UI.create then return end
    local recipe = UI.selectedRecipe
    local current = addon.Client.OpenInfo()
    local count = recipe and not recipe.canCreateMultiple and 1 or tonumber(UI.quantity:GetText()) or 0
    local valid, reason = Model.CraftAllowed(recipe, count, current and current.professionID, addon.state.professionID, InCombatLockdown())
    if valid then valid, reason = addon.Targets.Validate(recipe) end
    UI.create:Available(valid and not addon.state.crafting)
    UI.create.label:SetText(recipe and recipe.isEnchant and "Enchant" or "Create")
    local batchCount = Model.MaximumCraftCount(recipe)
    local allValid = recipe and recipe.canCreateMultiple and Model.CraftAllowed(recipe, batchCount, current and current.professionID, addon.state.professionID, InCombatLockdown())
    UI.createAll:Available(allValid and not addon.state.crafting)
    UI.createAll.label:SetText("Create all [" .. batchCount .. "]")
    local missing = {}
    for _, requirement in ipairs(recipe and recipe.requirements or {}) do
        if not requirement.met then missing[#missing + 1] = requirement.name end
    end
    local controlsVisible = #missing == 0 and recipe ~= nil and not recipe.unsupported
    UI.create:SetShown(controlsVisible)
    for _, control in ipairs({UI.createAll, UI.minus, UI.quantity.background, UI.plus}) do control:SetShown(controlsVisible and recipe.canCreateMultiple) end
    UI.requirements:SetShown(#missing > 0)
    UI.requirements:SetText(#missing > 0 and ("Requires: " .. table.concat(missing, ", ")) or "")
    if reason and reason:match("^Requires:") then reason = nil end
    local request, failure = addon.state.craftRequest, addon.state.craftFailure
    local failureMessage = failure and recipe and failure.recipeID == recipe.id and failure.message
    local showFailure = failureMessage and #missing == 0
    local status = failureMessage or reason or ""
    if not request and status == "" and recipe and recipe.castSeconds and batchCount > 0 then
        status = (recipe.canCreateMultiple and "Create all: est. " or "Est. ") .. Model.Duration(recipe.castSeconds * batchCount) .. " total"
        if recipe.charges then status = status .. " · " .. recipe.charges .. " charges available" end
    end
    UI.recipeStatus:SetFont(STANDARD_TEXT_FONT, failureMessage and 14 or 11, failureMessage and "OUTLINE" or "")
    UI.recipeStatus:SetTextColor(unpack(failureMessage and colors.error or colors.muted))
    UI.recipeStatus:SetJustifyH(showFailure and "CENTER" or "LEFT")
    UI.recipeStatus:SetText(#missing == 0 and status or "")
    UI.targetSlot:Available(not addon.state.crafting and not InCombatLockdown())
    UI.equipped:Available(not addon.state.crafting and not InCombatLockdown())
    UI.Layout(recipe, showFailure and craftFailurePadding or padding)
end

function UI.RefreshList(revealSelection)
    if not UI.frame then return end
    local state = addon.state
    UI.rows = Model.Select(state.recipes, state.query, state.sort, state.multiplyByQuantity, ProfessionKitDB.pinnedRecipes)
    local showHeadings = #UI.rows > 0 and (UI.rows[1].section ~= "Recipes" or UI.rows[#UI.rows].section ~= "Recipes")
    local rowTop, previousSection = 0, nil
    local selectedIndex
    UI.recipeTops, UI.headingTops, UI.recipeHeadingSpace = {}, {}, 0
    for index, recipe in ipairs(UI.rows) do
        if showHeadings and recipe.section ~= previousSection then
            local gap = previousSection and recipeSectionGap or 0
            UI.headingTops[recipe.section] = rowTop + gap
            rowTop = rowTop + gap + recipeSectionHeight
            UI.recipeHeadingSpace = UI.recipeHeadingSpace + gap + recipeSectionHeight
        end
        previousSection = recipe.section
        UI.recipeTops[index] = rowTop
        rowTop = rowTop + recipeRowStride
        if recipe.id == state.selected then selectedIndex = index end
    end
    UI.recipeContentHeight = #UI.rows > 0 and rowTop - recipeRowGap + padding * 2 or 74
    UI.revealRecipeIndex = revealSelection and selectedIndex or nil
    UI.recipeRowsDirty = true
    UI.skillSort:Active(state.sort == "skill")
    UI.priceSort:Active(state.sort == "auction")
    UI.multiplyByQuantity:SetChecked(state.multiplyByQuantity)
    local selected = UI.rows[selectedIndex or 1]
    state.selected = selected and selected.id or nil
    UI.listEmpty:SetShown(#UI.rows == 0)
    UI.listEmpty:SetText(state.loading and "Loading recipes…" or (#state.recipes == 0 and "No crafting recipes here. Gathering journals are available in the original window." or "No recipes match. Try clearing the search."))
    UI.Detail(selected)
end

function UI.RenderRecipeRows(maximumDetailHeight)
    local height = UI.recipeViewport:GetHeight()
    local offset = UI.recipeScrollOffset or 0
    if UI.revealRecipeIndex then
        local index = UI.revealRecipeIndex
        local top = UI.recipeTops[index]
        local headingTop = UI.headingTops[UI.rows[index].section]
        local revealTop = headingTop and headingTop + recipeSectionHeight == top and headingTop or top
        offset = math.min(revealTop, math.max(offset, top + recipeRowHeight - height))
        UI.revealRecipeIndex = nil
    end
    offset = math.max(0, math.min(offset, UI.recipeContentHeight - padding * 2 - height))
    UI.recipeScrollOffset = offset
    if not UI.recipeRowsDirty and UI.renderedOffset == offset and UI.renderedHeight == height and UI.renderedDetailLimit == maximumDetailHeight then return end
    UI.recipeRowsDirty = false
    UI.renderedOffset, UI.renderedHeight, UI.renderedDetailLimit = offset, height, maximumDetailHeight
    UI.selectedRecipeBottom = nil
    for section, heading in pairs(UI.recipeHeadings) do
        local top = UI.headingTops[section]
        local visible = top and top < offset + height and top + recipeSectionHeight > offset
        heading:SetShown(visible and true or false)
        if visible then Place(heading, UI.list, padding, padding + top - offset) end
    end
    local firstIndex, visibleCount = 1, 0
    for index, top in ipairs(UI.recipeTops) do
        if top >= offset + height then break end
        if top + recipeRowHeight > offset then
            if visibleCount == 0 then firstIndex = index end
            visibleCount = visibleCount + 1
        end
    end
    UI.visibleRecipeCount = visibleCount
    for index = #UI.recipeButtons + 1, visibleCount do CreateRecipeButton(index) end
    for index, button in ipairs(UI.recipeButtons) do
        local rowIndex = firstIndex + index - 1
        local recipe = index <= visibleCount and UI.rows[rowIndex] or nil
        button.recipe = recipe
        local tooltipLink
        if recipe then
            tooltipLink = recipe.outputLink
            if recipe.isEnchant or not tooltipLink then tooltipLink = "spell:" .. recipe.id end
        end
        SetTooltipLink(button, tooltipLink)
        button:SetShown(recipe ~= nil)
        if recipe then
            local top = UI.recipeTops[rowIndex] - offset
            Place(button, UI.list, padding, padding + top)
            button:SetHitRectInsets(0, 0, math.max(0, -top), math.max(0, top + recipeRowHeight - height))
            local isSelected = recipe.id == addon.state.selected
            local visibleBottom = recipeListTop + padding + math.min(top + recipeRowHeight, height)
            -- A low row beside an active batch still has its selection outline.
            local connectsToDetail = isSelected and visibleBottom <= maximumDetailHeight
            button:SetWidth(recipeTileWidth + (connectsToDetail and padding * 2 or 0))
            button.connector:SetShown(connectsToDetail)
            if connectsToDetail then UI.selectedRecipeBottom = visibleBottom end
            button.icon:SetTexture(recipe.icon or 134400)
            local atlas = recipe.canSkillUp and skillAtlases[recipe.difficulty]
            button.skillIcon:SetShown(not not atlas)
            if atlas then button.skillIcon:SetAtlas(atlas, true) end
            local contentLeft = recipeHorizontalPadding + button.icon:GetWidth() + 6
            local textOffset = 10
            button.skillIcon:ClearAllPoints()
            button.skillIcon:SetPoint("LEFT", button, "LEFT", contentLeft, textOffset)
            local countLeft = contentLeft + (atlas and button.skillIcon:GetWidth() + 4 or 0)
            local difficulty = Model.Difficulty(recipe)
            button.count:SetText("[" .. recipe.available .. "]")
            button.count:SetTextColor(unpack(recipe.available > 0 and colors.materialsAvailable or colors.materialsMissing))
            -- Measure the full text, not the previously constrained rendered width.
            -- Round up and leave a small allowance so brackets never become ellipses.
            local countWidth = math.ceil(button.count:GetUnboundedStringWidth()) + 2
            button.count:SetWidth(countWidth)
            CenterText(button.count, button, countLeft, textOffset)
            local nameLeft = countLeft + countWidth + 4
            CenterText(button.name, button, nameLeft, textOffset)
            button.name:SetWidth(recipeTileWidth - nameLeft - recipeHorizontalPadding)
            button.name:SetText(recipe.name)
            button.skillEstimate:SetText("est. " .. SkillEstimate(recipe) .. " skillups")
            button.skillEstimate:SetWidth(math.ceil(button.skillEstimate:GetUnboundedStringWidth()) + 2)
            CenterText(button.skillEstimate, button, recipeHorizontalPadding, -10)
            local pricesLeft = recipeHorizontalPadding + button.skillEstimate:GetWidth() + padding
            button.prices:SetText(Model.Money(recipe.batchPrice) .. " total / " .. Model.Money(recipe.auction) .. " each")
            button.prices:SetWidth(recipeTileWidth - pricesLeft - recipeHorizontalPadding)
            CenterText(button.prices, button, pricesLeft, -10)
            button.name:SetTextColor(unpack(difficulty.color))
            button:Active(isSelected)
        end
    end
    UI.listCount:SetText(firstIndex .. "–" .. (firstIndex + visibleCount - 1) .. " of " .. #UI.rows)
end

function UI.Detail(recipe)
    if not UI.selectedRecipe or not recipe or UI.selectedRecipe.id ~= recipe.id then
        UI.materialScroll:SetVerticalScroll(0)
        addon.state.craftFailure = nil
        addon.Targets.message = nil
        if UI.equippedPicker then UI.equippedPicker:Hide() end
    end
    UI.selectedRecipe = recipe
    UI.pinRecipe:SetShown(recipe ~= nil)
    UI.pinRecipe.label:SetText(recipe and ProfessionKitDB.pinnedRecipes[recipe.id] and "Unpin" or "Pin")
    UI.conversionArrow:SetShown(recipe ~= nil)
    UI.recipeTitle:SetText(recipe and recipe.outputName or "Select a recipe")
    UI.recipeCategory:SetText(recipe and recipe.category or "")
    UI.outputIcon:SetTexture(recipe and recipe.icon or 134400)
    for _, row in ipairs(UI.materialRows) do row:Hide() end
    if recipe then
        for index, reagent in ipairs(recipe.reagents) do
            local row = UI.materialRows[index] or UI.MakeItemRow(UI.materialContent, 0, (index - 1) * materialRowStride)
            UI.materialRows[index] = row
            row.icon:SetTexture(reagent.icon or 134400)
            row.name:SetText(reagent.owned .. "/" .. reagent.required .. "  " .. reagent.name)
            row.name:SetTextColor(unpack(reagent.owned >= reagent.required and colors.text or {1, 0.45, 0.4}))
            row.vendor:SetText(Model.Money(reagent.vendorBuy))
            row.auction:SetText(Model.Money(reagent.auction))
            SetTooltipLink(row, reagent.link)
            row:Show()
        end
    end
    local isEnchant = recipe and recipe.isEnchant or false
    UI.recipeTitle:SetWidth(isEnchant and detailWidth - 62 - pinButtonWidth - padding * 2 or auctionColumn - 62 - padding)
    UI.recipeTitle:SetWordWrap(isEnchant)
    UI.recipeTitle:SetHeight(isEnchant and 44 or 24)
    UI.recipeCategory:SetShown(not isEnchant)
    UI.outputHeading:SetText(isEnchant and "Item to enchant" or "Output · per craft")
    UI.vendorHeading:SetShown(not isEnchant)
    UI.auctionHeading:SetShown(not isEnchant)
    UI.targetPanel:SetShown(isEnchant)
    UI.enchantEffect:SetShown(isEnchant)
    UI.outputRow:SetShown(recipe ~= nil and not isEnchant)
    if isEnchant then
        local target = addon.Targets.Selected(recipe)
        UI.targetName:SetText(target and target.name or "Choose an item")
        UI.targetIcon:SetTexture(target and target.icon or "Interface\\Buttons\\UI-EmptySlot-Disabled")
        local description = target and C_Spell.GetSpellDescriptionForItemLocation and C_Spell.GetSpellDescriptionForItemLocation(recipe.id, target.location) or recipe.description
        UI.enchantEffect:SetText(description and description ~= "" and description or recipe.name)
        UI.enchantEffect:SetHeight(0)
        UI.targetSlot:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if target then GameTooltip:SetItemByGUID(target.guid) else GameTooltip:SetText("Item to enchant") end
            GameTooltip:AddLine("Click to open bags. Drag an item here.\nRight-click to clear the target.", 0.8, 0.85, 0.9, true)
            GameTooltip:Show()
        end)
        UI.targetSlot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    elseif recipe then
        local quantity = recipe.outputMin == recipe.outputMax and tostring(recipe.outputMin) or (recipe.outputMin .. "–" .. recipe.outputMax)
        UI.outputRow.icon:SetTexture(recipe.icon or 134400)
        UI.outputRow.name:SetText(quantity .. "  " .. recipe.outputName)
        UI.outputRow.vendor:SetText(Model.Money(recipe.vendorTotal))
        UI.outputRow.auction:SetText(recipe.bound and "Soulbound" or Model.Money(recipe.auctionTotal))
        SetTooltipLink(UI.outputRow, recipe.outputLink)
    end
    local priceAge = ""
    if recipe and recipe.auction and recipe.age ~= nil then
        priceAge = recipe.age == 0 and "AH prices\nSeen today" or ("AH prices\n" .. recipe.age .. (recipe.age == 1 and " day old" or " days old"))
    end
    UI.market:SetText(priceAge)
    UI.RefreshCraftButtons()
end

function UI.ToggleEquippedPicker()
    if addon.state.crafting or InCombatLockdown() then return end
    if UI.equippedPicker and UI.equippedPicker:IsShown() then UI.equippedPicker:Hide(); return end
    if not UI.equippedPicker then
        local frame = Panel(UI.frame, 340, 220, 0, 0)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UI.frame, "CENTER", 0, 0)
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        Text(frame, "Equipped items", 270, padding, padding, 15, colors.accent)
        Button(frame, "×", 26, 26, 302, 6, function() frame:Hide() end, "quantity")
        frame.empty = Text(frame, "No equipped items can receive this enchant.", 300, padding, 48, 12, colors.muted)
        frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -40)
        frame.scroll:SetSize(292, 160)
        frame.content = CreateFrame("Frame", nil, frame.scroll)
        frame.content:SetSize(292, 160)
        frame.scroll:SetScrollChild(frame.content)
        frame.buttons = {}
        UI.equippedPicker = frame
    end
    local frame = UI.equippedPicker
    local recipe = UI.selectedRecipe
    local items = addon.Targets.Eligible(recipe, true)
    for _, button in ipairs(frame.buttons) do button:Hide() end
    for index, item in ipairs(items) do
        local button = frame.buttons[index]
        if not button then
            button = Button(frame.content, "", 292, 42, 0, (index - 1) * 48, function(self)
                if UI.selectedRecipe and UI.selectedRecipe.id == self.recipeID and addon.Targets.Select(UI.selectedRecipe, self.item.guid) then frame:Hide() end
                UI.Detail(UI.selectedRecipe)
            end, "row")
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetSize(28, 28)
            button.icon:SetPoint("LEFT", button, "LEFT", 8, 0)
            button.label:ClearAllPoints()
            button.label:SetPoint("LEFT", button, "LEFT", 44, 0)
            button.label:SetWidth(238)
            button.label:SetJustifyH("LEFT")
            button.label:SetWordWrap(false)
            frame.buttons[index] = button
        end
        button.item, button.recipeID = item, recipe.id
        button.label:SetText(item.name)
        button.icon:SetTexture(item.icon or 134400)
        button:Show()
        SetTooltipLink(button, item.link)
    end
    frame.empty:SetShown(#items == 0)
    frame.scroll:SetShown(#items > 0)
    local contentHeight = math.max(48, #items * 48)
    local visibleHeight = math.min(384, contentHeight)
    frame.content:SetHeight(contentHeight)
    frame.scroll:SetHeight(visibleHeight)
    frame.scroll:SetVerticalScroll(0)
    frame.scroll.ScrollBar:SetShown(contentHeight > visibleHeight)
    frame:SetHeight(40 + visibleHeight + padding)
    frame:Show()
end

function UI.RefreshStations()
    for _, button in ipairs(UI.professionButtons or {}) do
        local status = button:IsShown() and button.profession and addon.Stations.Read(button.profession)
        button.station:SetShown(status ~= nil and status ~= false)
        if status then
            button.station.icon:SetTexture(status.icon)
            button.station.icon:SetDesaturated(not status.nearby)
            button.station.icon:SetAlpha(status.nearby and 1 or 0.4)
            button.station:SetBackdropBorderColor(unpack(status.nearby and {0.3, 1, 0.3, 1} or {0.4, 0.4, 0.4, 0.6}))
            Hint(button.station, "Crafting stations", status.tooltip)
        end
    end
end

function UI.Refresh()
    UI.Build()
    local professions = addon.Client.Professions()
    UI.professionCount = #professions
    for index, button in ipairs(UI.professionButtons) do
        local profession = professions[index]
        button:SetShown(profession ~= nil)
        if profession then
            button.profession = profession
            button.label:SetText(profession.name)
            button.rank:SetText(profession.rank .. " / " .. profession.maximum)
            button.icon:SetTexture(profession.icon)
            button:Active(profession.id == addon.state.professionID)
            button:SetWidth(navigationWidth - (profession.id == addon.state.professionID and padding or padding * 2))
            button.connector:SetShown(profession.id == addon.state.professionID)
            if profession.id == addon.state.professionID then
                UI.title:SetText(profession.name)
                UI.rank:SetText(profession.rank .. " / " .. profession.maximum)
            end
        end
    end
    UI.RefreshStations()
    UI.RefreshList()
end
