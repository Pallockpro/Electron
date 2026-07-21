-- ============================================================
-- Electron Hub (Blue Lock Rivals)
-- Premium: Insane Kick (toggle + power) – locked behind PandaAuth
-- Free: Shot Multiplier, Headers, Auto‑Aim, Utility, Misc, GK
-- Author: @blackberryfr & @pikaorsmth
-- ============================================================

-- ========== 0. PATCH: makefolder to prevent errors ==========
local originalMakeFolder = makefolder
if originalMakeFolder then
    makefolder = function(path)
        pcall(originalMakeFolder, path)
    end
else
    makefolder = function() end
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- LOAD WINDUI
-- ============================================================
local WindUI
local success, err = pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not success then
    warn("Failed to load WindUI: " .. tostring(err))
    return
end
print("✅ WindUI loaded")

-- ========== Prepare the PandaAuth (Wilkins) service ==========
local WilkinsLib = nil
local HttpService = game:GetService("HttpService")

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

-- ========== Create the main window with key system ==========
local Window = WindUI:CreateWindow({
    Title = "Electron Hub",
    Icon = "zap",
    Author = "@blackberryfr & @pikaorsmth",
    Size = UDim2.fromOffset(460, 680),
    Transparent = true,
    Theme = "Dark",
    Resizable = true,
    ToggleKey = Enum.KeyCode.K,

    KeySystem = {
        Note = "Enter your PandaAuth key to unlock premium features.",
        API = {
            {
                Type = "pandaauth",
                ServiceId = "getkeyhub",
            },
        },
    },
})

-- ========== Key accepted – show notification ==========
if _G.WilkinsIsPremium then
    WindUI:Notify({
        Title = "👑 Premium Unlocked",
        Content = "Insane Kick is now available.",
        Duration = 8
    })
end

-- ========== Keep the session alive ==========
if WilkinsLib then
    task.spawn(function()
        while WilkinsLib.isConnected and WilkinsLib.isConnected() do
            task.wait(5)
        end
        warn("[Wilkins] Session closed.")
    end)
end

-- ============================================================
-- STATE & CONFIG
-- ============================================================
local kickEnabled = false
local kickPower = 1000
local multiplierEnabled = false
local multiplier = 1.0
local autoAimEnabled = false
local headerEnabled = false
local headerPower = 1000
local alwaysHeader = false
local fastModeEnabled = false
local ballControlEnabled = false
local ballControlSpeed = 150
local autoGKEnabled = false
local showPrediction = false
local showTrailEnabled = false
local gkReactionRange = 40

-- Remote hooks
local hookedRemoteSet = {}
local lastRemoteKickTime = 0

-- Touch & heartbeat timing
local lastTouchKickTime = 0
local lastHeartbeatKickTime = 0
local TOUCH_DEBOUNCE = 0.2
local HEARTBEAT_DEBOUNCE = 0.3

-- Proximity exit detection
local proximityNearStart = nil
local lastProximityExitKickTime = 0
local PROXIMITY_NEAR_DIST = 5
local PROXIMITY_EXIT_GRACE = 0.3
local PROXIMITY_EXIT_COOLDOWN = 0.5

-- Ball & character
local ball = nil
local currentCharacter = LocalPlayer.Character

-- Ball control state
local ballControlLoop = nil
local originalCameraSubject = nil

-- Auto GK state
local gkLoop = nil
local gkHitbox = nil
local predictionIndicator = nil
local predictionBeam = nil
local smoothedTargetX = nil
local smoothedTargetZ = nil

-- GK ability remotes
local jumpRemote = nil
local diveRemote = nil
local staminaRemote = nil

-- Ball history for prediction
local prevBallPos = nil
local prevBallVel = Vector3.zero
local lastBallUpdateTime = 0

-- Error tracking
local emergencyMode = false
local emergencyStartTime = 0

-- Trail
local ballTrail = nil

-- UI references
local ballControlToggle = nil
local kickToggle = nil
local gkToggle = nil
local trailToggle = nil
local predictionToggle = nil
local kickPowerSlider = nil

-- ============================================================
-- OPPONENT GOAL FINDER (unchanged)
-- ============================================================
local function getOpponentGoal()
    local homeMove = workspace:FindFirstChild("AI") and workspace.AI:FindFirstChild("Home") and workspace.AI.Home:FindFirstChild("MovementBox")
    local awayMove = workspace:FindFirstChild("AI") and workspace.AI:FindFirstChild("Away") and workspace.AI.Away:FindFirstChild("MovementBox")
    
    if not homeMove or not awayMove then
        homeMove = workspace:FindFirstChild("Home") and workspace.Home:FindFirstChild("MovementBox")
        awayMove = workspace:FindFirstChild("Away") and workspace.Away:FindFirstChild("MovementBox")
    end
    
    if not homeMove or not awayMove then
        for _, child in ipairs(workspace:GetDescendants()) do
            if child:IsA("BasePart") and child.Name == "MovementBox" then
                if not homeMove then homeMove = child
                elseif not awayMove and child ~= homeMove then awayMove = child end
            end
        end
    end
    
    if not homeMove or not awayMove then
        for _, child in ipairs(workspace:GetDescendants()) do
            if child:IsA("BasePart") and child.Name == "DiveBox" then
                if not homeMove then homeMove = child
                elseif not awayMove and child ~= homeMove then awayMove = child end
            end
        end
    end
    
    if not homeMove or not awayMove then return nil end

    local team = LocalPlayer.Team
    local opponentGoal = nil
    if team then
        if team.Name == "Home" then opponentGoal = awayMove
        elseif team.Name == "Away" then opponentGoal = homeMove end
    end

    if not opponentGoal then
        local char = LocalPlayer.Character
        if not char then return nil end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local playerPos = root.Position
        local distHome = (playerPos - homeMove.Position).Magnitude
        local distAway = (playerPos - awayMove.Position).Magnitude
        opponentGoal = (distHome > distAway) and homeMove or awayMove
    end

    return opponentGoal
