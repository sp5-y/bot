--[[ MM2 Helper Bot ]]--
local Players = game:GetService("Players")
local cref = cloneref or function(x) return x end
local TCS = cref(game:GetService("TextChatService"))
local Tween = game:GetService("TweenService")
local RunSvc = game:GetService("RunService")
local RS = cref(game:GetService("ReplicatedStorage"))
local Http = cref(game:GetService("HttpService"))
local Stats = cref(game:GetService("Stats"))
local StarterGui = cref(game:GetService("StarterGui"))
local TeleportSvc = cref(game:GetService("TeleportService"))
local isLegacy = TCS.ChatVersion == Enum.ChatVersion.LegacyChatService
local me, cam = Players.LocalPlayer, workspace.CurrentCamera
local UIS = cref(game:GetService("UserInputService"))
local DEFAULT_FOV, WIDE_FOV = 70, 100
local SPAWN_CFRAME = CFrame.new(14.3513288, 505.044952, -58.2513657, 1, 0, 0, 0, 1, 0, 0, 0, 1)
local toggleGun = false
local toggleAlerts = false
local toggleReveal = true
local toggleResetOnOwnerDeath = false
local toggleDrop = false
local gunTargetId = nil
local gunDelivered = false
local hopBusy = false
local PING_MIN_MS, PING_MAX_MS = 50, 90
local G = getgenv and getgenv() or _G
local XENO_OWNER_USERNAME = tostring(G.XENO_OWNER_USERNAME or G.XENO_OWNER or G.MM_OwnerUsername or ""):match("^%s*(.-)%s*$") or ""
local bridgeOwnerConnected = false
G.MM_HopState = G.MM_HopState or {pingSearchActive = false}
local hopState = G.MM_HopState
_G.MM_StabBusy = _G.MM_StabBusy or false
_G.MM_GunBusy = _G.MM_GunBusy or false
_G.MM_OwnerDiedPendingReset = _G.MM_OwnerDiedPendingReset or false
local OWNER_MURD_GUN_MSG = "Gun unavailable"
local OWNER_MURD_STASH_COOLDOWN = 3
G.MM_OwnerPremium = true

--[[ Session ]]--
if getgenv and getgenv().MM_Session then getgenv().MM_Session.active = false end
if game.CoreGui:FindFirstChild("MM") then game.CoreGui.MM:Destroy() end
local session = {active = true, ownerId = nil}
if getgenv then getgenv().MM_Session = session end
do
    local pending = tonumber(G.MM_PendingOwnerId)
    if pending and pending > 0 then
        session.ownerId = pending
    end
end
cam.FieldOfView = DEFAULT_FOV
do local h = me.Character and me.Character:FindFirstChildOfClass("Humanoid") 
   if h then cam.CameraSubject = h end end

--[[ Background mode (low CPU, muted, no 3D) ]]--
-- Hold RightAlt to disable. Auto-disables when script is re-executed.
task.spawn(function()
    local UIS = game:GetService("UserInputService")
    local VU = game:GetService("VirtualUser")
    local RunSvc = game:GetService("RunService")
    local UGS = UserSettings():GetService("UserGameSettings")
    local origQuality = settings().Rendering.QualityLevel
    local origVolume = UGS.MasterVolume
    UGS.MasterVolume = 0
    pcall(function()
        Players.LocalPlayer.Idled:Connect(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.new(math.random(10, 50), math.random(10, 50)))
        end)
    end)
    while session.active and not UIS:IsKeyDown(Enum.KeyCode.RightAlt) do
        pcall(function()
            if setfpscap then setfpscap(15) end
            settings().Rendering.QualityLevel = 1
            RunSvc:Set3dRenderingEnabled(false)
        end)
        task.wait(1)
    end
    pcall(function()
        RunSvc:Set3dRenderingEnabled(true)
        settings().Rendering.QualityLevel = origQuality
        UGS.MasterVolume = origVolume
        if setfpscap then setfpscap(60) end
    end)
end)

--[[ GUI ]]--
local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name, gui.ResetOnSpawn = "MM", false
local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0, 140, 0, 180), UDim2.new(1, -150, 0, 10)
f.BackgroundColor3, f.Visible = Color3.fromRGB(20, 20, 20), false
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
local img = Instance.new("ImageLabel", f)
img.Size, img.Position, img.BackgroundTransparency = UDim2.new(1, -10, 1, -40), UDim2.new(0, 5, 0, 5), 1
local lbl = Instance.new("TextLabel", f)
lbl.Size, lbl.Position, lbl.BackgroundTransparency = UDim2.new(1, -10, 0, 28), UDim2.new(0, 5, 1, -32), 1
lbl.TextColor3, lbl.Font, lbl.TextScaled = Color3.new(1, 0, 0), Enum.Font.GothamBold, true

--[[ Log GUI ]]--
local logFrame = Instance.new("Frame", gui)
logFrame.Size = UDim2.new(0, 260, 0, 130)
logFrame.Position = UDim2.new(1, -270, 1, -140)
logFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
logFrame.BackgroundTransparency = 0.3
logFrame.BorderSizePixel = 0
Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 6)
local logList = Instance.new("UIListLayout", logFrame)
logList.SortOrder = Enum.SortOrder.LayoutOrder
logList.Padding = UDim.new(0, 1)
local logPad = Instance.new("UIPadding", logFrame)
logPad.PaddingLeft, logPad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
logPad.PaddingTop, logPad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
local logCounter = 0
local function log(msg)
    logCounter = logCounter + 1
    local order = logCounter
    local t = Instance.new("TextLabel", logFrame)
    t.Size = UDim2.new(1, 0, 0, 14)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.Code
    t.TextSize = 12
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextColor3 = Color3.fromRGB(180, 230, 180)
    t.Text = "[" .. os.date("%X") .. "] " .. tostring(msg)
    t.LayoutOrder = order
    t.TextTruncate = Enum.TextTruncate.AtEnd
    local kids = logFrame:GetChildren()
    local labels = {}
    for _, c in ipairs(kids) do
        if c:IsA("TextLabel") then table.insert(labels, c) end
    end
    table.sort(labels, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #labels > 8 do
        labels[1]:Destroy()
        table.remove(labels, 1)
    end
end

--[[ Finders ]]--
local function hasItem(parent, names)
    for _, c in ipairs(parent and parent:GetChildren() or {}) do
        if table.find(names, c.Name) then return true end
    end
end
local function playerHas(p, names)
    return hasItem(p.Character, names) or hasItem(p:FindFirstChildOfClass("Backpack"), names)
end
local function findHolder(names)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me and playerHas(p, names) then return p end
    end
end
local function botHasGun() return playerHas(me, {"Gun", "Revolver"}) end
local function botHasKnife() return playerHas(me, {"Knife"}) end
local function findDroppedGun()
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Tool") and (o.Name == "Gun" or o.Name == "Revolver" or o.Name == "GunDrop")
           and not Players:GetPlayerFromCharacter(o.Parent) then
            local h = o:FindFirstChild("Handle") or o:FindFirstChildWhichIsA("BasePart")
            if h then return h end
        end
    end
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") and o.Name == "GunDrop" then return o end
    end
end

local function findPlayer(q)
    if not q or q == "" then return end
    q = q:lower()
    local best, bestScore
    for _, p in ipairs(Players:GetPlayers()) do
        local n, d = p.Name:lower(), p.DisplayName:lower()
        local i = n:find(q, 1, true) or d:find(q, 1, true)
        if i then
            local score = i + math.abs(#n - #q)
            if not bestScore or score < bestScore then best, bestScore = p, score end
        end
    end
    return best
end
local function findOwner()
    if not session.ownerId then return end
    return Players:GetPlayerByUserId(session.ownerId)
end
local scheduleOwnerOnboarding
local function configuredOwnerMatches(p)
    if not p or XENO_OWNER_USERNAME == "" then return false end
    local q = XENO_OWNER_USERNAME:lower()
    return p.Name:lower() == q or tostring(p.DisplayName or ""):lower() == q
end
local function findConfiguredOwner()
    if XENO_OWNER_USERNAME == "" then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me and configuredOwnerMatches(p) then
            return p
        end
    end
    return nil
end
local function syncConfiguredOwner()
    local p = findConfiguredOwner()
    if not bridgeOwnerConnected then
        if session.ownerId then
            session.ownerId = nil
            G.MM_PendingOwnerId = nil
        end
        return p
    end
    if p and session.ownerId ~= p.UserId then
        session.ownerId = p.UserId
        G.MM_PendingOwnerId = p.UserId
        toggleResetOnOwnerDeath = false
        toggleDrop = false
        _G.MM_OwnerDiedPendingReset = false
        scheduleOwnerOnboarding(p.UserId)
        log("configured owner found: " .. p.Name)
    elseif not p and session.ownerId then
        local current = Players:GetPlayerByUserId(session.ownerId)
        if not current or (XENO_OWNER_USERNAME ~= "" and not configuredOwnerMatches(current)) then
            session.ownerId = nil
            G.MM_PendingOwnerId = nil
        end
    end
    return p
end
local function shortName(p) return p.Name:sub(1, 4) .. "..." end

local function bridgePlayerLabel(p)
    if not p then return "?" end
    local dn = p.DisplayName
    if type(dn) == "string" and dn ~= "" then return dn end
    return p.Name
end

local function isOwnerPlayer(p)
    return p and session.ownerId and p.UserId == session.ownerId
end

local function bridgeTargetLabel(p)
    if not p then return "?" end
    if isOwnerPlayer(p) then return "you" end
    return bridgePlayerLabel(p)
end

local function commandTargetLabel(p)
    if not p then return "?" end
    if isOwnerPlayer(p) then return "you" end
    return shortName(p)
end
local function restOfChatArgs(args)
    if not args or #args < 2 then return "" end
    return (table.concat(args, " ", 2)):match("^%s*(.-)%s*$") or ""
end
-- Like findPlayer but never the bot; prefers exact username/display match (matches bot.lua intent for combat targets).
local function findOtherPlayer(q)
    if not q or q == "" then return end
    q = tostring(q):lower()
    local exactN, exactD, best, bestScore
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= me then
            local nl, dl = pl.Name:lower(), tostring(pl.DisplayName or ""):lower()
            if nl == q then exactN = pl end
            if dl == q then exactD = pl end
            local i = nl:find(q, 1, true) or dl:find(q, 1, true)
            if i then
                local score = i + math.abs(#nl - #q)
                if not bestScore or score < bestScore then best, bestScore = pl, score end
            end
        end
    end
    return exactN or exactD or best
end
local function getHeldTool(p, names)
    for _, container in ipairs({p.Character, p:FindFirstChildOfClass("Backpack")}) do
        for _, c in ipairs(container and container:GetChildren() or {}) do
            if c:IsA("Tool") and table.find(names, c.Name) then
                return c
            end
        end
    end
end
--[[ Chat / Whisper ]]--
local function sendChat(msg)
    if not msg or msg == "" then return end
    msg = tostring(msg)
    pcall(function()
        if not isLegacy then TCS.TextChannels.RBXGeneral:SendAsync(msg)
        else RS.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All") end
    end)
end
local function sendBrandingPromo()
end
local function findWhisperChannel(uid)
    uid = tostring(uid)
    for _, ch in ipairs(TCS.TextChannels:GetChildren()) do
        if ch:IsA("TextChannel") and ch.Name:match("RBXWhisper") then
            if tostring(ch.Name):find(uid, 1, true) then
                return ch
            end
        end
    end
end
local function pollWhisperChannel(uid, duration)
    local t0 = tick()
    while tick() - t0 < duration do
        local ch = findWhisperChannel(uid)
        if ch then return ch end
        task.wait(0.08)
    end
    return findWhisperChannel(uid)
end
local function whisperTargets(o)
    local targets = {}
    local dn = tostring(o.DisplayName or ""):gsub("^@", "")
    if dn ~= "" then
        table.insert(targets, dn)
    end
    if o.Name and o.Name ~= "" and o.Name ~= dn then
        table.insert(targets, o.Name)
    end
    return targets
end
-- TextChatService often has no RBXWhisper channel until a /w line is sent on RBXGeneral first.
local function ensureWhisperChannel(o)
    local ch = findWhisperChannel(o.UserId)
    if ch then return ch end
    for _, handle in ipairs(whisperTargets(o)) do
        pcall(function()
            TCS.TextChannels.RBXGeneral:SendAsync("/w " .. handle .. " .")
        end)
        ch = pollWhisperChannel(o.UserId, 2.2)
        if ch then return ch end
    end
    return findWhisperChannel(o.UserId)
end
local function whisper(m, target)
    local o = target or findOwner()
    if not o then log("whisper: no target") return end
    log("-> " .. o.DisplayName .. ": " .. m)
    pcall(function()
        if isLegacy then
            for _, handle in ipairs(whisperTargets(o)) do
                if pcall(function()
                    RS.DefaultChatSystemChatEvents.SayMessageRequest:FireServer("/w " .. handle .. " " .. m, "All")
                end) then
                    return
                end
            end
            return
        end
        local ch = ensureWhisperChannel(o)
        local function sendOnChannel(chan)
            if not chan then return false end
            return pcall(function() chan:SendAsync(m) end)
        end
        if sendOnChannel(ch) then return end
        task.wait(0.22)
        ch = findWhisperChannel(o.UserId) or ensureWhisperChannel(o)
        if sendOnChannel(ch) then return end
        for _, handle in ipairs(whisperTargets(o)) do
            if pcall(function()
                TCS.TextChannels.RBXGeneral:SendAsync("/w " .. handle .. " " .. m)
            end) then
                return
            end
        end
    end)
end
local function whisperOk(m, target)
    local o = target or findOwner()
    if not o then return false end
    log("-> " .. o.DisplayName .. ": " .. m)
    if isLegacy then
        for _, handle in ipairs(whisperTargets(o)) do
            local ok = pcall(function()
                RS.DefaultChatSystemChatEvents.SayMessageRequest:FireServer("/w " .. handle .. " " .. m, "All")
            end)
            if ok then return true end
        end
        return false
    end
    local ch = ensureWhisperChannel(o)
    local function sendOnChannel(chan)
        if not chan then return false end
        return pcall(function() chan:SendAsync(m) end)
    end
    if sendOnChannel(ch) then return true end
    task.wait(0.22)
    ch = findWhisperChannel(o.UserId) or ensureWhisperChannel(o)
    if sendOnChannel(ch) then return true end
    for _, handle in ipairs(whisperTargets(o)) do
        local ok = pcall(function()
            TCS.TextChannels.RBXGeneral:SendAsync("/w " .. handle .. " " .. m)
        end)
        if ok then return true end
    end
    return false
end

local hiddenChatEvent = nil
local function getHiddenChatEvent()
    if hiddenChatEvent and hiddenChatEvent.Parent then return hiddenChatEvent end
    local ok, events = pcall(function()
        return RS:WaitForChild("DefaultChatSystemChatEvents", 10)
    end)
    if not ok or not events then return end
    ok, hiddenChatEvent = pcall(function()
        return events:WaitForChild("OnMessageDoneFiltering", 10)
    end)
    if ok then return hiddenChatEvent end
end
task.spawn(getHiddenChatEvent)
local recentCommandKeys = {}
local function cleanChatText(msg)
    return tostring(msg or ""):gsub("[\n\r]", ""):gsub("\t", " "):gsub("[ ]+", " ")
end
local function seenCommandRecently(p, msg)
    msg = tostring(msg or "")
    if msg == "" then return true end
    local key = tostring(p.UserId) .. "\0" .. msg
    local now = tick()
    local last = recentCommandKeys[key]
    recentCommandKeys[key] = now
    if last and now - last < 1.5 then return true end
    task.delay(3, function()
        if recentCommandKeys[key] == now then
            recentCommandKeys[key] = nil
        end
    end)
    return false
end
local function showHiddenChat(p, msg)
    local text = "{SPY} [" .. (p.DisplayName or p.Name) .. "]: " .. msg
    log(text)
    pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = text,
            Color = Color3.fromRGB(0, 255, 255),
            Font = Enum.Font.SourceSansBold,
            TextSize = 18,
        })
    end)
