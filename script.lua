-[[
    ================================================================
    [ SCRIPT INFORMATION ]
    Project: Custom Script
    Author: OYB
    YouTube: https://www.youtube.com/channel/UCAlXXV1Hbvf7WbfXARuVtiQ
    
    [ TERMS AND CONDITIONS ]
    - You ARE allowed to use and modify this script for your own games.
    - You ARE NOT allowed to re-upload, redistribute, or claim 
      ownership of this script.
    - Removing or altering these credits is strictly prohibited.
    
    Copyright (c) 2026 OYB. All rights reserved.
    ================================================================
]]

-- ⚠️ IMPORTANT: Put this code at the VERY TOP of your Main Script (before obfuscating) ⚠️

local ProtectionConfig = {
    -- 🔴 CRITICAL: This MUST exactly match the 'Secret' value in your Key System's Config!
    -- If your Key System has: Secret = "Test"
    -- Then this must also be: SecretKey = "Test"
    SecretKey = "kkop2610",
    
    -- The name of your Hub (shown in the kick message if they try to bypass)
    HubName = "AOI"
}

-- Anti-Bypass Logic: Checks if the Key System successfully set the global variable
if not _G[ProtectionConfig.SecretKey] then
    local player = game:GetService("Players").LocalPlayer
    if player then
        player:Kick("\n🛡️ Unauthorized Execution 🛡️\n\nPlease use the official Key System to run " .. ProtectionConfig.HubName)
    end
    return -- Stops the rest of the script from loading!
end

-------------------------------------------------------------------------------
-- 👇 YOUR MAIN SCRIPT CODE STARTS HERE 👇
-------------------------------------------------------------------------------

print(ProtectionConfig.HubName .. " Loaded Successfully!")

local _ENV = (getgenv or getrenv or getfenv)()

do 
    local Cached = _ENV.Connections or {}

    _ENV.Connections = Cached do
        for i = 1, #Cached do
            Cached[i]:Disconnect()
        end

        table.clear(Cached)
    end

    function Connect(Instance, Callback)
        local Connection = Instance:Connect(Callback)
        table.insert(Cached, Connection)
        return Connection
    end 
end

local Module = {}

local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