end

-- ============================================================
-- AIM DIRECTION HELPERS (unchanged)
-- ============================================================
local function getHeaderDirection()
    local targetGoal = getOpponentGoal()
    if targetGoal and LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local origin = root.Position
            local goalPos = targetGoal.Position + Vector3.new(0, 0.5, 0)
            return (goalPos - origin).unit
        end
    end
    return workspace.CurrentCamera.CFrame.LookVector
end

local function getAimDirection()
    if autoAimEnabled then
        local targetGoal = getOpponentGoal()
        if targetGoal and LocalPlayer.Character then
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local origin = root.Position
                local goalPos = targetGoal.Position + Vector3.new(0, 0.5, 0)
                return (goalPos - origin).unit
            end
        end
    end
    return workspace.CurrentCamera.CFrame.LookVector
end

-- ============================================================
-- HEADER SITUATION DETECTION (unchanged)
-- ============================================================
local function isHeaderSituation()
    if not ball or not ball.Parent then return false end
    if not currentCharacter or not currentCharacter.Parent then return false end
    local head = currentCharacter:FindFirstChild("Head")
    if not head then return false end
    local ballPos = ball.Position
    local headPos = head.Position
    local heightDiff = ballPos.Y - headPos.Y
    local horizontalDist = Vector2.new(ballPos.X - headPos.X, ballPos.Z - headPos.Z).Magnitude
    return heightDiff > 0 and heightDiff < 15 and horizontalDist < 10
end

-- ============================================================
-- POSSESSION / TOUCH / OWNERSHIP (unchanged)
-- ============================================================
local function isBallPossessedByPlayer()
    if not ball or not ball.Parent then return false end
    if not currentCharacter or not currentCharacter.Parent then return false end
    if ball:IsDescendantOf(currentCharacter) then return true end
    for _, joint in ipairs(ball:GetChildren()) do
        if joint:IsA("Weld") or joint:IsA("Motor6D") or joint:IsA("ManualWeld") then
            if joint.Part1 and joint.Part1:IsDescendantOf(currentCharacter) then
                return true
            end
        end
    end
    return false
end

local function getBallPossessingPlayer()
    if not ball or not ball.Parent then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if char then
            if ball:IsDescendantOf(char) then return player, char end
            for _, joint in ipairs(ball:GetChildren()) do
                if joint:IsA("Weld") or joint:IsA("Motor6D") or joint:IsA("ManualWeld") then
                    if joint.Part1 and joint.Part1:IsDescendantOf(char) then
                        return player, char
                    end
                end
            end
        end
    end
    return nil
end

local function isBallAttachedToAnyPlayer()
    if not ball or not ball.Parent then return false end
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            if ball:IsDescendantOf(char) then return true end
            for _, joint in ipairs(ball:GetChildren()) do
                if joint:IsA("Weld") or joint:IsA("Motor6D") or joint:IsA("ManualWeld") then
                    if joint.Part1 and joint.Part1:IsDescendantOf(char) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function isBallTouchingPlayer()
    if not ball or not currentCharacter then return false end
    local touchingParts = ball:GetTouchingParts()
    for _, part in ipairs(touchingParts) do
        if part:IsDescendantOf(currentCharacter) then
            return true
        end
    end
    return false
end

local function hasNetworkOwnership()
    if not ball then return false end
    local s, result = pcall(function() return isnetworkowner(ball) end)
    return s and result
end

-- ============================================================
-- FAST MODE (unchanged)
-- ============================================================
local function applyFastMode()
    if fastModeEnabled then
        Lighting.GlobalShadows = false
        Lighting.Technology = Enum.Technology.Compatibility
        settings().Rendering.QualityLevel = 1
        print("⚡ Fast Mode enabled")
    else
        Lighting.GlobalShadows = true
        Lighting.Technology = Enum.Technology.ShadowMap
        settings().Rendering.QualityLevel = 10
        print("⚡ Fast Mode disabled")
    end
end

-- ============================================================
-- BALL TRAIL (unchanged)
-- ============================================================
local function setupBallTrail()
    if not ball then return end
    if ballTrail then ballTrail:Destroy() end
    ballTrail = Instance.new("Trail")
    ballTrail.Attachment0 = ball:FindFirstChild("TrailAttachment0") or Instance.new("Attachment", ball)
    ballTrail.Attachment1 = ball:FindFirstChild("TrailAttachment1") or Instance.new("Attachment", ball)
    ballTrail.Attachment0.Name = "TrailAttachment0"
    ballTrail.Attachment1.Name = "TrailAttachment1"
    ballTrail.Attachment0.Position = Vector3.new(0, 0, 0)
    ballTrail.Attachment1.Position = Vector3.new(0, 0, -1)
    ballTrail.FaceCamera = true
    ballTrail.Enabled = true
    ballTrail.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
    ballTrail.Transparency = NumberSequence.new(0.5)
    ballTrail.Lifetime = 1
    ballTrail.MinLength = 0.1
    ballTrail.MaxLength = 10
    ballTrail.Parent = ball
end

local function removeBallTrail()
    if ballTrail then ballTrail:Destroy(); ballTrail = nil end
end

