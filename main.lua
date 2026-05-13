--[[ MM2 Helper Bot ]]--
local Players = game:GetService("Players")
local cref = cloneref or function(x) return x end
local TCS = cref(game:GetService("TextChatService"))
local Tween = game:GetService("TweenService")
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
local FRAUD_NAME = "2"
local toggleGun = false
local toggleAlerts = false
local toggleWho = true
local fraudOptedOut = false
local gunTargetId = nil
local gunDelivered = false
local hopBusy = false
local coinFarmActive = false
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
local function tpTo(p)
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
local function dropGunAt(target)
    if not isAlive(target) then return false end
    local h = hrp()
    local oh = target.Character:FindFirstChild("HumanoidRootPart")
    if not (h and oh) then return false end
    h.CFrame = oh.CFrame
    task.wait(0.1); reset()
    return true
end
local function bringGun(target)
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
    local g, h = findDroppedGun(), hrp()
    if not (g and h and isAlive(me)) then return false end
    g.CFrame = h.CFrame
    local t0 = tick()
    while session.active and tick() - t0 < 2.5 do
        if botHasGun() then return true end
        task.wait(0.05)
    end
    return false
end
local function equipTool(tool)
    local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if tool and hum and tool.Parent ~= me.Character then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.15)
    end
    return tool and tool.Parent == me.Character
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
local function shootTarget(target)
    if target == me then return false, "Invalid target." end
    if not isAlive(target) or not isAlive(me) then return false, "Player not found." end
    if not botHasGun() and not pickUpDroppedGun() then return false, "No gun available." end
    local gun = getHeldTool(me, {"Gun", "Revolver"})
    if not gun then return false, "No gun available." end
    if not equipTool(gun) then return false, "No gun available." end
    followTarget = nil
    local startHealth = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    startHealth = startHealth and startHealth.Health or nil
    local fired = false
    for _ = 1, 10 do
        if not isAlive(target) or not isAlive(me) then break end
        local mh = hrp()
        local th = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if not (mh and th) then break end
        local aimPoint = th.Position + Vector3.new(0, 1.2, 0)
        zeroVel(mh)
        mh.CFrame = CFrame.new(th.Position + Vector3.new(0, 1.5, 8), aimPoint)
        zeroVel(mh)
        local mouseX, mouseY = 0, 0
        pcall(function()
            cam.CFrame = CFrame.new(mh.Position + Vector3.new(0, 1.5, 0), aimPoint)
            local sp = cam:WorldToViewportPoint(aimPoint)
            if sp.Z > 0 then
                mouseX, mouseY = sp.X, sp.Y
            else
                local vs = cam.ViewportSize
                mouseX, mouseY = vs.X * 0.5, vs.Y * 0.45
            end
        end)
        pcall(function() gun:Activate() end)
        clickFire(mouseX, mouseY)
        task.wait(0.15)
        pcall(function() gun:Activate() end)
        clickFire(mouseX, mouseY)
        fired = true
        local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
        if hum and startHealth and hum.Health < startHealth then
            return true, "Shot " .. shortName(target) .. "."
        end
        if not isAlive(target) then
            return true, "Shot " .. shortName(target) .. "."
        end
        task.wait(0.2)
    end
    return fired, (fired and ("Tried to shoot " .. shortName(target) .. ".") or "No gun available.")
