--[[
    Electron Hub (SCP: Site Roleplay)
    Features:
        - Security: Destroy Desync Patch, AC Detection + Clipboard, Spoof Player Data, Kick Detection & Trace
        - Movement: Walk Speed (ERX method), Noclip, Infinite Jump
        - Premium: God Mode, Infinite Stamina (requires PandaAuth key)
        - Misc: Moderator Detection (auto-scan + manual)
    Uses WindUI + PandaAuth (Wilkins) – key system built in.
    Author: @blackberryfr
]]

-- ========== 0. PATCH: makefolder to prevent errors ==========
local originalMakeFolder = makefolder
if originalMakeFolder then
    makefolder = function(path)
        pcall(originalMakeFolder, path)
    end
else
    makefolder = function() end
end

-- ========== 1. Load WindUI and utilities ==========
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
if not WindUI then
    warn("Failed to load WindUI")
    return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- ========== 2. Prepare the PandaAuth (Wilkins) service ==========
local WilkinsLib = nil

local wsCtor = (WebSocket and WebSocket.connect)
    or (syn and syn.websocket and syn.websocket.connect)
    or (websocket and websocket.connect)

if wsCtor then
    local libCode
    local ws = wsCtor("wss://secure.pandauth.com/ws?type=wilkins-lib")
    ws.OnMessage:Connect(function(msg)
        if msg and #msg > 0 and not libCode then libCode = msg end
    end)
    local deadline = tick() + 15
    repeat task.wait(0.05) until libCode or tick() > deadline
    pcall(function() ws:Close() end)

    if libCode then
        local ok, mod = pcall(function() return loadstring(libCode)() end)
        if ok and mod and type(mod.configure) == "function" then
            WilkinsLib = mod
            WilkinsLib.configure({
                serviceId = "getkeyhub",
                debug = false,
                kickOnDetect = false,
                openDashboard = true,
                validationTimeout = 600,
                onTamper = function(flags)
                    warn("[Wilkins] Tamper: " .. table.concat(flags or {}, ","))
                end,
                onSessionEnd = function(reason, msg)
                    warn("[Wilkins] Session ended: " .. reason, msg or "")
                end,
            })
        end
    end
end

-- Register the custom WindUI service
WindUI.Services.pandaauth = {
    Name = "PandaAuth (Wilkins V4.5)",
    Icon = "shield-check",
    Args = { "ServiceId" },
    New = function(ServiceId)
        local function validateKey(key)
            if not WilkinsLib then
                return false, "WebSocket not supported or library failed to load."
            end
            if not key or key == "" then
                return false, "Key cannot be empty."
            end

            local ok, result = pcall(WilkinsLib.validate, key)
            if not ok then
                pcall(WilkinsLib.clearSavedKey)
                return false, "Validation crashed: " .. tostring(result)
            end

            if not result.success then
                pcall(WilkinsLib.clearSavedKey)
                return false, result.error or "Authentication failed"
            end

            _G.WilkinsIsPremium = result.isPremium or false
            return true, "Authenticated successfully"
        end

        local function copyLink()
            if WilkinsLib and WilkinsLib.copyGetKeyUrl then
                WilkinsLib.copyGetKeyUrl()
            else
                setclipboard("https://secure.pandauth.com/getkey?service=getkeyhub")
            end
        end

        return {
            Verify = validateKey,
            Copy = copyLink,
        }
    end
}

-- ========== 3. Create the main window with the key system ==========
local Window = WindUI:CreateWindow({
    Title = "Electron Hub",
    Icon = "zap",
    Author = "@blackberryfr",
    Size = UDim2.fromOffset(520, 500),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    ToggleKey = Enum.KeyCode.RightAlt,

    KeySystem = {
        Note = "Enter your PandaAuth key to continue.",
        API = {
            {
                Type = "pandaauth",
                ServiceId = "getkeyhub",
            },
        },
    },
})

-- ========== 4. Key accepted – show premium notification ==========
if _G.WilkinsIsPremium then
    WindUI:Notify({
        Title = "👑 Premium Unlocked",
        Content = "God Mode & Infinite Stamina now available.",
        Duration = 8
    })
end

-- ========== 5. Keep the session alive ==========
if WilkinsLib then
    task.spawn(function()
        while WilkinsLib.isConnected and WilkinsLib.isConnected() do
            task.wait(5)
        end
        warn("[Wilkins] Session closed.")
    end)
