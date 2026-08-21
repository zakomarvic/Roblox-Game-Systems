local Module = require(script.Parent.Parent:WaitForChild("Setting"))
local t=Module.MouseSensitive--MouseSpeed. 1 is regular mouse speed.

local atan2=math.atan2
local asin=math.asin
local abs=math.abs
local floor=math.floor
local cf=CFrame.new
local components=cf().components
local Angles=CFrame.Angles
local tau=2*math.pi
local RenderStepped=game:GetService("RunService").RenderStepped

local Player=game.Players.LocalPlayer
local Camera=workspace.CurrentCamera
local Character=Player.Character
local Head=Character:WaitForChild("Head")

local function EulerAnglesYX(c)--No z, I don't care about z.
	local _,_,_,m00,m01,m02,m10,m11,m12,m20,m21,m22=components(c)
	return abs(m12)>0.99999 and -atan2(-m20,m00) or -atan2(-m02,m22),-asin(m12)
end

local ly,lx=EulerAnglesYX(Camera.CoordinateFrame)
function Update()
	local cy,cx=EulerAnglesYX(Camera.CoordinateFrame)
	ly,lx=ly*(1-t)+(cy+tau*floor((ly-cy)/tau+0.5))*t,lx*(1-t)+(cx+tau*floor((lx-cx)/tau+0.5))*t
	--print(ly,lx)
	Camera.CoordinateFrame=Angles(0,ly,0)*Angles(lx,0,0)*cf(0,0,0.5)+Camera.Focus.p--Head.Position	
end
RenderStepped:connect(Update)

m=Player:GetMouse()
m.Button1Down:connect(function()
	zoom=true
	out=false
end)
m.Button1Up:connect(function()
	zoom=false
end)
m.Button2Down:connect(function()
	out=true
	zoom=false
end)
m.Button2Up:connect(function()
	out=false
end)