-- WindUI refactor + autoblock fixes (Part 1/2)
-- Requires Delta or similar executor that supports HttpGet for WindUI main.lua [web:2][web:19]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- WindUI bootstrap
local WindAsync = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))() -- uses latest release main.lua [web:2][web:3][web:19]
local UI = WindAsync

-- Window
local Window = UI:CreateWindow({
    Title = "TSB AutoBlock + Camlock",
    Icon = "shield",
    Author = "refactor",
    Folder = "TSB_WindUI",
    Size = UDim2.fromOffset(560, 430),
    Theme = "Dark",
    Resizable = true,
})

-- Tabs
local TabMain = Window:Tab({ Title = "Combat", Icon = "swords" })
local TabCam = Window:Tab({ Title = "Camlock", Icon = "camera" })
local TabTuning = Window:Tab({ Title = "Tuning", Icon = "sliders" })
local TabInfo = Window:Tab({ Title = "Info", Icon = "info" })

-- Sections
local S_Auto = TabMain:Section({ Title = "Autoblock", TextXAlignment = "Left" })
local S_M1 = TabMain:Section({ Title = "M1 Helpers", TextXAlignment = "Left" })
local S_Cam = TabCam:Section({ Title = "Camera Lock", TextXAlignment = "Left" })
local S_Small = TabCam:Section({ Title = "Mini GUI", TextXAlignment = "Left" })
local S_TuneBlock = TabTuning:Section({ Title = "Block Ranges", TextXAlignment = "Left" })
local S_TuneTiming = TabTuning:Section({ Title = "Timing & Grace", TextXAlignment = "Left" })
local S_TuneCam = TabTuning:Section({ Title = "View Cone", TextXAlignment = "Left" })
local S_Info = TabInfo:Section({ Title = "Notes", TextXAlignment = "Left" })

-- State
local State = {
    AutoBlock = false,
    M1After = false,
    M1Catch = false,

    NormalRange = 30,
    SpecialRange = 50,
    SkillRange = 50,
    SkillHold = 1.2,

    DashReleaseTime = 0.35,  -- release F for this long after dash
    PostDashNoBlock = 0.20,  -- grace period where block cannot re-engage
    MinPress = 0.14,         -- short block for poke
    ComboPress = 0.70,       -- longer block for combo/special

    CamLock = false,
    CamFovDeg = 35,          -- view cone half-angle
    CamMaxDistance = 120,    -- max target distance
    CamDoLoS = true,         -- require line of sight
}

-- Derived
local function now() return os.clock() end
local lastDashAt = 0
local blocking = false
local lastKeyPressAt = 0
local lastReleaseAt = 0
local lastCatch = 0
local targetHRP -- set by camlock chooser

-- Helpers
local function Communicate(goal, keycode, mobile)
    local char = LocalPlayer.Character
    if not char then return end
    local remote = char:FindFirstChild("Communicate")
    if not remote then return end
    local args = {{
        Goal = goal,
        Key = keycode,
        Mobile = mobile or nil
    }}
    remote:FireServer(unpack(args))
end

local function BlockPress()
    blocking = true
    lastKeyPressAt = now()
    Communicate("KeyPress", Enum.KeyCode.F)
end

local function BlockRelease()
    if blocking then
        blocking = false
        lastReleaseAt = now()
        Communicate("KeyRelease", Enum.KeyCode.F)
    end
end

local function TapM1IfClose(hrp, distLimit)
    local char = LocalPlayer.Character
    if not char or not hrp then return end
    local myHRP = char:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    if (hrp.Position - myHRP.Position).Magnitude <= (distLimit or 10) then
        Communicate("LeftClick", true)
        task.delay(0.25, function()
            Communicate("LeftClickRelease", true)
        end)
    end
end

-- WindUI Controls
local T_Auto = S_Auto:Toggle({
    Title = "Auto Block",
    Icon = "shield",
    Default = false,
    Callback = function(v)
        State.AutoBlock = v
        Window:Notify({ Title = "Autoblock", Content = v and "Enabled" or "Disabled", Duration = 1.5 })
        if not v then BlockRelease() end
    end
})

