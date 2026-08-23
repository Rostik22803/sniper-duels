--[[
    ====================================================================
    OCEL HUB - SNIPER DUELS [HvH Client] (SKELETON ESP & FIXED FOV)
    ====================================================================
    Game: SNIPER DUELS (https://www.roblox.com/games/109397169461300/SNIPER-DUELS)
    Toggle Menu Key: [RightShift]
    Manual AA Keys: Z (Left), X (Back), C (Right)
    ====================================================================
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer and LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

-- Config Flags
local Flags = {
    RageEnabled = false,
    SilentAim = false,
    AimTarget = "Head",
    AimPriority = "Crosshair",
    FOVRadius = 180,
    ShowFOV = true,
    FOVPosition = "Center", -- "Center" or "Mouse"
    FOVColor = Color3.fromRGB(0, 162, 255),
    Prediction = true,
    PredictionFactor = 0.135,
    AutoFire = false,
    WallCheck = true,
    TeamCheck = true,

    AAEnabled = false,
    PitchMode = "Emotionless",
    YawMode = "Spinbot",
    SpinSpeed = 25,
    JitterRange = 45,
    ManualDir = "Back",
    DesyncEnabled = false,
    DesyncMode = "Velocity",

    ESPEnabled = false,
    BoxESP = false,
    BoxColor = Color3.fromRGB(0, 162, 255),
    HealthBar = false,
    NameESP = false,
    DistanceESP = false,
    Tracers = false,
    TracerColor = Color3.fromRGB(255, 0, 100),
    SkeletonESP = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    ChamsEnabled = false,
    ChamsFillColor = Color3.fromRGB(0, 162, 255),
    ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
    ChamsTransparency = 0.5,
    OffscreenArrows = false,
    ArrowColor = Color3.fromRGB(0, 162, 255),

    BHop = false,
    SpeedHack = false,
    SpeedValue = 24,
    FlyEnabled = false,
    FlySpeed = 50,
    Noclip = false,

    HitSound = "Neverlose",
    NoRecoil = false,
    FOVChanger = false,
    FOVValue = 90,
    ThirdPerson = false,
    ThirdPersonDist = 12,
    MenuKey = Enum.KeyCode.RightShift
}

-- Config Management
local FOLDER_NAME = "OcelHub"
local FILE_NAME = FOLDER_NAME .. "/SniperDuels_Config.json"

local function SaveConfig()
    if isfolder and makefolder and not isfolder(FOLDER_NAME) then
        makefolder(FOLDER_NAME)
    end
    if writefile then
        local data = {}
        for k, v in pairs(Flags) do
            if typeof(v) == "Color3" then
                data[k] = {R = v.R, G = v.G, B = v.B, Type = "Color3"}
            elseif typeof(v) == "EnumItem" then
                data[k] = {Name = v.Name, Type = "Enum"}
            else
                data[k] = v
            end
        end
        writefile(FILE_NAME, HttpService:JSONEncode(data))
        return true
    end
    return false
end

local function LoadConfig()
    if isfile and readfile and isfile(FILE_NAME) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(FILE_NAME))
        end)
        if success and type(decoded) == "table" then
            for k, v in pairs(decoded) do
                if type(v) == "table" and v.Type == "Color3" then
                    Flags[k] = Color3.new(v.R, v.G, v.B)
                elseif type(v) == "table" and v.Type == "Enum" then
                    Flags[k] = Enum.KeyCode[v.Name] or Flags[k]
                else
                    Flags[k] = v
                end
            end
            return true
        end
    end
    return false
end
LoadConfig()

-- Helper Functions
local function GetCharacter(player)
    player = player or LocalPlayer
    return player and player.Character
end

local function GetHumanoid(player)
    local char = GetCharacter(player)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart(player)
    local char = GetCharacter(player)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char.PrimaryPart)
end

local function IsAlive(player)
    player = player or LocalPlayer
    local hum = GetHumanoid(player)
    local root = GetRootPart(player)
    return hum and hum.Health > 0 and root ~= nil
end

local function IsEnemy(player)
    if not Flags.TeamCheck then return true end
    if not LocalPlayer.Team then return true end
    return player.Team ~= LocalPlayer.Team
end

-- RAGEBOT MODULE
local RageTarget = nil
local RagePart = nil
local PredictedPos = nil

