-- TSB Autoblock + Camlock (Part 1/2): Local UI, bigger window, working slider defaults and drag

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Prefer gethui for input reliability
local function ui_parent()
    local ok, hui = pcall(gethui)
    if ok and typeof(hui) == "Instance" then return hui end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- Utility
local function round2(x) return math.round(x*100)/100 end

-- Minimal UI kit (window/section/toggle/slider/input/paragraph)
local UI = {}
do
    local Screen = Instance.new("ScreenGui")
    Screen.Name = "TSB_WindLocal"
    Screen.ResetOnSpawn = false
    Screen.IgnoreGuiInset = true
    Screen.Parent = ui_parent()

    function UI.Window(opts)
        local W = Instance.new("Frame")
        W.Name = "TSBWindow"
        W.AnchorPoint = Vector2.new(0.5, 0.5)
        W.Position = UDim2.fromScale(0.5, 0.5)
        W.Size = opts.Size or UDim2.fromOffset(680, 520) -- larger default
        W.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
        W.Active = true
        W.Draggable = true
        W.Parent = Screen

        local Title = Instance.new("TextLabel")
        Title.BackgroundTransparency = 1
        Title.Size = UDim2.new(1, -20, 0, 28)
        Title.Position = UDim2.new(0, 10, 0, 6)
        Title.Font = Enum.Font.GothamBold
        Title.TextSize = 16
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.TextColor3 = Color3.fromRGB(235, 235, 235)
        Title.Text = tostring(opts.Title or "TSB")
        Title.Parent = W

        local Holder = Instance.new("ScrollingFrame")
        Holder.Name = "Body"
        Holder.Size = UDim2.new(1, -20, 1, -44)
        Holder.Position = UDim2.new(0, 10, 0, 36)
        Holder.BackgroundTransparency = 1
        Holder.ScrollBarThickness = 4
        Holder.Parent = W

        local List = Instance.new("UIListLayout")
        List.Padding = UDim.new(0, 10)
        List.SortOrder = Enum.SortOrder.LayoutOrder
        List.Parent = Holder

        local function Section(title)
            local S = Instance.new("Frame")
            S.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            S.Size = UDim2.new(1, 0, 0, 84)
            S.Parent = Holder

            local SL = Instance.new("UIListLayout")
            SL.Padding = UDim.new(0, 6)
            SL.Parent = S

            local H = Instance.new("TextLabel")
            H.BackgroundTransparency = 1
            H.Size = UDim2.new(1, -12, 0, 20)
            H.Position = UDim2.new(0, 12, 0, 6)
            H.Font = Enum.Font.GothamBold
            H.TextSize = 14
            H.TextXAlignment = Enum.TextXAlignment.Left
            H.TextColor3 = Color3.fromRGB(220, 220, 220)
            H.Text = title or "Section"
            H.Parent = S

            local function Toggle(info)
                local B = Instance.new("TextButton")
                B.Size = UDim2.new(1, -16, 0, 28)
                B.Position = UDim2.new(0, 8, 0, 28)
                B.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                B.AutoButtonColor = false
                B.Text = (info.Title or "Toggle") .. ": OFF"
                B.Font = Enum.Font.Gotham
                B.TextSize = 14
                B.TextColor3 = Color3.fromRGB(235, 235, 235)
                B.Parent = S

                local val = info.Default or false
                local function paint()
                    B.Text = (info.Title or "Toggle") .. ": " .. (val and "ON" or "OFF")
                    B.BackgroundColor3 = val and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(50, 50, 50)
                end
                paint()

                B.MouseButton1Click:Connect(function()
                    val = not val
                    paint()
                    if info.Callback then task.spawn(info.Callback, val) end
                end)

                return { Set = function(_, v) val = not not v; paint(); if info.Callback then task.spawn(info.Callback, val) end end }
            end

            local function Slider(info)
                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, -16, 0, 40)
                F.Position = UDim2.new(0, 8, 0, 28)
                F.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
                F.Parent = S

                local L = Instance.new("TextLabel")
                L.BackgroundTransparency = 1
                L.Size = UDim2.new(1, -12, 0, 16)
                L.Position = UDim2.new(0, 6, 0, 2)
                L.Font = Enum.Font.Gotham
                L.TextSize = 13
                L.TextXAlignment = Enum.TextXAlignment.Left
                L.TextColor3 = Color3.fromRGB(235, 235, 235)
                L.Text = info.Title or "Slider"
                L.Parent = F

                local Bar = Instance.new("Frame")
                Bar.Size = UDim2.new(1, -12, 0, 8)
                Bar.Position = UDim2.new(0, 6, 0, 24)
                Bar.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
                Bar.Parent = F

                local Fill = Instance.new("Frame")
                Fill.Size = UDim2.new(0, 0, 1, 0)
                Fill.BackgroundColor3 = Color3.fromRGB(90, 160, 100)
                Fill.Parent = Bar

                local min = info.Min or 0
                local max = info.Max or 100
                local decimals = info.Decimals or ((max - min) <= 10 and 2 or 0)
                local suffix = info.Suffix or ""
                local val = info.Default or min
                local dragging = false

                local function set_value(v)
                    v = math.clamp(v, min, max)
                    val = v
                    local w = math.max(1, Bar.AbsoluteSize.X)
                    local pct = (val - min) / math.max(1e-9, (max - min))
                    Fill.Size = UDim2.new(pct, 0, 1, 0)
                    local shown = decimals > 0 and string.format("%0."..decimals.."f", val) or tostring(math.floor(val + 0.5))
                    L.Text = string.format("%s: %s%s", info.Title or "Slider", shown, suffix)
                    if info.Callback then task.spawn(info.Callback, val) end
                end

                local function set_from_x(x)
                    local w = math.max(1, Bar.AbsoluteSize.X)
                    local rel = math.clamp((x - Bar.AbsolutePosition.X) / w, 0, 1)
                    local v = min + (max - min) * rel
                    if decimals > 0 then v = round2(v) end
                    set_value(v)
                end

                Bar.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        set_from_x(i.Position.X)
                    end
                end)
                Bar.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)
                UserInputService.InputChanged:Connect(function(i)
                    if not dragging then return end
                    if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                        set_from_x(i.Position.X)
                    end
                end)

                -- Apply default immediately so it doesn't show 0
                task.defer(function() set_value(val) end)

                return { Set = set_value }
            end

            local function Input(info)
                local F = Instance.new("Frame")
                F.Size = UDim2.new(1, -16, 0, 34)
                F.Position = UDim2.new(0, 8, 0, 28)
                F.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
                F.Parent = S

                local Box = Instance.new("TextBox")
                Box.Size = UDim2.new(1, -12, 1, -6)
                Box.Position = UDim2.new(0, 6, 0, 3)
                Box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                Box.TextColor3 = Color3.fromRGB(235, 235, 235)
                Box.PlaceholderText = info.Title or "Input"
                Box.Text = tostring(info.Value or "")
                Box.Font = Enum.Font.Gotham
                Box.TextSize = 14
                Box.Parent = F

                Box.FocusLost:Connect(function()
                    local t = Box.Text
                    if info.Numeric then
                        local n = tonumber(t)
                        if n and info.Callback then task.spawn(info.Callback, n) end
                    else
                        if info.Callback then task.spawn(info.Callback, t) end
                    end
                end)
                return { Set = function(_, v) Box.Text = tostring(v) end }
            end

            local function Paragraph(info)
                local L = Instance.new("TextLabel")
                L.BackgroundTransparency = 1
                L.Size = UDim2.new(1, -16, 0, 20)
                L.Position = UDim2.new(0, 8, 0, 28)
                L.Font = Enum.Font.Gotham
                L.TextSize = 13
                L.TextXAlignment = Enum.TextXAlignment.Left
                L.TextColor3 = Color3.fromRGB(210, 210, 210)
                L.Text = (info.Title or "") .. " " .. (info.Desc or "")
                L.Parent = S
                return { SetDesc = function(_, t) L.Text = t end }
            end

            return { Toggle = Toggle, Slider = Slider, Input = Input, Paragraph = Paragraph }
        end

        return { Section = Section }
    end
    UI._Screen = Screen