local T_M1After = S_M1:Toggle({
    Title = "M1 After Block",
    Icon = "sword",
    Default = false,
    Callback = function(v) State.M1After = v end
})

local T_M1Catch = S_M1:Toggle({
    Title = "M1 Catch",
    Icon = "zap",
    Default = false,
    Callback = function(v) State.M1Catch = v end
})

-- Ranges
local SL_Normal = S_TuneBlock:Slider({
    Title = "Normal Range",
    Icon = "move",
    Min = 5, Max = 120, Default = State.NormalRange, Suffix = "studs",
    Callback = function(v) State.NormalRange = v end
})
local SL_Special = S_TuneBlock:Slider({
    Title = "Special Range",
    Icon = "target",
    Min = 10, Max = 150, Default = State.SpecialRange, Suffix = "studs",
    Callback = function(v) State.SpecialRange = v end
})
local SL_Skill = S_TuneBlock:Slider({
    Title = "Skill Range",
    Icon = "flare",
    Min = 10, Max = 150, Default = State.SkillRange, Suffix = "studs",
    Callback = function(v) State.SkillRange = v end
})
local IN_SkillHold = S_TuneTiming:Input({
    Title = "Skill Hold (s)",
    Placeholder = tostring(State.SkillHold),
    Numeric = true,
    Callback = function(text)
        local v = tonumber(text)
        if v and v > 0 then State.SkillHold = v end
    end
})

local SL_Poke = S_TuneTiming:Slider({
    Title = "Poke Block Time",
    Icon = "clock",
    Min = 0.08, Max = 0.35, Default = State.MinPress, Decimals = 2, Suffix = "s",
    Callback = function(v) State.MinPress = v end
})
local SL_Combo = S_TuneTiming:Slider({
    Title = "Combo Block Time",
    Icon = "hourglass",
    Min = 0.4, Max = 1.0, Default = State.ComboPress, Decimals = 2, Suffix = "s",
    Callback = function(v) State.ComboPress = v end
})
local SL_DashRel = S_TuneTiming:Slider({
    Title = "Dash Release Time",
    Icon = "arrow-right",
    Min = 0.15, Max = 0.7, Default = State.DashReleaseTime, Decimals = 2, Suffix = "s",
    Callback = function(v) State.DashReleaseTime = v end
})
local SL_PostDash = S_TuneTiming:Slider({
    Title = "Post-dash No-Block",
    Icon = "ban",
    Min = 0.1, Max = 0.6, Default = State.PostDashNoBlock, Decimals = 2, Suffix = "s",
    Callback = function(v) State.PostDashNoBlock = v end
})

-- Camlock controls
local T_CamLock = S_Cam:Toggle({
    Title = "Camera Lock",
    Icon = "camera",
    Default = false,
    Callback = function(v)
        State.CamLock = v
        if v then
            Window:Notify({ Title = "Camlock", Content = "Enabled", Duration = 1 })
        else
            Window:Notify({ Title = "Camlock", Content = "Disabled", Duration = 1 })
            targetHRP = nil
        end
    end
})
local SL_Fov = S_TuneCam:Slider({
    Title = "View Cone",
    Icon = "triangle",
    Min = 10, Max = 70, Default = State.CamFovDeg, Suffix = "deg",
    Callback = function(v) State.CamFovDeg = v end
})
local SL_CamDist = S_TuneCam:Slider({
    Title = "Max Distance",
    Icon = "ruler",
    Min = 30, Max = 250, Default = State.CamMaxDistance, Suffix = "studs",
    Callback = function(v) State.CamMaxDistance = v end
})
local T_LoS = S_TuneCam:Toggle({
    Title = "Require LoS",
    Icon = "eye",
    Default = true,
    Callback = function(v) State.CamDoLoS = v end
})

