-- Reproduce the user's Mining list through the complete addon, then change
-- inventory, skill eligibility, sort choice and auction data as in a live session.
local harness, addon = Harness, ProfessionKitAddon
local UI = addon.UI
local function ButtonFor(recipeID)
    for _, button in ipairs(UI.recipeButtons) do
        if button:IsShown() and button.recipe.id == recipeID then return button end
    end
    error("Recipe is not visible: " .. recipeID)
end
local function IndexOf(recipeID)
    for index, recipe in ipairs(UI.rows) do if recipe.id == recipeID then return index end end
end

harness.Event("ADDON_LOADED", "ProfessionKit")
for _, recipeID in ipairs({2657, 2659, 3304}) do
    harness.recipes[recipeID].info.relativeDifficulty = 3
    harness.recipes[recipeID].info.canSkillUp = false
end
harness.inventory[2770], harness.inventory[2771], harness.inventory[3576] = 40, 0, 0
harness.Item(279960, "Lodestone", 0, 0, 2000)
harness.Item(2835, "Rough Stone", 2, 0, 3)
harness.Recipe(1230161, 186, "Lodestone", 279960, 3, 25, 1, {{2835, 1}}, 2717)
addon.Open(186); harness.Advance(1)
harness.Check("Forty gray Copper crafts sort above zero Bronze and Tin", UI.rows[1].id == 2657 and UI.rows[1].available == 40 and UI.rows[2].id == 2659 and UI.rows[3].id == 3304)
harness.Check("The available gray recipe becomes the default selection", UI.selectedRecipe.id == 2657 and UI.createAll.label:GetText() == "Create all [40]" and UI.createAll.enabled)
local copper, tin = ButtonFor(2657), ButtonFor(3304)
copper:Run("OnEnter")
harness.Check("Hovering Smelt Copper opens the native Copper Bar item link", GameTooltip:IsOwned(copper) and GameTooltip:IsShown() and GameTooltip.hyperlink == "item:2840")
copper:Run("OnLeave")
harness.Check("Leaving the recipe closes its item tooltip", not GameTooltip:IsShown())
harness.Check("Craftable quantity is green while zero quantity is red", copper.count:GetText() == "[40]" and copper.count.textColor[2] > copper.count.textColor[1]
    and tin.count:GetText() == "[0]" and tin.count.textColor[1] > tin.count.textColor[2])
harness.Check("Gray names retain difficulty color independently of quantity", copper.name.textColor[1] == tin.name.textColor[1] and copper.name.textColor[2] == tin.name.textColor[2]
    and not copper.skillIcon:IsShown() and not tin.skillIcon:IsShown())
harness.Check("Existing skillup wording stays intact below the recipe name", copper.skillEstimate:GetText() == "est. 0 skillups" and tin.skillEstimate:GetText() == "est. 0 skillups")
harness.Snapshot("mining-gray-quantities")
UI.multiplyByQuantity:Click()
harness.Check("Disabling quantity weighting keeps unavailable recipes visible", #UI.rows == 4 and UI.rows[1].id == 2657)
UI.multiplyByQuantity:Click()

harness.recipes[3304].info.relativeDifficulty, harness.recipes[3304].info.canSkillUp = 0, true
addon.Refresh()
tin = ButtonFor(3304)
harness.Check("A skillable recipe without materials retains its skill icon and red zero", tin.skillIcon:IsShown() and tin.count.textColor[1] > tin.count.textColor[2]
    and tin.name.textColor[1] == addon.Model.difficulties[0].color[1])
harness.Snapshot("mining-availability-and-difficulty")
harness.inventory[2771] = 8
copper:Run("OnEnter")
addon.Refresh()
harness.Check("The hovered tile switches to the Tin Bar tooltip when recipes reorder", GameTooltip:IsOwned(copper) and GameTooltip.hyperlink == "item:3576")
copper:Run("OnLeave")
harness.Check("Selected skillup score remains primary over available quantity", UI.rows[1].id == 3304 and UI.rows[1].available == 8 and UI.rows[2].available == 40)
harness.Check("Explicit recipe selection survives automatic reordering", UI.selectedRecipe.id == 2657)
harness.recipes[3304].info.relativeDifficulty, harness.recipes[3304].info.canSkillUp = 3, false
addon.Refresh()
harness.Check("Tied skillup scores sort by descending available quantity", UI.rows[1].id == 2657 and UI.rows[2].id == 3304 and UI.rows[3].id == 2659)

harness.prices[2840], harness.prices[3576] = 2, 10
addon.Refresh(); UI.priceSort:Click()
harness.Check("Tied batch prices use available quantity as the secondary sort", UI.rows[1].batchPrice == 80 and UI.rows[2].batchPrice == 80 and UI.rows[1].id == 2657 and UI.rows[2].id == 3304)
harness.Check("Quantity color remains independent under Prices", ButtonFor(2657).count.textColor[2] > ButtonFor(2657).count.textColor[1] and ButtonFor(2659).count.textColor[1] > ButtonFor(2659).count.textColor[2])
harness.prices[3576] = 11
addon.Refresh()
harness.Check("Higher batch price wins even with fewer available crafts", UI.rows[1].id == 3304 and UI.rows[1].batchPrice == 88)
harness.inventory[2835] = 300
addon.Refresh()
harness.Check("Camping stays below regular recipes despite greater quantity and price", UI.rows[#UI.rows].id == 1230161 and UI.rows[#UI.rows].available == 300)
harness.prices[2840], harness.prices[3576] = nil, nil
addon.Refresh()
harness.Check("Unknown prices stay below known prices and tie by quantity", UI.rows[1].id == 2659 and IndexOf(2657) < IndexOf(3304))

UI.skillSort:Click()
harness.inventory[2770] = 8
addon.Refresh()
harness.Check("Equal scores and quantities retain alphabetical ordering", UI.rows[1].id == 2657 and UI.rows[2].id == 3304)
harness.inventory[2770] = 0
addon.Refresh()
harness.Check("Material changes immediately update both ordering and quantity color", UI.rows[1].id == 3304 and ButtonFor(2657).count:GetText() == "[0]"
    and ButtonFor(2657).count.textColor[1] > ButtonFor(2657).count.textColor[2])