end

-- Build window and sections
local Window = UI.Window({ Title = "TSB Autoblock + Camlock", Size = UDim2.fromOffset(720, 540) })
local S_Auto  = Window.Section("Autoblock")
local S_M1    = Window.Section("M1 Helpers")
local S_Cam   = Window.Section("Camlock")
local S_Range = Window.Section("Ranges")
local S_Time  = Window.Section("Timings")
local S_View  = Window.Section("View Cone")

-- Defaults from original script
local State = {
    AutoBlock=false, M1After=false, M1Catch=false,
    NormalRange=30, SpecialRange=50, SkillRange=50, SkillHold=1.2,
    MinPress=0.15, ComboPress=0.70, DashReleaseTime=0.35, PostDashNoBlock=0.20,
    CamLock=false, CamFovDeg=35, CamMaxDistance=120, CamDoLoS=true,
}

-- Communicate + block guard
local function Communicate(goal, keycode, mobile)
    local c = LocalPlayer.Character; if not c then return end
    local r = c:FindFirstChild("Communicate"); if not r then return end
    r:FireServer({ Goal=goal, Key=keycode, Mobile=mobile or nil })
end
local blocking, lastDashAt = false, 0
local function PressBlock() if blocking then return end blocking=true; Communicate("KeyPress", Enum.KeyCode.F) end
local function ReleaseBlock() if not blocking then return end blocking=false; Communicate("KeyRelease", Enum.KeyCode.F) end
local function IsDashing()
    local c=LocalPlayer.Character; local hrp=c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return false end
    local v=hrp.Velocity; return Vector3.new(v.X,0,v.Z).Magnitude>38