local FOVCircle = nil
if Drawing and Drawing.new then
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible = false
    FOVCircle.Thickness = 1.5
    FOVCircle.NumSides = 64
    FOVCircle.Filled = false
    FOVCircle.Color = Color3.fromRGB(0, 162, 255)
end

local function IsVisible(origin, targetPart, ignoreChar)
    if not Flags.WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {GetCharacter(), ignoreChar}
    params.IgnoreWater = true
    local res = Workspace:Raycast(origin, targetPart.Position - origin, params)
    return not res or res.Instance:IsDescendantOf(ignoreChar)
end

local function GetFOVCenterPos()
    if Flags.FOVPosition == "Center" then
        local vp = Camera.ViewportSize
        return Vector2.new(vp.X / 2, vp.Y / 2)
    else
        return UserInputService:GetMouseLocation()
    end
end

local function GetBestTarget()
    local fovPos = GetFOVCenterPos()
    local bestTarget, bestPart = nil, nil
    local minScore = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsEnemy(player) and IsAlive(player) then
            local char = player.Character
            local targetPart = char:FindFirstChild(Flags.AimTarget) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
            if targetPart then
                local worldPos = targetPart.Position
                if Flags.Prediction then
                    local vel = targetPart.AssemblyLinearVelocity or targetPart.Velocity or Vector3.zero
                    worldPos = worldPos + (vel * Flags.PredictionFactor)
                end
                local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
                if onScreen then
                    local distToFOV = (Vector2.new(screenPos.X, screenPos.Y) - fovPos).Magnitude
                    if distToFOV <= Flags.FOVRadius then
                        if IsVisible(Camera.CFrame.Position, targetPart, char) then
                            local score = (Flags.AimPriority == "Crosshair" and distToFOV) or (Flags.AimPriority == "Distance" and (worldPos - Camera.CFrame.Position).Magnitude) or 0
                            if score < minScore then
                                minScore = score
                                bestTarget = player
                                bestPart = targetPart
                                PredictedPos = worldPos
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget, bestPart
end

RunService.RenderStepped:Connect(function()
    if FOVCircle then
        FOVCircle.Position = GetFOVCenterPos()
        FOVCircle.Radius = Flags.FOVRadius
        FOVCircle.Color = Flags.FOVColor
        FOVCircle.Visible = Flags.RageEnabled and Flags.ShowFOV
    end
    if Flags.RageEnabled then
        RageTarget, RagePart = GetBestTarget()
    else
        RageTarget, RagePart, PredictedPos = nil, nil, nil
    end
end)

-- Metatable Hooks for Silent Aim
if hookmetamethod then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if Flags.RageEnabled and Flags.SilentAim and RagePart and PredictedPos then
            if method == "Raycast" and self == Workspace then
                if args[1] then
                    args[2] = (PredictedPos - args[1]).Unit * 5000
                    return oldNamecall(self, unpack(args))
                end
            end
            if (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList") and self == Workspace then
                local ray = args[1]
                if ray then
                    args[1] = Ray.new(ray.Origin, (PredictedPos - ray.Origin).Unit * 5000)
                    return oldNamecall(self, unpack(args))
                end
            end
        end
        return oldNamecall(self, ...)
    end)

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if Flags.RageEnabled and Flags.SilentAim and RagePart and PredictedPos and self == Mouse then
            if key == "Hit" then return CFrame.new(PredictedPos) end
            if key == "Target" then return RagePart end
        end
        return oldIndex(self, key)
    end)
end

-- ANTI-AIM MODULE
local spinAngle = 0
local jitterToggle = false

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Z then Flags.ManualDir = "Left" end
    if input.KeyCode == Enum.KeyCode.X then Flags.ManualDir = "Back" end
    if input.KeyCode == Enum.KeyCode.C then Flags.ManualDir = "Right" end
end)

