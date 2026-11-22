-- Continue the saved-preferences workflow through the grip's native drag callbacks.
local harness, addon = Harness, ProfessionKitAddon
local UI = addon.UI
local frame = UI.frame
local function BeginHeightDrag(height)
    UI.heightGrip:Run("OnDragStart")
    assert(frame.resizable and frame.sizingEdge == "BOTTOM")
    local bounds = frame.resizeBounds
    assert(bounds.minWidth == frame:GetWidth() and bounds.maxWidth == frame:GetWidth())
    frame:SetHeight(math.max(bounds.minHeight, math.min(bounds.maxHeight, height)))
end
local function DragHeight(height)
    BeginHeightDrag(height)
    UI.heightGrip:Run("OnDragStop")
end

addon.Open(186)
harness.Advance(1)
UIParent:SetHeight(1500)
for index = 1, 17 do
    harness.Recipe(95000 + index, 186, "Smelting fixture " .. index, 2840, 3, 1, 1, {{2770, 1}}, 3)
end
harness.Recipe(96000, 186, "Three material recipe", 2840, 3, 1, 1, {{2770, 1}, {2771, 1}, {2840, 1}}, 3)
addon.Refresh()
local width = frame:GetWidth()
local selectedID = UI.selectedRecipe.id
harness.Check("An existing profile starts with automatic window height", ProfessionKitDB.windowHeight == nil and UI.heightGrip:IsVisible())
BeginHeightDrag(1400)
harness.Check("Rows reflow during the drag before the height is saved", UI.visibleRecipeCount > 12
    and UI.workspace:GetHeight() == frame:GetHeight() - 48 and ProfessionKitDB.windowHeight == nil)
UI.heightGrip:Run("OnDragStop")
harness.Check("A tall drag shows additional recipe buttons at the same width and scale", frame:GetHeight() == 1400 and frame:GetWidth() == width
    and frame.scale == 1 and UI.visibleRecipeCount > 12 and UI.recipeButtons[UI.visibleRecipeCount]:IsVisible() and UI.selectedRecipe.id == selectedID)
UI.list:Run("OnMouseWheel", -100)
harness.Check("Extra recipe rows scroll to the final result", UI.recipeButtons[UI.visibleRecipeCount].recipe == UI.rows[#UI.rows])
UI.list:Run("OnMouseWheel", 100)
DragHeight(1)
local compactHeight = frame:GetHeight()
harness.Check("Shrinking stops at the measured minimum and gives the list fewer rows", compactHeight == frame.resizeBounds.minHeight
    and UI.visibleRecipeCount < 12 and frame.scale == 1 and ProfessionKitDB.windowHeight == compactHeight)
UI.search:SetText("Three material recipe")
harness.Check("Taller recipe details expand the minimum without overwriting the chosen height", frame:GetHeight() == frame.resizeBounds.minHeight
    and frame:GetHeight() > compactHeight and ProfessionKitDB.windowHeight == compactHeight)
UI.search:SetText("Smelt Copper")
harness.Check("A shorter recipe restores the chosen height", frame:GetHeight() == compactHeight and UI.selectedRecipe.id == selectedID)
UI.quantity:SetText("1")
UI.create:Click()
harness.Check("A live batch fits below the details at the minimum height", UI.craftingPanel:IsVisible() and frame:GetHeight() > compactHeight
    and UI.workspace:GetHeight() >= UI.detail:GetHeight() + UI.craftingPanel:GetHeight() + 36 and ProfessionKitDB.windowHeight == compactHeight)
harness.casting = false
harness.Event("UNIT_SPELLCAST_SUCCEEDED", "player", "resized-cast", selectedID)
harness.Check("Finishing the batch releases the temporary height", frame:GetHeight() == compactHeight)
UI.search:SetText("")
DragHeight(610)
UIParent:SetHeight(640)
addon.Refresh()
harness.Check("A smaller screen clamps the preferred height while preserving it", frame:GetHeight() == 580 and ProfessionKitDB.windowHeight == 610 and frame.scale == 1)
UIParent:SetHeight(900)
addon.Refresh()
harness.Check("More screen space restores the preferred height at fixed width", frame:GetHeight() == 610 and frame:GetWidth() == width)
UI.search:SetText("Three material recipe")
UI.pinRecipe:Click()
UI.search:SetText("")
DragHeight(637)
local listTop = -select(5, UI.list:GetPoint())
local counterTop = -select(5, UI.listCount:GetPoint())
local lastButton = UI.recipeButtons[UI.visibleRecipeCount]
local lastTop = -select(5, lastButton:GetPoint())
local clipBottom = UI.list:GetHeight() - 12
harness.Check("A 21-recipe list with two pins fills the column down to its range counter", #UI.rows == 21 and UI.rows[2].section == "Pinned"
    and UI.rows[3].section == "Recipes" and counterTop == listTop + UI.list:GetHeight() + 12
    and counterTop + 14 + 12 == UI.workspace:GetHeight())
harness.Check("The bottom recipe peeks into the viewport and only its visible area accepts clicks", UI.recipeViewport.clipsChildren
    and lastButton.parent.parent == UI.recipeViewport and lastTop < clipBottom and lastTop + lastButton:GetHeight() > clipBottom
    and lastButton.hitInsets[4] == lastTop + lastButton:GetHeight() - clipBottom
    and UI.listCount:GetText() == "1–" .. UI.visibleRecipeCount .. " of 21")
harness.Snapshot("mining-resized-height")
UI.list:Run("OnMouseWheel", -100)
lastButton = UI.recipeButtons[UI.visibleRecipeCount]
harness.Check("Scrolling to the end shows the entire final recipe and preserves window height", lastButton.recipe == UI.rows[21]
    and -select(5, lastButton:GetPoint()) + lastButton:GetHeight() == clipBottom and lastButton.hitInsets[4] == 0 and frame:GetHeight() == 637)
UI.search:SetText("Three material recipe")
UI.pinRecipe:Click()
harness.Check("A short search result stays compact and hides the range counter", UI.visibleRecipeCount == 1 and not UI.listCount:IsShown()
    and UI.list:GetHeight() == UI.recipeButtons[1]:GetHeight() + 24)
DragHeight(610)
harness.Event("PLAYER_LOGOUT")
