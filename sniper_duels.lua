--[[
    OCEL HUB - Sniper Duels
    100% Local Custom UI Framework (No External Loadstring)
    With Toggles, Sliders, Dropdowns, Color Pickers, Config Save/Load & Autoload.
--]]

-- Safety check: prevent duplicate run
if _G.OcelHubLoaded then
    local oldGui = game:GetService("CoreGui"):FindFirstChild("OcelHub") or game:GetService("Players").LocalPlayer:FindFirstChild("OcelHub")
    if oldGui then oldGui:Destroy() end
end
_G.OcelHubLoaded = true

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Local Player
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Config Folder
local CONFIG_FILE = "OcelHub_SniperDuels.json"

-- Default Settings Table
local Config = {
    -- Combat
    SilentAim = false,
    Aimbot = false,
    Triggerbot = false,
    Spinbot = false,
    SpinSpeed = 50,
    
    -- Config
    ShowFOV = false,
    FOVColor = {0, 255, 0},
    FOVRadius = 120,
    TeamCheck = true,
    WallCheck = true,
    HitPart = "Head",
    
    -- Gun Mods
    NoRecoil = false,
    NoSpread = false,
    
    -- Visuals
    EnemyESP = false,
    EnemyColor = {255, 0, 0},
    TeamESP = false,
    TeamColor = {0, 255, 0},
    DummyESP = false,
    DummyColor = {255, 255, 255},
    SkeletonESP = false,
    SkeletonColor = {255, 255, 255},
    
    -- Local Visuals
    SelfChams = false,
    SelfColor = {0, 170, 255},
    ArmChams = false,
    ArmColor = {255, 0, 128},
    WeaponChams = false,
    WeaponColor = {0, 255, 255},
    ThirdPerson = false,
    ThirdPersonDistance = 15,
    
    -- Extra
    WalkSpeed = 16,
    JumpPower = 50,
    InfJump = false,
    Noclip = false,
    Fly = false,
    FlySpeed = 50,
    
    -- Auto Load
    AutoLoad = false
}

-- Convert color table helper
local function toColor3(tbl)
    return Color3.fromRGB(tbl[1], tbl[2], tbl[3])
end

-- Save / Load Functions
local function saveConfig()
    if writefile then
        local success, err = pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
        end)
    end
end

local function loadConfig()
    if readfile and isfile and isfile(CONFIG_FILE) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)
        if success and type(data) == "table" then
            for k, v in pairs(data) do
                Config[k] = v
            end
        end
    end
end

-- Load config on startup if exists
loadConfig()

-- ESP & Visual Handlers
local ESP_Objects = {}
local Skeletons = {}

-- Drawing FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 60
FOVCircle.Radius = Config.FOVRadius
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.Color = toColor3(Config.FOVColor)

-- Update FOV pos
RunService.RenderStepped:Connect(function()
    FOVCircle.Radius = Config.FOVRadius
    FOVCircle.Color = toColor3(Config.FOVColor)
    FOVCircle.Visible = Config.ShowFOV
    FOVCircle.Position = UserInputService:GetMouseLocation()
end)

-- Helper: Wall Check
local function isVisible(targetPart, character)
    if not Config.WallCheck then return true end
    local ignoreList = {LocalPlayer.Character, character}
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = ignoreList
    raycastParams.IgnoreWater = true
    
    local raycastResult = Workspace:Raycast(Camera.CFrame.Position, targetPart.Position - Camera.CFrame.Position, raycastParams)
    return raycastResult == nil
end