RunService.Heartbeat:Connect(function(dt)
    if not Flags.AAEnabled or not IsAlive() then return end
    local root = GetRootPart()
    local hum = GetHumanoid()
    if not root or not hum then return end

    hum.AutoRotate = false
    local pitchRad, yawRad = 0, 0

    if Flags.PitchMode == "Emotionless" then pitchRad = math.rad(-89)
    elseif Flags.PitchMode == "Up" then pitchRad = math.rad(89)
    elseif Flags.PitchMode == "Jitter" then
        jitterToggle = not jitterToggle
        pitchRad = math.rad(jitterToggle and -89 or 89)
    end

    if Flags.YawMode == "Spinbot" then
        spinAngle = (spinAngle + Flags.SpinSpeed * dt * 50) % 360
        yawRad = math.rad(spinAngle)
    elseif Flags.YawMode == "Jitter" then
        jitterToggle = not jitterToggle
        yawRad = math.rad(jitterToggle and Flags.JitterRange or -Flags.JitterRange)
    elseif Flags.YawMode == "Backward" then
        local look = Camera.CFrame.LookVector
        yawRad = math.atan2(-look.X, -look.Z)
    elseif Flags.YawMode == "Manual" then
        local base = (Flags.ManualDir == "Left" and 90) or (Flags.ManualDir == "Right" and -90) or 180
        local look = Camera.CFrame.LookVector
        yawRad = math.atan2(look.X, look.Z) + math.rad(base)
    end

    if Flags.PitchMode ~= "Disabled" or Flags.YawMode ~= "Disabled" then
        root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yawRad, 0) * CFrame.Angles(pitchRad, 0, 0)
    end

    if Flags.DesyncEnabled then
        local oldVel = root.AssemblyLinearVelocity or root.Velocity
        root.AssemblyLinearVelocity = Vector3.new(math.random(-100, 100) * 10, oldVel.Y, math.random(-100, 100) * 10)
    end
end)

-- VISUALS MODULE (2D BOX, HEALTHBAR, SKELETON, CHAMS)
local ESPObjects = {}
local ChamsObjects = {}

-- Joint pairs for R15 and R6 character rigs
local R15Joints = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"}
}

local R6Joints = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"}
}

local function CreateESP(player)
    local esp = {
        BoxOutline = Drawing.new("Square"),
        Box = Drawing.new("Square"),
        HealthOutline = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        OffscreenArrow = Drawing.new("Triangle"),
        Skeletons = {}
    }

    esp.BoxOutline.Thickness = 3
    esp.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    esp.Box.Thickness = 1
    esp.Box.Color = Flags.BoxColor

    esp.HealthOutline.Thickness = 1
    esp.HealthOutline.Color = Color3.fromRGB(0, 0, 0)
    esp.HealthOutline.Filled = true
    esp.HealthBar.Filled = true

    esp.Name.Size = 13
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Color = Color3.fromRGB(255, 255, 255)

    esp.Distance.Size = 11
    esp.Distance.Center = true
    esp.Distance.Outline = true
    esp.Distance.Color = Color3.fromRGB(200, 200, 200)

    esp.Tracer.Thickness = 1
    esp.Tracer.Color = Flags.TracerColor
    esp.OffscreenArrow.Filled = true
    esp.OffscreenArrow.Color = Flags.ArrowColor

    -- Allocate 14 Drawing lines for Skeleton ESP
    for i = 1, 14 do
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Color = Flags.SkeletonColor
        line.Visible = false
        table.insert(esp.Skeletons, line)
    end

    ESPObjects[player] = esp
    return esp
end

local function UpdateChams(player, char)
    if Flags.ESPEnabled and Flags.ChamsEnabled and IsEnemy(player) then
        local hl = ChamsObjects[player]
        if not hl or hl.Parent ~= char then
            if hl then hl:Destroy() end
            hl = Instance.new("Highlight")
            hl.Name = "OcelChams"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
            ChamsObjects[player] = hl
        end
        hl.FillColor = Flags.ChamsFillColor
        hl.OutlineColor = Flags.ChamsOutlineColor
        hl.FillTransparency = Flags.ChamsTransparency
        hl.Enabled = true
    else
        if ChamsObjects[player] then ChamsObjects[player].Enabled = false end
    end
end

