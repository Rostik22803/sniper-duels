--[[
    OCEL HUB - Sniper Duels
    100% Local Custom UI Framework (No External Loadstring)
    Universal Engine-Native ESP (ScreenGui + Highlights, 100% Executor Compatibility)
--]]

-- Safety check: prevent duplicate run
if _G.OcelHubLoaded then
    local oldGui = game:GetService("CoreGui"):FindFirstChild("OcelHub") or (game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:FindFirstChild("OcelHub"))
    if oldGui then oldGui:Destroy() end
    local oldEsp = game:GetService("CoreGui"):FindFirstChild("OcelESP_Gui") or (game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer:FindFirstChild("OcelESP_Gui"))
    if oldEsp then oldEsp:Destroy() end
    if _G.ESP_Connections then
        for _, conn in pairs(_G.ESP_Connections) do pcall(function() conn:Disconnect() end) end
    end
    if _G.ESP_Drawings then
        for _, draw in pairs(_G.ESP_Drawings) do pcall(function() draw:Remove() end) end
    end
    if _G.ESP_Highlights then
        for _, hl in pairs(_G.ESP_Highlights) do pcall(function() hl:Destroy() end) end
    end
end
_G.OcelHubLoaded = true
_G.ESP_Connections = {}
_G.ESP_Drawings = {}
_G.ESP_Highlights = {}

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
    TeamCheck = false,
    WallCheck = true,
    HitPart = "Head",
    
    -- Gun Mods
    NoRecoil = false,
    NoSpread = false,
    
    -- Visuals
    BoxESP = false,
    HealthESP = false,
    NameESP = false,
    ChamsESP = true,
    ChamsStyle = "Highlight (Свечение)", -- Highlight, Box 2D, Filled Box, Corner Box, 3D Box
    EnemyESP = true,
    EnemyColor = {255, 50, 50},
    TeamESP = false,
    TeamColor = {50, 255, 50},
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
    AutoLoad = false,
    ActiveConfigName = "default"
}

-- Convert color table helper
local function toColor3(tbl)
    if type(tbl) == "table" then
        return Color3.fromRGB(tbl[1] or 255, tbl[2] or 255, tbl[3] or 255)
    elseif typeof(tbl) == "Color3" then
        return tbl
    end
    return Color3.fromRGB(255, 255, 255)
end

-- Save / Load Functions
local function getFileName(name)
    return "OcelHub_" .. tostring(name) .. ".json"
end

local function saveConfig(customName)
    local name = customName or Config.ActiveConfigName
    if writefile then
        pcall(function()
            writefile(getFileName(name), HttpService:JSONEncode(Config))
        end)
    end
end

local function loadConfig(customName)
    local name = customName or Config.ActiveConfigName
    pcall(function()
        if readfile and isfile and isfile(getFileName(name)) then
            local data = HttpService:JSONDecode(readfile(getFileName(name)))
            if type(data) == "table" then
                for k, v in pairs(data) do
                    Config[k] = v
                end
            end
        end
    end)
end

loadConfig("default")

-- ==================== SCREEN GUI CONTAINERS ====================
local GuiParent = CoreGui
pcall(function()
    if not CoreGui:IsA("LayerCollector") then
        GuiParent = LocalPlayer:WaitForChild("PlayerGui")
    end
end)

local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "OcelESP_Gui"
ESPGui.ResetOnSpawn = false
ESPGui.DisplayOrder = 10
pcall(function() ESPGui.Parent = GuiParent end)
if not ESPGui.Parent then pcall(function() ESPGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end) end

-- FOV Circle (Native ScreenGui + Drawing Fallback)
local FOVFrame = Instance.new("Frame")
FOVFrame.Name = "FOVCircle"
FOVFrame.BackgroundTransparency = 1
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVFrame.Size = UDim2.new(0, Config.FOVRadius * 2, 0, Config.FOVRadius * 2)
FOVFrame.Visible = Config.ShowFOV
FOVFrame.Parent = ESPGui

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Thickness = 1.5
FOVStroke.Color = toColor3(Config.FOVColor)
FOVStroke.Parent = FOVFrame

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVFrame

RunService.RenderStepped:Connect(function()
    if FOVFrame then
        FOVFrame.Visible = Config.ShowFOV
        FOVFrame.Size = UDim2.new(0, Config.FOVRadius * 2, 0, Config.FOVRadius * 2)
        FOVStroke.Color = toColor3(Config.FOVColor)
    end
end)

