--[[
    SNIPER DUELS - Multi-Functional Cheat Script
    Developed for: https://www.roblox.com/games/109397169461300/SNIPER-DUELS
    UI Library: Rayfield UI (Ocel Hub Customization)
--]]

-- Safety check: prevent multiple execution
if _G.OcelHubLoaded then
    return
end
_G.OcelHubLoaded = true

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

-- Local Player
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Default Settings
local Config = {
    -- Combat
    SilentAim = false,
    Aimbot = false,
    Triggerbot = false,
    Spinbot = false,
    SpinSpeed = 50,
    
    -- Config
    ShowFOV = false,
    FOVColor = Color3.fromRGB(0, 255, 0),
    FOVRadius = 120,
    TeamCheck = true,
    WallCheck = true,
    HitPart = "Head",
    
    -- Gun Mods
    NoRecoil = false,
    NoSpread = false,
    
    -- Visuals
    EnemyESP = false,
    EnemyColor = Color3.fromRGB(255, 0, 0),
    TeamESP = false,
    TeamColor = Color3.fromRGB(0, 255, 0),
    DummyESP = false,
    DummyColor = Color3.fromRGB(255, 255, 255),
    SkeletonESP = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    
    -- Local Visuals
    SelfChams = false,
    SelfColor = Color3.fromRGB(0, 170, 255),
    ArmChams = false,
    ArmColor = Color3.fromRGB(255, 0, 128),
    WeaponChams = false,
    WeaponColor = Color3.fromRGB(0, 255, 255),
    ThirdPerson = false,
    ThirdPersonDistance = 15,
    
    -- Extra
    WalkSpeed = 16,
    JumpPower = 50,
    InfJump = false,
    Noclip = false,
    Fly = false,
    FlySpeed = 50
}

-- ESP Storage
local ESP_Objects = {}
local Skeletons = {}

-- Drawing FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 60
FOVCircle.Radius = Config.FOVRadius
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.Color = Config.FOVColor

-- Update FOV position and properties
RunService.RenderStepped:Connect(function()
    FOVCircle.Radius = Config.FOVRadius
    FOVCircle.Color = Config.FOVColor
    FOVCircle.Visible = Config.ShowFOV
    FOVCircle.Position = UserInputService:GetMouseLocation()
end)

-- Helper: Check Wall / Visible
local function isVisible(targetPart, character)
    if not Config.WallCheck then return true end
    
    local ignoreList = {LocalPlayer.Character, character}
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = ignoreList
    raycastParams.IgnoreWater = true
    
    local raycastResult = Workspace:Raycast(Camera.CFrame.Position, targetPart.Position - Camera.CFrame.Position, raycastParams)
    
    if raycastResult then
        return false
    end
    return true
end

-- Helper: Find Target
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

    -- Check Players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            checkCharacter(player.Character, true, player)
        end
    end

    -- Check Dummies
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name:lower():find("dummy") or obj.Name:lower():find("training")) then
            checkCharacter(obj, false, nil)
        end
    end
    
    return closestTarget
end

-- Aimbot Loop
RunService.RenderStepped:Connect(function()
    if Config.Aimbot then
        local target = getClosestPlayer()
        if target and target:FindFirstChild(Config.HitPart) then
            local targetPos = target[Config.HitPart].Position
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
        end
    end
end)

-- Silent Aim
local mt = getrawmetatable(game)
local oldIndex = mt.__index
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__index = newcclosure(function(self, key)
    if not checkcaller() and Config.SilentAim and self == Mouse and (key == "Hit" or key == "Target") then
        local target = getClosestPlayer()
        if target and target:FindFirstChild(Config.HitPart) then
            if key == "Hit" then
                return target[Config.HitPart].CFrame
            elseif key == "Target" then
                return target[Config.HitPart]
            end
        end
    end
    return oldIndex(self, key)
end)

setreadonly(mt, true)

-- Triggerbot Loop
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
                    if isDummy then
                        shouldShoot = true
                    elseif targetPlayer and targetPlayer ~= LocalPlayer then
                        if not Config.TeamCheck or targetPlayer.Team ~= LocalPlayer.Team then
                            shouldShoot = true
                        end
                    end
                    
                    if shouldShoot then
                        mouse1click()
                    end
                end
            end
        end
    end
