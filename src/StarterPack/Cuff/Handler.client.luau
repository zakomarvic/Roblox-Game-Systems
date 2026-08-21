local Tool = script.Parent
local LocalPlayer = game.Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local UncuffEvent = script.Parent:WaitForChild("Uncuff")
local CuffServiceEvent = script.Parent:WaitForChild("CuffService")
local CuffingACharacter = false
local Equipped = false
local lastchar = nil
local sframe = game:GetService("ReplicatedStorage"):WaitForChild("CuffRep"):WaitForChild("Frame")
local BillboardGui = game:GetService("ReplicatedStorage"):WaitForChild("CuffRep"):WaitForChild("BillboardGui")
----------------------------------------------------
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
----------------------------------------------------
local function resetui()
	for i,v in LocalPlayer.PlayerGui:WaitForChild("CuffGui"):GetChildren() do
		if v:IsA("Frame") then
			v.Visible = false
		end
	end
end

Tool.Activated:Connect(function()
	local Target = Mouse.Target
	local distance = 0
	if Target and Target.Parent:FindFirstChild("Humanoid") then
		local MousePos = Mouse.Target.Position
		local PlayerPos = LocalPlayer.Character:WaitForChild("Head").Position
		distance = (MousePos-PlayerPos).Magnitude
	end
	--print(distance)
	if Target and Target.Parent and Target.Parent:FindFirstChild("Humanoid") and not CuffingACharacter and distance > 0 and distance <= 10 then
		CuffServiceEvent:FireServer(Target)
		--wait(2)
		if not Target.Parent:FindFirstChild("Cuffedhl") then
			local highlight = Instance.new("Highlight")
			highlight.FillColor = Color3.new(1, 0, 0)
			highlight.Name = "Cuffedhl"
			highlight.Parent = Target.Parent
		end

		if not Target.Parent:FindFirstChild("HumanoidRootPart"):FindFirstChild("BillboardGui") then
			local Billclone = BillboardGui:Clone()
			Billclone.Parent = Target.Parent:FindFirstChild("HumanoidRootPart")
			Billclone.Enabled = true
		end


		lastchar = Target.Parent
		CuffingACharacter = true
	else	
		if lastchar and lastchar:FindFirstChild("Humanoid") and lastchar:FindFirstChild("HumanoidRootPart"):FindFirstChild("BillboardGui") then
			local Billclone = lastchar:FindFirstChild("HumanoidRootPart"):FindFirstChild("BillboardGui")
			Billclone:Destroy()
		end
		resetui()

		if lastchar and lastchar:FindFirstChild("Humanoid") and lastchar:FindFirstChild("Cuffedhl") then
			local highlight =lastchar:FindFirstChild("Cuffedhl")
			highlight:Destroy()
		end
		UncuffEvent:FireServer()
		CuffingACharacter = false
	end
end)

local lastHighlightedCharacter = nil

