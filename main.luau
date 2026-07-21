--[[
    Flee The Facility (Koala Scripts v4) – WindUI + PandaAuth (Wilkins)
    Premium‑locked features: 3rd Person Beast, Anti PC Error, Sound Spam (4)
    Organized with tab icons and premium 👑 markers.
]]

-- ========== 1. Load WindUI and utilities ==========
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local PU = loadstring(game:HttpGet("https://pastebin.com/raw/xAZ4WQRS"))()
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game.Workspace
local Lighting = game.Lighting
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer

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

            -- Store premium status globally
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
    Title = "Flee The Facility (Electron V1.0.0)",
    Icon = "door-open",
    Author = "Electron - @blackberryfr",
    ToggleKey = Enum.KeyCode.RightAlt,
    Acrylic = false,

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

-- ========== 4. Key accepted – show premium notification & unlock premium features ==========
if _G.WilkinsIsPremium then
    WindUI:Notify({
        Title = "Premium User 👑",
        Content = "Thanks for using Elctron Hub! For concerns @blackberryfr.",
        Duration = 10
    })
end

-- ========== 5. Keep the session alive (heartbeat) ==========
if WilkinsLib then
    task.spawn(function()
        while WilkinsLib.isConnected and WilkinsLib.isConnected() do
            task.wait(5)
        end
        warn("[Wilkins] Session closed.")
    end)
end

-- ========== 6. All exploit features ==========

local Settings = {}
local ConfigFile = "FTF_WindUI_Full.json"

local function SaveSettings()
    pcall(function() writefile(ConfigFile, HttpService:JSONEncode(Settings)) end)
end

local function LoadSettings()
    pcall(function()
        if isfile(ConfigFile) then
            local json = readfile(ConfigFile)
            if json then
                local decoded = HttpService:JSONDecode(json)
                for k, v in pairs(decoded) do Settings[k] = v end
            end
        end
    end)
end
LoadSettings()

local defaults = {
    SpeedHackEnabled = false, SpeedHack = 16,
    InfiniteJump = false,
    JumpHackEnabled = false, JumpHack = 36,
    Noclip = false,
    BeastESP = false, PlayerESP = false, ShowPlrRagTime = false,
    ExitESP = false, PodESP = false, LockerESP = false, VentESP = false,
    PCESP = false, PCProgESP = false, PCProgESPSlideSize = 2,
    SelectedTeleportPlayer = "",
    BeastPowerInfoNotif = false,
    HitboxScale = 1,
    BeastTieRange = 0,
    UnTieMe = false,
    Beast3rdPerson = false,          -- premium
    AntiPCError = false,             -- premium
    FullBright = false,
    RagdollMovement = false,
    AutoHideFromSeer = false, ReturnFromHideSeer = false,
    SpeedHackCrawl = false, HackCrawlWPeople = false,
    HackCrawlType = "Crawl",
    HackCrawlTime = 1/3, HackCrawlDelay = -1,
    AlertModerator = false, KickOnModerator = false,
    HideBeastNear = false, HideBeastNearDist = 35,
    EnableDebuggingPrint = false,
    SlowBeast = false, UnTieAll = false,
    SpamBeastStealth = false,
    PiggyBackToggle = false, SelectedPiggyBack = "",
    STSpamPercentage = 50,
    STSpamSoundServiceCorrectSound = false,   -- premium
    STSpamSoundServiceWarningSound = false,   -- premium
    STSpamSoundServiceSafeSound = false,      -- premium
    STSpamSoundServiceDetectedSound = false,  -- premium
    STSpamSoundServiceSeenSound = false,
    STSpamMapErrorSoundAll = false, STSpamMapErrorSoundOne = false,
    STSpamMapSoundExitsUnlock = false,
    RecordStats = false,
}

for k, v in pairs(defaults) do
    if Settings[k] == nil then Settings[k] = v end
end

-- Force premium settings to false for free users
if not _G.WilkinsIsPremium then
    Settings.Beast3rdPerson = false
    Settings.AntiPCError = false
    Settings.STSpamSoundServiceCorrectSound = false
    Settings.STSpamSoundServiceWarningSound = false
    Settings.STSpamSoundServiceSafeSound = false
    Settings.STSpamSoundServiceDetectedSound = false
    SaveSettings()
end

-- Tabs with icons (no emojis)
local PlrTab = Window:Tab({ Title = "Player", Icon = "user" })
local ESPTab = Window:Tab({ Title = "ESP", Icon = "eye" })
local TeleportTab = Window:Tab({ Title = "Teleport", Icon = "map-pin" })
local BeastTab = Window:Tab({ Title = "Beast", Icon = "dog" })
local MiscTab = Window:Tab({ Title = "Misc", Icon = "settings" })
local TrollTab = Window:Tab({ Title = "Trolling", Icon = "music" })
local StatsTab = Window:Tab({ Title = "Stats", Icon = "bar-chart-2" })

-- ==================== Player Tab ====================
local MovementSection = PlrTab:Section({ Title = "Movement" })
MovementSection:Toggle({ Title = "Enable Speed Hacks", Value = Settings.SpeedHackEnabled, Callback = function(v) Settings.SpeedHackEnabled = v; SaveSettings() end })
MovementSection:Slider({ Title = "Player Speed", Value = { Min = 0, Max = 48, Default = Settings.SpeedHack }, Step = 1, Callback = function(v) Settings.SpeedHack = v; SaveSettings() end })
MovementSection:Toggle({ Title = "Infinite Jump", Value = Settings.InfiniteJump, Callback = function(v) Settings.InfiniteJump = v; SaveSettings() end })
MovementSection:Toggle({ Title = "Enable Jump Power Hacks", Value = Settings.JumpHackEnabled, Callback = function(v) Settings.JumpHackEnabled = v; SaveSettings() end })
MovementSection:Slider({ Title = "Player Jump Power", Value = { Min = 0, Max = 108, Default = Settings.JumpHack }, Step = 1, Callback = function(v) Settings.JumpHack = v; SaveSettings() end })
MovementSection:Toggle({ Title = "Enable Noclip", Value = Settings.Noclip, Callback = function(v) Settings.Noclip = v; PU.NoClip = v; SaveSettings() end })

