-- TSB Autoblock + Camlock UI (Part 1/2): Pure Roblox GUI (no WindUI), reliable on all executors

-- Services
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local LocalPlayer=Players.LocalPlayer

-- State defaults
getgenv().tsbConfig = getgenv().tsbConfig or {
    AutoBlock=false, M1After=false, M1Catch=false,
    NormalRange=30, SpecialRange=50, SkillRange=50, SkillHold=1.2,
    MinPress=0.15, ComboPress=0.70, DashReleaseTime=0.35, PostDashNoBlock=0.20,
    CamLock=false, CamFovDeg=35, CamMaxDistance=120, CamDoLoS=true,
    FPSBoost=false,
}
local State = getgenv().tsbConfig

-- Autosave (writefile-based)
local savePath="TSB_WindUI_autosave.json"
local function jsonify(tbl)
    local ok, enc = pcall(game.HttpService.JSONEncode, game.HttpService, tbl)
    return ok and enc or nil
end
local function parsejson(str)
    local ok, dec = pcall(game.HttpService.JSONDecode, game.HttpService, str)
    return ok and dec or nil
end
local function autosave()
    if writefile and jsonify then
        pcall(writefile, savePath, jsonify(State) or "")
    end
end
if isfile and isfile(savePath) and parsejson then
    local ok, data = pcall(readfile, savePath)
    if ok and data then
        local dec = parsejson(data)
        if type(dec)=="table" then for k,v in pairs(dec) do State[k]=v end end
    end
end

-- Communicate + block control
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
local function DashGuard() if IsDashing() then lastDashAt=os.clock(); ReleaseBlock(); return end if os.clock()-lastDashAt<=State.DashReleaseTime then ReleaseBlock() end end
local function CanReBlock() return (os.clock()-lastDashAt)>State.PostDashNoBlock end

-- UI Builder (pure Roblox)
local Screen = Instance.new("ScreenGui")
Screen.Name="TSB_StableUI"
Screen.ResetOnSpawn=false
do local ok,hui=pcall(gethui); (ok and typeof(hui)=="Instance" and (Screen.Parent=hui)) or (Screen.Parent=LocalPlayer:WaitForChild("PlayerGui")) end

local cam=Workspace.CurrentCamera; local vp=cam and cam.ViewportSize or Vector2.new(1280,720)
local W,H=math.max(720, math.floor(vp.X*0.8)), math.max(560, math.floor(vp.Y*0.75))

local Root = Instance.new("Frame")
Root.Name="Root"
Root.AnchorPoint=Vector2.new(0.5,0.5)
Root.Position=UDim2.fromScale(0.5,0.5)
Root.Size=UDim2.fromOffset(W,H)
Root.BackgroundColor3=Color3.fromRGB(24,24,24)
Root.Active=true; Root.Draggable=true
Root.Parent=Screen

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency=1
Title.TextXAlignment=Enum.TextXAlignment.Left
Title.Font=Enum.Font.GothamBold; Title.TextSize=16
Title.TextColor3=Color3.fromRGB(235,235,235)
Title.Text="TSB Autoblock + Camlock"
Title.Size=UDim2.new(1,-20,0,28); Title.Position=UDim2.new(0,10,0,6)
Title.Parent=Root

local Sidebar = Instance.new("Frame")
Sidebar.Size=UDim2.new(0,140,1,-44)
Sidebar.Position=UDim2.new(0,10,0,36)
Sidebar.BackgroundColor3=Color3.fromRGB(30,30,30)
Sidebar.Parent=Root
local SideList=Instance.new("UIListLayout", Sidebar)
SideList.Padding=UDim.new(0,8); SideList.SortOrder=Enum.SortOrder.LayoutOrder

local Content = Instance.new("ScrollingFrame")
Content.Size=UDim2.new(1,-(140+30),1,-44)
Content.Position=UDim2.new(0,160,0,36)
Content.BackgroundColor3=Color3.fromRGB(20,20,20)
Content.ScrollBarThickness=6
Content.Parent=Root
local ContentList=Instance.new("UIListLayout", Content)
ContentList.Padding=UDim.new(0,10); ContentList.SortOrder=Enum.SortOrder.LayoutOrder

