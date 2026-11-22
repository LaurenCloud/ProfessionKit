local _, addon = ...
addon.Stations = {}
local Stations = addon.Stations
local previousStatuses = {}

-- These describe each profession's ordinary station. Learned recipe requirements
-- below supply their exact names and any additional, specialized stations.
local ordinaryStations = {
    [186] = {profession = "Mining", name = "Forge", icon = "Interface\\Icons\\Trade_Mining"},
    [164] = {profession = "Blacksmithing", name = "Anvil", icon = "Interface\\Icons\\Trade_BlackSmithing"},
    [202] = {profession = "Engineering", name = "Anvil", icon = "Interface\\Icons\\Trade_BlackSmithing"},
    [185] = {profession = "Cooking", name = "Cooking fire", icon = "Interface\\Icons\\Spell_Fire_Fire"},
}

local function IsStation(requirement)
    return Enum.RecipeRequirementType and requirement.type == Enum.RecipeRequirementType.SpellFocus
end

function Stations.Observe(professionID, recipes)
    if not ProfessionKitDB then return end
    ProfessionKitDB.stationRecipes = ProfessionKitDB.stationRecipes or {}
    local probes = {}
    for _, recipe in ipairs(recipes) do
        for _, requirement in ipairs(recipe.requirements) do
            if IsStation(requirement) and not probes[requirement.name] then probes[requirement.name] = recipe.id end
        end
    end
    ProfessionKitDB.stationRecipes[professionID] = probes
end

function Stations.Read(profession)
    local ordinary = ordinaryStations[profession.id]
    local probes = ProfessionKitDB.stationRecipes and ProfessionKitDB.stationRecipes[profession.id] or {}
    local statuses, checked = {}, {}
    for name, recipeID in pairs(probes) do
        -- A different profession may not have a loaded data source. Missing data
        -- is unknown, never evidence that a previously visited station is nearby.
        if not checked[recipeID] then
            checked[recipeID] = true
            local success, requirements = pcall(C_TradeSkillUI.GetRecipeRequirements, recipeID)
            if success and type(requirements) == "table" then
                for _, requirement in ipairs(requirements) do
                    if IsStation(requirement) then statuses[requirement.name] = requirement.met == true end
                end
            end
        end
        if statuses[name] == nil then statuses[name] = "unknown" end
    end
    if next(statuses) == nil and ordinary then
        local professionEnum = Enum.Profession and Enum.Profession[ordinary.profession]
        local nearby = "unknown"
        if professionEnum and C_TradeSkillUI.IsNearProfessionSpellFocus then
            local success, result = pcall(C_TradeSkillUI.IsNearProfessionSpellFocus, professionEnum)
            if success and type(result) == "boolean" then nearby = result end
        end
        statuses[ordinary.name] = nearby
    end
    if next(statuses) == nil then return nil end
    local names, lines, anyNearby, anyUnknown = {}, {}, false, false
    for name in pairs(statuses) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local status = statuses[name]
        anyNearby = anyNearby or status == true
        anyUnknown = anyUnknown or status == "unknown"
        lines[#lines + 1] = name .. (status == true and ": nearby" or status == false and ": not nearby" or ": open profession to check")
    end
    local summary = table.concat(lines, "\n")
    if summary ~= previousStatuses[profession.id] then
        previousStatuses[profession.id] = summary
        if addon.Diagnostics then addon.Diagnostics.Record("station-status", {professionID = profession.id, stations = summary}) end
    end
    return {icon = ordinary and ordinary.icon or profession.icon, nearby = anyNearby, unknown = anyUnknown,
        tooltip = summary .. "\n\nIndividual recipes may require other stations or tools."}
end