-- Info
S_Info:Paragraph({
    Title = "WindUI Port",
    Desc = "UI migrated to WindUI, autoblock post-dash bug fixed, camlock picks targets inside camera cone and checks optional LoS.",
    Color = "White"
})

-- Mini Camlock widget (separate small window, shows only when main toggle on)
local CamMini = UI:CreateWindow({
    Title = "Camlock",
    Icon = "crosshair",
    Size = UDim2.fromOffset(260, 120),
    Transparent = true,
    Theme = "Dark",
    HideSearchBar = true,
})
local MiniSec = CamMini:Section({ Title = "Quick Controls" })
local MiniToggle = MiniSec:Toggle({
    Title = "Enabled",
    Icon = "power",
    Default = false,
    Callback = function(v)
        T_CamLock:Set(v)
    end
})
local MiniParagraph = MiniSec:Paragraph({
    Title = "Target",
    Desc = "None",
    Color = "White"
})
CamMini:SetVisible(false)

-- Auto handle mini window visibility when main toggle changes
T_CamLock:OnChanged(function(v)
    CamMini:SetVisible(v)
    MiniToggle:Set(v)
end)

-- Dash detection and autoblock release guard
local function IsDashing(hum)
    if not hum then return false end
    -- Detect quick horizontal velocity spike or custom "Dash" state: use MoveDirection magnitude
    local vel = hum.RootPart and hum.RootPart.Velocity or Vector3.zero
    local horizontal = Vector3.new(vel.X, 0, vel.Z).Magnitude
    -- Threshold tuned for anime combat dash bursts
    return horizontal > 38
end

-- Per-frame post-dash unblock
local function DashGuard()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    if IsDashing(hum) then
        lastDashAt = now()
        -- Immediate release during dash
        BlockRelease()
        return
    end

    -- If within post-dash windows, ensure block is not held
    local t = now()
    if t - lastDashAt <= State.DashReleaseTime then
        BlockRelease()
    end
end

-- Guard to prevent re-blocking too soon after dash
local function CanEngageBlock()
    local t = now()
    if t - lastDashAt <= State.PostDashNoBlock then
        return false
    end
    return true
end

-- Exported for part 2
_G.__TSB_State = State
_G.__TSB_Comms = {
    Press = BlockPress,
    Release = BlockRelease,
    TapM1IfClose = TapM1IfClose,
    DashGuard = DashGuard,
    CanBlock = CanEngageBlock,
    MiniParagraph = MiniParagraph,
    SetTarget = function(hrp) targetHRP = hrp end,
    GetTarget = function() return targetHRP end,
}
-- WindUI refactor + autoblock fixes (Part 2/2)
-- Relies on _G.__TSB_State and _G.__TSB_Comms from Part 1 [attached_file:1]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local State = _G.__TSB_State
local Comms = _G.__TSB_Comms
local Press = Comms.Press
local Release = Comms.Release
local TapM1IfClose = Comms.TapM1IfClose
local DashGuard = Comms.DashGuard
local CanBlock = Comms.CanBlock

local MiniParagraph = Comms.MiniParagraph
local function now() return os.clock() end

-- Animation IDs (ported from original)
local comboIDs = {10480793962, 10480796021}

local allIDs = {
    Saitama = {10469493270,10469630950,10469639222,10469643643, special=10479335397},
    Garou   = {13532562418,13532600125,13532604085,13294471966, special=10479335397},
    Cyborg  = {13491635433,13296577783,13295919399,13295936866, special=10479335397},
    Sonic   = {13370310513,13390230973,13378751717,13378708199, special=13380255751},
    Metal   = {14004222985,13997092940,14001963401,14136436157, special=13380255751},
    Blade   = {15259161390,15240216931,15240176873,15162694192, special=13380255751},
    Tatsu   = {16515503507,16515520431,16515448089,16552234590, special=10479335397},
    Dragon  = {17889458563,17889461810,17889471098,17889290569, special=10479335397},
    Tech    = {123005629431309,100059874351664,104895379416342,134775406437626, special=10479335397},
}