end
local function DashGuard() if IsDashing() then lastDashAt=os.clock(); ReleaseBlock(); return end if os.clock()-lastDashAt<=State.DashReleaseTime then ReleaseBlock() end end
local function CanReBlock() return (os.clock()-lastDashAt)>State.PostDashNoBlock end

-- Controls with defaults applied
S_Auto.Toggle({ Title="Auto Block", Default=false, Callback=function(v) State.AutoBlock=v; if not v then ReleaseBlock() end end })
S_M1.Toggle({ Title="M1 After Block", Default=false, Callback=function(v) State.M1After=v end })
S_M1.Toggle({ Title="M1 Catch", Default=false, Callback=function(v) State.M1Catch=v end })

local slNormal = S_Range.Slider({ Title="Normal Range", Min=5, Max=120, Default=State.NormalRange, Suffix=" studs", Callback=function(v) State.NormalRange=v end })
local slSpecial= S_Range.Slider({ Title="Special Range", Min=10, Max=150, Default=State.SpecialRange, Suffix=" studs", Callback=function(v) State.SpecialRange=v end })
local slSkill  = S_Range.Slider({ Title="Skill Range", Min=10, Max=150, Default=State.SkillRange, Suffix=" studs", Callback=function(v) State.SkillRange=v end })
local inHold   = S_Time.Input({ Title="Skill Hold (s)", Value=tostring(State.SkillHold), Numeric=true, Callback=function(n) if n and n>0 then State.SkillHold=n end end })

local slPoke   = S_Time.Slider({ Title="Poke Block Time", Min=0.08, Max=0.35, Default=State.MinPress, Decimals=2, Suffix=" s", Callback=function(v) State.MinPress=v end })
local slCombo  = S_Time.Slider({ Title="Combo Block Time", Min=0.4, Max=1.0, Default=State.ComboPress, Decimals=2, Suffix=" s", Callback=function(v) State.ComboPress=v end })
local slDRel   = S_Time.Slider({ Title="Dash Release", Min=0.15, Max=0.7, Default=State.DashReleaseTime, Decimals=2, Suffix=" s", Callback=function(v) State.DashReleaseTime=v end })
local slPost   = S_Time.Slider({ Title="Post-dash No-Block", Min=0.1, Max=0.6, Default=State.PostDashNoBlock, Decimals=2, Suffix=" s", Callback=function(v) State.PostDashNoBlock=v end })

local tCam     = S_Cam.Toggle({ Title="Camera Lock", Default=false, Callback=function(v) State.CamLock=v end })
local pMini    = Window.Section("Camlock Status").Paragraph({ Title="Target:", Desc="None" })

-- Export
_G.__TSB_Wind = {
    State = State,
    PressBlock = PressBlock,
    ReleaseBlock = ReleaseBlock,
    DashGuard = DashGuard,
    CanReBlock = CanReBlock,
    MiniLabel = pMini,
    Communicate = Communicate,
}
-- TSB Autoblock + Camlock (Part 2/2): Logic core

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local LocalPlayer=Players.LocalPlayer

if not _G.__TSB_Wind or type(_G.__TSB_Wind)~="table" then
    warn("[TSB] UI not initialized; skipping logic.")
    return