end

local function httpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and body then return body end
    local requestFn = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    if not requestFn then return end
    ok, body = pcall(function()
        return requestFn({Url = url, Method = "GET"})
    end)
    if not ok or not body then return end
    return body.Body or body.body or body
end

local function httpJson(method, url, payload)
    local body = payload and Http:JSONEncode(payload) or nil
    local headers = {["Content-Type"] = "application/json"}
    local bridgeKey = (getgenv and getgenv().XENO_BRIDGE_KEY) or ""
    if bridgeKey ~= "" then headers["X-Xeno-Key"] = bridgeKey end
    local requestFn = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
    if requestFn then
        local ok, res = pcall(function()
            return requestFn({
                Url = url,
                Method = method,
                Headers = headers,
                Body = body,
            })
        end)
        if ok and res then
            local raw = res.Body or res.body or res
            if type(raw) == "string" and raw ~= "" then return raw end
        end
    end
    if method == "GET" and not body then
        return httpGet(url)
    end
end

local function queuePingSearchOnTeleport()
    local queueFn = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
    if not queueFn then return end
    pcall(function()
        queueFn([[
pcall(function()
    local g = getgenv and getgenv() or _G
    g.MM_HopState = g.MM_HopState or {}
    g.MM_HopState.pingSearchActive = true
end)
]])
    end)
end

local function queueRegionSpreadOnTeleport()
    local queueFn = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
    if not queueFn then return end
    pcall(function()
        queueFn([[
pcall(function()
    local g = getgenv and getgenv() or _G
    g.MM_RegionSpreadCheck = true
end)
]])
    end)
end

local function queueOwnerPersistOnTeleport(ownerId)
    if not ownerId then return end
    local queueFn = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
    if not queueFn then return end
    pcall(function()
        queueFn(([[
pcall(function()
    local g = getgenv and getgenv() or _G
    g.MM_PendingOwnerId = %d
end)
]]):format(math.floor(ownerId)))
    end)
end

G.MM_HopSeenServers = G.MM_HopSeenServers or {}
G.MM_HopSeenHour = G.MM_HopSeenHour or os.date("!*t").hour

local function hopSeenResetIfNeeded()
    local h = tonumber(os.date("!*t").hour) or 0
    if tonumber(G.MM_HopSeenHour) ~= h then
        G.MM_HopSeenServers = {}
        G.MM_HopSeenHour = h
    end
end

local function hopIsSeen(serverId)
    hopSeenResetIfNeeded()
    local sid = tostring(serverId)
    for _, existing in ipairs(G.MM_HopSeenServers) do
        if tostring(existing) == sid then return true end
    end
    return false
end

local function hopMarkSeen(serverId)
    hopSeenResetIfNeeded()
    local sid = tostring(serverId)
    if hopIsSeen(sid) then return end
    table.insert(G.MM_HopSeenServers, sid)
end

local function getPingMs()
    local ok, value = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    end)
    if ok and value then
        local n = tonumber(tostring(value):match("(%d+%.?%d*)"))
        if n then return n end
    end
    ok, value = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok then
        value = tonumber(value)
        if value then
            if value > 0 and value < 10 then return value * 1000 end
            return value
        end
    end
end

local function findHopServer()
    hopSeenResetIfNeeded()
    hopMarkSeen(game.JobId)
    local cursor, fallback = nil, nil
    local jobId = tostring(game.JobId)
    for _ = 1, 12 do
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
        if cursor and cursor ~= "" then
            url = url .. "&cursor=" .. Http:UrlEncode(cursor)
        end
        local raw = httpGet(url)
        if not raw then break end
        local ok, page = pcall(function() return Http:JSONDecode(raw) end)
        if not ok or type(page) ~= "table" then break end
        for _, server in ipairs(page.data or {}) do
            local sid = server.id and tostring(server.id) or ""
            if sid ~= "" and sid ~= jobId and not hopIsSeen(sid) then
                local playing = tonumber(server.playing) or 0
                local maxPlayers = tonumber(server.maxPlayers) or 0
                if maxPlayers > playing then
                    if playing > 2 then
                        return sid
                    end
                    if not fallback then fallback = sid end
                end
            end
        end
        cursor = page.nextPageCursor
        if not cursor or cursor == "null" or cursor == nil then break end
    end
    return fallback
end

local function resolveHopServerId(targetServerId)
    if targetServerId and tostring(targetServerId) ~= "" then
        return tostring(targetServerId)
    end
    local serverId
    for _ = 1, 8 do
        serverId = findHopServer()
        if serverId then break end
        task.wait(0.4)
    end
    return serverId
end

local function hopServer(reason, continuePingSearch, targetServerId)
    if hopBusy then return false end
    hopBusy = true
    stopFollow()
    if continuePingSearch then
        hopState.pingSearchActive = true
        queuePingSearchOnTeleport()
    else
        if session.ownerId then
            G.MM_PendingOwnerId = session.ownerId
            queueOwnerPersistOnTeleport(session.ownerId)
        end
        queueRegionSpreadOnTeleport()
    end
    log("server hop: " .. tostring(reason or "requested"))
    G.MM_ServerLocationJob = nil
    G.MM_ServerLocationCache = nil
    local serverId = resolveHopServerId(targetServerId)
    if not serverId then
        log("server hop: no server found")
        hopBusy = false
        return false
    end
    log("server hop: teleporting to " .. tostring(serverId))
    local ok = pcall(function()
        TeleportSvc:TeleportToPlaceInstance(game.PlaceId, serverId, me)
    end)
    if not ok then
        log("server hop failed")
        hopMarkSeen(serverId)
        hopBusy = false
        return false
    end
    hopMarkSeen(serverId)
    return true
end

--[[ Movement ]]--
local function hrp() return me.Character and me.Character:FindFirstChild("HumanoidRootPart") end
local followTarget = nil
local function stopFollow()
    followTarget = nil
end
-- Horizontal lead from HRP velocity so handoffs stay ahead of walking targets.
local function horizontalApproachLead(root)
    if not root then return Vector3.zero end
    local v = root.AssemblyLinearVelocity
    if v.Magnitude < 1e-3 then v = root.Velocity end
    local vh = Vector3.new(v.X, 0, v.Z)
    local spd = vh.Magnitude
    if spd <= 0.12 then return Vector3.zero end
    return vh.Unit * math.min(spd * 0.14, 8)
end
-- Fling-only: stronger lookahead for ~15fps cap (velocity + Humanoid move intent).
local FLING_PREDICT_SEC = 0.22
local function flingApproachLead(root, hum)
    if not root then return Vector3.zero end
    local v = root.AssemblyLinearVelocity
    if v.Magnitude < 1e-3 then v = root.Velocity end
    if hum then
        local md = hum.MoveDirection
        if md.Magnitude > 0.05 then
            local hv = md * hum.WalkSpeed
            local vh = Vector3.new(v.X, 0, v.Z)
            local hm = Vector3.new(hv.X, 0, hv.Z)
            if hm.Magnitude > vh.Magnitude then
                v = hv
            elseif hm.Magnitude > 0.4 then
                v = vh + hm * 0.65
            end
        end
    end
    local vh = Vector3.new(v.X, 0, v.Z)
    local spd = vh.Magnitude
    if spd <= 0.08 then return Vector3.zero end
    local ahead = spd * FLING_PREDICT_SEC
    local snap = math.min(spd * 0.22, 7)
    return vh.Unit * math.min(snap + ahead, 18)