-- Helper: Wall Check
local function isVisible(targetPart, character)
    if not Config.WallCheck then return true end
    
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, character, Camera}
    raycastParams.IgnoreWater = true
    
    local hit = Workspace:Raycast(origin, direction, raycastParams)
    if hit and hit.Instance and hit.Instance.CanCollide and hit.Instance.Transparency < 0.8 then
        return false
    end
    return true
end

-- Helper: Find target
local function getClosestPlayer()
    local closestTarget = nil
    local shortestDistance = math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    local function checkCharacter(char, isPlayer, playerObj)
        if not char or not char:FindFirstChild("Humanoid") or not char:FindFirstChild(Config.HitPart) then return end
        if char.Humanoid.Health <= 0 then return end
        
        if isPlayer and Config.TeamCheck and playerObj and playerObj.Team ~= nil and LocalPlayer.Team ~= nil and playerObj.Team == LocalPlayer.Team then 
            return 
        end
        
        local hitPart = char[Config.HitPart]
        local screenPos, onScreen = Camera:WorldToViewportPoint(hitPart.Position)
        
        if onScreen and screenPos.Z > 0 then
            local screenPos2D = Vector2.new(screenPos.X, screenPos.Y)
            local mouseDistance = (screenPos2D - center).Magnitude
            
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

-- Aimbot Loop
RunService.RenderStepped:Connect(function()
    if Config.Aimbot then
        local target = getClosestPlayer()
        if target and target:FindFirstChild(Config.HitPart) then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target[Config.HitPart].Position)
        end
    end
end)

-- Silent Aim
pcall(function()
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
end)

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
                        local isTeam = targetPlayer.Team ~= nil and LocalPlayer.Team ~= nil and targetPlayer.Team == LocalPlayer.Team
                        if not Config.TeamCheck or not isTeam then shouldShoot = true end
                    end
                    if shouldShoot and mouse1click then mouse1click() end
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
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMaxZoomDistance = Config.ThirdPersonDistance
        LocalPlayer.CameraMinZoomDistance = Config.ThirdPersonDistance
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
            pcall(function() SelfHighlight.Parent = GuiParent end)
            table.insert(_G.ESP_Highlights, SelfHighlight)
        end
        SelfHighlight.Adornee = LocalPlayer.Character
        SelfHighlight.FillColor = toColor3(Config.SelfColor)
        SelfHighlight.OutlineColor = toColor3(Config.SelfColor)
        SelfHighlight.FillOpacity = 0.4
        SelfHighlight.OutlineOpacity = 0.8
        SelfHighlight.Enabled = true
    else
        if SelfHighlight then SelfHighlight.Enabled = false end
    end
end)

-- ==================== ADVANCED WEAPON & ARM CHAMS ====================
local WeaponHighlight = nil
local ArmHighlight = nil
local OriginalViewmodelProps = {}

local function applyPartChams(part, color)
    if not OriginalViewmodelProps[part] then
        OriginalViewmodelProps[part] = {
            Color = part.Color,
            Material = part.Material,
            Transparency = part.Transparency
        }
    end
    part.Color = color
    part.Material = Enum.Material.ForceField
    part.Transparency = 0.25
end

local function restorePart(part)
    local orig = OriginalViewmodelProps[part]
    if orig then
        part.Color = orig.Color
        part.Material = orig.Material
        part.Transparency = orig.Transparency
        OriginalViewmodelProps[part] = nil
    end
end

task.spawn(function()
    while task.wait(0.08) do
        local armColor = toColor3(Config.ArmColor)
        local weaponColor = toColor3(Config.WeaponColor)
        
        -- Collect all viewmodel candidates across Camera, Workspace, and Character
        local foundModels = {}
        for _, child in pairs(Camera:GetChildren()) do
            if child:IsA("Model") and child ~= LocalPlayer.Character then
                table.insert(foundModels, child)
            end
        end
        
        for _, name in pairs({"Arms", "ViewModel", "Viewmodel", "FPSArms", "Weapon", LocalPlayer.Name .. "Arms", LocalPlayer.Name .. "_ViewModel"}) do
            local obj = Workspace:FindFirstChild(name)
            if obj and obj:IsA("Model") and obj ~= LocalPlayer.Character then
                table.insert(foundModels, obj)
            end
        end
        
        -- Check equipped tool in Character
        if LocalPlayer.Character then
            for _, item in pairs(LocalPlayer.Character:GetChildren()) do
                if item:IsA("Tool") or (item:IsA("Model") and item.Name:lower():find("gun") or item.Name:lower():find("sniper") or item.Name:lower():find("weapon")) then
                    table.insert(foundModels, item)
                end
            end
        end
        
        -- Process parts
        for _, model in pairs(foundModels) do
            for _, part in pairs(model:GetDescendants()) do
                if part:IsA("BasePart") then
                    local name = part.Name:lower()
                    local parentName = part.Parent and part.Parent.Name:lower() or ""
                    local isArm = name:find("arm") or name:find("hand") or name:find("sleeve") or name:find("glove") or name:find("skin") or name:find("left") or name:find("right") or parentName:find("arm") or parentName:find("hand")
                    
                    if isArm and Config.ArmChams then
                        applyPartChams(part, armColor)
                    elseif not isArm and Config.WeaponChams then
                        applyPartChams(part, weaponColor)
                    else
                        restorePart(part)
                    end
                end
            end
        end
    end
end)