local function UpdateSkeleton(char, esp)
    if not Flags.ESPEnabled or not Flags.SkeletonESP then
        for _, line in ipairs(esp.Skeletons) do line.Visible = false end
        return
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local isR15 = hum and hum.RigType == Enum.HumanoidRigType.R15
    local joints = isR15 and R15Joints or R6Joints

    for i, pair in ipairs(joints) do
        local line = esp.Skeletons[i]
        if line then
            local part1 = char:FindFirstChild(pair[1])
            local part2 = char:FindFirstChild(pair[2])
            if part1 and part2 then
                local pos1, vis1 = Camera:WorldToViewportPoint(part1.Position)
                local pos2, vis2 = Camera:WorldToViewportPoint(part2.Position)
                if vis1 and vis2 then
                    line.From = Vector2.new(pos1.X, pos1.Y)
                    line.To = Vector2.new(pos2.X, pos2.Y)
                    line.Color = Flags.SkeletonColor
                    line.Visible = true
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end
    end

    -- Hide remaining lines not used by current rig
    for i = #joints + 1, #esp.Skeletons do
        esp.Skeletons[i].Visible = false
    end
end

RunService.RenderStepped:Connect(function()
    local viewport = Camera.ViewportSize
    local tracerStart = Vector2.new(viewport.X / 2, viewport.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local esp = ESPObjects[player] or CreateESP(player)
            if Flags.ESPEnabled and IsEnemy(player) and IsAlive(player) then
                local char = player.Character
                local root = GetRootPart(player)
                local head = char:FindFirstChild("Head")
                local hum = GetHumanoid(player)
                if root and head and hum then
                    UpdateChams(player, char)
                    UpdateSkeleton(char, esp)

                    local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

                    if onScreen then
                        local boxHeight = math.abs(headPos.Y - legPos.Y)
                        local boxWidth = boxHeight * 0.65
                        local boxPos = Vector2.new(rootPos.X - (boxWidth / 2), headPos.Y)

                        esp.BoxOutline.Size = Vector2.new(boxWidth, boxHeight)
                        esp.BoxOutline.Position = boxPos
                        esp.BoxOutline.Visible = Flags.BoxESP

                        esp.Box.Size = Vector2.new(boxWidth, boxHeight)
                        esp.Box.Position = boxPos
                        esp.Box.Color = Flags.BoxColor
                        esp.Box.Visible = Flags.BoxESP

                        local hpPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        esp.HealthOutline.Size = Vector2.new(4, boxHeight + 2)
                        esp.HealthOutline.Position = Vector2.new(boxPos.X - 7, boxPos.Y - 1)
                        esp.HealthOutline.Visible = Flags.HealthBar

                        esp.HealthBar.Size = Vector2.new(2, boxHeight * hpPct)
                        esp.HealthBar.Position = Vector2.new(boxPos.X - 6, boxPos.Y + (boxHeight * (1 - hpPct)))
                        esp.HealthBar.Color = Color3.fromHSV(hpPct * 0.3, 1, 1)
                        esp.HealthBar.Visible = Flags.HealthBar

                        esp.Name.Text = player.DisplayName or player.Name
                        esp.Name.Position = Vector2.new(rootPos.X, boxPos.Y - 16)
                        esp.Name.Visible = Flags.NameESP

                        esp.Distance.Text = "[" .. math.floor((root.Position - Camera.CFrame.Position).Magnitude) .. "m]"
                        esp.Distance.Position = Vector2.new(rootPos.X, boxPos.Y + boxHeight + 2)
                        esp.Distance.Visible = Flags.DistanceESP

                        esp.Tracer.From = tracerStart
                        esp.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                        esp.Tracer.Color = Flags.TracerColor
                        esp.Tracer.Visible = Flags.Tracers
                    else
                        esp.BoxOutline.Visible = false
                        esp.Box.Visible = false
                        esp.HealthOutline.Visible = false
                        esp.HealthBar.Visible = false
                        esp.Name.Visible = false
                        esp.Distance.Visible = false
                        esp.Tracer.Visible = false
                    end
                end
            else
                esp.BoxOutline.Visible = false
                esp.Box.Visible = false
                esp.HealthOutline.Visible = false
                esp.HealthBar.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
                esp.Tracer.Visible = false
                for _, line in ipairs(esp.Skeletons) do line.Visible = false end
            end
        end
    end
end)

-- MOVEMENT & CAMERA MODULE
RunService.Heartbeat:Connect(function()
    if Flags.BHop and IsAlive() then
        local hum = GetHumanoid()
        if hum and hum.FloorMaterial ~= Enum.Material.Air then
            hum.Jump = true
        end
    end
end)

RunService.Stepped:Connect(function()
    if not IsAlive() then return end
    local hum = GetHumanoid()
    if hum and Flags.SpeedHack then hum.WalkSpeed = Flags.SpeedValue end
    if Flags.Noclip then
        for _, part in ipairs(GetCharacter():GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if Flags.FOVChanger and Camera then Camera.FieldOfView = Flags.FOVValue end
    if Flags.ThirdPerson and LocalPlayer then
        LocalPlayer.CameraMaxZoomDistance = Flags.ThirdPersonDist
        LocalPlayer.CameraMinZoomDistance = Flags.ThirdPersonDist
    end
end)

-- ====================================================================
-- CUSTOM NEVERLOSE / FATALITY GUI (ROBUST DRAGGING, SLIDERS & BUTTONS)
-- ====================================================================
local parentTarget = (gethui and gethui()) or (syn and syn.protect_gui and CoreGui) or CoreGui or LocalPlayer:WaitForChild("PlayerGui")
if parentTarget:FindFirstChild("OcelHubGui") then parentTarget.OcelHubGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "OcelHubGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = parentTarget

-- Main Container Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 720, 0, 480)
MainFrame.Position = UDim2.new(0.5, -360, 0.5, -240)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(30, 36, 50)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Header Bar
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 45)
Header.BackgroundColor3 = Color3.fromRGB(18, 22, 31)
Header.BorderSizePixel = 0
Header.Active = true
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 8)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Text = "<b>OCEL HUB</b> <font color=\"#00aaff\">| SNIPER DUELS [HvH Client]</font>"
Title.RichText = true
Title.Size = UDim2.new(0, 350, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Control Buttons (Minimize & Close)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "✕"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -38, 0.5, -15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

local MinBtn = Instance.new("TextButton")
MinBtn.Text = "—"
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -74, 0.5, -15)
MinBtn.BackgroundColor3 = Color3.fromRGB(30, 36, 50)
MinBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

