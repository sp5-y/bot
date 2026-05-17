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
local VIM = pcall(function() return cref(game:GetService("VirtualInputManager")) end) and cref(game:GetService("VirtualInputManager")) or nil
local isLegacy = TCS.ChatVersion == Enum.ChatVersion.LegacyChatService
local me, cam = Players.LocalPlayer, workspace.CurrentCamera
local DEFAULT_FOV, WIDE_FOV = 70, 100
local SPAWN_CFRAME = CFrame.new(14.3513288, 505.044952, -58.2513657, 1, 0, 0, 0, 1, 0, 0, 0, 1)
local FRAUD_NAME = "fraud4balenci"
local toggleGun = false
local toggleShoot = false
local toggleAlerts = false
local toggleWho = true
local fraudOptedOut = false
local gunTargetId = nil
local gunDelivered = false
local hopBusy = false
local PING_MIN_MS, PING_MAX_MS = 50, 90
local G = getgenv and getgenv() or _G
G.MM_HopState = G.MM_HopState or {pingSearchActive = false}
local hopState = G.MM_HopState

--[[ Session ]]--
if getgenv and getgenv().MM_Session then getgenv().MM_Session.active = false end
if game.CoreGui:FindFirstChild("MM") then game.CoreGui.MM:Destroy() end
local session = {active = true, ownerId = nil}
if getgenv then getgenv().MM_Session = session end
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
    local p = Players:GetPlayerByUserId(session.ownerId)
    if p and p ~= me then return p end
end
local function getOwnerPlayer()
    if not session.ownerId then return end
    return Players:GetPlayerByUserId(session.ownerId)
end
local function ownerIsMurderer()
    local owner = getOwnerPlayer()
    if not owner then return false end
    local murd = findHolder({"Knife"})
    return murd and murd.UserId == owner.UserId
end
local function shortName(p) return p.Name:sub(1, 4) .. "..." end
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
local function toolMatchesName(toolName, names)
    for _, n in ipairs(names) do
        if toolName == n then return true end
    end
    return false
end
local function getHeldTool(p, names)
    for _, container in ipairs({p.Character, p:FindFirstChildOfClass("Backpack")}) do
        for _, c in ipairs(container and container:GetChildren() or {}) do
            if c:IsA("Tool") and toolMatchesName(c.Name, names) then
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
    local cursor, fallback = nil, nil
    for _ = 1, 5 do
        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100"):format(game.PlaceId)
        if cursor and cursor ~= "" then
            url = url .. "&cursor=" .. Http:UrlEncode(cursor)
        end
        local raw = httpGet(url)
        if not raw then break end
        local ok, page = pcall(function() return Http:JSONDecode(raw) end)
        if not ok or type(page) ~= "table" then break end
        for _, server in ipairs(page.data or {}) do
            local playing = tonumber(server.playing) or 0
            local maxPlayers = tonumber(server.maxPlayers) or 0
            if server.id ~= game.JobId and playing < maxPlayers and playing > 0 then
                if playing > 2 then return server.id end
                if not fallback then fallback = server.id end
            end
        end
        cursor = page.nextPageCursor
        if not cursor or cursor == "" then break end
    end
    return fallback
end

local function hopServer(reason, continuePingSearch)
    if hopBusy then return false end
    hopBusy = true
    if continuePingSearch then
        hopState.pingSearchActive = true
        queuePingSearchOnTeleport()
    end
    log("server hop: " .. tostring(reason or "requested"))
    local serverId = findHopServer()
    if not serverId then
        log("server hop: no server found")
        hopBusy = false
        return false
    end
    local ok = pcall(function()
        TeleportSvc:TeleportToPlaceInstance(game.PlaceId, serverId, me)
    end)
    if not ok then
        log("server hop failed")
        hopBusy = false
    end
    return ok
end

--[[ Movement ]]--
local function hrp() return me.Character and me.Character:FindFirstChild("HumanoidRootPart") end
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