-- ==================== 100% NATIVE SCREEN GUI ESP SYSTEM ====================
local ESP_Entries = {}

local function setGuiLine(lineFrame, p1_2d, p2_2d, color, thickness)
    local diff = p2_2d - p1_2d
    local dist = diff.Magnitude
    if dist < 1 then
        lineFrame.Visible = false
        return
    end
    local center = (p1_2d + p2_2d) / 2
    local angle = math.deg(math.atan2(diff.Y, diff.X))
    
    lineFrame.Size = UDim2.new(0, dist, 0, thickness or 2)
    lineFrame.Position = UDim2.new(0, center.X - dist / 2, 0, center.Y - (thickness or 2) / 2)
    lineFrame.Rotation = angle
    lineFrame.BackgroundColor3 = color
    lineFrame.Visible = true
end

local function cleanupESPEntry(entry)
    if not entry then return end
    if entry.Connection then
        pcall(function() entry.Connection:Disconnect() end)
    end
    if entry.MainContainer then
        pcall(function() entry.MainContainer:Destroy() end)
    end
    if entry.Highlight then
        pcall(function() entry.Highlight:Destroy() end)
    end
end

local function createESP(character, isPlayer, playerObj)
    if ESP_Entries[character] then return end
    
    local hrp = character:WaitForChild("HumanoidRootPart", 5) or character:WaitForChild("Torso", 5) or character:WaitForChild("UpperTorso", 5)
    local hum = character:WaitForChild("Humanoid", 5)
    if not hrp or not hum then return end
    
    -- Main container inside ScreenGui
    local container = Instance.new("Folder")
    container.Name = "ESP_" .. character.Name
    container.Parent = ESPGui
    
    -- 2D Box Frame
    local boxFrame = Instance.new("Frame")
    boxFrame.Name = "Box"
    boxFrame.BackgroundTransparency = 1
    boxFrame.BorderSizePixel = 0
    boxFrame.Visible = false
    boxFrame.Parent = container
    
    local boxStroke = Instance.new("UIStroke")
    boxStroke.Thickness = 1.5
    boxStroke.Color = Color3.fromRGB(255, 255, 255)
    boxStroke.Parent = boxFrame
    
    -- Health Bar
    local healthBg = Instance.new("Frame")
    healthBg.Name = "HealthBg"
    healthBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    healthBg.BorderSizePixel = 0
    healthBg.Visible = false
    healthBg.Parent = container
    
    local healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBg
    
    -- Name Tag Label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameTag"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.2
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Visible = false
    nameLabel.Parent = container
    
    -- Corner Box Lines (8 lines)
    local cornerLines = {}
    for i = 1, 8 do
        local l = Instance.new("Frame")
        l.Name = "Corner_" .. i
        l.BorderSizePixel = 0
        l.Visible = false
        l.Parent = container
        table.insert(cornerLines, l)
    end
    
    -- 3D Box Lines (12 lines)
    local box3DLines = {}
    for i = 1, 12 do
        local l = Instance.new("Frame")
        l.Name = "Box3D_" .. i
        l.BorderSizePixel = 0
        l.Visible = false
        l.Parent = container
        table.insert(box3DLines, l)
    end
    
    -- Skeleton Lines (14 lines for R15 & R6)
    local skeletonLines = {}
    for i = 1, 14 do
        local l = Instance.new("Frame")
        l.Name = "Skel_" .. i
        l.BorderSizePixel = 0
        l.Visible = false
        l.Parent = container
        table.insert(skeletonLines, l)
    end
    
    -- Highlight Chams
    local highlight = Instance.new("Highlight")
    highlight.Name = "OcelHighlight"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    pcall(function() highlight.Parent = GuiParent end)
    table.insert(_G.ESP_Highlights, highlight)
    
    local entry = {
        Character = character,
        MainContainer = container,
        BoxFrame = boxFrame,
        BoxStroke = boxStroke,
        HealthBg = healthBg,
        HealthFill = healthFill,
        NameLabel = nameLabel,
        CornerLines = cornerLines,
        Box3DLines = box3DLines,
        SkeletonLines = skeletonLines,
        Highlight = highlight
    }
    
    local function hideAll()
        boxFrame.Visible = false
        healthBg.Visible = false
        nameLabel.Visible = false
        for _, l in pairs(cornerLines) do l.Visible = false end
        for _, l in pairs(box3DLines) do l.Visible = false end
        for _, l in pairs(skeletonLines) do l.Visible = false end
    end
    
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not character or not character.Parent or not hrp or not hum or hum.Health <= 0 then
            cleanupESPEntry(entry)
            ESP_Entries[character] = nil
            return
        end
        
        -- Team calculation (Safe check for FFA / no teams)
        local isTeammate = false
        if isPlayer and playerObj then
            if playerObj.Team ~= nil and LocalPlayer.Team ~= nil and playerObj.Team == LocalPlayer.Team then
                isTeammate = true
            end
        end
        
        local isTargetEnabled = false
        local mainColor = toColor3(Config.EnemyColor)
        
        if isPlayer then
            if isTeammate then
                isTargetEnabled = Config.TeamESP
                mainColor = toColor3(Config.TeamColor)
            else
                isTargetEnabled = Config.EnemyESP
                mainColor = toColor3(Config.EnemyColor)
            end
        else
            isTargetEnabled = Config.DummyESP
            mainColor = toColor3(Config.DummyColor)
        end
        
        -- Highlight Chams Logic
        if highlight then
            if isTargetEnabled and Config.ChamsESP and (Config.ChamsStyle == "Highlight (Свечение)" or Config.ChamsStyle == "Highlight") then
                highlight.Enabled = true
                highlight.FillColor = mainColor
                highlight.OutlineColor = mainColor
                highlight.FillOpacity = 0.5
                highlight.OutlineOpacity = 0.8
            else
                highlight.Enabled = false
            end
        end
        
        if not isTargetEnabled then
            hideAll()
            return
        end
        
        local head = character:FindFirstChild("Head")
        local headWorldPos = head and (head.Position + Vector3.new(0, 0.6, 0)) or (hrp.Position + Vector3.new(0, 2.5, 0))
        local legWorldPos = hrp.Position - Vector3.new(0, 3.2, 0)
        
        local topScreen, topVis = Camera:WorldToViewportPoint(headWorldPos)
        local botScreen, botVis = Camera:WorldToViewportPoint(legWorldPos)
        local rootScreen, rootVis = Camera:WorldToViewportPoint(hrp.Position)
        
        if (topVis or botVis or rootVis) and rootScreen.Z > 0 then
            local height = math.abs(topScreen.Y - botScreen.Y)
            if height < 8 then height = 8 end
            local width = height * 0.62
            local boxX = rootScreen.X - (width / 2)
            local boxY = topScreen.Y
            
            -- Chams Mode: Filled Box / Box 2D / Normal Box ESP
            local showBox2D = Config.BoxESP or (Config.ChamsESP and (Config.ChamsStyle == "Box 2D (Квадратные)" or Config.ChamsStyle == "Filled Box (Залитые 2D)"))
            local isFilledChams = Config.ChamsESP and Config.ChamsStyle == "Filled Box (Залитые 2D)"
            
            if showBox2D then
                boxFrame.Size = UDim2.new(0, width, 0, height)
                boxFrame.Position = UDim2.new(0, boxX, 0, boxY)
                boxStroke.Color = mainColor
                boxStroke.Thickness = 1.5
                if isFilledChams then
                    boxFrame.BackgroundColor3 = mainColor
                    boxFrame.BackgroundTransparency = 0.55
                else
                    boxFrame.BackgroundTransparency = 1
                end
                boxFrame.Visible = true
            else
                boxFrame.Visible = false
            end
            
            -- Corner Box Chams
            if Config.ChamsESP and Config.ChamsStyle == "Corner Box (Уголки)" then
                local cLen = math.clamp(width * 0.25, 4, 16)
                local th = 2
                -- TL
                setGuiLine(cornerLines[1], Vector2.new(boxX, boxY), Vector2.new(boxX + cLen, boxY), mainColor, th)
                setGuiLine(cornerLines[2], Vector2.new(boxX, boxY), Vector2.new(boxX, boxY + cLen), mainColor, th)
                -- TR
                setGuiLine(cornerLines[3], Vector2.new(boxX + width, boxY), Vector2.new(boxX + width - cLen, boxY), mainColor, th)
                setGuiLine(cornerLines[4], Vector2.new(boxX + width, boxY), Vector2.new(boxX + width, boxY + cLen), mainColor, th)
                -- BL
                setGuiLine(cornerLines[5], Vector2.new(boxX, boxY + height), Vector2.new(boxX + cLen, boxY + height), mainColor, th)
                setGuiLine(cornerLines[6], Vector2.new(boxX, boxY + height), Vector2.new(boxX, boxY + height - cLen), mainColor, th)
                -- BR
                setGuiLine(cornerLines[7], Vector2.new(boxX + width, boxY + height), Vector2.new(boxX + width - cLen, boxY + height), mainColor, th)
                setGuiLine(cornerLines[8], Vector2.new(boxX + width, boxY + height), Vector2.new(boxX + width, boxY + height - cLen), mainColor, th)
            else
                for _, l in pairs(cornerLines) do l.Visible = false end
            end
            
            -- 3D Box Chams
            if Config.ChamsESP and Config.ChamsStyle == "3D Box (Объемный куб)" then
                local cf = hrp.CFrame
                local size = Vector3.new(2.2, 3, 1.8)
                local corners = {
                    cf * Vector3.new(-size.X, size.Y, -size.Z),
                    cf * Vector3.new(size.X, size.Y, -size.Z),
                    cf * Vector3.new(size.X, -size.Y, -size.Z),
                    cf * Vector3.new(-size.X, -size.Y, -size.Z),
                    cf * Vector3.new(-size.X, size.Y, size.Z),
                    cf * Vector3.new(size.X, size.Y, size.Z),
                    cf * Vector3.new(size.X, -size.Y, size.Z),
                    cf * Vector3.new(-size.X, -size.Y, size.Z)
                }
                
                local screenCorners = {}
                local all3dOn = true
                for i, c in ipairs(corners) do
                    local sc, on = Camera:WorldToViewportPoint(c)
                    if not on or sc.Z <= 0 then all3dOn = false break end
                    screenCorners[i] = Vector2.new(sc.X, sc.Y)
                end
                
                if all3dOn then
                    local edges = {
                        {1,2}, {2,3}, {3,4}, {4,1},
                        {5,6}, {6,7}, {7,8}, {8,5},
                        {1,5}, {2,6}, {3,7}, {4,8}
                    }
                    for i, edge in ipairs(edges) do
                        setGuiLine(box3DLines[i], screenCorners[edge[1]], screenCorners[edge[2]], mainColor, 1.5)
                    end
                else
                    for _, l in pairs(box3DLines) do l.Visible = false end
                end
            else
                for _, l in pairs(box3DLines) do l.Visible = false end
            end
            
            -- Health Bar
            if Config.HealthESP then
                local maxHp = math.max(hum.MaxHealth, 1)
                local curHp = math.clamp(hum.Health, 0, maxHp)
                local hpRatio = curHp / maxHp
                
                healthBg.Size = UDim2.new(0, 4, 0, height)
                healthBg.Position = UDim2.new(0, boxX - 6, 0, boxY)
                healthBg.Visible = true
                
                local fillHeight = math.floor(height * hpRatio)
                healthFill.Size = UDim2.new(1, 0, 0, fillHeight)
                healthFill.Position = UDim2.new(0, 0, 0, height - fillHeight)
                healthFill.BackgroundColor3 = Color3.fromRGB(math.floor(255 * (1 - hpRatio)), math.floor(255 * hpRatio), 0)
            else
                healthBg.Visible = false
            end
            
            -- Name & Distance
            if Config.NameESP then
                local dist = math.floor((Camera.CFrame.Position - hrp.Position).Magnitude)
                local displayName = isPlayer and (playerObj and playerObj.DisplayName or character.Name) or character.Name
                nameLabel.Text = displayName .. " [" .. dist .. "m]"
                nameLabel.TextColor3 = mainColor
                nameLabel.Size = UDim2.new(0, 200, 0, 16)
                nameLabel.Position = UDim2.new(0, rootScreen.X - 100, 0, boxY - 18)
                nameLabel.Visible = true
            else
                nameLabel.Visible = false
            end
            
            -- Full Body Anatomical Skeletons (R15 & R6)
            if Config.SkeletonESP then
                local isR15 = character:FindFirstChild("UpperTorso") ~= nil
                local skelColor = toColor3(Config.SkeletonColor)
                local joints = isR15 and {
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
                } or {
                    {"Head", "Torso"},
                    {"Torso", "Left Arm"},
                    {"Torso", "Right Arm"},
                    {"Torso", "Left Leg"},
                    {"Torso", "Right Leg"}
                }
                
                for i, pair in ipairs(joints) do
                    local line = skeletonLines[i]
                    if line then
                        local p1 = character:FindFirstChild(pair[1])
                        local p2 = character:FindFirstChild(pair[2])
                        if p1 and p2 then
                            local v1, on1 = Camera:WorldToViewportPoint(p1.Position)
                            local v2, on2 = Camera:WorldToViewportPoint(p2.Position)
                            if on1 and on2 and v1.Z > 0 and v2.Z > 0 then
                                setGuiLine(line, Vector2.new(v1.X, v1.Y), Vector2.new(v2.X, v2.Y), skelColor, 2)
                            else
                                line.Visible = false
                            end
                        else
                            line.Visible = false
                        end
                    end
                end
                
                for i = #joints + 1, #skeletonLines do
                    skeletonLines[i].Visible = false
                end
            else
                for _, line in pairs(skeletonLines) do
                    line.Visible = false
                end
            end
        else
            hideAll()
        end
    end)
    
    entry.Connection = conn
    table.insert(_G.ESP_Connections, conn)
    ESP_Entries[character] = entry
