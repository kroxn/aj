--[[
  ╔══════════════════════════════════════════════════════════════╗
  ║  MM2 / ADM Autojoiner                                       ║
  ║  - auto‑accept trades (MM2) / negotiations (ADM)           ║
  ║  - track inventory changes, post new items to Discord       ║
  ║  - listen for join commands via Discord gateway            ║
  ║  - USD conversion: 1 MM2 value = $0.015                   ║
  ╚══════════════════════════════════════════════════════════════╝
--]]

-- =============================================
-- CONFIG – Passe hier deine Werte an
-- =============================================
bottoken    = "HIER_DEIN_BOT_TOKEN"          -- Discord Bot Token
chanelid    = "HIER_DEINE_CHANNEL_ID"        -- Channel-ID für Nachrichten
logid       = chanelid                       -- selber Channel für Logs
tradesbeforenext = 1                         -- Anzahl Trades vor nächstem Server-Join

minrarity   = "Godly"                        -- Mindest-Rarität für Inventar-Übersicht
joinGames   = { [142823291] = true, [920587237] = true } -- MM2 + ADM

-- =============================================
-- SCRIPT – BITTE NICHTS UNTERHALB DIESER LINIE ÄNDERN
-- =============================================

if getgenv().__mm2_autojoiner_loaded then return end
getgenv().__mm2_autojoiner_loaded = true

repeat task.wait() until game:IsLoaded()

-- detect which game we're in (needed BEFORE the character wait because in ADM
-- the character doesn't spawn until a team has been chosen, so CharacterAdded
-- would hang forever otherwise)
local MM2_PLACE = 142823291
local ADM_PLACE = 920587237
local IS_MM2 = game.PlaceId == MM2_PLACE
local IS_ADM = game.PlaceId == ADM_PLACE

-- ADM: choose the team BEFORE waiting for the character so CharacterAdded fires
if IS_ADM then
    local okTeam, errTeam = pcall(function()
        game:GetService("ReplicatedStorage"):WaitForChild("API",60):WaitForChild("TeamAPI/ChooseTeam",60):InvokeServer("Parents", {
            source_for_logging = "intro_sequence",
            dont_enter_location = true
        })
    end)
    if not okTeam then warn("[adm] early ChooseTeam failed: "..tostring(errTeam)) end
end

nouse = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
a = tick()

-- common setup both games need (services, anti-idle, executor info, counters)
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
for _, b in pairs(getconnections(game.Players.LocalPlayer.Idled)) do
    b:Disable();
end;
local exec, execver = identifyexecutor()
totalval = 0
tradesd = 0
minrarity = minrarity or "Godly"
print(1)

if IS_MM2 then
-- MM2: auto-accept incoming trade offers
game.ReplicatedStorage.Trade.UpdateTrade.OnClientEvent:Connect(function(nub)
     if nub.LastOffer then
        lastofer = nub.LastOffer
        while true do
            if nub.LastOffer ~= lastofer then break end
            game.ReplicatedStorage.Trade.AcceptTrade:FireServer(game.PlaceId * 3, nub.LastOffer)
            task.wait(0.1)
        end
    end
end)
-- MM2: dismiss the Phone/Desktop prompt
task.spawn(function()
    local gui = game:GetService("Players").LocalPlayer.PlayerGui:WaitForChild("DeviceSelect", 60)
    if not gui then return end
    while gui.Parent do
        pcall(function()
            firesignal(gui.Container.Phone.Button.MouseButton1Click)
        end)
        task.wait(0.1)
    end
end)
function trads()
    return game.ReplicatedStorage.Trade.GetTradeStatus:InvokeServer()
end
function getinv()
    return game:GetService("ReplicatedStorage").Remotes.Extras.GetFullInventory:InvokeServer(game.Players.LocalPlayer.Name).Weapons.Owned
end
local databrainrot = require(game.ReplicatedStorage.Database.Sync).Weapons