end
local function magnetCoinsToBot()
    if session.ownerId then return 0 end
    local h = hrp()
    if not h then return 0 end
    local moved = 0
    local cf = h.CFrame
    for _, v in ipairs(workspace:GetDescendants()) do
        if (v:IsA("BasePart") or v:IsA("MeshPart")) then
            local n = v.Name
            if n == "Coin" or n == "Coins" or n == "Coin_Server" or n == "CoinDrop"
                or (n:sub(1, 4) == "Coin" and #n <= 24) then
                pcall(function()
                    v.CFrame = cf
                    moved = moved + 1
                end)
            end
        end
    end
    return moved
end
local function stopCoinFarm(tpBack)
    local wasActive = coinFarmActive
    coinFarmActive = false
    if wasActive and tpBack then
        tpHome()
    end
end

--[[ Fling ]]--
local flingActive = false
local flingLoopGen = 0
local flingLoopActive = false

local function cancelFlingWork()
    flingLoopGen = flingLoopGen + 1
    flingLoopActive = false
    flingActive = false
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
                mh.CFrame = th.CFrame
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
                    break
                end
            end
            task.wait()
        end
        log(flung and "fling success" or "fling done")
        if onDoneFn then
            onDoneFn(flung)
        else
            whisper("Flung " .. shortName(target) .. ".")
        end
        flingActive = false
        for i = 1, 3 do
            tpHome()
            task.wait(0.3)
        end
    end)
end

local function waitFlingDone(gen, timeout)
    local t0 = tick()
    while flingActive and tick() - t0 < (timeout or 25) do
        if gen ~= flingLoopGen then break end
        task.wait(0.03)
    end
end

local FLING_LOOP_MAX_SEC = 300

local function flingLoopTimedOut(loopBegan)
    return tick() - loopBegan >= FLING_LOOP_MAX_SEC
end

--- After a successful loop fling, wait until the victim dies/respawns (or caps) before the next fling.
local function waitAfterLoopFling(target, gen, loopBegan, hadSuccess)
    if not target or not target.Parent then return end
    if flingLoopTimedOut(loopBegan) then return end
    if not hadSuccess then
        local t0 = tick()
        while tick() - t0 < 0.75 and gen == flingLoopGen and flingLoopActive and not flingLoopTimedOut(loopBegan) do
            task.wait(0.05)
        end
        return
    end
    task.wait(0.4)
    local phase0 = tick()
    while gen == flingLoopGen and flingLoopActive and session.active and not flingLoopTimedOut(loopBegan) do
        if not target.Parent then return end
        if not isAlive(target) then break end
        if tick() - phase0 > 50 then break end
        task.wait(0.1)
    end
    while gen == flingLoopGen and flingLoopActive and session.active and not flingLoopTimedOut(loopBegan) do
        if not target.Parent then return end
        if isAlive(target) and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then break end
        if tick() - phase0 > 95 then break end
        task.wait(0.1)
    end
    task.wait(0.25)
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
                            whisper("Flung " .. shortName(tgt) .. ".")
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
                            whisper("Flung " .. shortName(tgt) .. ".")
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
                whisper("Fling loop stopped (5 minute limit).")
                cancelFlingWork()
                return
            end
            local targets = collectTargets()
            if #targets == 0 then
                task.wait(0.75)
            else
                for _, tgt in ipairs(targets) do
                    if gen ~= flingLoopGen or not flingLoopActive or flingLoopTimedOut(loopBegan) then break end
                    if mode == "player" and not loopTargetUserId and tgt.UserId then
                        loopTargetUserId = tgt.UserId
                    end
                    if isAlive(tgt) and isAlive(me) then
                        local lastOk = false
                        fling(tgt, function(ok)
                            lastOk = ok
                        end)
                        waitFlingDone(gen, 25)
                        if gen ~= flingLoopGen or not flingLoopActive then break end
                        waitAfterLoopFling(tgt, gen, loopBegan, lastOk)
                    end
                end
            end
        end
    end)
end

--[[ Follow ]]--
local followTarget = nil
local function startFollowLoop()
    task.spawn(function()
        while followTarget and session.active do
            local target = followTarget
            if target and isAlive(target) and isAlive(me) then
                local thrp = target.Character:FindFirstChild("HumanoidRootPart")
                local hum = me.Character:FindFirstChildOfClass("Humanoid")
                if thrp and hum then hum:MoveTo(thrp.Position) end
            end
            task.wait(0.3)
        end
    end)
end