local function clearContent()
    for _,c in ipairs(Content:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function Header(text)
    local L=Instance.new("TextLabel")
    L.BackgroundTransparency=1
    L.TextXAlignment=Enum.TextXAlignment.Left
    L.Font=Enum.Font.GothamBold; L.TextSize=14
    L.TextColor3=Color3.fromRGB(230,230,230)
    L.Text=text; L.Size=UDim2.new(1,-12,0,20); L.Position=UDim2.new(0,6,0,0)
    L.Parent=Content
end
local function Toggle(label, init, cb)
    local B=Instance.new("TextButton")
    B.Size=UDim2.new(1,-12,0,28)
    B.Position=UDim2.new(0,6,0,0)
    B.BackgroundColor3=Color3.fromRGB(50,50,50)
    B.AutoButtonColor=false
    local val=not not init
    local function paint() B.Text=label..": "..(val and "ON" or "OFF"); B.Font=Enum.Font.Gotham; B.TextSize=14; B.TextColor3=Color3.fromRGB(235,235,235); B.BackgroundColor3= val and Color3.fromRGB(50,140,70) or Color3.fromRGB(50,50,50) end
    paint(); B.Parent=Content
    B.MouseButton1Click:Connect(function() val=not val; paint(); if cb then cb(val) end end)
    return { Set=function(_,v) val=not not v; paint(); if cb then cb(val) end end }
end
local function Slider(label, min, max, def, step, cb)
    local F=Instance.new("Frame"); F.Size=UDim2.new(1,-12,0,40); F.BackgroundColor3=Color3.fromRGB(45,45,45); F.Parent=Content
    local L=Instance.new("TextLabel"); L.BackgroundTransparency=1; L.TextXAlignment=Enum.TextXAlignment.Left; L.Font=Enum.Font.Gotham; L.TextSize=13; L.TextColor3=Color3.fromRGB(235,235,235); L.Text=label; L.Size=UDim2.new(1,-12,0,16); L.Position=UDim2.new(0,6,0,2); L.Parent=F
    local Bar=Instance.new("Frame"); Bar.Size=UDim2.new(1,-12,0,8); Bar.Position=UDim2.new(0,6,0,24); Bar.BackgroundColor3=Color3.fromRGB(28,28,28); Bar.Parent=F
    local Fill=Instance.new("Frame"); Fill.Size=UDim2.new(0,0,1,0); Fill.BackgroundColor3=Color3.fromRGB(90,160,100); Fill.Parent=Bar
    local v=def or min; step=step or ((max-min)<=10 and 0.01 or 1)
    local function set(vn)
        vn=math.clamp(vn,min,max)
        if step and step>0 then vn=math.floor((vn/step)+0.5)*step end
        v=vn
        local pct=(v-min)/math.max(1e-9,(max-min)); Fill.Size=UDim2.new(pct,0,1,0)
        L.Text=string.format("%s: %g", label, v)
        if cb then cb(v) end
    end
    local dragging=false
    local function at(x)
        local w=math.max(1, Bar.AbsoluteSize.X)
        local rel=math.clamp((x - Bar.AbsolutePosition.X)/w,0,1)
        set(min+(max-min)*rel)
    end
    Bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; at(i.Position.X) end end)
    Bar.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then at(i.Position.X) end end)
    task.defer(function() set(v) end)
    return { Set=set }
end
local function addTab(name, onClick)
    local B=Instance.new("TextButton")
    B.Size=UDim2.new(1,-8,0,28); B.BackgroundColor3=Color3.fromRGB(40,40,40); B.AutoButtonColor=false
    B.Text=name; B.Font=Enum.Font.Gotham; B.TextSize=14; B.TextColor3=Color3.fromRGB(235,235,235); B.Parent=Sidebar
    B.MouseButton1Click:Connect(function() for _,c in ipairs(Sidebar:GetChildren()) do if c:IsA("TextButton") then c.BackgroundColor3=Color3.fromRGB(40,40,40) end end; B.BackgroundColor3=Color3.fromRGB(60,60,60); clearContent(); onClick() end)
    return B
end

-- Camlock mini + highlight
local Mini = Instance.new("Frame")
Mini.Size=UDim2.fromOffset(280,130); Mini.Position=UDim2.new(0, 20, 0, 80)
Mini.BackgroundColor3=Color3.fromRGB(25,25,25); Mini.Visible=State.CamLock; Mini.Parent=Screen
local MiniLabel=Instance.new("TextLabel"); MiniLabel.BackgroundTransparency=1; MiniLabel.TextXAlignment=Enum.TextXAlignment.Left; MiniLabel.Font=Enum.Font.Gotham; MiniLabel.TextSize=13; MiniLabel.TextColor3=Color3.fromRGB(230,230,230); MiniLabel.Text="Camlock: "..(State.CamLock and "ON" or "OFF"); MiniLabel.Size=UDim2.new(1,-12,0,20); MiniLabel.Position=UDim2.new(0,6,0,6); MiniLabel.Parent=Mini
local miniBtn=Instance.new("TextButton"); miniBtn.Size=UDim2.new(1,-12,0,26); miniBtn.Position=UDim2.new(0,6,0,30); miniBtn.BackgroundColor3=Color3.fromRGB(50,50,50); miniBtn.Text="Toggle"; miniBtn.Font=Enum.Font.Gotham; miniBtn.TextSize=14; miniBtn.TextColor3=Color3.fromRGB(235,235,235); miniBtn.Parent=Mini
miniBtn.MouseButton1Click:Connect(function() State.CamLock=not State.CamLock; Mini.Visible=State.CamLock; MiniLabel.Text="Camlock: "..(State.CamLock and "ON" or "OFF"); autosave() end)
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