-- Helper: Find target
local function getClosestPlayer()
    local closestTarget = nil
    local shortestDistance = math.huge
    local mousePos = UserInputService:GetMouseLocation()
    
    local function checkCharacter(char, isPlayer, playerObj)
        if not char or not char:FindFirstChild("Humanoid") or not char:FindFirstChild(Config.HitPart) then return end
        if char.Humanoid.Health <= 0 then return end
        if isPlayer and Config.TeamCheck and playerObj.Team == LocalPlayer.Team then return end
        
        local hitPart = char[Config.HitPart]
        local screenPos, onScreen = Camera:WorldToViewportPoint(hitPart.Position)
        
        if onScreen then
            local screenPos2D = Vector2.new(screenPos.X, screenPos.Y)
            local mouseDistance = (screenPos2D - mousePos).Magnitude
            
            if mouseDistance <= Config.FOVRadius and mouseDistance < shortestDistance then
                if isVisible(hitPart, char) then
                    shortestDistance = mouseDistance
                    closestTarget = char
                end
            end
        end
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            checkCharacter(player.Character, true, player)
        end
    end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name:lower():find("dummy") or obj.Name:lower():find("training")) then
            checkCharacter(obj, false, nil)
        end
    end
    
    return closestTarget
end

-- Loops
RunService.RenderStepped:Connect(function()
    if Config.Aimbot then
        local target = getClosestPlayer()
        if target and target:FindFirstChild(Config.HitPart) then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target[Config.HitPart].Position)
        end
    end
end)

-- Silent Aim
local mt = getrawmetatable(game)
local oldIndex = mt.__index
setreadonly(mt, false)
mt.__index = newcclosure(function(self, key)
    if not checkcaller() and Config.SilentAim and self == Mouse and (key == "Hit" or key == "Target") then
        local target = getClosestPlayer()
        if target and target:FindFirstChild(Config.HitPart) then
            if key == "Hit" then return target[Config.HitPart].CFrame
            elseif key == "Target" then return target[Config.HitPart] end
        end
    end
    return oldIndex(self, key)
end)
setreadonly(mt, true)

-- Triggerbot
task.spawn(function()
    while task.wait(0.05) do
        if Config.Triggerbot then
            local target = Mouse.Target
            if target and target.Parent then
                local character = target.Parent
                local humanoid = character:FindFirstChildOfClass("Humanoid") or character.Parent:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local targetPlayer = Players:GetPlayerFromCharacter(character) or Players:GetPlayerFromCharacter(character.Parent)
                    local isDummy = character.Name:lower():find("dummy") or character.Parent.Name:lower():find("dummy")
                    
                    local shouldShoot = false
                    if isDummy then shouldShoot = true
                    elseif targetPlayer and targetPlayer ~= LocalPlayer then
                        if not Config.TeamCheck or targetPlayer.Team ~= LocalPlayer.Team then shouldShoot = true end
                    end
                    if shouldShoot then mouse1click() end
                end
            end
        end
    end
end)

-- Spinbot
RunService.Heartbeat:Connect(function()
    if Config.Spinbot and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(Config.SpinSpeed), 0)
    end
end)

-- Camera
RunService.RenderStepped:Connect(function()
    if Config.ThirdPerson then
        LocalPlayer.CameraMaxZoomDistance = Config.ThirdPersonDistance
        LocalPlayer.CameraMinZoomDistance = Config.ThirdPersonDistance
    else
        LocalPlayer.CameraMaxZoomDistance = 12.8
        LocalPlayer.CameraMinZoomDistance = 0.5
    end
end)

-- Self Chams
local SelfHighlight = nil
RunService.RenderStepped:Connect(function()
    if Config.SelfChams and LocalPlayer.Character then
        if not SelfHighlight then
            SelfHighlight = Instance.new("Highlight")
            SelfHighlight.Name = "SelfChams"
            SelfHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            SelfHighlight.Parent = CoreGui
        end
        SelfHighlight.Adornee = LocalPlayer.Character
        SelfHighlight.FillColor = toColor3(Config.SelfColor)
        SelfHighlight.OutlineColor = toColor3(Config.SelfColor)
        SelfHighlight.FillOpacity = 0.4
        SelfHighlight.OutlineOpacity = 0.8
        SelfHighlight.Enabled = true
    else
        if SelfHighlight then SelfHighlight:Destroy() SelfHighlight = nil end
    end
end)