Module.SimplePath = (function()

    local displayPart = Instance.new("Part")
    displayPart.Size = Vector3.new(1, 1, 1)
    displayPart.Anchored = true
    displayPart.CanCollide = false
    displayPart.Color = Color3.fromRGB(255, 255, 255)
    displayPart.Material = Enum.Material.Neon
    displayPart.Shape = Enum.PartType.Ball

    local nonHumanoidRestrictions = {
        Stopped = "Stopped event";
    }
    local Path = {
        Status = {
            PathNotFound = "PathNotFound";
            PathCompleted = "PathCompleted";
        };
    }
    Path.__index = function(tab, index)
        if not tab._humanoid then
            assert(not nonHumanoidRestrictions[index], (nonHumanoidRestrictions[index] or "").." cannot be used for a non-humanoid model")
        end
        return (tab._signals[index] and tab._signals[index].Event) or Path[index]
    end
    local function GetNum(i, j) return Random.new(tick()):NextNumber(i, j) end

    local function Move(self)
        if self._active then
            if self._humanoid then
                self._humanoid:MoveTo(self._waypoints[self._waypoint].Position)
            end
        end
    end

    local function JumpDetect(self)
        return
    end

    local function FireWaypointReached(self)
        local lastPos = (self._waypoint - 1 > 0 and self._waypoints[self._waypoint - 1].Position) or self._model.PrimaryPart.Position
        local nextPos = self._waypoints[self._waypoint].Position
        if lastPos == nextPos then return end
        self._signals.WaypointReached:Fire(self._model, lastPos, nextPos)
    end

    local function WaypointReached(self, reached)
        FireWaypointReached(self)

        if not self._humanoid then
            if self._waypoint < #self._waypoints then
                self._waypoint += 1
            else
                self:Stop(self.Status.Reached)
                self._signals.Reached:Fire(self._model)
            end
            return
        end

        if reached and self._waypoint < #self._waypoints then
            JumpDetect(self)
            self._waypoint += 1
            Move(self)
        elseif reached then
            self:Stop(self.Status.PathCompleted)
            self._signals.Reached:Fire(self._model)
        else
            self:Stop(self.Status.PathCompleted)
            self._signals.Reached:Fire(self._model)
        end
    end

    local function CleanWaypoints(self, newWaypoints, finalPosition)
        local cleanedWaypoints = {}
        for _, waypoint in ipairs(newWaypoints) do
            local angle = math.acos((finalPosition - self._model.PrimaryPart.Position).Unit:Dot((waypoint.Position - self._model.PrimaryPart.Position).Unit))
            if angle < 150 * (math.pi / 180) then
                table.insert(cleanedWaypoints, waypoint)
            end
        end
        return cleanedWaypoints
    end

    local function GetNonHumanoidWaypoint(self)
        for i, waypoint in ipairs(self._waypoints) do
            local mag = (waypoint.Position - self._model.PrimaryPart.Position).Magnitude
            if mag > 2 then
                return i
            end
        end
        return 1
    end

    local function DestroyWaypoints(waypoints)
        return (waypoints and (function()
            for _, waypoint in ipairs(waypoints) do
                waypoint:Destroy()
            end
        end)())
    end

    local function CreateWaypoints(waypoints)
        local displayParts = {}
        for _, waypoint in ipairs(waypoints) do
            local displayPartClone = displayPart:Clone()
            displayPartClone.Position = waypoint.Position
            displayPartClone.Parent = workspace
            table.insert(displayParts, displayPartClone)
        end
        return displayParts
    end

    local function Timeout(self)
        if not self._model or not self._model.PrimaryPart then
            self._active = false
            return
        end
        self:Stop(self.Status.PathCompleted)
        self._signals.Reached:Fire(self._model)
    end

    local function GetFacingSide(part, face)
        local facing, val = nil, -7
        if math.abs(part.CFrame.LookVector[face]) >= val then val = math.abs(part.CFrame.LookVector[face]); facing = "Z" end
        if math.abs(part.CFrame.UpVector[face]) >= val then val = math.abs(part.CFrame.UpVector[face]); facing = "Y" end
        if math.abs(part.CFrame.RightVector[face]) >= val then val = math.abs(part.CFrame.RightVector[face]); facing = "X" end
        return facing
    end

    function Path.GetRandomPosition(part)
        assert(part:IsA("BasePart"), "part must be a valid BasePart")
        local faces = {X = GetFacingSide(part, "X"), Y = GetFacingSide(part, "Y"), Z = GetFacingSide(part, "Z")}
        local p0 = part.Position + Vector3.new(0, (part.Size[faces.X] / 2) + 1, 0) + Vector3.new(0, part.Size[faces.Y] / 2, 0)
        local x = part.Position.X + GetNum(-part.Size[faces.X] / 2, part.Size[faces.X] / 2)
        local y = part.Position.Y + GetNum(-part.Size[faces.Y] / 2, part.Size[faces.Y] / 2)
        local z = part.Position.Z + GetNum(-part.Size[faces.Z] / 2, part.Size[faces.Z] / 2)
        local p1 = Vector3.new(x, y, z)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Whitelist
        params.FilterDescendantsInstances = {part}
        local result = workspace:Raycast(p0, (p1 - p0).Unit * (part.Size.X * part.Size.Y * part.Size.Z))
        return (result and result.Position and result.Position + Vector3.new(0, 1 / 2, 0)) or Path.GetRandomPosition(part)
    end

    function Path.GetNearestCharacter(part)
        assert(part:IsA("BasePart"), "part must be a valid BasePart")
        local c, m = nil, -1
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and (p.Character.PrimaryPart.Position - part.Position).Magnitude > m then
                c, m = p.Character, (p.Character.PrimaryPart.Position - part.Position).Magnitude
            end
        end
        return c
    end

    function Path.GetNearestCharacterPosition(part)
        assert(part:IsA("BasePart"), "part must be a valid BasePart")
        local model = Path.GetNearestCharacter(part)
        return (model and model.PrimaryPart.Position)
    end

    function Path.new(model, agentParameters)
        assert(model:IsA("Model") and model.PrimaryPart, "model must by a valid Model Instance with a set PrimaryPart")

        local self = setmetatable({
            _signals = {
                Reached = Instance.new("BindableEvent");
                WaypointReached = Instance.new("BindableEvent");
                Stopped = Instance.new("BindableEvent");
            };
            _connections = {};
            _model = model;
            _path = PathfindingService:CreatePath(agentParameters);
            _humanoid = model:FindFirstChildOfClass("Humanoid") or false;
            IgnoreObstacles = true;
        }, Path)

        if self._humanoid then
            self._connections = {self._humanoid.MoveToFinished:Connect(function(reached)
                if self._active then
                    self._elapsed = tick()
                    WaypointReached(self, reached)
                end
            end)}
        end

        pcall(function() self._model.PrimaryPart:SetNetworkOwner(nil) end)
        return self
    end

    function Path:Destroy()
        for _, signal in ipairs(self._signals) do
            signal:Destroy()
            self._signals[signal] = nil
        end
        for _, connection in ipairs(self._connections) do
            connection:Disconnect()
        end
        DestroyWaypoints(self._displayParts)
        self._connections = nil
        self._humanoid = nil
        self._path = nil
        self._goal = nil
    end

    function Path:Stop(status)
        self._signals.Stopped:Fire(self._model, status)
        self._active = false
        self._elapsed = false
        self._displayParts = (self._displayParts and DestroyWaypoints(self._displayParts))
    end

    function Path:Run(goal)
        if not goal and not self._humanoid and self._goal then
            WaypointReached(self, true)
            return
        end
        assert(goal and (typeof(goal) == "Vector3" or goal:IsA("BasePart")), "Goal must be a valid BasePart or a Vector3 position")

        if not self._model or not self._model.PrimaryPart then return false end

        local initialPosition = self._model.PrimaryPart.Position
        local finalPosition = (typeof(goal) == "Vector3" and goal) or goal.Position
        local success, msg = pcall(function()
            self._path:ComputeAsync(initialPosition, finalPosition)
        end)
        if not success or self._path.Status == Enum.PathStatus.NoPath or not self._path:GetWaypoints() or #self._path:GetWaypoints() == 0 or (self._humanoid and self._humanoid.FloorMaterial == Enum.Material.Air and self._model.PrimaryPart.Velocity.Magnitude >= 1) then
            self:Stop(self.Status.PathNotFound)
            return false
        end

        self._waypoints = (self._active and CleanWaypoints(self, self._path:GetWaypoints(), finalPosition)) or self._path:GetWaypoints()
        self._waypoint = 1
        self._goal = goal
        DestroyWaypoints(self._displayParts)
        self._displayParts = (self.Visualize and CreateWaypoints(self._waypoints))

        if not self._humanoid then
            self._waypoint = GetNonHumanoidWaypoint(self)
            WaypointReached(self, true)
            return
        end

        if not self._active then
            self._active = true
            Move(self)
            coroutine.wrap(function()
                while self._active do
                    if self._elapsed and tick() - self._elapsed > 1 then
                        Timeout(self); break
                    end
                    RunService.Stepped:Wait()
                end
            end)()
        end

        return true
    end

    return Path
end)()

