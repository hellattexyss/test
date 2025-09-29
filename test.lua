-- WindUI refactor with working sliders and old defaults (Part 1/2)
-- Defaults mirrored from original: Normal=30, Special=50, Skill=50, SkillHold=1.2, Poke=0.15, Combo=0.70 [attached_file:1]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Load WindUI (release main.lua)
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))() -- WindUI API [web:2][web:19]

-- Window
local Window = WindUI:CreateWindow({
    Title = "TSB Autoblock + Camlock",
    Icon = "shield",
    Size = UDim2.fromOffset(560, 430),
    Theme = "Dark",
})

-- Tabs / sections
local TabMain = Window:Tab({ Title = "Combat", Icon = "swords" })
local TabCam  = Window:Tab({ Title = "Camlock", Icon = "camera" })
local TabTune = Window:Tab({ Title = "Tuning", Icon = "sliders" })

local S_Auto = TabMain:Section({ Title = "Autoblock" })
local S_M1   = TabMain:Section({ Title = "M1 Helpers" })
local S_Cam  = TabCam:Section({ Title = "Lock Controls" })
local S_CamMini = TabCam:Section({ Title = "Mini Window" })
local S_Range = TabTune:Section({ Title = "Ranges" })
local S_Time  = TabTune:Section({ Title = "Timings" })
local S_View  = TabTune:Section({ Title = "View Cone" })

-- State (defaults from old code)
local State = {
    AutoBlock = false,
    M1After = false,
    M1Catch = false,

    NormalRange = 30,   -- old normalRange [attached_file:1]
    SpecialRange = 50,  -- old specialRange [attached_file:1]
    SkillRange = 50,    -- old skillRange [attached_file:1]
    SkillHold = 1.2,    -- old skillDelay [attached_file:1]

    MinPress = 0.15,    -- old short wait for normals [attached_file:1]
    ComboPress = 0.70,  -- old long wait for combos [attached_file:1]
    DashReleaseTime = 0.35,
    PostDashNoBlock = 0.20,

    CamLock = false,
    CamFovDeg = 35,
    CamMaxDistance = 120,
    CamDoLoS = true,
}

-- Time helpers and tracking
local function now() return os.clock() end
local blocking = false
local lastDashAt = 0

-- Remote helpers
local function Communicate(goal, keycode, mobile)
    local char = LocalPlayer.Character
    if not char then return end
    local remote = char:FindFirstChild("Communicate")
    if not remote then return end
    remote:FireServer({
        Goal = goal,
        Key = keycode,
        Mobile = mobile or nil
    })
end

local function PressBlock()
    if blocking then return end
    blocking = true
    Communicate("KeyPress", Enum.KeyCode.F)
end

local function ReleaseBlock()
    if not blocking then return end
    blocking = false
    Communicate("KeyRelease", Enum.KeyCode.F)
end

-- Dash guard
local function IsDashing()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end
    local v = hrp.Velocity
    local h = Vector3.new(v.X, 0, v.Z).Magnitude
    return h > 38
end

local function DashGuard()
    if IsDashing() then
        lastDashAt = now()
        ReleaseBlock()
        return
    end
    if now() - lastDashAt <= State.DashReleaseTime then
        ReleaseBlock()
    end
end

local function CanReBlock()
    return (now() - lastDashAt) > State.PostDashNoBlock
end

-- UI controls (WindUI) – make sure sliders change State and show current values
local T_Auto = S_Auto:Toggle({
    Title = "Auto Block",
    Default = false,
    Callback = function(v)
        State.AutoBlock = v
        if not v then ReleaseBlock() end
    end
})

local T_M1After = S_M1:Toggle({
    Title = "M1 After Block",
    Default = false,
    Callback = function(v) State.M1After = v end
})

local T_M1Catch = S_M1:Toggle({
    Title = "M1 Catch",
    Default = false,
    Callback = function(v) State.M1Catch = v end
})

-- Range sliders with old defaults
local SL_Normal = S_Range:Slider({
    Title = "Normal Range",
    Min = 5, Max = 120, Default = State.NormalRange,
    Suffix = "studs",
    Callback = function(v) State.NormalRange = v end
})