local function search(actionName, inputState , target)

	if actionName == "Search" and inputState == Enum.UserInputState.Begin then
		--print("search")
		local scrollingFrame = LocalPlayer.PlayerGui:WaitForChild("CuffGui"):WaitForChild("Search").SF.ScrollingFrame

		for _, child in pairs(scrollingFrame:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		local plr = Players:GetPlayerFromCharacter(target)
		for i, v in plr:WaitForChild("Backpack"):GetChildren() do
			if v:IsA("Tool") then
				local clone = sframe:Clone()
				clone.TextLabel.Text = tostring(v)
				clone.Parent = LocalPlayer.PlayerGui:WaitForChild("CuffGui"):WaitForChild("Search").SF.ScrollingFrame
			end
		end
		local gui = LocalPlayer.PlayerGui:WaitForChild("CuffGui"):WaitForChild("Search")
		gui.TextLabel.Text = plr.Name.." Inventory"
		local t = gui:GetAttribute("VisibleState") or false 
		t = not t
		gui:SetAttribute("VisibleState", t)
		gui.Visible = t
	end

end

local function free(actionName, inputState)
	if actionName == "Free" and inputState == Enum.UserInputState.Begin then
		--print("free")
		CuffingACharacter = false
		if lastchar and lastchar:FindFirstChild("Humanoid") and lastchar:FindFirstChild("HumanoidRootPart"):FindFirstChild("BillboardGui") then
			local Billclone = lastchar:FindFirstChild("HumanoidRootPart"):FindFirstChild("BillboardGui")
			Billclone:Destroy()
		end
		if lastchar and lastchar:FindFirstChild("Humanoid") and lastchar:FindFirstChild("Cuffedhl") then
			local highlight =lastchar:FindFirstChild("Cuffedhl")
			highlight:Destroy()
		end
		resetui()
		UncuffEvent:FireServer()
	end
end

local num:number = nil
local gui = LocalPlayer.PlayerGui:WaitForChild("CuffGui"):WaitForChild("Jail")
local tb = gui.TextBox
local trgt = nil
local JailEvent = game:GetService("ReplicatedStorage"):WaitForChild("CuffRep"):WaitForChild("Jail")

tb.FocusLost:Connect(function(enterPressed: boolean) 
	num = tonumber(tb.Text)	
	--print(num)
	if enterPressed then
		num = tonumber(tb.Text)	
		print(num)
	end
end)

gui.Button.Activated:Connect(function() 
	print(num)
	print(trgt)
	if num and trgt then
		JailEvent:FireServer(trgt, num)
		resetui()
	end
end)

local function jail(actionName, inputState, target)
	if actionName == "Jail" and inputState == Enum.UserInputState.Begin then
		--print(target)
		local gui = LocalPlayer.PlayerGui:WaitForChild("CuffGui"):WaitForChild("Jail")
		local t = gui:GetAttribute("VisibleState") or false 
		t = not t
		gui:SetAttribute("VisibleState", t)
		gui.Visible = t
		trgt = target
	end
end

Tool.Equipped:Connect(function() 
	Equipped = true
	while wait() and Equipped do
		local Target = Mouse.Target

		if Target and Target.Parent and Target.Parent:FindFirstChild("Humanoid") and CuffingACharacter then

			ContextActionService:BindAction("Search", function(actionName, inputState, inputObject)
				search(actionName, inputState, Target.Parent) -- Pass Target.Parent correctly
			end, false, Enum.KeyCode.T)
			ContextActionService:BindAction("Free", free, false, Enum.KeyCode.X)
			ContextActionService:BindAction("Jail", function(actionName, inputState, inputObject)
				jail(actionName, inputState, Target.Parent) -- Pass Target.Parent correctly
			end, false, Enum.KeyCode.J)

		end


		if Target and Target.Parent and Target.Parent:FindFirstChild("Humanoid") and not CuffingACharacter then
			local character = Target.Parent
			local MousePos = Mouse.Target.Position
			local PlayerPos = LocalPlayer.Character:WaitForChild("Head").Position
			local distance = (MousePos-PlayerPos).Magnitude
			--print(distance)

			if lastHighlightedCharacter and lastHighlightedCharacter ~= character then
				local oldHighlight = lastHighlightedCharacter:FindFirstChild("Highlight")
				if oldHighlight then
					oldHighlight:Destroy()
				end
			end

			if not character:FindFirstChild("Highlight") and distance <= 10 then
				local highlight = Instance.new("Highlight")
				highlight.FillColor = Color3.new(0.333333, 1, 0)
				highlight.Parent = character
			end

			lastHighlightedCharacter = character

		elseif lastHighlightedCharacter and (not Target or Target.Parent ~= lastHighlightedCharacter) then
			local oldHighlight = lastHighlightedCharacter:FindFirstChild("Highlight")
			if oldHighlight then
				oldHighlight:Destroy()
			end
			lastHighlightedCharacter = nil
		end
	end
end)

Tool.Unequipped:Connect(function()
	Equipped = false
	ContextActionService:UnbindAction("Free")
	ContextActionService:UnbindAction("Search")
	ContextActionService:UnbindAction("Jail")
	if lastchar and lastchar:FindFirstChild("Humanoid") and lastchar:FindFirstChild("Cuffedhl") then
		local highlight =lastchar:FindFirstChild("Cuffedhl")
		highlight:Destroy()
	end

	if lastHighlightedCharacter then
		local oldHighlight = lastHighlightedCharacter:FindFirstChild("Highlight")
		if oldHighlight then
			oldHighlight:Destroy()
		end
		lastHighlightedCharacter = nil
	end
	resetui()
	UncuffEvent:FireServer()
end)