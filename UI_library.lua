-- StarterGui > LocalScript に貼り付け
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ScreenGui
local sg = Instance.new("ScreenGui")
sg.Name = "Rounded16x9UI"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = playerGui

-- Main Frame (16:9)
local frame = Instance.new("Frame")
frame.Name = "Card"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromScale(0, 0)  -- アニメ用に 0 スタート
frame.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
frame.BackgroundTransparency = 0.03
frame.BorderSizePixel = 0
frame.Parent = sg

-- 16:9 固定
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 16 / 9
aspect.AspectType = Enum.AspectType.ScaleWithParentSize
aspect.DominantAxis = Enum.DominantAxis.Width
aspect.Parent = frame

-- 角丸（相対サイズで追従）
local corner = Instance.new("UICorner")
corner.Parent = frame
RunService.RenderStepped:Connect(function()
	local vp = workspace.CurrentCamera.ViewportSize
	corner.CornerRadius = UDim.new(0, math.min(vp.X, vp.Y) * 0.025)
end)

-- 枠線
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 150, 255)
stroke.Thickness = 2
stroke.Transparency = 0.25
stroke.Parent = frame

-- 内側パディング + レイアウト
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 28)
pad.PaddingBottom = UDim.new(0, 28)
pad.PaddingLeft = UDim.new(0, 28)
pad.PaddingRight = UDim.new(0, 28)
pad.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 14)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Parent = frame

-- タイトル
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "🎮  GAME MENU"
title.TextColor3 = Color3.fromRGB(230, 235, 245)
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = frame

-- 区切り線
local divider = Instance.new("Frame")
divider.Size = UDim2.new(0.4, 0, 0, 2)
divider.BackgroundColor3 = Color3.fromRGB(90, 150, 255)
divider.BackgroundTransparency = 0.3
divider.BorderSizePixel = 0
divider.Parent = frame
Instance.new("UICorner", divider).CornerRadius = UDim.new(1, 0)

-- ボタン生成関数
local function addBtn(text, bgColor, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.65, 0, 0, 50)
	btn.BackgroundColor3 = bgColor
	btn.Text = text
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Parent = frame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 0.15}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.05), {Size = UDim2.new(0.63, 0, 0, 48)}):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Back), {Size = UDim2.new(0.65, 0, 0, 50)}):Play()
		if callback then callback() end
	end)
	return btn
end

addBtn("▶  Play", Color3.fromRGB(50, 180, 100), function()
	print("Play pressed")
end)
addBtn("⚙  Settings", Color3.fromRGB(70, 130, 255), function()
	print("Settings pressed")
end)
addBtn("✕  Quit", Color3.fromRGB(220, 70, 70), function()
	print("Quit pressed")
end)

-- 入場アニメ
TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
	Size = UDim2.fromScale(0.82, 0.82 * 9 / 16)
}):Play()

-- ESC で閉じる（任意）
game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.Escape then
		local tween = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromScale(0, 0)
		})
		tween:Play()
		tween.Completed:Wait()
		sg:Destroy()
	end
end)
