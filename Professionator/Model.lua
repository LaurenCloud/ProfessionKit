local _, addon = ...
addon.Model = {}
local Model = addon.Model

function Model.Money(copper)
    if copper == nil then return "—" end
    local sign = copper < 0 and "−" or ""
    copper = math.floor(math.abs(copper) + 0.5)
    return sign .. GetMoneyString(copper, true)
end

function Model.Duration(seconds)
    if seconds == nil then return "—" end
    seconds = math.max(0, math.ceil(seconds))
    local hours, minutes = math.floor(seconds / 3600), math.floor(seconds / 60) % 60
    if hours > 0 then return hours .. "h " .. minutes .. "m" end
    if minutes > 0 then return minutes .. "m " .. (seconds % 60) .. "s" end
    return seconds .. "s"
end

function Model.BatchTiming(request, now)
    if not request.castSeconds then return nil, nil end
    local remaining = request.remaining * request.castSeconds
    if request.castEndTime then
        remaining = math.max(0, request.castEndTime - now) + math.max(0, request.remaining - 1) * request.castSeconds
    end
    local elapsed = request.startedAt and math.max(0, now - request.startedAt) or 0
    return elapsed + remaining, remaining
end

Model.difficulties = {
    [0] = { label = "High skill-up chance", color = {1, 0.58, 0.22} },
    [1] = { label = "Medium skill-up chance", color = {1, 0.83, 0.35} },
    [2] = { label = "Low skill-up chance", color = {0.49, 0.79, 0.48} },
    [3] = { label = "No skill-up", color = {0.55, 0.59, 0.65} },
}

function Model.Difficulty(recipe)
    return Model.difficulties[recipe.canSkillUp and recipe.difficulty or 3] or Model.difficulties[3]
end

function Model.PriceRecipe(recipe)
    recipe.auctionTotal = recipe.auction and recipe.auction * recipe.outputMin or nil
    recipe.vendorTotal = recipe.vendorSell and recipe.vendorSell * recipe.outputMin or nil
    recipe.batchPrice = recipe.auctionTotal and recipe.auctionTotal * recipe.available or nil
    local chance = ({ [0] = 1, [1] = 0.5, [2] = 0.2, [3] = 0 })[recipe.difficulty] or 0
    -- Cap the estimate at the recipe's gray threshold as well as the trained skill cap.
    -- Color alone cannot tell us the exact probability curve; the UI calls this an estimate.
    recipe.skillPerCraft = recipe.canSkillUp and math.min(recipe.skillRoom or math.huge, recipe.skillUps * chance) or 0
    recipe.skillEstimate = recipe.canSkillUp and math.min(recipe.skillRoom or math.huge, recipe.available * recipe.skillUps * chance) or 0
end

function Model.Select(recipes, query, sort, multiplyByQuantity)
    local rows = {}
    query = (query or ""):lower()
    for _, recipe in ipairs(recipes) do
        local matches = recipe.name:lower():find(query, 1, true) or recipe.category:lower():find(query, 1, true)
        if matches then
            rows[#rows + 1] = recipe
        end
    end
    local function Score(recipe)
        if sort == "skill" then
            if multiplyByQuantity then return recipe.skillEstimate end
            return recipe.skillPerCraft
        end
        if sort == "auction" then
            if multiplyByQuantity then return recipe.batchPrice end
            return recipe.auctionTotal
        end
    end
    table.sort(rows, function(left, right)
        if left.isCamping ~= right.isCamping then return not left.isCamping end
        local leftScore, rightScore = Score(left), Score(right)
        if leftScore == rightScore then
            if left.available ~= right.available then return left.available > right.available end
            if left.name == right.name then return left.id < right.id end
            return left.name < right.name
        end
        if leftScore == nil then return false end
        if rightScore == nil then return true end
        return leftScore > rightScore
    end)
    return rows
end

function Model.CraftAllowed(recipe, count, currentProfessionID, selectedProfessionID, inCombat)
    if inCombat then return false, "Crafting is unavailable during combat." end
    if currentProfessionID ~= selectedProfessionID then return false, "Wait for this profession to finish loading." end
    if not recipe or not recipe.learned then return false, "Select a learned recipe." end
    if recipe.unsupported then return false, "This recipe needs the original crafting window." end
    if count < 1 or count ~= math.floor(count) then return false, "Enter a whole number of crafts." end
    if count > recipe.available then return false, "Not enough available materials." end
    if recipe.cooldown and recipe.cooldown > 0 then return false, "This recipe is on cooldown." end
    for _, requirement in ipairs(recipe.requirements) do
        if not requirement.met then return false, "Requires: " .. requirement.name end
    end
    return true
end
