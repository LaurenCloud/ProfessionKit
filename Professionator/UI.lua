local _, addon = ...
local Model = addon.Model
addon.UI = {}
local UI = addon.UI
-- Use the same inset on every side; row heights follow their content plus that inset.
local padding = 12
local navigationWidth = 164
local recipeListWidth = 354
local detailWidth = 406
local workspaceWidth = recipeListWidth + detailWidth + padding * 3
local windowWidth = navigationWidth + workspaceWidth + padding * 2
local workspaceTop = 24 + padding
local recipeListTop = 124
local materialsTop = 88
local maximumVisibleRecipes = 12
local recipeRowHeight = 22 + padding * 2
local recipeRowGap = 6
local recipeRowStride = recipeRowHeight + recipeRowGap
local recipeSectionHeight = 14 + recipeRowGap
local materialRowHeight = 22 + padding * 2
local materialRowStride = materialRowHeight + padding
local professionRowHeight = 28 + padding * 2
local professionRowStride = professionRowHeight + padding
local professionListTop = 16 + padding * 2
local controlHeight = 16 + padding * 2
local vendorColumn = 214
local auctionColumn = 302
local skillAtlases = {[0] = "Professions-Icon-Skill-High", [1] = "Professions-Icon-Skill-Medium", [2] = "Professions-Icon-Skill-Low"}
local colors = {
    panel = {0.65, 0.60, 0.51, 1}, inset = {0.34, 0.31, 0.27, 1},
    border = {0.56, 0.51, 0.40, 1}, text = {1, 0.97, 0.90},
    muted = {0.74, 0.70, 0.61}, accent = {1, 0.82, 0},
}
local panelBackdrop = {
    bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 64, edgeSize = 12,
    insets = {left = 3, right = 3, top = 3, bottom = 3},
}

local function Panel(parent, width, height, x, y, color)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    frame:SetBackdrop(panelBackdrop)
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
    local button = CreateFrame("Button", nil, parent, isRow and "BackdropTemplate" or "UIPanelButtonTemplate,BackdropTemplate")
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    if isRow then
        button:SetBackdrop(panelBackdrop)
        button:SetBackdropColor(unpack(colors.inset))
        button:SetBackdropBorderColor(unpack(colors.border))
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button.label = Text(button, label, width - 12, 6, (height - 14) / 2, 13)
        button.label:SetJustifyH("CENTER")
    else
        -- Retain Blizzard's red button art, pressed/disabled states and font behavior.
        button:SetText(label)
        button.label = button:GetFontString()
        if style == "quantity" then
            -- The native text anchors squeeze symbols on narrow buttons. Use a
            -- centered, fixed-size glyph while keeping the native button artwork.
            button:SetText("")
            button.label = Text(button, label, 24, 0, 0, 18, colors.accent)
            button.label:ClearAllPoints()
            button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
            button.label:SetHeight(22)
            button.label:SetJustifyH("CENTER")
            button.label:SetWordWrap(false)
        end
        button:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
        button:SetBackdropBorderColor(1, 0.82, 0, 0)
    end
    button:SetScript("OnClick", callback)
    function button:Active(active)
        if isRow then
            self:SetBackdropBorderColor(unpack(active and colors.accent or colors.border))
            self:SetBackdropColor(unpack(active and colors.panel or colors.inset))
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

local function CenterText(text, parent, x)
    text:ClearAllPoints()
    text:SetPoint("LEFT", parent, "LEFT", x, 0)
    text:SetHeight(16)
end

local function SkillEstimate(recipe)
    return tostring(math.floor(recipe.skillEstimate))
end