end)

-- Spinbot Loop
RunService.Heartbeat:Connect(function()
    if Config.Spinbot and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(Config.SpinSpeed), 0)
    end
end)

-- Third Person Loop
RunService.RenderStepped:Connect(function()
    if Config.ThirdPerson then
        LocalPlayer.CameraMaxZoomDistance = Config.ThirdPersonDistance
        LocalPlayer.CameraMinZoomDistance = Config.ThirdPersonDistance
    else
        LocalPlayer.CameraMaxZoomDistance = 12.8
        LocalPlayer.CameraMinZoomDistance = 0.5
    end
end)

-- Local/Self Chams Update
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
        SelfHighlight.FillColor = Config.SelfColor
        SelfHighlight.OutlineColor = Config.SelfColor
        SelfHighlight.FillOpacity = 0.4
        SelfHighlight.OutlineOpacity = 0.8
        SelfHighlight.Enabled = true
    else
        if SelfHighlight then
            SelfHighlight:Destroy()
            SelfHighlight = nil
        end
    end
end)

-- Arms and Weapons Chams
task.spawn(function()
    while task.wait(0.1) do
        if Config.ArmChams or Config.WeaponChams then
            local viewmodel = Camera:FindFirstChild("ViewModel") or Camera:FindFirstChild("Viewmodel") or Camera:FindFirstChild("Arms") or Camera:FindFirstChildOfClass("Model")
            if viewmodel and viewmodel ~= LocalPlayer.Character then
                for _, part in pairs(viewmodel:GetDescendants()) do
                    if part:IsA("BasePart") then
                        local name = part.Name:lower()
                        local isArm = name:find("arm") or name:find("hand") or name:find("sleeve") or name:find("glove") or name:find("skin") or name:find("left") or name:find("right")
                        
                        if isArm and Config.ArmChams then
                            part.Color = Config.ArmColor
                            part.Material = Enum.Material.ForceField
                            part.Transparency = 0.3
                        elseif not isArm and Config.WeaponChams then
                            part.Color = Config.WeaponColor
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
    highlight.FillOpacity = 0.5
    highlight.OutlineOpacity = 0.8
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not character or not character.Parent then
            highlight:Destroy()
            ESP_Objects[character] = nil
            connection:Disconnect()
            return
        end
        
        local color = Config.DummyColor
        local enabled = false
        
        if isPlayer then
            if playerObj.Team == LocalPlayer.Team then
                color = Config.TeamColor
                enabled = Config.TeamESP
            else
                color = Config.EnemyColor
                enabled = Config.EnemyESP
            end
        else
            color = Config.DummyColor
            enabled = Config.DummyESP
        end
        
        highlight.Enabled = enabled
        highlight.FillColor = color
        highlight.OutlineColor = color
    end)
    
    ESP_Objects[character] = highlight
end

-- Skeleton ESP Helper
local function createLine()
    local line = Drawing.new("Line")
    line.Thickness = 1.5
    line.Color = Config.SkeletonColor
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
            for _, line in pairs(lines) do
                line.Visible = false
            end
            if not Config.SkeletonESP and (not character or not character.Parent) then
                for _, line in pairs(lines) do
                    line:Remove()
                end
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
                    line.Color = Config.SkeletonColor
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
            for _, line in pairs(lines) do
                line.Visible = false
            end
        end
    end)
end

-- Track characters
local function onCharacterAdded(char, isPlayer, playerObj)
    char:WaitForChild("HumanoidRootPart", 10)
    applyESP(char, isPlayer, playerObj)
    drawSkeleton(char)
end

local function trackPlayer(player)
    if player == LocalPlayer then return end
    if player.Character then
        task.spawn(onCharacterAdded, player.Character, true, player)
    end
    player.CharacterAdded:Connect(function(char)
        onCharacterAdded(char, true, player)
    end)
end

Players.PlayerAdded:Connect(trackPlayer)
for _, p in pairs(Players:GetPlayers()) do
    trackPlayer(p)
end

