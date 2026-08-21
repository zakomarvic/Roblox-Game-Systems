local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local WeaponGUI = {}
WeaponGUI.__index = WeaponGUI

function WeaponGUI.new(GUI, Module, Controller)
	local self = setmetatable({}, WeaponGUI)
	self.GUI = GUI
	self.Module = Module
	self.Controller = Controller
	return self
end

function WeaponGUI:_TweenFill(Fill, Scale)
	if not Fill then
		return
	end

	Scale = math.clamp(tonumber(Scale) or 0, 0, 1)

	TweenService:Create(
		Fill,
		TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(Scale, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
		}
	):Play()
end

function WeaponGUI:Update()
	local GUI = self.GUI
	local Module = self.Module
	local Controller = self.Controller
	local CurrentAmmo = Controller:GetAmmo()
	local CurrentClips = Controller:GetClips()
	local AmmoPerClip = Module.AmmoPerClip
	local MaxClip = Module.MaxClip
	local LimitedClipEnabled = Module.LimitedClipEnabled == true

	if LimitedClipEnabled and typeof(MaxClip) == "number" and MaxClip > 0 then
		self:_TweenFill(GUI.Frame.Clips.Fill, CurrentClips / MaxClip)
	end

	if typeof(AmmoPerClip) == "number" and AmmoPerClip > 0 and AmmoPerClip ~= math.huge then
		self:_TweenFill(GUI.Frame.Ammo.Fill, CurrentAmmo / AmmoPerClip)
	end

	GUI.Frame.Ammo.Current.Text = tostring(CurrentAmmo)
	GUI.Frame.Ammo.Max.Text = tostring(AmmoPerClip or "∞")

	if LimitedClipEnabled then
		GUI.Frame.Clips.Current.Text = tostring(CurrentClips)
		GUI.Frame.Clips.Max.Text = tostring(MaxClip or "∞")
	end

	local Reloading = Controller:GetReloading()
	GUI.Frame.Ammo.Current.Visible = not Reloading
	GUI.Frame.Ammo.Max.Visible = not Reloading
	GUI.Frame.Ammo.Frame.Visible = not Reloading
	GUI.Frame.Ammo.Reloading.Visible = Reloading

	local HasClips = LimitedClipEnabled and CurrentClips > 0
	GUI.Frame.Clips.Current.Visible = HasClips
	GUI.Frame.Clips.Max.Visible = HasClips
	GUI.Frame.Clips.Frame.Visible = HasClips
	GUI.Frame.Clips.NoMoreClip.Visible = LimitedClipEnabled and not HasClips
	GUI.Frame.Clips.Visible = LimitedClipEnabled
	GUI.Frame.Size = LimitedClipEnabled
		and UDim2.new(0, 250, 0, 100)
		or UDim2.new(0, 250, 0, 55)
	GUI.Frame.Position = LimitedClipEnabled
		and UDim2.new(1, -260, 1, -110)
		or UDim2.new(1, -260, 1, -65)
end

function WeaponGUI:Show()
	if self.Module.AmmoPerClip ~= math.huge then
		self.GUI.Parent = Players.LocalPlayer.PlayerGui
	end
end

function WeaponGUI:Hide()
	self.GUI.Parent = nil
end

return WeaponGUI
