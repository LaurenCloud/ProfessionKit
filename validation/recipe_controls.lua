-- Exercise ranking controls and the crowded Engineering list through the full UI.
local harness, addon = Harness, ProfessionatorAddon
local UI = addon.UI
local function ButtonFor(recipeID)
    for _, button in ipairs(UI.recipeButtons) do
        if button:IsShown() and button.recipe.id == recipeID then return button end
    end
    error("Recipe is not visible: " .. recipeID)
end
local function Position(frame)
    local _, _, _, horizontal, vertical = frame:GetPoint()
    return horizontal, vertical
end

harness.Event("ADDON_LOADED", "Professionator")
harness.inventory[2770], harness.inventory[2771] = 40, 2
harness.recipes[2657].info.relativeDifficulty = 1
addon.Open(186); harness.Advance(1)
harness.Check("Quantity weighting defaults on for an existing profile without the preference", addon.state.multiplyByQuantity and UI.multiplyByQuantity:GetChecked())
harness.Check("Weighted Skill-ups ranks available skill gain capped at the gray threshold", UI.rows[1].id == 2657 and UI.rows[1].skillEstimate == 5)
local copperCount, copperEstimate = ButtonFor(2657).count:GetText(), ButtonFor(2657).summary:GetText()
UI.multiplyByQuantity:Click()
harness.Check("Unweighted Skill-ups ranks the chance from one craft", UI.rows[1].id == 3304 and UI.rows[1].skillPerCraft == 1 and UI.rows[3].id == 2657)
harness.Check("Changing weighting preserves selection and available-material labels", UI.selectedRecipe.id == 2657 and ButtonFor(2657).count:GetText() == copperCount and ButtonFor(2657).summary:GetText() == copperEstimate)
harness.Check("Uncraftable recipes stay visible with either quantity setting", #UI.rows == 3 and ButtonFor(2659).count:GetText() == "[0]")
UI.priceSort:Click()
harness.Check("Unweighted Prices includes every output of one craft", UI.rows[1].id == 2659 and UI.rows[1].auctionTotal == 230 and UI.rows[2].id == 3304)
local copperPrices = ButtonFor(2657).summary:GetText()
UI.multiplyByQuantity:Click()
harness.Check("Weighted Prices ranks the full available output value", UI.rows[1].id == 2657 and UI.rows[1].batchPrice == 2720 and UI.rows[2].id == 3304)
harness.Check("Price labels remain total available value and per output item across weighting changes", ButtonFor(2657).summary:GetText() == copperPrices and copperPrices == "est. 5 skillups · " .. addon.Model.Money(2720) .. " total / " .. addon.Model.Money(68) .. " each")

-- Reproduce the user's five Engineering rows, including unavailable and unpriced recipes.
harness.professions[2] = {name = "Engineering", id = 202, rank = 75, maximum = 75}
harness.Item(2835, "Rough Stone", 2, 24, 3)
harness.Item(2840, "Copper Bar", 10, 0, 109)
harness.Item(4357, "Rough Blasting Powder", 4, 0, 15)
harness.Item(4359, "Handful of Copper Bolts", 12, 0, 245)
harness.Item(4360, "Rough Copper Bomb", 10, 0, 60)
harness.Item(8067, "Crafted Light Shot", 0, 0, nil)
harness.Item(4358, "Rough Dynamite", 0, 0, nil)
harness.Recipe(3918, 202, "Rough Blasting Powder", 4357, 3, 30, 1, {{2835, 1}}, 3)
harness.Recipe(3922, 202, "Handful of Copper Bolts", 4359, 3, 60, 1, {{2840, 1}}, 3)
harness.Recipe(3923, 202, "Rough Copper Bomb", 4360, 3, 75, 1, {{2840, 1}}, 3)
harness.Recipe(3920, 202, "Crafted Light Shot", 8067, 3, 45, 200, {{2840, 1}}, 3)
harness.Recipe(3919, 202, "Rough Dynamite", 4358, 3, 60, 1, {{2840, 1}}, 3)
addon.Open(202); harness.Advance(1)
ButtonFor(3922):Click()
local powder = ButtonFor(3918)
local countLeft, countVertical = Position(powder.count)
local iconLeft = Position(powder.icon)
local nameLeft, nameVertical = Position(powder.name)
local priceLeft, priceVertical = Position(powder.summary)
harness.Check("Gray recipes leave only six units between the item icon and count", countLeft - iconLeft - powder.icon:GetWidth() == 6)
harness.Check("Price rows put names above prices with room between the lines", countVertical == nameVertical and nameVertical - priceVertical == 20 and powder:GetHeight() == 58)
harness.Check("Recipe tiles have narrower sides while keeping room vertically", iconLeft == 8 and (powder:GetHeight() - powder.icon:GetHeight()) / 2 == 18 and priceLeft + powder.summary:GetWidth() == powder:GetWidth() - 8)
local allNamesFit, allPricesFit, allCountsFit = true, true, true
for _, button in ipairs(UI.recipeButtons) do
    if button:IsShown() then
        allNamesFit = allNamesFit and button.name:GetWidth() >= button.name:GetUnboundedStringWidth()
        allPricesFit = allPricesFit and button.summary:GetWidth() >= button.summary:GetUnboundedStringWidth()
        allCountsFit = allCountsFit and button.count:GetWidth() >= button.count:GetUnboundedStringWidth() + 2
    end
end
harness.Check("Every name, quantity and total/each price fits in the Engineering fixture", allNamesFit and allPricesFit and allCountsFit)
harness.Snapshot("engineering-prices")

-- Reused font strings must grow again after a shorter quantity constrained them.
for _, quantity in ipairs({0, 8, 24, 240, 2400}) do
    harness.inventory[2835] = quantity
    addon.Refresh()
    powder = ButtonFor(3918)
    harness.Check("Quantity stays complete after inventory changes to " .. quantity, powder.count:GetText() == "[" .. quantity .. "]" and powder.count:GetWidth() >= powder.count:GetUnboundedStringWidth() + 2)
end
harness.Snapshot("engineering-large-quantity")
harness.inventory[2835] = 24
harness.recipes[3918].info.relativeDifficulty, harness.recipes[3918].info.canSkillUp = 2, true
harness.recipes[3918].info.maxTrivialLevel = 100
harness.professions[2].maximum = 150
addon.Refresh()
powder = ButtonFor(3918)
local skillLeft = Position(powder.skillIcon)
countLeft = Position(powder.count)
harness.Check("Skillable recipes insert only the native skill arrow plus a four-unit gap", powder.skillIcon:IsShown() and countLeft == skillLeft + powder.skillIcon:GetWidth() + 4)
UI.skillSort:Click()
harness.Check("Skill-ups keeps the same row layout and shows both the estimate and prices", powder:GetHeight() == 58 and powder.summary:IsShown() and select(2, Position(powder.name)) == 10
    and powder.summary:GetText() == "est. 4 skillups · " .. addon.Model.Money(360) .. " total / " .. addon.Model.Money(15) .. " each")
harness.Snapshot("engineering-skillups")
UI.multiplyByQuantity:Click()
harness.Event("PLAYER_LOGOUT")
harness.Check("Disabling quantity weighting is saved for reload", ProfessionatorDB.multiplyByQuantity == false)