end

local revealAnnouncePending = false
local roleAnnounceUnlockAt = 0

local function isAlive(p)
    local h = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
local function tweenTo(cf, dur)
    local h = hrp(); if not h then return end
    local tw = Tween:Create(h, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = cf})
    tw:Play(); tw.Completed:Wait()
end
local function zeroVel(h)
    if not h then return end
    pcall(function() h.AssemblyLinearVelocity = Vector3.zero end)
    pcall(function() h.AssemblyAngularVelocity = Vector3.zero end)
    h.Velocity = Vector3.zero
    h.RotVelocity = Vector3.zero
end
local function stowKnife()
    if not botHasKnife() then return end
    local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum:UnequipTools() end)
    end
    local knife = getHeldTool(me, {"Knife"})
    if knife and knife.Parent == me.Character then
        pcall(function() knife.Parent = me.Backpack end)
    end
end
local function tpTo(p)
    stopFollow()
    if not _G.MM_StabBusy and me.Character and me.Character:FindFirstChild("Knife") then
        stowKnife()
    end
    local h, t = hrp(), p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if h and t then
        zeroVel(h)
        h.CFrame = t.CFrame + Vector3.new(0, 0, 3)
        zeroVel(h)
    end
end
local function tpHome()
    stopFollow()
    local h = hrp()
    if h and SPAWN_CFRAME then
        pcall(function() h.Anchored = false end)
        zeroVel(h)
        h.CFrame = SPAWN_CFRAME
        zeroVel(h)
    end
end
local function reset()
    stopFollow()
    local char = me.Character
    if not char then return end
    local h = char:FindFirstChild("HumanoidRootPart")
    if h then
        pcall(function() h.CFrame = CFrame.new(0, -10000, 0) end)
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.Health = 0 end)
        pcall(function() hum:TakeDamage(hum.MaxHealth * 2) end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
    end
    pcall(function() char:BreakJoints() end)
    pcall(function() me:LoadCharacter() end)
end
local function runDeferredOwnerResetIfIdle()
    if not toggleResetOnOwnerDeath then
        _G.MM_OwnerDiedPendingReset = false
        return
    end
    if _G.MM_OwnerDiedPendingReset and not _G.MM_GunBusy and not _G.MM_StabBusy then
        _G.MM_OwnerDiedPendingReset = false
        log("owner died during combat -> resetting bot")
        task.spawn(function() pcall(reset) end)
    end
end
local function dropGunAt(target)
    if _G.MM_StabBusy then return false end
    if not isAlive(target) then return false end
    stopFollow()
    local h = hrp()
    local oh = target.Character:FindFirstChild("HumanoidRootPart")
    if not (h and oh) then return false end
    h.CFrame = oh.CFrame + horizontalApproachLead(oh)
    task.wait(0.1); reset()
    return true
end
local function bringGun(target)
    if _G.MM_StabBusy then return end
    target = target or findOwner()
    if not isAlive(target) then return end
    if botHasGun() then dropGunAt(target); return end
    local g, h = findDroppedGun(), hrp()
    if not (g and h) then return end
    g.CFrame = h.CFrame
    task.wait(0.5)
    dropGunAt(target)
end
local function stashGunAtSpawn()
    if _G.MM_StabBusy then return false end
    if not SPAWN_CFRAME or not isAlive(me) then return false end
    if not botHasGun() then
        local g, h = findDroppedGun(), hrp()
        if not (g and h) then return false end
        g.CFrame = h.CFrame
        local t0 = tick()
        while session.active and tick() - t0 < 2.5 do
            if botHasGun() then break end
            task.wait(0.05)
        end
        if not botHasGun() then return false end
    end
    for i = 1, 2 do tpHome(); task.wait(0.15) end
    task.wait(0.1)
    reset()
    return true
end
local function ownerMurdererActive(murderer, ownerPlayer)
    return ownerPlayer and murderer and murderer.UserId == ownerPlayer.UserId
end
local function gunAvailableForOwnerMurdStash()
    return botHasGun() or findDroppedGun() ~= nil
end
local function equipTool(tool)
    local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if tool and hum and tool.Parent ~= me.Character then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.08)
    end
    return tool and tool.Parent == me.Character
end

local STAB_PREDICT_T = 0.14
local STAB_MAX_LEAD = 3
local STAB_MELEE_OFFSET = 1.05
local STAB_MOVE_MIN = 2
local STAB_IDLE_LOCAL = CFrame.new(-0.6, 0.08, 2.05)

local function getStabHorizontalVelocity(th, hum, lastPos, lastT)
    local v = th.AssemblyLinearVelocity
    if v.Magnitude < 1e-3 then v = th.Velocity end
    local blend = Vector3.new(v.X, 0, v.Z)
    if hum then
        local md = hum.MoveDirection
        if md.Magnitude > 0.04 then
            local mdVel = Vector3.new(md.X, 0, md.Z) * hum.WalkSpeed
            if blend.Magnitude < 0.4 then
                blend = mdVel
            else
                blend = blend * 0.45 + mdVel * 0.55
            end
        end
    end
    if lastPos and lastT then
        local dt = tick() - lastT
        if dt > 0.03 and dt < 0.4 then
            local ev = (th.Position - lastPos) / dt
            local emp = Vector3.new(ev.X, 0, ev.Z)
            if emp.Magnitude > 1.5 then
                if blend.Magnitude < 0.5 then
                    blend = emp
                else
                    blend = blend * 0.3 + emp * 0.7
                end
            end
        end
    end
    return blend
end

local function getStabCFrame(target, lastPos, lastT)
    local th = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    if not th then return end
    local anchor = th.Position + Vector3.new(0, 0.25, 0)
    local vel = getStabHorizontalVelocity(th, hum, lastPos, lastT)
    local spd = vel.Magnitude
    if spd >= STAB_MOVE_MIN then
        local dir = vel.Unit
        local lead = dir * math.min(spd * STAB_PREDICT_T, STAB_MAX_LEAD)
        local pred = anchor + lead
        local pos = pred + dir * STAB_MELEE_OFFSET
        return CFrame.new(pos, pred), th.Position
    end
    return th.CFrame * STAB_IDLE_LOCAL, th.Position
end

local function whisperCombatResult(msg)
    if not msg or msg == "" then return end
    if msg == "Bot died" then
        log("bot died")
        return
    end
    whisper(msg)
end

local function stabPass(target, lastPos, lastT)
    if not isAlive(target) or not isAlive(me) then return false end
    if not botHasKnife() then return false end
    local knife = getHeldTool(me, {"Knife"})
    if not knife or not equipTool(knife) then return false end
    stopFollow()
    local cf, curPos = getStabCFrame(target, lastPos, lastT)
    local mh = hrp()
    if not (cf and mh) then return false end
    zeroVel(mh)
    mh.CFrame = cf
    zeroVel(mh)
    task.wait(0.05)
    cf = getStabCFrame(target, nil, nil) or cf
    if cf then
        zeroVel(mh)
        mh.CFrame = cf
        zeroVel(mh)
    end
    task.wait(0.1)
    pcall(function()
        local handle = knife:FindFirstChild("Handle")
        if knife:FindFirstChild("KnifeServer") and handle then
            local c = (handle.CFrame * CFrame.new(0, 1, 0)).Position
            knife.KnifeServer.SlashStart:FireServer(1, c)
        end
        knife:Activate()
    end)
    pcall(function() knife:Activate() end)
    return true, curPos or (target.Character and target.Character:FindFirstChild("HumanoidRootPart") and target.Character.HumanoidRootPart.Position)
end

local STAB_TIMEOUT_SEC = 45

local function stabTargetLoop(target)
    if target == me then return false, "Invalid target" end
    if not botHasKnife() then return false, "Bot needs to be murderer" end
    if not isAlive(target) then return false, "Player not found" end
    local started = tick()
    local lastPos, lastT
    while session.active and isAlive(me) and isAlive(target) and (tick() - started) < STAB_TIMEOUT_SEC do
        if not botHasKnife() then
            return false, "Bot needs to be murderer"
        end
        local ok, curPos = stabPass(target, lastPos, lastT)
        if not ok then
            return false, "Stab failed"
        end
        if curPos then lastPos, lastT = curPos, tick() end
        tpHome()
        task.wait(0.05)
        if not isAlive(target) then
            stowKnife()
            return true, "Killed " .. shortName(target)
        end
        if not isAlive(me) then
            log("bot died during stab")
            return false, "Bot died"
        end
        task.wait(math.random(10, 20) / 10)
    end
    for _ = 1, 3 do tpHome(); task.wait(0.15) end
    if not isAlive(me) then
        log("bot died during stab")
        return false, "Bot died"
    end
    if not isAlive(target) then
        stowKnife()
        return true, "Killed " .. shortName(target)
    end
    if (tick() - started) >= STAB_TIMEOUT_SEC then
        log("stab timed out on " .. shortName(target))
        return true, "Stab timed out"
    end
    return true, "Stopped stabbing " .. shortName(target)
end

--[[ Fling ]]--
local flingActive = false
local flingLoopGen = 0
local flingLoopActive = false
local flingLoopContinuous = false
local flingSettling = false

local function cancelFlingWork()
    flingLoopGen = flingLoopGen + 1
    flingLoopActive = false
    flingLoopContinuous = false
    flingActive = false
    flingSettling = false
end

local function recoverAfterFling()
    flingSettling = true
    for i = 1, 5 do
        local mh = hrp()
        if mh then
            zeroVel(mh)
            mh.Velocity = Vector3.zero
            mh.RotVelocity = Vector3.zero
        end
        tpHome()
        task.wait(0.06)
        if isAlive(me) then break end
    end
    if not isAlive(me) then
        pcall(reset)
        local t0 = tick()
        while tick() - t0 < 4 do
            if isAlive(me) then break end
            task.wait(0.15)
        end
    end
    local mh = hrp()
    if mh then zeroVel(mh) end
    flingSettling = false
end

local function fling(target, onDone)
    local onDoneFn = onDone
    if flingActive then
        if onDoneFn then onDoneFn(false) end
        return
    end
    if not isAlive(target) or not isAlive(me) then
        if onDoneFn then onDoneFn(false) end
        return
    end
    flingActive = true
    log("flinging " .. target.DisplayName)
    task.spawn(function()
        local thrp0 = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        local startPos = thrp0 and thrp0.Position
        local startedAt = tick()
        local stopAt = startedAt + 10
        local flung = false
        local hiVelFrames = 0
        while flingActive and tick() < stopAt and isAlive(target) and isAlive(me) do
            local mh = hrp()
            local th = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local thum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
            if mh and th then
                local lead = flingApproachLead(th, thum)
                mh.CFrame = th.CFrame + lead
                mh.Velocity = Vector3.new(99999, 99999, 99999)
                mh.RotVelocity = Vector3.new(99999, 99999, 99999)
            end
            if th and startPos and tick() - startedAt > 2 then
                local vel = th.Velocity.Magnitude
                if vel > 600 then hiVelFrames = hiVelFrames + 1
                else hiVelFrames = 0 end
                local moved = (th.Position - startPos).Magnitude
                local state = thum and thum:GetState()
                local ragdoll = state == Enum.HumanoidStateType.PlatformStanding
                             or state == Enum.HumanoidStateType.FallingDown
                             or state == Enum.HumanoidStateType.Physics
                if hiVelFrames >= 5 or moved > 60 or ragdoll then
                    flung = true
                    flingActive = false
                    local mh = hrp()
                    if mh then
                        zeroVel(mh)
                        mh.Velocity = Vector3.zero
                        mh.RotVelocity = Vector3.zero
                        pcall(function() mh.CFrame = SPAWN_CFRAME or mh.CFrame end)
                    end
                    break
                end
            end
            task.wait()
        end
        log(flung and "fling success" or "fling done")
        flingActive = false
        if onDoneFn then
            onDoneFn(flung)
        elseif flung then
            whisper("Flung " .. shortName(target))
        end
        recoverAfterFling()
    end)
