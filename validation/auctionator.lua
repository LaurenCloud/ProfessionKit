-- Read-only replay against the installed Auctionator API, serializer, and real saved data.
-- All deserialization and objects live in this separate Lua interpreter; no game file is written.
local function Load(relativePath) assert(loadfile(AuctionatorDirectory .. "/" .. relativePath))() end
strmatch = string.match
Load("Libs/LibStub/LibStub.lua")
Load("Libs/LibCBOR/LibCBOR.lua")
-- Windows text-mode loadfile stops at byte 0x1A inside Auctionator's CBOR strings.
local savedFile = assert(io.open(AuctionatorSettingsPath, "rb"))
local savedSource = savedFile:read("*a")
savedFile:close()
assert(loadstring(savedSource, "Auctionator saved variables"))()
time = os.time
Auctionator = {
    Constants = {SCAN_DAY_0 = os.time({year = 2020, month = 1, day = 1, hour = 0})},
    Config = {Options = {PRICE_HISTORY_DAYS = "price_history_days"}, Get = function() return 21 end},
    Utilities = {
        TableKeys = function(value) local keys = {}; for key in pairs(value) do table.insert(keys, key) end; return keys end,
        PrettyDate = function(timestamp) return os.date("%Y-%m-%d", timestamp) end,
    },
    API = {v1 = {}, InternalVerifyID = function(caller) assert(caller == "Professionator") end, ComposeError = error},
}
Load("Source/Database/Mixin.lua")
Load("Source/API/v1/GetAuctionPrice.lua")
Load("Source/API/v1/GetAuctionAge.lua")
local replay = {items = {}, realms = 0, itemCount = 0}
for realm, data in pairs(AUCTIONATOR_PRICE_DATABASE) do
    if realm ~= "__dbversion" then
        if type(data) == "string" then data = LibStub("LibCBOR-1.0"):Deserialize(data) end
        replay.realms = replay.realms + 1
        Auctionator.Database = setmetatable({}, {__index = Auctionator.DatabaseMixin})
        Auctionator.Database:Init(data)
        for key, value in pairs(data) do
            local itemID = tonumber(key)
            if itemID and type(value) == "table" then
                replay.itemCount = replay.itemCount + 1
                if not Harness.items[itemID] then Harness.Item(itemID, "Recorded item " .. itemID, 0) end
                local item = ProfessionatorAddon.Client.Item(itemID)
                assert(item.auction == (value.m > 0 and value.m or nil), "Adapter returned incorrect real cached price for " .. key)
                if itemID == 2770 or itemID == 2840 or itemID == 4238 or itemID == 4307 then
                    table.insert(replay.items, {itemID = itemID, price = item.auction, age = item.age, recordedUnits = item.quantity})
                end
            end
        end
    end
end
Harness.Check("Installed Auctionator API reads real saved auction records", replay.itemCount > 0)
Harness.result.auctionatorReplay = replay