-- Arms / Weapon Chams
task.spawn(function()
    while task.wait(0.2) do
        if Config.ArmChams or Config.WeaponChams then
            local viewmodel = Camera:FindFirstChild("ViewModel") or Camera:FindFirstChild("Viewmodel") or Camera:FindFirstChild("Arms") or Camera:FindFirstChildOfClass("Model")
            if viewmodel and viewmodel ~= LocalPlayer.Character then
                for _, part in pairs(viewmodel:GetDescendants()) do
                    if part:IsA("BasePart") then
                        local name = part.Name:lower()
                        local isArm = name:find("arm") or name:find("hand") or name:find("sleeve") or name:find("glove") or name:find("skin") or name:find("left") or name:find("right")
                        if isArm and Config.ArmChams then
                            part.Color = toColor3(Config.ArmColor)
                            part.Material = Enum.Material.ForceField
                            part.Transparency = 0.3
                        elseif not isArm and Config.WeaponChams then
                            part.Color = toColor3(Config.WeaponColor)
                            part.Material = Enum.Material.ForceField
                            part.Transparency = 0.3
                        end
                    end
                end
            end
        end
    end
end)

-- ESP Functions
local function applyESP(character, isPlayer, playerObj)
    if ESP_Objects[character] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Parent = CoreGui
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not character or not character.Parent then
            highlight:Destroy()
            ESP_Objects[character] = nil
            connection:Disconnect()
            return
        end
        
        local color = toColor3(Config.DummyColor)
        local enabled = false
        
        if isPlayer then
            if playerObj.Team == LocalPlayer.Team then
                color = toColor3(Config.TeamColor)
                enabled = Config.TeamESP
            else
                color = toColor3(Config.EnemyColor)
                enabled = Config.EnemyESP
            end
        else
            color = toColor3(Config.DummyColor)
            enabled = Config.DummyESP
        end
        
        highlight.Enabled = enabled
        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.FillOpacity = 0.5
        highlight.OutlineOpacity = 0.8
    end)
    ESP_Objects[character] = highlight
end

-- Skeleton ESP
local function createLine()
    local line = Drawing.new("Line")
    line.Thickness = 1.5
    line.Color = toColor3(Config.SkeletonColor)
    line.Transparency = 1
    line.Visible = false
    return line
end

local function drawSkeleton(character)
    if Skeletons[character] then return end
    local lines = {
        HeadToTorso = createLine(),
        TorsoToLeftArm = createLine(),
        TorsoToRightArm = createLine(),
        TorsoToLeftLeg = createLine(),
        TorsoToRightLeg = createLine()
    }
    Skeletons[character] = lines
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not character or not character.Parent or not Config.SkeletonESP then
            for _, l in pairs(lines) do l.Visible = false end
            if not Config.SkeletonESP and (not character or not character.Parent) then
                for _, l in pairs(lines) do l:Remove() end
                Skeletons[character] = nil
                connection:Disconnect()
            end
            return
        end
        
        local isR15 = character:FindFirstChild("UpperTorso") ~= nil
        local head = character:FindFirstChild("Head")
        local torso = character:FindFirstChild(isR15 and "UpperTorso" or "Torso")
        local leftArm = character:FindFirstChild(isR15 and "LeftHand" or "Left Arm")
        local rightArm = character:FindFirstChild(isR15 and "RightHand" or "Right Arm")
        local leftLeg = character:FindFirstChild(isR15 and "LeftFoot" or "Left Leg")
        local rightLeg = character:FindFirstChild(isR15 and "RightFoot" or "Right Leg")
        
        if head and torso and leftArm and rightArm and leftLeg and rightLeg then
            local function setLine(line, part1, part2)
                local p1, onScreen1 = Camera:WorldToViewportPoint(part1.Position)
                local p2, onScreen2 = Camera:WorldToViewportPoint(part2.Position)
                if onScreen1 and onScreen2 then
                    line.From = Vector2.new(p1.X, p1.Y)
                    line.To = Vector2.new(p2.X, p2.Y)
                    line.Color = toColor3(Config.SkeletonColor)
                    line.Visible = true
                else
                    line.Visible = false
                end
            end
            setLine(lines.HeadToTorso, head, torso)
            setLine(lines.TorsoToLeftArm, torso, leftArm)
            setLine(lines.TorsoToRightArm, torso, rightArm)
            setLine(lines.TorsoToLeftLeg, torso, leftLeg)
            setLine(lines.TorsoToRightLeg, torso, rightLeg)
        else
            for _, l in pairs(lines) do l.Visible = false end
        end
    end)