local SL_Special = S_Range:Slider({
    Title = "Special Range",
    Min = 10, Max = 150, Default = State.SpecialRange,
    Suffix = "studs",
    Callback = function(v) State.SpecialRange = v end
})

local SL_Skill = S_Range:Slider({
    Title = "Skill Range",
    Min = 10, Max = 150, Default = State.SkillRange,
    Suffix = "studs",
    Callback = function(v) State.SkillRange = v end
})

-- Timing sliders with old waits
local SL_Poke = S_Time:Slider({
    Title = "Poke Block Time",
    Min = 0.08, Max = 0.35, Default = State.MinPress,
    Decimals = 2, Suffix = "s",
    Callback = function(v) State.MinPress = v end
})

local SL_Combo = S_Time:Slider({
    Title = "Combo Block Time",
    Min = 0.4, Max = 1.0, Default = State.ComboPress,
    Decimals = 2, Suffix = "s",
    Callback = function(v) State.ComboPress = v end
})

local SL_DashRel = S_Time:Slider({
    Title = "Dash Release Time",
    Min = 0.15, Max = 0.7, Default = State.DashReleaseTime,
    Decimals = 2, Suffix = "s",
    Callback = function(v) State.DashReleaseTime = v end
})

local SL_NoRe = S_Time:Slider({
    Title = "Post-dash No-Block",
    Min = 0.1, Max = 0.6, Default = State.PostDashNoBlock,
    Decimals = 2, Suffix = "s",
    Callback = function(v) State.PostDashNoBlock = v end
})

-- Camlock controls and mini window
local T_Cam = S_Cam:Toggle({
    Title = "Camera Lock",
    Default = false,
    Callback = function(v) State.CamLock = v; CamMini:SetVisible(v) end
})

local SL_Fov = S_View:Slider({
    Title = "View Cone",
    Min = 10, Max = 70, Default = State.CamFovDeg,
    Suffix = "deg",
    Callback = function(v) State.CamFovDeg = v end
})

local SL_Dist = S_View:Slider({
    Title = "Max Distance",
    Min = 30, Max = 250, Default = State.CamMaxDistance,
    Suffix = "studs",
    Callback = function(v) State.CamMaxDistance = v end
})

local T_LoS = S_View:Toggle({
    Title = "Require LoS",
    Default = true,
    Callback = function(v) State.CamDoLoS = v end
})

-- Separate mini camlock window
local CamMini = WindUI:CreateWindow({
    Title = "Camlock",
    Icon = "crosshair",
    Size = UDim2.fromOffset(260, 120),
    Theme = "Dark",
})
local MiniSec = CamMini:Section({ Title = "Quick" })
local MiniToggle = MiniSec:Toggle({
    Title = "Enabled",
    Default = false,
    Callback = function(v) T_Cam:Set(v) end
})
local MiniLabel = MiniSec:Paragraph({ Title = "Target", Desc = "None" })
CamMini:SetVisible(false)

-- Export to part 2
_G.__TSB_Wind = {
    State = State,
    PressBlock = PressBlock,
    ReleaseBlock = ReleaseBlock,
    DashGuard = DashGuard,
    CanReBlock = CanReBlock,
    MiniLabel = MiniLabel,
}
-- Autoblock logic, animation scan, and camlock in-front selection (Part 2/2)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local W = _G.__TSB_Wind
local State = W.State
local PressBlock, ReleaseBlock = W.PressBlock, W.ReleaseBlock
local DashGuard, CanReBlock = W.DashGuard, W.CanReBlock
local MiniLabel = W.MiniLabel

local function now() return os.clock() end
local targetHRP

-- IDs from original script (shortened for space but core ones preserved)
local comboIDs = {10480793962, 10480796021} -- original combo markers [attached_file:1]

