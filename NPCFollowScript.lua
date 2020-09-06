local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local DestroyScriptClone = game:GetService("ReplicatedStorage"):FindFirstChild("GlobalReplicatedStorage"):WaitForChild("Scripts"):WaitForChild("AutoDestroyScript"):Clone()

local Debug = require(game.ServerScriptService.GlobalServerScripts.DebugScript)
 
-- Variables for the NPC, its humanoid, and destination
local npc = script.Parent
local humanoid = npc:WaitForChild("Humanoid"); 
humanoid = npc.Humanoid
local HRP = npc:WaitForChild("HumanoidRootPart")
HRP = npc.HumanoidRootPart

local spawnPoint = HRP.Position

local FOLLOW_DISTANCE = 100;
local AGGRO_DISTANCE = 2;
local MIN_ACCEPTABLE_DISTANCE_TO_SPAWN = 4
local FRAMES_BETWEEN_EACH_RECALCULATION_OF_ACTIVE_PATH = 1
local isAggressive = true;

local target = nil
local targetType = ""
local currentPath = nil
local frames_since_last_path_recalculation = 0;
	
-- Create the path object
local currentPath = PathfindingService:CreatePath()
local character
-- Variables to store waypoints table and zombie's current waypoint
local waypoints
local currentWaypointIndex
CALCULATING_PATH = false

local eventConnectionBlocked = nil
local eventConnectionMoveFinished = nil

local NPCStates = {
	IDLE = "IDLE",
	FIGHTING_TARGET = "FIGHTING_TARGET",
	PERFORMING_CUSTOM_ACTION = "PERFORMING_CUSTOM_ACTION",
	GOING_TO_SPAWN = "GOING_TO_SPAWN"
}

local NPCState = NPCStates.IDLE

local agentConfig = {AgentRadius = 2, AgentHeight = 5}

-- Debug Variables.

local debugging = false;
local textLabelDist =   HRP:FindFirstChild("dist"):FindFirstChild("Frame"):FindFirstChild("TextLabelDist")
local textLabelTarget = HRP:FindFirstChild("dist"):FindFirstChild("Frame"):FindFirstChild("TextLabelTarget")
local textLabelNPCState = HRP:FindFirstChild("dist"):FindFirstChild("Frame"):FindFirstChild("TextLabelState")
local amountTimesConnected = 0
local amountTimesDisconnected = 0



function createWaypointPart()
	local newPart = Instance.new("Part")
	newPart.Shape = "Ball"
	newPart.Material = "Neon"
	newPart.Size = Vector3.new(1, 1, 1)
	newPart.Position = Vector3.new(0,0,0)
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.Parent = game.Workspace
	return newPart
end

-- Create part that we can use as 
local targetPart = createWaypointPart()


local waypointsFolder = Instance.new("Folder")
waypointsFolder.Name = "Waypoints"
waypointsFolder.Parent = script.Parent


local walkAnim = script.Parent.Animate.walk.WalkAnim
local idleAnim = script.Parent.Animate.idle.Animation1



-- Setup a constantly listening function on HeartBeat.
-- This function will Assign new targets for the NPC to follow automatically.