end

local function trackPlayer(player)
    if player == LocalPlayer then return end
    if player.Character then task.spawn(applyESP, player.Character, true, player) task.spawn(drawSkeleton, player.Character) end
    player.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart", 10)
        applyESP(char, true, player)
        drawSkeleton(char)
    end)
end

Players.PlayerAdded:Connect(trackPlayer)
for _, p in pairs(Players:GetPlayers()) do trackPlayer(p) end

task.spawn(function()
    while true do
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name:lower():find("dummy") or obj.Name:lower():find("training")) then
                applyESP(obj, false, nil)
                drawSkeleton(obj)
            end
        end
        task.wait(5)
    end
end)

-- Gun Mods Loop
task.spawn(function()
    while task.wait(0.5) do
        if Config.NoRecoil or Config.NoSpread then
            for _, v in pairs(getgc(true)) do
                if type(v) == "table" then
                    if Config.NoRecoil then
                        if rawget(v, "Recoil") or rawget(v, "recoil") or rawget(v, "RecoilPower") then
                            v.Recoil = 0; v.recoil = 0; v.RecoilPower = 0; v.MaxRecoil = 0; v.MinRecoil = 0
                        end
                    end
                    if Config.NoSpread then
                        if rawget(v, "Spread") or rawget(v, "spread") or rawget(v, "Accuracy") then
                            v.Spread = 0; v.spread = 0; v.Accuracy = 100; v.MinSpread = 0; v.MaxSpread = 0
                        end
                    end
                end
            end
        end
    end
end)

-- Speed / Jump
task.spawn(function()
    while task.wait(0.1) do
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum.WalkSpeed ~= Config.WalkSpeed and Config.WalkSpeed ~= 16 then hum.WalkSpeed = Config.WalkSpeed end
            if hum.JumpPower ~= Config.JumpPower and Config.JumpPower ~= 50 then
                hum.JumpUseJumpPower = true
                hum.JumpPower = Config.JumpPower
            end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if Config.InfJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
    end
end)

-- Fly / Noclip
local FlyBodyVelocity, FlyBodyGyro
RunService.RenderStepped:Connect(function()
    if Config.Noclip and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
    
    if Config.Fly and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        if not FlyBodyVelocity then
            FlyBodyVelocity = Instance.new("BodyVelocity")
            FlyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            FlyBodyVelocity.Parent = hrp
        end
        if not FlyBodyGyro then
            FlyBodyGyro = Instance.new("BodyGyro")
            FlyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            FlyBodyGyro.Parent = hrp
        end
        FlyBodyGyro.CFrame = Camera.CFrame
        local velocity = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then velocity = velocity + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then velocity = velocity - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then velocity = velocity - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then velocity = velocity + Camera.CFrame.RightVector end
        FlyBodyVelocity.Velocity = velocity.Unit * Config.FlySpeed
        if velocity.Magnitude == 0 then FlyBodyVelocity.Velocity = Vector3.new(0,0,0) end
    else
        if FlyBodyVelocity then FlyBodyVelocity:Destroy() FlyBodyVelocity = nil end
        if FlyBodyGyro then FlyBodyGyro:Destroy() FlyBodyGyro = nil end
    end
end)

-- ==================== 100% CUSTOM LOCAL UI FRAMEWORK ====================
local OcelHub = Instance.new("ScreenGui")
OcelHub.Name = "OcelHub"
OcelHub.ResetOnSpawn = false
OcelHub.Parent = CoreGui

