-- CC BY 4.0; using WindUI like the provided example
local Windui = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Defaults (old code)
getgenv().tsb = getgenv().tsb or {
    AutoBlock=false, M1After=false, M1Catch=false,
    NormalRange=30, SpecialRange=50, SkillRange=50, SkillHold=1.2,
    MinPress=0.15, ComboPress=0.70, DashReleaseTime=0.35, PostDashNoBlock=0.20,
    CamLock=false, CamFovDeg=35, CamMaxDistance=120, CamDoLoS=true,
    FPSBoost=false,
}
local S = getgenv().tsb

-- Window (same flags as example)
local Window = Windui:CreateWindow({
    Title = "TSB",
    Icon = "shield",
    Author = "refactor",
    Folder = "TSB_Config",
    Size = UDim2.fromOffset(720, 520),
    Transparent = false,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 140,
    HideSearchBar = true,
    ScrollBarEnabled = true,
})

-- Config manager like example
local Config = Window.ConfigManager
local default = Config:CreateConfig("default")
local saveFlag = "WindUI/" .. Window.Folder .. "/config/autosave"
local loadFlag = "WindUI/" .. Window.Folder .. "/config/autoload"
local function fileon(path, on)
    if on then if writefile then pcall(writefile, path, "") end else if delfile then pcall(delfile, path) end end
end
if isfile and isfile(loadFlag) then pcall(function() default:Load() end) end
fileon(loadFlag, true); fileon(saveFlag, true)
local function autosave() pcall(function() default:Save() end) end

-- Tabs (exact API style)
local Combat = Window:Tab({ Title = "Combat", Icon = "swords" })
local Cam    = Window:Tab({ Title = "Camlock", Icon = "camera" })
local Tuning = Window:Tab({ Title = "Tuning", Icon = "sliders" })
local Misc   = Window:Tab({ Title = "Misc", Icon = "settings" })

-- Elements table for registration (example pattern)
local E = {}

-- Combat: flat toggles
E.auto = Combat:Toggle({
    Title = "Auto Block",
    Desc  = "Enable autoblock",
    Value = S.AutoBlock,
    Callback = function(v) S.AutoBlock=v; autosave() end,
})
E.m1a = Combat:Toggle({
    Title = "M1 After Block",
    Value = S.M1After,
    Callback = function(v) S.M1After=v; autosave() end,
})
E.m1c = Combat:Toggle({
    Title = "M1 Catch",
    Value = S.M1Catch,
    Callback = function(v) S.M1Catch=v; autosave() end,
})

-- Camlock controls
E.cl  = Cam:Toggle({
    Title = "Camera Lock",
    Value = S.CamLock,
    Callback = function(v) S.CamLock=v; autosave() end,
})
E.los = Cam:Toggle({
    Title = "Require LoS",
    Value = S.CamDoLoS,
    Callback = function(v) S.CamDoLoS=v; autosave() end,
})

-- Tuning: sliders like example style (Value table)
E.rn = Tuning:Slider({
    Title = "Normal Range",
    Value = { Min=5, Max=120, Default=S.NormalRange },
    Callback = function(v) S.NormalRange=tonumber(v); autosave() end,
})
E.rs = Tuning:Slider({
    Title = "Special Range",
    Value = { Min=10, Max=150, Default=S.SpecialRange },
    Callback = function(v) S.SpecialRange=tonumber(v); autosave() end,
})
E.rk = Tuning:Slider({
    Title = "Skill Range",
    Value = { Min=10, Max=150, Default=S.SkillRange },
    Callback = function(v) S.SkillRange=tonumber(v); autosave() end,
})
E.hold = Tuning:Slider({
    Title = "Skill Hold (s)",
    Step = 0.05,
    Value = { Min=0.2, Max=3, Default=S.SkillHold },
    Callback = function(v) S.SkillHold=tonumber(v); autosave() end,
})
E.tpoke = Tuning:Slider({
    Title = "Poke Block Time",
    Step = 0.01,
    Value = { Min=0.08, Max=0.35, Default=S.MinPress },
    Callback = function(v) S.MinPress=tonumber(v); autosave() end,
})
E.tcombo = Tuning:Slider({
    Title = "Combo Block Time",
    Step = 0.01,
    Value = { Min=0.4, Max=1.0, Default=S.ComboPress },
    Callback = function(v) S.ComboPress=tonumber(v); autosave() end,
})
E.tdash = Tuning:Slider({
    Title = "Dash Release",
    Step = 0.01,
    Value = { Min=0.15, Max=0.7, Default=S.DashReleaseTime },
    Callback = function(v) S.DashReleaseTime=tonumber(v); autosave() end,
})
E.tpost = Tuning:Slider({
    Title = "Post-dash No-Block",
    Step = 0.01,
    Value = { Min=0.1, Max=0.6, Default=S.PostDashNoBlock },
    Callback = function(v) S.PostDashNoBlock=tonumber(v); autosave() end,
})