-- Tabs content
addTab("Combat", function()
    Header("Autoblock")
    Toggle("Auto Block", State.AutoBlock, function(v) State.AutoBlock=v; if not v then ReleaseBlock() end; autosave() end)
    Toggle("M1 After Block", State.M1After, function(v) State.M1After=v; autosave() end)
    Toggle("M1 Catch", State.M1Catch, function(v) State.M1Catch=v; autosave() end)
end).BackgroundColor3=Color3.fromRGB(60,60,60) -- select default

addTab("Camlock", function()
    Header("Controls")
    Toggle("Camera Lock", State.CamLock, function(v) State.CamLock=v; Mini.Visible=v; MiniLabel.Text="Camlock: "..(v and "ON" or "OFF"); autosave() end)
    Toggle("Require LoS", State.CamDoLoS, function(v) State.CamDoLoS=v; autosave() end)
end)

addTab("Tuning", function()
    Header("Ranges")
    Slider("Normal Range", 5,120, State.NormalRange, 1, function(v) State.NormalRange=v; autosave() end)
    Slider("Special Range",10,150, State.SpecialRange,1, function(v) State.SpecialRange=v; autosave() end)
    Slider("Skill Range", 10,150, State.SkillRange, 1, function(v) State.SkillRange=v; autosave() end)
    Header("Timings")
    Slider("Skill Hold (s)", 0.2,3, State.SkillHold, 0.05, function(v) State.SkillHold=v; autosave() end)
    Slider("Poke Block Time", 0.08,0.35, State.MinPress, 0.01, function(v) State.MinPress=v; autosave() end)
    Slider("Combo Block Time",0.4,1.0, State.ComboPress,0.01, function(v) State.ComboPress=v; autosave() end)
    Slider("Dash Release", 0.15,0.7, State.DashReleaseTime,0.01, function(v) State.DashReleaseTime=v; autosave() end)
    Slider("Post-dash No-Block",0.1,0.6, State.PostDashNoBlock,0.01, function(v) State.PostDashNoBlock=v; autosave() end)
end)

addTab("Misc", function()
    Header("Performance")
    local originalFog
    Toggle("FPS Boost", State.FPSBoost, function(v)
        State.FPSBoost=v
        if v then
            originalFog=Lighting.FogEnd
            Lighting.FogEnd=9e9
            for _,inst in ipairs(Workspace:GetDescendants()) do
                if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("PostEffect") or inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
                    inst.Enabled=false
                end
            end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        else
            if originalFog then Lighting.FogEnd=originalFog end
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        end
        autosave()
    end)
end)

-- Select default first tab manually
clearContent()
Header("Autoblock")
Toggle("Auto Block", State.AutoBlock, function(v) State.AutoBlock=v; if not v then ReleaseBlock() end; autosave() end)
Toggle("M1 After Block", State.M1After, function(v) State.M1After=v; autosave() end)
Toggle("M1 Catch", State.M1Catch, function(v) State.M1Catch=v; autosave() end)

-- Export for logic
_G.__TSB_Wind = {
    State=State,
    Communicate=Communicate,
    PressBlock=PressBlock,
    ReleaseBlock=ReleaseBlock,
    DashGuard=DashGuard,
    CanReBlock=CanReBlock,
    SetHighlight=setHighlight,
}
-- TSB Autoblock + Camlock Logic (Part 2/2): accurate autoblock, camlock cone + highlight

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local LocalPlayer=Players.LocalPlayer

if not _G.__TSB_Wind then warn("[TSB] UI missing; abort."); return end
local W=_G.__TSB_Wind
local State=W.State
local Communicate=W.Communicate
local PressBlock,ReleaseBlock=W.PressBlock,W.ReleaseBlock
local DashGuard,CanReBlock=W.DashGuard,W.CanReBlock
local SetHighlight=W.SetHighlight

