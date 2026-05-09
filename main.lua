--[[ MM2 Helper Bot ]]--
local Players = game:GetService("Players")
local cref = cloneref or function(x) return x end
local TCS = cref(game:GetService("TextChatService"))
local Tween = game:GetService("TweenService")
local RS = cref(game:GetService("ReplicatedStorage"))
local isLegacy = TCS.ChatVersion == Enum.ChatVersion.LegacyChatService
local me, cam = Players.LocalPlayer, workspace.CurrentCamera
local DEFAULT_FOV, WIDE_FOV = 70, 100
local SPAWN_CFRAME = nil
local FRAUD_NAME = "test"
local toggleRole = true
local toggleGun = false
local fraudOptedOut = false

--[[ Session ]]--
if getgenv and getgenv().MM_Session then getgenv().MM_Session.active = false end
if game.CoreGui:FindFirstChild("MM") then game.CoreGui.MM:Destroy() end
local session = {active = true, ownerId = nil}
if getgenv then getgenv().MM_Session = session end
cam.FieldOfView = DEFAULT_FOV
do local h = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
   if h then cam.CameraSubject = h end end

--[[ GUI ]]--
local gui = Instance.new("ScreenGui", game.CoreGui)
gui.Name, gui.ResetOnSpawn = "MM", false
local f = Instance.new("Frame", gui)
f.Size, f.Position = UDim2.new(0, 140, 0, 180), UDim2.new(0, 10, 0, 10)
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
    for _, ch in ipairs(TCS.TextChannels:GetChildren()) do
        if ch.Name:match("RBXWhisper") then
            if tostring(ch.Name):find(tostring(uid)) then
                return ch
            end
        end
    end
end
local function whisper(m, target)
    local o = target or findOwner()
    if not o then log("whisper: no target") return end
    log("-> " .. o.DisplayName .. ": " .. m)
    pcall(function()
        if not isLegacy then
            local ch = findWhisperChannel(o.UserId)
            if ch then
                ch:SendAsync(m)
            else
                TCS.TextChannels.RBXGeneral:SendAsync("/w " .. o.DisplayName .. " " .. m)
            end
        else
            RS.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(
                "/w " .. o.DisplayName .. " " .. m,
                "All"
            )
        end
    end)
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
local function tpTo(p)
    local h, t = hrp(), p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if h and t then h.CFrame = t.CFrame + Vector3.new(0, 0, 3) end
end
local function tpHome()
    local h = hrp()
    if h and SPAWN_CFRAME then h.CFrame = SPAWN_CFRAME end
end
local function reset()
    local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0 end
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

--[[ Fling ]]--
local flingActive = false
local function fling(target)
    if flingActive then return end
    if not isAlive(target) or not isAlive(me) then return end
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
        flingActive = false
        log(flung and "fling success" or "fling done")
        if flung then
            task.wait(0.2)
            tpHome()
        end
    end)
end

--[[ Commands ]]--
local HELP = "!owner !dethrone !gun [name] !fling <name> !who !chat <msg> !tp [name] !tpmurd !tpsher !togglerole !togglegun !home !reset !help"
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
    if cmd == "fling" then
        log("fling cmd: query=" .. tostring(args[2]) .. " active=" .. tostring(flingActive))
        if flingActive then log("fling already active") return end
        local t = findPlayer(args[2])
        log("fling target: " .. (t and t.DisplayName or "nil"))
        if t then fling(t) else log("no fling target found") end
        return
    end
    if flingActive then flingActive = false end
    local m, s = findHolder({"Knife"}), findHolder({"Gun", "Revolver"})
    if cmd == "dethrone" then
        if p.Name:lower() == FRAUD_NAME then fraudOptedOut = true end
        session.ownerId = nil
        toggleRole, toggleGun = true, false
        sendChat('owner released — type "!owner" to claim')
        return
    elseif cmd == "chat" then sendChat(rest)
    elseif cmd == "who" then
        local botM, botS = botHasKnife(), botHasGun()
        local mL = botM and "Me" or (m and shortName(m)) or "?"
        local sL = botS and "Me" or (s and shortName(s)) or "?"
        whisper("Murder: " .. mL)
        task.wait(0.3)
        whisper("Sheriff: " .. sL)
    elseif cmd == "tp" then tpTo(findPlayer(args[2]) or findOwner())
    elseif cmd == "tpmurd" and m then tpTo(m)
    elseif cmd == "tpsher" and s then tpTo(s)
    elseif cmd == "gun" then bringGun(findPlayer(args[2]) or findOwner())
    elseif cmd == "home" then tpHome()
    elseif cmd == "reset" then reset()
    elseif cmd == "togglerole" then toggleRole = not toggleRole; whisper("role announce: " .. (toggleRole and "ON" or "OFF"))
    elseif cmd == "togglegun" then toggleGun = not toggleGun; whisper("auto gun: " .. (toggleGun and "ON" or "OFF"))
    elseif cmd == "help" then whisper(HELP) end
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
    p.Chatted:Connect(function(msg) handleCommand(p, msg) end)
    tryAutoClaimFraud(p)