end

-- ===============================
-- SECURITY TAB
-- ===============================
local SecurityTab = Window:Tab({
    Title = "Security",
    Icon = "shield"
})

-- 1. Destroy Desync Patch
local desyncRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Desync")
if desyncRemote then
    desyncRemote = desyncRemote:FindFirstChild("UnreliableRemoteEvent")
end

if desyncRemote then
    local originalDesyncFunc = nil
    for _, conn in ipairs(getconnections(desyncRemote.OnClientEvent)) do
        if conn and conn.Function then
            originalDesyncFunc = conn.Function
            hookfunction(conn.Function, function(p1, p2)
                if _G.DestroyDesyncPatch then
                    return -- ignore corrections
                end
                return originalDesyncFunc(p1, p2)
            end)
            break
        end
    end
end

SecurityTab:Toggle({
    Title = "Destroy Desync Patch",
    Desc = "Block server desync corrections",
    Value = false,
    Callback = function(state)
        _G.DestroyDesyncPatch = state
    end
})

-- 2. Anticheat Detection & Clipboard
SecurityTab:Button({
    Title = "Detect AC & Copy",
    Desc = "Scan for anticheat and copy 'ere'",
    Callback = function()
        local clipFunc = setclipboard or toclipboard or set
        if clipFunc then
            clipFunc("ere")
            WindUI:Notify({
                Title = "Clipboard",
                Content = "Copied 'ere'",
                Duration = 3
            })
        end

        local detected = false
        local patterns = {"getmemoryUsageMbForTag", "$ENC_", "AntiCheat", "Integrity"}
        for _, v in ipairs(getnilinstances()) do
            if v.Name == "LocalScript" and not v.Parent then
                local suc, bytecode = pcall(getscriptbytecode, v)
                if suc and bytecode then
                    for _, pat in ipairs(patterns) do
                        if bytecode:find(pat) then
                            detected = true
                            break
                        end
                    end
                end
            end
        end
        if not detected then
            for _, obj in ipairs(getgc(true)) do
                if type(obj) == "table" and tostring(obj):find("AntiCheat") then
                    detected = true
                    break
                end
            end
        end

        WindUI:Notify({
            Title = "Anti-Cheat Scan",
            Content = detected and "⚠️ AC DETECTED (see console)" or "✅ No obvious AC",
            Duration = 5
        })
        if detected then warn("Anticheat detected – check obfuscated scripts.") end
    end
})

-- 3. Spoof Player Data (metatable spoofing)
SecurityTab:Toggle({
    Title = "Spoof Player Data",
    Desc = "Return fake Position/Velocity/WalkSpeed",
    Value = false,
    Callback = function(state)
        _G.SpoofPlayerData = state
        if state and not _G.SpoofHook then
            local player = game:GetService("Players").LocalPlayer
            local character = player.Character or player.CharacterAdded:Wait()
            local humanoid = character:WaitForChild("Humanoid")

            local function hookPart(part)
                if not part or not part:IsA("BasePart") then return end
                local mt = getrawmetatable(part)
                if not mt then return end
                local oldIndex = mt.__index
                mt.__index = function(self, key)
                    if _G.SpoofPlayerData and not checkcaller() then
                        if key == "Position" then
                            local real = rawget(self, key)
                            return real + Vector3.new(math.random(-5,5), math.random(-2,2), math.random(-5,5))
                        elseif key == "Velocity" then
                            return Vector3.new(0,0,0)
                        elseif key == "CFrame" then
                            local real = rawget(self, key)
                            return real * CFrame.new(math.random(-3,3),0,math.random(-3,3))
                        end
                    end
                    return oldIndex(self, key)
                end
                setrawmetatable(part, mt)
            end

            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then hookPart(part) end
            end
            player.CharacterAdded:Connect(function(newChar)
                task.wait(0.5)
                for _, part in ipairs(newChar:GetDescendants()) do
                    if part:IsA("BasePart") then hookPart(part) end
                end
            end)

            -- Hook Humanoid.WalkSpeed
            local hmt = getrawmetatable(humanoid)
            if hmt then
                local oldIndex = hmt.__index
                hmt.__index = function(self, key)
                    if _G.SpoofPlayerData and not checkcaller() and key == "WalkSpeed" then
                        return 16
                    end
                    return oldIndex(self, key)
                end
                setrawmetatable(humanoid, hmt)
            end

            _G.SpoofHook = true
        elseif not state then
            _G.SpoofHook = false
        end
    end
})