-- ============================================================
-- BALL CONTROL (mouse steering) – unchanged
-- ============================================================
local function startBallControl()
    if not ball or not ball.Parent then
        WindUI:Notify({ Title = "Ball Control", Content = "No ball found!", Duration = 3 })
        ballControlEnabled = false
        if ballControlToggle then ballControlToggle:Set(false) end
        return
    end

    originalCameraSubject = workspace.CurrentCamera.CameraSubject or (currentCharacter and currentCharacter:FindFirstChild("Humanoid"))
    workspace.CurrentCamera.CameraSubject = ball
    ball.CanCollide = true
    ball.Massless = false
    ball.Transparency = 0

    if ballControlLoop then task.cancel(ballControlLoop) end

    ballControlLoop = task.spawn(function()
        while ballControlEnabled and ball and ball.Parent and currentCharacter do
            local mousePos = UserInputService:GetMouseLocation()
            local ray = workspace.CurrentCamera:ScreenPointToRay(mousePos.X, mousePos.Y)
            local targetPos = ray.Origin + ray.Direction * 50
            local dir = targetPos - ball.Position
            if dir.Magnitude > 0 then
                ball.AssemblyLinearVelocity = dir.Unit * ballControlSpeed
            end
            RunService.RenderStepped:Wait()
        end
        stopBallControl()
    end)
end

local function stopBallControl()
    if ballControlLoop then task.cancel(ballControlLoop); ballControlLoop = nil end
    if originalCameraSubject then workspace.CurrentCamera.CameraSubject = originalCameraSubject
    elseif currentCharacter and currentCharacter:FindFirstChild("Humanoid") then workspace.CurrentCamera.CameraSubject = currentCharacter.Humanoid end
    originalCameraSubject = nil
    if ball and ball.Parent then
        ball.AssemblyLinearVelocity = Vector3.zero
        ball.CanCollide = true
        ball.Massless = false
        ball.Transparency = 0
    end
    ballControlEnabled = false
    if ballControlToggle then ballControlToggle:Set(false) end
end

-- ============================================================
-- GK HELPERS (unchanged)
-- ============================================================
local function getOwnGoalBoxes()
    local team = LocalPlayer.Team
    if not team then return nil, nil, nil end
    local teamName = team.Name
    local folder = workspace:FindFirstChild("AI") and workspace.AI:FindFirstChild(teamName)
    if not folder then return nil, nil, nil end
    local diveBox = folder:FindFirstChild("DiveBox")
    local goalBox = folder:FindFirstChild("GoalBox")
    local penaltyBox = folder:FindFirstChild("PenaltyBox")
    return diveBox, goalBox, penaltyBox
end

local function isInHorizontalBounds(point, box)
    if not box then return false end
    local localPos = box.CFrame:PointToObjectSpace(point)
    local half = box.Size / 2
    return math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z
end

-- ============================================================
-- FETCH GK REMOTES (unchanged)
-- ============================================================
local function fetchGKRemotes()
    local ballService = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Knit") and ReplicatedStorage.Packages.Knit:FindFirstChild("Services") and ReplicatedStorage.Packages.Knit.Services:FindFirstChild("BallService")
    if ballService then
        local re = ballService:FindFirstChild("RE")
        if re then
            jumpRemote = re:FindFirstChild("Jump")
            diveRemote = re:FindFirstChild("Dive")
        end
    end
    local staminaService = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Knit") and ReplicatedStorage.Packages.Knit:FindFirstChild("Services") and ReplicatedStorage.Packages.Knit.Services:FindFirstChild("StaminaService")
    if staminaService then
        local re = staminaService:FindFirstChild("RE")
        if re then
            staminaRemote = re:FindFirstChild("DecreaseStamina")
        end
    end
    if jumpRemote then print("✅ Jump remote found") else print("⚠️ Jump remote not found") end
    if diveRemote then print("✅ Dive remote found") else print("⚠️ Dive remote not found") end
    if staminaRemote then print("✅ Stamina remote found") else print("⚠️ Stamina remote not found") end
end

-- ============================================================
-- MULTI‑MODEL PREDICTION (unchanged)
-- ============================================================
local function linearPredict(pos, vel, t)
    return pos + vel * t
end

local function gravityPredict(pos, vel, t)
    local g = Vector3.new(0, -workspace.Gravity, 0)
    return pos + vel * t + 0.5 * g * t * t
end

local function accelPredict(pos, vel, accel, t)
    return pos + vel * t + 0.5 * accel * t * t
end

local function getBallPrediction(targetTime)
    if not ball then return ball.Position, 0 end
    local now = tick()
    local dt = now - lastBallUpdateTime
    if dt <= 0 then dt = 0.016 end
    local pos = ball.Position
    local vel = ball.AssemblyLinearVelocity
    local accel = (vel - prevBallVel) / dt

    prevBallPos = pos
    prevBallVel = vel
    lastBallUpdateTime = now

    local speed = vel.Magnitude
    local isAirborne = ball.Position.Y > 3
    local velChange = (vel - prevBallVel).Magnitude
    local stable = velChange < 5

    local pLinear = linearPredict(pos, vel, targetTime)
    local pGravity = gravityPredict(pos, vel, targetTime)
    local pAccel = accelPredict(pos, vel, accel, targetTime)

    local wLinear, wGravity, wAccel = 0, 0, 0
    if stable and not isAirborne then
        wLinear = 0.7; wGravity = 0.3
    elseif isAirborne and stable then
        wGravity = 0.8; wLinear = 0.2
    else
        wAccel = 0.6; wLinear = 0.2; wGravity = 0.2
    end

    if emergencyMode then
        local pCorr = linearPredict(pos, vel, 0.1)
        local recoveryBlend = math.clamp((tick() - emergencyStartTime) / 1.0, 0, 1)
        wLinear = 0.2 * (1 - recoveryBlend) + 0.7 * recoveryBlend
        wGravity = 0.2 * (1 - recoveryBlend) + 0.3 * recoveryBlend
        wAccel = 0.6 * (1 - recoveryBlend)
        local wCorr = 1 - recoveryBlend
        local avgPos = (pLinear * wLinear + pGravity * wGravity + pAccel * wAccel) * (1 - wCorr) + pCorr * wCorr
        return avgPos, wCorr + recoveryBlend
    end

    local totalWeight = wLinear + wGravity + wAccel
    if totalWeight == 0 then
        return pos, 0
    end
    local weightedPos = (pLinear * wLinear + pGravity * wGravity + pAccel * wAccel) / totalWeight
    return weightedPos, totalWeight
