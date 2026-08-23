--[[
    OCEL HUB - Sniper Duels
    100% Local Custom UI Framework (No External Loadstring)
    Ultimate stability: fixed team check bug, improved wall check, restored skeletons, added minimize.
--]]

-- Safety check: prevent duplicate run
if _G.OcelHubLoaded then
    local oldGui = game:GetService("CoreGui"):FindFirstChild("OcelHub") or game:GetService("Players").LocalPlayer:FindFirstChild("OcelHub")
    if oldGui then oldGui:Destroy() end
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
    TeamCheck = false, -- Default to false to avoid team issues
    WallCheck = true,
    HitPart = "Head",
    
    -- Gun Mods
    NoRecoil = false,
    NoSpread = false,
    
    -- Visuals (Box, HP, Names, Chams, Skeletons)
    BoxESP = false,
    HealthESP = false,
    NameESP = false,
    ChamsESP = true,
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

-- Load default config on startup
loadConfig("default")

-- Visuals Storage & Tracking
local ESP_Entries = {}
local OriginalViewmodelProps = {}

-- Helper to safely create Drawing objects
local function newDrawing(drawType, props)
    local obj = nil
    pcall(function()
        obj = Drawing.new(drawType)
        if props then
            for k, v in pairs(props) do
                obj[k] = v
            end
        end
    end)
    if obj then
        table.insert(_G.ESP_Drawings, obj)
    end
    return obj
end

-- Drawing FOV Circle
local FOVCircle = newDrawing("Circle", {
    Thickness = 1.5,
    NumSides = 60,
    Radius = Config.FOVRadius,
    Filled = false,
    Visible = false,
    Color = toColor3(Config.FOVColor)
})

-- Update FOV pos to center of screen
RunService.RenderStepped:Connect(function()
    if FOVCircle then
        FOVCircle.Radius = Config.FOVRadius
        FOVCircle.Color = toColor3(Config.FOVColor)
        FOVCircle.Visible = Config.ShowFOV
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
end)

-- Helper: Wall Check (Fixed & Safe)
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

-- Helper: Find target (Fixed Team Check nil comparison)
local function getClosestPlayer()
    local closestTarget = nil
    local shortestDistance = math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    local function checkCharacter(char, isPlayer, playerObj)
        if not char or not char:FindFirstChild("Humanoid") or not char:FindFirstChild(Config.HitPart) then return end
        if char.Humanoid.Health <= 0 then return end
        
        -- Fix: Check team only if team is not nil, to avoid ignoring Neutral/No-team players
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

-- Camera (Force in match/round)
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
            SelfHighlight.Parent = CoreGui
            table.insert(_G.ESP_Highlights, SelfHighlight)
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

-- Viewmodel Chams (Hands & Weapon)
local function applyChamsToPart(part, isArm)
    if not OriginalViewmodelProps[part] then
        OriginalViewmodelProps[part] = {
            Color = part.Color,
            Material = part.Material,
            Transparency = part.Transparency
        }
    end
    
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
    while task.wait(0.1) do
        local viewmodel = Camera:FindFirstChild("ViewModel") or Camera:FindFirstChild("Viewmodel") or Camera:FindFirstChild("Arms") or Camera:FindFirstChildOfClass("Model")
        if viewmodel and viewmodel ~= LocalPlayer.Character then
            for _, part in pairs(viewmodel:GetDescendants()) do
                if part:IsA("BasePart") then
                    local name = part.Name:lower()
                    local isArm = name:find("arm") or name:find("hand") or name:find("sleeve") or name:find("glove") or name:find("skin") or name:find("left") or name:find("right")
                    
                    if (isArm and Config.ArmChams) or (not isArm and Config.WeaponChams) then
                        applyChamsToPart(part, isArm)
                    else
                        restorePart(part)
                    end
                end
            end
        else
            for part, _ in pairs(OriginalViewmodelProps) do
                if part.Parent then restorePart(part) else OriginalViewmodelProps[part] = nil end
            end
        end
    end
end)

-- ==================== HIGH PERFORMANCE UNIFIED ESP ====================
local function cleanupESPEntry(entry)
    if not entry then return end
    if entry.Connection then
        pcall(function() entry.Connection:Disconnect() end)
    end
    if entry.BoxOutline then pcall(function() entry.BoxOutline:Remove() end) end
    if entry.Box then pcall(function() entry.Box:Remove() end) end
    if entry.HealthBg then pcall(function() entry.HealthBg:Remove() end) end
    if entry.HealthFill then pcall(function() entry.HealthFill:Remove() end) end
    if entry.NameTag then pcall(function() entry.NameTag:Remove() end) end
    if entry.Highlight then pcall(function() entry.Highlight:Destroy() end) end
    if entry.SkeletonLines then
        for _, line in pairs(entry.SkeletonLines) do
            pcall(function() line:Remove() end)
        end
    end