-- 4. Kick Detection & Trace (NEW)
local kickTraceEnabled = false
local remoteTracker = {} -- stores last remote path
local remoteHookConnections = {}
local lastRemotePath = "None"

-- Function to get script path from a traceback string
local function extractScriptPath(trace)
    local path = "Unknown"
    -- Look for the first line that contains a script path pattern
    for line in trace:gmatch("[^\r\n]+") do
        -- Patterns for Roblox scripts: .../game/... or .../workspace/...
        local scriptPath = line:match("/([^/]+%.lua):") or line:match("(%[C%]):")
        if scriptPath then
            path = scriptPath
            break
        end
    end
    return path
end

-- Hook remote events and functions to track the last one called
local function hookRemotesForTracking()
    -- Hook RemoteEvent.FireServer
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") and not remoteTracker[obj] then
            local oldFire = obj.FireServer
            remoteTracker[obj] = true
            remoteHookConnections[obj] = hookfunction(obj.FireServer, function(self, ...)
                if kickTraceEnabled then
                    lastRemotePath = "RemoteEvent: " .. self:GetFullName()
                end
                return oldFire(self, ...)
            end)
        elseif obj:IsA("RemoteFunction") and not remoteTracker[obj] then
            local oldInvoke = obj.InvokeServer
            remoteTracker[obj] = true
            remoteHookConnections[obj] = hookfunction(obj.InvokeServer, function(self, ...)
                if kickTraceEnabled then
                    lastRemotePath = "RemoteFunction: " .. self:GetFullName()
                end
                return oldInvoke(self, ...)
            end)
        end
    end
end

-- Hook for new descendants (to track remotes added later)
local function onDescendantAdded(desc)
    if kickTraceEnabled then
        if desc:IsA("RemoteEvent") and not remoteTracker[desc] then
            local oldFire = desc.FireServer
            remoteTracker[desc] = true
            remoteHookConnections[desc] = hookfunction(desc.FireServer, function(self, ...)
                if kickTraceEnabled then
                    lastRemotePath = "RemoteEvent: " .. self:GetFullName()
                end
                return oldFire(self, ...)
            end)
        elseif desc:IsA("RemoteFunction") and not remoteTracker[desc] then
            local oldInvoke = desc.InvokeServer
            remoteTracker[desc] = true
            remoteHookConnections[desc] = hookfunction(desc.InvokeServer, function(self, ...)
                if kickTraceEnabled then
                    lastRemotePath = "RemoteFunction: " .. self:GetFullName()
                end
                return oldInvoke(self, ...)
            end)
        end
    end
end

-- Setup kick detection
local originalKick = nil
local function setupKickTrace()
    local player = game:GetService("Players").LocalPlayer
    if not player then return end
    originalKick = player.Kick

    -- Override Kick
    player.Kick = function(self, message)
        if kickTraceEnabled then
            -- Get traceback
            local trace = debug.traceback("Kick triggered", 2)
            local scriptPath = extractScriptPath(trace)

            -- Build clipboard content
            local info = string.format(
                "KICK DETECTED!\nReason: %s\nSource Script: %s\nLast Remote: %s\nFull Trace:\n%s",
                message or "No reason",
                scriptPath,
                lastRemotePath,
                trace
            )

            -- Copy to clipboard
            local clipFunc = setclipboard or toclipboard or set
            if clipFunc then
                pcall(clipFunc, info)
                WindUI:Notify({
                    Title = "Kick Detected",
                    Content = "Info copied to clipboard!",
                    Duration = 5
                })
                warn(info)
            end
        end

        -- Call original kick
        return originalKick(self, message)
    end
end