local SHOOT_PREDICT_SEC = 0.16
local function shootPredictLead(root, hum, lastPos, lastT)
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
    if lastPos and lastT then
        local dt = tick() - lastT
        if dt > 0.02 and dt < 0.45 then
            local ev = (root.Position - lastPos) / dt
            local evh = Vector3.new(ev.X, 0, ev.Z)
            local vh = Vector3.new(v.X, 0, v.Z)
            if evh.Magnitude > vh.Magnitude then v = ev end
        end
    end
    local vh = Vector3.new(v.X, 0, v.Z)
    local spd = vh.Magnitude
    if spd <= 0.08 then return Vector3.zero end
    local ahead = spd * SHOOT_PREDICT_SEC
    local snap = math.min(spd * 0.2, 6)
    return vh.Unit * math.min(snap + ahead, 14)
end

local SHOOT_RANGE = 12
local SHOOT_HEIGHT = 7
local SHOOT_RELOAD_MIN = 2.35
local SHOOT_RELOAD_MAX = 4.5
local STAB_PREDICT_T = 0.14
local STAB_MAX_LEAD = 3
local STAB_MELEE_OFFSET = 1.05
local STAB_MOVE_MIN = 2
local STAB_IDLE_LOCAL = CFrame.new(-0.6, 0.08, 2.05)

-- Real travel direction (velocity + MoveDirection + position delta); ignores where they face.
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
    local aim = th.Position + Vector3.new(0, 1.2, 0)
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

-- Behind target, mid-air, sheriff gun range; look at chest with light lead
local function getShootCFrame(target)
    local th = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    if not th then return end
    local lead = shootPredictLead(th, hum, nil, nil)
    local aim = th.Position + Vector3.new(0, 1.2, 0) + Vector3.new(lead.X, 0, lead.Z)
    local back = th.CFrame.LookVector
    local flatBack = Vector3.new(-back.X, 0, -back.Z)
    if flatBack.Magnitude < 0.05 then flatBack = Vector3.new(0, 0, 1) end
    flatBack = flatBack.Unit
    local pos = th.Position + flatBack * SHOOT_RANGE + Vector3.new(0, SHOOT_HEIGHT, 0)
    return CFrame.new(pos, aim)
end

local function getBehindCFrame(target)
    return getShootCFrame(target)
end

local function getShootAimPoint(target)
    local th = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    if not th then return end
    local lead = shootPredictLead(th, hum, nil, nil)
    return th.Position + Vector3.new(0, 1.2, 0) + Vector3.new(lead.X, 0, lead.Z)
end

local function isAlive(p)
    local h = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
local function zeroVel(h)
    if not h then return end
    pcall(function() h.AssemblyLinearVelocity = Vector3.zero end)
    pcall(function() h.AssemblyAngularVelocity = Vector3.zero end)
    pcall(function() h.Velocity = Vector3.zero end)
    pcall(function() h.RotVelocity = Vector3.zero end)
end
local function getActiveCam()
    local c = workspace.CurrentCamera
    if c then cam = c end
    return c or cam
end
local function enableShootRender()
    pcall(function() RunSvc:Set3dRenderingEnabled(true) end)
end
local function equipTool(tool)
    local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if tool and hum and tool.Parent ~= me.Character then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.15)
    end
    return tool and tool.Parent == me.Character
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
local function tpCFrame(cf)
    local h = hrp()
    if h and cf then
        zeroVel(h)
        h.CFrame = cf
        zeroVel(h)
    end
end
local function tpBehindTarget(target)
    local cf = getBehindCFrame(target)
    if cf then tpCFrame(cf) end
    return cf ~= nil
end
local function tweenTo(cf, dur)
    local h = hrp(); if not h then return end
    local tw = Tween:Create(h, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = cf})
    tw:Play(); tw.Completed:Wait()
end
local function tpTo(p)
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
    local h = hrp()
    if h and SPAWN_CFRAME then
        zeroVel(h)
        h.CFrame = SPAWN_CFRAME
        zeroVel(h)
    end
end
local function tpHomeBurst(count)
    if not isAlive(me) or not SPAWN_CFRAME then return end
    count = count or 3
    for i = 1, count do
        tpHome()
        if i < count then task.wait(0.06) end
    end
end
_G.MM_StabBusy = _G.MM_StabBusy or false
_G.MM_ShootBusy = _G.MM_ShootBusy or false
_G.MM_OwnerDiedPendingReset = _G.MM_OwnerDiedPendingReset or false

