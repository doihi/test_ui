--[[
	UI_library.lua
	Minecraft Client 風 Roblox UI ライブラリ (Lunar / Badlion 風)

	特徴:
	 ・ 横長ウィンドウに カテゴリタブ を上部に横並び表示 (Combat / Movement / Render / Utility など)
	 ・ タブをクリック (右クリックでも可) でパネルが下にスライドして切り替わる
	 ・ 各カテゴリの中に 好きな名前を入力できる 名前欄 (TextBox)
	 ・ トグルはクリックで ON/OFF。ON になると enabled color (アクセントカラー) に変化
	 ・ スライダー・ボタンも同梱

	使い方:
		local UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/あなたのURL/UI_library.lua"))()
		-- またはソースコードを直接スクリプトに貼り付け

		local UI = UILibrary:CreateWindow({ Name = "Minecraft Client", Size = UDim2.fromOffset(720, 460) })

		local Combat = UI:CreateDropdown("Combat")
		Combat:AddToggle({ Text = "Kill Aura", Default = true, Callback = function(v) print(v) end })
		Combat:AddNameInput({ Text = "名前", Placeholder = "好きな名前を入力", Callback = function(name) print(name) end })

		-- カテゴリはタブをクリック (右クリックでも可) で切り替えられます

	CreateWindow の追加オプション:
		OutlineColor = Color3.fromRGB(r, g, b) -- ウィンドウのアウトラインカラー
		Glow         = false                    -- 外側のグローを無効化
		GlowColor    = Color3.fromRGB(r, g, b)  -- グローの色 (デフォルトは緑)
		GlowSize     = 24                       -- グロー画像の広がり (px)
		GlowImage    = "rbxassetid://..."       -- グロー用 PNG (省略時は GitHub から自動取得)
		GlowTransparency = 0.6                  -- グロー画像の透明度
		ToggleKey    = Enum.KeyCode.RightControl -- UI を開閉するキー (false で無効化)
]]

local UILibrary = {}

-- サービス
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- エグゼキュータ互換 (gethui / protectgui)
local protectgui = protectgui or (syn and syn.protect_gui) or function() end
local gethui = gethui or function()
	return game:GetService("CoreGui")
end

-- フォント解決 (古いクライアントでもエラーにならないようにフォールバック)
local function resolveFont(name, fallback)
	local success, font = pcall(function()
		return Enum.Font[name]
	end)
	if success and font then
		return font
	end
	return fallback
end

-- テーマ (Minecraft 風のダークUI)
local Theme = {
	Background    = Color3.fromRGB(16, 16, 16),   -- ウィンドウ背景
	Panel         = Color3.fromRGB(30, 30, 30),   -- 行 / ドロップダウン
	PanelHover    = Color3.fromRGB(42, 42, 42),
	Input         = Color3.fromRGB(12, 12, 12),   -- 入力欄
	Border        = Color3.fromRGB(78, 78, 78),
	Text          = Color3.fromRGB(240, 240, 240),
	TextDim       = Color3.fromRGB(150, 150, 150),
	Accent        = Color3.fromRGB(90, 235, 130), -- enabled color (ON 時の色)
	AccentDim     = Color3.fromRGB(50, 120, 70),
	Disabled      = Color3.fromRGB(58, 58, 58),   -- OFF 時のトグル色
	Danger        = Color3.fromRGB(235, 90, 90),
	Outline       = Color3.fromRGB(0, 0, 0),      -- 文字の縁取り (Minecraft 風)
	WindowOutline = Color3.fromRGB(78, 78, 78),   -- ウィンドウのアウトラインカラー
	GlowColor     = Color3.fromRGB(90, 235, 130), -- ウィンドウ外側のグローカラー
}

-- 設定
local Settings = {
	AnimationSpeed = 0.28,  -- スライドアニメーションの速さ
	HoverSpeed     = 0.12,
	Glow           = true,  -- ウィンドウ外側のグローを有効化
	GlowSize       = 24,    -- グロー画像の広がり (px)
	GlowTransparency = 0.6, -- グロー画像の透明度
}