end

local function trackPlayer(player)
    if player == LocalPlayer then return end
    if player.Character then task.spawn(createESP, player.Character, true, player) end
    local cAdded = player.CharacterAdded:Connect(function(char)
        createESP(char, true, player)
    end)
    table.insert(_G.ESP_Connections, cAdded)
end

Players.PlayerAdded:Connect(trackPlayer)
for _, p in pairs(Players:GetPlayers()) do trackPlayer(p) end

task.spawn(function()
    while true do
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name:lower():find("dummy") or obj.Name:lower():find("training")) then
                createESP(obj, false, nil)
            end
        end
        task.wait(3)
    end
end)

-- Gun Mods Loop
task.spawn(function()
    while task.wait(0.5) do
        if Config.NoRecoil or Config.NoSpread then
            pcall(function()
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
            end)
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
pcall(function() OcelHub.Parent = GuiParent end)
if not OcelHub.Parent then pcall(function() OcelHub.Parent = LocalPlayer:WaitForChild("PlayerGui") end) end

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

-- Top Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
makeDraggable(TitleBar, MainFrame)

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local CoverFrame = Instance.new("Frame")
CoverFrame.Size = UDim2.new(1, 0, 0, 10)
CoverFrame.Position = UDim2.new(0, 0, 1, -10)
CoverFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
CoverFrame.BorderSizePixel = 0
CoverFrame.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -60, 1, 0)
TitleText.Position = UDim2.new(0, 15, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "Ocel Hub | Sniper Duels"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.Font = Enum.Font.SourceSansBold
TitleText.TextSize = 15
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

-- Minimize Button
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Size = UDim2.new(0, 25, 0, 25)
MinimizeButton.Position = UDim2.new(1, -65, 0.5, -12)
MinimizeButton.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.Font = Enum.Font.SourceSansBold
MinimizeButton.TextSize = 16
MinimizeButton.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 5)
MinCorner.Parent = MinimizeButton

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
    if ESPGui then ESPGui:Destroy() end
    for _, entry in pairs(ESP_Entries) do cleanupESPEntry(entry) end
    for _, hl in pairs(_G.ESP_Highlights) do pcall(function() hl:Destroy() end) end
    for _, conn in pairs(_G.ESP_Connections) do pcall(function() conn:Disconnect() end) end
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