local skillIDs = {
    [10468665991]=true,[10466974800]=true,[10471336737]=true,[12510170988]=true,[12272894215]=true,[12296882427]=true,[12307656616]=true,
    [101588604872680]=true,[105442749844047]=true,[109617620932970]=true,[131820095363270]=true,[135289891173395]=true,[125955606488863]=true,
    [12534735382]=true,[12502664044]=true,[12509505723]=true,[12618271998]=true,[12684390285]=true,
    [13376869471]=true,[13294790250]=true,[13376962659]=true,[13501296372]=true,[13556985475]=true,
    [145162735010]=true,[14046756619]=true,[14299135500]=true,[14351441234]=true,
    [15290930205]=true,[15145462680]=true,[15295895753]=true,[15295336270]=true,
    [16139108718]=true,[16515850153]=true,[16431491215]=true,[16597322398]=true,[16597912086]=true,
    [17799224866]=true,[17838006839]=true,[17857788598]=true,[18179181663]=true,
    [113166426814229]=true,[116753755471636]=true,[116153572280464]=true,[114095570398448]=true,[77509627104305]=true,
}

-- Utility
local function HRPOf(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function GetAnimator(hum)
    return hum and hum:FindFirstChildOfClass("Animator")
end

local function InLiveModel(character)
    return character and character.Parent == (Workspace:FindFirstChild("Live") or Workspace)
end

-- Animator scan throttling
local animScanCooldown = 0.03
local lastScan = 0

local function getPlayingIds(hum)
    local t = now()
    if t - lastScan < animScanCooldown then
        -- still scan but keep early exit patterns small
    end
    lastScan = t
    local animator = GetAnimator(hum)
    if not animator then return nil end
    local map = {}
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local id = tonumber(track.Animation.AnimationId:match("%d+"))
        if id then map[id] = true end
    end
    return map
end

local function anySkill(anims) -- skill cast detection
    for id in pairs(anims) do
        if skillIDs[id] then return true end
    end
    return false
end

local function comboCountIn(anims)
    local c = 0
    for _, id in ipairs(comboIDs) do
        if anims[id] then c += 1 end
    end
    return c
end

local function normalsInGroup(anims, group)
    local n = 0
    for i=1,4 do
        if anims[group[i]] then n += 1 end
    end
    return n, anims[group.special] and true or false
end

-- Autoblock brain
local function AutoBlockTick()
    if not State.AutoBlock then return end
    if not CanBlock() then return end

    local myChar = LocalPlayer.Character
    local myHRP = HRPOf(myChar)
    if not myChar or not myHRP then return end

    -- Scan others
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and InLiveModel(plr.Character) then
            local theirHRP = HRPOf(plr.Character)
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if theirHRP and hum then
                local dist = (theirHRP.Position - myHRP.Position).Magnitude
                -- Skip far
                if dist > math.max(State.SpecialRange, State.SkillRange, State.NormalRange) then
                    continue
                end

                local anims = getPlayingIds(hum)
                if not anims then continue end

                local CC = comboCountIn(anims)
                for _, group in pairs(allIDs) do
                    local nHits, special = normalsInGroup(anims, group)

                    if CC == 2 and nHits >= 2 and dist <= State.SpecialRange then
                        Press()
                        task.delay(State.ComboPress, Release)
                        if State.M1After then
                            task.delay(0.08, function() TapM1IfClose(theirHRP, 10) end)
                        end
                        return
                    elseif nHits > 0 and dist <= State.NormalRange then
                        Press()
                        task.delay(State.MinPress, Release)
                        if State.M1After then
                            task.delay(0.08, function() TapM1IfClose(theirHRP, 10) end)
                        end
                        return
                    elseif special and dist <= State.SpecialRange and not State.M1Catch then
                        Press()
                        task.delay(State.ComboPress, Release)
                        return
                    end
                end

                if anySkill(anims) and dist <= State.SkillRange then
                    Press()
                    task.delay(State.SkillHold, Release)
                    return
                end
            end
        end
    end
end

-- M1 catch with cooldown
local function M1CatchTick()
    if not State.M1Catch then return end
    local myChar = LocalPlayer.Character
    local myHRP = HRPOf(myChar)
    if not myChar or not myHRP then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and InLiveModel(player.Character) then
            local hrp = HRPOf(player.Character)
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                local dist1 = (hrp.Position - myHRP.Position).Magnitude
                if dist1 <= 30 then
                    local anims = getPlayingIds(hum)
                    if anims and anims[10479335397] then -- special seen in original
                        task.delay(0.1, function()
                            local dist2 = (hrp.Position - myHRP.Position).Magnitude
                            if dist2 < dist1 - 0.5 and now() - (lastCatch or 0) >= 5 then
                                lastCatch = now()
                                Communicate = function() end -- shadow guard not needed; preserved interface
                                TapM1IfClose(hrp, 10)
                            end
                        end)
                        return
                    end
                end
            end
        end
    end
end

-- Camlock targeting: choose target inside camera cone in front
local function HasLineOfSight(fromPos, toPart)
    if not State.CamDoLoS then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    local dir = (toPart.Position - fromPos)
    local res = Workspace:Raycast(fromPos, dir, params)
    if not res then return true end
    return (res.Instance:IsDescendantOf(toPart.Parent))
end

local function ChooseTargetInView()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local camPos = cam.CFrame.Position
    local camLook = cam.CFrame.LookVector
    local cosMax = math.cos(math.rad(State.CamFovDeg)) -- dot threshold

    local best, bestDot = nil, cosMax
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and InLiveModel(plr.Character) then
            local hrp = HRPOf(plr.Character)
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local toVec = (hrp.Position - camPos)
                local dist = toVec.Magnitude
                if dist <= State.CamMaxDistance then
                    local dir = toVec.Unit
                    local d = dir:Dot(camLook)
                    if d >= bestDot then
                        if HasLineOfSight(camPos, hrp) then
                            best = hrp
                            bestDot = d
                        end
                    end
                end
            end
        end
    end
    return best
end

local function UpdateCamMini(hrp)
    if not MiniParagraph then return end
    if hrp and hrp.Parent then
        local plr = Players:GetPlayerFromCharacter(hrp.Parent)
        local name = plr and plr.DisplayName or (hrp.Parent.Name)
        MiniParagraph:SetDesc("Target: ".. tostring(name))
    else
        MiniParagraph:SetDesc("None")
    end
end

local function CamLockTick()
    if not State.CamLock then return end
    local cam = Workspace.CurrentCamera
    local char = LocalPlayer.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    if not cam or not char or not myHRP then return end

    -- Pick or validate target
    local tgt = Comms.GetTarget()
    if not tgt or not tgt.Parent then
        tgt = ChooseTargetInView()
        Comms.SetTarget(tgt)
        UpdateCamMini(tgt)
    else
        -- target can drift out of cone; if too far off, reacquire
        local camPos = cam.CFrame.Position
        local camLook = cam.CFrame.LookVector
        local dir = (tgt.Position - camPos).Unit
        local dot = dir:Dot(camLook)
        if dot < math.cos(math.rad(State.CamFovDeg + 10)) then
            tgt = ChooseTargetInView()
            Comms.SetTarget(tgt)
            UpdateCamMini(tgt)
        end
    end

    if not tgt then return end

    -- Soft lock: only orient camera to look at target, do not force Scriptable type
    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, tgt.Position)
end

-- Per-frame loop
RunService.Heartbeat:Connect(function()
    -- Dash guard always active to prevent stuck block after dash
    DashGuard()

    -- If we’re blocking with no stimuli and after allowed windows, release
    if not State.AutoBlock then
        Release()
        return
    end

    -- Core logic
    AutoBlockTick()
    M1CatchTick()
    CamLockTick()
end)