local function reset()
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
    if _G.MM_OwnerDiedPendingReset and not _G.MM_ShootBusy and not _G.MM_StabBusy then
        _G.MM_OwnerDiedPendingReset = false
        log("owner died during combat -> resetting bot")
        task.spawn(function() pcall(reset) end)
    end
end
local function dropGunAt(target)
    if _G.MM_ShootBusy or _G.MM_StabBusy then return false end
    if not isAlive(target) then return false end
    local h = hrp()
    local oh = target.Character:FindFirstChild("HumanoidRootPart")
    if not (h and oh) then return false end
    h.CFrame = oh.CFrame + horizontalApproachLead(oh)
    task.wait(0.1); reset()
    return true
end
local function bringGun(target)
    if _G.MM_ShootBusy or _G.MM_StabBusy then return end
    target = target or getOwnerPlayer()
    if not isAlive(target) then return end
    if botHasGun() then dropGunAt(target); return end
    local g, h = findDroppedGun(), hrp()
    if not (g and h) then return end
    g.CFrame = h.CFrame
    task.wait(0.5)
    dropGunAt(target)
end
local function stashGunAtSpawn()
    if _G.MM_ShootBusy or _G.MM_StabBusy or _G.MM_GunBusy then return false end
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
local function pickUpDroppedGun()
    if botHasGun() then return true end
    local h = hrp()
    if not (h and isAlive(me)) then return false end
    local drop = workspace:FindFirstChild("GunDrop")
    if drop then
        pcall(function()
            if drop:IsA("BasePart") then
                drop.CFrame = h.CFrame
            elseif drop:IsA("Model") and drop.PrimaryPart then
                drop:SetPrimaryPartCFrame(h.CFrame)
            end
        end)
        task.wait(0.08)
        if botHasGun() then return true end
    end
    local g = findDroppedGun()
    if g then
        pcall(function() g.CFrame = h.CFrame end)
    end
    local t0 = tick()
    while session.active and tick() - t0 < 3 do
        if botHasGun() then return true end
        task.wait(0.05)
    end
    return botHasGun()
end
local function ensureShootGun()
    if botHasGun() then return true end
    return pickUpDroppedGun()
end
local function gunCanShoot(gun)
    if not gun or not gun.Parent then return false end
    for _, name in ipairs({"Reloading", "IsReloading", "reloading"}) do
        local v = gun:FindFirstChild(name, true)
        if v and v:IsA("BoolValue") and v.Value then return false end
    end
    for _, name in ipairs({"Ammo", "Bullets", "ammo"}) do
        local v = gun:FindFirstChild(name, true)
        if v and (v:IsA("IntValue") or v:IsA("NumberValue")) and v.Value <= 0 then return false end
    end
    return true
end

local function waitGunReloadAfterShot(gun)
    local t0 = tick()
    task.wait(0.12)
    local needLong = not gunCanShoot(gun)
    local minWait = needLong and SHOOT_RELOAD_MIN or 0.4
    while session.active and tick() - t0 < SHOOT_RELOAD_MAX do
        if tick() - t0 >= minWait and gunCanShoot(gun) then return true end
        task.wait(0.05)
    end
    if tick() - t0 < minWait then
        task.wait(minWait - (tick() - t0))
    end
    return true
end

local function fireGunOnce(gun)
    if not gun then return end
    pcall(function() gun:Activate() end)
    if getconnections then
        pcall(function()
            local c = getconnections(gun.Activated)
            if c then
                for _, conn in ipairs(c) do
                    pcall(function() conn:Fire() end)
                end
            end
        end)
    end
end

local function shootGunRemote(gun, aimPoint)
    if not gun or not aimPoint then return false end
    local remote = gun:FindFirstChild("ShootGun", true)
        or gun:FindFirstChild("Shoot", true)
    if not remote then
        for _, d in ipairs(gun:GetDescendants()) do
            if d.Name == "ShootGun" and (d:IsA("RemoteFunction") or d:IsA("RemoteEvent")) then
                remote = d
                break
            end
        end
    end
    if not remote then return false end
    local ok = false
    pcall(function()
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer(aimPoint)
            ok = true
        else
            remote:FireServer(aimPoint)
            ok = true
        end
    end)
    if not ok then
        pcall(function()
            if remote:IsA("RemoteFunction") then
                remote:InvokeServer(tick(), aimPoint)
            else
                remote:FireServer(tick(), aimPoint)
            end
            ok = true
        end)
    end
    return ok