-- Dragging logic
local function makeDraggable(frame, parent)
    local dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            startPos = parent.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragStart = nil end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragStart then
            local delta = input.Position - dragStart
            parent.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Main Window Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 580, 0, 420)
MainFrame.Position = UDim2.new(0.5, -290, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = OcelHub

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- Top Title Bar (Draggable)
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
makeDraggable(TitleBar, MainFrame)

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

-- Cover bottom corners of titlebar
local CoverFrame = Instance.new("Frame")
CoverFrame.Size = UDim2.new(1, 0, 0, 10)
CoverFrame.Position = UDim2.new(0, 0, 1, -10)
CoverFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
CoverFrame.BorderSizePixel = 0
CoverFrame.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -20, 1, 0)
TitleText.Position = UDim2.new(0, 15, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "Ocel Hub | Sniper Duels"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.Font = Enum.Font.Goblin -- Modern/Sci-Fi font
TitleText.TextSize = 14
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 25, 0, 25)
CloseButton.Position = UDim2.new(1, -35, 0.5, -12)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.TextSize = 14
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseButton

CloseButton.MouseButton1Click:Connect(function()
    OcelHub:Destroy()
    FOVCircle:Remove()
    for _, h in pairs(ESP_Objects) do h:Destroy() end
    for _, l in pairs(Skeletons) do for _, line in pairs(l) do line:Remove() end end
    _G.OcelHubLoaded = nil
end)

-- Sidebar Container
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 140, 1, -35)
Sidebar.Position = UDim2.new(0, 0, 0, 35)
Sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.Parent = Sidebar

-- Content Frame
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -140, 1, -35)
Content.Position = UDim2.new(0, 140, 0, 35)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

-- Tab Frames Table
local Tabs = {}
local TabButtons = {}

local function createTab(name)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 38)
    button.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Text = name
    button.TextColor3 = Color3.fromRGB(180, 180, 180)
    button.Font = Enum.Font.SourceSansSemibold
    button.TextSize = 14
    button.Parent = Sidebar
    
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Color3.fromRGB(50, 50, 70)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Parent = Content
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = page
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = page
    
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)
    
    button.MouseButton1Click:Connect(function()
        for _, t in pairs(Tabs) do t.Visible = false end
        for _, b in pairs(TabButtons) do
            b.BackgroundTransparency = 1
            b.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        page.Visible = true
        button.BackgroundTransparency = 0.5
        button.TextColor3 = Color3.fromRGB(0, 170, 255)
    end)
    
    Tabs[name] = page
    TabButtons[name] = button
    
    return page
end

-- UI Components Creation Helpers
local function createContainer(parent, height)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0.92, 0, 0, height)
    container.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    container.BorderSizePixel = 0
    container.Parent = parent
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = container
    
    return container
end

local function addLabel(parent, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.6, 0, 1, 0)
    l.Position = UDim2.new(0.04, 0, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(240, 240, 240)
    l.Font = Enum.Font.SourceSans
    l.TextSize = 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
end

local function addToggle(parent, text, configKey, callback)
    local container = createContainer(parent, 35)
    addLabel(container, text)
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 45, 0, 20)
    btn.Position = UDim2.new(0.92, -45, 0.5, -10)
    btn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(45, 45, 60)
    btn.Text = ""
    btn.Parent = container
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn
    
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 16, 0, 16)
    dot.Position = Config[configKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.Parent = btn
    
    local dCorner = Instance.new("UICorner")
    dCorner.CornerRadius = UDim.new(1, 0)
    dCorner.Parent = dot
    
    btn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        btn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(45, 45, 60)
        dot:TweenPosition(Config[configKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8), "Out", "Quad", 0.15, true)
        callback(Config[configKey])
        saveConfig()
    end)
end