--[[ Commands ]]--
local COMMAND_HELP = {
    owner = "Claim control of the bot",
    dethrone = "Release owner control",
    who = "Show current murderer and sheriff",
    shoot = "<player> - Pick up gun if needed and try to shoot a player",
    togglewho = "Toggle automatic role callout each round",
    togglealerts = "Toggle kill/drop/pickup alerts",
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
    "owner", "dethrone", "tp", "who", "shoot", "gun", "fling", "togglegun", "togglewho", "togglealerts",
    "reset", "follow", "unfollow", "chat", "help",
}
local function sendFullHelp(target)
    whisper('Use !help <command> for one command, e.g. !help gun', target)
    local parts = {}
    for _, key in ipairs(HELP_ORDER) do
        table.insert(parts, "!" .. key)
    end
    whisper(table.concat(parts, " "), target)
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
            stopCoinFarm(true)
        end
        return
    end
    if not session.ownerId or p.UserId ~= session.ownerId then return end
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
            if flingLoopActive or flingActive then
                cancelFlingWork()
                whisper("Fling loop stopped.")
                return
            end
            whisper("!fling all | sheriff | murder | <name> — add loop to repeat. !fling alone stops (5 min max).")
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
            whisper("Use !fling all only. Looping the whole server is disabled.")
            return
        end

        flingActive = false
        flingLoopGen = flingLoopGen + 1
        local gen = flingLoopGen
        flingLoopActive = true

        local loopArg = continuousLoop and mode ~= "all"
        runFlingLoop(mode, playerQuery, gen, loopArg)
        if mode == "all" then
            whisper("Flinging everyone (one pass).")
        elseif loopArg then
            local label = mode == "player" and work or mode
            whisper("Say !fling alone to stop the loop.")
            task.wait(0.3)
            whisper("Looping on: " .. label)
        else
            whisper("Flinging " .. (mode == "player" and work or mode) .. ".")
        end
        return
    end
    local m, s = findHolder({"Knife"}), findHolder({"Gun", "Revolver"})
    local ownerIsMurd = session.ownerId and m and not botHasKnife() and m.UserId == session.ownerId
    if cmd == "dethrone" then
        if p.Name:lower() == FRAUD_NAME then fraudOptedOut = true end
        session.ownerId = nil
        toggleGun, toggleAlerts, toggleWho = false, false, true
        gunTargetId, gunDelivered = nil, false
        sendChat('Owner released. Type !owner to claim.')
        return
    elseif cmd == "chat" then
        sendChat(rest)
        whisper("Chat sent.")
    elseif cmd == "who" then
        local botM, botS = botHasKnife(), botHasGun()
        local mL = botM and "Me" or (m and shortName(m)) or "?"
        local sL = botS and "Me" or (s and shortName(s)) or "?"
        whisper("Murderer: " .. mL)
        task.wait(0.3)
        whisper("Sheriff: " .. sL)
    elseif cmd == "tp" then
        local t = findPlayer(args[2]) or findOwner()
        if not t then whisper("Player not found.") return end
        tpTo(t)
        whisper("Teleported to " .. shortName(t) .. ".")
    elseif cmd == "tpmurd" then
        if not m then whisper("Murderer not found.") return end
        tpTo(m)
        whisper("Teleported to murderer.")
    elseif cmd == "tpsher" then
        if not s then whisper("Sheriff not found.") return end
        tpTo(s)
        whisper("Teleported to sheriff.")
    elseif cmd == "shoot" then
        local q = restOfChatArgs(args)
        if q == "" then whisper("!shoot <player>") return end
        local picked = findOtherPlayer(q)
        if not picked then whisper("Player not found.") return end
        local targetUid = picked.UserId
        if ownerIsMurd or botHasKnife() then whisper("No gun available.") return end
        if _G.MM_GunBusy then whisper("Gun busy, try again.") return end
        _G.MM_GunBusy = true
        task.spawn(function()
            local tgt = Players:GetPlayerByUserId(targetUid)
            if not tgt or not isAlive(tgt) then
                whisper("Player not found.")
                task.wait(0.2)
                _G.MM_GunBusy = false
                return
            end
            local ok, status = shootTarget(tgt)
            whisper(status)
            task.wait(1)
            _G.MM_GunBusy = false
        end)
    elseif cmd == "gun" then
        local t = findPlayer(args[2]) or findOwner()
        if not t then whisper("Player not found.") return end
        if ownerIsMurd then whisper("No gun available.") return end
        if botHasKnife() then whisper("No gun available.") return end
        if not (botHasGun() or findDroppedGun()) then whisper("No gun available.") return end
        bringGun(t)
        whisper("Gun delivered to " .. shortName(t) .. ".")
    elseif cmd == "spawn" or cmd == "home" then
        tpHome()
        whisper("Teleported to spawn.")
    elseif cmd == "reset" then
        whisper("Resetting...")
        reset()
    elseif cmd == "rejoin" then
        whisper("Rejoining...")
        hopServer("manual rejoin", false)
    elseif cmd == "togglegun" then
        if ownerIsMurd then whisper("No gun available.") return end
        if args[2] then
            local t = findPlayer(args[2])
            if not t then whisper("Player not found.") return end
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
    elseif cmd == "togglewho" then
        toggleWho = not toggleWho
        whisper("Role callouts: " .. (toggleWho and "on" or "off"))
    elseif cmd == "follow" then
        local t = findPlayer(args[2]) or findOwner()
        if not t then whisper("Player not found.") return end
        local wasActive = followTarget ~= nil
        local switching = followTarget ~= t
        followTarget = t
        if switching then tpTo(t) end
        whisper("Following " .. shortName(t) .. ".")
        if not wasActive then startFollowLoop() end
    elseif cmd == "unfollow" then
        if not followTarget then whisper("Not following anyone.") return end
        local name = shortName(followTarget)
        followTarget = nil
        whisper("Unfollowed " .. name .. ".")
    elseif cmd == "help" then
        local helpCmd = args[2] and args[2]:gsub("^!", ""):lower()
        if helpCmd and COMMAND_HELP[helpCmd] then
            whisper("!" .. helpCmd .. ": " .. COMMAND_HELP[helpCmd])
        else
            sendFullHelp()
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
    stopCoinFarm(true)
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
        toggleGun, toggleAlerts, toggleWho = false, false, true
        gunTargetId, gunDelivered = nil, false
        sendChat("Owner left. Type !owner to claim.")
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
                        if owner then whisper(("High ping (%dms), hopping."):format(math.floor(ping + 0.5))) end
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