end

-- ============================================================
-- ATTACKER‑AWARE POSITIONING (unchanged)
-- ============================================================
local function getAttackerAimTarget(diveBox)
    local attackerPlayer, attackerChar = getBallPossessingPlayer()
    if not attackerChar then return nil end
    local hrp = attackerChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local attackerPos = hrp.Position
    local attackerLook = hrp.CFrame.LookVector

    local goalZ = diveBox.Position.Z
    local t = (goalZ - attackerPos.Z) / attackerLook.Z
    if t <= 0 then return nil end

    local hitPoint = attackerPos + attackerLook * t
    local targetX = math.clamp(hitPoint.X, diveBox.Position.X - diveBox.Size.X/2, diveBox.Position.X + diveBox.Size.X/2)
    local distToGoal = math.abs(goalZ - attackerPos.Z)
    local shotSpeed = 80
    local timeToGoal = distToGoal / shotSpeed

    return Vector3.new(targetX, hrp.Position.Y, goalZ), attackerPos, timeToGoal
end

-- ============================================================
-- AUTO GK (unchanged)
-- ============================================================
local function startAutoGK()
    if autoGKEnabled then
        if gkLoop then task.cancel(gkLoop); gkLoop = nil end
        if not gkHitbox then
            gkHitbox = Instance.new("Part")
            gkHitbox.Size = Vector3.new(6, 8, 2)
            gkHitbox.Anchored = true
            gkHitbox.CanCollide = false
            gkHitbox.Transparency = 1
            gkHitbox.Parent = workspace
        end
        if showPrediction then
            if predictionIndicator then predictionIndicator:Destroy() end
            predictionIndicator = Instance.new("Part")
            predictionIndicator.Shape = Enum.PartType.Ball
            predictionIndicator.Size = Vector3.new(1, 1, 1)
            predictionIndicator.Anchored = true
            predictionIndicator.CanCollide = false
            predictionIndicator.Color = Color3.fromRGB(0, 255, 0)
            predictionIndicator.Transparency = 0.5
            predictionIndicator.Parent = workspace

            if predictionBeam then predictionBeam:Destroy() end
            predictionBeam = Instance.new("Beam")
            predictionBeam.FaceCamera = true
            predictionBeam.Width0 = 0.2
            predictionBeam.Width1 = 0.2
            predictionBeam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 0))
            predictionBeam.Transparency = NumberSequence.new(0.5)
            predictionBeam.Parent = workspace
        else
            if predictionIndicator then predictionIndicator:Destroy(); predictionIndicator = nil end
            if predictionBeam then predictionBeam:Destroy(); predictionBeam = nil end
        end

        fetchGKRemotes()
        prevBallPos = ball and ball.Position
        prevBallVel = ball and ball.AssemblyLinearVelocity or Vector3.zero
        lastBallUpdateTime = tick()
        smoothedTargetX = nil
        smoothedTargetZ = nil
        emergencyMode = false

        gkLoop = task.spawn(function()
            while autoGKEnabled do
                local char = LocalPlayer.Character
                if not char then task.wait(0.1); continue end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then task.wait(0.1); continue end

                local diveBox, goalBox, penaltyBox = getOwnGoalBoxes()
                if not diveBox or not goalBox then task.wait(0.1); continue end

                if not ball or not ball.Parent then
                    ball = workspace:FindFirstChild("Football")
                    task.wait(0.1); continue
                end

                local ballPos = ball.Position
                local ballVel = ball.AssemblyLinearVelocity

                if prevBallPos then
                    local shortPred = linearPredict(prevBallPos, prevBallVel, tick() - lastBallUpdateTime)
                    local err = (ballPos - shortPred).Magnitude
                    if err > 5 and not emergencyMode then
                        emergencyMode = true
                        emergencyStartTime = tick()
                    elseif emergencyMode and tick() - emergencyStartTime > 1.5 and err < 2 then
                        emergencyMode = false
                    end
                end

                local attackerAimTarget, attackerPos, attackerTime = getAttackerAimTarget(diveBox)
                local ballFree = not isBallAttachedToAnyPlayer()

                local inGoalBox = goalBox and (ballPos - goalBox.Position).Magnitude < goalBox.Size.Magnitude
                local inPenaltyBox = penaltyBox and isInHorizontalBounds(ballPos, penaltyBox)
                local attackerInPenaltyBox = attackerPos and isInHorizontalBounds(attackerPos, penaltyBox)

                if not inGoalBox and not inPenaltyBox and not attackerInPenaltyBox then
                    task.wait(0.03)
                    continue
                end

                local targetX, targetZ, targetY
                local goalZ = diveBox.Position.Z
                local zSign = (ballPos.Z > goalZ and 1) or -1

                if ballFree then
                    local timeToGoal = (ballVel.Z ~= 0) and ((goalZ - ballPos.Z) / ballVel.Z) or 0.5
                    if timeToGoal < 0 then timeToGoal = 0 end
                    if timeToGoal > 2 then timeToGoal = 2 end
                    local predictedPos, confidence = getBallPrediction(timeToGoal)

                    local forwardOffset = math.clamp(5 - math.abs(ballPos.Z - goalZ), 1, 4)
                    targetZ = goalZ + forwardOffset * zSign
                    targetX = math.clamp(predictedPos.X, diveBox.Position.X - diveBox.Size.X/2, diveBox.Position.X + diveBox.Size.X/2)
                    targetY = predictedPos.Y

                    if predictionIndicator then
                        local indicatorPos = Vector3.new(targetX, targetY, goalZ + 0.5 * zSign)
                        predictionIndicator.Position = indicatorPos
                        if predictionBeam then
                            predictionBeam.Attachment0 = ball:FindFirstChild("BeamAttachment0") or Instance.new("Attachment", ball)
                            predictionBeam.Attachment0.Name = "BeamAttachment0"
                            predictionBeam.Attachment1 = predictionIndicator:FindFirstChild("BeamAttachment1") or Instance.new("Attachment", predictionIndicator)
                            predictionBeam.Attachment1.Name = "BeamAttachment1"
                            predictionBeam.Attachment0.WorldPosition = ballPos
                            predictionBeam.Attachment1.WorldPosition = indicatorPos
                        end
                    end
                elseif attackerAimTarget then
                    local aimPos = attackerAimTarget
                    local distToAttacker = (attackerPos - hrp.Position).Magnitude
                    local isClose = distToAttacker < 10
                    if isClose then
                        targetX = aimPos.X
                        targetZ = goalZ + 1 * zSign
                        targetY = math.clamp(attackerPos.Y, hrp.Position.Y, diveBox.Position.Y + diveBox.Size.Y/2)
                        local snapPos = Vector3.new(targetX, hrp.Position.Y, targetZ)
                        hrp.CFrame = CFrame.lookAt(snapPos, attackerPos)
                    else
                        targetX = math.clamp(aimPos.X, diveBox.Position.X - diveBox.Size.X/2, diveBox.Position.X + diveBox.Size.X/2)
                        targetZ = goalZ + 1 * zSign
                        targetY = attackerPos.Y
                    end
                    if predictionIndicator then predictionIndicator.Position = Vector3.new(0,-100,0) end
                else
                    task.wait(0.03)
                    continue
                end

                if not (attackerAimTarget and (attackerPos - hrp.Position).Magnitude < 10) then
                    if not smoothedTargetX then
                        smoothedTargetX = targetX
                        smoothedTargetZ = targetZ
                    else
                        smoothedTargetX = smoothedTargetX * 0.8 + targetX * 0.2
                        smoothedTargetZ = smoothedTargetZ * 0.8 + targetZ * 0.2
                    end
                    local currentPos = hrp.Position
                    local lerpFactor = 0.4
                    local newPos = Vector3.new(
                        currentPos.X + (smoothedTargetX - currentPos.X) * lerpFactor,
                        currentPos.Y,
                        currentPos.Z + (smoothedTargetZ - currentPos.Z) * lerpFactor
                    )
                    hrp.CFrame = CFrame.lookAt(newPos, ballPos)
                end

                local minY = hrp.Position.Y - 0.5
                local maxY = diveBox.Position.Y + diveBox.Size.Y/2
                local hitboxY = math.clamp(targetY or ballPos.Y, math.min(minY, maxY), math.max(minY, maxY))
                gkHitbox.CFrame = CFrame.new(hrp.Position.X, hitboxY, hrp.Position.Z) * CFrame.new(0, 0, 2)

                local distToBall = (ballPos - hrp.Position).Magnitude
                if ballFree and ballVel.Magnitude > 5 and distToBall < 6 and (ballVel.Z ~= 0 and ((goalZ - ballPos.Z) / ballVel.Z) < 0.5) then
                    if diveRemote then
                        diveRemote:FireServer()
                        if staminaRemote then staminaRemote:FireServer(10) end
                        print("🤾 GK Dive")
                    end
                end
                if ballFree and (targetY or ballPos.Y) > hrp.Position.Y + 3 and ballVel.Magnitude > 5 then
                    if jumpRemote then
                        jumpRemote:FireServer()
                        print("🦘 GK Jump")
                    end
                end

                if (ballPos - gkHitbox.Position).Magnitude < (gkHitbox.Size.X/2) then
                    ball.AssemblyLinearVelocity = Vector3.zero
                    ball.AssemblyAngularVelocity = Vector3.zero
                    ball.Position = gkHitbox.Position
                end

                task.wait(0.03)
            end
            if gkHitbox then gkHitbox:Destroy(); gkHitbox = nil end
            if predictionIndicator then predictionIndicator:Destroy(); predictionIndicator = nil end
            if predictionBeam then predictionBeam:Destroy(); predictionBeam = nil end
            gkLoop = nil
        end)
    else
        if gkLoop then task.cancel(gkLoop); gkLoop = nil end
        if gkHitbox then gkHitbox:Destroy(); gkHitbox = nil end
        if predictionIndicator then predictionIndicator:Destroy(); predictionIndicator = nil end
        if predictionBeam then predictionBeam:Destroy(); predictionBeam = nil end
    end