-- Enable/disable kick trace
SecurityTab:Toggle({
    Title = "Kick Detection & Trace",
    Desc = "On kick, copy script/remote path to clipboard",
    Value = false,
    Callback = function(state)
        kickTraceEnabled = state
        if state then
            -- Setup hooks
            setupKickTrace()
            hookRemotesForTracking()
            -- Listen for new remotes
            game.DescendantAdded:Connect(onDescendantAdded)
            WindUI:Notify({
                Title = "Kick Trace",
                Content = "Active – will trace kick source",
                Duration = 3
            })
        else
            -- Restore original Kick if we have it
            local player = game:GetService("Players").LocalPlayer
            if player and originalKick then
                player.Kick = originalKick
                originalKick = nil
            end
            -- Unhook remote hooks (optional)
            for obj, hook in pairs(remoteHookConnections) do
                -- We can't easily revert hooks without restoring the original, but we can stop tracking
                -- We'll just disable the logic by setting kickTraceEnabled false.
            end
            WindUI:Notify({
                Title = "Kick Trace",
                Content = "Disabled",
                Duration = 2
            })
        end
    end
})

-- ===============================
-- MOVEMENT TAB (ERX walk speed method)
-- ===============================
local MovementTab = Window:Tab({
    Title = "Movement",
    Icon = "footprints"
})

-- Initialize global variables
_G.SpeedModify = false
_G.SpeedModifyValue = 16

-- Get local player, character, humanoid, root part
local player = game:GetService("Players").LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")

-- Speed loop with error protection
task.spawn(function()
    while true do
        local dt = task.wait()
        if _G.SpeedModify and humanoid and humanoid.Parent and rootPart and rootPart.Parent then
            local moveDir = humanoid.MoveDirection
            local walkSpeed = humanoid.WalkSpeed
            if moveDir and moveDir.Magnitude > 0 and not humanoid.Sit and walkSpeed and walkSpeed > 0 then
                local speedIn1sec = 1 / (dt + 0.001)
                local extra = moveDir * ((_G.SpeedModifyValue - walkSpeed) / speedIn1sec)
                rootPart.CFrame = rootPart.CFrame + extra
            end
        end
    end
end)

MovementTab:Toggle({
    Title = "Walk Speed",
    Desc = "Enable custom walk speed (ERX method)",
    Value = false,
    Callback = function(state)
        _G.SpeedModify = state
    end
})

MovementTab:Slider({
    Title = "Speed Value",
    Desc = "Adjust target walk speed",
    Value = {
        Min = 1,
        Max = 250,
        Default = 16
    },
    Step = 1,
    Callback = function(val)
        _G.SpeedModifyValue = tonumber(val) or 16
    end
})

-- Optional: Noclip
MovementTab:Toggle({
    Title = "Noclip",
    Desc = "Walk through walls",
    Value = false,
    Callback = function(state)
        _G.LocalNoclip = state
        if state then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        else
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
})