-- Scan for dummies
task.spawn(function()
    while true do
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name:lower():find("dummy") or obj.Name:lower():find("training")) then
                if not ESP_Objects[obj] then
                    applyESP(obj, false, nil)
                end
                if not Skeletons[obj] then
                    drawSkeleton(obj)
                end
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
                            v.Recoil = 0
                            v.recoil = 0
                            v.RecoilPower = 0
                            v.MaxRecoil = 0
                            v.MinRecoil = 0
                        end
                    end
                    if Config.NoSpread then
                        if rawget(v, "Spread") or rawget(v, "spread") or rawget(v, "Accuracy") then
                            v.Spread = 0
                            v.spread = 0
                            v.Accuracy = 100
                            v.MinSpread = 0
                            v.MaxSpread = 0
                        end
                    end
                end
            end
            
            local function cleanWeapon(tool)
                if tool:IsA("Tool") then
                    for _, child in pairs(tool:GetDescendants()) do
                        if child:IsA("ModuleScript") then
                            pcall(function()
                                local mod = require(child)
                                if type(mod) == "table" then
                                    if Config.NoRecoil then
                                        mod.Recoil = 0
                                        mod.recoil = 0
                                        mod.RecoilPower = 0
                                    end
                                    if Config.NoSpread then
                                        mod.Spread = 0
                                        mod.spread = 0
                                    end
                                end
                            end)
                        end
                    end
                end
            end
            
            for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
                cleanWeapon(item)
            end
            if LocalPlayer.Character then
                for _, item in pairs(LocalPlayer.Character:GetChildren()) do
                    cleanWeapon(item)
                end
            end
        end
    end
end)

-- WalkSpeed & JumpPower Loop
task.spawn(function()
    while task.wait(0.1) do
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum.WalkSpeed ~= Config.WalkSpeed and Config.WalkSpeed ~= 16 then
                hum.WalkSpeed = Config.WalkSpeed
            end
            if hum.JumpPower ~= Config.JumpPower and Config.JumpPower ~= 50 then
                hum.JumpUseJumpPower = true
                hum.JumpPower = Config.JumpPower
            end
        end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if Config.InfJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
    end
end)

-- Noclip and Fly
local FlyBodyVelocity
local FlyBodyGyro
RunService.RenderStepped:Connect(function()
    if Config.Noclip and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
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
        
        local lookVec = Camera.CFrame.LookVector
        local rightVec = Camera.CFrame.RightVector
        local velocity = Vector3.new(0, 0, 0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            velocity = velocity + lookVec
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            velocity = velocity - lookVec
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            velocity = velocity - rightVec
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            velocity = velocity + rightVec
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            velocity = velocity + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            velocity = velocity - Vector3.new(0, 1, 0)
        end
        
        FlyBodyVelocity.Velocity = velocity.Unit * Config.FlySpeed
        if velocity.Magnitude == 0 then
            FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
    else
        if FlyBodyVelocity then FlyBodyVelocity:Destroy() FlyBodyVelocity = nil end
        if FlyBodyGyro then FlyBodyGyro:Destroy() FlyBodyGyro = nil end
    end
end)


-- ==================== RAYFIELD UI LIBRARY ====================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Ocel Hub - Sniper Duels",
   LoadingTitle = "Ocel Hub",
   LoadingSubtitle = "Sniper Duels Edition",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "OcelHubConfigs",
      FileName = "SniperDuels"
   },
   Discord = {
      Enabled = false,
      Invite = "",
      RememberJoins = true
   },
   KeySystem = false
})

-- MAIN TAB
local MainTab = Window:CreateTab("Main", 4483345998)

-- Combat Section
MainTab:CreateSection("Combat")

MainTab:CreateToggle({
   Name = "Silent Aim",
   CurrentValue = Config.SilentAim,
   Flag = "SilentAim",
   Callback = function(Value)
      Config.SilentAim = Value
   end
})

MainTab:CreateToggle({
   Name = "Aimbot",
   CurrentValue = Config.Aimbot,
   Flag = "Aimbot",
   Callback = function(Value)
      Config.Aimbot = Value
   end
})