end

-- ============================================================
-- RELIABLE REMOTE HOOKS (unchanged)
-- ============================================================
local function hookAllRemotes()
    local knit = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Knit")
    if not knit then return end
    local ballService = knit:FindFirstChild("Services") and knit.Services:FindFirstChild("BallService")
    if not ballService then return end
    local reFolder = ballService:FindFirstChild("RE")
    if not reFolder then return end

    local remotesToHook = {}
    for _, remote in ipairs(reFolder:GetChildren()) do
        if not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then continue end
        local name = remote.Name:lower()
        if name:find("goalie") then continue end
        if name:find("shoot") or name:find("volley") or name:find("kick") then
            remotesToHook[remote] = "shoot"
        elseif name:find("header") or name:find("head") then
            remotesToHook[remote] = "header"
        end
    end

    local mt = getrawmetatable(game)
    if not mt then return end
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" then
            local actionType = remotesToHook[self]
            if actionType then
                local args = {...}
                local originalPower = args[1]
                if type(originalPower) == "number" then
                    local finalPower = originalPower
                    local finalDirection = args[2]
                    local modified = false

                    if alwaysHeader then
                        finalPower = headerPower
                        finalDirection = getAimDirection()
                        print("🦅 Always Header Kick (remote): power =", finalPower)
                        modified = true
                    elseif actionType == "shoot" and kickEnabled and _G.WilkinsIsPremium then
                        finalPower = kickPower
                        if autoAimEnabled then finalDirection = getAimDirection() end
                        print("💥 Insane Kick (remote): power =", finalPower)
                        modified = true
                    elseif actionType == "shoot" and not kickEnabled and multiplierEnabled then
                        finalPower = originalPower * multiplier
                        if autoAimEnabled then finalDirection = getAimDirection() end
                        modified = true
                    elseif actionType == "header" and headerEnabled then
                        finalPower = headerPower
                        finalDirection = getHeaderDirection()
                        print("🦅 OP Header (remote): power =", finalPower)
                        modified = true
                    end

                    if modified then
                        args[1] = finalPower
                        if finalDirection and typeof(finalDirection) == "Vector3" then
                            args[2] = finalDirection
                        end
                        lastRemoteKickTime = tick()
                    end
                end
                return oldNamecall(self, table.unpack(args))
            end
        end
        return oldNamecall(self, ...)
    end
    setreadonly(mt, true)
    hookedRemoteSet = remotesToHook
    print("✅ Remote hooks installed via __namecall")