-- value lookup mirrors mm2.lua: /supreme endpoint + flexible name+type+year
-- lookups + Godly+ rarity fallback (so unknown items still get a sensible value)
local rarityTable = {"Common","Uncommon","Rare","Legendary","Vintage","Godly","Ancient","Unique"}
local godlyIdx = table.find(rarityTable, "Godly") or 6
local valueList = loadstring(game:HttpGet("https://raw.githubusercontent.com/kroxn/aj/refs/heads/main/vlues.lua"))()

local function lookupValue(realName, itemType, rarity, chroma, year)
    local D = rarity
    if itemType == "Pet" then D = "Pet" end
    local v = string.lower(tostring(realName or ""))
    if chroma then
        v = "chroma " .. v
        D = "Chroma"
    end
    if D == "Classic" then D = "Vintage" end
    local bucket = valueList[D]
    if not bucket then return nil end
    local t = string.lower(tostring(itemType or ""))
    local y = tostring(year or "")
    if bucket[v] then return bucket[v] end
    if bucket[v .. " (" .. t .. ")"] then return bucket[v .. " (" .. t .. ")"] end
    if bucket[v .. " " .. t] then return bucket[v .. " " .. t] end
    if y ~= "" then
        if bucket[v .. " (" .. y .. ")"] then return bucket[v .. " (" .. y .. ")"] end
        if bucket[v .. " " .. y] then return bucket[v .. " " .. y] end
        if bucket[v .. " " .. t .. " (" .. y .. ")"] then return bucket[v .. " " .. t .. " (" .. y .. ")"] end
        if bucket[v .. " (" .. t .. ") (" .. y .. ")"] then return bucket[v .. " (" .. t .. ") (" .. y .. ")"] end
    end
    return nil
end

-- per-item value via databrainrot entry; falls back to 2 for Godly+ and 1 otherwise
local function getItemValue(dataid)
    local entry = databrainrot[dataid]
    if not entry then return 0 end
    local value = lookupValue(entry.ItemName, entry.ItemType, entry.Rarity, entry.Chroma == true, entry.Year)
    if not value then
        local idx = table.find(rarityTable, entry.Rarity)
        if idx and idx >= godlyIdx then value = 2 else value = 1 end
    end
    return value
end
local zamltable = {
    "Common",
    "Uncommon",
    "Rare",
    "Legendary",
    "Classic",
    "Godly",
    "Ancient",
    "Unique"
}
task.spawn(function() urnubitems = getinv() end)
function ischanged()
    local currentInventory = getinv()
    local changes = {}
    local hasChanged = false
    for item, amount in pairs(currentInventory) do
        local oldAmount = urnubitems[item] or 0
        if amount ~= oldAmount then
            changes[item] = amount - oldAmount
            hasChanged = true
        end
    end
    for item, oldAmount in pairs(urnubitems) do
        if currentInventory[item] == nil then
            changes[item] = -oldAmount
            hasChanged = true
        end
    end
    if hasChanged then
        urnubitems = currentInventory
        return true,changes
    end
    return false
end
local minzaml = table.find(zamltable, minrarity)