local function RecipeTooltip(button)
    button:SetScript("OnEnter", function(self)
        local recipe = self.recipe
        if not recipe then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(recipe.name)
        GameTooltip:AddLine(Model.Difficulty(recipe).label .. " · est. " .. SkillEstimate(recipe) .. " skillups with available materials", 1, 0.82, 0, true)
        GameTooltip:AddLine(recipe.available .. " crafts available. Skillup totals are estimates.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Auction value: " .. Model.Money(recipe.batchPrice) .. " total / " .. Model.Money(recipe.auction) .. " each", 1, 1, 1, true)
        GameTooltip:AddLine("Each is per output item; total uses all available crafts and minimum output quantity.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function ItemTooltip(frame, record)
    frame:SetScript("OnEnter", function(self)
        if not self.record or not self.record.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.record.link)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.record = record
end

function UI.Build()
    if UI.frame then return end
    local frame = CreateFrame("Frame", "ProfessionatorFrame", UIParent, "BasicFrameTemplate")
    UI.frame = frame
    frame:Hide()
    frame:SetSize(windowWidth, 500)
    frame:SetPoint("CENTER")
    frame:SetScale(math.min(1, (UIParent:GetWidth() - 40) / windowWidth, (UIParent:GetHeight() - 60) / 500))
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ProfessionatorDB.position = {point, relativePoint, x, y}
    end)
    frame.TitleText:SetText("Professionator")
    SetTextureWithAddressModeOptions(frame.Bg, "Profession-Background-Overview")
    frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
    if ProfessionatorDB.position then
        local position = ProfessionatorDB.position
        frame:ClearAllPoints()
        frame:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    end
    tinsert(UISpecialFrames, "ProfessionatorFrame")
    UI.native = Button(frame, "Original window", 132, 22, windowWidth - 168, 2, function() addon.Native() end)
    frame:SetScript("OnHide", function() addon.Closed() end)

    UI.workspace = Panel(frame, workspaceWidth, 450, navigationWidth + padding, workspaceTop)
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
        -- The selected vertical tab extends through the shared edge into the content panel.
        -- Its bridge covers both right-hand tab edging and the panel's left border.
        button.connector = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.connector:SetSize(12, professionRowHeight - 6)
        button.connector:SetPoint("TOPRIGHT", button, "TOPRIGHT", 6, -3)
        button.connector:SetBackdrop({bgFile = panelBackdrop.bgFile, tile = true, tileSize = 64})
        button.connector:SetBackdropColor(unpack(colors.panel))
        button.connector:Hide()
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
        UI.offset = 0
        UI.RefreshList()
    end)
    Text(UI.workspace, "Sort", 28, padding, 91, 11, colors.muted)
    UI.skillSort = Button(UI.workspace, "Skill-ups", 78, 28, 44, 84, function() addon.state.sort = "skill"; UI.offset = 0; UI.RefreshList() end, "row")
    UI.priceSort = Button(UI.workspace, "Prices", 62, 28, 128, 84, function() addon.state.sort = "auction"; UI.offset = 0; UI.RefreshList() end, "row")
    Hint(UI.skillSort, "Skill-ups from your materials", "Estimated batch skill gains. Ranking weights: orange 1, yellow 0.5, green 0.2 per craft. These are estimates, not measured probabilities. Capped by your trained skill limit and the recipe's gray threshold when known. Chances decline as you level. Recalculates after crafting.")
    Hint(UI.priceSort, "Auction value of your craftable batch", "Crafts available × items produced × recorded auction price. Uses minimum output for variable yields. This is gross listing value, not profit or guaranteed sales. Missing prices sort last.")
    UI.filter = CreateFrame("CheckButton", nil, UI.workspace, "UICheckButtonTemplate")
    UI.filter:SetSize(24, 24)
    UI.filter:SetPoint("TOPLEFT", 208, -86)
    UI.filter:SetHitRectInsets(0, -132, 0, 0)
    Text(UI.workspace, "Have materials", 132, 234, 91, 11)
    UI.filter:SetScript("OnClick", function(self)
        addon.state.filter = self:GetChecked() and "craftable" or "all"
        UI.offset = 0
        UI.RefreshList()
    end)
    Hint(UI.filter, "Filter: have materials", "Checked: recipes you can make with your materials. Unchecked: all learned recipes.")
    UI.list = Panel(UI.workspace, recipeListWidth, 490, padding, recipeListTop, colors.inset)
    UI.list:EnableMouseWheel(true)
    UI.list:SetScript("OnMouseWheel", function(_, delta)
        UI.offset = math.max(0, math.min(math.max(0, #(UI.rows or {}) - UI.visibleRecipeCount), (UI.offset or 0) - delta * 2))
        UI.RefreshList()
    end)
    UI.recipeButtons = {}
    UI.recipeHeadings = {
        Text(UI.list, "Recipes", recipeListWidth - padding * 2, padding, padding, 11, colors.muted),
        Text(UI.list, "Camping", recipeListWidth - padding * 2, padding, padding, 11, colors.muted),
    }
    for index = 1, maximumVisibleRecipes do
        local button = Button(UI.list, "", recipeListWidth - padding * 2, recipeRowHeight, padding, padding + (index - 1) * recipeRowStride, function(self)
            addon.state.selected = self.recipe.id
            UI.RefreshList()
        end, "row")
        button.label:Hide()
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(22, 22)
        button.icon:SetPoint("LEFT", padding, 0)
        button.skillIcon = button:CreateTexture(nil, "ARTWORK")
        button.skillIcon:SetPoint("LEFT", 42, 0)
        button.name = Text(button, "", button:GetWidth() - 66 - padding, 66, padding, 12)
        button.value = Text(button, "", 190, 156, 12, 11, colors.muted)
        CenterText(button.name, button, 66)
        CenterText(button.value, button, 156)
        button.name:SetWordWrap(false)
        button.value:SetWordWrap(false)
        RecipeTooltip(button)
        UI.recipeButtons[index] = button
    end
    UI.listEmpty = Text(UI.list, "Open a profession to load recipes.", recipeListWidth - 32, 16, 16, 13, colors.muted)
    UI.listCount = Text(UI.workspace, "", recipeListWidth, 14, 620, 10, colors.muted)
    UI.detail = Panel(UI.workspace, detailWidth, 366, recipeListWidth + padding * 2, padding)
    UI.outputIcon = UI.detail:CreateTexture(nil, "ARTWORK")
    UI.outputIcon:SetSize(38, 38)
    UI.outputIcon:SetPoint("TOPLEFT", 12, -12)
    UI.recipeTitle = Text(UI.detail, "Select a recipe", auctionColumn - 62 - padding, 62, 12, 19, colors.accent)
    UI.recipeTitle:SetWordWrap(false)
    UI.recipeCategory = Text(UI.detail, "", auctionColumn - 62 - padding, 62, 38, 11, colors.muted)
    UI.recipeCategory:SetWordWrap(false)
    UI.market = Text(UI.detail, "", detailWidth - auctionColumn - padding, auctionColumn, 14, 11, colors.muted)
    UI.market:SetJustifyH("RIGHT")
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
    UI.requirements = Text(UI.detail, "", detailWidth - padding * 2, padding, 248, 13, {1, 0.35, 0.30})
    UI.outputHeading = Text(UI.detail, "Output · per craft", vendorColumn - padding * 2, padding, 152, 11, colors.muted)
    UI.vendorHeading = Text(UI.detail, "Vendor sell", 76, vendorColumn, 152, 11, colors.muted)
    UI.auctionHeading = Text(UI.detail, "Auction", 80, auctionColumn, 152, 11, colors.muted)
    UI.outputRow = UI.MakeItemRow(UI.detail, 12, 168)
    UI.createAll = Button(UI.detail, "Create all", 120, controlHeight, padding, 248, function() addon.Craft(true) end)
    UI.create = Button(UI.detail, "Create", 82, controlHeight, 144, 248, function() addon.Craft(false) end)
    UI.minus = Button(UI.detail, "−", controlHeight, controlHeight, 238, 248, function() UI.SetQuantity((tonumber(UI.quantity:GetText()) or 1) - 1) end, "quantity")
    UI.quantity = Edit(UI.detail, 52, controlHeight, 290, 248, 6)
    UI.quantity:SetNumeric(true)
    UI.quantity:SetMaxLetters(5)
    UI.quantity:SetText("1")
    UI.quantity:SetScript("OnTextChanged", function() addon.state.craftFailure = nil; UI.RefreshCraftButtons() end)
    UI.plus = Button(UI.detail, "+", controlHeight, controlHeight, 354, 248, function() UI.SetQuantity((tonumber(UI.quantity:GetText()) or 1) + 1) end, "quantity")
    UI.craftStatus = Text(UI.detail, "", detailWidth - padding * 2, padding, 286, 11, colors.muted)
    UI.craftProgress = CreateFrame("StatusBar", nil, UI.detail, "BackdropTemplate")
    UI.craftProgress:SetSize(116, 16)
    UI.craftProgress:SetBackdrop(panelBackdrop)
    UI.craftProgress:SetBackdropColor(0.08, 0.06, 0.03, 1)
    UI.craftProgress:SetBackdropBorderColor(unpack(colors.border))
    UI.craftProgress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    UI.craftProgress:SetStatusBarColor(1, 0.72, 0.12)
    UI.craftProgress:SetMinMaxValues(0, 1)
    UI.craftProgress:SetValue(0)
    UI.craftProgress:Hide()
    UI.craftProgress:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.05 then return end
        self.elapsed = 0
        UI.RefreshCraftProgress()
    end)
    Hint(UI.craftProgress, "Batch progress", "Estimated progress through the entire batch, including the current craft. Uses the same live cast timing as the remaining-time estimate.")
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
        local frame = CreateFrame("Frame", "ProfessionatorSettingsFrame", UIParent, "BasicFrameTemplate")
        UI.settings = frame
        frame:Hide()
        frame:SetSize(356, 132)
        frame:SetPoint("TOPRIGHT", addon.launcher, "BOTTOMLEFT", -padding, -padding)
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame.TitleText:SetText("Professionator settings")
        SetTextureWithAddressModeOptions(frame.Bg, "Profession-Background-Overview")
        frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
        tinsert(UISpecialFrames, "ProfessionatorSettingsFrame")

        local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        UI.replaceNativeCheckbox = checkbox
        checkbox:SetSize(26, 26)
        checkbox:SetPoint("TOPLEFT", padding, -40)
        checkbox:SetHitRectInsets(0, -300, 0, 0)
        local label = Text(frame, "Replace the normal professions window", 300, 44, 45, 12)
        label:SetWordWrap(false)
        checkbox:SetScript("OnClick", function(self)
            ProfessionatorDB.replaceNative = self:GetChecked() and true or false
        end)
        Text(frame, "Applies the next time you open a profession.\nLeft-click the minimap icon to open Professionator anytime.", 332, padding, 78, 11, colors.muted)
    end
    UI.replaceNativeCheckbox:SetChecked(ProfessionatorDB.replaceNative)
    UI.settings:SetShown(not UI.settings:IsShown())
end

function UI.Layout(recipe)
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
    local hasAge = recipe and recipe.auction and recipe.age ~= nil
    UI.market:SetShown(not not hasAge)
    local controlsTop = outputHeadingTop + 14 + padding + materialRowHeight + padding
    Place(UI.createAll, UI.detail, padding, controlsTop)
    Place(UI.create, UI.detail, 144, controlsTop)
    Place(UI.minus, UI.detail, 238, controlsTop)
    Place(UI.quantity.background, UI.detail, 290, controlsTop)
    Place(UI.plus, UI.detail, 354, controlsTop)
    Place(UI.requirements, UI.detail, padding, controlsTop + padding)
    local statusTop = controlsTop + controlHeight + padding
    local progressVisible = UI.craftProgress:IsShown()
    local statusLeft = progressVisible and (padding + UI.craftProgress:GetWidth() + padding) or padding
    Place(UI.craftProgress, UI.detail, padding, statusTop + 5)
    Place(UI.craftStatus, UI.detail, statusLeft, statusTop)
    UI.craftStatus:SetWidth(detailWidth - statusLeft - padding)
    local statusHeight = progressVisible and 28 or 14
    local detailHeight = statusTop + (UI.craftStatus:GetText() ~= "" and statusHeight + padding or 0)
    UI.detail:SetHeight(detailHeight)

    local listHeight = UI.recipeContentHeight or 74
    UI.list:SetHeight(listHeight)
    Place(UI.listCount, UI.workspace, padding, recipeListTop + listHeight + padding)
    UI.listCount:SetShown(#(UI.rows or {}) > UI.visibleRecipeCount)
    local listBottom = recipeListTop + listHeight + padding + (#(UI.rows or {}) > UI.visibleRecipeCount and 14 + padding or 0)
    local navigationBottom = professionListTop + (UI.professionCount or 0) * professionRowStride
    local workspaceHeight = math.max(210, detailHeight + padding * 2, listBottom, navigationBottom)
    UI.workspace:SetHeight(workspaceHeight)
    UI.navigation:SetHeight(workspaceHeight)
    local windowHeight = workspaceHeight + workspaceTop + padding
    UI.frame:SetHeight(windowHeight)
    UI.frame:SetScale(math.min(1, (UIParent:GetWidth() - 40) / windowWidth, (UIParent:GetHeight() - 60) / windowHeight))
end

local function CraftStatus(request)
    if not request.started then return "Starting craft…", nil end
    local status = "Crafting " .. (request.count - request.remaining + 1) .. "/" .. request.count
    local totalSeconds, remainingSeconds = Model.BatchTiming(request, GetTime())
    if totalSeconds and totalSeconds > 0 and remainingSeconds then
        status = status .. "\nest. " .. Model.Duration(remainingSeconds) .. " left / " .. Model.Duration(totalSeconds) .. " total"
        return status, math.max(0, math.min(1, 1 - remainingSeconds / totalSeconds))
    end
    return status, nil
end

function UI.RefreshCraftProgress()
    local request = addon.state.craftRequest
    if not request or not UI.craftProgress:IsShown() then return end
    local status, progress = CraftStatus(request)
    if progress ~= nil then
        UI.craftProgress:SetValue(progress)
        UI.craftStatus:SetText(status)
    end
end

function UI.RefreshCraftButtons()
    if not UI.create then return end
    local recipe = UI.selectedRecipe
    local current = addon.Client.OpenInfo()
    local count = tonumber(UI.quantity:GetText()) or 0
    local valid, reason = Model.CraftAllowed(recipe, count, current and current.professionID, addon.state.professionID, InCombatLockdown())
    UI.create:Available(valid and not addon.state.crafting)
    local allValid = Model.CraftAllowed(recipe, recipe and recipe.available or 0, current and current.professionID, addon.state.professionID, InCombatLockdown())
    UI.createAll:Available(allValid and not addon.state.crafting)
    UI.createAll.label:SetText("Create all [" .. (recipe and recipe.available or 0) .. "]")
    local missing = {}
    for _, requirement in ipairs(recipe and recipe.requirements or {}) do
        if not requirement.met then missing[#missing + 1] = requirement.name end
    end
    local controlsVisible = #missing == 0
    for _, control in ipairs({UI.createAll, UI.create, UI.minus, UI.quantity.background, UI.plus}) do control:SetShown(controlsVisible) end
    UI.requirements:SetShown(not controlsVisible)
    UI.requirements:SetText(not controlsVisible and ("Requires: " .. table.concat(missing, ", ")) or "")
    if reason and reason:match("^Requires:") then reason = nil end
    local request, failure = addon.state.craftRequest, addon.state.craftFailure
    local status = failure and recipe and failure.recipeID == recipe.id and failure.message or reason or ""
    local progress
    if request then
        status, progress = CraftStatus(request)
    elseif status == "" and recipe and recipe.castSeconds and recipe.available > 0 then
        status = "Create all: est. " .. Model.Duration(recipe.castSeconds * recipe.available) .. " total"
    end
    UI.craftProgress:SetShown(controlsVisible and progress ~= nil)
    UI.craftProgress:SetValue(progress or 0)
    UI.craftStatus:SetText(controlsVisible and status or "")
    UI.Layout(recipe)
end

function UI.RefreshList()
    if not UI.frame then return end
    local state = addon.state
    -- Scroll long lists sooner on smaller displays instead of shrinking every font.
    local availableListHeight = UIParent:GetHeight() - 60 - workspaceTop - padding * 3 - recipeListTop - 26
    UI.rows = Model.Select(state.recipes, state.query, state.filter, state.sort)
    local hasCamping = #UI.rows > 0 and UI.rows[#UI.rows].isCamping
    local sectionCount = hasCamping and (UI.rows[1].isCamping and 1 or 2) or 0
    UI.visibleRecipeCount = math.max(1, math.min(maximumVisibleRecipes, math.floor((availableListHeight - padding * 2 - sectionCount * recipeSectionHeight + recipeRowGap) / recipeRowStride)))
    UI.offset = math.max(0, math.min(UI.offset or 0, math.max(0, #UI.rows - UI.visibleRecipeCount)))
    UI.skillSort:Active(state.sort == "skill")
    UI.priceSort:Active(state.sort == "auction")
    UI.filter:SetChecked(state.filter == "craftable")
    local selected
    for _, recipe in ipairs(UI.rows) do if recipe.id == state.selected then selected = recipe end end
    -- Regular recipes sort first; camping may be selected automatically when it is the only result.
    selected = selected or UI.rows[1]
    state.selected = selected and selected.id or nil
    for _, heading in ipairs(UI.recipeHeadings) do heading:Hide() end
    local rowTop, previousSection = padding, nil
    for index, button in ipairs(UI.recipeButtons) do
        local recipe = index <= UI.visibleRecipeCount and UI.rows[index + UI.offset] or nil
        button:SetShown(recipe ~= nil)
        if recipe then
            local section = recipe.isCamping and 2 or 1
            if hasCamping and section ~= previousSection then
                local heading = UI.recipeHeadings[section]
                Place(heading, UI.list, padding, rowTop)
                heading:Show()
                rowTop = rowTop + recipeSectionHeight
            end
            previousSection = section
            Place(button, UI.list, padding, rowTop)
            rowTop = rowTop + recipeRowStride
            button.recipe = recipe
            button.icon:SetTexture(recipe.icon or 134400)
            local atlas = recipe.canSkillUp and skillAtlases[recipe.difficulty]
            button.skillIcon:SetShown(not not atlas)
            if atlas then button.skillIcon:SetAtlas(atlas, true) end
            local name = "[" .. recipe.available .. "] " .. recipe.name
            button.value:SetShown(state.sort == "auction")
            if state.sort == "skill" then
                button.name:SetWidth(button:GetWidth() - 66 - padding)
                button.name:SetText(name .. " (est. " .. SkillEstimate(recipe) .. " skillups)")
            else
                button.value:SetText(Model.Money(recipe.batchPrice) .. " total / " .. Model.Money(recipe.auction) .. " each")
                local valueWidth = math.min(160, button.value:GetStringWidth())
                button.value:SetWidth(valueWidth)
                CenterText(button.value, button, button:GetWidth() - padding - valueWidth)
                button.name:SetWidth(math.max(40, button:GetWidth() - 66 - padding * 2 - valueWidth))
                button.name:SetText(name)
            end
            button.name:SetTextColor(unpack(Model.Difficulty(recipe).color))
            button:Active(recipe == selected)
        end
    end
    UI.recipeContentHeight = #UI.rows > 0 and rowTop - recipeRowGap + padding or 74
    UI.listEmpty:SetShown(#UI.rows == 0)
    UI.listEmpty:SetText(state.loading and "Loading recipes…" or (#state.recipes == 0 and "No crafting recipes here. Gathering journals are available in the original window." or "No recipes match. Try clearing the search or filter."))
    UI.listCount:SetText((UI.offset + 1) .. "–" .. math.min(#UI.rows, UI.offset + UI.visibleRecipeCount) .. " of " .. #UI.rows)
    UI.Detail(selected)
end

function UI.Detail(recipe)
    if not UI.selectedRecipe or not recipe or UI.selectedRecipe.id ~= recipe.id then
        UI.materialScroll:SetVerticalScroll(0)
        addon.state.craftFailure = nil
    end
    UI.selectedRecipe = recipe
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
            ItemTooltip(row, reagent)
            row:Show()
        end
    end
    UI.outputRow:SetShown(recipe ~= nil)
    if recipe then
        local quantity = recipe.outputMin == recipe.outputMax and tostring(recipe.outputMin) or (recipe.outputMin .. "–" .. recipe.outputMax)
        UI.outputRow.icon:SetTexture(recipe.icon or 134400)
        UI.outputRow.name:SetText(quantity .. "  " .. recipe.outputName)
        UI.outputRow.vendor:SetText(Model.Money(recipe.vendorTotal))
        UI.outputRow.auction:SetText(recipe.bound and "Soulbound" or Model.Money(recipe.auctionTotal))
        ItemTooltip(UI.outputRow, {link = recipe.outputLink})
    end
    local priceAge = ""
    if recipe and recipe.auction and recipe.age ~= nil then
        priceAge = recipe.age == 0 and "AH prices\nSeen today" or ("AH prices\n" .. recipe.age .. (recipe.age == 1 and " day old" or " days old"))
    end
    UI.market:SetText(priceAge)
    UI.RefreshCraftButtons()
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
    UI.RefreshList()
end
