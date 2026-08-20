--[[
	UI_library.lua
	Vape V4 風 Roblox UI ライブラリ

	特徴:
	 ・ メインウィンドウ自体が 220px 幅のサイドバー、高さはコンテンツに合わせて自動
	 ・ カテゴリーはクリックで切替、選択中はアクセント色 + 右端に矢印が表示される
	 ・ パネルはサイドバーの右隣に独立ウィンドウで開き、ヘッダーのドラッグで移動
	 ・ パネル右端を左クリック長押し + ドラッグで幅を縮小/拡大
	 ・ トグルは行全体がボタン。ON になるとアクセントカラーに変化
	 ・ スライダーは細バー + 円形ノブ、値はクリックで直接入力も可能
	 ・ 各カテゴリの中に 好きな名前を入力できる 名前欄 (TextBox)

	使い方:
		local UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/あなたのURL/UI_library.lua"))()
		-- またはソースコードを直接スクリプトに貼り付け

		local UI = UILibrary:CreateWindow({ Name = "Minecraft Client" })

		local Combat = UI:CreateDropdown("Combat")
		Combat:AddToggle({ Text = "Kill Aura", Default = true, Callback = function(v) print(v) end })
		Combat:AddNameInput({ Text = "名前", Placeholder = "好きな名前を入力", Callback = function(name) print(name) end })

		-- カテゴリーはサイドバーからクリックで切り替えられます

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

-- テーマ (Vape V4 風のダークUI)
local Theme = {
	Background    = Color3.fromRGB(26, 25, 26),   -- ウィンドウ背景 (uipallet.Main)
	Sidebar       = Color3.fromRGB(26, 25, 26),   -- カテゴリーリスト
	Panel         = Color3.fromRGB(26, 25, 26),   -- モジュール行
	PanelHover    = Color3.fromRGB(31, 30, 31),   -- 行ホバー
	Input         = Color3.fromRGB(31, 30, 31),   -- 入力欄
	Border        = Color3.fromRGB(85, 85, 85),   -- UIStroke 枠線
	Text          = Color3.fromRGB(200, 200, 200),-- uipallet.Text
	TextDim       = Color3.fromRGB(159, 159, 159),-- 非選択テキスト
	TextDim2      = Color3.fromRGB(90, 90, 90),   -- 補助テキスト (区切り等)
	Placeholder   = Color3.fromRGB(121, 121, 121),
	Accent        = Color3.fromRGB(90, 235, 130), -- enabled color (ON 時の色)
	AccentDim     = Color3.fromRGB(50, 120, 70),
	Disabled      = Color3.fromRGB(62, 61, 62),   -- トグル OFF (ホルダー)
	DisabledHover = Color3.fromRGB(120, 119, 120),-- トグル OFF ホバー
	SliderTrack   = Color3.fromRGB(35, 34, 35),   -- スライダーバー
	ButtonHolder  = Color3.fromRGB(39, 38, 39),   -- ボタン内枠
	ButtonHover   = Color3.fromRGB(48, 47, 48),   -- ボタン内枠ホバー
	Danger        = Color3.fromRGB(235, 90, 90),
	Outline       = Color3.fromRGB(0, 0, 0),      -- 文字の縁取り
	WindowOutline = Color3.fromRGB(85, 85, 85),   -- ウィンドウのアウトラインカラー
	GlowColor     = Color3.fromRGB(90, 235, 130), -- ウィンドウ外側のグローカラー
}

-- 設定
local Settings = {
	HoverSpeed     = 0.12,
	Glow           = true,  -- ウィンドウ外側のグローを有効化
	GlowSize       = 24,    -- グロー画像の広がり (px)
	GlowTransparency = 0.6, -- グロー画像の透明度
}

local FONT_TITLE = resolveFont("GothamSemibold", Enum.Font.ArialBold)
local FONT_TEXT  = resolveFont("Gotham", Enum.Font.Arial)
local FONT_INPUT = resolveFont("Gotham", Enum.Font.Arial) -- 名前入力欄は日本語対応フォント

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

	local position = config.Position or UDim2.fromOffset(6, 60) -- Vape V4 準拠の初期位置

	-- アウトライン / グロー設定 (config で上書き可能)
	local outlineColor = config.OutlineColor or Theme.WindowOutline
	local glowEnabled = (config.Glow ~= false) and Settings.Glow
	local glowColor = config.GlowColor or Theme.GlowColor
	local glowSize = config.GlowSize or Settings.GlowSize
	local glowImage = config.GlowImage or UILibrary:GetGlowImage()
	local glowTransparency = config.GlowTransparency or Settings.GlowTransparency

	local WINDOW_WIDTH = 220 -- Vape V4 準拠: メインウィンドウ = サイドバー幅

	local main = New("Frame", {
		Name = "Main",
		Size = UDim2.fromOffset(WINDOW_WIDTH, 0),
		Position = position,
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
	}, screenGui)
	New("UICorner", { CornerRadius = UDim.new(0, 8) }, main)
	New("UIStroke", { Color = outlineColor, Thickness = 1, Transparency = 0.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, main)

	-- 外側のグロー (PNG 画像でぼかし風に。main の後ろに描画される別フレーム)
	local glowFrame = nil
	if glowEnabled then
		glowFrame = New("Frame", {
			Name = "Glow",
			Size = UDim2.fromOffset(WINDOW_WIDTH + glowSize * 2, glowSize * 2),
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

	-- タイトルバー (サイドバーのヘッダー)
	local titleBar = New("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
	}, main)
	New("UICorner", { CornerRadius = UDim.new(0, 8) }, titleBar)
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0, 41),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
	}, main)

	-- アイコン (草ブロック風の緑の四角)
	local icon = New("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	}, titleBar)
	New("UICorner", { CornerRadius = UDim.new(0, 4) }, icon)

	local titleLabel = New("TextLabel", {
		Text = config.Name or "Minecraft Client",
		Font = FONT_TITLE,
		TextSize = 14,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 34, 0, 0),
		Size = UDim2.new(0.75, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, titleBar)
	MakeOutline(titleLabel, 0.4)

	New("TextLabel", {
		Text = "v1.0",
		Font = FONT_TEXT,
		TextSize = 11,
		TextColor3 = Theme.TextDim,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -34, 0, 0),
		Size = UDim2.new(0, 30, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, titleBar)

	-- カテゴリーリスト (メインウィンドウ本体)
	local categoryList = New("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, main)

	local function updateWindowHeight()
		-- AbsoluteContentSize は titleBar + divider + ボタン分を含むため +8 だけでよい
		local h = categoryList.AbsoluteContentSize.Y + 8
		main.Size = UDim2.fromOffset(WINDOW_WIDTH, h)
		if glowFrame then
			glowFrame.Size = UDim2.fromOffset(WINDOW_WIDTH + glowSize * 2, h + glowSize * 2)
		end
	end
	categoryList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateWindowHeight)
	task.defer(updateWindowHeight)

	-- カテゴリー選択管理 (選択中のみ右隣にパネルを表示)
	local activeDropdown = nil
	local function selectCategory(dropdown)
		if activeDropdown == dropdown then
			return
		end
		if activeDropdown then
			activeDropdown._panel.Visible = false
			activeDropdown._button.TextColor3 = Theme.TextDim
			activeDropdown._button.BackgroundColor3 = Theme.Background
			activeDropdown._arrow.TextColor3 = Theme.TextDim2
			activeDropdown.Open = false
		end
		activeDropdown = dropdown
		dropdown.Open = true
		dropdown._panel.Visible = true
		dropdown._button.TextColor3 = Theme.Accent
		dropdown._button.BackgroundColor3 = Theme.PanelHover
		dropdown._arrow.TextColor3 = Theme.Accent
	end
	function window:SelectTab(dropdown, animate)
		selectCategory(dropdown)
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
	-- カテゴリ作成 (左サイドバーに追加、右側パネルで表示)
	-- ============================================================
	function window:CreateDropdown(name, dropdownConfig)
		dropdownConfig = dropdownConfig or {}

		local dropdown = {}
		dropdown.Open = false

		-- サイドバーのカテゴリーボタン (Vape V4 の GUIButton 風)
		local button = New("TextButton", {
			Name = "Category_" .. tostring(name),
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Theme.Background,
			AutoButtonColor = false,
			Text = string.rep(" ", 12) .. (name or "Category"),
			Font = FONT_TEXT,
			TextSize = 14,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			BorderSizePixel = 0,
		}, main)

		-- 右端の選択矢印
		local arrow = New("TextLabel", {
			Text = "»",
			Font = FONT_TEXT,
			TextSize = 14,
			TextColor3 = Theme.TextDim2,
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -24, 0, 0),
			Size = UDim2.new(0, 16, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, button)

		button.MouseEnter:Connect(function()
			if activeDropdown ~= dropdown then
				TweenService:Create(button, TweenInfoFast, { BackgroundColor3 = Theme.PanelHover }):Play()
				TweenService:Create(button, TweenInfoFast, { TextColor3 = Theme.Text }):Play()
			end
		end)
		button.MouseLeave:Connect(function()
			if activeDropdown ~= dropdown then
				TweenService:Create(button, TweenInfoFast, { BackgroundColor3 = Theme.Background }):Play()
				TweenService:Create(button, TweenInfoFast, { TextColor3 = Theme.TextDim }):Play()
			end
		end)
		button.MouseButton1Click:Connect(function()
			window:SelectTab(dropdown)
		end)

		-- パネルウィンドウ (サイドバーの右隣に独立表示、ドラッグで移動)
		local panel = New("Frame", {
			Name = "Panel_" .. tostring(name),
			Size = UDim2.fromOffset(WINDOW_WIDTH, 41),
			Position = UDim2.fromOffset(236, 60),
			BackgroundColor3 = Theme.Background,
			BorderSizePixel = 0,
			Visible = false,
		}, screenGui)
		New("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
		New("UIStroke", { Color = Theme.WindowOutline, Thickness = 1, Transparency = 0.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)

		-- ヘッダー (ドラッグでパネル移動)
		local header = New("TextButton", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 41),
			BackgroundColor3 = Theme.Background,
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
		}, panel)
		New("UICorner", { CornerRadius = UDim.new(0, 8) }, header)
		New("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 0, 40),
			BackgroundColor3 = Theme.Border,
			BorderSizePixel = 0,
		}, panel)

		-- ヘッダー内: カテゴリーアイコン + 名前
		New("Frame", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(0, 12, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
		}, header)
		local headerLabel = New("TextLabel", {
			Text = name or "Category",
			Font = FONT_TITLE,
			TextSize = 13,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 34, 0, 0),
			Size = UDim2.new(0.7, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, header)
		MakeOutline(headerLabel, 0.4)

		-- モジュールリスト (ヘッダー下、コンテンツに合わせて高さ自動)
		local moduleList = New("ScrollingFrame", {
			Name = "ModuleList",
			Position = UDim2.new(0, 0, 0, 41),
			Size = UDim2.new(1, 0, 1, -41),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 2,
			ScrollBarImageTransparency = 0.75,
			CanvasSize = UDim2.new(0, 0, 0, 0),
		}, panel)

		local panelList = New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, moduleList)

		panelList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			local content = panelList.AbsoluteContentSize.Y
			moduleList.CanvasSize = UDim2.fromOffset(0, content)
			panel.Size = UDim2.fromOffset(panel.Size.X.Offset, math.min(41 + content, 601))
		end)

		-- ヘッダードラッグでパネル移動
		local panelDrag = false
		local panelDragOffset = Vector2.zero
		header.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				panelDrag = true
				panelDragOffset = input.Position - panel.AbsolutePosition
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if panelDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
				local newPos = input.Position - panelDragOffset
				panel.Position = UDim2.fromOffset(newPos.X, newPos.Y)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				panelDrag = false
			end
		end)

		-- 右端のリサイズハンドル (左クリック長押し + ドラッグで幅を縮小/拡大)
		local resizeHandle = New("Frame", {
			Name = "ResizeHandle",
			Size = UDim2.new(0, 8, 1, 0),
			Position = UDim2.new(1, -8, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, panel)

		local resizing = false
		local resizeStartX = 0
		local resizeStartWidth = 0
		resizeHandle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = true
				resizeStartX = input.Position.X
				resizeStartWidth = panel.AbsoluteSize.X
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
				local newWidth = math.max(WINDOW_WIDTH, resizeStartWidth + (input.Position.X - resizeStartX))
				panel.Size = UDim2.fromOffset(newWidth, panel.Size.Y.Offset)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = false
			end
		end)

		dropdown._button = button
		dropdown._arrow = arrow
		dropdown._panel = panel

		-- ============================================================
		-- トグル追加 (行全体がトグル、ON でアクセント色になる)
		-- ============================================================
		function dropdown:AddToggle(toggleConfig)
			toggleConfig = toggleConfig or {}

			local row = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Theme.Panel,
				AutoButtonColor = false,
				Text = string.rep(" ", 12) .. (toggleConfig.Text or "Toggle"),
				Font = FONT_TEXT,
				TextSize = 14,
				TextColor3 = Theme.TextDim,
				TextXAlignment = Enum.TextXAlignment.Left,
				BorderSizePixel = 0,
			}, moduleList)

			-- ON 時に下部に表示される区切り線
			local divider = New("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.new(0, 0, 1, -1),
				BackgroundColor3 = Color3.fromRGB(48, 48, 48),
				BorderSizePixel = 0,
				Visible = false,
			}, row)

			local toggle = {
				Value = toggleConfig.Default or false,
				Callback = toggleConfig.Callback or function() end,
			}

			local function apply(v)
				toggle.Value = v
				TweenService:Create(row, TweenInfoFast, {
					TextColor3 = v and Theme.Accent or Theme.TextDim,
					BackgroundColor3 = v and Theme.PanelHover or Theme.Panel,
				}):Play()
				divider.Visible = v
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

			row.MouseEnter:Connect(function()
				if not toggle.Value then
					TweenService:Create(row, TweenInfoFast, { TextColor3 = Theme.Text }):Play()
					TweenService:Create(row, TweenInfoFast, { BackgroundColor3 = Theme.PanelHover }):Play()
				end
			end)
			row.MouseLeave:Connect(function()
				if not toggle.Value then
					apply(toggle.Value)
				end
			end)
			row.MouseButton1Click:Connect(function()
				toggle:Toggle()
			end)

			apply(toggle.Value)
			return toggle
		end

		-- ============================================================
		-- 名前入力欄追加 (タイトル + 角丸入力ボックス)
		-- ============================================================
		function dropdown:AddNameInput(inputConfig)
			inputConfig = inputConfig or {}

			local row = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 58),
				BackgroundColor3 = Theme.Panel,
				AutoButtonColor = false,
				Text = "",
				BorderSizePixel = 0,
			}, moduleList)

			local label = New("TextLabel", {
				Text = inputConfig.Text or "Name",
				Font = FONT_INPUT,
				TextSize = 12,
				TextColor3 = Theme.Text,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 3),
				Size = UDim2.new(1, -10, 0, 20),
				TextXAlignment = Enum.TextXAlignment.Left,
			}, row)

			local holder = New("Frame", {
				Position = UDim2.fromOffset(10, 23),
				Size = UDim2.new(1, -20, 0, 29),
				BackgroundColor3 = Theme.Input,
				BorderSizePixel = 0,
			}, row)
			New("UICorner", { CornerRadius = UDim.new(0, 4) }, holder)

			local box = New("TextBox", {
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -8, 1, 0),
				BackgroundTransparency = 1,
				ClearTextOnFocus = false,
				PlaceholderText = inputConfig.Placeholder or "Click to set",
				PlaceholderColor3 = Theme.Placeholder,
				Text = inputConfig.Default or "",
				TextColor3 = Theme.TextDim,
				Font = FONT_INPUT,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, holder)

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

			row.MouseButton1Click:Connect(function()
				box:CaptureFocus()
			end)

			box.FocusLost:Connect(function(enterPressed)
				input.Value = box.Text
				if inputConfig.Callback then
					task.spawn(inputConfig.Callback, input.Value, enterPressed)
				end
			end)

			return input
		end

		-- ============================================================
		-- スライダー追加 (細バー + 円形ノブ + 値ラベル)
		-- ============================================================
		function dropdown:AddSlider(sliderConfig)
			sliderConfig = sliderConfig or {}

			local min = sliderConfig.Min or 0
			local max = sliderConfig.Max or 100
			local decimals = sliderConfig.Decimals or 0

			local row = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundColor3 = Theme.Panel,
				AutoButtonColor = false,
				Text = "",
				BorderSizePixel = 0,
			}, moduleList)

			local label = New("TextLabel", {
				Text = sliderConfig.Text or "Slider",
				Font = FONT_TEXT,
				TextSize = 11,
				TextColor3 = Theme.TextDim,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 2),
				Size = UDim2.new(1, -80, 0, 30),
				TextXAlignment = Enum.TextXAlignment.Left,
			}, row)

			local valueLabel = New("TextButton", {
				Text = "",
				Font = FONT_TEXT,
				TextSize = 11,
				TextColor3 = Theme.TextDim,
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -69, 0, 9),
				Size = UDim2.fromOffset(60, 15),
				TextXAlignment = Enum.TextXAlignment.Right,
			}, row)

			local bar = New("Frame", {
				Position = UDim2.fromOffset(10, 37),
				Size = UDim2.new(1, -20, 0, 2),
				BackgroundColor3 = Theme.SliderTrack,
				BorderSizePixel = 0,
			}, row)

			local fill = New("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
			}, bar)

			local knob = New("Frame", {
				Size = UDim2.fromOffset(14, 14),
				Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
			}, fill)
			New("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

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

			row.InputBegan:Connect(function(input)
				if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
					and input.Position.Y - row.AbsolutePosition.Y > 20 then
					dragging = true
					update(min + (max - min) * fractionFromInput(input), true)
				end
			end)
			row.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
					update(min + (max - min) * fractionFromInput(input), true)
				end
			end)

			-- 値ラベルクリックで直接数値入力
			local custombox = New("TextBox", {
				Position = valueLabel.Position,
				Size = valueLabel.Size,
				BackgroundTransparency = 1,
				ClearTextOnFocus = false,
				Font = FONT_TEXT,
				TextSize = 11,
				TextColor3 = Theme.TextDim,
				TextXAlignment = Enum.TextXAlignment.Right,
				Visible = false,
			}, row)
			valueLabel.MouseButton1Click:Connect(function()
				valueLabel.Visible = false
				custombox.Visible = true
				custombox.Text = tostring(slider.Value)
				custombox:CaptureFocus()
			end)
			custombox.FocusLost:Connect(function(enter)
				valueLabel.Visible = true
				custombox.Visible = false
				if enter and tonumber(custombox.Text) then
					update(tonumber(custombox.Text), true)
				end
			end)

			update(sliderConfig.Default or min, false)
			return slider
		end

		-- ============================================================
		-- ボタン追加 (内枠ボタン、ホバーで明るくなる)
		-- ============================================================
		function dropdown:AddButton(buttonConfig)
			buttonConfig = buttonConfig or {}

			local row = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 31),
				BackgroundColor3 = Theme.Panel,
				AutoButtonColor = false,
				Text = "",
				BorderSizePixel = 0,
			}, moduleList)

			local holder = New("Frame", {
				Position = UDim2.fromOffset(10, 2),
				Size = UDim2.new(1, -20, 0, 27),
				BackgroundColor3 = Theme.ButtonHolder,
				BorderSizePixel = 0,
			}, row)
			New("UICorner", { CornerRadius = UDim.new(0, 4) }, holder)

			local label = New("TextLabel", {
				Text = buttonConfig.Text or "Button",
				Font = FONT_TEXT,
				TextSize = 14,
				TextColor3 = Theme.TextDim,
				BackgroundColor3 = Theme.Panel,
				Position = UDim2.fromOffset(2, 2),
				Size = UDim2.new(1, -4, 1, -4),
				TextXAlignment = Enum.TextXAlignment.Center,
			}, holder)
			New("UICorner", { CornerRadius = UDim.new(0, 4) }, label)

			row.MouseEnter:Connect(function()
				TweenService:Create(holder, TweenInfoFast, { BackgroundColor3 = Theme.ButtonHover }):Play()
			end)
			row.MouseLeave:Connect(function()
				TweenService:Create(holder, TweenInfoFast, { BackgroundColor3 = Theme.ButtonHolder }):Play()
			end)
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

		-- 最初のカテゴリー or DefaultOpen なら最初から表示
		task.defer(function()
			if dropdownConfig.DefaultOpen or activeDropdown == nil then
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