-- ==================== ESP Tab ====================
ESPTab:Section({ Title = "Beast ESP" }):Toggle({ Title = "Beast ESP", Value = Settings.BeastESP, Callback = function(v) Settings.BeastESP = v; SaveSettings() end })
ESPTab:Section({ Title = "Player ESP" }):Toggle({ Title = "Player ESP", Value = Settings.PlayerESP, Callback = function(v) Settings.PlayerESP = v; SaveSettings() end })
ESPTab:Toggle({ Title = "Show Player Ragdoll Time", Value = Settings.ShowPlrRagTime, Callback = function(v) Settings.ShowPlrRagTime = v; SaveSettings() end })
ESPTab:Section({ Title = "Exit Doors" }):Toggle({ Title = "Exit Doors ESP", Value = Settings.ExitESP, Callback = function(v) Settings.ExitESP = v; SaveSettings() end })
ESPTab:Section({ Title = "Freeze Pods" }):Toggle({ Title = "Freeze Pods ESP", Value = Settings.PodESP, Callback = function(v) Settings.PodESP = v; SaveSettings() end })
ESPTab:Section({ Title = "Lockers" }):Toggle({ Title = "Lockers ESP", Value = Settings.LockerESP, Callback = function(v) Settings.LockerESP = v; SaveSettings() end })
ESPTab:Section({ Title = "Vents" }):Toggle({ Title = "Vents ESP", Value = Settings.VentESP, Callback = function(v) Settings.VentESP = v; SaveSettings() end })
ESPTab:Section({ Title = "Computers" }):Toggle({ Title = "Computer ESP", Value = Settings.PCESP, Callback = function(v) Settings.PCESP = v; SaveSettings() end })
ESPTab:Toggle({ Title = "Show Computer Progress", Value = Settings.PCProgESP, Callback = function(v) Settings.PCProgESP = v; SaveSettings() end })
ESPTab:Slider({ Title = "Progress Size", Value = { Min = 1, Max = 2, Default = Settings.PCProgESPSlideSize }, Step = 1, Callback = function(v) Settings.PCProgESPSlideSize = v; SaveSettings() end })
ESPTab:Button({ Title = "Update All ESPs", Callback = function()
    UpdateLockerESP(); UpdatePodESP(); UpdateExitESP(); UpdatePlrESP(); UpdateBeastESP(); UpdateVentESP()
end })

-- ==================== Teleport Tab ====================
local TPSec = TeleportTab:Section({ Title = "To Player" })
local TPDropdown
local function RecreateTPDropdown()
    local values = {}
    for _, plr in pairs(Players:GetPlayers()) do if plr ~= LocalPlayer then table.insert(values, plr.Name) end end
    if TPDropdown then TPDropdown:Destroy() end
    TPDropdown = TPSec:Dropdown({ Title = "Player", Values = values, Value = Settings.SelectedTeleportPlayer, Callback = function(v) Settings.SelectedTeleportPlayer = v; SaveSettings() end })
end
RecreateTPDropdown()
Players.PlayerAdded:Connect(RecreateTPDropdown)
Players.PlayerRemoving:Connect(RecreateTPDropdown)
TPSec:Button({ Title = "Teleport to Selected", Callback = function()
    local target = Players:FindFirstChild(Settings.SelectedTeleportPlayer)
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character:PivotTo(target.Character:GetPivot())
    end
end })

-- ==================== Beast Tab ====================
BeastTab:Section({ Title = "Beast Abilities" })
BeastTab:Toggle({ Title = "Slow down Beast", Value = Settings.SlowBeast, Callback = function(v) Settings.SlowBeast = v; SaveSettings() end })
BeastTab:Toggle({ Title = "UnTie Everyone", Value = Settings.UnTieAll, Callback = function(v) Settings.UnTieAll = v; SaveSettings() end })
BeastTab:Slider({ Title = "Auto Tie Range", Value = { Min = 0, Max = 30, Default = Settings.BeastTieRange }, Step = 1, Callback = function(v) Settings.BeastTieRange = v; SaveSettings() end })

-- PREMIUM: 3rd Person when Beast
local beast3rdPersonToggle = BeastTab:Toggle({
    Title = "Enable 3rd Person when Beast 👑",
    Value = _G.WilkinsIsPremium and Settings.Beast3rdPerson or false,
    Callback = function(v)
        Settings.Beast3rdPerson = v
        SaveSettings()
    end
})
if _G.WilkinsIsPremium then
    beast3rdPersonToggle:Unlock()   -- explicitly unlock
else
    beast3rdPersonToggle:Lock()
    beast3rdPersonToggle:SetDesc("This is a premium feature")
end

BeastTab:Toggle({ Title = "Spam Beast Stealth (Silent)", Value = Settings.SpamBeastStealth, Callback = function(v) Settings.SpamBeastStealth = v; SaveSettings() end })
BeastTab:Slider({ Title = "Hitbox Scale", Value = { Min = 1, Max = 8, Default = Settings.HitboxScale }, Step = 0.5, Callback = function(v) Settings.HitboxScale = v; SaveSettings() end })
BeastTab:Button({ Title = "Fling Beast", Callback = function()
    if OnFling then return end
    OnFling = true
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr:FindFirstChild("TempPlayerStatsModule") and plr.TempPlayerStatsModule:WaitForChild("IsBeast").Value == true and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local s, r = pcall(function() return PU:FlingPlayer(plr) end)
            if r == "PlayerNotReady" then WindUI:Notify({ Title = "Cannot Fling Now", Content = "Player not ready" })
            elseif r == "Timedout" then WindUI:Notify({ Title = "Fling Possibly Failed", Content = "Timed out" }) end
            if not s then WindUI:Notify({ Title = "Internal Error", Content = "Fling system error" }) end
            OnFling = false; return
        end
    end
    OnFling = false
end })