-- Floating Open Button (Appears when window is closed/minimized)
local OpenBtn = Instance.new("TextButton")
OpenBtn.Name = "OcelOpenBtn"
OpenBtn.Text = "<b>OCEL HUB</b>"
OpenBtn.RichText = true
OpenBtn.Size = UDim2.new(0, 120, 0, 36)
OpenBtn.Position = UDim2.new(0, 20, 0, 20)
OpenBtn.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
OpenBtn.TextColor3 = Color3.fromRGB(0, 162, 255)
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.TextSize = 13
OpenBtn.Visible = false
OpenBtn.Parent = ScreenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(0, 8)
OpenCorner.Parent = OpenBtn

local OpenStroke = Instance.new("UIStroke")
OpenStroke.Color = Color3.fromRGB(0, 162, 255)
OpenStroke.Thickness = 1.5
OpenStroke.Parent = OpenBtn

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    OpenBtn.Visible = true
end)

local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    MainFrame.Size = isMinimized and UDim2.new(0, 720, 0, 45) or UDim2.new(0, 720, 0, 480)
end)

OpenBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    OpenBtn.Visible = false
end)

-- BULLETPROOF DRAGGING LOGIC
local isDragging = false
local dragStartPos = Vector2.zero
local frameStartPos = UDim2.new()

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStartPos = UserInputService:GetMouseLocation()
        frameStartPos = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local currentMousePos = UserInputService:GetMouseLocation()
        local delta = currentMousePos - dragStartPos
        MainFrame.Position = UDim2.new(
            frameStartPos.X.Scale,
            frameStartPos.X.Offset + delta.X,
            frameStartPos.Y.Scale,
            frameStartPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
    end
end)

-- Sidebar & Content Area
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 160, 1, -45)
Sidebar.Position = UDim2.new(0, 0, 0, 45)
Sidebar.BackgroundColor3 = Color3.fromRGB(16, 19, 27)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0, 5)
SidebarList.Parent = Sidebar