local FONT_TITLE = resolveFont("Minecraft", resolveFont("GothamSemibold", Enum.Font.ArialBold))
local FONT_TEXT  = resolveFont("Minecraft", resolveFont("Gotham", Enum.Font.Arial))
local FONT_INPUT = resolveFont("Gotham", Enum.Font.Arial) -- 名前入力欄は日本語対応フォント

local TweenInfoOut  = TweenInfo.new(Settings.AnimationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenInfoFast = TweenInfo.new(Settings.HoverSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

UILibrary.Theme = Theme
UILibrary.Settings = Settings
UILibrary.Windows = {}

-- インスタンス生成ヘルパー
local function New(className, props, parent)
	local inst = Instance.new(className)
	for prop, value in pairs(props) do
		inst[prop] = value
	end
	inst.Parent = parent
	return inst
end

local function Round(value, decimals)
	local mult = 10 ^ (decimals or 0)
	return math.floor(value * mult + 0.5) / mult
end

local function MakeOutline(parent, transparency)
	return New("UIStroke", { Color = Theme.Outline, Thickness = 1, Transparency = transparency or 0.35 }, parent)
end

-- ============================================================
-- グロー画像アセット管理 (GitHub の PNG を取得して getcustomasset で使う)
-- ============================================================
local GlowAsset = {
	RobloxId = 127605550134602, -- アップロード済みの glow_texture.png (getcustomasset 優先)
	Path = "Obsidian/custom_assets/glow_texture.png",
	URL = "https://raw.githubusercontent.com/doihi/obsidian/main/asset/glow_texture.png",
	Id = nil,
}

local function EnsureFolders(path)
	if not isfolder or not makefolder then
		return
	end
	local segments = path:split("/")
	table.remove(segments, #segments)
	local current = ""
	for _, segment in ipairs(segments) do
		if not isfolder(current .. segment) then
			makefolder(current .. segment)
		end
		current = current .. segment .. "/"
	end
end

local function DownloadGlowAsset(force)
	if not getcustomasset or not writefile or not isfile then
		return false
	end
	EnsureFolders(GlowAsset.Path)
	if force ~= true and isfile(GlowAsset.Path) then
		return true
	end
	local ok = pcall(function()
		writefile(GlowAsset.Path, game:HttpGet(GlowAsset.URL))
	end)
	return ok
end

function UILibrary:GetGlowImage()
	if GlowAsset.Id then
		return GlowAsset.Id
	end
	local image = "rbxassetid://9146036312" -- getcustomasset 非対応環境の最終フォールバック
	if getcustomasset then
		local success, newId = pcall(getcustomasset, GlowAsset.Path)
		if success and newId then
			image = newId
		elseif GlowAsset.RobloxId > 0 then
			image = string.format("rbxassetid://%s", GlowAsset.RobloxId)
		end
	end
	GlowAsset.Id = image
	return image
end

DownloadGlowAsset()

-- ============================================================
-- ウィンドウ作成
-- ============================================================
function UILibrary:CreateWindow(config)
	config = config or {}

	local window = {}

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = config.Name or "UILibrary"
	screenGui.DisplayOrder = 100
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	protectgui(screenGui)
	screenGui.Parent = gethui()

	local size = config.Size or UDim2.fromOffset(720, 460) -- 横長 (ランドスケープ)
	local position = config.Position or UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2)

	-- アウトライン / グロー設定 (config で上書き可能)
	local outlineColor = config.OutlineColor or Theme.WindowOutline
	local glowEnabled = (config.Glow ~= false) and Settings.Glow
	local glowColor = config.GlowColor or Theme.GlowColor
	local glowSize = config.GlowSize or Settings.GlowSize
	local glowImage = config.GlowImage or UILibrary:GetGlowImage()
	local glowTransparency = config.GlowTransparency or Settings.GlowTransparency

	local main = New("Frame", {
		Name = "Main",
		Size = size,
		Position = position,
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
	}, screenGui)
	New("UICorner", { CornerRadius = UDim.new(0, 10) }, main)
	New("UIStroke", { Color = outlineColor, Thickness = 1.5, Transparency = 0.25 }, main)

	-- 外側のグロー (PNG 画像でぼかし風に。main の後ろに描画される別フレーム)
	local glowFrame = nil
	if glowEnabled then
		glowFrame = New("Frame", {
			Name = "Glow",
			Size = UDim2.new(size.X.Scale, size.X.Offset + glowSize * 2, size.Y.Scale, size.Y.Offset + glowSize * 2),
			Position = position,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, screenGui)

		local glowImageLabel = New("ImageLabel", {
			Name = "GlowImage",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = glowImage,
			ImageColor3 = glowColor,
			ImageTransparency = glowTransparency,
			ScaleType = Enum.ScaleType.Fit,
		}, glowFrame)
	end

	-- タイトルバー (ウィンドウと同じ背景色 + 区切り線)
	local titleBar = New("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
	}, main)
	New("UICorner", { CornerRadius = UDim.new(0, 10) }, titleBar)
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0, 41),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
	}, main)

	-- アイコン (草ブロック風の緑の四角)
	local icon = New("Frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	}, titleBar)
	New("UICorner", { CornerRadius = UDim.new(0, 3) }, icon)

	local titleLabel = New("TextLabel", {
		Text = config.Name or "Minecraft Client",
		Font = FONT_TITLE,
		TextSize = 17,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 32, 0, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, titleBar)
	MakeOutline(titleLabel, 0.35)

	New("TextLabel", {
		Text = "v1.0",
		Font = FONT_TEXT,
		TextSize = 13,
		TextColor3 = Theme.TextDim,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -50, 0, 0),
		Size = UDim2.new(0, 42, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, titleBar)

	-- カテゴリタブ (上部に横並び)
	local tabBar = New("Frame", {
		Name = "TabBar",
		Position = UDim2.new(0, 10, 0, 50),
		Size = UDim2.new(1, -20, 0, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, main)
	local tabLayout = New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, tabBar)

	-- パネル表示領域 (選択中のカテゴリを表示)
	local panelArea = New("ScrollingFrame", {
		Name = "PanelArea",
		Position = UDim2.new(0, 10, 0, 86),
		Size = UDim2.new(1, -20, 1, -94),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Border,
		CanvasSize = UDim2.new(0, 0, 0, 0),
	}, main)

	-- タブ選択管理
	local activeTab = nil
	local tabSelected = false
	local function updateCanvas()
		local h = 0
		if activeTab and activeTab._panel then
			h = activeTab._panel.Size.Y.Offset
		end
		panelArea.CanvasSize = UDim2.fromOffset(0, h)
	end
	function window:SelectTab(dropdown, animate)
		if activeTab == dropdown then
			return
		end
		if activeTab then
			activeTab._panel.Visible = false
			activeTab._tab.BackgroundColor3 = Theme.Panel
			activeTab._tab.TextColor3 = Theme.TextDim
			activeTab.Open = false
		end
		activeTab = dropdown
		tabSelected = true
		dropdown.Open = true
		dropdown._panel.Visible = true
		dropdown._panel.Size = UDim2.new(1, 0, 0, dropdown._contentHeight())
		dropdown._tab.BackgroundColor3 = Theme.Accent
		dropdown._tab.TextColor3 = Theme.Background
		if animate ~= false then
			dropdown._panel.Position = UDim2.new(0, 0, 0, -24)
			TweenService:Create(dropdown._panel, TweenInfoOut, {
				Position = UDim2.new(0, 0, 0, 0),
			}):Play()
		else
			dropdown._panel.Position = UDim2.new(0, 0, 0, 0)
		end
		panelArea.CanvasPosition = Vector2.zero
		updateCanvas()
	end

	-- ドラッグで移動 (文字等に阻まれないよう最前面の透明領域で受ける)
	local dragArea = New("Frame", {
		Name = "DragArea",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, titleBar)

	local dragging = false
	local dragOffset = Vector2.zero
	dragArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragOffset = input.Position - main.AbsolutePosition
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local newPos = input.Position - dragOffset
			main.Position = UDim2.fromOffset(newPos.X, newPos.Y)
			if glowFrame then
				glowFrame.Position = main.Position
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	-- キーバインドで UI を開閉 (デフォルト: RightControl、false で無効化)
	local toggleKey = config.ToggleKey
	if toggleKey == nil then
		toggleKey = Enum.KeyCode.RightControl
	end
	if toggleKey then
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not gameProcessed and input.KeyCode == toggleKey then
				screenGui.Enabled = not screenGui.Enabled
			end
		end)
	end
	function window:Toggle()
		screenGui.Enabled = not screenGui.Enabled
	end
	function window:SetToggleKey(key)
		toggleKey = key
	end

	-- ============================================================
	-- カテゴリ作成 (上部のタブ + パネル)
	-- ============================================================
	function window:CreateDropdown(name, dropdownConfig)
		dropdownConfig = dropdownConfig or {}

		local dropdown = {}
		dropdown.Open = false
		dropdown._rowOrder = 1

		-- タブ (上部に横並び)
		local tab = New("TextButton", {
			Name = "Tab_" .. tostring(name),
			Size = UDim2.new(0, 0, 0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.Panel,
			AutoButtonColor = false,
			Text = name or "Tab",
			Font = FONT_TEXT,
			TextSize = 15,
			TextColor3 = Theme.TextDim,
			TextStrokeColor3 = Theme.Outline,
			TextStrokeTransparency = 0.35,
			BorderSizePixel = 0,
		}, tabBar)
		New("UICorner", { CornerRadius = UDim.new(0, 8) }, tab)

		tab.MouseEnter:Connect(function()
			if activeTab ~= dropdown then
				TweenService:Create(tab, TweenInfoFast, { BackgroundColor3 = Theme.PanelHover }):Play()
			end
		end)
		tab.MouseLeave:Connect(function()
			if activeTab ~= dropdown then
				TweenService:Create(tab, TweenInfoFast, { BackgroundColor3 = Theme.Panel }):Play()
			end
		end)
		tab.MouseButton1Click:Connect(function()
			window:SelectTab(dropdown)
		end)
		tab.MouseButton2Click:Connect(function()
			window:SelectTab(dropdown)
		end)

		-- パネル (タブの中身、選択時のみ表示)
		local panel = New("Frame", {
			Name = "Panel_" .. tostring(name),
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
		}, panelArea)

		local panelList = New("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, panel)

		local function contentHeight()
			return panelList.AbsoluteContentSize.Y + 8
		end

		panelList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			panel.Size = UDim2.new(1, 0, 0, contentHeight())
			if dropdown.Open then
				updateCanvas()
			end
		end)

		dropdown._tab = tab
		dropdown._panel = panel
		dropdown._contentHeight = contentHeight

		-- 共通の行作成
		local function makeRow(height)
			local row = New("TextButton", {
				Size = UDim2.new(1, -16, 0, height),
				Position = UDim2.new(0, 8, 0, 0),
				BackgroundColor3 = Theme.Panel,
				AutoButtonColor = false,
				Text = "",
				BorderSizePixel = 0,
				LayoutOrder = dropdown._rowOrder,
			}, panel)
			dropdown._rowOrder = dropdown._rowOrder + 1
			New("UICorner", { CornerRadius = UDim.new(0, 8) }, row)

			row.MouseEnter:Connect(function()
				TweenService:Create(row, TweenInfoFast, { BackgroundColor3 = Theme.PanelHover }):Play()
			end)
			row.MouseLeave:Connect(function()
				TweenService:Create(row, TweenInfoFast, { BackgroundColor3 = Theme.Panel }):Play()
			end)
			return row
		end

		-- ============================================================
		-- トグル追加 (クリックで ON/OFF、enabled color に基づいて色が変わる)
		-- ============================================================
		function dropdown:AddToggle(toggleConfig)
			toggleConfig = toggleConfig or {}

			local row = makeRow(34)

			local label = New("TextLabel", {
				Text = toggleConfig.Text or "Toggle",
				Font = FONT_TEXT,
				TextSize = 14,
				TextColor3 = Theme.Text,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(1, -70, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}, row)
			MakeOutline(label, 0.4)

			-- ピル型スイッチ
			local pill = New("Frame", {
				Size = UDim2.fromOffset(42, 20),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Theme.Disabled,
				BorderSizePixel = 0,
			}, row)
			New("UICorner", { CornerRadius = UDim.new(0, 10) }, pill)

			local knob = New("Frame", {
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.new(0, 2, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.fromRGB(200, 200, 200),
				BorderSizePixel = 0,
			}, pill)
			New("UICorner", { CornerRadius = UDim.new(0, 8) }, knob)

			local toggle = {
				Value = toggleConfig.Default or false,
				Callback = toggleConfig.Callback or function() end,
			}

			local function apply(v)
				toggle.Value = v
				TweenService:Create(pill, TweenInfoFast, {
					BackgroundColor3 = v and Theme.Accent or Theme.Disabled,
				}):Play()
				TweenService:Create(knob, TweenInfoFast, {
					Position = v and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
				}):Play()
				TweenService:Create(label, TweenInfoFast, {
					TextColor3 = v and Theme.Text or Theme.TextDim,
				}):Play()
			end

			function toggle:Set(v, fire)
				v = not not v
				if toggle.Value ~= v then
					apply(v)
					if fire ~= false then
						task.spawn(toggle.Callback, v)
					end
				end
			end

			function toggle:Toggle()
				toggle:Set(not toggle.Value)
			end

			function toggle:Get()
				return toggle.Value
			end

			row.MouseButton1Click:Connect(function()
				toggle:Toggle()
			end)

			apply(toggle.Value)
			return toggle
		end

		-- ============================================================
		-- 名前入力欄追加 (好きな名前を入力)
		-- ============================================================
		function dropdown:AddNameInput(inputConfig)
			inputConfig = inputConfig or {}

			local row = makeRow(36)

			local label = New("TextLabel", {
				Text = inputConfig.Text or "名前",
				Font = FONT_INPUT,
				TextSize = 14,
				TextColor3 = Theme.Text,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(0, 90, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}, row)

			local box = New("TextBox", {
				Position = UDim2.new(0, 108, 0, 5),
				Size = UDim2.new(1, -120, 0, 26),
				BackgroundColor3 = Theme.Input,
				BorderSizePixel = 0,
				PlaceholderText = inputConfig.Placeholder or "好きな名前を入力...",
				PlaceholderColor3 = Theme.TextDim,
				Text = inputConfig.Default or "",
				TextColor3 = Theme.Text,
				Font = FONT_INPUT,
				TextSize = 14,
				ClearTextOnFocus = true,
			}, row)
			New("UICorner", { CornerRadius = UDim.new(0, 6) }, box)
			New("UIStroke", { Color = Theme.Border, Thickness = 1, Transparency = 0.5 }, box)

			local input = { Value = inputConfig.Default or "" }

			function input:Get()
				return input.Value
			end

			function input:Set(text)
				input.Value = tostring(text or "")
				box.Text = input.Value
			end

			function input:Clear()
				input:Set("")
			end

			box.FocusLost:Connect(function(enterPressed)
				input.Value = box.Text
				if inputConfig.Callback then
					task.spawn(inputConfig.Callback, input.Value, enterPressed)
				end
			end)

			return input
		end

		-- ============================================================
		-- スライダー追加
		-- ============================================================
		function dropdown:AddSlider(sliderConfig)
			sliderConfig = sliderConfig or {}

			local min = sliderConfig.Min or 0
			local max = sliderConfig.Max or 100
			local decimals = sliderConfig.Decimals or 0

			local row = makeRow(40)

			local label = New("TextLabel", {
				Text = sliderConfig.Text or "Slider",
				Font = FONT_TEXT,
				TextSize = 14,
				TextColor3 = Theme.Text,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(1, -110, 0, 20),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}, row)
			MakeOutline(label, 0.4)

			local valueLabel = New("TextLabel", {
				Text = "",
				Font = FONT_TEXT,
				TextSize = 13,
				TextColor3 = Theme.Accent,
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -104, 0, 0),
				Size = UDim2.new(0, 92, 0, 20),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
			}, row)

			local bar = New("TextButton", {
				Position = UDim2.new(0, 12, 0, 24),
				Size = UDim2.new(1, -24, 0, 12),
				BackgroundColor3 = Theme.Input,
				AutoButtonColor = false,
				Text = "",
				BorderSizePixel = 0,
			}, row)
			New("UICorner", { CornerRadius = UDim.new(0, 6) }, bar)
			New("UIStroke", { Color = Theme.Border, Thickness = 1, Transparency = 0.5 }, bar)

			local fill = New("Frame", {
				Size = UDim2.fromScale(0, 1),
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
			}, bar)
			New("UICorner", { CornerRadius = UDim.new(0, 6) }, fill)

			local knob = New("Frame", {
				Size = UDim2.fromOffset(10, 16),
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Text,
				BorderSizePixel = 0,
			}, bar)
			New("UICorner", { CornerRadius = UDim.new(0, 4) }, knob)

			local slider = {
				Value = min,
				Min = min,
				Max = max,
				Callback = sliderConfig.Callback or function() end,
			}
			local dragging = false

			local function fractionFromInput(input)
				local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
				return math.clamp(rel, 0, 1)
			end

			local function update(v, fire)
				v = Round(math.clamp(v, min, max), decimals)
				slider.Value = v

				local frac = (v - min) / (max - min)
				fill.Size = UDim2.fromScale(frac, 1)
				knob.Position = UDim2.new(frac, 0, 0.5, 0)
				valueLabel.Text = string.format("%." .. decimals .. "f", v)

				if fire ~= false then
					task.spawn(slider.Callback, v)
				end
			end

			function slider:Get()
				return slider.Value
			end

			function slider:Set(v, fire)
				update(v, fire)
			end

			bar.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					update(min + (max - min) * fractionFromInput(input), true)
				end
			end)
			bar.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
					update(min + (max - min) * fractionFromInput(input), true)
				end
			end)

			update(sliderConfig.Default or min, false)
			return slider
		end

		-- ============================================================
		-- ボタン追加
		-- ============================================================
		function dropdown:AddButton(buttonConfig)
			buttonConfig = buttonConfig or {}

			local row = makeRow(34)
			if buttonConfig.Color then
				row.BackgroundColor3 = buttonConfig.Color
			end

			local label = New("TextLabel", {
				Text = buttonConfig.Text or "Button",
				Font = FONT_TEXT,
				TextSize = 14,
				TextColor3 = Theme.Text,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}, row)
			MakeOutline(label, 0.4)

			row.MouseButton1Click:Connect(function()
				task.spawn(buttonConfig.Callback or function() end)
			end)

			local button = {}
			function button:SetText(text)
				label.Text = tostring(text or "")
			end
			return button
		end

		-- タブ選択 API
		function dropdown:SetOpen(open, animate)
			if open then
				window:SelectTab(dropdown, animate)
			end
		end

		function dropdown:Toggle(animate)
			if not dropdown.Open then
				window:SelectTab(dropdown, animate)
			end
		end

		-- 最初のカテゴリ or DefaultOpen なら最初から表示
		task.defer(function()
			if dropdownConfig.DefaultOpen or not tabSelected then
				window:SelectTab(dropdown, false)
			end
		end)

		return dropdown
	end

	-- ウィンドウ API
	function window:SetVisible(visible)
		screenGui.Enabled = visible
	end

	function window:GetVisible()
		return screenGui.Enabled
	end

	function window:Destroy()
		screenGui:Destroy()
	end

	table.insert(UILibrary.Windows, window)
	return window
end

-- 全ウィンドウ破棄
function UILibrary:Unload()
	for _, window in ipairs(UILibrary.Windows) do
		window:Destroy()
	end
	UILibrary.Windows = {}
end

return UILibrary