-- ==================== Misc Tab ====================
MiscTab:Section({ Title = "Information" }):Toggle({ Title = "Notify beast power", Value = Settings.BeastPowerInfoNotif, Callback = function(v) Settings.BeastPowerInfoNotif = v; SaveSettings() end })

MiscTab:Section({ Title = "Self / Others" })
MiscTab:Toggle({ Title = "Auto Remove Rope (Myself)", Value = Settings.UnTieMe, Callback = function(v) Settings.UnTieMe = v; SaveSettings() end })

-- PREMIUM: Anti PC Error
local antiPCErrorToggle = MiscTab:Toggle({
    Title = "Anti PC Error 👑",
    Value = _G.WilkinsIsPremium and Settings.AntiPCError or false,
    Callback = function(v)
        Settings.AntiPCError = v
        SaveSettings()
    end
})
if _G.WilkinsIsPremium then
    antiPCErrorToggle:Unlock()
else
    antiPCErrorToggle:Lock()
    antiPCErrorToggle:SetDesc("This is a premium feature")
end

MiscTab:Toggle({ Title = "Full Bright", Value = Settings.FullBright, Callback = function(v) Settings.FullBright = v; SaveSettings() end })
MiscTab:Toggle({ Title = "Disable Ragdoll (Buggy)", Value = Settings.RagdollMovement, Callback = function(v) Settings.RagdollMovement = v; SaveSettings() end })

MiscTab:Section({ Title = "Hide on Seer Ability" }):Toggle({ Title = "Auto Hide From Seer", Value = Settings.AutoHideFromSeer, Callback = function(v) Settings.AutoHideFromSeer = v; SaveSettings() end })
MiscTab:Toggle({ Title = "Return after Hiding", Value = Settings.ReturnFromHideSeer, Callback = function(v) Settings.ReturnFromHideSeer = v; SaveSettings() end })

MiscTab:Section({ Title = "Speed up Hacking" }):Toggle({ Title = "Speed Hack (Crawl/Jump/Air)", Value = Settings.SpeedHackCrawl, Callback = function(v) Settings.SpeedHackCrawl = v; SaveSettings() end })
MiscTab:Toggle({ Title = "Speed Hack with People", Value = Settings.HackCrawlWPeople, Callback = function(v) Settings.HackCrawlWPeople = v; SaveSettings() end })
MiscTab:Dropdown({ Title = "Hack Type", Values = { "Crawl", "Jump", "Air" }, Value = Settings.HackCrawlType, Callback = function(v) Settings.HackCrawlType = v; SaveSettings() end })
MiscTab:Slider({ Title = "Hack Crawl Time", Value = { Min = -1, Max = 5, Default = Settings.HackCrawlTime }, Step = 0.05, Callback = function(v) Settings.HackCrawlTime = v; SaveSettings() end })
MiscTab:Slider({ Title = "Delay between hacks", Value = { Min = -1, Max = 10, Default = Settings.HackCrawlDelay }, Step = 0.1, Callback = function(v) Settings.HackCrawlDelay = v; SaveSettings() end })

MiscTab:Section({ Title = "Moderator Alert" }):Toggle({ Title = "Alert on Mod Join", Value = Settings.AlertModerator, Callback = function(v) Settings.AlertModerator = v; SaveSettings() end })
MiscTab:Toggle({ Title = "Kick on Mod Join", Value = Settings.KickOnModerator, Callback = function(v) Settings.KickOnModerator = v; SaveSettings() end })

MiscTab:Section({ Title = "Beast Near Hiding" }):Toggle({ Title = "Hide when beast near", Value = Settings.HideBeastNear, Callback = function(v) Settings.HideBeastNear = v; SaveSettings() end })
MiscTab:Slider({ Title = "Distance to hide", Value = { Min = 25, Max = 100, Default = Settings.HideBeastNearDist }, Step = 1, Callback = function(v) Settings.HideBeastNearDist = v; SaveSettings() end })

MiscTab:Section({ Title = "Debugging" }):Toggle({ Title = "Enable Debug Print", Value = Settings.EnableDebuggingPrint, Callback = function(v) Settings.EnableDebuggingPrint = v; SaveSettings() end })

-- ==================== Troll Tab ====================
local PiggySec = TrollTab:Section({ Title = "Piggyback" })
local PiggyDropdown
local function RecreatePiggyDropdown()
    local values = {}
    for _, plr in pairs(Players:GetPlayers()) do if plr ~= LocalPlayer then table.insert(values, plr.Name) end end
    if PiggyDropdown then PiggyDropdown:Destroy() end
    PiggyDropdown = PiggySec:Dropdown({ Title = "Player", Values = values, Value = Settings.SelectedPiggyBack, Callback = function(v) Settings.SelectedPiggyBack = v; SaveSettings() end })
end
RecreatePiggyDropdown()
Players.PlayerAdded:Connect(RecreatePiggyDropdown)
Players.PlayerRemoving:Connect(RecreatePiggyDropdown)
PiggySec:Toggle({ Title = "Enable Piggyback", Value = Settings.PiggyBackToggle, Callback = function(v)
    Settings.PiggyBackToggle = v; SaveSettings()
    if v then PU.PiggyBack = Players:FindFirstChild(Settings.SelectedPiggyBack) else PU.PiggyBack = nil end
end })