end

local function clickGunFire(gun, mouseX, mouseY)
    fireGunOnce(gun)
    if mouse1click then
        pcall(mouse1click)
    elseif mouse1press and mouse1release then
        pcall(mouse1press)
        task.wait(0.04)
        pcall(mouse1release)
    end
    clickFire(mouseX, mouseY)
end
local function clickFire(x, y)
    if not VIM then return end
    x = tonumber(x) or 0
    y = tonumber(y) or 0
    pcall(function()
        VIM:SendMouseMoveEvent(x, y, game)
    end)
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end
-- Fire at target from behind TP; wait for reload before caller returns to spawn
local function fireGunAtTarget(target, gun)
    if not gun or not isAlive(target) or not isAlive(me) then return false end
    enableShootRender()
    local aimPoint = getShootAimPoint(target)
    local mh = hrp()
    if not (aimPoint and mh) then return false end
    zeroVel(mh)
    mh.CFrame = CFrame.new(mh.Position, aimPoint)
    zeroVel(mh)
    pcall(function() mh.Anchored = true end)
    task.wait(0.05)
    local shootCam = getActiveCam()
    local mouseX, mouseY = 400, 300
    if shootCam then
        pcall(function()
            local lookCf = CFrame.new(mh.Position, aimPoint)
            shootCam.CFrame = lookCf
            local vs = shootCam.ViewportSize
            mouseX, mouseY = vs.X * 0.5, vs.Y * 0.45
            local sp = shootCam:WorldToViewportPoint(aimPoint)
            if sp.Z > 0 then
                mouseX, mouseY = sp.X, sp.Y
            end
        end)
    end
    shootGunRemote(gun, aimPoint)
    clickGunFire(gun, mouseX, mouseY)
    task.wait(0.08)
    clickGunFire(gun, mouseX, mouseY)
    pcall(function() mh.Anchored = false end)
    waitGunReloadAfterShot(gun)
    return true
end

-- One pass: gun -> equip -> TP behind -> shoot -> wait reload (then loop TPs spawn)
local function shootPass(target)
    if not isAlive(target) or not isAlive(me) then return false end
    if botHasKnife() then return false end
    if not ensureShootGun() then return false end
    local gun = getHeldTool(me, {"Gun", "Revolver"})
    if not gun or not equipTool(gun) then return false end
    local cf = getShootCFrame(target)
    local mh = hrp()
    if not (cf and mh) then return false end
    zeroVel(mh)
    mh.CFrame = cf
    zeroVel(mh)
    return fireGunAtTarget(target, gun)
end

-- Pick up / equip, TP behind, shoot, wait reload, spawn, wait 1.2-2s; until bot or target dies
local function shootTargetLoop(target)
    if target == me then return false, "Invalid target" end
    if ownerIsMurderer() then return false, "Owner is murderer" end
    if not isAlive(target) then return false, "Player not found" end
    if botHasKnife() then return false, "No gun available" end
    if not ensureShootGun() then return false, "No gun available" end
    while session.active and isAlive(me) and isAlive(target) do
        if ownerIsMurderer() then
            tpHome()
            return false, "Owner is murderer"
        end
        if not ensureShootGun() then
            return false, "No gun available"
        end
        shootPass(target)
        tpHome()
        if not isAlive(target) then
            return true, "Killed " .. shortName(target)
        end
        if not isAlive(me) then
            log("bot died during shoot")
            return false, "Bot died"
        end
        task.wait(math.random(12, 20) / 10)
    end
    if not isAlive(me) then
        log("bot died during shoot")
        return false, "Bot died"
    end
    if not isAlive(target) then return true, "Killed " .. shortName(target) end
    return true, "Stopped shooting " .. shortName(target)
end

local function stabPass(target, lastPos, lastT)
    if not isAlive(target) or not isAlive(me) then return false end
    if not botHasKnife() then return false end
    local knife = getHeldTool(me, {"Knife"})
    if not knife or not equipTool(knife) then return false end
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

local function disableToggleGun(notify)
    if not toggleGun then return false end
    toggleGun = false
    gunTargetId, gunDelivered = nil, false
    if notify then whisper("Auto-gun: off") end
    return true
