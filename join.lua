--[[
  test.lua — join a Roblox experience via share invite link (ExperienceInvite)

  Paste your full share URL or just the code at the top, then run in your executor.

  Example:
  https://www.roblox.com/share?code=_3hn82fow6t6x8t1pcn4axg93vf092qxge5gadm07401lbtf9my&type=ExperienceInvite

  Flow:
  1. Parse `code` from the URL
  2. POST https://apis.roblox.com/sharelinks/v1/resolve-link (same as the website Join button)
  3. Teleport with placeId + instanceId (JobId) when the API returns them
]]

-- ============ CONFIG ============
local INVITE_URL = "https://www.roblox.com/share?code=_3hn82fow6t6x8t1pcn4axg93vg61ncxiqw2heiljgop13kmp07&type=ExperienceInvite"
-- Or set CODE directly and leave INVITE_URL empty:
local INVITE_CODE = ""
-- =================================

local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local TeleportSvc = game:GetService("TeleportService")
local me = Players.LocalPlayer

local RESOLVE_URL = "https://apis.roblox.com/sharelinks/v1/resolve-link"

local function log(msg)
    print("[invite-test] " .. tostring(msg))
end

local function httpRequest(opts)
    local requestFn = (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
        or (fluxus and fluxus.request)
    if requestFn then
        local ok, res = pcall(function()
            return requestFn(opts)
        end)
        if ok and res then
            local body = res.Body or res.body or res
            if type(body) == "table" and body.Body then
                body = body.Body
            end
            return true, body, res.StatusCode or res.status or res.Status
        end
        return false, res
    end
    if (opts.Method or "GET") == "GET" and opts.Url then
        local ok, body = pcall(function()
            return game:HttpGet(opts.Url)
        end)
        return ok, body, ok and 200 or nil
    end
    return false, "no http client (syn.request / http.request / game:HttpGet)"
end

local function parseInviteCode(urlOrCode)
    local s = (urlOrCode or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then
        return nil
    end
    if not s:find("roblox.com", 1, true) and not s:find("?", 1, true) then
        return s
    end
    local code = s:match("[?&]code=([^&]+)")
    if code then
        code = code:gsub("%%(%x%x)", function(h)
            return string.char(tonumber(h, 16))
        end)
        return code
    end
    return nil
end

local function decodeJson(raw)
    if type(raw) ~= "string" or raw == "" then
        return nil, "empty body"
    end
    local ok, data = pcall(function()
        return Http:JSONDecode(raw)
    end)
    if not ok then
        return nil, data
    end
    return data
end

local function firstTable(...)
    for i = 1, select("#", ...) do
        local t = select(i, ...)
        if type(t) == "table" then
            return t
        end
    end
    return nil
end

local function pickJoinFields(data)
    if type(data) ~= "table" then
        return nil
    end
    local block = firstTable(
        data.notificationExperienceInviteData,
        data.experienceInviteData,
        data.experienceDetailsInviteData,
        data.privateServerInviteData
    )
    if not block then
        return nil
    end
    local placeId = tonumber(block.placeId or block.place_id or data.placeId)
    local instanceId = block.instanceId or block.gameInstanceId or block.jobId or block.serverId
    if instanceId ~= nil then
        instanceId = tostring(instanceId)
        if instanceId == "" or instanceId:lower() == "null" then
            instanceId = nil
        end
    end
    local universeId = tonumber(block.universeId or block.universe_id or data.universeId)
    local launchData = block.launchData or block.launch_data
    local accessCode = block.accessCode or block.access_code or block.linkCode or block.link_code
    return {
        placeId = placeId,
        instanceId = instanceId,
        universeId = universeId,
        launchData = launchData,
        accessCode = accessCode and tostring(accessCode) or nil,
        rawBlock = block,
    }
end

local function resolveInviteLink(linkId)
    local bodies = {
        Http:JSONEncode({ linkId = linkId }),
        Http:JSONEncode({ linkId = linkId, linkType = "ExperienceInvite" }),
        Http:JSONEncode({ linkId = linkId, linkType = 1 }),
    }
    for i, body in ipairs(bodies) do
        log("resolve attempt " .. i .. " …")
        local ok, raw, status = httpRequest({
            Url = RESOLVE_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Accept"] = "application/json",
            },
            Body = body,
        })
        if not ok then
            log("resolve HTTP failed: " .. tostring(raw))
        else
            log("resolve status: " .. tostring(status))
            local data, err = decodeJson(raw)
            if not data then
                log("resolve JSON error: " .. tostring(err))
                log("body preview: " .. tostring(raw):sub(1, 400))
            else
                local fields = pickJoinFields(data)
                if fields and fields.placeId then
                    return fields, data
                end
                log("resolve ok but no placeId in known fields — dumping keys")
                for k in pairs(data) do
                    log("  key: " .. tostring(k))
                end
            end
        end
    end
    return nil, nil
end

local function tryTeleportToInstance(placeId, instanceId)
    log(("TeleportToPlaceInstance place=%s instance=%s"):format(tostring(placeId), tostring(instanceId)))
    local ok, err = pcall(function()
        TeleportSvc:TeleportToPlaceInstance(placeId, instanceId, me)
    end)
    return ok, err
end

local function tryTeleportAsync(placeId, instanceId, launchData)
    local okOpt, teleportOptions = pcall(function()
        return Instance.new("TeleportOptions")
    end)
    if not okOpt or not teleportOptions then
        return false, "TeleportOptions unavailable"
    end
    if instanceId and instanceId ~= "" then
        pcall(function()
            teleportOptions.ServerInstanceId = instanceId
        end)
    end
    if launchData and launchData ~= "" then
        pcall(function()
            teleportOptions.LaunchData = tostring(launchData):sub(1, 200)
        end)
    end
    log(("TeleportAsync place=%s instance=%s"):format(tostring(placeId), tostring(instanceId or "any")))
    local ok, err = pcall(function()
        TeleportSvc:TeleportAsync(placeId, { me }, teleportOptions)
    end)
    return ok, err
end

local function tryPrivateServer(placeId, accessCode)
    if not accessCode or accessCode == "" then
        return false, "no access code"
    end
    log(("TeleportToPrivateServer place=%s"):format(tostring(placeId)))
    local ok, err = pcall(function()
        TeleportSvc:TeleportToPrivateServer(placeId, accessCode, { me })
    end)
    return ok, err
end

local function tryOpenShareUrl(url)
    local okLs, linking = pcall(function()
        return game:GetService("LinkingService")
    end)
    if not okLs or not linking then
        return false, "LinkingService missing"
    end
    log("LinkingService:OpenUrl …")
    local ok, err = pcall(function()
        linking:OpenUrl(url)
    end)
    return ok, err
end

-- ============ RUN ============
local code = (INVITE_CODE ~= "" and INVITE_CODE) or parseInviteCode(INVITE_URL)
if not code or code == "" then
    log("No invite code — set INVITE_URL or INVITE_CODE at the top of test.lua")
    return
end

local shareUrl = INVITE_URL
if shareUrl == "" or not shareUrl:find("code=", 1, true) then
    shareUrl = "https://www.roblox.com/share?code=" .. code .. "&type=ExperienceInvite"
end

log("code: " .. code:sub(1, 12) .. "…")
log("url: " .. shareUrl)

local fields, rawResolve = resolveInviteLink(code)
if not fields or not fields.placeId then
    log("Could not resolve invite — try LinkingService fallback only")
    local okUrl, errUrl = tryOpenShareUrl(shareUrl)
    log("OpenUrl: " .. (okUrl and "called" or tostring(errUrl)))
    return
end

log("placeId: " .. tostring(fields.placeId))
log("instanceId: " .. tostring(fields.instanceId or "(none — joins any server)"))
log("universeId: " .. tostring(fields.universeId or "—"))
if fields.launchData then
    log("launchData: " .. tostring(fields.launchData):sub(1, 120))
end

local placeId = fields.placeId
local instanceId = fields.instanceId
local launched = false

if fields.accessCode then
    local ok, err = tryPrivateServer(placeId, fields.accessCode)
    log("private server: " .. (ok and "started" or tostring(err)))
    launched = ok or launched
end

if instanceId then
    local ok, err = tryTeleportAsync(placeId, instanceId, fields.launchData)
    log("TeleportAsync: " .. (ok and "started" or tostring(err)))
    if not ok then
        ok, err = tryTeleportToInstance(placeId, instanceId)
        log("TeleportToPlaceInstance: " .. (ok and "started" or tostring(err)))
    end
    launched = ok or launched
else
    log("No instanceId in resolve response — joining place only (not a specific server)")
    local ok, err = tryTeleportAsync(placeId, nil, fields.launchData)
    log("TeleportAsync (any server): " .. (ok and "started" or tostring(err)))
    if not ok then
        ok, err = pcall(function()
            TeleportSvc:Teleport(placeId, me)
        end)
        log("Teleport: " .. (ok and "started" or tostring(err)))
    end
    launched = ok or launched
end

if not launched then
    log("Teleport APIs failed — trying LinkingService:OpenUrl")
    local okUrl, errUrl = tryOpenShareUrl(shareUrl)
    log("OpenUrl: " .. (okUrl and "called" or tostring(errUrl)))
end

log("done (if teleport started, you should leave this server shortly)")