-- Minimize Actions
local isMinimized = false
local function toggleMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame:TweenSize(UDim2.new(0, 580, 0, 35), "Out", "Quad", 0.2, true)
        Sidebar.Visible = false
        Content.Visible = false
        MinimizeButton.Text = "+"
    else
        MainFrame:TweenSize(UDim2.new(0, 580, 0, 420), "Out", "Quad", 0.2, true)
        task.delay(0.15, function()
            Sidebar.Visible = true
            Content.Visible = true
        end)
        MinimizeButton.Text = "-"
    end
end

MinimizeButton.MouseButton1Click:Connect(toggleMinimize)

-- Keyboard toggle (Insert key)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- Floating Mini Toggle Button
local FloatingToggle = Instance.new("TextButton")
FloatingToggle.Size = UDim2.new(0, 70, 0, 25)
FloatingToggle.Position = UDim2.new(0, 10, 0, 10)
FloatingToggle.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
FloatingToggle.Text = "Ocel Hub"
FloatingToggle.TextColor3 = Color3.fromRGB(0, 170, 255)
FloatingToggle.Font = Enum.Font.SourceSansBold
FloatingToggle.TextSize = 12
FloatingToggle.Parent = OcelHub

local ftCorner = Instance.new("UICorner")
ftCorner.CornerRadius = UDim.new(0, 5)
ftCorner.Parent = FloatingToggle