ms = 0
RunService.Heartbeat:Connect(function(t)
	
	 ms = ms - (1000 * t)
	
	

	
	if CALCULATING_PATH then		
		return 
	end
	
	


	
	
	--print("Current Path: " .. tostring(currentPath))
	--print("Amount of times Connected    " .. amountTimesConnected)
	--print("Amount of times Disconnected " .. amountTimesDisconnected)
	
	showDebugInfo()
	if Debug.isDebugging()  then
		textLabelNPCState.Parent.Visible = true
		targetPart.Transparency = 0
	else
		textLabelNPCState.Parent.Visible = false
		targetPart.Transparency = 1
	end
	
	
	if(NPCState == NPCStates.IDLE) then
		Debug.print("Running code for NPCStates.IDLE")
		--
		if currentPath == nil and target then
			--print("Setting a new path to target name " .. target.Name)
			findNewPathToTarget(target)
			
			
		elseif  target == nil and isAggressive then 
			local res = SearchForTarget()
			if res ~= nil then
				NPCState = NPCStates.FIGHTING_TARGET
				return
			end
				
		elseif  target and currentPath then		
			findNewPathIfTimeHasCome()
		end
		
		
	elseif (NPCState == NPCStates.FIGHTING_TARGET) then
		Debug.print("Running code for NPCStates.FIGHTING_TARGET")

		-- print("Distance to target return value: " .. tostring(distanceToTarget))
		
		-- If distance from Spawnpoint is too big while fighting a target, or distance to target is too big.
		-- Set target to nil and it will go back.
		if target and (distanceBetweenVectors(spawnPoint,HRP.position) > FOLLOW_DISTANCE or distanceToTarget() > FOLLOW_DISTANCE ) then
			Debug.print("Target is out of reach, Ending Search.")
			target = nil
			endPathFinding(currentPath)
			NPCState = NPCStates.GOING_TO_SPAWN
		
		elseif currentPath == nil and target then
			Debug.print("Setting a new path to target name " .. target.Name)
			findNewPathToTarget(target)
			
		
		elseif target == nil then
			endPathFinding(currentPath)
			NPCState = NPCStates.GOING_TO_SPAWN
		
		elseif target and currentPath then
			findNewPathIfTimeHasCome()
		end
			
		
	elseif (NPCState == NPCStates.PERFORMING_CUSTOM_ACTION) then
		Debug.print("Running code for NPCStates.PERFORMING_CUSTOM_ACTION")
		
		
		
	elseif (NPCState == NPCStates.GOING_TO_SPAWN) then
		Debug.print("Running code for NPCStates.GOING_TO_SPAWN")
		target = spawnPoint
		-- If the NPC has no target
		-- Move back to Spawn.
		if currentPath == nil then
			findNewPathToTarget(target)	
			
		elseif distanceToTarget() < MIN_ACCEPTABLE_DISTANCE_TO_SPAWN and distanceToTarget() ~= -1 then
			NPCState = NPCStates.IDLE
			target = nil
			endPathFinding(currentPath)
		elseif target and currentPath then
			findNewPathIfTimeHasCome()
		end
	end
	
	--[[
	if target and humanoid.MoveDirection.Magnitude > 0 then 
		
		for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
			if  track.Animation ~= walkAnim then
				local newAnim = humanoid:LoadAnimation(walkAnim)
				newAnim.Looped = true
				newAnim:Play()
			end
		end
		
		
		
	else
		for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
			if  track.Animation ~= walkAnim then
				local newAnim = humanoid:LoadAnimation(idleAnim)
				newAnim.Looped = true
				newAnim:Play()
			end
		end
			
	end
	
	]]--
	
	
	
	
end)	

function getTargetPosition()
	if target and typeof(target) == "Instance" and target["Character"] then
		return target.Character.HumanoidRootPart.Position
	end
	
	if target and typeof(target) == "Vector3" then
		 return target
	end
	
	return HRP.Position
end

function SearchForTarget()
	Debug.print("Search for target was called")
	local players = game.Players:GetPlayers()
	for i,p in pairs(players) do
		if p["Character"] and distanceBetweenVectors(p.Character.HumanoidRootPart.Position,getOwnPosition()) < AGGRO_DISTANCE then
			target = p
			print("NPC started following a target named: " .. target.Name )
			return target
		end		
	end
	
	return nil
	
	
end


