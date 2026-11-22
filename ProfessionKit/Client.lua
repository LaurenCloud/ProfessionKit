local _, addon = ...
addon.Client = {}
local Client = addon.Client
local Model = addon.Model

function Client.Professions()
    local rows = {}
    local slots = { GetProfessions() }
    -- Primary professions, Cooking, Fishing, First Aid, then other skill slots.
    for _, index in ipairs({1, 2, 5, 4, 6, 3, 7}) do
        if slots[index] then
            local name, icon, rank, maximum, _, _, skillLine = GetProfessionInfo(slots[index])
            if name and skillLine and skillLine ~= 3012 then
                rows[#rows + 1] = { id = skillLine, name = name, icon = icon, rank = rank, maximum = maximum }
            end
        end
    end
    return rows
end

function Client.OpenInfo()
    local api = C_TradeSkillUI
    if not api.IsTradeSkillReady() or (api.IsDataSourceChanging and api.IsDataSourceChanging()) then return nil end
    if api.IsTradeSkillLinked and api.IsTradeSkillLinked() then return nil end
    local profession = api.GetBaseProfessionInfo()
    if not profession or not profession.professionID or profession.professionID == 0 then return nil end
    return profession
end

function Client.Item(itemID)
    if not itemID or itemID == 0 then return {} end
    local name, link, _, _, _, _, _, _, _, icon, sell, _, _, bind = C_Item.GetItemInfo(itemID)
    if not name and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    local record = { name = name or ("Item " .. itemID), link = link or ("item:" .. itemID), icon = icon,
        vendorSell = sell, bound = bind == 1, cached = name ~= nil }
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.GetAuctionPriceByItemID and record.cached and not record.bound then
        local success, value = pcall(api.GetAuctionPriceByItemID, "ProfessionKit", itemID)
        if success and type(value) == "number" and value > 0 then record.auction = value end
        if api.GetAuctionAgeByItemID then
            local valid, age = pcall(api.GetAuctionAgeByItemID, "ProfessionKit", itemID)
            if valid and type(age) == "number" then record.age = age end
        end
    end
    local vendor = ProfessionKitDB and ProfessionKitDB.vendorPrices and ProfessionKitDB.vendorPrices[itemID]
    record.vendorBuy = vendor and vendor.price or nil
    return record
end

local function PlainNumber(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) == "number" and value == value and value ~= math.huge then return value end
end

function Client.Cooldown(recipeID)
    -- The profession API returns remaining seconds, not a start timestamp. A
    -- recharging recipe can still be used while it has charges left.
    local remaining, charges, maximumCharges
    if C_TradeSkillUI.GetRecipeCooldown then
        local seconds, _, available, maximum = C_TradeSkillUI.GetRecipeCooldown(recipeID)
        remaining, charges, maximumCharges = PlainNumber(seconds), PlainNumber(available), PlainNumber(maximum)
    end
    if maximumCharges and maximumCharges > 0 and charges then
        return charges > 0 and 0 or math.max(0, remaining or 0), math.max(0, charges)
    end
    if remaining and remaining > 0 then return remaining, nil end
    local chargeInfo = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(recipeID)
    if chargeInfo and PlainNumber(chargeInfo.currentCharges) and PlainNumber(chargeInfo.maxCharges) and chargeInfo.maxCharges > 0 then
        local start, duration = PlainNumber(chargeInfo.cooldownStartTime), PlainNumber(chargeInfo.cooldownDuration)
        remaining = start and duration and math.max(0, start + duration - GetTime()) or 0
        return chargeInfo.currentCharges > 0 and 0 or remaining, chargeInfo.currentCharges
    end
    local cooldown = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(recipeID)
    if cooldown then
        local start, duration = PlainNumber(cooldown.startTime), PlainNumber(cooldown.duration)
        local global = C_Spell.GetSpellCooldown(61304)
        local globalStart = global and PlainNumber(global.startTime)
        local globalDuration = global and PlainNumber(global.duration)
        -- Compare the actual GCD interval; isOnGCD is only reliable inside its event.
        local onlyGlobal = start and duration and globalStart and globalDuration and duration > 0
            and math.abs(start - globalStart) < 0.01 and math.abs(duration - globalDuration) < 0.01
        if start and duration and not onlyGlobal then return math.max(0, start + duration - GetTime()), nil end
    end
    return 0, nil
end

function Client.Recipe(recipeID)
    local api = C_TradeSkillUI
    local info = api.GetRecipeInfo(recipeID)
    if not info or not info.learned or info.isDummyRecipe then return nil end
    local schematic = api.GetRecipeSchematic(recipeID, false)
    if not schematic then return nil end
    local itemID = schematic.outputItemID
    local output = Client.Item(itemID)
    local category = info.categoryID and api.GetCategoryInfo(info.categoryID)
    local spell = C_Spell.GetSpellInfo(recipeID)
    local recipeTypes = Enum.TradeskillRecipeType or {}
    local isEnchant = schematic.recipeType == recipeTypes.Enchant and recipeTypes.Enchant ~= nil or info.isEnchantingRecipe == true
    local isGathering = info.isGatheringRecipe == true or (recipeTypes.Gathering ~= nil and schematic.recipeType == recipeTypes.Gathering)
    local cooldown, charges = Client.Cooldown(recipeID)
    local recipe = {
        id = recipeID, name = info.name or "Loading recipe…", learned = info.learned,
        icon = info.icon or output.icon, category = category and category.name or "Recipes",
        isCamping = category ~= nil and category.name == "Camping",
        difficulty = info.relativeDifficulty or 3, canSkillUp = info.canSkillUp == true,
        skillUps = math.max(1, info.numSkillUps or 1), available = math.max(0, api.GetCraftableCount(recipeID) or 0),
        outputID = itemID, outputName = output.name or info.name, outputLink = output.link,
        outputMin = schematic.quantityMin or 1, outputMax = schematic.quantityMax or schematic.quantityMin or 1,
        auction = output.auction, age = output.age, bound = output.bound,
        vendorSell = output.vendorSell, reagents = {}, requirements = api.GetRecipeRequirements(recipeID) or {},
        cooldown = cooldown, charges = charges,
        isEnchant = isEnchant, isGathering = isGathering,
        canCreateMultiple = info.canCreateMultiple ~= false and not isEnchant and not isGathering
            and not (api.HasNoReagentCost and api.HasNoReagentCost(recipeID)),
        disabled = info.disabled == true or info.craftable == false, disabledReason = info.disabledReason,
        description = isEnchant and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(recipeID) or nil,
        castSeconds = spell and type(spell.castTime) == "number" and spell.castTime > 0 and spell.castTime / 1000 or nil,
        unsupported = isGathering or info.isSalvageRecipe == true or info.isRecraft == true
            or (not isEnchant and (not itemID or itemID == 0))
            or (isEnchant and (not api.CraftEnchant or not api.GetEnchantItems)),
    }
    local profession = Client.OpenInfo()
    recipe.skillRoom = profession and profession.maxSkillLevel and profession.skillLevel and math.max(0, profession.maxSkillLevel - profession.skillLevel) or nil
    if profession and profession.skillLevel and info.maxTrivialLevel and info.maxTrivialLevel > 0 then
        recipe.skillRoom = math.min(recipe.skillRoom or math.huge, math.max(0, info.maxTrivialLevel - profession.skillLevel))
    end
    if recipe.available == math.huge then recipe.available = 1 end
    if isEnchant then
        recipe.outputName, recipe.auction, recipe.age, recipe.vendorSell = recipe.name, nil, nil, nil
    end
    local basic = Enum.CraftingReagentType.Basic
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        if slot.required then
            local options = slot.reagents or {}
            if slot.reagentType ~= basic or #options ~= 1 or not options[1].itemID then
                recipe.unsupported = true
            else
                local reagent = Client.Item(options[1].itemID)
                reagent.id = options[1].itemID
                reagent.required = slot.quantityRequired or 1
                reagent.owned = C_Item.GetItemCount(reagent.id, false, false, false) or 0
                recipe.reagents[#recipe.reagents + 1] = reagent
                if reagent.required > 0 then recipe.available = math.min(recipe.available, math.floor(reagent.owned / reagent.required)) end
            end
        end
    end
    Model.PriceRecipe(recipe)
    return recipe
end

function Client.Read(professionID)
    local current = Client.OpenInfo()
    if not current or current.professionID ~= professionID then return nil end
    local recipes, seen = {}, {}
    local child = C_TradeSkillUI.GetChildProfessionInfo and C_TradeSkillUI.GetChildProfessionInfo()
    local skillLine = child and child.professionID and child.professionID > 0 and child.professionID or professionID
    for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
        if not C_TradeSkillUI.IsRecipeInSkillLine or C_TradeSkillUI.IsRecipeInSkillLine(recipeID, skillLine) then
            local recipe = Client.Recipe(recipeID)
            if recipe and not seen[recipe.id] then
                seen[recipe.id] = true
                recipes[#recipes + 1] = recipe
            end
        end
    end
    if addon.Stations then addon.Stations.Observe(professionID, recipes) end
    return recipes
end

function Client.RecordVendor()
    for index = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(index)
        local info = C_MerchantFrame.GetItemInfo(index)
        local price, stack, extended = info and info.price, info and info.stackCount, info and info.hasExtendedCost
        local itemID = link and tonumber(link:match("item:(%d+)"))
        if itemID and price and stack and stack > 0 and not extended then
            ProfessionKitDB.vendorPrices[itemID] = { price = price / stack, observed = time() }
        end
    end
end