-- Misc: FPS boost toggle in same API
E.fps = Misc:Toggle({
    Title = "FPS Boost",
    Desc  = "Disable costly effects for performance",
    Value = S.FPSBoost,
    Callback = function(v) S.FPSBoost=v; autosave() end,
})

-- Register elements with config like example
for _, el in pairs(E) do
    if el and el.Title then default:Register(el.Title, el) end
end

-- Export UI/back-end hooks
_G.__TSB_Wind = _G.__TSB_Wind or {}
_G.__TSB_Wind.State = S
_G.__TSB_Wind.AutoSave = autosave
-- Logic for TSB (paste after the UI block above)

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local LocalPlayer=Players.LocalPlayer

local S = (_G.__TSB_Wind and _G.__TSB_Wind.State) or getgenv().tsb
if not S then warn("TSB: config missing"); return end

-- Remotes and helpers
local function Communicate(goal, keycode, mobile)
    local c=LocalPlayer.Character; if not c then return end
    local r=c:FindFirstChild("Communicate"); if not r then return end
    r:FireServer({Goal=goal, Key=keycode, Mobile=mobile or nil})
end
local blocking,lastDashAt=false,0
local function PressBlock() if blocking then return end blocking=true; Communicate("KeyPress", Enum.KeyCode.F) end
local function ReleaseBlock() if not blocking then return end blocking=false; Communicate("KeyRelease", Enum.KeyCode.F) end
local function IsDashing()
    local c=LocalPlayer.Character; local hrp=c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return false end
    local v=hrp.Velocity; return Vector3.new(v.X,0,v.Z).Magnitude>38
end
local function DashGuard() if IsDashing() then lastDashAt=os.clock(); ReleaseBlock(); return end if os.clock()-lastDashAt<=S.DashReleaseTime then ReleaseBlock() end end
local function CanReBlock() return (os.clock()-lastDashAt)>S.PostDashNoBlock end
local function now() return os.clock() end

-- IDs (from original)
local comboIDs={10480793962,10480796021}
local allIDs={
    Saitama={10469493270,10469630950,10469639222,10469643643, special=10479335397},
    Garou  ={13532562418,13532600125,13532604085,13294471966, special=10479335397},
    Cyborg ={13491635433,13296577783,13295919399,13295936866, special=10479335397},
    Sonic  ={13370310513,13390230973,13378751717,13378708199, special=13380255751},
    Metal  ={14004222985,13997092940,14001963401,14136436157, special=13380255751},
    Blade  ={15259161390,15240216931,15240176873,15162694192, special=13380255751},
    Tatsu  ={16515503507,16515520431,16515448089,16552234590, special=10479335397},
    Dragon ={17889458563,17889461810,17889471098,17889290569, special=10479335397},
    Tech   ={123005629431309,100059874351664,104895379416342,134775406437626, special=10479335397},
}
local skillIDs={
    [10468665991]=true,[10466974800]=true,[10471336737]=true,[12510170988]=true,[12272894215]=true,[12296882427]=true,[12307656616]=true,
    [101588604872680]=true,[105442749844047]=true,[109617620932970]=true,[131820095363270]=true,[135289891173395]=true,[125955606488863]=true,
    [12534735382]=true,[12502664044]=true,[12509505723]=true,[12618271998]=true,[12684390285]=true,[13376869471]=true,[13294790250]=true,
    [13376962659]=true,[13501296372]=true,[13556985475]=true,[145162735010]=true,[14046756619]=true,[14299135500]=true,[14351441234]=true,
    [15290930205]=true,[15145462680]=true,[15295895753]=true,[15295336270]=true,[16139108718]=true,[16515850153]=true,[16431491215]=true,
    [16597322398]=true,[16597912086]=true,[17799224866]=true,[17838006839]=true,[17857788598]=true,[18179181663]=true,
    [113166426814229]=true,[116753755471636]=true,[116153572280464]=true,[114095570398448]=true,[77509627104305]=true,
}