end

local function waitFlingDone(gen, timeout)
    local t0 = tick()
    while (flingActive or flingSettling) and tick() - t0 < (timeout or 25) do
        if gen ~= flingLoopGen then break end
        task.wait(0.03)
    end
end

local FLING_LOOP_MAX_SEC = 300

local function flingLoopTimedOut(loopBegan)
    return tick() - loopBegan >= FLING_LOOP_MAX_SEC
end

--- Between loop flings: retry fast on miss; on hit, short pause if still alive or wait for respawn if dead.
local function waitAfterLoopFling(target, gen, loopBegan, hadSuccess)
    if not target or not target.Parent then return end
    if flingLoopTimedOut(loopBegan) then return end
    if not hadSuccess then
        task.wait(0.55)
        return
    end
    task.wait(0.35)
    if not isAlive(target) then
        local t0 = tick()
        while gen == flingLoopGen and flingLoopActive and session.active and not flingLoopTimedOut(loopBegan) do
            if not target.Parent then return end
            if isAlive(target) and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                break
            end
            if tick() - t0 > 40 then break end
            task.wait(0.12)
        end
        task.wait(0.25)
    else
        task.wait(0.85)
    end
end

local function runFlingLoop(mode, playerQuery, gen, continuousLoop)
    task.spawn(function()
        if mode == "all" then
            local targets = {}
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= me and (not session.ownerId or pl.UserId ~= session.ownerId) then
                    table.insert(targets, pl)
                end
            end
            for i, tgt in ipairs(targets) do
                if gen ~= flingLoopGen or not flingLoopActive or not session.active then break end
                if isAlive(tgt) and isAlive(me) then
                    fling(tgt, function(ok)
                        if ok and flingLoopActive and gen == flingLoopGen then
                            whisper("Flung " .. shortName(tgt))
                        end
                    end)
                    waitFlingDone(gen, 25)
                    if i < #targets and gen == flingLoopGen and flingLoopActive then
                        task.wait(0.5)
                    end
                end
            end
            if gen == flingLoopGen then
                flingLoopActive = false
            end
            return
        end

        local loopTargetUserId = nil
        local function collectTargets()
            local targets = {}
            if mode == "sheriff" then
                local s = findHolder({"Gun", "Revolver"})
                if s and s ~= me then table.insert(targets, s) end
            elseif mode == "murder" then
                local murd = findHolder({"Knife"})
                if murd and murd ~= me then table.insert(targets, murd) end
            else
                if loopTargetUserId then
                    local pl = Players:GetPlayerByUserId(loopTargetUserId)
                    if pl and pl ~= me then table.insert(targets, pl) end
                else
                    local t = findOtherPlayer(playerQuery)
                    if t then table.insert(targets, t) end
                end
            end
            return targets
        end

        if not continuousLoop then
            local targets = collectTargets()
            for i, tgt in ipairs(targets) do
                if gen ~= flingLoopGen or not flingLoopActive or not session.active then break end
                if isAlive(tgt) and isAlive(me) then
                    fling(tgt, function(ok)
                        if ok and flingLoopActive and gen == flingLoopGen then
                            whisper("Flung " .. shortName(tgt))
                        end
                    end)
                    waitFlingDone(gen, 25)
                    if i < #targets and gen == flingLoopGen and flingLoopActive then
                        task.wait(0.5)
                    end
                end
            end
            if gen == flingLoopGen then
                flingLoopActive = false
            end
            return
        end

        local loopBegan = tick()
        while session.active and gen == flingLoopGen and flingLoopActive do
            if flingLoopTimedOut(loopBegan) then
                whisper("Fling loop stopped")
                cancelFlingWork()
                return
            end
            if mode == "player" and loopTargetUserId and not Players:GetPlayerByUserId(loopTargetUserId) then
                whisper("Fling target left")
                cancelFlingWork()
                return
            end
            if not isAlive(me) then
                task.wait(0.5)
            else
                local targets = collectTargets()
                if #targets == 0 then
                    task.wait(0.6)
                else
                    for _, tgt in ipairs(targets) do
                        if gen ~= flingLoopGen or not flingLoopActive or flingLoopTimedOut(loopBegan) then break end
                        if mode == "player" and not loopTargetUserId and tgt.UserId then
                            loopTargetUserId = tgt.UserId
                        end
                        if isAlive(tgt) then
                            local lastOk = false
                            fling(tgt, function(ok)
                                lastOk = ok
                            end)
                            waitFlingDone(gen, 25)
                            if gen ~= flingLoopGen or not flingLoopActive then break end
                            waitAfterLoopFling(tgt, gen, loopBegan, lastOk)
                        elseif mode == "player" and loopTargetUserId then
                            task.wait(0.45)
                        end
                    end
                end
            end
            if gen == flingLoopGen and flingLoopActive then
                task.wait(0.15)
            end
        end
        if gen == flingLoopGen then
            flingLoopActive = false
            flingLoopContinuous = false
        end
    end)
end

--[[ Follow ]]-- (followTarget / stopFollow are under Movement)

--[[ Round ]]--
local function isRoundActive()
    return findHolder({"Knife"}) or findHolder({"Gun", "Revolver"})
        or botHasKnife() or botHasGun()
end

local function getAliveExcludingBot()
    local list = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= me and isAlive(pl) then
            table.insert(list, pl)
        end
    end
    return list
end

local function startFollowLoop()
    task.spawn(function()
        while followTarget and session.active do
            local target = followTarget
            if target and isAlive(target) and isAlive(me) then
                local thrp = target.Character:FindFirstChild("HumanoidRootPart")
                local thum = target.Character:FindFirstChildOfClass("Humanoid")
                local hum = me.Character:FindFirstChildOfClass("Humanoid")
                if thrp and hum then
                    hum:MoveTo(thrp.Position)
                    if thum then
                        local st = thum:GetState()
                        local j = st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
                        if j or thrp.Velocity.Y > 10 then
                            hum.Jump = true
                        end
                    end
                end
            end
            task.wait(0.12)
        end
    end)
end

--[[ Commands ]]--
local COMMAND_HELP = {
    reveal = "Show current murderer and sheriff",
    stab = "sheriff | <name> - Murderer only, stab a given player",
    togglereveal = "Toggle automatic role callout each round",
    togglealerts = "Toggle kill/drop/pickup alerts",
    togglereset = "Toggle auto-reset when owner dies",
    toggledrop = "Toggle stashing guns when you are murderer",
    reset = "Force bot respawn",
    tp = "<player> - Teleport bot to a player",
    tpmurd = "Teleport bot to the murderer",
    tpsher = "Teleport bot to the sheriff",
    spawn = "Teleport bot to spawn",
    follow = "<player> - Follow a player",
    unfollow = "Stop following current player",
    gun = "<player> - Deliver gun to a player",
    togglegun = "<player> - Auto-deliver gun to a player",
    chat = "<msg> - Make bot send a public chat message",
    fling = "<player> - Flings player off the map",
    help = "<cmd> - Show command list or explain one command",
}
local HELP_ORDER = {
    "tp", "reveal", "stab", "gun", "fling", "togglegun", "togglereveal", "togglealerts",
    "reset", "follow", "unfollow", "chat", "help",
}
local PREMIUM_ONLY_COMMANDS = {
    togglereset = true,
    toggledrop = true,
    togglegun = true,
    togglereveal = true,
    togglealerts = true,
    fling = true,
    chat = true,
}

local function ownerIsPremium()
    return true
end

local function helpKeysForOwner()
    local keys = {}
    for _, k in ipairs(HELP_ORDER) do
        table.insert(keys, k)
    end
    if not ownerIsPremium() then
        return keys
    end
    local out = {}
    for _, k in ipairs(keys) do
        if k == "reset" then
            table.insert(out, "togglereset")
            table.insert(out, "toggledrop")
        end
        table.insert(out, k)
    end
    return out
end

local function isPremiumOnlyCommand(cmd)
    return PREMIUM_ONLY_COMMANDS[cmd] == true
end