local PlaySoundSec = TrollTab:Section({ Title = "Sound Trolling (Play)" })
PlaySoundSec:Button({ Title = "Play CorrectSound", Callback = function() SoundService.CorrectSound:Play() end })
PlaySoundSec:Button({ Title = "Play WarningSound", Callback = function() SoundService.WarningSound:Play() end })
PlaySoundSec:Button({ Title = "Play SafeSound", Callback = function() SoundService.SafeSound:Play() end })
PlaySoundSec:Button({ Title = "Play DetectedSound", Callback = function() SoundService.DetectedSound:Play() end })
PlaySoundSec:Button({ Title = "Play SeenSound", Callback = function() SoundService.SeenSound:Play() end })
PlaySoundSec:Button({ Title = "Play Map ErrorSound (All)", Callback = function() STFPMapErrorSound(false) end })
PlaySoundSec:Button({ Title = "Play Map ErrorSound (One)", Callback = function() STFPMapErrorSound(true) end })
PlaySoundSec:Button({ Title = "Play Map SoundExitsUnlock", Callback = function()
    local success = false
    for i = 1, 5 do
        local map = ReplicatedStorage.CurrentMap.Value
        if map then
            local siren = map:FindFirstChild("FacilitySiren")
            if siren then
                local sound = siren:FindFirstChild("SoundExitsUnlock")
                if sound then
                    sound:Play()
                    success = true
                    break
                end
            end
        end
        task.wait(0.5)
    end
    if not success then
        WindUI:Notify({ Title = "Error", Content = "Could not find SoundExitsUnlock" })
    end
end })

local SpamSoundSec = TrollTab:Section({ Title = "Sound Trolling (Spam)" })
SpamSoundSec:Slider({ Title = "Spam Percentage", Value = { Min = 0, Max = 100, Default = Settings.STSpamPercentage }, Step = 1, Callback = function(v) Settings.STSpamPercentage = v; SaveSettings() end })

-- Premium spam toggles
local correctSpamToggle = SpamSoundSec:Toggle({
    Title = "Spam CorrectSound 👑",
    Value = _G.WilkinsIsPremium and Settings.STSpamSoundServiceCorrectSound or false,
    Callback = function(v)
        Settings.STSpamSoundServiceCorrectSound = v
        SaveSettings()
    end
})
if _G.WilkinsIsPremium then
    correctSpamToggle:Unlock()
else
    correctSpamToggle:Lock()
    correctSpamToggle:SetDesc("This is a premium feature")
end

local warnSpamToggle = SpamSoundSec:Toggle({
    Title = "Spam WarningSound 👑",
    Value = _G.WilkinsIsPremium and Settings.STSpamSoundServiceWarningSound or false,
    Callback = function(v)
        Settings.STSpamSoundServiceWarningSound = v
        SaveSettings()
    end
})
if _G.WilkinsIsPremium then
    warnSpamToggle:Unlock()
else
    warnSpamToggle:Lock()
    warnSpamToggle:SetDesc("This is a premium feature")
end

local safeSpamToggle = SpamSoundSec:Toggle({
    Title = "Spam SafeSound 👑",
    Value = _G.WilkinsIsPremium and Settings.STSpamSoundServiceSafeSound or false,
    Callback = function(v)
        Settings.STSpamSoundServiceSafeSound = v
        SaveSettings()
    end
})
if _G.WilkinsIsPremium then
    safeSpamToggle:Unlock()
else
    safeSpamToggle:Lock()
    safeSpamToggle:SetDesc("This is a premium feature")
end

local detectedSpamToggle = SpamSoundSec:Toggle({
    Title = "Spam DetectedSound 👑",
    Value = _G.WilkinsIsPremium and Settings.STSpamSoundServiceDetectedSound or false,
    Callback = function(v)
        Settings.STSpamSoundServiceDetectedSound = v
        SaveSettings()
    end
})
if _G.WilkinsIsPremium then
    detectedSpamToggle:Unlock()
else
    detectedSpamToggle:Lock()
    detectedSpamToggle:SetDesc("This is a premium feature")
end

-- Non‑premium spams (free)
SpamSoundSec:Toggle({ Title = "Spam SeenSound", Value = Settings.STSpamSoundServiceSeenSound, Callback = function(v) Settings.STSpamSoundServiceSeenSound = v; SaveSettings() end })
SpamSoundSec:Toggle({ Title = "Spam Map ErrorSound (All)", Value = Settings.STSpamMapErrorSoundAll, Callback = function(v) Settings.STSpamMapErrorSoundAll = v; SaveSettings() end })
SpamSoundSec:Toggle({ Title = "Spam Map ErrorSound (One)", Value = Settings.STSpamMapErrorSoundOne, Callback = function(v) Settings.STSpamMapErrorSoundOne = v; SaveSettings() end })
SpamSoundSec:Toggle({ Title = "Spam Map SoundExitsUnlock", Value = Settings.STSpamMapSoundExitsUnlock, Callback = function(v) Settings.STSpamMapSoundExitsUnlock = v; SaveSettings() end })

-- ==================== Stats Tab ====================
local StatsConfig = { Recording = false, StartMoney = 0, StartXP = 0, Elapsed = 0 }
local MoneyBtn, XPBtn, MoneyHourBtn, XPHourBtn, RecordElapsedBtn
do
    local RecSec = StatsTab:Section({ Title = "Recording" })
    local RecordButton = RecSec:Button({ Title = "Start Recording", Callback = function()
        if not StatsConfig.Recording then
            RecordButton:SetTitle("Stop Recording")
            StatsConfig.Elapsed = 0
            local mod = LocalPlayer:FindFirstChild("SavedPlayerStatsModule")
            if mod then
                StatsConfig.StartXP = mod:FindFirstChild("Xp") and mod.Xp.Value or 0
                StatsConfig.StartMoney = mod:FindFirstChild("Credits") and mod.Credits.Value or 0
            end
            StatsConfig.Recording = true
        else
            RecordButton:SetTitle("Start Recording")
            StatsConfig.Recording = false
        end
    end })
    RecordElapsedBtn = RecSec:Button({ Title = "0:00:00", Locked = true, Callback = function() end })
    local EarnSec = StatsTab:Section({ Title = "Total Earning" })
    MoneyBtn = EarnSec:Button({ Title = "Total Credits: 0C", Locked = true, Callback = function() end })
    XPBtn = EarnSec:Button({ Title = "Total XP: 0XP", Locked = true, Callback = function() end })
    local PerHourSec = StatsTab:Section({ Title = "Per Hour" })
    MoneyHourBtn = PerHourSec:Button({ Title = "Credits per Hour: 0C/h", Locked = true, Callback = function() end })
    XPHourBtn = PerHourSec:Button({ Title = "XP per Hour: 0XP/h", Locked = true, Callback = function() end })