local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop = UDim.new(0, 10)
SidebarPad.PaddingLeft = UDim.new(0, 10)
SidebarPad.PaddingRight = UDim.new(0, 10)
SidebarPad.Parent = Sidebar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -160, 1, -45)
ContentArea.Position = UDim2.new(0, 160, 0, 45)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local Tabs = {}
local function CreateTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundTransparency = 1
    btn.Text = icon .. "  " .. name
    btn.TextColor3 = Color3.fromRGB(150, 155, 170)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = Sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    local btnPad = Instance.new("UIPadding")
    btnPad.PaddingLeft = UDim.new(0, 10)
    btnPad.Parent = btn

    local tabFrame = Instance.new("ScrollingFrame")
    tabFrame.Size = UDim2.new(1, 0, 1, 0)
    tabFrame.BackgroundTransparency = 1
    tabFrame.ScrollBarThickness = 4
    tabFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 162, 255)
    tabFrame.Visible = false
    tabFrame.Parent = ContentArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.Parent = tabFrame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 15)
    pad.PaddingLeft = UDim.new(0, 15)
    pad.PaddingRight = UDim.new(0, 15)
    pad.PaddingBottom = UDim.new(0, 15)
    pad.Parent = tabFrame

    btn.MouseButton1Click:Connect(function()
        for _, t in pairs(Tabs) do
            t.Frame.Visible = false
            t.Button.TextColor3 = Color3.fromRGB(150, 155, 170)
            t.Button.BackgroundTransparency = 1
        end
        tabFrame.Visible = true
        btn.TextColor3 = Color3.fromRGB(0, 162, 255)
        btn.BackgroundTransparency = 0
        btn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
    end)

    Tabs[name] = {Button = btn, Frame = tabFrame}

    -- Select first created tab
    if #Sidebar:GetChildren() == 3 then
        tabFrame.Visible = true
        btn.TextColor3 = Color3.fromRGB(0, 162, 255)
        btn.BackgroundTransparency = 0
        btn.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
    end

    local Builder = {}

    -- TOGGLE BUILDER
    function Builder:AddToggle(text, key)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 36)
        frame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
        frame.Parent = tabFrame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Text = text
        label.Size = UDim2.new(0.7, 0, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(240, 240, 245)
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local tBtn = Instance.new("TextButton")
        tBtn.Text = ""
        tBtn.Size = UDim2.new(0, 42, 0, 22)
        tBtn.Position = UDim2.new(1, -54, 0.5, -11)
        tBtn.BackgroundColor3 = Flags[key] and Color3.fromRGB(0, 162, 255) or Color3.fromRGB(16, 19, 27)
        tBtn.Parent = frame

        local tCorner = Instance.new("UICorner")
        tCorner.CornerRadius = UDim.new(1, 0)
        tCorner.Parent = tBtn

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = Flags[key] and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
        knob.Parent = tBtn

        local kCorner = Instance.new("UICorner")
        kCorner.CornerRadius = UDim.new(1, 0)
        kCorner.Parent = knob

        tBtn.MouseButton1Click:Connect(function()
            Flags[key] = not Flags[key]
            tBtn.BackgroundColor3 = Flags[key] and Color3.fromRGB(0, 162, 255) or Color3.fromRGB(16, 19, 27)
            knob.Position = Flags[key] and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        end)
    end

    -- BULLETPROOF SLIDER BUILDER
    function Builder:AddSlider(text, key, min, max)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 52)
        frame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
        frame.Parent = tabFrame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Text = text
        label.Size = UDim2.new(0.5, 0, 0, 20)
        label.Position = UDim2.new(0, 12, 0, 6)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(240, 240, 245)
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local valLabel = Instance.new("TextLabel")
        valLabel.Text = tostring(Flags[key])
        valLabel.Size = UDim2.new(0.2, 0, 0, 20)
        valLabel.Position = UDim2.new(0.5, 0, 0, 6)
        valLabel.BackgroundTransparency = 1
        valLabel.TextColor3 = Color3.fromRGB(0, 162, 255)
        valLabel.Font = Enum.Font.GothamBold
        valLabel.TextSize = 13
        valLabel.TextXAlignment = Enum.TextXAlignment.Right
        valLabel.Parent = frame

        -- Minus Button
        local MinusBtn = Instance.new("TextButton")
        MinusBtn.Text = "-"
        MinusBtn.Size = UDim2.new(0, 22, 0, 22)
        MinusBtn.Position = UDim2.new(1, -54, 0, 5)
        MinusBtn.BackgroundColor3 = Color3.fromRGB(16, 19, 27)
        MinusBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
        MinusBtn.Font = Enum.Font.GothamBold
        MinusBtn.TextSize = 14
        MinusBtn.Parent = frame

        local mCorner = Instance.new("UICorner")
        mCorner.CornerRadius = UDim.new(0, 4)
        mCorner.Parent = MinusBtn

        -- Plus Button
        local PlusBtn = Instance.new("TextButton")
        PlusBtn.Text = "+"
        PlusBtn.Size = UDim2.new(0, 22, 0, 22)
        PlusBtn.Position = UDim2.new(1, -28, 0, 5)
        PlusBtn.BackgroundColor3 = Color3.fromRGB(16, 19, 27)
        PlusBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
        PlusBtn.Font = Enum.Font.GothamBold
        PlusBtn.TextSize = 14
        PlusBtn.Parent = frame

        local pCorner = Instance.new("UICorner")
        pCorner.CornerRadius = UDim.new(0, 4)
        pCorner.Parent = PlusBtn

        -- Slider Track & Interactor Button
        local TrackBtn = Instance.new("TextButton")
        TrackBtn.Text = ""
        TrackBtn.Size = UDim2.new(1, -24, 0, 10)
        TrackBtn.Position = UDim2.new(0, 12, 0, 34)
        TrackBtn.BackgroundColor3 = Color3.fromRGB(16, 19, 27)
        TrackBtn.Parent = frame

        local trCorner = Instance.new("UICorner")
        trCorner.CornerRadius = UDim.new(1, 0)
        trCorner.Parent = TrackBtn

        local fillPct = math.clamp((Flags[key] - min) / (max - min), 0, 1)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(fillPct, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
        fill.Parent = TrackBtn

        local fCorner = Instance.new("UICorner")
        fCorner.CornerRadius = UDim.new(1, 0)
        fCorner.Parent = fill

        local function UpdateValue(newVal)
            newVal = math.clamp(math.floor(newVal), min, max)
            Flags[key] = newVal
            valLabel.Text = tostring(newVal)
            local pct = (newVal - min) / (max - min)
            fill.Size = UDim2.new(pct, 0, 1, 0)
        end

        MinusBtn.MouseButton1Click:Connect(function()
            UpdateValue(Flags[key] - 1)
        end)

        PlusBtn.MouseButton1Click:Connect(function()
            UpdateValue(Flags[key] + 1)
        end)

        local isSliding = false
        local function UpdateFromMouse()
            local mouseX = UserInputService:GetMouseLocation().X
            local trackX = TrackBtn.AbsolutePosition.X
            local trackWidth = TrackBtn.AbsoluteSize.X
            if trackWidth > 0 then
                local posPct = math.clamp((mouseX - trackX) / trackWidth, 0, 1)
                local calcVal = min + (max - min) * posPct
                UpdateValue(calcVal)
            end
        end

        TrackBtn.MouseButton1Down:Connect(function()
            isSliding = true
            UpdateFromMouse()
        end)

        UserInputService.InputChanged:Connect(function(input)
            if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                UpdateFromMouse()
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isSliding = false
            end
        end)
    end

    -- DROPDOWN BUILDER
    function Builder:AddDropdown(text, key, options)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 38)
        frame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
        frame.Parent = tabFrame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Text = text
        label.Size = UDim2.new(0.5, 0, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(240, 240, 245)
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local sBtn = Instance.new("TextButton")
        sBtn.Text = tostring(Flags[key]) .. " ▼"
        sBtn.Size = UDim2.new(0, 140, 0, 26)
        sBtn.Position = UDim2.new(1, -152, 0.5, -13)
        sBtn.BackgroundColor3 = Color3.fromRGB(16, 19, 27)
        sBtn.TextColor3 = Color3.fromRGB(0, 162, 255)
        sBtn.Font = Enum.Font.GothamMedium
        sBtn.TextSize = 12
        sBtn.Parent = frame

        local sCorner = Instance.new("UICorner")
        sCorner.CornerRadius = UDim.new(0, 4)
        sCorner.Parent = sBtn

        sBtn.MouseButton1Click:Connect(function()
            local idx = 1
            for i, opt in ipairs(options) do if opt == Flags[key] then idx = i break end end
            local nextOpt = options[(idx % #options) + 1]
            Flags[key] = nextOpt
            sBtn.Text = tostring(nextOpt) .. " ▼"
        end)
    end

    -- BUTTON BUILDER
    function Builder:AddButton(text, callback)
        local btnFrame = Instance.new("TextButton")
        btnFrame.Size = UDim2.new(1, -10, 0, 36)
        btnFrame.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
        btnFrame.Text = text
        btnFrame.TextColor3 = Color3.fromRGB(240, 240, 245)
        btnFrame.Font = Enum.Font.GothamBold
        btnFrame.TextSize = 13
        btnFrame.Parent = tabFrame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btnFrame

        btnFrame.MouseButton1Click:Connect(function()
            if callback then callback() end
        end)
    end

    return Builder
end

-- POPULATE TABS & UI
local Rage = CreateTab("Ragebot", "🎯")
Rage:AddToggle("Enable Ragebot", "RageEnabled")
Rage:AddToggle("Silent Aim", "SilentAim")
Rage:AddDropdown("Target Hitbox", "AimTarget", {"Head", "UpperTorso", "HumanoidRootPart"})
Rage:AddDropdown("Target Priority", "AimPriority", {"Crosshair", "Distance", "LowestHP"})
Rage:AddToggle("Velocity Prediction", "Prediction")
Rage:AddSlider("Prediction Factor", "PredictionFactor", 0, 1)
Rage:AddToggle("Show FOV Circle", "ShowFOV")
Rage:AddDropdown("FOV Align Position", "FOVPosition", {"Center", "Mouse"})
Rage:AddSlider("FOV Radius", "FOVRadius", 30, 600)
Rage:AddToggle("Wall Check", "WallCheck")
Rage:AddToggle("Team Check", "TeamCheck")

local AA = CreateTab("Anti-Aim", "🛡️")
AA:AddToggle("Enable Anti-Aim", "AAEnabled")
AA:AddDropdown("Pitch Mode", "PitchMode", {"Emotionless", "Up", "Zero", "Jitter", "Disabled"})
AA:AddDropdown("Yaw Mode", "YawMode", {"Spinbot", "Jitter", "Backward", "Manual", "Disabled"})
AA:AddSlider("Spinbot Speed", "SpinSpeed", 5, 100)
AA:AddSlider("Jitter Range", "JitterRange", 10, 180)
AA:AddToggle("Desync Simulation", "DesyncEnabled")

local Vis = CreateTab("Visuals", "👁️")
Vis:AddToggle("Master ESP Enable", "ESPEnabled")
Vis:AddToggle("2D Bounding Box", "BoxESP")
Vis:AddToggle("Dynamic Health Bar", "HealthBar")
Vis:AddToggle("Player Names", "NameESP")
Vis:AddToggle("Distance Text", "DistanceESP")
Vis:AddToggle("Tracers", "Tracers")
Vis:AddToggle("Skeleton ESP (Bone Lines)", "SkeletonESP")
Vis:AddToggle("Chams (Glow Highlights)", "ChamsEnabled")
Vis:AddToggle("Offscreen Arrows", "OffscreenArrows")

local Mov = CreateTab("Movement", "⚡")
Mov:AddToggle("Auto BunnyHop", "BHop")
Mov:AddToggle("Speed Hack", "SpeedHack")
Mov:AddSlider("WalkSpeed", "SpeedValue", 16, 120)
Mov:AddToggle("Fly Mode", "FlyEnabled")
Mov:AddSlider("Fly Speed", "FlySpeed", 20, 200)
Mov:AddToggle("Noclip", "Noclip")

local MiscTab = CreateTab("Misc & Config", "⚙️")
MiscTab:AddDropdown("Hit Sound", "HitSound", {"None", "Neverlose", "Skeet", "Rust", "Roblox"})
MiscTab:AddToggle("Camera No Recoil", "NoRecoil")
MiscTab:AddToggle("FOV Changer", "FOVChanger")
MiscTab:AddSlider("Field of View", "FOVValue", 70, 120)
MiscTab:AddToggle("Third Person Camera", "ThirdPerson")
MiscTab:AddSlider("Third Person Distance", "ThirdPersonDist", 5, 35)

MiscTab:AddButton("💾 Save Configuration", function()
    if SaveConfig() then
        print("[OcelHub] Config saved!")
    end
end)

MiscTab:AddButton("📂 Load Configuration", function()
    if LoadConfig() then
        print("[OcelHub] Config loaded!")
    end
end)

-- Menu Key Toggle
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Flags.MenuKey then
        MainFrame.Visible = not MainFrame.Visible
        OpenBtn.Visible = not MainFrame.Visible
    end
end)

print("[OcelHub] Skeleton ESP & Fixed FOV Position Loaded!")