end

local function disableToggleShoot(notify)
    if not toggleShoot then return false end
    toggleShoot = false
    if notify then whisper("Auto-shoot murderer: off") end
    return true
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

local function isOnlyMurdererLeftWithBot(murderer)
    if not murderer or botHasKnife() then return false end
    if not isAlive(me) or not isAlive(murderer) then return false end
    local alive = getAliveExcludingBot()
    return #alive == 1 and alive[1].UserId == murderer.UserId
end

--[[ Commands ]]--
local COMMAND_HELP = {
    owner = "Claim control of the bot",
    dethrone = "Release owner control",
    who = "Show current murderer and sheriff",
    shoot = "<player> - Shoot a given player",
    stab = "sheriff | <name> - Murderer only, Stab a given player",
    toggleshoot = "Toggle auto shoot on murderer each round",
    togglewho = "Toggle automatic role callout each round",
    togglealerts = "Toggle kill/drop/pickup alerts",
    reset = "Force bot respawn",
    tp = "<player> - Teleport bot to a player",
    tpmurd = "Teleport bot to the murderer",
    tpsher = "Teleport bot to the sheriff",
    spawn = "Teleport bot to spawn",
    gun = "<player> - Deliver gun to a player",
    togglegun = "<player> - Auto-deliver gun to a player",
    chat = "<msg> - Make bot send a public chat message",
    fling = "<player> - Flings player off the map",
    help = "<cmd> - Show command list or explain one command",
}
local HELP_ORDER = {
    "owner", "dethrone", "tp", "who", "shoot", "stab", "toggleshoot", "gun", "fling", "togglegun", "togglewho", "togglealerts",
    "reset", "chat", "help",
}
local function sendFullHelp(target)
    local o = target or findOwner()
    if not o then return end
    whisper("Use !help <command> for what a command does", o)
    task.wait(0.5)
    local parts = {}
    for _, key in ipairs(HELP_ORDER) do
        table.insert(parts, "!" .. key)
    end
    local line = table.concat(parts, " ")
    if #line <= 200 then
        whisper(line, o)
        return
    end
    local mid = math.ceil(#HELP_ORDER / 2)
    local a, b = {}, {}
    for i, key in ipairs(HELP_ORDER) do
        if i <= mid then table.insert(a, "!" .. key) else table.insert(b, "!" .. key) end
    end
    whisper(table.concat(a, " "), o)
    task.wait(0.5)
    whisper(table.concat(b, " "), o)
end

local function handleCommand(p, msg)
    if msg:sub(1, 1) ~= "!" then return end
    local args = msg:split(" ")
    local cmd, rest = args[1]:sub(2):lower(), msg:sub(#args[1] + 2)
    if cmd == "owner" then
        local isFraud = p.Name:lower() == FRAUD_NAME
        if not session.ownerId or isFraud or session.ownerId == p.UserId then
            session.ownerId = p.UserId
            if isFraud then fraudOptedOut = false end
        end
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
    local ownerIsMurd = session.ownerId and m and not botHasKnife() and m.UserId == session.ownerId
    if cmd == "dethrone" then
        if p.Name:lower() == FRAUD_NAME then fraudOptedOut = true end
        session.ownerId = nil
        toggleGun, toggleShoot, toggleAlerts, toggleWho = false, false, false, true
        gunTargetId, gunDelivered = nil, false
        sendChat("Owner released — type !owner to claim")
        return
    elseif cmd == "chat" then
        sendChat(rest)
        whisper("Chat sent")
    elseif cmd == "who" then
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
        whisper("Teleported to " .. shortName(t))
    elseif cmd == "tpmurd" then
        if not m then whisper("Murderer not found") return end
        tpTo(m)
        whisper("Teleported to murderer")
    elseif cmd == "tpsher" then
        if not s then whisper("Sheriff not found") return end
        tpTo(s)
        whisper("Teleported to sheriff")
    elseif cmd == "shoot" then
        local q = restOfChatArgs(args)
        if q == "" then whisper("!shoot <player>") return end
        local picked = findOtherPlayer(q)
        if not picked then whisper("Player not found") return end
        local targetUid = picked.UserId
        local shootName = shortName(picked)
        if ownerIsMurd or botHasKnife() or ownerIsMurderer() then whisper("No gun available") return end
        if not (botHasGun() or findDroppedGun() or workspace:FindFirstChild("GunDrop")) then
            whisper("No gun available") return
        end
        if _G.MM_ShootBusy then whisper("Shoot busy, try again") return end
        _G.MM_ShootBusy = true
        whisper("Shooting " .. shootName)
        task.spawn(function()
            local status = "Player not found"
            local ok, err = pcall(function()
                local tgt = Players:GetPlayerByUserId(targetUid)
                if not tgt or not isAlive(tgt) then return end
                if ownerIsMurderer() or botHasKnife() or not ensureShootGun() then
                    status = "No gun available"
                    return
                end
                local _, msg = shootTargetLoop(tgt)
                if msg and msg ~= "" then
                    status = msg
                else
                    status = "No gun available"
                end
            end)
            if not ok then
                status = "Shoot failed"
                log("shoot error: " .. tostring(err))
            end
            if status and status ~= "Bot died" and not status:match("^Killed ") then
                task.wait(0.35)
            end
            whisperCombatResult(status)
            _G.MM_ShootBusy = false
            runDeferredOwnerResetIfIdle()
        end)
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
        if ownerIsMurd then whisper("No gun available") return end
        if botHasKnife() then whisper("No gun available") return end
        if not (botHasGun() or findDroppedGun()) then whisper("No gun available") return end
        bringGun(t)
        whisper("Gun delivered to " .. shortName(t))
    elseif cmd == "spawn" or cmd == "home" then
        tpHome()
        whisper("Teleported to spawn")
    elseif cmd == "reset" then
        whisper("Resetting")
        reset()
    elseif cmd == "rejoin" then
        whisper("Rejoining")
        hopServer("manual rejoin", false)
    elseif cmd == "togglegun" then
        if ownerIsMurd then whisper("No gun available") return end
        if args[2] then
            local t = findPlayer(args[2])
            if not t then whisper("Player not found") return end
            disableToggleShoot(true)
            toggleGun, gunTargetId, gunDelivered = true, t.UserId, false
            whisper("Auto-gun on: " .. shortName(t))
        else
            if toggleGun then
                toggleGun = false
                gunTargetId, gunDelivered = nil, false
                whisper("Auto-gun: off")
            else
                disableToggleShoot(true)
                toggleGun = true
                gunTargetId, gunDelivered = nil, false
                whisper("Auto-gun: on")
            end
        end
    elseif cmd == "togglealerts" then
        toggleAlerts = not toggleAlerts
        whisper("Kill alerts: " .. (toggleAlerts and "on" or "off"))
    elseif cmd == "togglewho" then
        toggleWho = not toggleWho
        whisper("Role callouts: " .. (toggleWho and "on" or "off"))
    elseif cmd == "toggleshoot" then
        if ownerIsMurd or botHasKnife() then whisper("No gun available") return end
        if toggleShoot then
            toggleShoot = false
            whisper("Auto-shoot murderer: off")
        else
            disableToggleGun(true)
            toggleShoot = true
            whisper("Auto-shoot murderer: on")
        end
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
            sendFullHelp(p)
        end
    end
end
local function routeCommand(p, msg)
    msg = cleanChatText(msg)
    if msg == "" or seenCommandRecently(p, msg) then return end
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
local function tryAutoClaimFraud(p)
    if fraudOptedOut then return end
    if session.ownerId then return end
    if p.Name:lower() ~= FRAUD_NAME then return end
    if p == me then return end
    session.ownerId = p.UserId
    log("auto-claimed fraud as owner: " .. p.DisplayName)
end
local function hookSpeaker(p)
    p.Chatted:Connect(function(msg)
        routeCommand(p, msg)
        watchHiddenChat(p, msg)
    end)
    tryAutoClaimFraud(p)
end
for _, p in ipairs(Players:GetPlayers()) do hookSpeaker(p) end
Players.PlayerAdded:Connect(hookSpeaker)
Players.PlayerRemoving:Connect(function(p)
    if session.ownerId and p.UserId == session.ownerId then
        session.ownerId = nil
        toggleGun, toggleShoot, toggleAlerts, toggleWho = false, false, false, true
        gunTargetId, gunDelivered = nil, false
        sendChat("Owner left — type !owner to claim")
    end
end)

if not session.ownerId then
    session.ownerId = me.UserId
end

task.spawn(function()
    local lastOwner = nil
    while session.active do
        if session.ownerId and session.ownerId ~= lastOwner then
            lastOwner = session.ownerId
            local owner = findOwner()
            log("new owner: " .. (owner and owner.DisplayName or "nil"))
            if owner then
                local target = owner
                local targetId = owner.UserId
                task.spawn(function()
                    task.wait(2)
                    if session.ownerId ~= targetId then return end
                    whisper("Loading new owner", target)
                end)
                task.spawn(function()
                    task.wait(5)
                    if session.ownerId ~= targetId then return end
                    sendFullHelp(target)
                end)
            end
        elseif not session.ownerId then
            lastOwner = nil
        end
        task.wait(0.5)
    end
end)

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
                    if _G.MM_ShootBusy or _G.MM_StabBusy then
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
                            whisper("Sheriff eliminated the murderer")
                            suppressDrop = true
                        elseif p.UserId == gunIdPrev then
                            whisper("Murderer killed Sheriff")
                        elseif knifeIdPrev then
                            whisper("Murderer killed " .. shortName(p))
                        elseif gunIdPrev then
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
        knifeIdPrev = kid
        gunIdPrev = gid
        droppedGunPrev = droppedGun
        task.wait(0.12)
    end
end)

log("bot online")

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

--[[ Main loop ]]--
local lastMurderId, announced, aloneMurderWinDone
local whoAnnouncePending = false
local ownerMurdStashBusy = false
local roleAnnounceUnlockAt = 0
local lastToggleShootTry = 0
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
        whoAnnouncePending = true
        -- Murderer / round detected: spawn TP immediately (main thread, before any msgs)
        tpHomeBurst(3)
        local owner = getOwnerPlayer()
        task.spawn(function()
            local curM, curS, curBotM, curBotS
            local murdKnown = false
            -- Wait for roles; re-TP spawn as soon as murderer exists, before whispers
            for _ = 1, 50 do
                curM = findHolder({"Knife"})
                curS = findHolder({"Gun", "Revolver"})
                curBotM = botHasKnife()
                curBotS = botHasGun()
                if (curM or curBotM) and not murdKnown then
                    murdKnown = true
                    tpHomeBurst(3)
                end
                if (curBotM or curM) and (curBotS or curS) then break end
                task.wait(0.05)
            end
            if not murdKnown and (curM or curBotM) then
                tpHomeBurst(3)
            end
            curM, curS, curBotM, curBotS = resolveRoleSnapshot(0.6)
            if curM or curBotM then
                tpHomeBurst(2)
            end

            local ownerIsMurdRound = owner and curM and owner.UserId == curM.UserId
            -- Bot sheriff + owner murderer: stash after role msgs so owner sees them first
            local deferGunStash = not curBotM and ownerIsMurdRound and (curBotS or botHasGun())

            -- Drop gun at spawn only when owner is murderer (not just because bot is sheriff)
            if isAlive(me) and not curBotM and ownerIsMurdRound
                and (botHasGun() or findDroppedGun()) and not deferGunStash
            then
                pcall(stashGunAtSpawn)
                task.wait(0.45)
            end

            -- Role callouts / public msgs (after spawn safety TPs)
            if toggleWho or not session.ownerId then
                local mLabel = curBotM and "Me" or (curM and shortName(curM)) or "?"
                local sLabel = curBotS and "Me" or (curS and shortName(curS)) or "?"
                if session.ownerId then
                    whisper("Murderer: " .. mLabel)
                    task.wait(0.3)
                    whisper("Sheriff: " .. sLabel)
                else
                    sendChat("Murderer: " .. mLabel)
                    task.wait(0.6)
                    sendChat("Sheriff: " .. sLabel)
                    task.wait(0.6)
                    sendChat("Type !owner to use private bot commands")
                end
            end

            if deferGunStash and isAlive(me) and (botHasGun() or findDroppedGun()) then
                task.wait(1)
                ownerMurdStashBusy = true
                pcall(stashGunAtSpawn)
                task.wait(0.45)
                ownerMurdStashBusy = false
            end

            -- Post-msg movement
            task.wait(0.5)
            if curBotM then
                if owner and curS and owner.UserId == curS.UserId then
                    for i = 1, 3 do tpTo(owner); task.wait(0.6) end
                end
            elseif session.ownerId then
                for i = 1, 3 do tpHome(); task.wait(0.5) end
            end

            roleAnnounceUnlockAt = tick() + 0.35
            whoAnnouncePending = false
        end)
    elseif not roundActive then
        announced, gunDelivered, aloneMurderWinDone, whoAnnouncePending = false, false, false, false
        ownerMurdStashBusy = false
        roleAnnounceUnlockAt = 0
    end

    local ownerMurd = ownerIsMurderer()
    if ownerMurd then
        toggleGun = false
        toggleShoot = false
        gunTargetId = nil
        gunDelivered = false
    end

    -- Owner is murderer: stash bot's gun at spawn (never during shoot/stab/gun delivery)
    if session.ownerId and ownerMurd and SPAWN_CFRAME and isAlive(me)
        and not whoAnnouncePending and tick() >= roleAnnounceUnlockAt
        and botHasGun() and not ownerMurdStashBusy
        and not _G.MM_ShootBusy and not _G.MM_StabBusy and not _G.MM_GunBusy
    then
        ownerMurdStashBusy = true
        task.spawn(function()
            pcall(stashGunAtSpawn)
            task.wait(2.5)
            ownerMurdStashBusy = false
        end)
    end

    local ownerIsMurd = ownerMurd

    if not session.ownerId and roundActive and m and not aloneMurderWinDone
        and isOnlyMurdererLeftWithBot(m)
    then
        aloneMurderWinDone = true
        log("no owner: bot + murderer only -> reset for murderer win")
        task.spawn(function() pcall(reset) end)
    end

    local gunTarget = (gunTargetId and Players:GetPlayerByUserId(gunTargetId)) or getOwnerPlayer()
    if toggleGun and not ownerMurd and not flingLoopContinuous and not botM and not gunDelivered and not _G.MM_GunBusy
       and not _G.MM_ShootBusy and not _G.MM_StabBusy and me.Character
       and not whoAnnouncePending and tick() >= roleAnnounceUnlockAt
       and gunTarget and gunTarget ~= me and isAlive(gunTarget)
       and (botHasGun() or findDroppedGun()) then
        gunDelivered = true
        _G.MM_GunBusy = true
        task.spawn(function() bringGun(gunTarget); task.wait(3); _G.MM_GunBusy = false end)
    end

    if toggleShoot and not ownerMurd and session.ownerId and not flingActive and not flingLoopActive and not flingLoopContinuous
        and not _G.MM_ShootBusy and not _G.MM_GunBusy and (tick() - lastToggleShootTry) >= 2.25
        and not whoAnnouncePending and tick() >= roleAnnounceUnlockAt
        and not botM and m and m ~= me and isAlive(m) and isAlive(me)
    then
        lastToggleShootTry = tick()
        _G.MM_ShootBusy = true
        task.spawn(function()
            pcall(function()
                local murd = findHolder({"Knife"})
                if toggleShoot and not ownerIsMurderer() and session.ownerId and murd and murd ~= me and isAlive(murd) and isAlive(me)
                    and not botHasKnife()
                then
                    local _, status = shootTargetLoop(murd)
                    log("toggleshoot " .. tostring(status))
                end
            end)
            _G.MM_ShootBusy = false
            runDeferredOwnerResetIfIdle()
        end)
    end

    local subject = (s and s.Character and s.Character:FindFirstChildOfClass("Humanoid"))
                  or findDroppedGun()
                  or (me.Character and me.Character:FindFirstChildOfClass("Humanoid"))
    local loopCam = getActiveCam()
    if loopCam then
        pcall(function()
            if loopCam.CameraType ~= Enum.CameraType.Custom then loopCam.CameraType = Enum.CameraType.Custom end
            if subject then loopCam.CameraSubject = subject end
            loopCam.FieldOfView = WIDE_FOV
        end)
    end
    task.wait(0.5)
end

--[[ Cleanup ]]--
do
    local c = getActiveCam()
    if c then
        pcall(function() c.FieldOfView = DEFAULT_FOV end)
        local h = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() c.CameraSubject = h end) end
    end
end