end

-- ==================== Core Variables & Functions ====================
local TempPlayerStatsModule = nil
local Beast = nil
local bnhide = false
local clpos = false
local lpos = nil
local bnhideelapse = 0
local noelepse = 0
local HadNotifiedMod = false
local HadSeerHide = false
local LastSeerHidePos = nil
local OnFling = false

local BeastHighlights = {}
local PlrHighlights = {}
local ExitDoorHighlights = {}
local PodHighlights = {}
local LockerHighlights = {}
local VentHighlights = {}
local PCHighlights = {}
local PlrRagTimeBillboards = {}

function IsThereChar(APlr)
    local plr = APlr or LocalPlayer
    return plr.Character and plr.Character:FindFirstChild("Humanoid")
end

function TPPlayerSpawn()
    if IsThereChar() then
        LocalPlayer.Character:PivotTo(Workspace.LobbySpawnPad.CFrame * CFrame.new(0, 3, 0))
    end
end

function UpdateBeastESP()
    for i = #BeastHighlights, 1, -1 do
        local v = BeastHighlights[i]
        if not v or not v.Adornee then if v then v:Destroy() end; table.remove(BeastHighlights, i) end
    end
    if Settings.BeastESP then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr.Character and plr.Character:FindFirstChild("BeastPowers") and plr ~= LocalPlayer and not plr.Character:FindFirstChild("KHHighlight") then
                local h = Instance.new("Highlight")
                h.Name = "KHHighlight"; h.Adornee = plr.Character; h.Parent = plr.Character
                h.FillColor = Color3.fromRGB(200, 50, 50); h.OutlineColor = Color3.fromRGB(255, 50, 50)
                table.insert(BeastHighlights, h)
            end
        end
    else
        for _, v in pairs(BeastHighlights) do v:Destroy() end
        BeastHighlights = {}
    end
end

function UpdatePlrESP()
    for i = #PlrHighlights, 1, -1 do
        local v = PlrHighlights[i]
        if not v or not v.Adornee then if v then v:Destroy() end; table.remove(PlrHighlights, i) end
    end
    if Settings.PlayerESP then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr.Character and not plr.Character:FindFirstChild("BeastPowers") and plr ~= LocalPlayer and not plr.Character:FindFirstChild("KHHighlight") then
                local h = Instance.new("Highlight")
                h.Name = "KHHighlight"; h.Adornee = plr.Character; h.Parent = plr.Character
                h.FillColor = Color3.fromRGB(0, 230, 0); h.OutlineColor = Color3.fromRGB(0, 255, 0)
                table.insert(PlrHighlights, h)
            end
        end
    else
        for _, v in pairs(PlrHighlights) do v:Destroy() end
        PlrHighlights = {}
    end
end

function UpdateShowPlrRagTime()
    local function PlrDown(v)
        return v:FindFirstChild("TempPlayerStatsModule") and v.TempPlayerStatsModule:FindFirstChild("Ragdoll") and v.TempPlayerStatsModule.Ragdoll.Value
    end
    if Settings.ShowPlrRagTime then
        for _, plr in pairs(Players:GetPlayers()) do
            if IsThereChar(plr) and PlrDown(plr) and not PlrRagTimeBillboards[plr] then
                local bg = Instance.new("BillboardGui")
                bg.AlwaysOnTop = true; bg.ExtentsOffsetWorldSpace = Vector3.new(0, 1.25, 0)
                bg.Size = UDim2.new(0, 200, 0, 50); bg.Parent = plr.Character
                local tl = Instance.new("TextLabel")
                tl.BackgroundTransparency = 1; tl.TextStrokeTransparency = 0; tl.TextColor3 = Color3.new(1,1,1)
                tl.TextScaled = true; tl.Size = UDim2.new(1,0,1,0); tl.RichText = true; tl.Parent = bg
                PlrRagTimeBillboards[plr] = bg
            end
        end
    end
    for plr, bb in pairs(PlrRagTimeBillboards) do
        if not bb or not bb.Parent or not plr.Parent or not PlrDown(plr) or not IsThereChar(plr) or not Settings.ShowPlrRagTime then
            if bb then bb:Destroy() end
            PlrRagTimeBillboards[plr] = nil
        else
            bb.TextLabel.Text = plr.Name .. " | Downed " .. tostring(math.floor(plr.TempPlayerStatsModule.ActionProgress.Value * 100)) .. "%"
        end
    end
end

function UpdateExitESP()
    for i = #ExitDoorHighlights, 1, -1 do
        local v = ExitDoorHighlights[i]
        if not v or not v.Adornee then if v then v:Destroy() end; table.remove(ExitDoorHighlights, i) end
    end
    local CurrentMap = ReplicatedStorage.CurrentMap.Value
    if Settings.ExitESP and CurrentMap then
        for _, v in pairs(CurrentMap:GetChildren()) do
            if v.Name == "ExitDoor" and not v:FindFirstChild("KHHighlight") then
                local h = Instance.new("Highlight")
                h.Name = "KHHighlight"; h.Adornee = v; h.Parent = v
                h.FillColor = Color3.fromRGB(220, 220, 50); h.OutlineColor = Color3.fromRGB(255, 255, 100)
                table.insert(ExitDoorHighlights, h)
            end
        end
    end
end

function UpdatePodESP()
    for i = #PodHighlights, 1, -1 do
        local v = PodHighlights[i]
        if not v or not v.Adornee then if v then v:Destroy() end; table.remove(PodHighlights, i) end
    end
    local CurrentMap = ReplicatedStorage.CurrentMap.Value
    if Settings.PodESP and CurrentMap then
        for _, v in pairs(CurrentMap:GetChildren()) do
            if v.Name == "FreezePod" and not v:FindFirstChild("KHHighlight") then
                local h = Instance.new("Highlight")
                h.Name = "KHHighlight"; h.Adornee = v; h.Parent = v
                h.FillColor = Color3.fromRGB(0, 150, 255); h.OutlineColor = Color3.fromRGB(0, 170, 255)
                table.insert(PodHighlights, h)
            end
        end
    end