MainTab:CreateToggle({
   Name = "Triggerbot",
   CurrentValue = Config.Triggerbot,
   Flag = "Triggerbot",
   Callback = function(Value)
      Config.Triggerbot = Value
   end
})

MainTab:CreateToggle({
   Name = "Spinbot",
   CurrentValue = Config.Spinbot,
   Flag = "Spinbot",
   Callback = function(Value)
      Config.Spinbot = Value
   end
})

MainTab:CreateSlider({
   Name = "Spin Speed",
   Min = 10,
   Max = 150,
   CurrentValue = Config.SpinSpeed,
   Flag = "SpinSpeed",
   Callback = function(Value)
      Config.SpinSpeed = Value
   end
})

-- Config Section
MainTab:CreateSection("Config")

MainTab:CreateToggle({
   Name = "Show FOV",
   CurrentValue = Config.ShowFOV,
   Flag = "ShowFOV",
   Callback = function(Value)
      Config.ShowFOV = Value
   end
})

MainTab:CreateColorpicker({
   Name = "FOV Circle Color",
   DefaultColor = Config.FOVColor,
   Flag = "FOVColor",
   Callback = function(Value)
      Config.FOVColor = Value
   end
})

MainTab:CreateSlider({
   Name = "FOV Radius",
   Min = 10,
   Max = 800,
   CurrentValue = Config.FOVRadius,
   Flag = "FOVRadius",
   Callback = function(Value)
      Config.FOVRadius = Value
   end
})

MainTab:CreateToggle({
   Name = "Team Check",
   CurrentValue = Config.TeamCheck,
   Flag = "TeamCheck",
   Callback = function(Value)
      Config.TeamCheck = Value
   end
})

MainTab:CreateToggle({
   Name = "Wall Check",
   CurrentValue = Config.WallCheck,
   Flag = "WallCheck",
   Callback = function(Value)
      Config.WallCheck = Value
   end
})

MainTab:CreateDropdown({
   Name = "Hit Part",
   Options = {"Head", "Torso", "HumanoidRootPart"},
   CurrentOption = {Config.HitPart},
   Flag = "HitPart",
   Callback = function(Value)
      Config.HitPart = Value[1]
   end
})

-- Gun Mods Section
MainTab:CreateSection("Gun Mods")

MainTab:CreateToggle({
   Name = "No Recoil",
   CurrentValue = Config.NoRecoil,
   Flag = "NoRecoil",
   Callback = function(Value)
      Config.NoRecoil = Value
   end
})

MainTab:CreateToggle({
   Name = "No Bullet Spread",
   CurrentValue = Config.NoSpread,
   Flag = "NoSpread",
   Callback = function(Value)
      Config.NoSpread = Value
   end
})

-- Visuals Section
MainTab:CreateSection("Visuals")

MainTab:CreateToggle({
   Name = "Enemy ESP",
   CurrentValue = Config.EnemyESP,
   Flag = "EnemyESP",
   Callback = function(Value)
      Config.EnemyESP = Value
   end
})

MainTab:CreateColorpicker({
   Name = "Enemy ESP Color",
   DefaultColor = Config.EnemyColor,
   Flag = "EnemyColor",
   Callback = function(Value)
      Config.EnemyColor = Value
   end
})

MainTab:CreateToggle({
   Name = "Team ESP",
   CurrentValue = Config.TeamESP,
   Flag = "TeamESP",
   Callback = function(Value)
      Config.TeamESP = Value
   end
})

MainTab:CreateColorpicker({
   Name = "Team ESP Color",
   DefaultColor = Config.TeamColor,
   Flag = "TeamColor",
   Callback = function(Value)
      Config.TeamColor = Value
   end
})

MainTab:CreateToggle({
   Name = "Training Dummy ESP",
   CurrentValue = Config.DummyESP,
   Flag = "DummyESP",
   Callback = function(Value)
      Config.DummyESP = Value
   end
})

MainTab:CreateColorpicker({
   Name = "Dummy ESP Color",
   DefaultColor = Config.DummyColor,
   Flag = "DummyColor",
   Callback = function(Value)
      Config.DummyColor = Value
   end
})