local function addSlider(parent, text, min, max, configKey, callback)
    local container = createContainer(parent, 45)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0, 20)
    label.Position = UDim2.new(0.04, 0, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(240, 240, 240)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.2, 0, 0, 20)
    valLabel.Position = UDim2.new(0.76, 0, 0, 4)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(Config[configKey])
    valLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    valLabel.Font = Enum.Font.SourceSansSemibold
    valLabel.TextSize = 14
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = container
    
    local slideBar = Instance.new("Frame")
    slideBar.Size = UDim2.new(0.92, 0, 0, 5)
    slideBar.Position = UDim2.new(0.04, 0, 0, 30)
    slideBar.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    slideBar.BorderSizePixel = 0
    slideBar.Parent = container
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((Config[configKey] - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    fill.BorderSizePixel = 0
    fill.Parent = slideBar
    
    local dragging = false
    
    local function update(input)
        local pos = math.clamp((input.Position.X - slideBar.AbsolutePosition.X) / slideBar.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (pos * (max - min)))
        Config[configKey] = val
        valLabel.Text = tostring(val)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        callback(val)
        saveConfig()
    end
    
    slideBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input)
        end
    end)
end

local function addDropdown(parent, text, options, configKey, callback)
    local container = createContainer(parent, 35)
    addLabel(container, text)
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 120, 0, 24)
    btn.Position = UDim2.new(0.92, -120, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    btn.Text = Config[configKey]
    btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 13
    btn.Parent = container
    
    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 4)
    bCorner.Parent = btn
    
    local menu = Instance.new("Frame")
    menu.Size = UDim2.new(1, 0, 0, #options * 25)
    menu.Position = UDim2.new(0, 0, 1, 2)
    menu.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    menu.ZIndex = 10
    menu.Visible = false
    menu.Parent = btn
    
    local mCorner = Instance.new("UICorner")
    mCorner.CornerRadius = UDim.new(0, 4)
    mCorner.Parent = menu
    
    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 25)
        optBtn.Position = UDim2.new(0, 0, 0, (i-1)*25)
        optBtn.BackgroundTransparency = 1
        optBtn.Text = opt
        optBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        optBtn.Font = Enum.Font.SourceSans
        optBtn.TextSize = 13
        optBtn.ZIndex = 11
        optBtn.Parent = menu
        
        optBtn.MouseButton1Click:Connect(function()
            Config[configKey] = opt
            btn.Text = opt
            menu.Visible = false
            callback(opt)
            saveConfig()
        end)
    end
    
    btn.MouseButton1Click:Connect(function()
        menu.Visible = not menu.Visible
    end)
end

local function addColorPicker(parent, text, configKey, callback)
    local container = createContainer(parent, 35)
    addLabel(container, text)
    
    local clr = Config[configKey]
    local colorBox = Instance.new("TextButton")
    colorBox.Size = UDim2.new(0, 22, 0, 22)
    colorBox.Position = UDim2.new(0.92, -22, 0.5, -11)
    colorBox.BackgroundColor3 = Color3.fromRGB(clr[1], clr[2], clr[3])
    colorBox.Text = ""
    colorBox.Parent = container
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = colorBox
    
    -- Very simple cycle picker for simplicity/stability in custom code
    local colors = {
        {255, 0, 0}, {0, 255, 0}, {0, 0, 255}, 
        {255, 255, 0}, {255, 0, 255}, {0, 255, 255}, 
        {255, 255, 255}, {255, 128, 0}, {128, 0, 255}
    }
    
    colorBox.MouseButton1Click:Connect(function()
        local idx = 1
        for i, c in ipairs(colors) do
            if c[1] == Config[configKey][1] and c[2] == Config[configKey][2] and c[3] == Config[configKey][3] then
                idx = i + 1
                break
            end
        end
        if idx > #colors then idx = 1 end
        Config[configKey] = colors[idx]
        colorBox.BackgroundColor3 = toColor3(Config[configKey])
        callback(toColor3(Config[configKey]))
        saveConfig()
    end)
end