end

function UpdateLockerESP()
    for i = #LockerHighlights, 1, -1 do
        local v = LockerHighlights[i]
        if not v or not v.Adornee then if v then v:Destroy() end; table.remove(LockerHighlights, i) end
    end
    if Settings.LockerESP then
        for _, v in pairs(CollectionService:GetTagged("LOCKER")) do
            if not v:FindFirstChild("KHHighlight") then
                local h = Instance.new("Highlight")
                h.Name = "KHHighlight"; h.Adornee = v; h.Parent = v
                h.FillColor = Color3.fromRGB(210, 210, 0); h.FillTransparency = 0.75
                h.OutlineColor = Color3.fromRGB(230, 230, 0); h.OutlineTransparency = 0.25
                table.insert(LockerHighlights, h)
            end
        end
    end
end

function UpdateVentESP()
    for i = #VentHighlights, 1, -1 do
        local v = VentHighlights[i]
        for _, c in pairs(v:GetChildren()) do if c:IsA("SurfaceGui") and c.Name == "KHHighlight" then c:Destroy() end end
        table.remove(VentHighlights, i)
    end
    if Settings.VentESP and ReplicatedStorage.CurrentMap.Value then
        for _, v in pairs(ReplicatedStorage.CurrentMap.Value:GetDescendants()) do
            if v:IsA("BasePart") and string.find(string.lower(v.Name), "ventblock") and not v:FindFirstChild("KHHighlight") then
                local function NewSUI(Face)
                    local sg = Instance.new("SurfaceGui")
                    sg.Name = "KHHighlight"; sg.Adornee = v; sg.AlwaysOnTop = true; sg.Face = Face; sg.Parent = v
                    local fr = Instance.new("Frame")
                    fr.BackgroundColor3 = Color3.fromRGB(255, 255, 200); fr.Transparency = 0.6; fr.Size = UDim2.new(1,0,1,0); fr.Parent = sg
                end
                for _, face in pairs({Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom}) do
                    NewSUI(face)
                end
                table.insert(VentHighlights, v)
            end
        end
    end
end

function STFPMapErrorSound(Single)
    local map = ReplicatedStorage.CurrentMap.Value
    if not map then return end
    if Single then
        local v = map:FindFirstChild("ComputerTable")
        if v and v:FindFirstChild("Screen") and v.Screen:FindFirstChild("ErrorSound") then
            v.Screen.ErrorSound:Play()
        end
    else
        for _, v in pairs(map:GetChildren()) do
            if v.Name == "ComputerTable" and v:FindFirstChild("Screen") and v.Screen:FindFirstChild("ErrorSound") then
                v.Screen.ErrorSound:Play()
            end
        end
    end
end

function STFPMapSoundExitsUnlock()
    local map = ReplicatedStorage.CurrentMap.Value
    if map and map:FindFirstChild("FacilitySiren") and map.FacilitySiren:FindFirstChild("SoundExitsUnlock") then
        map.FacilitySiren.SoundExitsUnlock:Play()
    end
end

-- Sound spam coroutine (only runs toggles that are enabled)
coroutine.wrap(function()
    local MapSoundTimes = { ErrorSound = 0.967 }
    local DTs = {
        SScorrectsound = 0, SSwarnsound = 0, SSsafesound = 0, SSdetsound = 0, SSseesound = 0,
        SpamErrorSoundAllDT = 0, SpamErrorSoundOneDT = 0, SpamExitsUnlockDT = 0
    }
    while true do
        local dt = task.wait()
        local mul = Settings.STSpamPercentage / 100
        for k, _ in pairs(DTs) do DTs[k] = DTs[k] + dt end
        if Settings.STSpamSoundServiceCorrectSound and DTs.SScorrectsound > SoundService.CorrectSound.TimeLength * mul then
            DTs.SScorrectsound = 0; SoundService.CorrectSound:Play()
        end
        if Settings.STSpamSoundServiceWarningSound and DTs.SSwarnsound > SoundService.WarningSound.TimeLength * mul then
            DTs.SSwarnsound = 0; SoundService.WarningSound:Play()
        end
        if Settings.STSpamSoundServiceSafeSound and DTs.SSsafesound > SoundService.SafeSound.TimeLength * mul then
            DTs.SSsafesound = 0; SoundService.SafeSound:Play()
        end
        if Settings.STSpamSoundServiceDetectedSound and DTs.SSdetsound > SoundService.DetectedSound.TimeLength * mul then
            DTs.SSdetsound = 0; SoundService.DetectedSound:Play()
        end
        if Settings.STSpamSoundServiceSeenSound and DTs.SSseesound > SoundService.SeenSound.TimeLength * mul then
            DTs.SSseesound = 0; SoundService.SeenSound:Play()
        end
        if Settings.STSpamMapErrorSoundOne and DTs.SpamErrorSoundOneDT >= (MapSoundTimes.ErrorSound * mul) then
            DTs.SpamErrorSoundOneDT = 0; STFPMapErrorSound(true)
        end
        if Settings.STSpamMapErrorSoundAll and DTs.SpamErrorSoundAllDT >= (MapSoundTimes.ErrorSound * mul) then
            DTs.SpamErrorSoundAllDT = 0; STFPMapErrorSound(false)
        end
        if Settings.STSpamMapSoundExitsUnlock then
            local map = ReplicatedStorage.CurrentMap.Value
            if map and map:FindFirstChild("FacilitySiren") and map.FacilitySiren:FindFirstChild("SoundExitsUnlock") then
                local sound = map.FacilitySiren.SoundExitsUnlock
                if DTs.SpamExitsUnlockDT >= (sound.TimeLength * mul) then
                    DTs.SpamExitsUnlockDT = 0; sound:Play()
                end
            end
        end
    end
end)()