end

local function createESP(character, isPlayer, playerObj)
    if ESP_Entries[character] then return end
    
    local hrp = character:WaitForChild("HumanoidRootPart", 5) or character:WaitForChild("Torso", 5) or character:WaitForChild("UpperTorso", 5)
    local hum = character:WaitForChild("Humanoid", 5)
    if not hrp or not hum then return end
    
    local entry = {
        Character = character,
        HRP = hrp,
        Humanoid = hum,
        IsPlayer = isPlayer,
        PlayerObj = playerObj,
        BoxOutline = newDrawing("Square", { Thickness = 3, Filled = false, Color = Color3.fromRGB(0, 0, 0), Visible = false }),
        Box = newDrawing("Square", { Thickness = 1.5, Filled = false, Color = Color3.fromRGB(255, 255, 255), Visible = false }),
        HealthBg = newDrawing("Square", { Thickness = 1, Filled = true, Color = Color3.fromRGB(0, 0, 0), Visible = false }),
        HealthFill = newDrawing("Square", { Thickness = 1, Filled = true, Color = Color3.fromRGB(0, 255, 0), Visible = false }),
        NameTag = newDrawing("Text", { Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(255, 255, 255), Visible = false }),
        SkeletonLines = {}
    }
    
    -- Pre-create 14 skeleton lines for max R15 joint fidelity
    for i = 1, 14 do
        local l = newDrawing("Line", { Thickness = 1.5, Color = toColor3(Config.SkeletonColor), Visible = false })
        if l then table.insert(entry.SkeletonLines, l) end
    end
    
    -- Highlight (Chams)
    local highlight = Instance.new("Highlight")
    highlight.Name = "OcelHighlight"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = CoreGui
    entry.Highlight = highlight
    table.insert(_G.ESP_Highlights, highlight)
    
    local function hideDrawings()
        if entry.BoxOutline then entry.BoxOutline.Visible = false end
        if entry.Box then entry.Box.Visible = false end
        if entry.HealthBg then entry.HealthBg.Visible = false end
        if entry.HealthFill then entry.HealthFill.Visible = false end
        if entry.NameTag then entry.NameTag.Visible = false end
        if entry.SkeletonLines then
            for _, line in pairs(entry.SkeletonLines) do
                line.Visible = false
            end
        end
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
        
        -- Update Chams
        if entry.Highlight then
            if isTargetEnabled and Config.ChamsESP then
                entry.Highlight.Enabled = true
                entry.Highlight.FillColor = mainColor
                entry.Highlight.OutlineColor = mainColor
                entry.Highlight.FillOpacity = 0.5
                entry.Highlight.OutlineOpacity = 0.8
            else
                entry.Highlight.Enabled = false
            end
        end
        
        if not isTargetEnabled then
            hideDrawings()
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
            if height < 6 then height = 6 end
            local width = height * 0.6
            local boxX = rootScreen.X - (width / 2)
            local boxY = topScreen.Y
            
            -- Box ESP
            if Config.BoxESP then
                if entry.BoxOutline then
                    entry.BoxOutline.Position = Vector2.new(boxX - 1, boxY - 1)
                    entry.BoxOutline.Size = Vector2.new(width + 2, height + 2)
                    entry.BoxOutline.Visible = true
                end
                if entry.Box then
                    entry.Box.Position = Vector2.new(boxX, boxY)
                    entry.Box.Size = Vector2.new(width, height)
                    entry.Box.Color = mainColor
                    entry.Box.Visible = true
                end
            else
                if entry.BoxOutline then entry.BoxOutline.Visible = false end
                if entry.Box then entry.Box.Visible = false end
            end
            
            -- Health Bar ESP
            if Config.HealthESP then
                local maxHp = math.max(hum.MaxHealth, 1)
                local curHp = math.clamp(hum.Health, 0, maxHp)
                local hpRatio = curHp / maxHp
                
                if entry.HealthBg then
                    entry.HealthBg.Position = Vector2.new(boxX - 6, boxY - 1)
                    entry.HealthBg.Size = Vector2.new(4, height + 2)
                    entry.HealthBg.Visible = true
                end
                if entry.HealthFill then
                    local fillHeight = math.floor(height * hpRatio)
                    entry.HealthFill.Position = Vector2.new(boxX - 5, boxY + height - fillHeight)
                    entry.HealthFill.Size = Vector2.new(2, fillHeight)
                    entry.HealthFill.Color = Color3.fromRGB(math.floor(255 * (1 - hpRatio)), math.floor(255 * hpRatio), 0)
                    entry.HealthFill.Visible = true
                end
            else
                if entry.HealthBg then entry.HealthBg.Visible = false end
                if entry.HealthFill then entry.HealthFill.Visible = false end
            end
            
            -- Name & Distance ESP
            if Config.NameESP then
                if entry.NameTag then
                    local dist = math.floor((Camera.CFrame.Position - hrp.Position).Magnitude)
                    local displayName = isPlayer and (playerObj and playerObj.DisplayName or character.Name) or character.Name
                    entry.NameTag.Text = displayName .. " [" .. dist .. "m]"
                    entry.NameTag.Position = Vector2.new(rootScreen.X, boxY - 16)
                    entry.NameTag.Color = mainColor
                    entry.NameTag.Visible = true
                end
            else
                if entry.NameTag then entry.NameTag.Visible = false end
            end
            
            -- Full Body Skeleton ESP (R15 & R6)
            if Config.SkeletonESP then
                local isR15 = character:FindFirstChild("UpperTorso") ~= nil
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
                    local line = entry.SkeletonLines[i]
                    if line then
                        local p1 = character:FindFirstChild(pair[1])
                        local p2 = character:FindFirstChild(pair[2])
                        if p1 and p2 then
                            local v1, on1 = Camera:WorldToViewportPoint(p1.Position)
                            local v2, on2 = Camera:WorldToViewportPoint(p2.Position)
                            if on1 and on2 and v1.Z > 0 and v2.Z > 0 then
                                line.From = Vector2.new(v1.X, v1.Y)
                                line.To = Vector2.new(v2.X, v2.Y)
                                line.Color = toColor3(Config.SkeletonColor)
                                line.Visible = true
                            else
                                line.Visible = false
                            end
                        else
                            line.Visible = false
                        end
                    end
                end
                
                for i = #joints + 1, #entry.SkeletonLines do
                    entry.SkeletonLines[i].Visible = false
                end
            else
                for _, line in pairs(entry.SkeletonLines) do
                    line.Visible = false
                end
            end
        else
            hideDrawings()
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