-- Infinite Jump
MovementTab:Toggle({
    Title = "Infinite Jump",
    Desc = "Jump repeatedly",
    Value = false,
    Callback = function(state)
        _G.InfiniteJump = state
        if state then
            if not _G.JumpConnection then
                _G.JumpConnection = game:GetService("UserInputService").JumpRequest:Connect(function()
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
            end
        else
            if _G.JumpConnection then
                _G.JumpConnection:Disconnect()
                _G.JumpConnection = nil
            end
        end
    end
})

-- ===============================
-- PREMIUM TAB (God Mode & Infinite Stamina)
-- ===============================
local PremiumTab = Window:Tab({
    Title = "Premium",
    Icon = "crown"
})

-- God Mode variables
local godModeEnabled = false
local godModeConnection = nil

-- Infinite Stamina variables
local staminaEnabled = false
local staminaConnection = nil

-- God Mode functions
local function EnableGodMode(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.MaxHealth = math.huge
    hum.Health = math.huge
    if godModeConnection then godModeConnection:Disconnect() end
    godModeConnection = hum.HealthChanged:Connect(function()
        if godModeEnabled and _G.WilkinsIsPremium then
            hum.Health = math.huge
        end
    end)
end

local function DisableGodMode(char)
    if godModeConnection then
        godModeConnection:Disconnect()
        godModeConnection = nil
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.MaxHealth = 100
        hum.Health = 100
    end
end

-- Infinite Stamina functions
local function StartInfiniteStamina(char)
    local staminaScript = char:FindFirstChild("Stamina")
    if not staminaScript then return end
    local maxStamina = staminaScript:FindFirstChild("MaxStamina")
    local stamina = staminaScript:FindFirstChild("Stamina")
    if not maxStamina or not stamina then return end
    if staminaConnection then staminaConnection:Disconnect() end
    staminaConnection = stamina:GetPropertyChangedSignal("Value"):Connect(function()
        if staminaEnabled and _G.WilkinsIsPremium then
            stamina.Value = maxStamina.Value
        end
    end)
    stamina.Value = maxStamina.Value
end

local function StopInfiniteStamina()
    if staminaConnection then
        staminaConnection:Disconnect()
        staminaConnection = nil
    end
end

-- Apply to current character if toggled
if _G.WilkinsIsPremium then
    -- We'll apply on toggle, not automatically
end

-- God Mode Toggle
local godToggle = PremiumTab:Toggle({
    Title = "God Mode 👑",
    Desc = "Health locked at maximum – you cannot die.",
    Value = false,
    Callback = function(state)
        if not _G.WilkinsIsPremium then
            WindUI:Notify({
                Title = "Locked",
                Content = "Premium feature – enter a valid key to unlock.",
                Duration = 3
            })
            state = false
            godToggle:Set(false)
            return
        end
        godModeEnabled = state
        if state then
            if character then EnableGodMode(character) end
        else
            if character then DisableGodMode(character) end
        end
    end
})

-- Infinite Stamina Toggle
local stamToggle = PremiumTab:Toggle({
    Title = "Infinite Stamina 👑",
    Desc = "Stamina never drains.",
    Value = false,
    Callback = function(state)
        if not _G.WilkinsIsPremium then
            WindUI:Notify({
                Title = "Locked",
                Content = "Premium feature – enter a valid key to unlock.",
                Duration = 3
            })
            state = false
            stamToggle:Set(false)
            return
        end
        staminaEnabled = state
        if state then
            if character then StartInfiniteStamina(character) end
        else
            StopInfiniteStamina()
        end
    end
})

-- If premium is already unlocked, show the toggles as usable.
if _G.WilkinsIsPremium then
    godToggle:Unlock()
    stamToggle:Unlock()
else
    godToggle:Lock()
    godToggle:SetDesc("Premium feature – enter a valid key to unlock")
    stamToggle:Lock()
    stamToggle:SetDesc("Premium feature – enter a valid key to unlock")
end

-- ===============================
-- MISC TAB (Moderator Detection)
-- ===============================
local MiscTab = Window:Tab({
    Title = "Misc",
    Icon = "settings"
})

-- Moderator Detection Section
local ModSection = MiscTab:Section({
    Title = "Moderator Detection"
})

-- Variables for moderator detection
local modDetectionEnabled = false
local modScanTask = nil
local GROUP_ID = 2935212
local MOD_ROLE_ID = 20294813 -- "Game Moderation and Administration" role ID[reference:1]
local lastModAlert = {}
local detectedMods = {}

-- Function to check if a user has the moderator role in the SCP group
local function checkUserModStatus(userId)
    local success, result = pcall(function()
        local url = "https://groups.roblox.com/v1/users/" .. tostring(userId) .. "/groups/roles"
        local response = game:HttpGet(url)
        local data = HttpService:JSONDecode(response)
        if data and data.data then
            for _, groupData in ipairs(data.data) do
                if groupData.group and groupData.group.id == GROUP_ID then
                    if groupData.role and groupData.role.id == MOD_ROLE_ID then
                        return true
                    end
                end
            end
        end
        return false
    end)
    if not success then
        return false
    end
    return result
end

-- Function to scan for moderators
local function scanForModerators()
    local moderators = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local isMod = checkUserModStatus(plr.UserId)
            if isMod then
                table.insert(moderators, plr.Name)
            end
        end
    end
    return moderators
end

-- Function to check if a specific user is in the server
local function checkSpecificUser(username)
    for _, plr in ipairs(Players:GetPlayers()) do
        if string.lower(plr.Name) == string.lower(username) then
            return true, plr.Name
        end
    end
    return false, nil
end

-- Function to start/stop the auto-scan
local function toggleModDetection(state)
    modDetectionEnabled = state
    if modScanTask then
        modScanTask:Disconnect()
        modScanTask = nil
    end
    if state then
        detectedMods = {}
        lastModAlert = {}
        -- Run an initial scan immediately
        task.spawn(function()
            local mods = scanForModerators()
            if #mods > 0 then
                local modList = table.concat(mods, ", ")
                WindUI:Notify({
                    Title = "⚠️ Moderator Detected",
                    Content = "Moderator(s) in server: " .. modList,
                    Duration = 8
                })
                for _, name in ipairs(mods) do
                    detectedMods[name] = true
                    lastModAlert[name] = tick()
                end
            end
        end)
        -- Start the periodic scan (every 10 seconds)
        modScanTask = RunService.Heartbeat:Connect(function()
            if not modDetectionEnabled then return end
            -- Only scan every 10 seconds
            if tick() % 10 < 0.1 then
                task.spawn(function()
                    local mods = scanForModerators()
                    for _, name in ipairs(mods) do
                        if not detectedMods[name] then
                            detectedMods[name] = true
                            lastModAlert[name] = tick()
                            WindUI:Notify({
                                Title = "⚠️ Moderator Joined",
                                Content = name .. " is now in the server!",
                                Duration = 8
                            })
                        else
                            -- Update last seen time
                            lastModAlert[name] = tick()
                        end
                    end
                    -- Check for moderators that left
                    for name, _ in pairs(detectedMods) do
                        local stillHere = false
                        for _, modName in ipairs(mods) do
                            if modName == name then
                                stillHere = true
                                break
                            end
                        end
                        if not stillHere then
                            detectedMods[name] = nil
                            lastModAlert[name] = nil
                        end
                    end
                end)
            end
        end)
    else
        detectedMods = {}
        lastModAlert = {}
        WindUI:Notify({
            Title = "Moderator Detection",
            Content = "Auto-scan disabled.",
            Duration = 3
        })
    end
end

-- Toggle for auto moderator detection
local modToggle = ModSection:Toggle({
    Title = "Auto Moderator Detection",
    Desc = "Scans for 'Game Moderation and Administration' every 10 seconds",
    Value = false,
    Callback = function(state)
        toggleModDetection(state)
    end
})

-- Manual scan button for specific user
ModSection:Button({
    Title = "Scan for 'chilten44pa'",
    Desc = "Check if chilten44pa is in the server",
    Callback = function()
        local found, name = checkSpecificUser("chilten44pa")
        if found then
            WindUI:Notify({
                Title = "🔍 User Found",
                Content = name .. " is currently in the server!",
                Duration = 5
            })
        else
            WindUI:Notify({
                Title = "🔍 User Not Found",
                Content = "chilten44pa is not in the server.",
                Duration = 5
            })
        end
    end
})

-- Manual full scan button
ModSection:Button({
    Title = "Manual Full Scan",
    Desc = "Scan for all moderators in the server",
    Callback = function()
        WindUI:Notify({
            Title = "Scanning...",
            Content = "Checking for moderators...",
            Duration = 3
        })
        task.spawn(function()
            local mods = scanForModerators()
            if #mods > 0 then
                local modList = table.concat(mods, ", ")
                WindUI:Notify({
                    Title = "⚠️ Moderator(s) Found",
                    Content = "Moderator(s) in server: " .. modList,
                    Duration = 8
                })
            else
                WindUI:Notify({
                    Title = "✅ No Moderators",
                    Content = "No 'Game Moderation and Administration' members found.",
                    Duration = 5
                })
            end
        end)
    end
})

-- ===============================
-- UPDATE REFERENCES ON RESPAWN
-- ===============================
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:FindFirstChild("HumanoidRootPart") or newChar:WaitForChild("HumanoidRootPart")

    -- Reapply premium features if enabled
    if godModeEnabled and _G.WilkinsIsPremium then
        EnableGodMode(newChar)
    end
    if staminaEnabled and _G.WilkinsIsPremium then
        StartInfiniteStamina(newChar)
    end
end)

-- Clean up on player leave
Players.PlayerRemoving:Connect(function(plr)
    if modDetectionEnabled then
        local name = plr.Name
        if detectedMods[name] then
            detectedMods[name] = nil
            lastModAlert[name] = nil
        end
    end
end)

-- ===============================
-- NOTIFY LOADED
-- ===============================
WindUI:Notify({
    Title = "Electron Hub Loaded",
    Content = "Security, Movement & Misc ready! Premium features require a key.",
    Duration = 3
})

-- Return window for potential external use
return Window