local LocalPlayer = Players.LocalPlayer
local Cached = nil
local CurrentTarget = nil
local IsRunning = false
local SkippedPlayers = {}

do
    Connect(LocalPlayer.Idled, function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    Connect(LocalPlayer.CharacterRemoving, function()
        Cached = nil
        CurrentTarget = nil
        IsRunning = false
        SkippedPlayers = {}
    end)
end

do
    Module.PlayersModule = (function()
        local PlayersModule = {}

        function PlayersModule:IsAlive(Character)
            return Character and Character:FindFirstChild("Humanoid") and Character:FindFirstChild("HumanoidRootPart") and Character.Humanoid.Health > 0
        end

        function PlayersModule:GetTeam(Character)
            if not Character then return nil end
            local TeamHL = Character:FindFirstChild("TeamHL")
            if TeamHL then
                return TeamHL.OutlineColor
            end
            return nil
        end

        function PlayersModule:CanFire()
            local Current = LocalPlayer.Character and PlayersModule:GetTeam(LocalPlayer.Character)

            for _, v in Players:GetPlayers() do
                if v == LocalPlayer then continue end

                local Character = v.Character
                if not Character then continue end

                if Character:FindFirstChildOfClass("ForceField") then continue end

                local Head = Character:FindFirstChild("Head")
                if not Head then continue end

                if not PlayersModule:IsAlive(Character) then continue end

                local Team = PlayersModule:GetTeam(Character)
                if Current and Team and Team == Current then continue end

                if not PlayersModule:RaysToTarget(Head) then continue end

                return true
            end

            return false
        end

        function PlayersModule:RaysToTarget(Target)
            if not Target then return false end

            local Character = LocalPlayer.Character
            if not Character then return false end

            local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
            if not HumanoidRootPart then return false end

            local Direction = Target.Position - HumanoidRootPart.Position

            local WorldIgnore = workspace:FindFirstChild("WorldIgnore")
            local FilterList = {Character, Target.Parent}

            if WorldIgnore then
                table.insert(FilterList, WorldIgnore)
            end

            local Params = RaycastParams.new()
            Params.FilterType = Enum.RaycastFilterType.Blacklist
            Params.FilterDescendantsInstances = FilterList

            local Result = workspace:Raycast(HumanoidRootPart.Position, Direction, Params)

            if Result then
                return Result.Instance:IsDescendantOf(Target.Parent)
            end

            return true
        end

        function PlayersModule:Logic(Current, Character, Head)
            if Character:FindFirstChildOfClass("ForceField") then return end

            local Team = PlayersModule:GetTeam(Character)

            if Current and Team and Team == Current then return end

            if not PlayersModule:IsAlive(Character) then return end

            if not PlayersModule:RaysToTarget(Head) then return end

            return true
        end

        function PlayersModule:GetPlayers()
            local Current = LocalPlayer.Character and PlayersModule:GetTeam(LocalPlayer.Character)
            local Nearest, Distance = nil, math.huge
            local Now = tick()

            for target, t in pairs(SkippedPlayers) do
                if Now - t > 2 then
                    SkippedPlayers[target] = nil
                end
            end

            for _, v in Players:GetPlayers() do
                if v == LocalPlayer then continue end

                local Character = v.Character
                if not Character then continue end

                local Head = Character:FindFirstChild("Head")
                if not Head then continue end

                if SkippedPlayers[Head] then continue end

                if not PlayersModule:Logic(Current, Character, Head) then continue end

                local Magnitude = Module:Distance(Character:GetPivot())
                if Magnitude < Distance then
                    Nearest, Distance = Head, Magnitude
                end
            end

            return Nearest
        end

        return PlayersModule
    end)()

    Module.Hooked = (function()
        local Raycast = nil

        for _, v in getgc() do
            if typeof(v) ~= 'function' then continue end
            local Path, Name = debug.info(v, 's'), debug.info(v, 'n')
            if Path:find('CommonFunctions') and Name == "RayCast" then
                Raycast = v
            end
        end

        repeat task.wait(0.1) until Raycast

        local RPD_HOOK do
            local safehook = hookfunction and clonefunction(hookfunction)
            RPD_HOOK = safehook(Raycast, function(v1, v2, v3, v4)
                local Target = Module.PlayersModule:GetPlayers()

                if Target and Module.PlayersModule:RaysToTarget(Target) then
                    v2 = Target.Position
                end

                return RPD_HOOK(v1, v2, v3, v4)
            end)
        end

        return RPD_HOOK
    end)()

    function Module:Distance(Position)
        return Position and ((typeof(Position) == 'CFrame' and LocalPlayer:DistanceFromCharacter(Position.Position)) or LocalPlayer:DistanceFromCharacter(Position))
    end
end

do
    local Highligh = Instance.new("Highlight") do
        Highligh.FillColor = Color3.fromRGB(255, 0, 0)
    end

    local Settings = {
        Play = false, -- Changed to false so script starts disabled
    }

    local function NewOption(Flag, Function, Interval)
        return task.spawn(function()
            while task.wait(Interval) do
                if Settings[Flag] then
                    pcall(Function)
                end
            end
        end)
    end

    local function SetupCached(Character)
        Cached = Module.SimplePath.new(Character, {
            AgentCanJump = false,
            AgentCanClimb = false,
        })

        IsRunning = false

        Cached.Reached:Connect(function()
            IsRunning = false
            CurrentTarget = nil
        end)

        Cached.Stopped:Connect(function(model, status)
            if status == "PathNotFound" then
                if CurrentTarget then
                    SkippedPlayers[CurrentTarget] = tick()
                    CurrentTarget = nil
                    IsRunning = false
                end
            end
        end)
    end

    local SpawnIndex = 1
    local IsPatrolling = false

    local function GetSpawnPoints()
        local WorldIgnore = workspace:FindFirstChild("WorldIgnore")
        if not WorldIgnore then return {} end
        local folder = WorldIgnore:FindFirstChild("SpawnPoints")
        if not folder then return {} end
        return folder:GetChildren()
    end

    local function GetNearestSpawn()
        local spawns = GetSpawnPoints()
        if #spawns == 0 then return nil end

        local Current = LocalPlayer.Character and Module.PlayersModule:GetTeam(LocalPlayer.Character)
        local NearestPlayer, NearestPlayerDist = nil, math.huge

        for _, v in Players:GetPlayers() do
            if v == LocalPlayer then continue end
            local Char = v.Character
            if not Char then continue end
            if not Module.PlayersModule:IsAlive(Char) then continue end
            local Team = Module.PlayersModule:GetTeam(Char)
            if Current and Team and Team == Current then continue end
            local Dist = Module:Distance(Char:GetPivot())
            if Dist < NearestPlayerDist then
                NearestPlayer = Char
                NearestPlayerDist = Dist
            end
        end

        if not NearestPlayer then
            if SpawnIndex > #spawns then SpawnIndex = 1 end
            local goal = spawns[SpawnIndex]
            SpawnIndex += 1
            return goal
        end

        local NearestSpawn, NearestSpawnDist = nil, math.huge
        local PlayerPos = NearestPlayer.PrimaryPart.Position

        for _, spawn in ipairs(spawns) do
            if not spawn:IsA("BasePart") then continue end
            local Dist = (spawn.Position - PlayerPos).Magnitude
            if Dist < NearestSpawnDist then
                NearestSpawn = spawn
                NearestSpawnDist = Dist
            end
        end

        return NearestSpawn
    end

    local function PatrolSpawns()
        if IsPatrolling then return end

        local spawns = GetSpawnPoints()
        if #spawns == 0 then return end

        IsPatrolling = true

        task.spawn(function()
            while not CurrentTarget do
                local goal = GetNearestSpawn()

                if not goal then task.wait(1) continue end

                if not Cached then
                    local Character = LocalPlayer.Character
                    if not Character then break end
                    SetupCached(Character)
                end

                local done = false

                local conn = Cached.Reached:Connect(function()
                    done = true
                end)

                local ok, result = pcall(function()
                    return Cached:Run(goal)
                end)

                if not ok or result == false then
                    conn:Disconnect()
                    IsRunning = false
                    task.wait(0.2)
                    continue
                end

                IsRunning = true

                local t = tick()
                while not done and not CurrentTarget and tick() - t < 15 do
                    task.wait(0.1)
                end

                conn:Disconnect()
                IsRunning = false

                if CurrentTarget then break end
                task.wait(0.2)
            end
            IsPatrolling = false
        end)
    end
    
    -- ===== BUTTON UI =====
    local CoreGui = game:GetService('CoreGui')
    
    -- Clean up old UI if it exists
    local oldAuto = CoreGui:FindFirstChild('Auto')
    if oldAuto then oldAuto:Destroy() end
    
    -- Create main ScreenGui
    local Auto = Instance.new("ScreenGui")
    Auto.Name = "Auto"
    Auto.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    Auto.IgnoreGuiInset = true
    Auto.Parent = CoreGui
    Auto.ZIndexBehavior = Enum.ZIndexBehavior.Global
    
    -- Create toggle button
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.Size = UDim2.new(0, 120, 0, 50)
    ToggleButton.Position = UDim2.new(0.5, -60, 0, 10)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = 18
    ToggleButton.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
    ToggleButton.Text = "OFF"
    ToggleButton.Parent = Auto
    ToggleButton.BorderSizePixel = 0
    
    -- Add corner radius to button
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = ToggleButton
    
    -- Create status text label
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Size = UDim2.new(1, 0, 0, 50)
    StatusLabel.Position = UDim2.new(0, 0, 0, 70)
    StatusLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    StatusLabel.TextSize = 16
    StatusLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular)
    StatusLabel.Text = "Idle"
    StatusLabel.TextStrokeTransparency = 0.5
    StatusLabel.Parent = Auto
    StatusLabel.BorderSizePixel = 0
    
    -- Button click handler
    ToggleButton.MouseButton1Click:Connect(function()
        Settings.Play = not Settings.Play
        
        if Settings.Play then
            ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            ToggleButton.Text = "ON"
        else
            ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            ToggleButton.Text = "OFF"
            -- Reset script state when turned off
            Highligh.Parent = nil
            Highligh.Adornee = nil
            Cached = nil
            CurrentTarget = nil
            IsRunning = false
            IsPatrolling = false
            StatusLabel.Text = "Idle"
        end
    end)
    
    -- Main loop
    Connect(RunService.Stepped, function()
        if not Settings["Play"] then return end
        
        local Character = LocalPlayer.Character
        
        if not Character then return end

        local Humanoid = Character:FindFirstChildOfClass('Humanoid')

        if not Humanoid or Humanoid.Health <= 0 then
            Highligh.Parent = nil
            Highligh.Adornee = nil
            Cached = nil
            CurrentTarget = nil
            IsRunning = false
            IsPatrolling = false
            StatusLabel.Text = "Dead"
            return
        end

        local HumanoidRootPart = Character:FindFirstChild('HumanoidRootPart')
        
        if not HumanoidRootPart then return end

        local Backpack = LocalPlayer:FindFirstChildOfClass('Backpack')
        
        if not Backpack then return end

        if not Character:FindFirstChild('Revolver') then
            local Tool = Backpack:FindFirstChild('Revolver')
            
            if Tool then
                StatusLabel.Text = "Equipping..."
                Humanoid:EquipTool(Tool)
            end
            
            return
        end

        if not Cached then
            StatusLabel.Text = "Setting up..."
            SetupCached(Character)
        end

        local Camera = workspace.CurrentCamera

        if Module.PlayersModule:CanFire() then
            LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
            LocalPlayer.CameraMinZoomDistance = 0.5
            LocalPlayer.CameraMaxZoomDistance = 0.5

            local Target = Module.PlayersModule:GetPlayers()

            if Target then
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, Target.Position)
                StatusLabel.Text = "Firing at " .. tostring(Target.Parent.Name)
            end

            VirtualUser:Button1Down(Vector2.new(0, 0), Camera.CFrame)
        else
            VirtualUser:Button1Up(Vector2.new(0, 0), Camera.CFrame)
        end

        local TargetDead = CurrentTarget and not Module.PlayersModule:IsAlive(CurrentTarget.Parent)

        if TargetDead then
            CurrentTarget = nil
            IsRunning = false
        end

        if not CurrentTarget then
            local NewTarget = Module.PlayersModule:GetPlayers()

            if NewTarget ~= CurrentTarget then
                CurrentTarget = NewTarget
                IsRunning = false
            end
        end

        local Target = CurrentTarget

        if not Target then
            StatusLabel.Text = "Hunting..."

            Highligh.Parent = nil
            Highligh.Adornee = nil
            PatrolSpawns()

            return
        end

        IsPatrolling = false
        
        Highligh.Parent = Target.Parent
        Highligh.Adornee = Target.Parent

        if not IsRunning then
            IsRunning = true

            task.spawn(function()
                StatusLabel.Text = "Walking to " .. tostring(Target.Parent.Name)
                
                local success, err = pcall(function()
                    Cached:Run(Target)
                end)

                if not success then
                    SkippedPlayers[Target] = tick()
                    CurrentTarget = nil
                    Cached = nil
                    IsRunning = false
                end
            end)
        end
    end)
end