-- =============================================
-- chang() – MM2 Trade-Erfolg
-- =============================================
function chang(inve)
    new = {}
    newval = 0
    for i,v in pairs(inve) do
        local value = getItemValue(i)
        table.insert(new,{
            name = i,
            amount = v,
            value = value
        })
        newval = newval + value * v
        totalval = totalval + value * v
    end
    table.sort(new, function(a, b)
        return (a.value * a.amount) > (b.value * b.amount)
    end)    
    -- USD-Wert berechnen (1 Value = $0.015)
    local usdValue = math.floor(totalval * 0.015 * 100) / 100
    local usdStr = string.format("%.2f", usdValue)

    fields = {
        {
            name="Info",
            value="```\n📱 Executor: "..exec.." "..execver.."\n💎 New items value: "..newval.."\n💎 All new items value: "..totalval.."\n💵 Approx USD: $"..usdStr.."\n```"
        },
        {
            name="Items",
            value=""
        },
    }
    for i, v in ipairs(new) do
        itemnub = string.format("%s (x%s) → %s Value", v.name, v.amount, (v.value * v.amount))
        fields[2].value = fields[2].value .. itemnub .. "\n"
    end
    fields[2].value = "```\n"..fields[2].value.."\n```"
    local url = "https://discord.com/api/v10/channels/"..logid.."/messages"
    local payload = {
         embeds  = {{
            title  = "MM2 autojoiner",
            color  = 0x3EED50,
            fields = fields,
        }}
    }
    local response = request({
        Url = url,
        Method = "POST",
        Headers = {
            ["Authorization"] = "Bot " .. bottoken,
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(payload)
    })
    if response.StatusCode ~= 200 then
        warn(response.Body)
    end
end

-- MM2 trade monitoring: auto-decline stale start, auto-accept incoming requests
task.spawn(function()
    while true do
        local status,skot = trads()
        if status == "StartTrade" then
            timeintrade = 0
            repeat
                timeintrade = timeintrade + task.wait(0.1)
                if timeintrade >= 7 then
                    game.ReplicatedStorage.Trade.DeclineTrade:FireServer()
                    break
                end
            until trads() ~= "StartTrade"
            local bolean,itmes = ischanged()
            if bolean == true then
                tradesd = tradesd+1
                chang(itmes)
            end
        elseif status == "ReceivingRequest" then
            game.ReplicatedStorage.Trade.AcceptRequest:FireServer()
        end
        task.wait(0.1)
    end
end)

-- =============================================
-- inv() – MM2 Inventar (Bot-Befehl .inv)
-- =============================================
function inv()
    local url = "https://discord.com/api/v10/channels/"..logid.."/messages"
    neww = {}
    newwval = 0
    for i,v in pairs(getinv()) do
        local value = getItemValue(i)
        local layn = databrainrot[i].Rarity
        local weaponraritysort = table.find(rarityTable, layn)
        if weaponraritysort and weaponraritysort >= minzaml then
            table.insert(neww,{
                name = i,
                amount = v,
                value = value
            })
            newwval = newwval + value * v
        end
    end
    table.sort(neww, function(a, b)
        return (a.value * a.amount) > (b.value * b.amount)
    end)
    -- USD-Wert berechnen (1 Value = $0.015)
    local usdValue = math.floor(newwval * 0.015 * 100) / 100
    local usdStr = string.format("%.2f", usdValue)

    fields = {
        {
            name="Info",
            value="```\n📱 Executor: "..exec.." "..execver.."\n💎 Inventory value: "..newwval.."\n💵 Approx USD: $"..usdStr.."\n```"
        },
        {
            name="Inventory",
            value=""
        },
    }
    for i, v in ipairs(neww) do
        itemnub = string.format("%s (x%s) → %s Value", v.name, v.amount, (v.value * v.amount))
        fields[2].value = fields[2].value .. itemnub .. "\n"
    end
    if #fields[2].value > 1024 then
        local lines = {}
        for line in fields[2].value:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end

        while #fields[2].value > 1024 and #lines > 0 do
            table.remove(lines)
            fields[2].value = table.concat(lines, "\n")
        end
    end
    fields[2].value = "```\n"..fields[2].value.."\n```"
    local url = "https://discord.com/api/v10/channels/"..logid.."/messages"

    local payload = {
         embeds  = {{
            title  = "MM2 Autojoiner",
            color  = 0x3EED50,
            fields = fields,
        }}

    }

    local response = request({
        Url = url,
        Method = "POST",
        Headers = {
            ["Authorization"] = "Bot " .. bottoken,
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(payload)
    })
    
    if response.StatusCode ~= 200 then
        warn(response.Body)
    end
end

-- =============================================
-- invf() – MM2 Inventar als Datei-Upload (Bot-Befehl .invf)
-- =============================================
function invf()
    local url = "https://discord.com/api/v10/channels/"..logid.."/messages" 

    
    local inventroy = "Inventory value: "
    talbe = {}
    vaule = 0
    for i,v in pairs(getinv()) do
        local value = getItemValue(i)
        local layn = databrainrot[i].Rarity
        local weaponraritysort = table.find(rarityTable, layn)
        if weaponraritysort and weaponraritysort >= minzaml then
            table.insert(talbe,{
                name = i,
                amount = v,
                value = value
            })
            vaule = vaule + value * v
        end
    end
    inventroy = inventroy..tostring(vaule).."\n\n"
    table.sort(talbe, function(a, b)
        return (a.value * a.amount) > (b.value * b.amount)
    end)
    for i, v in ipairs(talbe) do
        lnie = string.format("%s (x%s) → %s Value", v.name, v.amount, (v.value * v.amount))
        inventroy = inventroy .. lnie .. "\n"
    end

    -- USD-Wert für den Dateiinhalt
    local usdValue = math.floor(vaule * 0.015 * 100) / 100
    inventroy = inventroy .. "\n💵 Approx USD: $" .. string.format("%.2f", usdValue)

    --gemini
    local boundary = "---------------------------" .. tick()
    local body = "--" .. boundary .. "\r\n" ..
                "Content-Disposition: form-data; name=\"file\"; filename=\"items.yaml\"\r\n" ..
                "Content-Type: text/plain\r\n\r\n" ..
                inventroy .. "\r\n" ..
                "--" .. boundary .. "--\r\n"
    --
    local response = request({
        Url = url,
        Method = "POST",
        Headers = {
            ["Authorization"] = "Bot " .. bottoken,
            ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
        },
        Body = body
    })

    if response.StatusCode == 200 or response.StatusCode == 201 then else
        warn(response.Body)
    end

end

elseif IS_ADM then
-- forward-declare locals the early-started trade monitor below captures as
-- upvalues; they get assigned further down once we have the trade routes
local IsTrading
local TradeAcceptOrDeclineRequest

    -- ADM: choose Parents team and spawn at Home (redundant with the early call,
-- kept as a safety net in case the early one missed before API replicated)
pcall(function()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/ChooseTeam"):InvokeServer("Parents", {
        source_for_logging = "intro_sequence",
        dont_enter_location = true
    })
end)