FloatingToggle.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

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
        if callback then callback(Config[configKey]) end
        saveConfig()
    end)
end

-- Responsive Slider
local function addSlider(parent, text, min, max, configKey, callback)
    local container = createContainer(parent, 50)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.65, 0, 0, 20)
    label.Position = UDim2.new(0.04, 0, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(240, 240, 240)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.25, 0, 0, 20)
    valLabel.Position = UDim2.new(0.71, 0, 0, 4)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(Config[configKey] or min)
    valLabel.TextColor3 = Color3.fromRGB(0, 170, 255)
    valLabel.Font = Enum.Font.SourceSansBold
    valLabel.TextSize = 14
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = container
    
    local track = Instance.new("Frame")
    track.Size = UDim2.new(0.92, 0, 0, 8)
    track.Position = UDim2.new(0.04, 0, 0, 30)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    track.BorderSizePixel = 0
    track.Parent = container
    
    local trCorner = Instance.new("UICorner")
    trCorner.CornerRadius = UDim.new(1, 0)
    trCorner.Parent = track
    
    local currentVal = Config[configKey] or min
    local initRatio = math.clamp((currentVal - min) / (max - min), 0, 1)
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(initRatio, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill
    
    local hitBtn = Instance.new("TextButton")
    hitBtn.Size = UDim2.new(0.92, 0, 0, 24)
    hitBtn.Position = UDim2.new(0.04, 0, 0, 22)
    hitBtn.BackgroundTransparency = 1
    hitBtn.Text = ""
    hitBtn.Parent = container
    
    local isDragging = false
    
    local function updateValue(input)
        local trackPos = track.AbsolutePosition.X
        local trackWidth = track.AbsoluteSize.X
        if trackWidth <= 0 then return end
        
        local ratio = math.clamp((input.Position.X - trackPos) / trackWidth, 0, 1)
        local val = math.floor(min + (ratio * (max - min)))
        Config[configKey] = val
        valLabel.Text = tostring(val)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        if callback then callback(val) end
        saveConfig()
    end
    
    hitBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            updateValue(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateValue(input)
        end
    end)
end

local function addDropdown(parent, text, options, configKey, callback)
    local container = createContainer(parent, 35)
    addLabel(container, text)
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 150, 0, 24)
    btn.Position = UDim2.new(0.92, -150, 0.5, -12)
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
    menu.ZIndex = 15
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
        optBtn.TextSize = 12
        optBtn.ZIndex = 16
        optBtn.Parent = menu
        
        optBtn.MouseButton1Click:Connect(function()
            Config[configKey] = opt
            btn.Text = opt
            menu.Visible = false
            if callback then callback(opt) end
            saveConfig()
        end)
    end
    
    btn.MouseButton1Click:Connect(function()
        menu.Visible = not menu.Visible
    end)