local function now() return os.clock() end

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
    if not State.AutoBlock or not CanReBlock() then return end
    local ch=LocalPlayer.Character; local my=HRPOf(ch); if not my then return end

    local bestThreat,bestDist=nil,1e9
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=LocalPlayer and pl.Character and InLive(pl.Character) then
            local hrp=HRPOf(pl.Character); local hum=pl.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health>0 then
                local dist=(hrp.Position-my.Position).Magnitude
                if dist<=math.max(State.SpecialRange,State.SkillRange,State.NormalRange) then
                    local m=getAnims(hum)
                    if m then
                        local cc=comboCount(m)
                        for _,g in pairs(allIDs) do
                            local n,sp=normalsAndSp(m,g)
                            if cc==2 and n>=2 and dist<=State.SpecialRange then if dist<bestDist then bestThreat={pl,hrp,"combo"}; bestDist=dist end
                            elseif n>0 and dist<=State.NormalRange then if dist<bestDist then bestThreat={pl,hrp,"poke"}; bestDist=dist end
                            elseif sp and dist<=State.SpecialRange and not State.M1Catch then if dist<bestDist then bestThreat={pl,hrp,"special"}; bestDist=dist end end
                        end
                        if hasSkill(m) and dist<=State.SkillRange then if dist<bestDist then bestThreat={pl,hrp,"skill"}; bestDist=dist end end
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
            PressBlock(); task.delay(State.ComboPress, ReleaseBlock)
            if State.M1After then task.delay(0.08,function() TapM1IfClose(hrp) end) end
        elseif tag=="poke" then
            PressBlock(); task.delay(State.MinPress, ReleaseBlock)
            if State.M1After then task.delay(0.08,function() TapM1IfClose(hrp) end) end
        elseif tag=="skill" then
            PressBlock(); task.delay(State.SkillHold, ReleaseBlock)
        end
    else
        ReleaseBlock()
    end

    if (now()-lastActiveAnimAt)>=COMBO_END_GAP then ReleaseBlock() end
end

local lastCatch=0
local function M1CatchTick()
    if not State.M1Catch then return end
    local ch=LocalPlayer.Character; local my=ch and ch:FindFirstChild("HumanoidRootPart"); if not my then return end
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=LocalPlayer and pl.Character and InLive(pl.Character) then
            local hrp=HRPOf(pl.Character); local hum=pl.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                local d1=(hrp.Position-my.Position).Magnitude
                if d1<=30 then
                    local m=getAnims(hum)
                    if m and m[10479335397] then
                        task.delay(0.1,function()
                            local d2=(hrp.Position-my.Position).Magnitude
                            if d2<d1-0.5 and now()-lastCatch>=5 then
                                lastCatch=now()
                                Communicate("LeftClick", true)
                                task.delay(0.2,function() Communicate("LeftClickRelease", true) end)
                            end
                        end)
                        return
                    end
                end
            end
        end
    end
end

local targetHRP
local function HasLoS(fromPos,toPart)
    if not State.CamDoLoS then return true end
    local p=RaycastParams.new(); p.FilterType=Enum.RaycastFilterType.Exclude; p.FilterDescendantsInstances={LocalPlayer.Character}
    local res=Workspace:Raycast(fromPos,(toPart.Position-fromPos),p)
    return not res or res.Instance:IsDescendantOf(toPart.Parent)
end
local function ChooseFrontTarget()
    local cam=Workspace.CurrentCamera; if not cam then return nil end
    local camPos,look=cam.CFrame.Position,cam.CFrame.LookVector
    local cosThresh=math.cos(math.rad(State.CamFovDeg))
    local best,bestDot=nil,cosThresh
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=LocalPlayer and pl.Character and InLive(pl.Character) then
            local hrp=HRPOf(pl.Character); local hum=pl.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health>0 then
                local vec=hrp.Position-camPos; local dist=vec.Magnitude
                if dist<=State.CamMaxDistance then
                    local d=vec.Unit:Dot(look)
                    if d>=bestDot and HasLoS(camPos,hrp) then best,bestDot=hrp,d end
                end
            end
        end
    end
    return best
end
local function CamLockTick()
    if not State.CamLock then targetHRP=nil; SetHighlight(nil); return end
    local cam=Workspace.CurrentCamera; local ch=LocalPlayer.Character; local my=ch and ch:FindFirstChild("HumanoidRootPart")
    if not cam or not my then return end
    if not targetHRP or not targetHRP.Parent then
        targetHRP=ChooseFrontTarget(); SetHighlight(targetHRP and targetHRP.Parent or nil)
    else
        local dir=(targetHRP.Position-cam.CFrame.Position).Unit
        if dir:Dot(cam.CFrame.LookVector) < math.cos(math.rad(State.CamFovDeg+10)) then
            targetHRP=ChooseFrontTarget(); SetHighlight(targetHRP and targetHRP.Parent or nil)
        end
    end
    if not targetHRP then return end
    cam.CFrame=CFrame.lookAt(cam.CFrame.Position,targetHRP.Position)
end

RunService.Heartbeat:Connect(function()
    DashGuard()
    if State.AutoBlock then
        AutoBlockTick()
        M1CatchTick()
    else
        ReleaseBlock()
    end
    CamLockTick()
end)