local function HRPOf(c) return c and c:FindFirstChild("HumanoidRootPart") end
local function InLive(c) local live=Workspace:FindFirstChild("Live"); return c and c.Parent==(live or Workspace) end

local lastScan=0
local function getAnims(h)
    if not h then return nil end
    if now()-lastScan<0.03 then end
    lastScan=now()
    local a=h:FindFirstChildOfClass("Animator"); if not a then return nil end
    local ok,tr=pcall(function() return a:GetPlayingAnimationTracks() end)
    if not ok or not tr then return nil end
    local m={}
    for _,t in ipairs(tr) do
        local anim=t.Animation
        if anim and anim.AnimationId then
            local id=tonumber(anim.AnimationId:match("%d+"))
            if id then m[id]=true end
        end
    end
    return m
end

local function comboCount(m) local c=0 for _,id in ipairs(comboIDs) do if m[id] then c+=1 end end return c end
local function normalsAndSp(m,g) local n=0 for i=1,4 do if m[g[i]] then n+=1 end end return n, m[g.special] and true or false end
local function hasSkill(m) for id in pairs(m) do if skillIDs[id] then return true end end return false end

-- Accuracy improvements
local lastBlockFrom={}, 0.25
local BLOCK_COOLDOWN=0.25
local COMBO_END_GAP=0.15
local lastActiveAnimAt=0

local function TapM1IfClose(hrp)
    local ch=LocalPlayer.Character; local my=ch and ch:FindFirstChild("HumanoidRootPart"); if not my or not hrp then return end
    if (hrp.Position-my.Position).Magnitude<=10 then
        Communicate("LeftClick", true)
        task.delay(0.25,function() Communicate("LeftClickRelease", true) end)
    end
end

local function AutoBlockTick()
    if not S.AutoBlock or not ((os.clock()-lastDashAt)>S.PostDashNoBlock) then return end
    local ch=LocalPlayer.Character; local my=HRPOf(ch); if not my then return end

    local bestThreat,bestDist=nil,1e9
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=LocalPlayer and pl.Character and InLive(pl.Character) then
            local hrp=HRPOf(pl.Character); local hum=pl.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health>0 then
                local dist=(hrp.Position-my.Position).Magnitude
                if dist<=math.max(S.SpecialRange,S.SkillRange,S.NormalRange) then
                    local m=getAnims(hum)
                    if m then
                        local cc=comboCount(m)
                        for _,g in pairs(allIDs) do
                            local n,sp=normalsAndSp(m,g)
                            if cc==2 and n>=2 and dist<=S.SpecialRange then if dist<bestDist then bestThreat={pl,hrp,"combo"}; bestDist=dist end
                            elseif n>0 and dist<=S.NormalRange then if dist<bestDist then bestThreat={pl,hrp,"poke"}; bestDist=dist end
                            elseif sp and dist<=S.SpecialRange and not S.M1Catch then if dist<bestDist then bestThreat={pl,hrp,"special"}; bestDist=dist end end
                        end
                        if hasSkill(m) and dist<=S.SkillRange then if dist<bestDist then bestThreat={pl,hrp,"skill"}; bestDist=dist end end
                        for _ in pairs(m) do lastActiveAnimAt=now() break end
                    end
                end
            end
        end
    end

    if bestThreat then
        local pl,hrp,tag=bestThreat[1],bestThreat[2],bestThreat[3]
        local t=now()
        if (t-(lastBlockFrom[pl] or 0))<BLOCK_COOLDOWN then return end
        lastBlockFrom[pl]=t
        if tag=="combo" or tag=="special" then
            PressBlock(); task.delay(S.ComboPress, ReleaseBlock)
            if S.M1After then task.delay(0.08,function() TapM1IfClose(hrp) end) end
        elseif tag=="poke" then
            PressBlock(); task.delay(S.MinPress, ReleaseBlock)
            if S.M1After then task.delay(0.08,function() TapM1IfClose(hrp) end) end
        elseif tag=="skill" then
            PressBlock(); task.delay(S.SkillHold, ReleaseBlock)
        end
    else
        ReleaseBlock()
    end

    if (now()-lastActiveAnimAt)>=COMBO_END_GAP then ReleaseBlock() end