-- ==================== BUILD TABS ====================
local mainPage = createTab("Main")
local visualPage = createTab("Visuals")
local localPage = createTab("Local Visuals")
local extraPage = createTab("Extra")
local settingsPage = createTab("Settings")

-- Main Tab Content
addToggle(mainPage, "Silent Aim", "SilentAim", function(v) end)
addToggle(mainPage, "Aimbot", "Aimbot", function(v) end)
addToggle(mainPage, "Triggerbot", "Triggerbot", function(v) end)
addToggle(mainPage, "Spinbot", "Spinbot", function(v) end)
addSlider(mainPage, "Spin Speed", 10, 150, "SpinSpeed", function(v) end)
addToggle(mainPage, "Show FOV", "ShowFOV", function(v) end)
addColorPicker(mainPage, "FOV Circle Color", "FOVColor", function(v) end)
addSlider(mainPage, "FOV Radius", 10, 600, "FOVRadius", function(v) end)
addToggle(mainPage, "Team Check", "TeamCheck", function(v) end)
addToggle(mainPage, "Wall Check", "WallCheck", function(v) end)
addDropdown(mainPage, "Hit Part", {"Head", "Torso", "HumanoidRootPart"}, "HitPart", function(v) end)

-- Gun Mods in Main Tab
addToggle(mainPage, "No Recoil (Без отдачи)", "NoRecoil", function(v) end)
addToggle(mainPage, "No Spread (Без разброса)", "NoSpread", function(v) end)

-- Visuals Tab
addToggle(visualPage, "Enemy ESP (Враги)", "EnemyESP", function(v) end)
addColorPicker(visualPage, "Enemy ESP Color", "EnemyColor", function(v) end)
addToggle(visualPage, "Team ESP (Союзники)", "TeamESP", function(v) end)
addColorPicker(visualPage, "Team ESP Color", "TeamColor", function(v) end)
addToggle(visualPage, "Dummy ESP (Манекены)", "DummyESP", function(v) end)
addColorPicker(visualPage, "Dummy ESP Color", "DummyColor", function(v) end)
addToggle(visualPage, "Skeleton ESP (Скелеты)", "SkeletonESP", function(v) end)
addColorPicker(visualPage, "Skeleton ESP Color", "SkeletonColor", function(v) end)

-- Local Visuals Tab
addToggle(localPage, "Chams on Self (Чамсы на себя)", "SelfChams", function(v) end)
addColorPicker(localPage, "Self Color", "SelfColor", function(v) end)
addToggle(localPage, "Chams on Hands (Чамсы на руки)", "ArmChams", function(v) end)
addColorPicker(localPage, "Hands Color", "ArmColor", function(v) end)
addToggle(localPage, "Chams on Weapon (Чамсы на оружие)", "WeaponChams", function(v) end)
addColorPicker(localPage, "Weapon Color", "WeaponColor", function(v) end)
addToggle(localPage, "Third Person (3 Лицо)", "ThirdPerson", function(v) end)
addSlider(localPage, "Third Person Distance", 5, 100, "ThirdPersonDistance", function(v) end)

-- Extra Tab
addSlider(extraPage, "WalkSpeed Speed", 16, 250, "WalkSpeed", function(v) end)
addSlider(extraPage, "Jump Power", 50, 350, "JumpPower", function(v) end)
addToggle(extraPage, "Infinite Jump", "InfJump", function(v) end)
addToggle(extraPage, "Noclip", "Noclip", function(v) end)
addToggle(extraPage, "Fly", "Fly", function(v) end)
addSlider(extraPage, "Fly Speed", 10, 300, "FlySpeed", function(v) end)

-- Settings Tab
addToggle(settingsPage, "Autoload Config (Автозагрузка)", "AutoLoad", function(v) end)

-- Load UI state according to loaded config
TabButtons["Main"].BackgroundTransparency = 0.5
TabButtons["Main"].TextColor3 = Color3.fromRGB(0, 170, 255)
Tabs["Main"].Visible = true
