local DataStoreService = game:GetService("DataStoreService")
local JailTimeStore = DataStoreService:GetDataStore("JailTime")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JailEvent = ReplicatedStorage:WaitForChild("CuffRep"):WaitForChild("Jail")
local sttng = require(ReplicatedStorage:WaitForChild("CuffRep"):WaitForChild("Settings"))
local webhookURL = sttng.WebhookURL

-- Helper: send Discord webhook embed
local function sendMessageToDiscord(embed)
	local data = { embeds = {embed} }
	local jsonData = HttpService:JSONEncode(data)

	local success, response = pcall(function()
		return HttpService:PostAsync(webhookURL, jsonData, Enum.HttpContentType.ApplicationJson, false)
	end)

	if success then
		print("Embed sent successfully")
	else
		warn("Failed to send embed: " .. tostring(response))
	end
end

-- Helper: create embed for jail log and send it
local function sendEmbed(player: Player, target: Player, time: number)
	local embed = {
		title = "Cuff Log",
		description = "A player got jailed!",
		color = 0x000000,
		fields = {
			{
				name = "Who Jailed the Player:",
				value = string.format("UserName: %s\nUserId: %s", player.Name, player.UserId),
				inline = false,
			},
			{
				name = "Jailed Player Info:",
				value = string.format("UserName: %s\nUserId: %s", target.Name, target.UserId),
				inline = false,
			},
			{
				name = "Jailed Time:",
				value = string.format("Time: %s", tostring(time)),
				inline = false,
			},
		},
		footer = {
			text = "Cuff Engine By pwntime2",
			icon_url = "https://media.discordapp.net/attachments/1338450594892877824/1338768547522023454/bug_report_60dp_FFFFFF_FILL0_wght400_GRAD0_opsz48.png",
		},
	}

	sendMessageToDiscord(embed)
end

-- Helper: restore player to previous or default team after jail
local function restorePlayerTeam(player, previousTeam)
	if previousTeam == game.Teams:FindFirstChild("Jailed") then
		local autoTeam = nil
		for _, team in pairs(game.Teams:GetChildren()) do
			if team:IsA("Team") and team.AutoAssignable then
				autoTeam = team
				break
			end
		end
		if autoTeam then
			player.Team = autoTeam
			player:LoadCharacter()
		else
			-- No auto-assignable team found, clear team and respawn
			player.Team = nil
			player:LoadCharacter()
		end
	elseif previousTeam and previousTeam:IsA("Team") then
		player.Team = previousTeam
		player:LoadCharacter()
	else
		-- No previous team, clear team and respawn
		player.Team = nil
		player:LoadCharacter()
	end
end

-- On player join: create JailData and restore jail time if any
Players.PlayerAdded:Connect(function(player: Player)
	local JailData = Instance.new("Folder")
	JailData.Name = "JailData"
	JailData.Parent = player

	local jailtime = Instance.new("IntValue")
	jailtime.Name = "JailTime"
	jailtime.Value = 0
	jailtime.Parent = JailData

	local success, result = pcall(function()
		return JailTimeStore:GetAsync(tostring(player.UserId))
	end)

	if success and result and result > 0 then
		print("Loaded jail time for player:", player.Name, "Time:", result)
		local PreviousTeam = player.Team
		jailtime.Value = result
		player.Team = game.Teams:FindFirstChild("Jailed")
		player:LoadCharacter()

		task.spawn(function()
			task.wait(result)
			jailtime.Value = 0

			local removeSuccess, removeErr = pcall(function()
				JailTimeStore:RemoveAsync(tostring(player.UserId))
			end)
			if not removeSuccess then
				warn("Failed to remove jail time: " .. tostring(removeErr))
			end

			restorePlayerTeam(player, PreviousTeam)
		end)
	elseif not success then
		warn("Failed to load jail time for player: " .. player.Name .. " Error: " .. tostring(result))
	end
end)

-- On player leave: save their jail time
Players.PlayerRemoving:Connect(function(player: Player)
	local jailData = player:FindFirstChild("JailData")
	if jailData then
		local jailTime = jailData:FindFirstChild("JailTime")
		if jailTime then
			local success, errorMessage = pcall(function()
				JailTimeStore:SetAsync(tostring(player.UserId), jailTime.Value)
			end)
			if not success then
				warn("Failed to save jail time for player: " .. player.Name .. " Error: " .. tostring(errorMessage))
			end
		end
	end
end)

-- On game close: save jail times for all players
game:BindToClose(function()
	for _, player in pairs(Players:GetPlayers()) do
		local jailData = player:FindFirstChild("JailData")
		if jailData then
			local jailTime = jailData:FindFirstChild("JailTime")
			if jailTime then
				local success, errorMessage = pcall(function()
					JailTimeStore:SetAsync(tostring(player.UserId), jailTime.Value)
				end)
				if not success then
					warn("Failed to save jail time for player: " .. player.Name .. " Error: " .. tostring(errorMessage))
				end
			end
		end
	end
end)

-- Main jail event handler
JailEvent.OnServerEvent:Connect(function(player: Player, target, Time: number)
	local plr = nil

	if typeof(target) == "Instance" then
		if target:IsA("Player") then
			plr = target
		elseif target:IsA("Model") then
			plr = Players:GetPlayerFromCharacter(target)
		end
	end

	if not plr then
		warn("Invalid jailed player passed to JailEvent: " .. tostring(target))
		return
	end

	if not Time or type(Time) ~= "number" or Time <= 0 then
		warn("Invalid jail time passed to JailEvent: " .. tostring(Time))
		return
	end

	local PreviousTeam = plr.Team -- can be nil
	plr.Team = game.Teams:FindFirstChild("Jailed")
	plr:LoadCharacter()

	sendEmbed(player, plr, Time)

	local jailData = plr:FindFirstChild("JailData")
	if not jailData then
		jailData = Instance.new("Folder")
		jailData.Name = "JailData"
		jailData.Parent = plr
	end

	local JailTime = jailData:FindFirstChild("JailTime")
	if not JailTime then
		JailTime = Instance.new("IntValue")
		JailTime.Name = "JailTime"
		JailTime.Parent = jailData
	end
	JailTime.Value = Time

	local success, err = pcall(function()
		JailTimeStore:SetAsync(tostring(plr.UserId), JailTime.Value)
	end)
	if not success then
		warn("Failed to save jail time: " .. tostring(err))
	end

	task.spawn(function()
		task.wait(Time)
		JailTime.Value = 0
		restorePlayerTeam(plr, PreviousTeam)
	end)
end)