task.spawn(function()
    while session.active do
        -- Farm only with no owner; do not require "round active" (lobby / pre-round has coins too).
        local shouldFarm = not session.ownerId and isAlive(me) and not flingActive
            and not botHasKnife() and not botHasGun() and not _G.MM_GunBusy and not hopBusy
        if shouldFarm then
            coinFarmActive = true
            magnetCoinsToBot()
        else
            if coinFarmActive then
                coinFarmActive = false
            end
        end
        task.wait(0.4)
    end
end)

task.spawn(function()
    local lastOwner = nil
    while session.active do
        if session.ownerId and session.ownerId ~= lastOwner then
            lastOwner = session.ownerId
            local owner = Players:GetPlayerByUserId(session.ownerId)
            log("new owner: " .. (owner and owner.DisplayName or "nil"))
            if owner then
                local target = owner
                local targetId = owner.UserId
                task.spawn(function()
                    task.wait(2)
                    if session.ownerId ~= targetId then return end
                    whisper("You are the bot owner.", target)
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
                    log("owner died -> resetting bot")
                    task.spawn(function() pcall(reset) end)
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
                            whisper("Sheriff eliminated the murderer.")
                            suppressDrop = true
                        elseif p.UserId == gunIdPrev then
                            whisper("Murderer eliminated the sheriff.")
                        elseif knifeIdPrev then
                            whisper("Murderer killed " .. shortName(p) .. ".")
                        elseif gunIdPrev then
                            whisper("Sheriff shot " .. shortName(p) .. ".")
                        end
                    end
                end
            end
            if gunIdPrev and not gid and not suppressDrop then
                local prev = Players:GetPlayerByUserId(gunIdPrev)
                if prev and aliveState(prev) == true then
                    whisper("Sheriff dropped the gun.")
                end
            end
            if not gunIdPrev and gid and droppedGunPrev and gHolder then
                whisper(shortName(gHolder) .. " picked up the gun.")
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
local lastMurderId, announced, aloneTpDone
local whoAnnouncePending = false
local ownerMurdSheriffDropDone = false
local roleAnnounceUnlockAt = 0
while session.active and gui.Parent do
    local m, s = findHolder({"Knife"}), findHolder({"Gun", "Revolver"})
    local botM, botS = botHasKnife(), botHasGun()
    local roundActive = m or botM or s or botS

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
        whoAnnouncePending = toggleWho or not session.ownerId
        local owner = findOwner()
        local sN = findHolder({"Gun", "Revolver"})
        task.spawn(function()
            task.wait(1.5)
            local _, curS, curBotM = resolveRoleSnapshot(1.2)
            if botM then
                if owner and not curBotM and curS and owner.UserId == curS.UserId then
                    for i = 1, 3 do tpTo(owner); task.wait(0.6) end
                end
            else
                for i = 1, 3 do tpHome(); task.wait(0.6) end
            end
        end)
        task.spawn(function()
            task.wait(2.5)
            if toggleWho or not session.ownerId then
                local curM, curS, curBotM, curBotS = resolveRoleSnapshot(1.4)
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
                    sendChat("Type !owner to use private bot commands.")
                end
            end
            roleAnnounceUnlockAt = tick() + 1.25
            whoAnnouncePending = false
            task.wait(1)
            local curOwner = findOwner()
            local _, curSN, curBotM = resolveRoleSnapshot(0.8)
            local goingToOwner = curBotM and curOwner and curSN and curOwner.UserId == curSN.UserId
            if not goingToOwner then
                for i = 1, 3 do tpHome(); task.wait(0.5) end
            end
        end)
    elseif not roundActive then
        announced, gunDelivered, aloneTpDone, whoAnnouncePending = false, false, false, false
        ownerMurdSheriffDropDone = false
        roleAnnounceUnlockAt = 0
    end

    local ownerForDrop = findOwner()
    local ownerIsMurd = ownerForDrop and m and not botM and ownerForDrop.UserId == m.UserId
    if session.ownerId and ownerIsMurd and SPAWN_CFRAME and not ownerMurdSheriffDropDone
       and not whoAnnouncePending and tick() >= roleAnnounceUnlockAt
       and isAlive(me) and not _G.MM_GunBusy and (botHasGun() or findDroppedGun()) then
        _G.MM_GunBusy = true
        task.spawn(function()
            if stashGunAtSpawn() then
                ownerMurdSheriffDropDone = true
                gunDelivered = true
            end
            task.wait(2.5)
            _G.MM_GunBusy = false
        end)
    end

    if not session.ownerId and m and not aloneTpDone and isAlive(me) and isAlive(m) then
        local alive = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= me and isAlive(p) then alive = alive + 1 end
        end
        if alive == 1 then aloneTpDone = true; tpTo(m) end
    end

    local gunTarget = (gunTargetId and Players:GetPlayerByUserId(gunTargetId)) or findOwner()
    if toggleGun and not botM and not ownerIsMurd and not gunDelivered and not _G.MM_GunBusy and me.Character
       and not whoAnnouncePending and tick() >= roleAnnounceUnlockAt
       and gunTarget and gunTarget ~= me and isAlive(gunTarget)
       and (botHasGun() or findDroppedGun()) then
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