end

local function addColorPicker(parent, text, configKey, callback)
    local container = createContainer(parent, 55)
    addLabel(container, text)
    
    local paletteGrid = Instance.new("Frame")
    paletteGrid.Size = UDim2.new(0, 180, 0, 40)
    paletteGrid.Position = UDim2.new(0.96, -180, 0.5, -20)
    paletteGrid.BackgroundTransparency = 1
    paletteGrid.Parent = container
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 18, 0, 18)
    gridLayout.CellPadding = UDim2.new(0, 4, 0, 4)
    gridLayout.Parent = paletteGrid
    
    local colors = {
        {255, 0, 0}, {0, 255, 0}, {0, 0, 255}, {255, 255, 0}, {255, 0, 255}, {0, 255, 255},
        {255, 255, 255}, {255, 128, 0}, {128, 0, 255}, {0, 170, 255}, {255, 0, 128}, {0, 255, 128}
    }
    
    local colorButtons = {}
    for _, c in ipairs(colors) do
        local cBox = Instance.new("TextButton")
        cBox.Size = UDim2.new(0, 18, 0, 18)
        cBox.BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3])
        cBox.Text = ""
        cBox.BorderSizePixel = 0
        cBox.Parent = paletteGrid
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = cBox
        
        local selectFrame = Instance.new("Frame")
        selectFrame.Size = UDim2.new(1, 4, 1, 4)
        selectFrame.Position = UDim2.new(0, -2, 0, -2)
        selectFrame.BackgroundTransparency = 1
        selectFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
        selectFrame.BorderSizePixel = 1
        selectFrame.Visible = (Config[configKey] and Config[configKey][1] == c[1] and Config[configKey][2] == c[2] and Config[configKey][3] == c[3])
        selectFrame.Parent = cBox
        
        local sfCorner = Instance.new("UICorner")
        sfCorner.CornerRadius = UDim.new(0, 5)
        sfCorner.Parent = selectFrame
        
        cBox.MouseButton1Click:Connect(function()
            for _, btn in ipairs(colorButtons) do
                btn.selectFrame.Visible = false
            end
            selectFrame.Visible = true
            Config[configKey] = c
            if callback then callback(toColor3(c)) end
            saveConfig()
        end)
        
        table.insert(colorButtons, {btn = cBox, selectFrame = selectFrame})
    end