-- Cover bottom corners of titlebar
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

-- Minimize Button (Collapses window)
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
    if FOVCircle then pcall(function() FOVCircle:Remove() end) end
    for _, entry in pairs(ESP_Entries) do cleanupESPEntry(entry) end
    for _, hl in pairs(_G.ESP_Highlights) do pcall(function() hl:Destroy() end) end
    for _, conn in pairs(_G.ESP_Connections) do pcall(function() conn:Disconnect() end) end
    for _, draw in pairs(_G.ESP_Drawings) do pcall(function() draw:Remove() end) end
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

-- Keyboard toggle (Insert key to toggle visibility)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- Floating Mini Toggle Button (Always on screen to show/hide menu easily)
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

-- Completely fixed and responsive Slider
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
    
    -- Hit box button across the entire track area for seamless clicks and drags
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
addToggle(visualPage, "Box ESP (2D Боксы)", "BoxESP", function(v) end)
addToggle(visualPage, "Health ESP (Здоровье)", "HealthESP", function(v) end)
addToggle(visualPage, "Name ESP (Ники и дистанция)", "NameESP", function(v) end)
addToggle(visualPage, "Chams ESP (Подсветка тел)", "ChamsESP", function(v) end)
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
    if FOVCircle then pcall(function() FOVCircle:Remove() end) end
    for _, entry in pairs(ESP_Entries) do cleanupESPEntry(entry) end
    for _, hl in pairs(_G.ESP_Highlights) do pcall(function() hl:Destroy() end) end
    for _, conn in pairs(_G.ESP_Connections) do pcall(function() conn:Disconnect() end) end
    for _, draw in pairs(_G.ESP_Drawings) do pcall(function() draw:Remove() end) end
    _G.OcelHubLoaded = nil
    loadstring(readfile("sniper_duels.lua"))()
end)
addToggle(settingsPage, "Autoload Config (Автозагрузка)", "AutoLoad", function(v) end)

-- Load UI state according to loaded config
TabButtons["Main"].BackgroundTransparency = 0.5
TabButtons["Main"].TextColor3 = Color3.fromRGB(0, 170, 255)
Tabs["Main"].Visible = true