end

local function keepHooksAlive()
    while true do
        pcall(hookAllRemotes)
        task.wait(10)
    end
end

-- ============================================================
-- TOUCH FALLBACK (unchanged)
-- ============================================================
local function onBallTouched(otherPart)
    if not ball or not ball.Parent then return end
    if not currentCharacter or not currentCharacter.Parent then return end
    if not otherPart:IsDescendantOf(currentCharacter) then return end
    if isBallPossessedByPlayer() then return end

    local now = tick()
    if now - lastTouchKickTime < TOUCH_DEBOUNCE then return end

    if alwaysHeader then
        lastTouchKickTime = now
        ball.CanCollide = true
        ball.Massless = false
        ball.AssemblyLinearVelocity = getAimDirection() * headerPower
        print("🦅 Touch Always Header: power", headerPower)
    elseif kickEnabled and _G.WilkinsIsPremium then
        lastTouchKickTime = now
        ball.CanCollide = true
        ball.Massless = false
        ball.AssemblyLinearVelocity = getAimDirection() * kickPower
        print("💥 Touch Kick: power", kickPower)
    end
end

local function onHeaderTouch(otherPart)
    if not ball or not ball.Parent then return end
    if not currentCharacter or not currentCharacter.Parent then return end
    if not otherPart:IsDescendantOf(currentCharacter) then return end
    if not isHeaderSituation() then return end
    if isBallPossessedByPlayer() then return end

    local now = tick()
    if now - lastTouchKickTime < TOUCH_DEBOUNCE then return end

    if headerEnabled or alwaysHeader then
        lastTouchKickTime = now
        ball.CanCollide = true
        ball.Massless = false
        ball.AssemblyLinearVelocity = getHeaderDirection() * headerPower
        print("🦅 Touch Header: power", headerPower)
    end
end

-- ============================================================
-- HEARTBEAT FALLBACK (unchanged)
-- ============================================================
local function heartbeatFallback()
    local now = tick()
    if not (kickEnabled or headerEnabled or alwaysHeader) then return end
    if not ball or not ball.Parent then return end
    if not currentCharacter or not currentCharacter.Parent then return end
    if isBallPossessedByPlayer() then
        proximityNearStart = nil
        return
    end

    local root = currentCharacter:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local dist = (ball.Position - root.Position).Magnitude

    if dist < PROXIMITY_NEAR_DIST then
        if not proximityNearStart then proximityNearStart = now end
    else
        if proximityNearStart then
            local nearDuration = now - proximityNearStart
            if nearDuration < PROXIMITY_EXIT_GRACE then
                local cooldownOK = (now - lastProximityExitKickTime) > PROXIMITY_EXIT_COOLDOWN
                local remoteNotRecent = (now - lastRemoteKickTime) > 0.2
                local ballSpeed = ball.AssemblyLinearVelocity.Magnitude
                if cooldownOK and remoteNotRecent and ballSpeed < 10 then
                    lastProximityExitKickTime = now
                    ball.CanCollide = true
                    ball.Massless = false
                    if alwaysHeader then
                        ball.AssemblyLinearVelocity = getAimDirection() * headerPower
                        print("🦅 Proximity Exit Always Header: power", headerPower)
                    elseif kickEnabled and _G.WilkinsIsPremium then
                        ball.AssemblyLinearVelocity = getAimDirection() * kickPower
                        print("💥 Proximity Exit Kick: power", kickPower)
                    elseif headerEnabled and isHeaderSituation() then
                        ball.AssemblyLinearVelocity = getHeaderDirection() * headerPower
                        print("🦅 Proximity Exit Header: power", headerPower)
                    end
                end
            end
            proximityNearStart = nil
        end
    end

    if not isBallTouchingPlayer() then return end
    if now - lastRemoteKickTime < 0.15 then return end
    if ball.AssemblyLinearVelocity.Magnitude > 10 then return end

    if alwaysHeader and now - lastHeartbeatKickTime > HEARTBEAT_DEBOUNCE then
        lastHeartbeatKickTime = now
        ball.CanCollide = true
        ball.Massless = false
        ball.AssemblyLinearVelocity = getAimDirection() * headerPower
        print("🦅 Heartbeat Always Header: power", headerPower)
    elseif kickEnabled and _G.WilkinsIsPremium and now - lastHeartbeatKickTime > HEARTBEAT_DEBOUNCE then
        lastHeartbeatKickTime = now
        ball.CanCollide = true
        ball.Massless = false
        ball.AssemblyLinearVelocity = getAimDirection() * kickPower
        print("💥 Heartbeat Kick: power", kickPower)
    elseif headerEnabled and isHeaderSituation() and now - lastHeartbeatKickTime > HEARTBEAT_DEBOUNCE then
        lastHeartbeatKickTime = now
        ball.CanCollide = true
        ball.Massless = false
        ball.AssemblyLinearVelocity = getHeaderDirection() * headerPower
        print("🦅 Heartbeat Header: power", headerPower)
    end