end
for _, p in ipairs(Players:GetPlayers()) do hookSpeaker(p) end
Players.PlayerAdded:Connect(hookSpeaker)
Players.PlayerRemoving:Connect(function(p)
    if session.ownerId and p.UserId == session.ownerId then
        session.ownerId = nil
        toggleRole, toggleGun = true, false
        sendChat('owner left — type "!owner" to claim')
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
                    log("burn step (" .. session.ownerId .. " vs " .. targetId .. ")")
                    if session.ownerId ~= targetId then log("burn skip: owner changed") return end
                    whisper("Loading new owner...", target)
                end)
                task.spawn(function()
                    task.wait(5)
                    log("HELP step (" .. tostring(session.ownerId) .. " vs " .. targetId .. ")")
                    if session.ownerId ~= targetId then log("HELP skip: owner changed") return end
                    whisper(HELP, target)
                end)
            end
        elseif not session.ownerId then
            lastOwner = nil
        end
        task.wait(0.5)
    end
end)

local function saveSpawnIfSafe()
    if findHolder({"Knife"}) or botHasKnife() or findHolder({"Gun", "Revolver"}) or botHasGun() then return end
    local h = hrp()
    if h then SPAWN_CFRAME = h.CFrame end
end
task.spawn(function()
    if not me.Character then me.CharacterAdded:Wait() end
    me.Character:WaitForChild("HumanoidRootPart", 5)
    task.wait(1); saveSpawnIfSafe()
end)
me.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart", 5)
    task.wait(1); saveSpawnIfSafe()
end)

log("bot online")

--[[ Main loop ]]--
local lastMurderId, announced, gunDelivered, aloneTpDone
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
        local owner = findOwner()
        local sN = findHolder({"Gun", "Revolver"})
        if botM then
            if owner and sN and owner.UserId == sN.UserId then tpTo(owner) end
        else
            if m and owner and owner.UserId == m.UserId then
                tpTo(owner)
            else
                tpHome()
            end
        end
        task.spawn(function()
            task.wait(1)
            if toggleRole then
                local mLabel = botM and "Me" or (m and shortName(m)) or "?"
                local sLabel = botS and "Me" or (sN and shortName(sN)) or "?"
                if session.ownerId then
                    whisper("Murder: " .. mLabel)
                    task.wait(0.3)
                    whisper("Sheriff: " .. sLabel)
                else
                    sendChat("Murder: " .. mLabel)
                    task.wait(0.6)
                    sendChat("Sheriff: " .. sLabel)
                    task.wait(0.6)
                    sendChat('Type "!owner" for private commands')
                end
            end
        end)
    elseif not roundActive then announced, gunDelivered, aloneTpDone = false, false, false end

    if not session.ownerId and m and not aloneTpDone and isAlive(me) and isAlive(m) then
        local alive = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= me and isAlive(p) then alive = alive + 1 end
        end
        if alive == 1 then aloneTpDone = true; tpTo(m) end
    end

    if toggleGun and not gunDelivered and not _G.MM_GunBusy and me.Character
       and session.ownerId and isAlive(findOwner())
       and (botHasGun() or findDroppedGun()) then
        gunDelivered = true
        _G.MM_GunBusy = true
        task.spawn(function() bringGun(); task.wait(3); _G.MM_GunBusy = false end)
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