end

local function addTextBox(parent, text, placeholder, callback)
    local container = createContainer(parent, 35)
    addLabel(container, text)
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 120, 0, 24)
    box.Position = UDim2.new(0.92, -120, 0.5, -12)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    box.PlaceholderText = placeholder
    box.Text = Config.ActiveConfigName
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 13
    box.Parent = container
    
    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 4)
    bCorner.Parent = box
    
    box.FocusLost:Connect(function()
        if box.Text ~= "" then
            Config.ActiveConfigName = box.Text
            if callback then callback(box.Text) end
            saveConfig()
        end
    end)
end

local function addButton(parent, text, callback)
    local container = createContainer(parent, 35)
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.92, 0, 0, 25)
    btn.Position = UDim2.new(0.04, 0, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 13
    btn.Parent = container
    
    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 4)
    bCorner.Parent = btn
    
    btn.MouseButton1Click:Connect(callback)
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
addToggle(mainPage, "Team Check (Командный чек)", "TeamCheck", function(v) end)
addToggle(mainPage, "Wall Check (Проверка стен)", "WallCheck", function(v) end)
addDropdown(mainPage, "Hit Part", {"Head", "Torso", "HumanoidRootPart"}, "HitPart", function(v) end)

-- Gun Mods
addToggle(mainPage, "No Recoil (Без отдачи)", "NoRecoil", function(v) end)
addToggle(mainPage, "No Spread (Без разброса)", "NoSpread", function(v) end)

-- Visuals Tab
addToggle(visualPage, "Chams ESP (Чамсы)", "ChamsESP", function(v) end)
addDropdown(visualPage, "Chams Style (Стиль чамсов)", {"Highlight (Свечение)", "Box 2D (Квадратные)", "Filled Box (Залитые 2D)", "Corner Box (Уголки)", "3D Box (Объемный куб)"}, "ChamsStyle", function(v) end)
addToggle(visualPage, "Box ESP (2D Боксы)", "BoxESP", function(v) end)
addToggle(visualPage, "Health ESP (Здоровье)", "HealthESP", function(v) end)
addToggle(visualPage, "Name ESP (Ники и дистанция)", "NameESP", function(v) end)
addToggle(visualPage, "Enemy Visuals (Враги)", "EnemyESP", function(v) end)
addColorPicker(visualPage, "Enemy ESP Color", "EnemyColor", function(v) end)
addToggle(visualPage, "Team Visuals (Союзники)", "TeamESP", function(v) end)
addColorPicker(visualPage, "Team ESP Color", "TeamColor", function(v) end)
addToggle(visualPage, "Dummy Visuals (Манекены)", "DummyESP", function(v) end)
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

-- Settings Tab (Config manager)
addTextBox(settingsPage, "Config Name", "default", function(v) end)
addButton(settingsPage, "Save Current Config (Сохранить)", function()
    saveConfig(Config.ActiveConfigName)
end)
addButton(settingsPage, "Load Config (Загрузить)", function()
    loadConfig(Config.ActiveConfigName)
    OcelHub:Destroy()
    if ESPGui then ESPGui:Destroy() end
    for _, entry in pairs(ESP_Entries) do cleanupESPEntry(entry) end
    for _, hl in pairs(_G.ESP_Highlights) do pcall(function() hl:Destroy() end) end
    for _, conn in pairs(_G.ESP_Connections) do pcall(function() conn:Disconnect() end) end
    _G.OcelHubLoaded = nil
    loadstring(readfile("sniper_duels.lua"))()
end)
addToggle(settingsPage, "Autoload Config (Автозагрузка)", "AutoLoad", function(v) end)

-- Load UI state according to loaded config
TabButtons["Main"].BackgroundTransparency = 0.5
TabButtons["Main"].TextColor3 = Color3.fromRGB(0, 170, 255)
Tabs["Main"].Visible = true