function findNewPathToTarget(targetArgument)
	Debug.print("findNewPathToTarget called")
		
	-- If destination Object is nil, just quit.
	if targetArgument == nil then 
		return
	end 
	
	if CALCULATING_PATH then
		return 
	end

	CALCULATING_PATH = true
	-- Destination Object is not nil, 
	-- But What kind of Target are we dealing with?
	Debug.print("Determining what sort of Target we are dealing with!")
	
	if typeof(targetArgument) == "Instance" then 
		character = targetArgument["Character"]
		Debug.print("Target is a Character / Humanoid!")
		if character == nil then
		Debug.print("Target has no Character Attribute! Ending pathFinding.")
			return
		end
		
		Debug.print("Computing path to Target: " .. target.Name)
		targetType = "Humanoid"
		
		local startTime = ms
		currentPath = PathfindingService:CreatePath(agentConfig)
		Debug.print ( "Time currentPath Used." .. tostring(ms - startTime) )
		startTime = ms
		currentPath:ComputeAsync(npc.HumanoidRootPart.Position, character.HumanoidRootPart.Position)
		Debug.print ( "Time ComputeAsynch Used." .. tostring(ms - startTime) )
	
	elseif typeof(targetArgument) == "Vector3" then
		

		Debug.print("Target is a Vector3")
		targetType = "Vector3"
		currentPath = PathfindingService:CreatePath(agentConfig)
		currentPath:ComputeAsync(npc.HumanoidRootPart.Position, targetArgument)
	else
		Debug.print("No type for the target was found! Aborting search for path.")
		targetType = "Nothing"
		endPathFinding(currentPath)
		CALCULATING_PATH = false
		return
	end
	
	CALCULATING_PATH = false


	-- Empty waypoints table after each new path computation
	waypoints = {}
	


	if currentPath.Status == Enum.PathStatus.Success then

		-- Get the path waypoints and start NPC walking
		waypoints = currentPath:GetWaypoints()
		
		Debug.print("Path to Destination object was found, number of subPathgoals =  " .. #waypoints)
		-- Move to first waypoint
		
		
		-- This is so player dont start at the beginning of the calculated path,
		-- But start in the closest and cleverest one.
		local closestIndex = findClosestNodeToTargetInFrontOfNPC(waypoints)
		currentWaypointIndex = closestIndex
		
		humanoid:MoveTo(waypoints[currentWaypointIndex].Position)
		
		
		
		if Debug.isDebugging() then
			-- move the debugging final part to where the goal is.
			targetPart.Position = waypoints[#waypoints].Position
		
			-- Visualize Path
			visualizePath(waypoints)
			
		end
		 
		
		
		
		if eventConnectionBlocked then
			eventConnectionBlocked:Disconnect()
			Debug.print("eventConnectionBlocked was Disconnected")
			amountTimesDisconnected+=1
		end
		
		if eventConnectionMoveFinished then 
			eventConnectionMoveFinished:Disconnect()
			Debug.print("eventConnectionMoveFinished was Disconnected")
		end

		-- Connect 'Blocked' event to the 'onPathBlocked' function
		eventConnectionBlocked = currentPath.Blocked:Connect(onPathBlocked)
		 
		-- Connect 'MoveToFinished' event to the 'onWaypointReached' function
		eventConnectionMoveFinished = humanoid.MoveToFinished:Connect(onWaypointReached)
		
		amountTimesConnected+=1
		
	else
		-- Error (path not found); stop humanoid
		Debug.print("Path to Destination object was NOT found")
		--humanoid:MoveTo(npc.HumanoidRootPart.Position)
		-- endPathFinding(currentPath)
	end
	

end
	 
function onWaypointReached(reached)
	Debug.print("Waypoint Reached, currently at point #" .. tostring(currentWaypointIndex))
	if reached and currentWaypointIndex ~= nil and currentWaypointIndex < #waypoints then
		currentWaypointIndex = currentWaypointIndex + 1
		humanoid:MoveTo(waypoints[currentWaypointIndex].Position)
	end
	
	if reached and waypoints and currentWaypointIndex == #waypoints then
		Debug.print("Waypoint Reached Final Waypoint. ENDING PATHFINDING.")
		endPathFinding(currentPath)
		--humanoid:MoveTo(npc.HumanoidRootPart.Position)
	end
	
end
	 
function onPathBlocked(blockedWaypointIndex)
	Debug.print("Path was Blocked, attempting to recalculate path")
	-- Check if the obstacle is further down the path
	if blockedWaypointIndex > currentWaypointIndex then
		endPathFinding(currentPath)
	end
end












function distanceBetweenVectors(a,b)
	return (a - b).Magnitude
end

function distanceToTarget()
	
	Debug.print ( "type of target : " .. typeof(target) )
	if target and typeof(target) == "Instance" and target["Character"] then
		return (npc.HumanoidRootPart.Position - target.Character.HumanoidRootPart.Position).Magnitude
	end
	
	if target and typeof(target) == "Vector3" then
		return (npc.HumanoidRootPart.Position - target).Magnitude
	end
	
	return -1
end




function getOwnPosition()
	return HRP.position;
end
	


function endPathFinding(path)
	
	Debug.print("end path finding was called")
	
	-- Disconnect Events connected to current path.
	
	-- Set the waypoints to nil
	waypoints = nil
	-- Set current WaypointIndex to nil
	currentWaypointIndex = nil
	--And set Current path to nil
	currentPath:Destroy()
	
	
	-- Delete the small Nodes that show the path created for the NPC.
	deletePathVisualization()
end


function visualizePath(waypoints)
	
	for i,v in pairs(waypoints) do 
		local targetPart = Instance.new("Part")
		targetPart.Shape = "Ball"
		targetPart.Material = "Neon"
		targetPart.Size = Vector3.new(0.6, 0.6, 0.6)
		targetPart.Position = v.Position
		targetPart.Anchored = true
		targetPart.CanCollide = false
		targetPart.Parent = waypointsFolder
	end 
end

function deletePathVisualization(waypoints)
	waypointsFolder:ClearAllChildren()
end

function showDebugInfo()
	
	--	print("TextLabelDist" .. tostring(textLabelDist))
	--	print("TextLabelTarget" .. tostring(textLabelTarget))
	
	if target then
		
		textLabelNPCState.Parent.Visible = true
		textLabelDist.Visible = true
		textLabelTarget.Visible = true
		textLabelNPCState.Visible = true
		if typeof(target) == "Instance" then 
			
			textLabelTarget.Text = target.Name
			
			if target["Character"] then 
				textLabelDist.Text = math.floor(distanceBetweenVectors(target.Character.HumanoidRootPart.Position,getOwnPosition()))
			end
			
		else 
			textLabelTarget.Text = tostring(target)
			textLabelDist.Text = math.floor(distanceToTarget())
		end

		textLabelNPCState.Text = NPCState
	else
		textLabelNPCState.Parent.Visible = false
		textLabelDist.Visible = false
		textLabelTarget.Visible = false
		textLabelNPCState.Visible = false
	end	
	
end



function findNewPathIfTimeHasCome()
	
	if CALCULATING_PATH then return end
	
	if currentPath and frames_since_last_path_recalculation > FRAMES_BETWEEN_EACH_RECALCULATION_OF_ACTIVE_PATH then
		endPathFinding(currentPath)
		-- While waiting for next target
		humanoid:MoveTo(getTargetPosition())
		-- Just move.
		findNewPathToTarget(target)
		frames_since_last_path_recalculation = 0
	else
		frames_since_last_path_recalculation += 1
	end
	
end


function findClosestNodeToTargetInFrontOfNPC(waypoints)
	local closestDistance = math.huge
	local closestPoint = waypoints[1]
	local closestIndex = 1
	
	local frontPositionObject = createWaypointPart()
	frontPositionObject.CFrame = HRP.CFrame * CFrame.new(0,0,-10) 
	-- Create an object that is in front of the player
		
	frontPositionObject.Parent = game.Workspace
	local DestroyScript = DestroyScriptClone:Clone()
	DestroyScript.Parent = frontPositionObject
	
	if true ~= Debug.isDebugging() then
		frontPositionObject.Transparency = 1
	end
	
	
	
	for i,v in pairs(waypoints) do
		local dist = distanceBetweenVectors(frontPositionObject.Position,v.Position)
		if dist < closestDistance then
			closestDistance = dist
			closestPoint = v 
			closestIndex = i
		end
	end
	
	return closestIndex
	
end