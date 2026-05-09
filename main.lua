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
local FRAUD_NAME = "fraud4balenci"
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
local LOG_CAP = 14
local logFrame = Instance.new("Frame", gui)
logFrame.Size = UDim2.new(0, 320, 0, 240)
logFrame.Position = UDim2.new(1, -330, 1, -250)
logFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
logFrame.BackgroundTransparency = 0.25
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
    local t = Instance.new("TextLabel", logFrame)
    t.Size = UDim2.new(1, 0, 0, 15)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.Code
    t.TextSize = 13
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextColor3 = Color3.fromRGB(180, 230, 180)
    t.Text = "[" .. os.date("%X") .. "] " .. tostring(msg)
    t.LayoutOrder = logCounter
    t.TextTruncate = Enum.TextTruncate.AtEnd
    local labels = {}
    for _, c in ipairs(logFrame:GetChildren()) do
        if c:IsA("TextLabel") then table.insert(labels, c) end
    end
    table.sort(labels, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #labels > LOG_CAP do
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
            end
        else
            RS.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(
                "/w " .. o.DisplayName .. " " .. m,
                "All"
            )
        end
    end)
end
local function openWhisper(p)
    if isLegacy then return end
    pcall(function()
        TCS.TextChannels.RBXGeneral:SendAsync("/w " .. p.DisplayName)
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

--[[ Commands ]]--
local HELP = "!owner !dethrone !chat <msg> !who !tp [name] !tpmurd !tpsher !gun [name] !togglerole !togglegun !home !reset !help"
local function handleCommand(p, msg)
    if msg:sub(1, 1) ~= "!" then return end
    local args = msg:split(" ")
    local cmd, rest = args[1]:sub(2):lower(), msg:sub(#args[1] + 2)
    if cmd == "owner" then
        local isFraud = p.Name:lower() == FRAUD_NAME
        if not session.ownerId or isFraud or session.ownerId == p.UserId then
            session.ownerId = p.UserId
            if isFraud then fraudOptedOut = false end
            openWhisper(p)
        end
        return
    end
    if not session.ownerId or p.UserId ~= session.ownerId then return end
    local m, s = findHolder({"Knife"}), findHolder({"Gun", "Revolver"})
    if cmd == "dethrone" then
        if p.Name:lower() == FRAUD_NAME then fraudOptedOut = true end
        session.ownerId = nil
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
    openWhisper(p)
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
                task.spawn(function()
                    task.wait(4)
                    if session.ownerId ~= owner.UserId then return end
                    local ch = findWhisperChannel(owner.UserId)
                    log(ch and ("channel ready: " .. ch.Name) or "no channel after 4s")
                    whisper("ownership granted", owner)
                    task.wait(2)
                    if session.ownerId ~= owner.UserId then return end
                    whisper(HELP, owner)
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
task.spawn(function()
    task.wait(2)
    if session.ownerId then return end
    sendChat('type "!owner" for private commands')
end)

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
        task.spawn(function()
            task.wait(0.3)
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
            task.wait(0.7)
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