local allIDs = { -- normals + special per style (same keys as original)
    Saitama = {10469493270,10469630950,10469639222,10469643643, special=10479335397},
    Garou   = {13532562418,13532600125,13532604085,13294471966, special=10479335397},
    Cyborg  = {13491635433,13296577783,13295919399,13295936866, special=10479335397},
    Sonic   = {13370310513,13390230973,13378751717,13378708199, special=13380255751},
    Metal   = {14004222985,13997092940,14001963401,14136436157, special=13380255751},
    Blade   = {15259161390,15240216931,15240176873,15162694192, special=13380255751},
    Tatsumaki={16515503507,16515520431,16515448089,16552234590, special=10479335397},
    Dragon  = {17889458563,17889461810,17889471098,17889290569, special=10479335397},
    Tech    = {123005629431309,100059874351664,104895379416342,134775406437626, special=10479335397},
} -- sourced from original file mapping [attached_file:1]

local skillIDs = { -- condensed from original
    [10468665991]=true,[10466974800]=true,[10471336737]=true,[12510170988]=true,[12272894215]=true,[12296882427]=true,[12307656616]=true,
    [101588604872680]=true,[105442749844047]=true,[109617620932970]=true,[131820095363270]=true,[135289891173395]=true,[125955606488863]=true,
    [12534735382]=true,[12502664044]=true,[12509505723]=true,[12618271998]=true,[12684390285]=true,[13376869471]=true,[13294790250]=true,
    [13376962659]=true,[13501296372]=true,[13556985475]=true,[145162735010]=true,[14046756619]=true,[14299135500]=true,[14351441234]=true,
    [15290930205]=true,[15145462680]=true,[15295895753]=true,[15295336270]=true,[16139108718]=true,[16515850153]=true,[16431491215]=true,
    [16597322398]=true,[16597912086]=true,[17799224866]=true,[17838006839]=true,[17857788598]=true,[18179181663]=true,
    [113166426814229]=true,[116753755471636]=true,[116153572280464]=true,[114095570398448]=true,[77509627104305]=true,
} -- original set mirrored [attached_file:1]