end

-- ============================================================
-- BALL TELEPORT (unchanged)
-- ============================================================
local function teleportBallToPlayer()
    if not ball or not ball.Parent then print("❌ No ball found."); return end
    if not hasNetworkOwnership() then
        WindUI:Notify({ Title = "Ball Teleport", Content = "You don't own the ball!", Duration = 3 })
        return
    end
    local char = LocalPlayer.Character
    if not char or not char.Parent then print("❌ No character."); return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local offset = root.CFrame.LookVector * 3 + Vector3.new(0, 2, 0)
    ball.CFrame = CFrame.new(root.Position + offset)
    print("⚽ Ball teleported!")
end

-- ============================================================
-- AUTO‑AIM RAINBOW (unchanged)
-- ============================================================
local function autoAimRedirect()
    if not autoAimEnabled then return end
    if not ball or not ball.Parent then return end
    local speed = ball.AssemblyLinearVelocity.Magnitude
    if speed < 50 then return end

    local targetGoal = getOpponentGoal()
    if not targetGoal then return end
    local root = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local goalPos = targetGoal.Position + Vector3.new(0, 0.5, 0)
    local direction = (goalPos - root.Position).unit
    ball.AssemblyLinearVelocity = direction * speed
end

-- ============================================================
-- BALL TRACKING & EVENTS (unchanged)
-- ============================================================
local kickConnection, headerConnection, ballAncestryConnection

local function bindBallEvents()
    if kickConnection then kickConnection:Disconnect() end
    if headerConnection then headerConnection:Disconnect() end
    if ballAncestryConnection then ballAncestryConnection:Disconnect() end
    if not ball then return end

    kickConnection = ball.Touched:Connect(onBallTouched)
    headerConnection = ball.Touched:Connect(onHeaderTouch)
    ballAncestryConnection = ball.AncestryChanged:Connect(function(_, parent)
        if parent then bindBallEvents() end
    end)
    print("⚽ Ball touch events bound")
end

local function onBallFound(obj)
    if obj.Name == "Football" and obj:IsA("BasePart") then
        ball = obj
        bindBallEvents()
        if showTrailEnabled then setupBallTrail() end
    end
end
local function onBallLost(obj)
    if obj == ball then
        if kickConnection then kickConnection:Disconnect() end
        if headerConnection then headerConnection:Disconnect() end
        if ballAncestryConnection then ballAncestryConnection:Disconnect() end
        ball = nil
        if ballControlEnabled then stopBallControl() end
        removeBallTrail()
    end
end

workspace.DescendantAdded:Connect(onBallFound)
workspace.DescendantRemoving:Connect(onBallLost)
for _, obj in ipairs(workspace:GetDescendants()) do
    if obj.Name == "Football" and obj:IsA("BasePart") then
        ball = obj
        bindBallEvents()
        break
    end
end

-- ============================================================
-- CHARACTER TRACKING (unchanged)
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function(newChar)
    currentCharacter = newChar
    proximityNearStart = nil
    print("👤 Character updated")
end)

-- ============================================================
-- UI – Tabs (Premium tab for Insane Kick)
-- ============================================================

-- Tab 1: Shot & Aim (free)
local ShotTab = Window:Tab({ Title = "Shot & Aim", Icon = "target" })
ShotTab:Toggle({
    Title = "Enable Shot Multiplier",
    Desc = "Turns on/off the multiplier when Insane Kick is OFF",
    Value = false,
    Callback = function(Value) multiplierEnabled = Value end
})
ShotTab:Slider({
    Title = "Shot Multiplier",
    Step = 0.1,
    Value = { Min = 0.5, Max = 5.0, Default = 1.0 },
    Callback = function(Value) multiplier = Value end
})
ShotTab:Toggle({
    Title = "Auto-Aim (Rainbow)",
    Value = false,
    Callback = function(Value) autoAimEnabled = Value end
})
ShotTab:Paragraph({ Title = "Multiplier only works when toggled on + Insane Kick off", Desc = "Auto-Aim redirects fast balls (speed > 50)", Icon = "info" })

-- Tab 2: OP Headers (free)
local HeaderTab = Window:Tab({ Title = "OP Headers", Icon = "crown" })
HeaderTab:Toggle({
    Title = "Enable OP Headers",
    Value = false,
    Callback = function(Value) headerEnabled = Value end
})
HeaderTab:Slider({
    Title = "Header Power",
    Step = 1,
    Value = { Min = 100, Max = 5000, Default = 1000 },
    Callback = function(Value) headerPower = Value end
})
HeaderTab:Toggle({
    Title = "Always Header (Bicycle Kick)",
    Desc = "Every kick becomes a header with header power",
    Value = false,
    Callback = function(Value) alwaysHeader = Value end
})
HeaderTab:Paragraph({ Title = "Direction respects Auto‑Aim toggle", Desc = "Works with all kicks, touches, and abilities", Icon = "info" })

-- Tab 3: Utility (free)
local UtilityTab = Window:Tab({ Title = "Utility", Icon = "wrench" })
UtilityTab:Button({
    Title = "Teleport Ball to Me",
    Desc = "Only works if you own the ball",
    Callback = function() teleportBallToPlayer() end
})
UtilityTab:Keybind({
    Title = "Ball Teleport (T)",
    Value = "T",
    Callback = function(key) teleportBallToPlayer() end
})
UtilityTab:Paragraph({ Title = "Ball Teleport", Desc = "Requires network ownership – instant teleport", Icon = "alert" })