-- ==================== Main Tick Loop ====================
local Comp = 0
coroutine.wrap(function()
    while true do
        local dt = task.wait()
        pcall(function()
            -- Stats recording
            if StatsConfig.Recording then
                StatsConfig.Elapsed = StatsConfig.Elapsed + dt
                local curXP, curMoney
                local mod = LocalPlayer:FindFirstChild("SavedPlayerStatsModule")
                if mod then
                    curXP = mod:FindFirstChild("Xp") and mod.Xp.Value
                    curMoney = mod:FindFirstChild("Credits") and mod.Credits.Value
                end
                if curXP and curMoney then
                    local totalMoney = curMoney - StatsConfig.StartMoney
                    local totalXP = curXP - StatsConfig.StartXP
                    local hours = StatsConfig.Elapsed / 3600
                    MoneyBtn:SetTitle("Total Credits: " .. totalMoney .. "C")
                    XPBtn:SetTitle("Total XP: " .. totalXP .. "XP")
                    MoneyHourBtn:SetTitle("Credits per Hour: " .. math.ceil(totalMoney / hours) .. "C/h")
                    XPHourBtn:SetTitle("XP per Hour: " .. math.ceil(totalXP / hours) .. "XP/h")
                    local t = math.floor(StatsConfig.Elapsed)
                    local h = math.floor(t/3600); local m = math.floor((t%3600)/60); local s = t%60
                    RecordElapsedBtn:SetTitle(string.format("%d:%02d:%02d", h, m, s))
                end
            end

            if IsThereChar() then
                TempPlayerStatsModule = LocalPlayer:FindFirstChild("TempPlayerStatsModule")
                if TempPlayerStatsModule then
                    if TempPlayerStatsModule.Ragdoll.Value and Settings.RagdollMovement then
                        TempPlayerStatsModule.Ragdoll.Value = false
                    end
                    -- Premium 3rd person (already guarded by setting)
                    if TempPlayerStatsModule.IsBeast.Value and Settings.Beast3rdPerson then
                        LocalPlayer.CameraMinZoomDistance = 0.5
                        LocalPlayer.CameraMode = Enum.CameraMode.Classic
                    end
                end
                if Settings.SpeedHackEnabled then
                    LocalPlayer.Character.Humanoid.WalkSpeed = Settings.SpeedHack
                end
                if Settings.JumpHackEnabled then
                    LocalPlayer.Character.Humanoid.JumpPower = Settings.JumpHack
                end
                if Settings.FullBright and not LocalPlayer.Character.HumanoidRootPart:FindFirstChild("KH_FullBright") then
                    local l = Instance.new("PointLight")
                    l.Name = "KH_FullBright"; l.Range = math.huge; l.Brightness = 2.5; l.Parent = LocalPlayer.Character.HumanoidRootPart
                    Lighting.GlobalShadows = false
                elseif not Settings.FullBright and LocalPlayer.Character.HumanoidRootPart:FindFirstChild("KH_FullBright") then
                    LocalPlayer.Character.HumanoidRootPart.KH_FullBright:Destroy()
                    Lighting.GlobalShadows = true
                end
            end

            -- Premium Anti PC Error
            if Settings.AntiPCError then
                ReplicatedStorage.RemoteEvent:FireServer("SetPlayerMinigameResult", true)
            end

            -- Beast trolling actions
            if Settings.SlowBeast or Settings.UnTieAll or Settings.UnTieMe or Settings.BeastTieRange > 0 or Settings.SpamBeastStealth then
                for _, plr in pairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr:FindFirstChild("TempPlayerStatsModule") and plr.TempPlayerStatsModule.IsBeast.Value and IsThereChar(plr) then
                        local char = plr.Character
                        local hammer = char:FindFirstChild("Hammer")
                        local beastPowers = char:FindFirstChild("BeastPowers")
                        if hammer and hammer:FindFirstChild("HammerEvent") then
                            if Settings.UnTieAll then hammer.HammerEvent:FireServer("HammerClick", true) end
                            if Settings.UnTieMe and IsThereChar() then
                                for _, v in pairs(char:GetDescendants()) do
                                    if v:IsA("RopeConstraint") and ((v.Attachment0 and v.Attachment0:IsDescendantOf(LocalPlayer.Character)) or (v.Attachment1 and v.Attachment1:IsDescendantOf(LocalPlayer.Character))) then
                                        hammer.HammerEvent:FireServer("HammerClick", true)
                                    end
                                end
                            end
                            if Settings.BeastTieRange > 0 and TempPlayerStatsModule and TempPlayerStatsModule.IsBeast.Value and char == LocalPlayer.Character then
                                for _, target in pairs(Players:GetPlayers()) do
                                    if target ~= LocalPlayer and target:FindFirstChild("TempPlayerStatsModule") and target.TempPlayerStatsModule:FindFirstChild("Ragdoll") and target.TempPlayerStatsModule.Ragdoll.Value and IsThereChar(target) then
                                        local dist = (LocalPlayer.Character.HumanoidRootPart.Position - target.Character.HumanoidRootPart.Position).Magnitude
                                        if dist <= Settings.BeastTieRange then
                                            hammer.HammerEvent:FireServer("HammerTieUp", target.Character.Torso, target.Character.Torso.Position)
                                        end
                                    end
                                end
                            end
                        end
                        if Settings.SlowBeast and beastPowers and beastPowers:FindFirstChild("PowersEvent") then
                            beastPowers.PowersEvent:FireServer("Jumped")
                        end
                        if Settings.SpamBeastStealth and beastPowers and beastPowers:FindFirstChild("PowersEvent") then
                            beastPowers.PowersEvent:FireServer("Sleuth")
                        end
                    end
                end
            end

            -- Moderator detection
            if (Settings.AlertModerator or Settings.KickOnModerator) and not HadNotifiedMod then
                local hasMod = false
                if LocalPlayer.PlayerGui:FindFirstChild("ScreenGui") and LocalPlayer.PlayerGui.ScreenGui:FindFirstChild("PlayerNamesFrame") then
                    for _, child in pairs(LocalPlayer.PlayerGui.ScreenGui.PlayerNamesFrame:GetChildren()) do
                        if child:FindFirstChild("IconLabel") and child.IconLabel.Image ~= "" and child.IconLabel.Image ~= "rbxassetid://1188562340" then
                            hasMod = true
                            break
                        end
                    end
                end
                if hasMod then
                    if Settings.KickOnModerator then
                        LocalPlayer:Kick("A Moderator has joined, leaving for safety.")
                    elseif Settings.AlertModerator then
                        WindUI:Notify({ Title = "Warning! Moderator Joined", Content = "Disable hacks or leave immediately." })
                    end
                    HadNotifiedMod = true
                end
            end

            if Settings.HideBeastNear and IsThereChar() and Beast and IsThereChar(Beast) and TempPlayerStatsModule and not TempPlayerStatsModule.IsBeast.Value and Beast ~= LocalPlayer then
                local dist = (Beast.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if (dist < Settings.HideBeastNearDist or TempPlayerStatsModule.Ragdoll.Value or bnhide) then
                    LocalPlayer.Character:PivotTo(Beast.Character:GetPivot() * CFrame.new(0, 25 + Settings.HideBeastNearDist, 0))
                    bnhide = true
                elseif not bnhide and not clpos then
                    lpos = LocalPlayer.Character:GetPivot()
                end
                if bnhide and lpos and (Beast.Character.HumanoidRootPart.Position - lpos.Position).Magnitude > Settings.HideBeastNearDist + 10 and not TempPlayerStatsModule.Ragdoll.Value then
                    LocalPlayer.Character:PivotTo(lpos)
                    bnhide = false
                end
            end

            if bnhide then
                bnhideelapse += dt; noelepse = 0
            else
                noelepse += dt
                if noelepse > 5 then bnhideelapse = 0 end
            end

            if IsThereChar() and LocalPlayer.Character.HumanoidRootPart.Position.Y < -3000 then TPPlayerSpawn() end

            local gui = LocalPlayer.PlayerGui:FindFirstChild("ScreenGui")
            if gui and gui:FindFirstChild("WarningFrame") and gui.WarningFrame.Visible and IsThereChar() then
                if Settings.AutoHideFromSeer and TempPlayerStatsModule and TempPlayerStatsModule.Health.Value > 0 and not TempPlayerStatsModule.IsBeast.Value and not HadSeerHide then
                    HadSeerHide = true
                    if not LastSeerHidePos then LastSeerHidePos = LocalPlayer.Character.HumanoidRootPart.CFrame; task.wait(1/4) end
                    local closestLocker
                    local closestDist = math.huge
                    for _, v in pairs(CollectionService:GetTagged("LOCKER")) do
                        if v:IsA("Model") then
                            local d = (v:GetPivot().Position - LocalPlayer.Character:GetPivot().Position).Magnitude
                            if d < closestDist then closestLocker = v; closestDist = d end
                        end
                    end
                    if closestLocker then LocalPlayer.Character:PivotTo(closestLocker:GetPivot()) end
                end
            elseif LastSeerHidePos and IsThereChar() then
                local elapsed = 0
                local ready = false
                repeat
                    elapsed += task.wait()
                    ready = true
                    if gui and gui:FindFirstChild("DetectedFrame") then
                        for _, child in pairs(gui.DetectedFrame:GetChildren()) do
                            if child:IsA("Frame") and child.Visible then ready = false; break end
                        end
                    end
                until ready or elapsed >= 3
                HadSeerHide = false
                if Settings.ReturnFromHideSeer then
                    task.wait(1/4)
                    LocalPlayer.Character:PivotTo(LastSeerHidePos)
                end
                LastSeerHidePos = nil
            end

            UpdateShowPlrRagTime()

            local GotComputers = 0
            if ReplicatedStorage.CurrentMap.Value then
                for _, v in pairs(ReplicatedStorage.CurrentMap.Value:GetChildren()) do if v.Name == "ComputerTable" then GotComputers += 1 end end
            end
            if GotComputers ~= Comp then
                Comp = GotComputers
                if GotComputers == 0 then
                    task.wait(1)
                    UpdateVentESP(); UpdateLockerESP(); UpdatePodESP(); UpdateExitESP(); UpdatePlrESP(); UpdateBeastESP()
                    Beast = nil
                else
                    task.wait(3)
                    UpdateVentESP(); UpdateLockerESP(); UpdatePodESP(); UpdateExitESP(); UpdatePlrESP()
                    repeat task.wait() until ReplicatedStorage.IsGameActive.Value
                    task.wait(3)
                    UpdateVentESP(); UpdateLockerESP(); UpdatePodESP(); UpdateExitESP(); UpdatePlrESP(); UpdateBeastESP()
                    if Settings.BeastPowerInfoNotif then
                        local power = ReplicatedStorage:FindFirstChild("CurrentPower") and ReplicatedStorage.CurrentPower.Value or "?"
                        WindUI:Notify({ Title = "Beast Power", Content = "Beast Power: " .. power })
                    end
                    Beast = nil
                    for _, plr in pairs(Players:GetPlayers()) do
                        if plr:FindFirstChild("TempPlayerStatsModule") and plr.TempPlayerStatsModule.IsBeast.Value then Beast = plr end
                    end
                end
            end
        end)
    end
end)()

-- Auto AFK
coroutine.wrap(function()
    while task.wait(60) do
        if Settings.AntiAFK then
            VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
        end
    end
end)()

-- Hotkey Ctrl+2
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Two and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        Settings.SpeedHackCrawl = not Settings.SpeedHackCrawl
        SaveSettings()
        WindUI:Notify({ Title = "Hotkey (Ctrl+2)", Content = "Speed Hack " .. (Settings.SpeedHackCrawl and "enabled" or "disabled") })
    end
end)

-- Initialize ESPs
UpdateBeastESP(); UpdatePlrESP(); UpdateExitESP(); UpdatePodESP(); UpdateLockerESP(); UpdateVentESP()