local function sendFullHelp(target, gapBetween)
    gapBetween = gapBetween or 0.5
    local uid
    if type(target) == "number" then
        uid = target
    elseif target and typeof(target) == "Instance" and target:IsA("Player") then
        uid = target.UserId
    end
    local function resolve()
        if uid then return Players:GetPlayerByUserId(uid) end
        return findOwner()
    end
    local o
    for _ = 1, 15 do
        o = resolve()
        if o then break end
        task.wait(0.2)
    end
    if not o then return end
    whisper("Use !help <command> for what a command does", o)
    if gapBetween > 0 then task.wait(gapBetween) end
    o = resolve()
    if not o then
        for _ = 1, 12 do
            task.wait(0.15)
            o = resolve()
            if o then break end
        end
    end
    if not o then return end
    local keys = helpKeysForOwner()
    local parts = {}
    for _, key in ipairs(keys) do
        table.insert(parts, "!" .. key)
    end
    local line = table.concat(parts, " ")
    if #line <= 200 then
        whisper(line, o)
        return
    end
    local mid = math.ceil(#keys / 2)
    local a, b = {}, {}
    for i, key in ipairs(keys) do
        if i <= mid then table.insert(a, "!" .. key) else table.insert(b, "!" .. key) end
    end
    whisper(table.concat(a, " "), o)
    if gapBetween > 0 then task.wait(gapBetween) end
    o = resolve()
    if not o then
        for _ = 1, 12 do
            task.wait(0.15)
            o = resolve()
            if o then break end
        end
    end
    if o then whisper(table.concat(b, " "), o) end
end

local ownerOnboardingGen = 0

local function resolveOwnerPlayer(userId)
    if session.ownerId ~= userId then return nil end
    return Players:GetPlayerByUserId(userId)
end

-- One line at a time; retry whisperOk, then one best-effort whisper() if all acks fail.
local function deliverOwnerLine(userId, msg, attempts, step)
    attempts = attempts or 14
    step = step or 0.42
    for _ = 1, attempts do
        if session.ownerId ~= userId then return false end
        local o = resolveOwnerPlayer(userId)
        if o and whisperOk(msg, o) then return true end
        task.wait(step)
    end
    local o = resolveOwnerPlayer(userId)
    if not o then return false end
    whisper(msg, o)
    task.wait(0.35)
    return whisperOk(msg, o) or session.ownerId == userId
end

local function sendFullHelpToOwner(userId, gapBetween)
    gapBetween = gapBetween or 0.75
    if session.ownerId ~= userId then return false end

    if not deliverOwnerLine(userId, "Use !help <command> for what a command does", 16, 0.45) then
        return false
    end
    task.wait(gapBetween)

    local keys = helpKeysForOwner()
    local parts = {}
    for _, key in ipairs(keys) do
        table.insert(parts, "!" .. key)
    end
    local line = table.concat(parts, " ")
    if #line <= 200 then
        return deliverOwnerLine(userId, line, 16, 0.45)
    end

    local mid = math.ceil(#keys / 2)
    local a, b = {}, {}
    for i, key in ipairs(keys) do
        if i <= mid then table.insert(a, "!" .. key) else table.insert(b, "!" .. key) end
    end
    if not deliverOwnerLine(userId, table.concat(a, " "), 16, 0.45) then return false end
    task.wait(gapBetween)
    return deliverOwnerLine(userId, table.concat(b, " "), 16, 0.45)
end

local function syncOwnerPremiumFromClaim(claim)
    G.MM_OwnerPremium = true
end

function scheduleOwnerOnboarding(userId)
    ownerOnboardingGen = ownerOnboardingGen + 1
    local gen = ownerOnboardingGen
    task.spawn(function()
        task.wait(1.1)
        if gen ~= ownerOnboardingGen or session.ownerId ~= userId then return end
        local o
        for _ = 1, 40 do
            if gen ~= ownerOnboardingGen or session.ownerId ~= userId then return end
            o = resolveOwnerPlayer(userId)
            if o then break end
            task.wait(0.12)
        end
        if not o then
            log("onboarding: owner player not found")
            return
        end
        log("new owner: " .. o.DisplayName)

        if not deliverOwnerLine(userId, "Loading new owner", 12, 0.4) then
            log("onboarding: could not whisper Loading new owner")
        end

        task.wait(0.85)
        if gen ~= ownerOnboardingGen or session.ownerId ~= userId then return end

        local helpOk = false
        for attempt = 1, 4 do
            if gen ~= ownerOnboardingGen or session.ownerId ~= userId then return end
            if sendFullHelpToOwner(userId, 0.75) then
                helpOk = true
                break
            end
            log("onboarding: help send attempt " .. attempt .. " failed, retrying")
            task.wait(0.5 + attempt * 0.35)
        end
        if not helpOk then
            log("onboarding: help whispers failed after retries")
        end

    end)
end

local function handleCommand(p, msg)
    if msg:sub(1, 1) ~= "!" then return end
    local args = msg:split(" ")
    local cmd, rest = args[1]:sub(2):lower(), msg:sub(#args[1] + 2)
    if cmd == "owner" or cmd == "dethrone" then
        return
    end
    if not session.ownerId or p.UserId ~= session.ownerId then return end
    if flingLoopContinuous and cmd ~= "fling" then
        whisper('You need to toggle off fling loop using "!fling"')
        return
    end
    if cmd == "fling" then
        local raw = restOfChatArgs(args)
        local trimmed = (raw:match("^%s*(.-)%s*$") or "")
        local wl = trimmed:lower()
        local continuousLoop = wl:match(" loop%s*$") ~= nil
        local work = trimmed
        if continuousLoop then
            work = (trimmed:gsub("%s+[Ll][Oo][Oo][Pp]%s*$", ""):match("^%s*(.-)%s*$") or "")
        end
        local q = (work:match("^%s*(.-)%s*$") or ""):lower()
        if q == "" then
            if flingLoopActive or flingActive or flingSettling then
                cancelFlingWork()
                whisper("Fling loop stopped")
                return
            end
            whisper("!fling all | sheriff | murder | <name> — add loop to repeat, !fling alone stops")
            return
        end

        if flingLoopContinuous then
            whisper('You need to toggle off fling loop using "!fling"')
            return
        end

        local mode, playerQuery = "player", work
        local first = q:match("^(%S+)")
        if first == "all" then
            mode, playerQuery = "all", ""
        elseif first == "sheriff" or first == "sher" or first == "sherif" then
            mode, playerQuery = "sheriff", ""
        elseif first == "murder" or first == "murd" or first == "murderer" then
            mode, playerQuery = "murder", ""
        end

        if continuousLoop and mode == "all" then
            whisper("Use !fling all only")
            return
        end

        if mode == "player" then
            if not findOtherPlayer(work) then
                whisper("Could not find player: " .. work)
                return
            end
        end

        flingActive = false
        flingLoopGen = flingLoopGen + 1
        local gen = flingLoopGen
        flingLoopActive = true

        local loopArg = continuousLoop and mode ~= "all"
        flingLoopContinuous = loopArg
        runFlingLoop(mode, playerQuery, gen, loopArg)
        if mode == "all" then
            whisper("Flinging everyone")
        elseif loopArg then
            local label = mode == "player" and work or mode
            whisper("Say !fling alone to stop the loop")
            task.wait(0.3)
            whisper("Looping on: " .. label)
        else
            whisper("Flinging " .. (mode == "player" and work or mode))
        end
        return
    end
    local m, s = findHolder({"Knife"}), findHolder({"Gun", "Revolver"})
    local ownerPlayer = findOwner()
    local ownerIsMurd = ownerMurdererActive(m, ownerPlayer) and not botHasKnife()
    if cmd == "chat" then
        sendChat(rest)
        whisper("Chat sent")
    elseif cmd == "reveal" then
        local botM, botS = botHasKnife(), botHasGun()
        local mL = botM and "Me" or (m and shortName(m)) or "?"
        local sL = botS and "Me" or (s and shortName(s)) or "?"
        whisper("Murderer: " .. mL)
        task.wait(0.3)
        whisper("Sheriff: " .. sL)
    elseif cmd == "tp" then
        local t = findPlayer(args[2]) or findOwner()
        if not t then whisper("Player not found") return end
        tpTo(t)
        whisper("Teleported to " .. commandTargetLabel(t))
    elseif cmd == "tpmurd" then
        if not m then whisper("Murderer not found") return end
        tpTo(m)
        whisper("Teleported to murderer")
    elseif cmd == "tpsher" then
        if not s then whisper("Sheriff not found") return end
        tpTo(s)
        whisper("Teleported to sheriff")
    elseif cmd == "stab" then
        if not botHasKnife() then whisper("Bot needs to be murderer") return end
        local q = restOfChatArgs(args)
        if q == "" then whisper("!stab sheriff | <name>") return end
        local wl = q:lower()
        local first = wl:match("^(%S+)")
        local picked
        if first == "sheriff" or first == "sher" or first == "sherif" then
            picked = findHolder({"Gun", "Revolver"})
            if not picked or picked == me then whisper("Sheriff not found") return end
        else
            picked = findOtherPlayer(q)
            if not picked then whisper("Player not found") return end
        end
        if _G.MM_StabBusy then whisper("Stab busy, try again") return end
        if _G.MM_GunBusy then whisper("Gun busy, try again") return end
        local targetUid = picked.UserId
        _G.MM_StabBusy = true
        whisper("Stabbing " .. shortName(picked))
        task.spawn(function()
            local status = "Player not found"
            local ok, err = pcall(function()
                local tgt = Players:GetPlayerByUserId(targetUid)
                if not tgt or not isAlive(tgt) then return end
                local _, msg = stabTargetLoop(tgt)
                status = msg
            end)
            if not ok then
                status = "Stab failed"
                log(tostring(err))
            end
            whisperCombatResult(status)
            _G.MM_StabBusy = false
            runDeferredOwnerResetIfIdle()
        end)
    elseif cmd == "gun" then
        local t = findPlayer(args[2]) or findOwner()
        if not t then whisper("Player not found") return end
        if ownerIsMurd then whisper(OWNER_MURD_GUN_MSG) return end
        if botHasKnife() then whisper("No gun available") return end
        if not gunAvailableForOwnerMurdStash() then whisper("No gun available") return end
        bringGun(t)
        whisper("Gun delivered to " .. commandTargetLabel(t))
    elseif cmd == "spawn" or cmd == "home" then
        tpHome()
        whisper("Teleported to spawn")
    elseif cmd == "reset" then
        whisper("Resetting")
        reset()
    elseif cmd == "togglegun" then
        if args[2] and ownerIsMurd then whisper(OWNER_MURD_GUN_MSG) return end
        if args[2] then
            local t = findPlayer(args[2])
            if not t then whisper("Player not found") return end
            toggleGun, gunTargetId, gunDelivered = true, t.UserId, false
            whisper("Auto-gun on: " .. shortName(t))
        else
            toggleGun = not toggleGun
            gunTargetId, gunDelivered = nil, false
            whisper("Auto-gun: " .. (toggleGun and "on" or "off"))
        end
    elseif cmd == "togglealerts" then
        toggleAlerts = not toggleAlerts
        whisper("Kill alerts: " .. (toggleAlerts and "on" or "off"))
    elseif cmd == "togglereveal" then
        toggleReveal = not toggleReveal
        whisper("Role callouts: " .. (toggleReveal and "on" or "off"))
    elseif cmd == "togglereset" then
        toggleResetOnOwnerDeath = not toggleResetOnOwnerDeath
        _G.MM_OwnerDiedPendingReset = false
        whisper("Reset on owner death: " .. (toggleResetOnOwnerDeath and "on" or "off"))
    elseif cmd == "toggledrop" then
        toggleDrop = not toggleDrop
        whisper("Murderer gun stash: " .. (toggleDrop and "on" or "off"))
    elseif cmd == "follow" then
        local t = findPlayer(args[2]) or findOwner()
        if not t then whisper("Player not found") return end
        local wasActive = followTarget ~= nil
        local switching = followTarget ~= t
        followTarget = t
        if switching then tpTo(t) end
        whisper("Following " .. shortName(t))
        if not wasActive then startFollowLoop() end
    elseif cmd == "unfollow" then
        if not followTarget then whisper("Not following anyone") return end
        local name = shortName(followTarget)
        followTarget = nil
        whisper("Unfollowed " .. name)
    elseif cmd == "help" then
        local tail = restOfChatArgs(args)
        tail = (tail:gsub("^!+", ""):match("^%s*(.-)%s*$") or "")
        local helpCmd = (tail:match("^(%S+)") or ""):lower()
        if helpCmd == "" and args[2] then
            helpCmd = (tostring(args[2]):gsub("^!+", ""):match("^%s*(.-)%s*$") or ""):lower()
        end
        if helpCmd ~= "" and COMMAND_HELP[helpCmd] then
            whisper("!" .. helpCmd .. ": " .. COMMAND_HELP[helpCmd])
        elseif helpCmd ~= "" then
            whisper("No help for !" .. helpCmd .. " — use !help for the list")
        else
            sendFullHelp()
        end
    end
end
local function routeCommand(p, msg)
    msg = cleanChatText(msg)
    if msg == "" or seenCommandRecently(p, msg) then return end
    if XENO_OWNER_USERNAME ~= "" and configuredOwnerMatches(p) and session.ownerId ~= p.UserId then
        syncConfiguredOwner()
    end
    handleCommand(p, msg)
end
local function watchHiddenChat(p, msg)
    local event = getHiddenChatEvent()
    if not event or p == me then return end
    local clean = cleanChatText(msg)
    if clean == "" then return end
    local hidden = true
    local conn
    conn = event.OnClientEvent:Connect(function(packet)
        local packetMsg = packet and packet.Message
        if packet and packet.SpeakerUserId == p.UserId and type(packetMsg) == "string" then
            local suffix = clean:sub(math.max(1, #clean - #packetMsg + 1))
            if packetMsg == suffix then
                hidden = false
            end
        end
    end)
    task.delay(1, function()
        if conn then conn:Disconnect() end
        if hidden and session.active then
            showHiddenChat(p, clean)
            routeCommand(p, clean)
        end
    end)
end
local function hookSpeaker(p)
    p.Chatted:Connect(function(msg)
        routeCommand(p, msg)
        watchHiddenChat(p, msg)
    end)
end
for _, p in ipairs(Players:GetPlayers()) do hookSpeaker(p) end
Players.PlayerAdded:Connect(hookSpeaker)
Players.PlayerRemoving:Connect(function(p)
    if session.ownerId and p.UserId == session.ownerId then
        if hopBusy then return end
        session.ownerId = nil
        G.MM_PendingOwnerId = nil
        toggleGun, toggleAlerts, toggleReveal = false, false, true
        toggleDrop, toggleResetOnOwnerDeath = false, false
        gunTargetId, gunDelivered = nil, false
    end
end)

--[[ Discord bridge (discord-xeno.py Flask) ]]--
local XENO_BRIDGE_URL = (getgenv and getgenv().XENO_BRIDGE_URL) or "https://xenobotsmm2.xyz"
local XENO_BRIDGE_ENABLED = not (getgenv and getgenv().XENO_BRIDGE_ENABLED == false)
local XENO_POLL_SEC = (getgenv and tonumber(getgenv().XENO_POLL_SEC)) or 2.5
local BRIDGE_CLAIM_WAIT_SEC = 15 * 60
local BRIDGE_ACK_DELAY_SEC = 5
local REGION_PEER_MAX = 3
local REGION_SPREAD_MAX_ATTEMPTS = 12
local bridgeAcked = {}
local bridgeClaimId = nil
local bridgeAwaitingName = nil
local bridgeClaimExpiresAt = 0
local bridgeFulfilledClaimId = nil

local function nameMatchesPlayer(pl, name)
    if not pl or not name or name == "" then return false end
    local lower = name:lower()
    return pl.Name:lower() == lower or tostring(pl.DisplayName or ""):lower() == lower
end

local function findPlayerInServerByName(name)
    if not name or name == "" then return nil end
    name = name:match("^%s*(.-)%s*$") or name
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= me and nameMatchesPlayer(pl, name) then
            return pl
        end
    end
end

local function bridgeReportClaimEvent(event, extra)
    extra = extra or {}
    pcall(function()
        httpJson("POST", XENO_BRIDGE_URL .. "/api/xeno/poll", {
            job_id = game.JobId,
            bot_username = me.Name,
            bot_user_id = me.UserId,
            place_id = game.PlaceId,
            owner_id = extra.owner_id or session.ownerId,
            player_count = #Players:GetPlayers(),
            claim_event = event,
            claim_id = extra.claim_id or bridgeClaimId,
            bot_note = extra.note,
        })
    end)
end

local function fulfillBridgeClaim(claimId, username)
    if not claimId or not username then return false end
    if bridgeFulfilledClaimId == claimId then return true end
    local pl = findPlayerInServerByName(username)
    if not pl then return false end
    local prevId = session.ownerId
    session.ownerId = pl.UserId
    bridgeFulfilledClaimId = claimId
    bridgeAwaitingName = nil
    log("bridge: owner joined — " .. pl.Name)
    if prevId ~= pl.UserId then
        toggleResetOnOwnerDeath = false
        toggleDrop = false
        _G.MM_OwnerDiedPendingReset = false
        scheduleOwnerOnboarding(pl.UserId)
    end
    bridgeReportClaimEvent("owner_joined", { claim_id = claimId, owner_id = pl.UserId, note = pl.Name })
    return true
end

local function clearBridgeReservation(reason)
    if bridgeAwaitingName or bridgeClaimId then
        log("bridge: reservation cleared — " .. tostring(reason))
    end
    bridgeClaimId = nil
    bridgeAwaitingName = nil
    bridgeClaimExpiresAt = 0
    bridgeReportClaimEvent("released", { note = reason })
end

local function bridgeAck(jobId, commandId, status, message)
    if not commandId or commandId == "" then return end
    bridgeAcked[commandId] = true
    pcall(function()
        httpJson("POST", XENO_BRIDGE_URL .. "/api/xeno/ack", {
            job_id = jobId,
            command_id = commandId,
            status = status or "ok",
            message = message or "",
            bot_user_id = me.UserId,
        })
    end)
end

local function bridgeCommandDelay(cmd)
    return 0
end

-- Run as soon as poll delivers the command, then ack right away.
local function bridgeExecuteAfterPollDelay(jobId, commandId, fn, cmd)
    task.spawn(function()
        task.wait(bridgeCommandDelay(cmd))
        local ok, st, msg = pcall(fn)
        if ok and type(st) == "string" then
            bridgeAck(jobId, commandId, st, msg or "")
        else
            bridgeAck(jobId, commandId, "error", "Command failed")
        end
    end)
end

local function bridgeTrim(s)
    return (tostring(s or ""):match("^%s*(.-)%s*$") or "")
end

local function bridgeHelpMessage(topic)
    topic = bridgeTrim(topic):lower():gsub("^!", "")
    if topic ~= "" then
        if COMMAND_HELP[topic] then
            return "ok", "!" .. topic .. ": " .. COMMAND_HELP[topic]
        end
        return "error", "No help for !" .. topic .. " — use /help for the full list"
    end
    local lines = {
        "Discord: /help /gun /stab /fling /tp /reveal /reset /chat /alerts",
        "",
    }
    table.insert(lines, "In-game: !help and the same commands with !")
    table.insert(lines, "")
    for _, key in ipairs(helpKeysForOwner()) do
        local desc = COMMAND_HELP[key] or ""
        table.insert(lines, "• **!" .. key .. "** — " .. desc)
    end
    return "ok", table.concat(lines, "\n")
end

local function bridgeToggleGunMessage(mode)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    local m = findHolder({"Knife"})
    local ownerPlayer = findOwner()
    if ownerMurdererActive(m, ownerPlayer) and not botHasKnife() then
        return "error", OWNER_MURD_GUN_MSG
    end
    mode = bridgeTrim(mode):lower()
    if mode == "enable" then
        if toggleGun then
            return "ok", "Automatic gun is already enabled"
        end
        toggleGun = true
        gunTargetId, gunDelivered = nil, false
        return "ok", "Automatic gun enabled"
    elseif mode == "disable" then
        if not toggleGun then
            return "error", "Automatic gun is not enabled"
        end
        toggleGun = false
        gunTargetId, gunDelivered = nil, false
        return "ok", "Automatic gun disabled"
    end
    return "error", "Use Enable or Disable"
end

local function bridgeToggleRevealMessage(mode)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    mode = bridgeTrim(mode):lower()
    if mode == "enable" then
        if toggleReveal then
            return "ok", "In-game whispers are already enabled"
        end
        toggleReveal = true
        return "ok", "In-game whispers enabled"
    elseif mode == "disable" then
        if not toggleReveal then
            return "error", "In-game whispers are not enabled"
        end
        toggleReveal = false
        return "ok", "In-game whispers disabled"
    end
    return "error", "Use Enable or Disable"
end

local function bridgeToggleAlertsMessage(mode)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    mode = bridgeTrim(mode):lower()
    if mode == "enable" then
        if toggleAlerts then
            return "ok", "In-game whispers are already enabled"
        end
        toggleAlerts = true
        return "ok", "In-game whispers enabled"
    elseif mode == "disable" then
        if not toggleAlerts then
            return "error", "In-game whispers are not enabled"
        end
        toggleAlerts = false
        return "ok", "In-game whispers disabled"
    end
    return "error", "Use Enable or Disable"
end

local function bridgeChatMessage(text)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    text = bridgeTrim(text)
    if text == "" then
        return "error", "Message required"
    end
    sendChat(text)
    return "ok", "Chat sent"
end

local function bridgeGunMessage(targetQuery)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    local m = findHolder({"Knife"})
    local ownerPlayer = findOwner()
    local ownerIsMurd = ownerMurdererActive(m, ownerPlayer) and not botHasKnife()
    local t
    if bridgeTrim(targetQuery) == "" then
        t = ownerPlayer
    else
        t = findPlayer(targetQuery)
    end
    if not t then return "error", "Player not found" end
    if ownerIsMurd then return "error", OWNER_MURD_GUN_MSG end
    if botHasKnife() then return "error", "No gun available" end
    if not gunAvailableForOwnerMurdStash() then return "error", "No gun available" end
    bringGun(t)
    return "ok", "Gun delivered to " .. bridgeTargetLabel(t)
end

local function bridgeParseFlingQuery(query)
    query = bridgeTrim(query)
    if query == "" then
        return nil, nil, "Use: **all**, **sheriff**, **murder**, or a player name"
    end
    local q = query:lower()
    local first = q:match("^(%S+)")
    local mode, playerQuery = "player", query
    if first == "all" then
        mode, playerQuery = "all", ""
    elseif first == "sheriff" or first == "sher" or first == "sherif" then
        mode, playerQuery = "sheriff", ""
    elseif first == "murder" or first == "murd" or first == "murderer" then
        mode, playerQuery = "murder", ""
    end
    return mode, playerQuery, nil
end

local function bridgeRunFlingOnce(mode, playerQuery, gen)
    if mode == "all" then
        local n = 0
        for _, pl in ipairs(Players:GetPlayers()) do
            if gen ~= flingLoopGen or not flingLoopActive or not session.active then break end
            if pl ~= me and (not session.ownerId or pl.UserId ~= session.ownerId) and isAlive(pl) and isAlive(me) then
                local flung = false
                fling(pl, function(ok) flung = ok end)
                waitFlingDone(gen, 25)
                if flung then n = n + 1 end
            end
        end
        if n > 0 then
            return "ok", "Flung " .. tostring(n) .. " player(s)"
        end
        return "ok", "Fling finished (no hits)"
    end

    local tgt
    if mode == "sheriff" then
        tgt = findHolder({"Gun", "Revolver"})
        if not tgt or tgt == me then return "error", "Sheriff not found" end
    elseif mode == "murder" then
        tgt = findHolder({"Knife"})
        if not tgt or tgt == me then return "error", "Murderer not found" end
    else
        tgt = findOtherPlayer(playerQuery)
        if not tgt then return "error", "Player not found: " .. playerQuery end
    end
    if not isAlive(tgt) or not isAlive(me) then return "error", "Target or bot not alive" end
    local flung = false
    fling(tgt, function(ok) flung = ok end)
    waitFlingDone(gen, 25)
    if flung then
        return "ok", "Flung " .. bridgeTargetLabel(tgt)
    end
    return "ok", "Fling finished"
end

local function bridgeStabMessage(targetQuery)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    if not botHasKnife() then
        return "error", "Bot needs to be murderer"
    end
    local q = bridgeTrim(targetQuery)
    if q == "" then
        return "error", "Use: sheriff or a player name"
    end
    local wl = q:lower()
    local first = wl:match("^(%S+)")
    local picked
    if first == "sheriff" or first == "sher" or first == "sherif" then
        picked = findHolder({"Gun", "Revolver"})
        if not picked or picked == me then return "error", "Sheriff not found" end
    else
        picked = findOtherPlayer(q)
        if not picked then return "error", "Player not found" end
    end
    if _G.MM_StabBusy then return "error", "Stab busy, try again" end
    if _G.MM_GunBusy then return "error", "Gun busy, try again" end
    _G.MM_StabBusy = true
    local targetUid = picked.UserId
    local status = "Player not found"
    local okRun, errRun = pcall(function()
        local tgt = Players:GetPlayerByUserId(targetUid)
        if not tgt or not isAlive(tgt) then return end
        local _, msg = stabTargetLoop(tgt)
        status = msg
    end)
    _G.MM_StabBusy = false
    runDeferredOwnerResetIfIdle()
    if not okRun then
        return "error", "Stab failed"
    end
    if status:find("not found", 1, true) or status:find("failed", 1, true) then
        return "error", status
    end
    return "ok", "Stabbed " .. bridgeTargetLabel(picked)
end

local function bridgeFlingMessage(query)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    if flingLoopContinuous then
        return "error", "Stop the in-game fling loop with !fling first"
    end
    local mode, playerQuery, err = bridgeParseFlingQuery(query)
    if err then return "error", err end
    if mode == "player" and not findOtherPlayer(playerQuery) then
        return "error", "Could not find player: " .. playerQuery
    end
    cancelFlingWork()
    flingLoopGen = flingLoopGen + 1
    local gen = flingLoopGen
    flingLoopActive = true
    local st, msg = bridgeRunFlingOnce(mode, playerQuery, gen)
    if gen == flingLoopGen then
        flingLoopActive = false
    end
    return st, msg
end

local murdererRoundKills = 0
local sheriffRoundKills = 0
local whoKnifeIdPrev, whoGunIdPrev = nil, nil

local function ownerHrp()
    local o = findOwner()
    if not o or o == me then return nil end
    return o.Character and o.Character:FindFirstChild("HumanoidRootPart")
end

local function distanceStudsToPlayer(p)
    local h = ownerHrp()
    local t = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if not (h and t) then return nil end
    return math.floor((h.Position - t.Position).Magnitude + 0.5)
end

local function distanceStudsToPart(part)
    local h = ownerHrp()
    if not (h and part) then return nil end
    local pos = part.Position
    return math.floor((h.Position - pos).Magnitude + 0.5)
end

local function whoRoleEntry(p, kills)
    return {
        user_id = p and p.UserId or nil,
        username = p and bridgePlayerLabel(p) or nil,
        kills = kills or 0,
        distance_studs = p and distanceStudsToPlayer(p) or nil,
        is_bot = p == me,
    }
end

local function bridgeRevealMessage()
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    local m = findHolder({"Knife"})
    local s = findHolder({"Gun", "Revolver"})
    local botM, botS = botHasKnife(), botHasGun()
    local murdererP = botM and me or m
    if not murdererP then
        return "error", "Round hasn't started yet"
    end
    local sheriffP = botS and me or s
    local gunDrop = findDroppedGun()
    local gunEquipped = botS or (sheriffP and playerHas(sheriffP, {"Gun", "Revolver"}))
    local gunDropped = gunDrop ~= nil and not sheriffP
    local gunAvailable = gunEquipped or gunDropped
    local sheriffDist = sheriffP and distanceStudsToPlayer(sheriffP)
        or (gunDrop and distanceStudsToPart(gunDrop))
    local payload = {
        murderer = whoRoleEntry(murdererP, murdererRoundKills),
        sheriff = {
            user_id = sheriffP and sheriffP.UserId or nil,
            username = sheriffP and bridgePlayerLabel(sheriffP) or nil,
            kills = sheriffRoundKills,
            distance_studs = sheriffDist,
            is_bot = sheriffP == me,
            gun_available = gunAvailable,
            gun_equipped = gunEquipped,
            gun_dropped = gunDropped,
        },
    }
    return "ok", Http:JSONEncode(payload)
end

local function bridgeTpMessage(targetQuery)
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    local t
    if bridgeTrim(targetQuery) == "" then
        t = findOwner()
    else
        t = findPlayer(targetQuery) or findOtherPlayer(targetQuery)
    end
    if not t then
        return "error", "Player not found"
    end
    tpTo(t)
    return "ok", "Teleported to " .. bridgeTargetLabel(t)
end

local function bridgeResetMessage()
    if not session.ownerId then
        return "error", "No owner — join your reserved server first"
    end
    reset()
    return "ok", "Bot reset"
end

local function processBridgeCommands(jobId, commands)
    if type(commands) ~= "table" then return end
    for _, cmd in ipairs(commands) do
        if type(cmd) == "table" and cmd.id and not bridgeAcked[cmd.id] then
            local ctype = cmd.type
            if ctype == "help" then
                local topic = cmd.topic or cmd.command or ""
                local st, msg = bridgeHelpMessage(topic)
                log("bridge: help")
                bridgeAck(jobId, cmd.id, st, msg)
            elseif ctype == "toggle_gun" then
                log("bridge: toggle_gun")
                local mode = cmd.mode or cmd.action or ""
                bridgeExecuteAfterPollDelay(jobId, cmd.id, function()
                    return bridgeToggleGunMessage(mode)
                end, cmd)
            elseif ctype == "toggle_reveal" then
                log("bridge: toggle_reveal")
                local mode = cmd.mode or cmd.action or ""
                bridgeExecuteAfterPollDelay(jobId, cmd.id, function()
                    return bridgeToggleRevealMessage(mode)
                end, cmd)
            elseif ctype == "toggle_alerts" then
                log("bridge: toggle_alerts")
                local mode = cmd.mode or cmd.action or ""
                bridgeExecuteAfterPollDelay(jobId, cmd.id, function()
                    return bridgeToggleAlertsMessage(mode)
                end, cmd)
            elseif ctype == "chat" then
                log("bridge: chat")
                local text = cmd.message or cmd.text or ""
                bridgeExecuteAfterPollDelay(jobId, cmd.id, function()
                    return bridgeChatMessage(text)
                end, cmd)
            elseif ctype == "gun" then
                log("bridge: gun")
                local target = cmd.target or cmd.player or ""
                bridgeExecuteAfterPollDelay(jobId, cmd.id, function()
                    return bridgeGunMessage(target)
                end, cmd)
            elseif ctype == "stab" then
                log("bridge: stab")
                local target = cmd.target or cmd.query or ""
                bridgeExecuteAfterPollDelay(jobId, cmd.id, function()
                    return bridgeStabMessage(target)
                end, cmd)
            elseif ctype == "fling" then
                log("bridge: fling")
                local target = cmd.target or cmd.query or ""
                bridgeExecuteAfterPollDelay(jobId, cmd.id, function()
                    return bridgeFlingMessage(target)
                end, cmd)
            elseif ctype == "tp" then
                log("bridge: tp")
                local target = cmd.target or cmd.player or ""
                bridgeExecuteAfterPollDelay(jobId, cmd.id, function()
                    return bridgeTpMessage(target)
                end, cmd)
            elseif ctype == "reveal" then
                log("bridge: reveal")
                bridgeExecuteAfterPollDelay(jobId, cmd.id, function()
                    return bridgeRevealMessage()
                end, cmd)
            elseif ctype == "reset" then
                log("bridge: reset")
                bridgeExecuteAfterPollDelay(jobId, cmd.id, function()
                    return bridgeResetMessage()
                end, cmd)
            else
                bridgeAck(jobId, cmd.id, "error", "unknown command")
            end
        end
    end
end

local function restoreOwnerFromClaim(claim)
    if type(claim) ~= "table" then return end
    local oid = tonumber(claim.owner_id)
    if oid and oid > 0 and session.ownerId ~= oid then
        session.ownerId = oid
        G.MM_PendingOwnerId = oid
        log("bridge: restored owner " .. tostring(oid))
    end
end

local function processBridgeClaim(claim)
    if type(claim) ~= "table" then return end
    syncOwnerPremiumFromClaim(claim)
    local st = claim.status
    if st == "in_use" or st == "fulfilled" then
        bridgeOwnerConnected = true
        syncConfiguredOwner()
        restoreOwnerFromClaim(claim)
        if claim.roblox_username and claim.id then
            bridgeClaimId = claim.id
            if bridgeFulfilledClaimId ~= claim.id then
                fulfillBridgeClaim(claim.id, claim.roblox_username)
            end
        end
        return
    end
    if st == "awaiting_join" and claim.roblox_username and claim.id then
        bridgeOwnerConnected = true
        bridgeClaimId = claim.id
        bridgeAwaitingName = claim.roblox_username
        bridgeClaimExpiresAt = tonumber(claim.expires_at) or (os.time() + BRIDGE_CLAIM_WAIT_SEC)
        if claim.age_group then
            G.MM_OwnerAgeGroup = claim.age_group
        end
        if bridgeFulfilledClaimId ~= claim.id then
            fulfillBridgeClaim(claim.id, claim.roblox_username)
        end
    elseif st == "available" or not claim.roblox_username then
        bridgeOwnerConnected = false
        session.ownerId = nil
        G.MM_PendingOwnerId = nil
        if bridgeAwaitingName and os.time() >= bridgeClaimExpiresAt then
            clearBridgeReservation("expired")
        elseif not bridgeAwaitingName then
            bridgeClaimId = nil
            bridgeClaimExpiresAt = 0
        end
    end
end

G.MM_RegionSpreadCheck = G.MM_RegionSpreadCheck or false
G.MM_RegionSpreadAttempts = G.MM_RegionSpreadAttempts or 0

local function getServerLocationLabel()
    if G.MM_ServerLocationJob == game.JobId and G.MM_ServerLocationCache then
        return G.MM_ServerLocationCache
    end
    local raw = httpGet("http://ip-api.com/json/?fields=status,countryCode,city")
    if not raw then return nil end
    local ok, data = pcall(function() return Http:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" or data.status ~= "success" then return nil end
    local country = tostring(data.countryCode or ""):upper()
    local city = tostring(data.city or "")
    local label
    if country ~= "" and city ~= "" then
        label = country .. ", " .. city
    elseif country ~= "" then
        label = country
    elseif city ~= "" then
        label = city
    end
    if label and label ~= "" then
        G.MM_ServerLocationJob = game.JobId
        G.MM_ServerLocationCache = label
        return label
    end
    return nil
end

local function countRegionPeers(location)
    if not location or location == "" or not XENO_BRIDGE_ENABLED then return 0 end
    local qs = "location=" .. Http:UrlEncode(location) .. "&bot_user_id=" .. tostring(me.UserId)
    local raw = httpJson("GET", XENO_BRIDGE_URL .. "/api/xeno/region-peers?" .. qs)
    if not raw then return 0 end
    local ok, data = pcall(function() return Http:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" or not data.ok then return 0 end
    return tonumber(data.count) or 0
end

local function ensureRegionSpreadOnStart()
    if not XENO_BRIDGE_ENABLED or hopBusy then return end
    if G.MM_RegionSpreadAttempts >= REGION_SPREAD_MAX_ATTEMPTS then
        log("region spread: max attempts reached, staying")
        G.MM_RegionSpreadAttempts = 0
        return
    end
    local loc = getServerLocationLabel()
    if not loc then
        log("region spread: location unknown")
        return
    end
    pcall(function() bridgePollOnce() end)
    local peers = countRegionPeers(loc)
    log(("region spread: %d other bot(s) in %s"):format(peers, loc))
    if peers < REGION_PEER_MAX then
        G.MM_RegionSpreadAttempts = 0
        G.MM_RegionSpreadCheck = false
        return
    end
    G.MM_RegionSpreadAttempts = (G.MM_RegionSpreadAttempts or 0) + 1
    log(("region spread: hopping (%d/%d)"):format(G.MM_RegionSpreadAttempts, REGION_SPREAD_MAX_ATTEMPTS))
    G.MM_RegionSpreadCheck = true
    queueRegionSpreadOnTeleport()
    hopServer("region spread", false)
end

local function bridgePollOnce()
    local configuredOwner = findConfiguredOwner()
    if bridgeOwnerConnected then
        configuredOwner = syncConfiguredOwner()
    end
    local claimEvent = nil
    if bridgeAwaitingName and bridgeClaimExpiresAt > 0 and os.time() >= bridgeClaimExpiresAt then
        claimEvent = "released"
        bridgeAwaitingName = nil
        bridgeClaimId = nil
        bridgeClaimExpiresAt = 0
    end
    local pollBody = {
        job_id = game.JobId,
        bot_username = me.Name,
        bot_user_id = me.UserId,
        owner_username = XENO_OWNER_USERNAME ~= "" and XENO_OWNER_USERNAME or nil,
        owner_present = configuredOwner ~= nil,
        place_id = game.PlaceId,
        owner_id = configuredOwner and configuredOwner.UserId or nil,
        player_count = #Players:GetPlayers(),
        claim_event = claimEvent,
        claim_id = bridgeClaimId,
        bot_note = bridgeAwaitingName and ("waiting:" .. bridgeAwaitingName) or nil,
    }
    local serverLoc = getServerLocationLabel()
    if serverLoc then
        pollBody.server_location = serverLoc
    end
    local raw = httpJson("POST", XENO_BRIDGE_URL .. "/api/xeno/poll", pollBody)
    if not raw then return false end
    local ok, data = pcall(function() return Http:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" or not data.ok then return false end
    processBridgeCommands(game.JobId, data.commands)
    processBridgeClaim(data.claim)
    if data.availability == "available" and bridgeAwaitingName and not claimEvent then
        clearBridgeReservation("server available")
    end
    return true
end

Players.PlayerAdded:Connect(function(pl)
    if not XENO_BRIDGE_ENABLED or pl == me then return end
    if configuredOwnerMatches(pl) then
        task.defer(syncConfiguredOwner)
    end
    if bridgeAwaitingName and nameMatchesPlayer(pl, bridgeAwaitingName) and bridgeClaimId then
        task.defer(function()
            fulfillBridgeClaim(bridgeClaimId, bridgeAwaitingName)
        end)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if not XENO_BRIDGE_ENABLED then return end
    if session.ownerId and p.UserId == session.ownerId then
        if hopBusy then return end
        bridgeFulfilledClaimId = nil
        bridgeReportClaimEvent("owner_left", { owner_id = nil, note = p.Name })
    end
end)

if XENO_BRIDGE_ENABLED then
    task.spawn(function()
        log("bridge: polling " .. XENO_BRIDGE_URL .. " every " .. tostring(XENO_POLL_SEC) .. "s")
        local fails = 0
        while session.active do
            if not bridgePollOnce() then
                fails = fails + 1
                if fails == 3 then
                    log("bridge: cannot reach Flask (is discord-xeno.py running?)")
                end
            else
                fails = 0
            end
            task.wait(XENO_POLL_SEC)
        end
    end)
end

task.spawn(function()
    local joinedAt = tick()
    local badPingSince = nil
    local skipThisJoin = not hopState.pingSearchActive
    while session.active do
        if not skipThisJoin and not hopBusy then
            local ping = getPingMs()
            if ping then
                local inRange = ping >= PING_MIN_MS and ping <= PING_MAX_MS
                if inRange then
                    if hopState.pingSearchActive then
                        hopState.pingSearchActive = false
                        log(("ping hop: found %.0fms server"):format(ping))
                    end
                    badPingSince = nil
                else
                    badPingSince = badPingSince or tick()
                    if tick() - joinedAt >= 20 and tick() - badPingSince >= 15 then
                        local owner = findOwner()
                        if owner then whisper(("High ping (%dms), hopping"):format(math.floor(ping + 0.5))) end
                        if not hopServer(("ping %.0fms"):format(ping), true) then
                            badPingSince = tick() - 10
                        end
                    end
                end
            end
        end
        task.wait(5)
    end
end)

--[[ Alerts watcher ]]--
local function aliveState(p)
    local char = p.Character
    if not char then return nil end
    local h = char:FindFirstChildOfClass("Humanoid")
    if not h then return nil end
    return h.Health > 0
end
task.spawn(function()
    local alivePrev = {}
    local knifeIdPrev, gunIdPrev = nil, nil
    local droppedGunPrev = false
    local suppressDrop = false
    while session.active do
        local kHolder = findHolder({"Knife"})
        local gHolder = findHolder({"Gun", "Revolver"})
        local kid = kHolder and kHolder.UserId
        local gid = gHolder and gHolder.UserId
        local droppedGun = findDroppedGun() ~= nil
        if kid and not knifeIdPrev then suppressDrop = false end
        -- Always watch owner life (not gated on toggleAlerts); nil cur = character gone after death.
        if session.ownerId then
            local own = Players:GetPlayerByUserId(session.ownerId)
            if own and own ~= me then
                local cur = aliveState(own)
                local prev = alivePrev[own.UserId]
                if prev == true and (cur == false or cur == nil) then
                    if not toggleResetOnOwnerDeath then
                        log("owner died (reset on death off)")
                    elseif _G.MM_GunBusy or _G.MM_StabBusy then
                        _G.MM_OwnerDiedPendingReset = true
                        log("owner died during combat (reset deferred)")
                    else
                        log("owner died -> resetting bot")
                        task.spawn(function() pcall(reset) end)
                    end
                end
            end
        end
        if toggleAlerts and session.ownerId then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= me then
                    local cur = aliveState(p)
                    local prev = alivePrev[p.UserId]
                    if prev == true and cur == false then
                        if p.UserId == knifeIdPrev then
                            whisper("Sheriff killed the murderer")
                            suppressDrop = true
                        elseif p.UserId == gunIdPrev then
                            whisper("Murderer killed Sheriff")
                        elseif knifeIdPrev then
                            murdererRoundKills = murdererRoundKills + 1
                            whisper("Murderer killed " .. shortName(p))
                        elseif gunIdPrev then
                            sheriffRoundKills = sheriffRoundKills + 1
                            whisper("Sheriff shot " .. shortName(p))
                        end
                    end
                end
            end
            if gunIdPrev and not gid and not suppressDrop then
                local prev = Players:GetPlayerByUserId(gunIdPrev)
                if prev and aliveState(prev) == true then
                    whisper("Sheriff dropped the gun")
                end
            end
            if not gunIdPrev and gid and droppedGunPrev and gHolder then
                whisper(shortName(gHolder) .. " picked up the gun")
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            local cur = aliveState(p)
            if cur ~= nil then
                alivePrev[p.UserId] = cur
            elseif alivePrev[p.UserId] == true then
                alivePrev[p.UserId] = false
            end
        end
        if kid ~= whoKnifeIdPrev then
            murdererRoundKills = 0
            whoKnifeIdPrev = kid
        end
        if gid ~= whoGunIdPrev then
            sheriffRoundKills = 0
            whoGunIdPrev = gid
        end
        knifeIdPrev = kid
        gunIdPrev = gid
        droppedGunPrev = droppedGun
        task.wait(0.12)
    end
end)

log("bot online")

if XENO_BRIDGE_ENABLED then
    task.spawn(function()
        task.wait(G.MM_RegionSpreadCheck and 3 or 2)
        ensureRegionSpreadOnStart()
    end)
end

local function resolveRoleSnapshot(timeout)
    local deadline = tick() + (timeout or 0)
    local curM, curS, curBotM, curBotS
    repeat
        curM = findHolder({"Knife"})
        curS = findHolder({"Gun", "Revolver"})
        curBotM = botHasKnife()
        curBotS = botHasGun()
        if (curBotM or curM) and (curBotS or curS) then
            break
        end
        if tick() >= deadline then break end
        task.wait(0.15)
    until false
    return curM, curS, curBotM, curBotS
end

local function sendRoundRoleCallouts(curM, curS, curBotM, curBotS)
    if not session.ownerId then return false end
    local mLabel = curBotM and "Me" or (curM and shortName(curM)) or "?"
    local sLabel = curBotS and "Me" or (curS and shortName(curS)) or "?"
    if not whisperOk("Murderer: " .. mLabel) then return false end
    task.wait(0.35)
    return whisperOk("Sheriff: " .. sLabel)
end

local function waitForRoleCallouts(curM, curS, curBotM, curBotS)
    for _ = 1, 8 do
        if sendRoundRoleCallouts(curM, curS, curBotM, curBotS) then
            return true, curM, curS, curBotM, curBotS
        end
        task.wait(0.55)
        curM, curS, curBotM, curBotS = resolveRoleSnapshot(0.5)
    end
    return false, curM, curS, curBotM, curBotS
end

--[[ Main loop ]]--
local lastMurderId, announced
local ownerMurdStashBusy = false
while session.active and gui.Parent do
    local m, s = findHolder({"Knife"}), findHolder({"Gun", "Revolver"})
    local botM, botS = botHasKnife(), botHasGun()
    local roundActive = isRoundActive()

    if m then
        if lastMurderId ~= m.UserId then
            lastMurderId = m.UserId
            pcall(function() img.Image = Players:GetUserThumbnailAsync(m.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150) end)
            lbl.Text = m.DisplayName
        end
        f.Visible = true
    else f.Visible, lastMurderId = false, nil end

    if (m or botM) and not announced then
        announced = true
        gunDelivered = false
        revealAnnouncePending = true
        tpHome()
        local owner = findOwner()
        task.spawn(function()
            local curM, curS, curBotM, curBotS = resolveRoleSnapshot(2.5)

            if toggleReveal and session.ownerId then
                local ok
                ok, curM, curS, curBotM, curBotS = waitForRoleCallouts(curM, curS, curBotM, curBotS)
                if not ok then
                    curM, curS, curBotM, curBotS = resolveRoleSnapshot(0.5)
                end
            else
                curM, curS, curBotM, curBotS = resolveRoleSnapshot(0.5)
            end

            if curBotM and owner and curS and owner.UserId == curS.UserId then
                tpTo(owner)
            elseif session.ownerId and not curBotM then
                tpHome()
            end

            roleAnnounceUnlockAt = tick() + 0.35
            revealAnnouncePending = false
        end)
    elseif not roundActive then
        announced, gunDelivered, revealAnnouncePending = false, false, false
        ownerMurdStashBusy = false
        roleAnnounceUnlockAt = 0
    end

    local ownerForDrop = findOwner()
    local ownerIsMurd = ownerMurdererActive(m, ownerForDrop) and not botM
    -- Do not clear toggleGun here — owner-murderer only pauses delivery below; user setting stays on.

    -- Owner murderer: stash guns at spawn only if premium owner enabled !toggledrop
    if session.ownerId and ownerIsMurd and ownerIsPremium() and toggleDrop and roundActive and SPAWN_CFRAME
       and not ownerMurdStashBusy and not revealAnnouncePending
       and tick() >= roleAnnounceUnlockAt
       and isAlive(me) and gunAvailableForOwnerMurdStash()
       and not _G.MM_GunBusy and not _G.MM_StabBusy
       and not flingActive and not flingLoopActive and not flingLoopContinuous and not flingSettling
    then
        ownerMurdStashBusy = true
        _G.MM_GunBusy = true
        task.spawn(function()
            pcall(stashGunAtSpawn)
            task.wait(OWNER_MURD_STASH_COOLDOWN)
            _G.MM_GunBusy = false
            ownerMurdStashBusy = false
        end)
    end

    local gunTarget = (gunTargetId and Players:GetPlayerByUserId(gunTargetId)) or findOwner()
    if toggleGun and not flingLoopContinuous and not botM and not ownerIsMurd and not gunDelivered and not _G.MM_GunBusy and not _G.MM_StabBusy and me.Character
       and not revealAnnouncePending and tick() >= roleAnnounceUnlockAt
       and not flingActive and not flingLoopActive and not flingSettling
       and gunTarget and gunTarget ~= me and isAlive(gunTarget)
       and gunAvailableForOwnerMurdStash() then
        gunDelivered = true
        _G.MM_GunBusy = true
        task.spawn(function() bringGun(gunTarget); task.wait(3); _G.MM_GunBusy = false end)
    end

    local subject = (s and s.Character and s.Character:FindFirstChildOfClass("Humanoid"))
                  or findDroppedGun()
                  or (me.Character and me.Character:FindFirstChildOfClass("Humanoid"))
    if cam.CameraType ~= Enum.CameraType.Custom then cam.CameraType = Enum.CameraType.Custom end
    if subject then cam.CameraSubject = subject end
    cam.FieldOfView = WIDE_FOV
    task.wait(0.5)
end

--[[ Cleanup ]]--
cam.FieldOfView = DEFAULT_FOV
do local h = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
   if h then cam.CameraSubject = h end end