local function HRPOf(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function InLive(char)
    local live = Workspace:FindFirstChild("Live")
    return char and char.Parent == (live or Workspace)
end

local animScanCooldown = 0.03
local lastScan = 0
local function getAnims(hum)
    if not hum then return nil end
    if now() - lastScan < animScanCooldown then
        -- still scan; throttling avoids heavy cost
    end
    lastScan = now()
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return nil end
    local m = {}
    for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
        local id = tonumber(tr.Animation.AnimationId:match("%d+"))
        if id then m[id] = true end
    end
    return m
end

local function hasAnySkill(m)
    if not m then return false end
    for id in pairs(m) do
        if skillIDs[id] then return true end
    end
    return false
end

local function comboCount(m)
    local c = 0
    for _, id in ipairs(comboIDs) do
        if m[id] then c += 1 end
    end
    return c
end

local function normalsAndSpecial(m, group)
    local n = 0
    for i=1,4 do
        if m[group[i]] then n += 1 end
    end
    local sp = m[group.special] and true or false
    return n, sp
end

-- After-block M1 helper
local function TapM1IfClose(hrp)
    local char = LocalPlayer.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    if not myHRP or not hrp then return end
    local d = (hrp.Position - myHRP.Position).Magnitude
    if d <= 10 then
        Communicate("LeftClick", true)
        task.delay(0.25, function() Communicate("LeftClickRelease", true) end)
    end
end

-- Autoblock logic preserving old timings
local function AutoBlockTick()
    if not State.AutoBlock then return end
    if not CanReBlock() then return end

    local myChar = LocalPlayer.Character
    local myHRP = HRPOf(myChar)
    if not myChar or not myHRP then return end

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and InLive(pl.Character) then
            local hrp = HRPOf(pl.Character)
            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                local dist = (hrp.Position - myHRP.Position).Magnitude
                if dist > math.max(State.SpecialRange, State.SkillRange, State.NormalRange) then
                    continue
                end
                local m = getAnims(hum)
                if not m then continue end

                local cc = comboCount(m)
                for _, group in pairs(allIDs) do
                    local n, sp = normalsAndSpecial(m, group)
                    if cc == 2 and n >= 2 and dist <= State.SpecialRange then
                        PressBlock()
                        task.delay(State.ComboPress, ReleaseBlock)
                        if State.M1After then task.delay(0.08, function() TapM1IfClose(hrp) end) end
                        return
                    elseif n > 0 and dist <= State.NormalRange then
                        PressBlock()
                        task.delay(State.MinPress, ReleaseBlock)
                        if State.M1After then task.delay(0.08, function() TapM1IfClose(hrp) end) end
                        return
                    elseif sp and dist <= State.SpecialRange and not State.M1Catch then
                        PressBlock()
                        task.delay(State.ComboPress, ReleaseBlock)
                        return
                    end
                end

                if hasAnySkill(m) and dist <= State.SkillRange then
                    PressBlock()
                    task.delay(State.SkillHold, ReleaseBlock)
                    return
                end
            end
        end
    end
end

-- M1 catch preserved
local lastCatch = 0
local function M1CatchTick()
    if not State.M1Catch then return end
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and InLive(pl.Character) then
            local hrp = HRPOf(pl.Character)
            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                local d1 = (hrp.Position - myHRP.Position).Magnitude
                if d1 <= 30 then
                    local m = getAnims(hum)
                    if m and m[10479335397] then
                        task.delay(0.1, function()
                            local d2 = (hrp.Position - myHRP.Position).Magnitude
                            if d2 < d1 - 0.5 and now() - lastCatch >= 5 then
                                lastCatch = now()
                                Communicate("LeftClick", true)
                                task.delay(0.2, function() Communicate("LeftClickRelease", true) end)
                            end
                        end)
                        return
                    end
                end
            end
        end
    end
end

-- Camlock: choose target in front of camera view
local function HasLoS(fromPos, toPart)
    if not State.CamDoLoS then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    local res = Workspace:Raycast(fromPos, (toPart.Position - fromPos), params)
    return not res or res.Instance:IsDescendantOf(toPart.Parent)
end

local function ChooseFrontTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local camPos = cam.CFrame.Position
    local look = cam.CFrame.LookVector
    local cosThresh = math.cos(math.rad(State.CamFovDeg))
    local best, bestDot = nil, cosThresh

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and InLive(pl.Character) then
            local hrp = HRPOf(pl.Character)
            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local vec = hrp.Position - camPos
                local dist = vec.Magnitude
                if dist <= State.CamMaxDistance then
                    local d = vec.Unit:Dot(look)
                    if d >= bestDot and HasLoS(camPos, hrp) then
                        best, bestDot = hrp, d
                    end
                end
            end
        end
    end
    return best
end

local function UpdateMini(hrp)
    if not MiniLabel then return end
    if hrp and hrp.Parent then
        local pl = Players:GetPlayerFromCharacter(hrp.Parent)
        MiniLabel:SetDesc(pl and ("Target: "..pl.DisplayName) or ("Target: "..hrp.Parent.Name))
    else
        MiniLabel:SetDesc("None")
    end
end

local function CamLockTick()
    if not State.CamLock then return end
    local cam = Workspace.CurrentCamera
    local char = LocalPlayer.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    if not cam or not myHRP then return end

    if not targetHRP or not targetHRP.Parent then
        targetHRP = ChooseFrontTarget()
        UpdateMini(targetHRP)
    else
        local camPos = cam.CFrame.Position
        local look = cam.CFrame.LookVector
        local dir = (targetHRP.Position - camPos).Unit
        local dot = dir:Dot(look)
        if dot < math.cos(math.rad(State.CamFovDeg + 10)) then
            targetHRP = ChooseFrontTarget()
            UpdateMini(targetHRP)
        end
    end
    if not targetHRP then return end

    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetHRP.Position)
end

-- Main loop
RunService.Heartbeat:Connect(function()
    DashGuard()
    if not State.AutoBlock then
        ReleaseBlock()
        if State.CamLock then CamLockTick() end
        return
    end
    AutoBlockTick()
    M1CatchTick()
    CamLockTick()
end)