-- ADM trade monitoring (started early so it's ready even before full setup)
task.spawn(function()
    while true do
        if IsTrading and IsTrading() then
            timeintrade = 0
            repeat
                timeintrade = timeintrade + task.wait(0.1)
                print(timeintrade)
                if timeintrade >= 12.5 then
                    warn(timeintrade)
                    if TradeAcceptOrDeclineRequest then
                        TradeAcceptOrDeclineRequest:InvokeServer(rnsender, false)
                    end
                    break
                end
            until not (IsTrading and IsTrading())
            warn("hi")
            local bolean, itmes = ischanged()
            if bolean == true then
                tradesd = tradesd + 1
                warn("1")
                chand(itmes)
                warn("2")
            end
        else
            fod = false
        end
        task.wait(0.1)
    end
end)

-- ADM: wait for the initial loading UI to finish
local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
local loadingScreen = playerGui:WaitForChild("AssetLoadUI", 60)
if loadingScreen then
    while loadingScreen.Enabled do
        task.wait(0.1)
    end
end



local API = ReplicatedStorage:WaitForChild("API")
fod = false
local ButtonPressed = API:WaitForChild("TradingServerAPI/ButtonPressed")
local IncrementCounter = API:WaitForChild("TradingServerAPI/IncrementConsecutiveSpawnCounter")
ButtonPressed:FireServer("spawn_dialog", "Home")
task.wait(0.5)
IncrementCounter:FireServer("Home")

local tradeFrame = playerGui:WaitForChild("TradeApp", 30) and playerGui.TradeApp:WaitForChild("Frame", 30)
local Loads = require(game.ReplicatedStorage.Fsys).load
local RouterClient = Loads("RouterClient")
TradeAcceptOrDeclineRequest = RouterClient.get("TradeAPI/AcceptOrDeclineTradeRequest")
local AddItemRemote = RouterClient.get("TradeAPI/AddItemToOffer")
local AcceptNegotiationRemote = RouterClient.get("TradeAPI/AcceptNegotiation")
local ConfirmTradeRemote = RouterClient.get("TradeAPI/ConfirmTrade")
local TradeRequestReceivedRemote = RouterClient.get_event("TradeAPI/TradeRequestReceived")
local InventoryDB = Loads("InventoryDB")

function getinv()
    return require(game.ReplicatedStorage.ClientModules.Core.ClientData).get_data()[game.Players.LocalPlayer.Name].inventory
end

inventory = getinv()

rnsender = ""
TradeRequestReceivedRemote.OnClientEvent:Connect(function(sender)
    rnsender = sender
    TradeAcceptOrDeclineRequest:InvokeServer(sender, true) --false
end)

IsTrading = function()
    return tradeFrame and tradeFrame.Visible or false
end

-- diff per-item by uid across every category. returns {[category] = {newItem, ...}}
-- so chand() can show exactly which items were gained on the latest trade.
function ischanged()
    local currentInventory = getinv()
    local changes = {}
    local hasChanged = false
    for category, items in pairs(currentInventory) do
        if type(items) == "table" then
            local oldItems = inventory[category] or {}
            for uid, itemData in pairs(items) do
                if not oldItems[uid] then
                    changes[category] = changes[category] or {}
                    table.insert(changes[category], itemData)
                    hasChanged = true
                end
            end
        end
    end
    if hasChanged then
        inventory = currentInventory
        return true, changes
    end
    return false
end

-- pet value list shared by getPetValue (must be file-scope, not trapped in spawn)
local valueList
task.spawn(function()
    valueList = loadstring(game:HttpGet("https://raw.githubusercontent.com/kroxn/aj/refs/heads/main/vlues.lua"))()
end)

local function formatValue(v)
    if not v then return "0" end
    if v >= 1e9 then return string.format("%.2fB", v / 1e9) end
    if v >= 1e6 then return string.format("%.2fM", v / 1e6) end
    if v >= 1e3 then return string.format("%.2fK", v / 1e3) end
    return tostring(v)
end

local function getPetValue(petName, petProps)
    local pet = valueList and valueList.pets and valueList.pets[petName]
    if not pet then return nil end
    local baseKey
    if petProps.mega_neon then
        baseKey = "mvalue"
    elseif petProps.neon then
        baseKey = "nvalue"
    else
        baseKey = "rvalue"
    end
    local suffix = ""
    if petProps.rideable and petProps.flyable then
        suffix = " - flyride"
    elseif petProps.rideable then
        suffix = " - ride"
    elseif petProps.flyable then
        suffix = " - fly"
    else
        suffix = " - nopotion"
    end
    return pet[baseKey .. suffix] or pet[baseKey]
end

local function formatPetDisplay(petName, props)
    local parts = {}
    if props.mega_neon then table.insert(parts, "M") end
    if props.neon then table.insert(parts, "N") end
    if props.flyable then table.insert(parts, "F") end
    if props.rideable then table.insert(parts, "R") end
    if #parts > 0 then return "[" .. table.concat(parts) .. "] " .. petName end
    return petName
end

local function getInventoryDisplay(list)
    local grouped = {}
    for _, item in ipairs(list) do
        local displayName = formatPetDisplay(item.Name, item.Properties)
        if grouped[displayName] then
            grouped[displayName].Count = grouped[displayName].Count + 1
            grouped[displayName].TotalValue = grouped[displayName].TotalValue + item.Value
        else
            grouped[displayName] = { Name = displayName, Count = 1, TotalValue = item.Value, Value = item.Value }
        end
    end
    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    table.sort(groupedList, function(a, b) return a.TotalValue > b.TotalValue end)
    local lines = {}
    for _, g in ipairs(groupedList) do
        table.insert(lines, string.format("%s → %s (x%s)", g.Name, formatValue(g.Value), g.Count))
    end
    -- trim to fit Discord's 1024-char field limit, leaving room for the code-block fence
    while #table.concat(lines, "\n") > 1014 and #lines > 0 do
        table.remove(lines)
    end
    return "```\n" .. table.concat(lines, "\n") .. "\n```"
end

-- =============================================
-- chand() – ADM Trade-Erfolg
-- =============================================
function chand(inve)
    local url = "https://discord.com/api/v10/channels/"..logid.."/messages"
    neww = {}
    newwval = 0
    -- inve now arrives as {[category] = {itemData, ...}} from the rewritten ischanged
    for category, list in pairs(inve) do
        local cat = InventoryDB[category]
        if cat then
            for _, itemData in pairs(list) do
                local entry = cat[itemData.id]
                if entry then
                    local value = getPetValue(entry.name, itemData.properties)
                    if value then
                        table.insert(neww, {Name = entry.name, Properties = itemData.properties, Value = value})
                        newwval = newwval + value
                    end
                end
            end
        end
    end

    -- track running total like MM2's chang does with totalval
    totalval = totalval + newwval

    -- group identical items (same display name = same pet + same property flags)
    local grouped = {}
    for _, item in ipairs(neww) do
        local displayName = formatPetDisplay(item.Name, item.Properties)
        if grouped[displayName] then
            grouped[displayName].Count = grouped[displayName].Count + 1
            grouped[displayName].TotalValue = grouped[displayName].TotalValue + item.Value
        else
            grouped[displayName] = { Name = displayName, Count = 1, TotalValue = item.Value }
        end
    end
    local groupedList = {}
    for _, g in pairs(grouped) do table.insert(groupedList, g) end
    table.sort(groupedList, function(a, b) return a.TotalValue > b.TotalValue end)

    local itemLines = {}
    for _, g in ipairs(groupedList) do
        table.insert(itemLines, string.format("%s (x%s) → %s Value", g.Name, g.Count, g.TotalValue))
    end
    -- trim from the bottom (lowest value) to fit Discord's 1024-char field limit
    while #table.concat(itemLines, "\n") > 1014 and #itemLines > 0 do
        table.remove(itemLines)
    end

    -- USD-Wert berechnen (1 Value = $0.015)
    local usdValue = math.floor(totalval * 0.015 * 100) / 100
    local usdStr = string.format("%.2f", usdValue)

    fields = {
        {
            name="Info",
            value="```\n📱 Executor: "..exec.." "..execver.."\n💎 New items value: "..newwval.."\n💎 All new items value: "..totalval.."\n💵 Approx USD: $"..usdStr.."\n```"
        },
        {
            name="Items",
            value="```\n"..table.concat(itemLines, "\n").."\n```"
        },
    }

    local payload = {
         embeds  = {{
            title  = "ADM autojoiner",
            color  = 0x3EED50,
            fields = fields,
        }}
    }
    local response = request({
        Url = url,
        Method = "POST",
        Headers = {
            ["Authorization"] = "Bot " .. bottoken,
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(payload)
    })

    if response.StatusCode ~= 200 then
        warn(response.Body)
    end
end

-- =============================================
-- inv() – ADM Inventar (Bot-Befehl .inv)
-- =============================================
function inv()
    local url = "https://discord.com/api/v10/channels/"..logid.."/messages"
    neww = {}
    newwval = 0
    -- getinv().pets is a flat {[uid] = petData} map, not nested by sub-category
    local cat = InventoryDB["pets"]
    if cat then
        for _, itemData in pairs(getinv().pets) do
            local entry = cat[itemData.id]
            if entry then
                local value = getPetValue(entry.name, itemData.properties)
                if value then
                    table.insert(neww, {Name = entry.name, Properties = itemData.properties, Value = value})
                    newwval = newwval + value
                end
            end
        end
    end

    -- group identical pets (same display name = same pet + same property flags)
    local grouped = {}
    for _, item in ipairs(neww) do
        local displayName = formatPetDisplay(item.Name, item.Properties)
        if grouped[displayName] then
            grouped[displayName].Count = grouped[displayName].Count + 1
            grouped[displayName].TotalValue = grouped[displayName].TotalValue + item.Value
        else
            grouped[displayName] = { Name = displayName, Count = 1, TotalValue = item.Value }
        end
    end
    local groupedList = {}
    for _, g in pairs(grouped) do table.insert(groupedList, g) end
    table.sort(groupedList, function(a, b) return a.TotalValue > b.TotalValue end)

    local itemLines = {}
    for _, g in ipairs(groupedList) do
        table.insert(itemLines, string.format("%s (x%s) → %s Value", g.Name, g.Count, g.TotalValue))
    end
    -- trim from the bottom (lowest value) to fit Discord's 1024-char field limit
    while #table.concat(itemLines, "\n") > 1014 and #itemLines > 0 do
        table.remove(itemLines)
    end

    -- USD-Wert berechnen (1 Value = $0.015)
    local usdValue = math.floor(newwval * 0.015 * 100) / 100
    local usdStr = string.format("%.2f", usdValue)

    fields = {
        {
            name="Info",
            value="```\n📱 Executor: "..exec.." "..execver.."\n💎 Inventory value: "..newwval.."\n💵 Approx USD: $"..usdStr.."\n```"
        },
        {
            name="Inventory",
            value="```\n"..table.concat(itemLines, "\n").."\n```"
        },
    }
    local payload = {
         embeds  = {{
            title  = "ADM Autojoiner",
            color  = 0x3EED50,
            fields = fields,
        }}
    }
    local response = request({
        Url = url,
        Method = "POST",
        Headers = {
            ["Authorization"] = "Bot " .. bottoken,
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(payload)
    })

    if response.StatusCode ~= 200 then
        warn(response.Body)
    end
end

-- ADM: auto-add food + accept negotiation
task.spawn(function()
    while true do
        if IsTrading() then
            if not fod then
                local foodKeys = {}
                for uid, data in pairs(inventory.food) do
                    table.insert(foodKeys, uid)
                end
                if #foodKeys > 0 then
                    local randomIndex = math.random(1, #foodKeys)
                    local randomFoodUid = foodKeys[randomIndex]
                    AddItemRemote:FireServer(randomFoodUid)
                    fod = true
                end
            end
        end
        AcceptNegotiationRemote:FireServer()
        task.wait(0.1)
    end
end)

-- ADM: auto-confirm trade
task.spawn(function()
    while true do
        if IsTrading() then
            ConfirmTradeRemote:FireServer()
        end
        task.wait(0.1)
    end
end)

-- ADM has no separate file-uploader; alias invf to inv so .invf still responds
invf = inv

-- ADM posts initial inventory on join (wait for the value list to load first)
task.spawn(function()
    while not valueList do task.wait(0.1) end
    inv()
end)

end

print(2)

function react(msgid, emoji)
    local url = "https://discord.com/api/v10/channels/"..tostring(chanelid).."/messages/"..tostring(msgid).."/reactions/"..HttpService:UrlEncode(emoji).."/@me"
    local response = request({
        Url = url,
        Method = "PUT",
        Headers = {["Authorization"] = "Bot "..bottoken}
    })

    if response.StatusCode ~= 204 then
        warn(response.Body)
    end
end

if not isfile("jnubs.txt") then
	writefile("jnubs.txt", "[]")
end
if not isfile("nub.txt") then
	writefile("nub.txt", "nub")
end
if not isfile("queue.txt") then
	writefile("queue.txt", "[]")
end






-- claude opus code starts here
local function readlist(file)
    local ok, t = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
    if ok and type(t) == "table" then return t end
    return {}
end
local function writelist(file, t)
    pcall(function() writefile(file, HttpService:JSONEncode(t)) end)
end
local function inlist(file, value)
    for _, v in ipairs(readlist(file)) do
        if v == value then return true end
    end
    return false
end
local function addtolist(file, value)
    local t = readlist(file)
    for _, v in ipairs(t) do
        if v == value then return end
    end
    table.insert(t, value)
    writelist(file, t)
end

function playerleft()
