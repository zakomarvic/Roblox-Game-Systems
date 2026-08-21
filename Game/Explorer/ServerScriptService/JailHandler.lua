local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local JailTimeStore = DataStoreService:GetDataStore("JailTime")
local CuffRep = ReplicatedStorage:WaitForChild("CuffRep")
local JailEvent = CuffRep:WaitForChild("Jail")
local Settings = require(CuffRep:WaitForChild("Settings"))
local WebhookURL = Settings.WebhookURL

local JailedTeam = Teams:FindFirstChild("Jailed")
local ActiveJails = {}
local SaveInProgress = {}

local function getJailData(player)
	local jailData = player:FindFirstChild("JailData")
	if not jailData then
		jailData = Instance.new("Folder")
		jailData.Name = "JailData"
		jailData.Parent = player
	end

	local jailTime = jailData:FindFirstChild("JailTime")
	if not jailTime then
		jailTime = Instance.new("IntValue")
		jailTime.Name = "JailTime"
		jailTime.Value = 0
		jailTime.Parent = jailData
	end

	return jailData, jailTime
end

local function getAutoAssignableTeam()
	for _, team in ipairs(Teams:GetChildren()) do
		if team:IsA("Team") and team.AutoAssignable and team ~= JailedTeam then
			return team
		end
	end

	return nil
end

local function restorePlayerTeam(player, previousTeamName)
	if not player.Parent then
		return
	end

	local previousTeam = previousTeamName and Teams:FindFirstChild(previousTeamName)
	local team = previousTeam

	if not team or team == JailedTeam then
		team = getAutoAssignableTeam()
	end

	player.Team = team
	player:LoadCharacter()
end

local function sendMessageToDiscord(embed)
	if not WebhookURL or WebhookURL == "" then
		return
	end

	local success, response = pcall(function()
		local data = HttpService:JSONEncode({embeds = {embed}})
		return HttpService:PostAsync(
			WebhookURL,
			data,
			Enum.HttpContentType.ApplicationJson,
			false
		)
	end)

	if not success then
		warn("Failed to send jail webhook: " .. tostring(response))
	end
end

local function sendJailLog(player, target, time)
	sendMessageToDiscord({
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
	})
end

local function readStoredJailData(result)
	if type(result) == "number" then
		-- Backwards compatibility with the old datastore format.
		return math.max(0, math.floor(result)), nil
	end

	if type(result) == "table" then
		local time = tonumber(result.Time) or tonumber(result.JailTime) or 0
		local previousTeam = result.PreviousTeam
		if type(previousTeam) ~= "string" then
			previousTeam = nil
		end
		return math.max(0, math.floor(time)), previousTeam
	end

	return 0, nil
end

local function savePlayerJail(player)
	local _, jailTime = getJailData(player)
	local remaining = math.max(0, math.floor(jailTime.Value))

	if remaining <= 0 then
		local success, err = pcall(function()
			JailTimeStore:RemoveAsync(tostring(player.UserId))
		end)
		if not success then
			warn("Failed to clear jail time for " .. player.Name .. ": " .. tostring(err))
		end
		return success
	end

	local jailState = ActiveJails[player]
	local previousTeam = jailState and jailState.PreviousTeam
	local data = {
		Time = remaining,
		PreviousTeam = previousTeam,
	}

	local success, err = pcall(function()
		JailTimeStore:SetAsync(tostring(player.UserId), data)
	end)

	if not success then
		warn("Failed to save jail time for " .. player.Name .. ": " .. tostring(err))
	end

	return success
end

local function stopJailTimer(player)
	local state = ActiveJails[player]
	if state then
		state.Token += 1
		ActiveJails[player] = nil
	end
end

local function startJailTimer(player, previousTeamName)
	stopJailTimer(player)

	local _, jailTime = getJailData(player)
	local token = 1
	local state = {
		Token = token,
		PreviousTeam = previousTeamName,
	}
	ActiveJails[player] = state

	task.spawn(function()
		while player.Parent and state.Token == token and jailTime.Value > 0 do
			task.wait(1)

			if not player.Parent or state.Token ~= token then
				return
			end

			jailTime.Value = math.max(0, jailTime.Value - 1)
		end

		if not player.Parent or state.Token ~= token then
			return
		end

		ActiveJails[player] = nil

		local success, err = pcall(function()
			JailTimeStore:RemoveAsync(tostring(player.UserId))
		end)
		if not success then
			warn("Failed to clear expired jail time for " .. player.Name .. ": " .. tostring(err))
		end

		restorePlayerTeam(player, state.PreviousTeam)
	end)
end

Players.PlayerAdded:Connect(function(player)
	local _, jailTime = getJailData(player)

	local success, result = pcall(function()
		return JailTimeStore:GetAsync(tostring(player.UserId))
	end)

	if not success then
		warn("Failed to load jail time for " .. player.Name .. ": " .. tostring(result))
		return
	end

	local remaining, previousTeamName = readStoredJailData(result)
	if remaining <= 0 then
		return
	end

	if not JailedTeam then
		warn("Jailed team does not exist; cannot jail " .. player.Name)
		return
	end

	jailTime.Value = remaining
	player.Team = JailedTeam
	player:LoadCharacter()
	startJailTimer(player, previousTeamName)
end)

Players.PlayerRemoving:Connect(function(player)
	stopJailTimer(player)

	if SaveInProgress[player] then
		return
	end

	SaveInProgress[player] = true
	savePlayerJail(player)
	SaveInProgress[player] = nil
end)

game:BindToClose(function()
	local players = Players:GetPlayers()
	local remaining = #players

	if remaining == 0 then
		return
	end

	for _, player in ipairs(players) do
		task.spawn(function()
			stopJailTimer(player)
			savePlayerJail(player)
			remaining -= 1
		end)
	end

	local deadline = os.clock() + 25
	while remaining > 0 and os.clock() < deadline do
		task.wait()
	end
end)

JailEvent.OnServerEvent:Connect(function(player, target, time)
	local targetPlayer

	if typeof(target) == "Instance" then
		if target:IsA("Player") then
			targetPlayer = target
		elseif target:IsA("Model") then
			targetPlayer = Players:GetPlayerFromCharacter(target)
		end
	end

	if not targetPlayer then
		warn("Invalid jailed player passed to JailEvent: " .. tostring(target))
		return
	end

	if targetPlayer == player then
		return
	end

	if typeof(time) ~= "number" or time <= 0 or time ~= time then
		warn("Invalid jail time passed to JailEvent: " .. tostring(time))
		return
	end

	if not JailedTeam then
		warn("Jailed team does not exist; cannot jail " .. targetPlayer.Name)
		return
	end

	local _, jailTime = getJailData(targetPlayer)
	local existingState = ActiveJails[targetPlayer]
	local previousTeamName = existingState and existingState.PreviousTeam

	if not previousTeamName and targetPlayer.Team and targetPlayer.Team ~= JailedTeam then
		previousTeamName = targetPlayer.Team.Name
	end

	stopJailTimer(targetPlayer)

	jailTime.Value = math.floor(time)
	targetPlayer.Team = JailedTeam
	targetPlayer:LoadCharacter()

	local saveSuccess = pcall(function()
		JailTimeStore:SetAsync(tostring(targetPlayer.UserId), {
			Time = jailTime.Value,
			PreviousTeam = previousTeamName,
		})
	end)

	if not saveSuccess then
		warn("Failed to save jail time for " .. targetPlayer.Name)
	end

	sendJailLog(player, targetPlayer, jailTime.Value)
	startJailTimer(targetPlayer, previousTeamName)
end)