end

-- Camlock + highlight
local highlight
local function setHighlight(model)
    if highlight then highlight:Destroy(); highlight=nil end
    if not model then return end
    local h=Instance.new("Highlight")
    h.FillColor=Color3.fromRGB(220,60,60); h.FillTransparency=0.35
    h.OutlineColor=Color3.fromRGB(255,0,0); h.OutlineTransparency=0
    h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee=model; h.Parent=Workspace
    highlight=h
end
local targetHRP
local function HasLoS(fromPos,toPart)
    if not S.CamDoLoS then return true end
    local p=RaycastParams.new(); p.FilterType=Enum.RaycastFilterType.Exclude; p.FilterDescendantsInstances={LocalPlayer.Character}
    local res=Workspace:Raycast(fromPos,(toPart.Position-fromPos),p)
    return not res or res.Instance:IsDescendantOf(toPart.Parent)
end
local function ChooseFrontTarget()
    local cam=Workspace.CurrentCamera; if not cam then return nil end
    local camPos,look=cam.CFrame.Position,cam.CFrame.LookVector
    local cosThresh=math.cos(math.rad(S.CamFovDeg))
    local best,bestDot=nil,cosThresh
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=LocalPlayer and pl.Character and InLive(pl.Character) then
            local hrp=HRPOf(pl.Character); local hum=pl.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health>0 then
                local vec=hrp.Position-camPos; local dist=vec.Magnitude
                if dist<=S.CamMaxDistance then
                    local d=vec.Unit:Dot(look)
                    if d>=bestDot and HasLoS(camPos,hrp) then best,bestDot=hrp,d end
                end
            end
        end
    end
    return best
end
local function CamLockTick()
    if not S.CamLock then targetHRP=nil; setHighlight(nil); return end
    local cam=Workspace.CurrentCamera; local ch=LocalPlayer.Character; local my=ch and ch:FindFirstChild("HumanoidRootPart")
    if not cam or not my then return end
    if not targetHRP or not targetHRP.Parent then
        targetHRP=ChooseFrontTarget(); setHighlight(targetHRP and targetHRP.Parent or nil)
    else
        local dir=(targetHRP.Position-cam.CFrame.Position).Unit
        if dir:Dot(cam.CFrame.LookVector) < math.cos(math.rad(S.CamFovDeg+10)) then
            targetHRP=ChooseFrontTarget(); setHighlight(targetHRP and targetHRP.Parent or nil)
        end
    end
    if not targetHRP then return end
    cam.CFrame=CFrame.lookAt(cam.CFrame.Position,targetHRP.Position)
end

-- FPS boost application when toggled in UI (optional; safe no-op here)

-- Main loop
RunService.Heartbeat:Connect(function()
    DashGuard()
    if S.AutoBlock then
        AutoBlockTick()
    else
        ReleaseBlock()
    end
    CamLockTick()
end)