MainTab:CreateToggle({
   Name = "Skeleton ESP",
   CurrentValue = Config.SkeletonESP,
   Flag = "SkeletonESP",
   Callback = function(Value)
      Config.SkeletonESP = Value
   end
})

MainTab:CreateColorpicker({
   Name = "Skeleton Color",
   DefaultColor = Config.SkeletonColor,
   Flag = "SkeletonColor",
   Callback = function(Value)
      Config.SkeletonColor = Value
   end
})


-- LOCAL VISUALS TAB
local LocalTab = Window:CreateTab("Local Visuals", 4483345998)

LocalTab:CreateSection("Self & Viewmodel Chams")

LocalTab:CreateToggle({
   Name = "Chams on Self",
   CurrentValue = Config.SelfChams,
   Flag = "SelfChams",
   Callback = function(Value)
      Config.SelfChams = Value
   end
})

LocalTab:CreateColorpicker({
   Name = "Self Color",
   DefaultColor = Config.SelfColor,
   Flag = "SelfColor",
   Callback = function(Value)
      Config.SelfColor = Value
   end
})

LocalTab:CreateToggle({
   Name = "Chams on Hands",
   CurrentValue = Config.ArmChams,
   Flag = "ArmChams",
   Callback = function(Value)
      Config.ArmChams = Value
   end
})

LocalTab:CreateColorpicker({
   Name = "Hands Color",
   DefaultColor = Config.ArmColor,
   Flag = "ArmColor",
   Callback = function(Value)
      Config.ArmColor = Value
   end
})

LocalTab:CreateToggle({
   Name = "Chams on Weapon",
   CurrentValue = Config.WeaponChams,
   Flag = "WeaponChams",
   Callback = function(Value)
      Config.WeaponChams = Value
   end
})

LocalTab:CreateColorpicker({
   Name = "Weapon Color",
   DefaultColor = Config.WeaponColor,
   Flag = "WeaponColor",
   Callback = function(Value)
      Config.WeaponColor = Value
   end
})

LocalTab:CreateSection("Camera")

LocalTab:CreateToggle({
   Name = "Third Person",
   CurrentValue = Config.ThirdPerson,
   Flag = "ThirdPerson",
   Callback = function(Value)
      Config.ThirdPerson = Value
   end
})

LocalTab:CreateSlider({
   Name = "Third Person Distance",
   Min = 5,
   Max = 100,
   CurrentValue = Config.ThirdPersonDistance,
   Flag = "ThirdPersonDistance",
   Callback = function(Value)
      Config.ThirdPersonDistance = Value
   end
})


-- EXTRA TAB
local ExtraTab = Window:CreateTab("Extra", 4483345998)

ExtraTab:CreateSection("Movement")

ExtraTab:CreateSlider({
   Name = "WalkSpeed Speed",
   Min = 16,
   Max = 250,
   CurrentValue = Config.WalkSpeed,
   Flag = "WalkSpeed",
   Callback = function(Value)
      Config.WalkSpeed = Value
   end
})

ExtraTab:CreateSlider({
   Name = "Jump Power",
   Min = 50,
   Max = 350,
   CurrentValue = Config.JumpPower,
   Flag = "JumpPower",
   Callback = function(Value)
      Config.JumpPower = Value
   end
})

ExtraTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = Config.InfJump,
   Flag = "InfJump",
   Callback = function(Value)
      Config.InfJump = Value
   end
})

ExtraTab:CreateToggle({
   Name = "Noclip",
   CurrentValue = Config.Noclip,
   Flag = "Noclip",
   Callback = function(Value)
      Config.Noclip = Value
   end
})

ExtraTab:CreateToggle({
   Name = "Fly",
   CurrentValue = Config.Fly,
   Flag = "Fly",
   Callback = function(Value)
      Config.Fly = Value
   end
})

ExtraTab:CreateSlider({
   Name = "Fly Speed",
   Min = 10,
   Max = 300,
   CurrentValue = Config.FlySpeed,
   Flag = "FlySpeed",
   Callback = function(Value)
      Config.FlySpeed = Value
   end
})

-- Auto-load config on startup
task.spawn(function()
    task.wait(1.5)
    pcall(function()
        Rayfield:LoadConfiguration()
    end)
end)