end

local W=_G.__TSB_Wind
local State=W.State
local PressBlock,ReleaseBlock=W.PressBlock,W.ReleaseBlock
local DashGuard,CanReBlock=W.DashGuard,W.CanReBlock
local MiniLabel=W.MiniLabel
local Communicate=W.Communicate
local function now() return os.clock() end

-- IDs from original
local comboIDs={10480793962,10480796021}
local allIDs={
    Saitama={10469493270,10469630950,10469639222,10469643643,special=10479335397},
    Garou  ={13532562418,13532600125,13532604085,13294471966,special=10479335397},
    Cyborg ={13491635433,13296577783,13295919399,13295936866,special=10479335397},
    Sonic  ={13370310513,13390230973,13378751717,13378708199,special=13380255751},
    Metal  ={14004222985,13997092940,14001963401,14136436157,special=13380255751},
    Blade  ={15259161390,15240216931,15240176873,15162694192,special=13380255751},
    Tatsu  ={16515503507,16515520431,16515448089,16552234590,special=10479335397},
    Dragon ={17889458563,17889461810,17889471098,17889290569,special=10479335397},
    Tech   ={123005629431309,100059874351664,104895379416342,134775406437626,special=10479335397},
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

-- Safe animation scan
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

local function TapM1IfClose(hrp)
    local ch=LocalPlayer.Character; local my=ch and ch:FindFirstChild("HumanoidRootPart")
    if not my or not hrp then return end
    if (hrp.Position-my.Position).Magnitude<=10 then
        Communicate("LeftClick", true)
        task.delay(0.25,function() Communicate("LeftClickRelease", true) end)
    end
end

local function AutoBlockTick()
    if not State.AutoBlock or not CanReBlock() then return end
    local ch=LocalPlayer.Character; local my=HRPOf(ch); if not my then return end
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=LocalPlayer and pl.Character and InLive(pl.Character) then
            local hrp=HRPOf(pl.Character); local hum=pl.Character:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then continue end
            local dist=(hrp.Position-my.Position).Magnitude
            if dist>math.max(State.SpecialRange,State.SkillRange,State.NormalRange) then continue end
            local m=getAnims(hum); if not m then continue end

            local cc=comboCount(m)
            for _,g in pairs(allIDs) do
                local n,sp=normalsAndSp(m,g)
                if cc==2 and n>=2 and dist<=State.SpecialRange then
                    PressBlock(); task.delay(State.ComboPress, ReleaseBlock)
                    if State.M1After then task.delay(0.08,function() TapM1IfClose(hrp) end) end
                    return
                elseif n>0 and dist<=State.NormalRange then
                    PressBlock(); task.delay(State.MinPress, ReleaseBlock)
                    if State.M1After then task.delay(0.08,function() TapM1IfClose(hrp) end) end
                    return
                elseif sp and dist<=State.SpecialRange and not State.M1Catch then
                    PressBlock(); task.delay(State.ComboPress, ReleaseBlock)
                    return
                end
            end
            if hasSkill(m) and dist<=State.SkillRange then
                PressBlock(); task.delay(State.SkillHold, ReleaseBlock)
                return
            end
        end
    end
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

-- Camlock: camera cone + LoS
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
local function UpdateMini(hrp)
    if not MiniLabel then return end
    if hrp and hrp.Parent then
        local pl=Players:GetPlayerFromCharacter(hrp.Parent)
        MiniLabel:SetDesc(pl and ("Target: "..pl.DisplayName) or ("Target: "..hrp.Parent.Name))
    else
        MiniLabel:SetDesc("None")
    end
end
local function CamLockTick()
    if not State.CamLock then return end
    local cam=Workspace.CurrentCamera; local ch=LocalPlayer.Character; local my=ch and ch:FindFirstChild("HumanoidRootPart")
    if not cam or not my then return end
    if not targetHRP or not targetHRP.Parent then
        targetHRP=ChooseFrontTarget(); UpdateMini(targetHRP)
    else
        local camPos,look=cam.CFrame.Position,cam.CFrame.LookVector
        local dir=(targetHRP.Position-camPos).Unit
        if dir:Dot(look)<math.cos(math.rad(State.CamFovDeg+10)) then
            targetHRP=ChooseFrontTarget(); UpdateMini(targetHRP)
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