-- Tab 4: Misc (free)
local MiscTab = Window:Tab({ Title = "Misc", Icon = "settings" })
MiscTab:Toggle({
    Title = "Fast Mode",
    Desc = "Lowers graphics for better performance",
    Value = false,
    Callback = function(Value) fastModeEnabled = Value; applyFastMode() end
})

ballControlToggle = MiscTab:Toggle({
    Title = "Control Ball",
    Desc = "Steer the ball with your mouse (always works)",
    Value = false,
    Callback = function(Value)
        ballControlEnabled = Value
        if Value then startBallControl() else stopBallControl() end
    end
})
MiscTab:Keybind({
    Title = "Toggle Ball Control (R)",
    Value = "R",
    Callback = function(key)
        ballControlEnabled = not ballControlEnabled
        ballControlToggle:Set(ballControlEnabled)
        if ballControlEnabled then startBallControl() else stopBallControl() end
    end
})
MiscTab:Slider({
    Title = "Control Speed",
    Desc = "Ball movement speed when controlling",
    Step = 1,
    Value = { Min = 50, Max = 500, Default = 150 },
    Callback = function(Value) ballControlSpeed = Value; print("⚡ Ball Control Speed set to:", Value) end
})

trailToggle = MiscTab:Toggle({
    Title = "Show Ball Trail",
    Desc = "Red transparent path behind the ball",
    Value = false,
    Callback = function(Value)
        showTrailEnabled = Value
        if Value then
            if ball then setupBallTrail() end
        else
            removeBallTrail()
        end
    end
})

MiscTab:Paragraph({ Title = "Performance & Control", Desc = "Fast Mode: disables shadows, lowers quality. Ball Control: mouse aim with adjustable speed.", Icon = "info" })

-- Tab 5: Goalkeeper (free)
local GKTab = Window:Tab({ Title = "Goalkeeper", Icon = "shield" })

gkToggle = GKTab:Toggle({
    Title = "Auto Goalkeeper",
    Desc = "AI goalie – smooth target, attacker‑aware",
    Value = false,
    Callback = function(Value)
        autoGKEnabled = Value
        startAutoGK()
    end
})

GKTab:Keybind({
    Title = "Toggle Auto GK (G)",
    Value = "G",
    Callback = function(key)
        autoGKEnabled = not autoGKEnabled
        gkToggle:Set(autoGKEnabled)
        startAutoGK()
    end
})

GKTab:Slider({
    Title = "Reaction Range",
    Desc = "Max horizontal distance to react to shots",
    Step = 1,
    Value = { Min = 20, Max = 100, Default = 40 },
    Callback = function(Value) gkReactionRange = Value; print("🛡️ GK Reaction Range:", Value) end
})

predictionToggle = GKTab:Toggle({
    Title = "Show Prediction",
    Desc = "Green sphere + beam where ball will cross goal line",
    Value = false,
    Callback = function(Value)
        showPrediction = Value
        if autoGKEnabled then
            autoGKEnabled = false
            startAutoGK()
            autoGKEnabled = true
            startAutoGK()
        end
    end
})

GKTab:Paragraph({ Title = "Goalkeeper AI v14", Desc = "Smooth target, prediction line, emergency recovery", Icon = "shield" })

-- Tab 6: Premium (Insane Kick)
local PremiumTab = Window:Tab({ Title = "Premium", Icon = "crown" })

local premiumSection = PremiumTab:Section({ Title = "Insane Kick (Premium)" })

kickToggle = premiumSection:Toggle({
    Title = "Enable Insane Kick",
    Desc = "Massive power kicks",
    Value = false,
    Callback = function(Value)
        if not _G.WilkinsIsPremium then
            WindUI:Notify({
                Title = "Locked",
                Content = "Premium feature – enter a valid key to unlock.",
                Duration = 3
            })
            kickToggle:Set(false)
            kickEnabled = false
            return
        end
        kickEnabled = Value
    end
})

kickPowerSlider = premiumSection:Slider({
    Title = "Kick Power",
    Step = 1,
    Value = { Min = 100, Max = 5000, Default = 1000 },
    Callback = function(Value)
        if not _G.WilkinsIsPremium then
            WindUI:Notify({
                Title = "Locked",
                Content = "Premium feature – enter a valid key to unlock.",
                Duration = 3
            })
            -- Revert slider to previous value?
            kickPowerSlider:Set(kickPower)
            return
        end
        kickPower = Value
    end
})

PremiumTab:Keybind({
    Title = "Toggle Insane Kick (B)",
    Value = "B",
    Callback = function(key)
        if not _G.WilkinsIsPremium then
            WindUI:Notify({
                Title = "Locked",
                Content = "Premium feature – enter a valid key to unlock.",
                Duration = 3
            })
            return
        end
        kickEnabled = not kickEnabled
        kickToggle:Set(kickEnabled)
        print("Insane Kick:", kickEnabled and "ON" or "OFF")
    end
})

-- Lock controls if not premium
if not _G.WilkinsIsPremium then
    kickToggle:Lock()
    kickToggle:SetDesc("Premium feature – enter a valid key to unlock")
    kickPowerSlider:Lock()
    kickPowerSlider:SetDesc("Premium feature – enter a valid key to unlock")
else
    kickToggle:Unlock()
    kickPowerSlider:Unlock()
end

-- ============================================================
-- STARTUP
-- ============================================================
hookAllRemotes()
task.spawn(keepHooksAlive)
RunService.Heartbeat:Connect(heartbeatFallback)
RunService.Heartbeat:Connect(autoAimRedirect)

print("⚽ Electron Hub (Blue Lock Rivals) loaded!")
print("  - B: Toggle Insane Kick (premium)")
print("  - T: Teleport ball (ownership check)")
print("  - R: Toggle Ball Control (always works)")
print("  - G: Toggle Auto GK (smooth movement)")
print("  - Show Prediction in GK tab, Trail in Misc")
print("  - Press K to open UI")
