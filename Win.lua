-- Win11UIModule (ModuleScript) – Full Mobile + PC Support
-- Supports: Space, Logs, BoolValue, Slider, TextBox, TextBoxAndButton,
--           Button, ColorUI, ColorPicker, InstancePicker, SaveLoad, Keybind
-- ✦ เพิ่ม: Window slide-up open animation + Tab slide-from-left animation
-- ✦ เพิ่ม: _items registry + GetItem(key) สำหรับ set Value แล้ว UI อัปเดต

local Win11UIModule = {}
Win11UIModule.__index = Win11UIModule

-- ─── Services ────────────────────────────────
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local UIS              = UserInputService
local LogService       = game:GetService("LogService")
local Debris           = game:GetService("Debris")

local neon
if game:GetService("RunService"):IsStudio() then
	neon = require(game.ReplicatedStorage.neon)
else
	neon = loadstring(game:HttpGet("https://raw.githubusercontent.com/benten1100/-/refs/heads/main/neno.lua"))()
end

-- ─── Mobile Detection ────────────────────────
local isMobile = false

-- ─── Global State ────────────────────────────
local globalConnections = {}
local activePickerCloser = nil

local function trackGlobalConnection(conn)
	table.insert(globalConnections, conn)
	return conn
end

local function cleanupGlobalConnections()
	for _, conn in ipairs(globalConnections) do
		if conn then pcall(function() conn:Disconnect() end) end
	end
	globalConnections = {}
	pcall(function()
		local cg = game:GetService("CoreGui")
		local fab = cg:FindFirstChild("BenTen_Mobile") or Players.LocalPlayer.PlayerGui:FindFirstChild("BenTen_Mobile")
		if fab then fab:Destroy() end
	end)
end

-- ─── Helpers ─────────────────────────────────
local function new(class, parent, props)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do obj[k] = v end
	obj.Parent = parent
	return obj
end

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local function tw(obj, tweenInfo, props)
	if typeof(tweenInfo) == "number" then
		local tween = TweenService:Create(
			obj,
			TweenInfo.new(tweenInfo or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			props
		)
		tween:Play()
		return tween
	else
		local tween = TweenService:Create(obj, tweenInfo, props)
		tween:Play()
		return tween
	end
end

local function ripple(btn)
	if not btn or not btn.Parent then return end
	local r = new("Frame", btn, {
		AnchorPoint            = Vector2.new(0.5, 0.5),
		Position               = UDim2.new(0.5, 0, 0.5, 0),
		Size                   = UDim2.fromOffset(0, 0),
		BackgroundColor3       = rgb(255, 255, 255),
		BackgroundTransparency = 0.7,
		BorderSizePixel        = 0,
		ZIndex                 = (btn.ZIndex or 1) + 5,
	})
	new("UICorner", r, { CornerRadius = UDim.new(1, 0) })
	local sz = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 2
	local ti = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(r, ti, { Size = UDim2.fromOffset(sz, sz), BackgroundTransparency = 1 }):Play()
	Debris:AddItem(r, 0.45)
end

local function colorToHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function hexToColor3(hex)
	hex = hex:gsub("#", "")
	if #hex == 6 then
		local r = tonumber(hex:sub(1, 2), 16)
		local g = tonumber(hex:sub(3, 4), 16)
		local b = tonumber(hex:sub(5, 6), 16)
		if r and g and b then return Color3.fromRGB(r, g, b) end
	end
	return nil
end

local function getContrastColor(c)
	local brightness = (c.R * 0.299) + (c.G * 0.587) + (c.B * 0.114)
	return brightness > 0.5 and rgb(0, 0, 0) or rgb(255, 255, 255)
end

-- ─── Touch/Mouse unified input ───────────────
local function isTouchOrMouse(inp)
	return inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch
end

local function isMove(inp)
	return inp.UserInputType == Enum.UserInputType.MouseMovement
		or inp.UserInputType == Enum.UserInputType.Touch
end

-- ─── Color Palette ────────────────────────────
local C = {
	BASE      = rgb(18, 18, 20),
	SURFACE   = rgb(24, 24, 27),
	SURFACE2  = rgb(30, 30, 34),
	SIDEBAR   = rgb(14, 14, 16),
	BORDER    = rgb(35, 35, 42),
	BORDER2   = rgb(44, 44, 52),
	ACCENT    = rgb(30, 30, 30),
	TEXT      = rgb(200, 200, 208),
	TEXT2     = rgb(255, 255, 255),
	ICON      = rgb(255, 255, 255),
	HOVER     = rgb(255, 255, 255),
	SEL_BAR   = rgb(130, 130, 148),
	DIVIDER   = rgb(30, 30, 30),
	CLOSEHOV  = rgb(58, 58, 58),
	MINHOV    = rgb(32, 32, 38),
}

-- ─── Item Design Tokens ──────────────────────
local D = {
	pillBg      = rgb(20, 20, 24),
	pillBorder  = rgb(36, 36, 44),
	pillText    = rgb(190, 190, 200),
	pillMuted   = rgb(75, 75, 88),
	accent      = rgb(130, 130, 148),
	accentDim   = rgb(32, 32, 40),
	sliderFill  = rgb(120, 120, 140),
	sliderTrack = rgb(30, 30, 36),
	knob        = rgb(160, 160, 172),
	rad         = UDim.new(0.05, 0),
	radRound    = UDim.new(1, 0),
	fontMain    = isMobile and 15 or 14,
	fontSub     = isMobile and 12 or 16,
	fontValue   = isMobile and 15 or 14,
	fontSmall   = isMobile and 13 or 12,
	fontIcon    = isMobile and 20 or 18,
	inputW      = isMobile and 150 or 140,
	keybindW    = isMobile and 70 or 60,
	sliderW     = isMobile and 160 or 200,
	btnW        = 90,
	toggleW     = isMobile and 50 or 45,
	pillH       = isMobile and 38 or 32,
	marginR     = 20,
	iconSize    = isMobile and 32 or 28,
	iconPad     = 8,
}

-- ══════════════════════════════════════════════
-- Notify
-- ══════════════════════════════════════════════
function Win11UIModule.Notify(options)
	local type     = options.type     or "info"
	local title    = options.title    or "แจ้งเตือน"
	local message  = options.message  or ""
	local duration = options.duration or 3

	local colors = {
		success = Color3.fromRGB(74, 222, 128),
		error   = Color3.fromRGB(248, 113, 113),
		info    = Color3.fromRGB(96, 165, 250),
		warn    = Color3.fromRGB(251, 191, 36),
	}
	local accent = colors[type] or colors.info

	local gui = Instance.new("ScreenGui")
	gui.Name = "Win11Notify_" .. tostring(tick())
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 68)
	frame.Position = UDim2.new(1, 10, 1, -90)
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 38)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 35, 1, 0)
	bar.Position = UDim2.new(0, 0, 0, 0)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = frame

	local UIGradient = Instance.new("UIGradient")
	UIGradient.Parent = bar
	UIGradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.0829, 0),
		NumberSequenceKeypoint.new(0.0894, 1),
		NumberSequenceKeypoint.new(1, 1)
	}
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 10)
	barCorner.Parent = bar

	local progress = Instance.new("Frame")
	progress.Size = UDim2.new(1, -3, 0, 2)
	progress.Position = UDim2.new(1, 0, 1, -2)
	progress.AnchorPoint = Vector2.new(1, 1)
	progress.BackgroundColor3 = accent
	progress.BorderSizePixel = 0
	progress.Parent = frame

	local UIGradient2 = Instance.new("UIGradient")
	UIGradient2.Parent = progress
	UIGradient2.Rotation = 180
	UIGradient2.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.722, 0),
		NumberSequenceKeypoint.new(1, 1)
	}
	local progCorner = Instance.new("UICorner")
	progCorner.CornerRadius = UDim.new(0, 6)
	progCorner.Parent = progress

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -50, 0, 20)
	titleLabel.Position = UDim2.new(0, 16, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local msgLabel = Instance.new("TextLabel")
	msgLabel.Size = UDim2.new(1, -20, 0, 28)
	msgLabel.Position = UDim2.new(0, 16, 0, 30)
	msgLabel.BackgroundTransparency = 1
	msgLabel.Text = message
	msgLabel.TextColor3 = Color3.fromRGB(160, 160, 185)
	msgLabel.Font = Enum.Font.Gotham
	msgLabel.TextSize = 12
	msgLabel.TextXAlignment = Enum.TextXAlignment.Left
	msgLabel.TextWrapped = true
	msgLabel.Parent = frame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -30, 0, 8)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = ">"
	closeBtn.TextColor3 = Color3.fromRGB(120, 120, 140)
	closeBtn.Font = Enum.Font.Gotham
	closeBtn.TextSize = 12
	closeBtn.Parent = frame

	local function slideIn()
		frame:TweenPosition(UDim2.new(1, -10, 1, -90), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.35, true)
	end
	local function slideOut()
		frame:TweenPosition(UDim2.new(1, 300, 1, -90), Enum.EasingDirection.In, Enum.EasingStyle.Quart, 0.3, true, function() gui:Destroy() end)
	end
	local function startProgress()
		local tween = game:GetService("TweenService"):Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })
		tween:Play()
	end

	closeBtn.MouseButton1Click:Connect(slideOut)
	slideIn()
	startProgress()
	task.delay(duration, slideOut)
end

-- ══════════════════════════════════════════════
-- Key System
-- ══════════════════════════════════════════════
function Win11UIModule.Key(config)
	local player    = Players.LocalPlayer
	local playerGui = game:GetService("CoreGui") or player:WaitForChild("PlayerGui")
	local camera    = workspace.CurrentCamera

	local BASE_W = isMobile and 540 or 1280
	local BASE_H = isMobile and 960 or 720
	local vp0 = camera.ViewportSize
	local WIN_W = config.width  or (isMobile and math.floor(vp0.X * 0.95) or 420)
	local WIN_H = config.height or (isMobile and math.floor(vp0.Y * 0.45) or 320)
	local WIN   = { dx = 0, dy = 0, w = WIN_W, h = WIN_H }

	local sg = new("ScreenGui", playerGui, {
		Name           = "BenTen__" .. tostring(math.random(1e6)),
		ResetOnSpawn   = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder   = 100,
		IgnoreGuiInset = true,
	})
	local uiScale = new("UIScale", sg, {})

	local window = new("Frame", sg, {
		AnchorPoint      = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.BASE,
		BorderSizePixel  = 0,
		ClipsDescendants = false,
	})
	new("UICorner", window, { CornerRadius = UDim.new(0, 12) })
	new("UIStroke", window, { Color = C.BORDER, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })

	local function applyWin()
		window.Position = UDim2.new(0.5, WIN.dx, 0.5, WIN.dy)
		window.Size     = UDim2.fromOffset(WIN.w, WIN.h)
	end
	applyWin()

	local function updateScale()
		local vp = camera.ViewportSize
		if isMobile then
			uiScale.Scale = 1
			WIN.w  = math.floor(vp.X * 0.95)
			WIN.h  = math.floor(vp.Y * 0.45)
			WIN.dx = 0
			WIN.dy = 0
			applyWin()
		else
			uiScale.Scale = math.min(vp.X / BASE_W, vp.Y / BASE_H)
		end
	end
	updateScale()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	local function getRefSize()
		local vp = camera.ViewportSize
		local sc = uiScale.Scale
		return vp.X / sc, vp.Y / sc
	end

	local function getOffScreenBottom()
		local _, rh = getRefSize()
		return math.floor(rh / 2 + WIN.h / 2 + 50)
	end

	local TITLE_H = isMobile and 38 or 32
	local titleBar = new("Frame", window, {
		Size             = UDim2.new(1, 0, 0, TITLE_H),
		BackgroundColor3 = rgb(28, 28, 28),
		BorderSizePixel  = 0,
		ZIndex           = 10,
	})
	new("Frame", titleBar, { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = C.BORDER, BorderSizePixel = 0 })
	new("UICorner", titleBar, { CornerRadius = UDim.new(0, 12) })
	new("TextLabel", titleBar, {
		Size = UDim2.new(0, 200, 1, 0), Position = UDim2.fromOffset(30, 0),
		BackgroundTransparency = 1, Text = config.title or "Key System",
		TextColor3 = C.TEXT2, Font = Enum.Font.GothamBold,
		TextSize = isMobile and 13 or 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11,
	})

	local ctrlW = isMobile and 36 or 46
	local closeBtn = new("TextButton", titleBar, {
		Size = UDim2.fromOffset(ctrlW, TITLE_H), Position = UDim2.new(1, -ctrlW, 0, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0, Text = "X",
		TextColor3 = C.TEXT2, Font = Enum.Font.Gotham,
		TextSize = isMobile and 13 or 12, AutoButtonColor = false, ZIndex = 11,
	})
	new("UICorner", closeBtn, { CornerRadius = UDim.new(0, 12) })
	closeBtn.MouseEnter:Connect(function() closeBtn.BackgroundColor3 = C.CLOSEHOV; tw(closeBtn, 0.1, { BackgroundTransparency = 0 }) end)
	closeBtn.MouseLeave:Connect(function() tw(closeBtn, 0.1, { BackgroundTransparency = 1 }) end)
	closeBtn.MouseButton1Click:Connect(function()
		local targetY = getOffScreenBottom()
		TweenService:Create(window, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, WIN.dx, 0.5, targetY) }):Play()
		task.delay(0.32, function() cleanupGlobalConnections(); sg:Destroy() end)
	end)

	local body = new("Frame", window, {
		Size = UDim2.new(1, 0, 1, -TITLE_H), Position = UDim2.fromOffset(0, TITLE_H),
		BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false,
	})

	new("TextLabel", body, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.15, 0), Size = UDim2.fromOffset(50, 50), BackgroundTransparency = 1, Text = "🔑", TextSize = isMobile and 32 or 28, ZIndex = 5 })
	new("TextLabel", body, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.32, 0), Size = UDim2.new(0.85, 0, 0, 22), BackgroundTransparency = 1, Text = config.lockTitle or "กรุณาใส่ Key เพื่อใช้งาน", TextColor3 = C.TEXT, Font = Enum.Font.GothamBold, TextSize = isMobile and 15 or 14, ZIndex = 5 })

	local INPUT_W = isMobile and 260 or 300
	local INPUT_H = isMobile and 42 or 38
	local inputFrame = new("Frame", body, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.52, 0),
		Size = UDim2.fromOffset(INPUT_W, INPUT_H), BackgroundColor3 = rgb(30, 30, 36),
		BorderSizePixel = 0, ZIndex = 5, Name = "InputFrame",
	})
	new("UICorner", inputFrame, { CornerRadius = UDim.new(0, 8) })
	local inputStroke = new("UIStroke", inputFrame, { Color = D.pillBorder, Thickness = 1 })

	local keyInput = new("TextBox", inputFrame, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0.9, 0, 0.7, 0), BackgroundTransparency = 1,
		Font = Enum.Font.Code, Text = "", PlaceholderText = "ใส่ Key ที่นี่...",
		PlaceholderColor3 = Color3.new(0.647059, 0.647059, 0.647059),
		TextColor3 = Color3.new(1, 1, 1), TextSize = isMobile and 15 or 14,
		ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6,
	})
	keyInput.Focused:Connect(function() tw(inputStroke, 0.15, { Color = rgb(1, 1, 1) }) end)
	keyInput.FocusLost:Connect(function() tw(inputStroke, 0.15, { Color = D.pillBorder }) end)

	local errorLabel = new("TextLabel", body, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.64, 0),
		Size = UDim2.new(0.85, 0, 0, 18), BackgroundTransparency = 1, Text = "",
		TextColor3 = rgb(255, 80, 80), Font = Enum.Font.Gotham,
		TextSize = isMobile and 12 or 11, TextTransparency = 1, ZIndex = 5,
	})

	local function showError(msg)
		errorLabel.Text = msg
		tw(errorLabel, 0.15, { TextTransparency = 0 })
		tw(inputStroke, 0.15, { Color = rgb(200, 50, 50) })
		task.delay(2.5, function()
			if errorLabel and errorLabel.Parent then tw(errorLabel, 0.3, { TextTransparency = 1 }) end
			if inputStroke and inputStroke.Parent then tw(inputStroke, 0.3, { Color = D.pillBorder }) end
		end)
	end

	local BTN_H   = isMobile and 38 or 34
	local BTN_GAP = isMobile and 10 or 12
	local COPY_W  = isMobile and 130 or 140
	local OK_W    = isMobile and 130 or 140
	local totalW  = COPY_W + BTN_GAP + OK_W
	local startX  = -totalW / 2

	local copyBtnFrame = new("Frame", body, {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, startX, 0.78, 0),
		Size = UDim2.fromOffset(COPY_W, BTN_H), BackgroundColor3 = rgb(45, 50, 70), BorderSizePixel = 0, ZIndex = 5,
	})
	new("UICorner", copyBtnFrame, { CornerRadius = UDim.new(0, 8) })
	new("UIStroke", copyBtnFrame, { Color = rgb(65, 70, 95), Thickness = 1 })
	new("TextLabel", copyBtnFrame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.45, 0, 0.5, 0), Size = UDim2.new(0.7, 0, 0.65, 0), BackgroundTransparency = 1, Text = "📋 CopyKey", TextColor3 = rgb(180, 185, 210), Font = Enum.Font.GothamMedium, TextSize = isMobile and 13 or 12, ZIndex = 6 })
	new("TextLabel", copyBtnFrame, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.95, 0, 0.5, 0), Size = UDim2.new(0.2, 0, 0.5, 0), BackgroundTransparency = 1, Text = "∨", TextColor3 = D.pillMuted, TextSize = isMobile and 12 or 10, ZIndex = 6 })

	local okBtnFrame = new("Frame", body, {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, startX + COPY_W + BTN_GAP, 0.78, 0),
		Size = UDim2.fromOffset(OK_W, BTN_H), BackgroundColor3 = rgb(50, 75, 55), BorderSizePixel = 0, ZIndex = 5,
	})
	new("UICorner", okBtnFrame, { CornerRadius = UDim.new(0, 8) })
	new("UIStroke", okBtnFrame, { Color = rgb(60, 100, 65), Thickness = 1 })
	new("TextLabel", okBtnFrame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.8, 0, 0.65, 0), BackgroundTransparency = 1, Text = "✓ ตกลง", TextColor3 = rgb(180, 220, 185), Font = Enum.Font.GothamBold, TextSize = isMobile and 13 or 12, ZIndex = 6 })

	local copyBtn = new("TextButton", copyBtnFrame, { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 7 })
	local okBtn   = new("TextButton", okBtnFrame,   { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 7 })

	copyBtn.MouseEnter:Connect(function() tw(copyBtnFrame, 0.12, { BackgroundColor3 = rgb(55, 60, 85) }) end)
	copyBtn.MouseLeave:Connect(function() tw(copyBtnFrame, 0.12, { BackgroundColor3 = rgb(45, 50, 70) }) end)
	okBtn.MouseEnter:Connect(function() tw(okBtnFrame, 0.12, { BackgroundColor3 = rgb(55, 90, 65) }) end)
	okBtn.MouseLeave:Connect(function() tw(okBtnFrame, 0.12, { BackgroundColor3 = rgb(50, 75, 55) }) end)

	local dropdownOpen = false
	local dropdown = nil
	local dropdownConn = nil
	local currentDropdownH = 100

	local copyCategories = config.copyLinks or {}
	local linkMap = config.linkMap or {}
	local ITEM_H = isMobile and 38 or 34
	local POP_WIDTH = isMobile and (WIN_W - 40) or 250

	local function closeDropdown(instant)
		dropdownOpen = false
		if dropdownConn then dropdownConn:Disconnect(); dropdownConn = nil end
		if not dropdown then return end
		if instant then
			if dropdown.Parent then dropdown:Destroy() end
			dropdown = nil
		else
			local curW = dropdown.Size.X.Offset
			dropdown.ClipsDescendants = true
			TweenService:Create(dropdown, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Size = UDim2.fromOffset(curW, 0) }):Play()
			task.delay(0.22, function() if dropdown and dropdown.Parent then dropdown:Destroy(); dropdown = nil end end)
		end
	end

	local function buildDropdown()
		if dropdown then dropdown:Destroy() end
		dropdown = new("Frame", window, { BackgroundColor3 = rgb(22, 22, 26), BorderSizePixel = 0, ClipsDescendants = true, Visible = false, ZIndex = 50 })
		new("UICorner", dropdown, { CornerRadius = UDim.new(0, 8) })
		new("UIStroke", dropdown, { Color = rgb(55, 55, 65), Thickness = 1 })
		local listFrame = new("ScrollingFrame", dropdown, { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = isMobile and 3 or 4, ScrollBarImageColor3 = rgb(60, 60, 70) })
		new("UIListLayout", listFrame, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
		new("UIPadding", listFrame, { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
		local order = 0
		local calcH = 12
		for _, cat in ipairs(copyCategories) do
			order = order + 1; calcH = calcH + 26
			local headerFrame = new("Frame", listFrame, { BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 26) })
			new("TextLabel", headerFrame, { AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.new(0, 4, 1, 0), Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.GothamBold, Text = cat.name, TextColor3 = rgb(255, 255, 255), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left })
			for _, itemName in ipairs(cat.items or {}) do
				order = order + 1; calcH = calcH + ITEM_H + 2
				local itemFrame = new("Frame", listFrame, { BackgroundColor3 = rgb(30, 30, 38), BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.new(1, 0, 0, ITEM_H) })
				new("UICorner", itemFrame, { CornerRadius = UDim.new(0, 6) })
				local iconText = "🔗"
				if itemName:find("Discord") then iconText = "💬" elseif itemName:find("YouTube") then iconText = "▶️" elseif itemName:find("Facebook") then iconText = "📘" elseif itemName:find("Website") then iconText = "🌐" end
				new("TextLabel", itemFrame, { AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(0.08, 0, 1, 0), Text = iconText, TextSize = isMobile and 14 or 12 })
				new("TextLabel", itemFrame, { AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0, 32, 0.5, 0), Size = UDim2.new(1, -45, 0, ITEM_H - 4), Font = Enum.Font.Gotham, Text = itemName, TextColor3 = rgb(180, 180, 195), TextSize = isMobile and 13 or 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
				new("TextLabel", itemFrame, { AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.15, 0, 0.5, 0), Text = "↗", TextColor3 = D.pillMuted, TextSize = isMobile and 14 or 12 })
				local itemBtn = new("TextButton", itemFrame, { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", ZIndex = 2 })
				itemBtn.MouseEnter:Connect(function() tw(itemFrame, 0.1, { BackgroundColor3 = rgb(40, 40, 50) }) end)
				itemBtn.MouseLeave:Connect(function() tw(itemFrame, 0.1, { BackgroundColor3 = rgb(30, 30, 38) }) end)
				itemBtn.MouseButton1Click:Connect(function()
					local link = linkMap[itemName] or itemName
					if setclipboard then pcall(function() setclipboard(link) end) end
					if config.onCopy then config.onCopy(itemName, link) end
					closeDropdown(); ripple(itemBtn)
				end)
			end
		end
		currentDropdownH = math.clamp(calcH, 50, 300)
		dropdown.Size = UDim2.fromOffset(POP_WIDTH, currentDropdownH)
	end

	local function calcDropdownPos()
		local sc = uiScale.Scale
		local winAbs = window.AbsolutePosition
		local btnAbs = copyBtnFrame.AbsolutePosition
		local btnSz  = copyBtnFrame.AbsoluteSize
		local relX = btnAbs.X - winAbs.X
		local relY = btnAbs.Y + btnSz.Y - winAbs.Y
		local x = relX / sc - 58
		local y = relY / sc + 10
		if x + POP_WIDTH > WIN.w - 10 then x = WIN.w - POP_WIDTH - 10 end
		local _, rh = getRefSize()
		if y + currentDropdownH > rh - 10 then
			local relBtnTop = btnAbs.Y - winAbs.Y
			y = relBtnTop / sc - currentDropdownH - 4
		end
		return x, y
	end

	local function openDropdown()
		if dropdownOpen then closeDropdown(); return end
		buildDropdown()
		local x, y = calcDropdownPos()
		dropdown.Position = UDim2.fromOffset(x, y)
		dropdown.Size = UDim2.fromOffset(POP_WIDTH, 0)
		dropdown.ClipsDescendants = true
		dropdown.Visible = true
		dropdownOpen = true
		TweenService:Create(dropdown, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(POP_WIDTH, currentDropdownH) }):Play()
		dropdownConn = UIS.InputBegan:Connect(function(inp)
			if not dropdownOpen or not dropdown or not dropdown.Parent then return end
			if not isTouchOrMouse(inp) then return end
			local pos = inp.Position
			local bPos = copyBtnFrame.AbsolutePosition; local bSz = copyBtnFrame.AbsoluteSize
			if pos.X >= bPos.X and pos.X <= bPos.X + bSz.X and pos.Y >= bPos.Y and pos.Y <= bPos.Y + bSz.Y then return end
			local dPos = dropdown.AbsolutePosition; local dSz = dropdown.AbsoluteSize
			if pos.X >= dPos.X and pos.X <= dPos.X + dSz.X and pos.Y >= dPos.Y and pos.Y <= dPos.Y + dSz.Y then return end
			closeDropdown()
		end)
	end

	copyBtn.MouseButton1Click:Connect(function() if dropdownOpen then closeDropdown() else openDropdown() end; ripple(copyBtn) end)

	local function trySubmit()
		local inputKey = keyInput.Text
		if inputKey == "" then showError("⚠️ กรุณาใส่ Key"); return end
		local isValid = false
		if config.validateKey then isValid = config.validateKey(inputKey)
		elseif config.correctKey then isValid = (inputKey == config.correctKey) end
		if isValid then
			if config.onSuccess then config.onSuccess(inputKey) end
			local targetY = getOffScreenBottom()
			tw(window, 0.25, { BackgroundTransparency = 1 })
			TweenService:Create(window, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, WIN.dx, 0.5, targetY) }):Play()
			task.delay(0.35, function() if config.onComplete then config.onComplete(inputKey) else sg:Destroy() end end)
		else
			showError("❌ Key ผิด!")
			if config.onFail then config.onFail(inputKey) end
			local origX = inputFrame.Position.X.Offset
			task.spawn(function()
				for i = 1, 6 do
					local shakeX = (i % 2 == 0) and 6 or -6
					tw(inputFrame, 0.04, { Position = UDim2.new(0.5, origX + shakeX, 0.52, 0) })
					task.wait(0.01)
				end
				tw(inputFrame, 0.1, { Position = UDim2.new(0.5, origX, 0.52, 0) })
			end)
		end
	end

	okBtn.MouseButton1Click:Connect(function() trySubmit(); ripple(okBtn) end)
	keyInput.FocusLost:Connect(function(enter) if enter then trySubmit() end end)

	local offScreenBottom = getOffScreenBottom()
	window.BackgroundTransparency = 1
	window.Position = UDim2.new(0.5, WIN.dx, 0.5, offScreenBottom)
	neon:BindFrame(window, { Transparency = 0.8, BrickColor = BrickColor.new("Institutional white") })
	tw(window, 0.25, { BackgroundTransparency = .15 })
	TweenService:Create(window, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, WIN.dx, 0.5, WIN.dy) }):Play()
	task.delay(0.5, function() if keyInput and keyInput.Parent then keyInput:CaptureFocus() end end)
	sg.AncestryChanged:Connect(function() if not sg.Parent then pcall(function() neon:UnbindFrame(window) end) end end)
	return sg
end

-- ══════════════════════════════════════════════
-- Main UI
-- ══════════════════════════════════════════════
function Win11UIModule.new(config)
	config = config or {}
	local self = setmetatable({}, Win11UIModule)

	local player    = Players.LocalPlayer
	local playerGui = game:GetService("CoreGui") or player:WaitForChild("PlayerGui")
	local camera    = workspace.CurrentCamera

	local BASE_W = isMobile and 540 or 1280
	local BASE_H = isMobile and 960 or 720
	local vp0  = camera.ViewportSize
	local WIN_W = config.width  or (isMobile and math.floor(vp0.X * 0.95) or 960)
	local WIN_H = config.height or (isMobile and math.floor(vp0.Y * 0.88) or 580)
	local WIN   = { dx = 0, dy = 0, w = WIN_W, h = WIN_H }
	local MIN_W  = config.minW or (isMobile and 280 or 500)
	local MIN_H  = config.minH or (isMobile and 300 or 340)
	local isMax, savedWin = false, {}

	local sidebarOpen = true
	local SW_OPEN  = isMobile and 150 or 185
	local SW_CLOSE = 0

	local sg = new("ScreenGui", playerGui, {
		Name           = "Win11UI_" .. tostring(math.random(1e6)),
		ResetOnSpawn   = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder   = 10,
		IgnoreGuiInset = true,
	})
	self.Gui = sg
	local uiScale = new("UIScale", sg, {})

	local window = new("Frame", sg, {
		AnchorPoint      = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.BASE,
		BorderSizePixel  = 0,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	})
	neon:BindFrame(window, { Transparency = 0.89, BrickColor = BrickColor.new("Institutional white") })
	
	new("UICorner", window, { CornerRadius = UDim.new(0, 10) })
	new("UIStroke", window, { Color = C.BORDER, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })

	local function applyWin()
		window.Position = UDim2.new(0.5, WIN.dx, 0.5, WIN.dy)
		window.Size     = UDim2.fromOffset(WIN.w, WIN.h)
	end
	applyWin()

	local function updateScale()
		local vp = camera.ViewportSize
		if isMobile then
			uiScale.Scale = 1
			WIN.w  = math.floor(vp.X * 0.95)
			WIN.h  = math.floor(vp.Y * 0.88)
			WIN.dx = 0; WIN.dy = 0
			applyWin()
		else
			uiScale.Scale = math.min(vp.X / BASE_W, vp.Y / BASE_H)
		end
	end
	updateScale()
	local scaleCon = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	-- ── Connection + Items tracker ───────────────────
	local _connections = {}
	local _items = {}  -- ← registry สำหรับ GetItem()

	local function trackConnection(conn)
		_connections[#_connections + 1] = conn
		return conn
	end

	local function toRef(position)
		local sc = uiScale.Scale
		return Vector2.new(position.X / sc, position.Y / sc)
	end

	local cornerResizing = false

	do
		local ImageLabel = new("ImageLabel", window, {
			AnchorPoint       = Vector2.new(.5, .5),
			Position          = UDim2.new(.96, 0, .95, 0),
			BackgroundTransparency = 1,
			ImageTransparency = .3,
			Size              = UDim2.fromOffset(150, 150),
			Image             = "rbxassetid://99168852788153",
			ImageColor3       = rgb(200, 200, 210),
			ScaleType         = Enum.ScaleType.Fit,
			ZIndex            = 21,
			Rotation          = 180,
		})
		local hb = new("TextButton", ImageLabel, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(.3, 0, .3, 0), BackgroundTransparency = 1,
			BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 22,
		})
		local startMouse, snapWin = nil, nil
		hb.InputBegan:Connect(function(inp)
			if not isTouchOrMouse(inp) then return end
			cornerResizing = true
			startMouse = toRef(inp.Position)
			snapWin    = { dx = WIN.dx, dy = WIN.dy, w = WIN.w, h = WIN.h }
			tw(ImageLabel, 0.2, { ImageColor3 = rgb(255, 255, 255) })
		end)
		hb.InputEnded:Connect(function(inp)
			if not isTouchOrMouse(inp) then return end
			cornerResizing = false
			tw(ImageLabel, 0.2, { ImageColor3 = rgb(200, 200, 210), ImageTransparency = 0 })
		end)
		hb.MouseEnter:Connect(function() tw(ImageLabel, 0.15, { ImageColor3 = rgb(230, 230, 235), ImageTransparency = .3 }) end)
		hb.MouseLeave:Connect(function() if not cornerResizing then tw(ImageLabel, 0.15, { ImageColor3 = rgb(200, 200, 210) }) end end)
		trackConnection(UIS.InputChanged:Connect(function(inp)
			if not cornerResizing then return end
			if not isMove(inp) then return end
			local m  = toRef(inp.Position)
			local dx = m.X - startMouse.X
			local dy = m.Y - startMouse.Y
			local nw = math.max(MIN_W, snapWin.w + dx)
			local nh = math.max(MIN_H, snapWin.h + dy)
			WIN.dx = snapWin.dx + (nw - snapWin.w) / 2
			WIN.dy = snapWin.dy + (nh - snapWin.h) / 2
			WIN.w  = nw; WIN.h = nh
			applyWin()
		end))
		trackConnection(UIS.InputEnded:Connect(function(inp)
			if isTouchOrMouse(inp) then
				cornerResizing = false
				tw(ImageLabel, 0.2, { ImageColor3 = rgb(200, 200, 210) })
			end
		end))
	end

	local function getRefSize()
		local vp = camera.ViewportSize
		local sc = uiScale.Scale
		return vp.X / sc, vp.Y / sc
	end
	local function winTopLeft()
		local rw, rh = getRefSize()
		return rw / 2 + WIN.dx - WIN.w / 2, rh / 2 + WIN.dy - WIN.h / 2
	end
	local function getOffScreenY()
		local _, rh = getRefSize()
		return math.floor(rh / 2 + WIN.h / 2 + 100)
	end

	-- ── Title Bar ────────────────────────────
	local TITLE_H = isMobile and 40 or 32
	local titleBar = new("Frame", window, {
		Size = UDim2.new(1, 0, 0, TITLE_H), BackgroundColor3 = rgb(28, 28, 28), BorderSizePixel = 0, ZIndex = 10,
	})
	new("Frame", titleBar, { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = C.BORDER, BorderSizePixel = 0 })
	new("UICorner", titleBar, { CornerRadius = UDim.new(0, 10) })
	local hamburgerBtn
	if isMobile then
		hamburgerBtn = new("TextButton", titleBar, {
			Size = UDim2.fromOffset(TITLE_H, TITLE_H), Position = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0, Text = "☰",
			TextColor3 = C.TEXT2, Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = false, ZIndex = 12,
		})
	end

	local appIconX = isMobile and TITLE_H or 84
	
	new("TextLabel", titleBar, {
		Size = UDim2.new(0, 180, 1, 0), Position = UDim2.fromOffset(appIconX - 65, 0),
		BackgroundTransparency = 1, Text = config.title or "AppDemo",
		TextColor3 = C.TEXT2, Font = Enum.Font.Gotham,
		TextSize = isMobile and 14 or 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11,
	})

	local ctrlW = isMobile and 36 or 46
	local ctrlDefs = {
		{ t = "-", xOff = -(ctrlW * 3), hov = C.CLOSEHOV, act = "min"   },
		{ t = "⬚", xOff = -(ctrlW * 2), hov = C.CLOSEHOV, act = "max"   },
		{ t = "X", xOff = -ctrlW,       hov = C.CLOSEHOV, act = "close", isClose = true },
	}
	for _, d in ipairs(ctrlDefs) do
		local btn = new("TextButton", titleBar, {
			Size = UDim2.fromOffset(ctrlW, TITLE_H), Position = UDim2.new(1, d.xOff, 0, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0, Text = d.t,
			TextColor3 = C.TEXT2, Font = Enum.Font.Gotham,
			TextSize = isMobile and 13 or 12, AutoButtonColor = false, ZIndex = 11,
		})
		if d.isClose then new("UICorner", btn, { CornerRadius = UDim.new(0, 10) }) end
		btn.MouseEnter:Connect(function() btn.BackgroundColor3 = d.hov; tw(btn, 0.1, { BackgroundTransparency = 0 }); tw(btn, 0.1, { TextColor3 = rgb(255, 255, 255) }) end)
		btn.MouseLeave:Connect(function() tw(btn, 0.1, { BackgroundTransparency = 1 }); if d.isClose then tw(btn, 0.1, { TextColor3 = C.TEXT2 }) end end)
		btn.MouseButton1Click:Connect(function()
			if d.act == "close" then
				TweenService:Create(window, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, WIN.dx, 0.5, getOffScreenY()) }):Play()
				task.delay(0.32, function() cleanupGlobalConnections(); sg:Destroy() end)
			elseif d.act == "min" then
				TweenService:Create(window, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, WIN.dx, 0.5, getOffScreenY()) }):Play()
				task.delay(0.32, function() window.Visible = false end)
			elseif d.act == "max" then
				if not isMax then
					savedWin = { dx = WIN.dx, dy = WIN.dy, w = WIN.w, h = WIN.h }
					local rw, rh = getRefSize()
					WIN.dx, WIN.dy, WIN.w, WIN.h = 0, 0, rw, rh
					isMax = true
				else
					WIN.dx, WIN.dy, WIN.w, WIN.h = savedWin.dx, savedWin.dy, savedWin.w, savedWin.h
					isMax = false
				end
				tw(window, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, WIN.dx, 0.5, WIN.dy), Size = UDim2.fromOffset(WIN.w, WIN.h) })
			end
		end)
	end

	-- ── Body ─────────────────────────────────
	local body = new("Frame", window, {
		Size = UDim2.new(1, 0, 1, -TITLE_H), Position = UDim2.fromOffset(0, TITLE_H),
		BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
	})

	-- ── Sidebar ──────────────────────────────
	local sidebar = new("Frame", body, {
		Size = UDim2.new(0, SW_OPEN, 1, 0), BackgroundColor3 = C.SIDEBAR, BorderSizePixel = 0,
		ZIndex = isMobile and 20 or 1,
		BackgroundTransparency = 1,
	})
	
	if isMobile and hamburgerBtn then
		local function toggleSidebar()
			sidebarOpen = not sidebarOpen
			tw(sidebar, 0.22, { Size = UDim2.new(0, sidebarOpen and SW_OPEN or SW_CLOSE, 1, 0) })
		end
		hamburgerBtn.MouseButton1Click:Connect(toggleSidebar)
		trackGlobalConnection(UIS.InputBegan:Connect(function(inp)
			if inp.UserInputType ~= Enum.UserInputType.Touch then return end
			if not sidebarOpen then return end
			local pos = inp.Position
			local sbPos = sidebar.AbsolutePosition; local sbSize = sidebar.AbsoluteSize
			if pos.X < sbPos.X or pos.X > sbPos.X + sbSize.X or pos.Y < sbPos.Y or pos.Y > sbPos.Y + sbSize.Y then
				local hbPos = hamburgerBtn.AbsolutePosition; local hbSize = hamburgerBtn.AbsoluteSize
				if pos.X >= hbPos.X and pos.X <= hbPos.X + hbSize.X and pos.Y >= hbPos.Y and pos.Y <= hbPos.Y + hbSize.Y then return end
				sidebarOpen = false
				tw(sidebar, 0.22, { Size = UDim2.new(0, SW_CLOSE, 1, 0) })
			end
		end))
	end

	local tabBarFrame = new("Frame", sidebar, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0 })
	new("UIListLayout", tabBarFrame, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
	new("UIPadding", tabBarFrame, { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })

	local navScroll = new("ScrollingFrame", sidebar, {
		Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = isMobile and 2 or 3, ScrollBarImageColor3 = C.BORDER2,
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingEnabled = true, ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	local navList = new("Frame", navScroll, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0 })
	new("UIListLayout", navList, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
	new("UIPadding", navList, { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })

	-- ── Content area ─────────────────────────
	local function makeContentFrame(parent, visible)
		local f = new("ScrollingFrame", parent, {
			Size = UDim2.new(1, -SW_OPEN, 1, 0), Position = UDim2.fromOffset(SW_OPEN, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = isMobile and 3 or 4, ScrollBarImageColor3 = C.BORDER2,
			CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingEnabled = true, ScrollingDirection = Enum.ScrollingDirection.Y, Visible = visible,
		})
		new("UIPadding", f, { PaddingTop = UDim.new(0, isMobile and 14 or 28), PaddingLeft = UDim.new(0, isMobile and 10 or 32), PaddingRight = UDim.new(0, isMobile and 8 or 24), PaddingBottom = UDim.new(0, isMobile and 16 or 32) })
		new("UIListLayout", f, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, isMobile and 8 or 10) })
		return f
	end

	local content = makeContentFrame(body, true)
	local pageTitle = new("TextLabel", content, {
		LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1,
		Text = config.pageTitle or "", TextColor3 = C.TEXT, Font = Enum.Font.GothamBold,
		TextSize = isMobile and 18 or 22, TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- ── Tab system ───────────────────────────
	local pages        = {}
	local tabBtns      = {}
	local pageSlots    = {}
	local activeTab    = nil
	local navCount     = 0
	local contentOrder = 2
	local defaultPage  = content

	local function updateLayout()
		local currentSW = sidebar.Size.X.Offset
		content.Position = UDim2.fromOffset(currentSW, 0)
		content.Size     = UDim2.new(1, -currentSW, 1, 0)
		for _, page in pairs(pages) do
			page.Position = UDim2.fromOffset(currentSW, 0)
			page.Size     = UDim2.new(1, -currentSW, 1, 0)
		end
	end
	trackConnection(window:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout))

	local function animatePageSlots(page)
		local slots = pageSlots[page]
		if not slots then return end
		for i, s in ipairs(slots) do
			if s and s.Parent then
				s.Position = UDim2.new(-0.6, 0, 0.5, 0)
				task.delay(i * 0.04, function()
					if s and s.Parent then
						tw(s, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.5, 0) })
					end
				end)
			end
		end
	end

	local function switchTab(name)
		if activeTab == name then
			if isMobile and sidebarOpen then sidebarOpen = false; tw(sidebar, 0.22, { Size = UDim2.new(0, SW_CLOSE, 1, 0) }) end
			return
		end
		activeTab = name
		for n, page in pairs(pages) do page.Visible = (n == name) end
		local targetPage = pages[name]
		if targetPage then animatePageSlots(targetPage) end
		for n, btn in pairs(tabBtns) do
			if n == name then
				btn.BackgroundColor3 = rgb(255, 255, 255)
				tw(btn, 0.12, { BackgroundTransparency = 0.88 })
				local lbl = btn:FindFirstChildWhichIsA("TextLabel")
				if lbl then lbl.Font = Enum.Font.GothamBold; tw(lbl, 0.12, { TextColor3 = C.TEXT }) end
			else
				tw(btn, 0.12, { BackgroundTransparency = 1 })
				local lbl = btn:FindFirstChildWhichIsA("TextLabel")
				if lbl then lbl.Font = Enum.Font.Gotham; tw(lbl, 0.12, { TextColor3 = C.ICON }) end
			end
		end
		pageTitle.Text = name
		if isMobile and sidebarOpen then sidebarOpen = false; tw(sidebar, 0.22, { Size = UDim2.new(0, SW_CLOSE, 1, 0) }) end
		updateLayout()
	end

	local function createTabPage(name)
		if pages[name] then return pages[name] end
		local currentSW = sidebar.Size.X.Offset
		local page = new("ScrollingFrame", body, {
			Size = UDim2.new(1, -currentSW, 1, 0), Position = UDim2.fromOffset(currentSW, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = isMobile and 3 or 4, ScrollBarImageColor3 = C.BORDER2,
			CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingEnabled = true, ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
		})
		new("UIPadding", page, { PaddingTop = UDim.new(0, isMobile and 10 or 16), PaddingLeft = UDim.new(0, isMobile and 10 or 32), PaddingRight = UDim.new(0, isMobile and 8 or 24), PaddingBottom = UDim.new(0, isMobile and 16 or 32) })
		new("UIListLayout", page, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, isMobile and 7 or -5) })
		pages[name] = page
		pageSlots[page] = {}
		return page
	end

	local function createTabButton(name, icon, customIcon)
		navCount = navCount + 1
		local TAB_H = isMobile and 40 or 36
		local btn = new("Frame", navList, {
			LayoutOrder = navCount, Size = UDim2.new(1, 0, 0, TAB_H),
			BackgroundColor3 = rgb(255, 255, 255), BackgroundTransparency = 1, BorderSizePixel = 0,
		})
		new("UICorner", btn, { CornerRadius = UDim.new(0, 6) })
		if customIcon and tostring(customIcon) ~= "" then
			local imgId = tostring(customIcon)
			if tonumber(imgId) then imgId = "rbxassetid://" .. imgId end
			new("ImageLabel", btn, { Size = UDim2.fromOffset(22, TAB_H), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Image = imgId, ScaleType = Enum.ScaleType.Fit, ImageColor3 = C.ICON, Name = "TabIcon" })
		else
			new("TextLabel", btn, { Size = UDim2.fromOffset(22, TAB_H), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Text = icon or "☰", TextColor3 = C.ICON, Font = Enum.Font.Gotham, TextSize = isMobile and 14 or 13 })
		end
		local lbl = new("TextLabel", btn, { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(40, 0), BackgroundTransparency = 1, Text = name, TextColor3 = C.ICON, Font = Enum.Font.Gotham, TextSize = isMobile and 14 or 13, TextXAlignment = Enum.TextXAlignment.Left })
		local hb = new("TextButton", btn, { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 15 })
		hb.MouseEnter:Connect(function() if activeTab ~= name then btn.BackgroundColor3 = C.HOVER; tw(btn, 0.12, { BackgroundTransparency = 0.92 }); tw(lbl, 0.12, { TextColor3 = C.TEXT }) end end)
		hb.MouseLeave:Connect(function() if activeTab ~= name then tw(btn, 0.12, { BackgroundTransparency = 1 }); tw(lbl, 0.12, { TextColor3 = C.ICON }) end end)
		hb.MouseButton1Click:Connect(function() switchTab(name) end)
		tabBtns[name] = btn
		return btn
	end

	-- ─── Helper: createRightControl ──────────
	local function createRightControl(slot, width, height)
		local ctrl = new("Frame", slot, {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -D.marginR, 0.5, 0),
			Size = UDim2.new(0, width, 0, height), BackgroundColor3 = D.pillBg, BorderSizePixel = 0,
		})
		new("UICorner", ctrl, { CornerRadius = D.rad })
		new("UIStroke", ctrl, { Color = D.pillBorder, Thickness = 1 })
		return ctrl
	end

	-- ─── Helper: buildItemIcon ───────────────
	local function buildItemIcon(slot, cfg)
		if not cfg.icon or cfg.icon == "" then return 0 end
		local iconSize = D.iconSize; local iconPad = D.iconPad
		local iconFrame = new("Frame", slot, { Name = "IconFrame", AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = rgb(32, 32, 40), BorderSizePixel = 0, Position = UDim2.new(0.04, 0, 0.5, 0), Size = UDim2.fromOffset(iconSize, iconSize) })
		new("UICorner", iconFrame, { CornerRadius = UDim.new(0, 6) })
		new("UIStroke", iconFrame, { Color = D.pillBorder, Thickness = 1 })
		local imgId = tostring(cfg.icon)
		if tonumber(imgId) then imgId = "rbxassetid://" .. imgId end
		new("ImageLabel", iconFrame, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(iconSize - 6, iconSize - 6), Image = imgId, ScaleType = Enum.ScaleType.Fit, ImageColor3 = rgb(255, 255, 255) })
		return iconSize + iconPad
	end

	-- ══════════════════════════════════════════
	-- createItem  (ทุก branch เพิ่ม _items registry)
	-- ══════════════════════════════════════════
	local function createItem(scroll, itemIndex, itemName, originalCfg)
		local proxy = {}

		-- ── Space ────────────────────────────
		if originalCfg.name == "Space" then
			local container = new("Frame", scroll, { Name = "Container_" .. itemName, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = itemIndex, Size = UDim2.new(1, 0, 0, 30) })
			local Space = new("Frame", container, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.985, 0, 1, 0) })
			new("UICorner", Space, { CornerRadius = UDim.new(0.1, 0) })
			new("TextLabel", Space, { BackgroundTransparency = 1, Position = UDim2.new(0.02, 0, 0.1, 0), Size = UDim2.new(0.96, 0, 0.8, 0), Font = Enum.Font.GothamMedium, Text = originalCfg.Value or "", TextColor3 = rgb(140, 140, 155), TextSize = D.fontSub, TextXAlignment = Enum.TextXAlignment.Left })
			if pageSlots[scroll] then table.insert(pageSlots[scroll], Space) end
			setmetatable(proxy, { __index = originalCfg })
			-- ✅ register
			_items[originalCfg.key or itemName] = proxy
			return container, Space

			-- ── Logs ─────────────────────────────
		elseif originalCfg.name == "Logs" then
			local container = new("Frame", scroll, { Name = "Container_" .. itemName, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = itemIndex, Size = UDim2.new(1, 0, 0, 100) })
			local Space = new("Frame", container, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = rgb(28, 28, 32), BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.985, 0, 1, 0) })
			new("UICorner", Space, { CornerRadius = UDim.new(0.02, 0) })
			new("UIStroke", Space, { Color = D.pillBorder, Thickness = 1 })
			new("TextLabel", Space, { BackgroundTransparency = 1, Position = UDim2.new(0.02, 0, 0.02, 0), Size = UDim2.new(0.4, 0, 0.14, 0), ZIndex = 3, Text = "Logs", TextColor3 = D.pillMuted, TextSize = D.fontSub, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left })
			local ClearBtn = new("TextButton", Space, { AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = D.pillBg, BorderSizePixel = 0, Position = UDim2.new(0.98, 0, 0.04, 0), Size = UDim2.new(0.18, 0, 0.18, 0), Font = Enum.Font.Gotham, Text = "Clear", TextColor3 = D.pillText, TextSize = D.fontSmall })
			new("UICorner", ClearBtn, { CornerRadius = D.rad })
			local LogArea = new("Frame", Space, { Name = "LogArea", AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = rgb(18, 18, 20), BorderSizePixel = 0, ClipsDescendants = true, Position = UDim2.new(0.5, 0, 0.99, 0), Size = UDim2.new(0.96, 0, 0.72, 0) })
			new("UICorner", LogArea, { CornerRadius = UDim.new(0.02, 0) })
			new("UIListLayout", LogArea, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0.04, 0) })
			new("UIPadding", LogArea, { PaddingLeft = UDim.new(0.04, 0), PaddingTop = UDim.new(0.06, 0) })
			local function addLog(msg, msgType)
				local color = rgb(200, 200, 200)
				if msgType == Enum.MessageType.MessageWarning then color = rgb(255, 200, 0)
				elseif msgType == Enum.MessageType.MessageError then color = rgb(255, 80, 80)
				elseif msgType == Enum.MessageType.MessageInfo  then color = rgb(80, 180, 255) end
				new("TextLabel", LogArea, { Name = "Slot", BackgroundTransparency = 1, Size = UDim2.new(0.93, 0, 0.13, 0), ZIndex = 3, Text = "[" .. os.date("%X") .. "] " .. msg, TextColor3 = color, TextSize = 14, TextScaled = true, Font = Enum.Font.Code, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
				if #LogArea:GetChildren() > 9 then local f = LogArea:FindFirstChild("Slot"); if f then f:Destroy() end end
			end
			ClearBtn.MouseButton1Click:Connect(function() for _, c in pairs(LogArea:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end end)
			trackGlobalConnection(LogService.MessageOut:Connect(function(msg, msgType)
				if msg:find("^%>") then return end
				if not sg or not sg.Parent then return end
				addLog(msg, msgType)
			end))
			setmetatable(proxy, { __index = originalCfg })
			-- ✅ register
			_items[originalCfg.key or itemName] = proxy
			return container, Space
		end

		-- ── Standard slot ────────────────────
		local SLOT_H = isMobile and 60 or 54
		local container = new("Frame", scroll, { Name = "Container_" .. itemName, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = itemIndex, Size = UDim2.new(1, 0, 0, SLOT_H) })
		local slot = new("Frame", container, {
			Name = itemName, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = rgb(28, 28, 32),
			BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.983, 0, 0.8, 0),
		})
		slot.BackgroundTransparency = .5
		new("UICorner", slot, { CornerRadius = D.rad })
		new("UIStroke", slot, { Color = D.pillBorder, Thickness = 1 })

		local iconOffsetX = buildItemIcon(slot, originalCfg)
		local labelXScale  = 0.04
		local labelXOffset = iconOffsetX + (iconOffsetX > 0 and 8 or 0)
		local labelWidth   = UDim.new(1, -(D.inputW + D.marginR + 30 + labelXOffset))

		new("TextLabel", slot, { Name = "Name1", AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Position = UDim2.new(labelXScale, labelXOffset, 0.33, 0), Size = UDim2.new(labelWidth.Scale, labelWidth.Offset, 0.38, 0), Font = Enum.Font.GothamMedium, Text = itemName, TextColor3 = D.pillText, TextSize = D.fontMain, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
		new("TextLabel", slot, { Name = "Name2", AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Position = UDim2.new(labelXScale, labelXOffset, 0.72, 0), Size = UDim2.new(labelWidth.Scale, labelWidth.Offset, 0.22, 0), Font = Enum.Font.Gotham, Text = originalCfg.name2 or "", TextColor3 = D.pillMuted, TextSize = D.fontSub, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })

		local mainBtn = new("TextButton", slot, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.Gotham, Text = "" })

		-- ── Fold ─────────────────────────────
		if originalCfg.name == "Fold" then
			local isOpen = originalCfg.Value ~= false
			local HEADER_H = isMobile and 40 or 36
			local childItems = originalCfg.Items or {}
			local outerFrame = new("Frame", scroll, { Name = "Container_" .. itemName, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = itemIndex, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.None, ClipsDescendants = true })
			local header = new("Frame", outerFrame, { Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundColor3 = rgb(22, 22, 26), BorderSizePixel = 0 })
			new("UICorner", header, { CornerRadius = UDim.new(0, 6) })
			new("UIStroke", header, { Color = D.pillBorder, Thickness = 1 })
			new("TextLabel", header, { AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.04, 0, 0.5, 0), Size = UDim2.new(0.8, 0, 0.7, 0), Font = Enum.Font.GothamBold, Text = itemName, TextColor3 = D.pillText, TextSize = D.fontMain, TextXAlignment = Enum.TextXAlignment.Left })
			local chevron = new("TextLabel", header, { AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.97, 0, 0.5, 0), Size = UDim2.new(0.1, 0, 0.6, 0), Font = Enum.Font.GothamBold, Text = "∨", TextColor3 = D.pillMuted, TextSize = D.fontMain, Rotation = isOpen and 180 or 0 })
			local inner = new("Frame", outerFrame, { Position = UDim2.fromOffset(0, HEADER_H + 4), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0 })
			new("UIListLayout", inner, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, isMobile and 7 or 8) })
			local innerOrder = 0
			for _, childCfg in ipairs(childItems) do
				innerOrder += 1
				local childKey = childCfg.key or childCfg.name or ("FoldItem" .. innerOrder)
				createItem(inner, innerOrder, childKey, childCfg)
			end
			local function getInnerH()
				local h = 0
				for _, c in ipairs(inner:GetChildren()) do if c:IsA("Frame") then h = h + c.AbsoluteSize.Y + (isMobile and 7 or 8) end end
				return h
			end
			local function applyHeight(open)
				local targetH = open and (HEADER_H + 4 + getInnerH() + 8) or HEADER_H
				tw(outerFrame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, targetH) })
				TweenService:Create(chevron, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = open and 180 or 0 }):Play()
			end
			task.defer(function() applyHeight(isOpen) end)
			local hBtn = new("TextButton", header, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), Text = "" })
			hBtn.MouseButton1Click:Connect(function() isOpen = not isOpen; applyHeight(isOpen); ripple(hBtn) end)
			setmetatable(proxy, { __index = originalCfg })
			-- ✅ register
			_items[originalCfg.key or itemName] = proxy
			return outerFrame, header

			-- ── BoolValue ────────────────────────
		elseif originalCfg.name == "BoolValue" then
			local isTick = originalCfg.Tick == true
			if isTick then
				local tickBox = createRightControl(slot, 40, D.pillH)
				local check = new("TextLabel", tickBox, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.45, 0), Size = UDim2.new(0.7, 0, 0.7, 0), Font = Enum.Font.GothamBold, Text = "✓", TextColor3 = D.accent, TextSize = D.fontIcon, Visible = originalCfg.Value or false })
				local function updateUI(v) check.Visible = v end
				updateUI(originalCfg.Value or false)
				setmetatable(proxy, {
					__index = originalCfg,
					__newindex = function(t, k, v)
						rawset(originalCfg, k, v)
						if k == "Value" then updateUI(v); if originalCfg.Script then originalCfg.Script(v) end end
					end
				})
				mainBtn.MouseButton1Click:Connect(function() proxy.Value = not (proxy.Value or false); ripple(mainBtn) end)
			else
				local track = new("Frame", slot, { AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = rgb(45, 45, 50), BorderSizePixel = 0, Position = UDim2.new(1, -D.marginR, 0.5, 0), Size = UDim2.new(0, D.toggleW, 0, isMobile and 26 or 22) })
				new("UICorner", track, { CornerRadius = D.radRound })
				local trackStroke = new("UIStroke", track, { Color = rgb(70, 70, 78), Thickness = 1.2 })
				local knob = new("Frame", track, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = rgb(200, 200, 205), BorderSizePixel = 0, Position = UDim2.new(0.25, 0, 0.5, 0), Size = UDim2.new(0.36, 0, 0.72, 0), ZIndex = 3 })
				new("UICorner", knob, { CornerRadius = D.radRound })
				local knobGlow = new("Frame", knob, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = D.accent, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1.8, 0, 1.8, 0), ZIndex = 2 })
				new("UICorner", knobGlow, { CornerRadius = D.radRound })
				local function updateUI(v)
					tw(track, 0.25, { BackgroundColor3 = v and rgb(101, 95, 117) or rgb(45, 45, 50) })
					tw(trackStroke, 0.25, { Color = v and rgb(38, 38, 38) or rgb(70, 70, 78) })
					tw(knob, 0.28, { Position = UDim2.new(v and 0.75 or 0.25, 0, 0.5, 0), BackgroundColor3 = v and rgb(235, 235, 240) or rgb(200, 200, 205), Size = UDim2.new(0.38, 0, 0.76, 0) })
					tw(knobGlow, 0.25, { BackgroundTransparency = v and 0.75 or 1 })
				end
				updateUI(originalCfg.Value or false)
				setmetatable(proxy, {
					__index = originalCfg,
					__newindex = function(t, k, v)
						rawset(originalCfg, k, v)
						if k == "Value" then updateUI(v); if originalCfg.Script then originalCfg.Script(v) end end
					end
				})
				mainBtn.MouseButton1Click:Connect(function() proxy.Value = not (proxy.Value or false) end)
			end

			-- ── Slider ───────────────────────────
		elseif originalCfg.name == "Slider" then
			local minV = originalCfg.Value_Start or 0
			local maxV = originalCfg.Value_End   or 10
			local val  = originalCfg.Value or 0
			local valPill = createRightControl(slot, 50, D.pillH)
			local valLabel = new("TextLabel", valPill, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.9, 0, 0.7, 0), Font = Enum.Font.GothamMedium, Text = tostring(val), TextColor3 = D.pillText, TextSize = D.fontValue })
			local sliderW = isMobile and math.floor(WIN_W * 0.35) or D.sliderW
			local track = new("Frame", slot, { AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = D.sliderTrack, BorderSizePixel = 0, Position = UDim2.new(1, -(D.marginR + 50 + 10), 0.5, 0), Size = UDim2.new(0, sliderW, 0, isMobile and 8 or 6) })
			new("UICorner", track, { CornerRadius = D.radRound })
			local fill = new("Frame", track, { AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = D.sliderFill, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new((val - minV) / (maxV - minV), 0, 1, 0) })
			new("UICorner", fill, { CornerRadius = D.radRound })
			local knobSz = isMobile and 18 or 14
			local knob = new("Frame", track, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = D.knob, BorderSizePixel = 0, Position = UDim2.new((val - minV) / (maxV - minV), 0, 0.5, 0), Size = UDim2.fromOffset(knobSz, knobSz), ZIndex = 2 })
			new("UICorner", knob, { CornerRadius = D.radRound })
			new("UIStroke", knob, { Color = D.pillBorder, Thickness = 1 })
			local function updateSlider(n)
				val = n; valLabel.Text = tostring(val)
				local r = (val - minV) / (maxV - minV)
				tw(knob, 0.08, { Position = UDim2.new(r, 0, 0.5, 0) })
				tw(fill, 0.08, { Size = UDim2.new(r, 0, 1, 0) })
			end
			setmetatable(proxy, {
				__index = originalCfg,
				__newindex = function(t, k, v)
					rawset(originalCfg, k, v)
					if k == "Value" then updateSlider(v); if originalCfg.Script then originalCfg.Script(v) end end
				end
			})
			local sliding = false
			mainBtn.InputBegan:Connect(function(i) if isTouchOrMouse(i) then sliding = true end end)
			mainBtn.InputEnded:Connect(function(i) if isTouchOrMouse(i) then sliding = false end end)
			local knobBtn = new("TextButton", knob, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(2, 0, 2, 0), Text = "", ZIndex = 3 })
			knobBtn.InputBegan:Connect(function(i) if isTouchOrMouse(i) then sliding = true end end)
			knobBtn.InputEnded:Connect(function(i) if isTouchOrMouse(i) then sliding = false end end)
			trackConnection(UIS.InputChanged:Connect(function(i)
				if not sliding then return end
				if isMove(i) then
					local r = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
					proxy.Value = math.floor(minV + (maxV - minV) * r)
				end
			end))
			trackConnection(UIS.InputEnded:Connect(function(i) if isMove(i) then sliding = false end end))

			-- ── TextBox ──────────────────────────
		elseif originalCfg.name == "TextBox" then
			local isKeyMode = originalCfg.KeyMode == true
			local inputPill = createRightControl(slot, D.inputW, D.pillH)
			local TextBox = new("TextBox", inputPill, {
				AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.92, 0, 0.7, 0),
				Font = Enum.Font.Gotham, Text = originalCfg.Value and tostring(originalCfg.Value) or "",
				PlaceholderText = isKeyMode and "กดปุ่ม..." or "...", PlaceholderColor3 = D.pillMuted,
				TextColor3 = D.pillText, TextSize = D.fontValue, TextEditable = not isKeyMode, TextXAlignment = Enum.TextXAlignment.Center,
			})
			setmetatable(proxy, {
				__index = originalCfg,
				__newindex = function(t, k, v)
					rawset(originalCfg, k, v)
					if k == "Value" then
						if not TextBox:IsFocused() then TextBox.Text = tostring(v) end
						if isKeyMode and originalCfg.UI then _G.KeyClose = tostring(v) end
						if originalCfg.Script then originalCfg.Script(v) end
					end
				end
			})
			if isKeyMode then
				if originalCfg.UI and originalCfg.Value and originalCfg.Value ~= "" then _G.KeyClose = originalCfg.Value end
				local keyConn
				TextBox.Focused:Connect(function()
					TextBox.Text = "…"
					keyConn = UIS.InputBegan:Connect(function(input)
						if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
						local ignore = { [Enum.KeyCode.LeftShift]=true,[Enum.KeyCode.RightShift]=true,[Enum.KeyCode.LeftControl]=true,[Enum.KeyCode.RightControl]=true,[Enum.KeyCode.LeftAlt]=true,[Enum.KeyCode.RightAlt]=true,[Enum.KeyCode.LeftMeta]=true,[Enum.KeyCode.RightMeta]=true,[Enum.KeyCode.Unknown]=true }
						if ignore[input.KeyCode] then return end
						if originalCfg.UI then _G.KeyClose = input.KeyCode.Name end
						TextBox.Text = input.KeyCode.Name
						proxy.Value = input.KeyCode.Name
						TextBox:ReleaseFocus()
						if keyConn then keyConn:Disconnect(); keyConn = nil end
					end)
				end)
				TextBox.FocusLost:Connect(function()
					if keyConn then keyConn:Disconnect(); keyConn = nil end
					if TextBox.Text == "…" or TextBox.Text == "" then TextBox.Text = proxy.Value and tostring(proxy.Value) or "" end
				end)
			else
				local lastValue = originalCfg.Value and tostring(originalCfg.Value) or ""
				TextBox.Focused:Connect(function() TextBox.Text = lastValue; TextBox.CursorPosition = #lastValue + 1 end)
				TextBox.FocusLost:Connect(function() lastValue = TextBox.Text; proxy.Value = TextBox.Text end)
			end

			-- ── TextBoxAndButton ─────────────────
		elseif originalCfg.name == "TextBoxAndButton" then
			mainBtn:Destroy()
			local addPill = createRightControl(slot, 40, D.pillH)
			new("TextLabel", addPill, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.46, 0), Size = UDim2.new(0.7, 0, 0.7, 0), Font = Enum.Font.GothamMedium, Text = "+", TextColor3 = D.pillText, TextSize = D.fontIcon })
			local inputPill = createRightControl(slot, D.inputW - 10, D.pillH)
			inputPill.Position = UDim2.new(1, -(D.marginR + 50), 0.5, 0)
			local tb = new("TextBox", inputPill, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.9, 0, 0.7, 0), Font = Enum.Font.Gotham, PlaceholderColor3 = D.pillMuted, PlaceholderText = originalCfg.Placeholder or "...", Text = originalCfg.Value and tostring(originalCfg.Value) or "", TextColor3 = D.pillText, TextSize = D.fontValue, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left })
			local addBtn = new("TextButton", addPill, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), Text = "" })
			local function submit()
				local text = tb.Text
				if text == "" then return end
				rawset(originalCfg, "Value", text)
				if originalCfg.Script then originalCfg.Script(text) end
				ripple(addBtn)
				if originalCfg.ClearAfter ~= false then tb.Text = ""; rawset(originalCfg, "Value", "") end
			end
			addBtn.MouseButton1Click:Connect(submit)
			tb.FocusLost:Connect(function(ep) if ep then submit() end end)
			setmetatable(proxy, {
				__index = originalCfg,
				__newindex = function(t, k, v)
					rawset(originalCfg, k, v)
					if k == "Value" and not tb:IsFocused() then tb.Text = tostring(v) end
				end
			})

			-- ── Button ───────────────────────────
		elseif originalCfg.name == "Button" then
			local arrPill = createRightControl(slot, 36, D.pillH)
			new("TextLabel", arrPill, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.8, 0, 0.7, 0), Font = Enum.Font.GothamBold, Text = "›", TextColor3 = D.pillMuted, TextSize = D.fontIcon })
			local function showConfirm(onYes)
				local backdrop = new("Frame", sg, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), ZIndex = 500 })
				tw(backdrop, 0.2, { BackgroundTransparency = 0.55 })
				local dialog = new("Frame", sg, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = rgb(24, 24, 30), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0.38, 0), Size = UDim2.fromOffset(isMobile and 260 or 300, isMobile and 130 or 120), ZIndex = 501 })
				new("UICorner", dialog, { CornerRadius = UDim.new(0, 5) })
				new("UIStroke", dialog, { Color = rgb(55, 55, 70), Thickness = 1 })
				tw(dialog, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.45, 0), BackgroundTransparency = 0 })
				new("TextLabel", dialog, { AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(28, 28), Text = "⚠️", TextSize = 20, ZIndex = 502 })
				new("TextLabel", dialog, { AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.new(0.85, 0, 0, 36), Font = Enum.Font.GothamMedium, Text = originalCfg.ConfirmText or "ยืนยันการดำเนินการ?", TextColor3 = rgb(200, 200, 215), TextSize = isMobile and 13 or 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 502 })
				new("Frame", dialog, { AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = rgb(45, 45, 58), BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 0, 88), Size = UDim2.new(1, 0, 0, 1), ZIndex = 502 })
				local noBtn = new("TextButton", dialog, { AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = rgb(38, 38, 48), BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0.5, 0, 0, 32), Font = Enum.Font.GothamMedium, Text = "ยกเลิก", TextColor3 = rgb(160, 160, 175), TextSize = isMobile and 13 or 12, AutoButtonColor = false, ZIndex = 503 })
				new("UICorner", noBtn, { CornerRadius = UDim.new(0, 5) })
				local yesBtn = new("TextButton", dialog, { AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = rgb(45, 80, 55), BorderSizePixel = 0, Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0.5, 0, 0, 32), Font = Enum.Font.GothamBold, Text = "ยืนยัน ✓", TextColor3 = rgb(160, 220, 170), TextSize = isMobile and 13 or 12, AutoButtonColor = false, ZIndex = 503 })
				new("UICorner", yesBtn, { CornerRadius = UDim.new(0, 5) })
				noBtn.MouseEnter:Connect(function() tw(noBtn, 0.12, { BackgroundColor3 = rgb(50, 50, 62) }) end)
				noBtn.MouseLeave:Connect(function() tw(noBtn, 0.12, { BackgroundColor3 = rgb(38, 38, 48) }) end)
				yesBtn.MouseEnter:Connect(function() tw(yesBtn, 0.12, { BackgroundColor3 = rgb(55, 95, 65) }) end)
				yesBtn.MouseLeave:Connect(function() tw(yesBtn, 0.12, { BackgroundColor3 = rgb(45, 80, 55) }) end)
				local function closeDialog()
					tw(dialog, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0.55, 0), BackgroundTransparency = 1 })
					tw(backdrop, 0.2, { BackgroundTransparency = 1 })
					task.delay(0.22, function() if dialog.Parent then dialog:Destroy() end; if backdrop.Parent then backdrop:Destroy() end end)
				end
				noBtn.MouseButton1Click:Connect(function() ripple(noBtn); closeDialog() end)
				yesBtn.MouseButton1Click:Connect(function() ripple(yesBtn); closeDialog(); task.delay(0.15, onYes) end)
			end
			mainBtn.MouseEnter:Connect(function() tw(arrPill, 0.15, { BackgroundColor3 = rgb(40, 40, 52) }); tw(arrPill:FindFirstChildWhichIsA("TextLabel"), 0.15, { TextColor3 = D.pillText }) end)
			mainBtn.MouseLeave:Connect(function() tw(arrPill, 0.15, { BackgroundColor3 = D.pillBg }); tw(arrPill:FindFirstChildWhichIsA("TextLabel"), 0.15, { TextColor3 = D.pillMuted }) end)
			mainBtn.MouseButton1Click:Connect(function()
				ripple(arrPill)
				if originalCfg.Confirm then showConfirm(function() if originalCfg.Script then originalCfg.Script(proxy.Value) end end)
				else if originalCfg.Script then originalCfg.Script(proxy.Value) end end
			end)
			setmetatable(proxy, { __index = originalCfg })

			-- ── ColorUI ──────────────────────────
		elseif originalCfg.name == "ColorUI" then
			local presets = {
				{ name = "White",  color = rgb(220, 220, 225) },
				{ name = "Purple", color = rgb(130, 60, 200)  },
				{ name = "Red",    color = rgb(216, 62, 62)   },
				{ name = "Custom", color = originalCfg.Value or rgb(216, 62, 62) },
			}
			local applyingTheme = false
			local customColor   = originalCfg.Value or rgb(216, 62, 62)
			local customBox     = nil
			local h2, s2, v3   = Color3.toHSV(customColor)
			local cpPopup, cpOpen = nil, false
			local cpTrack, cpResize, cpGuiConn = nil, nil, nil
			local CP_SCALE_X = isMobile and 0.7 or 0.35
			local CP_SCALE_Y = isMobile and 0.5 or 0.55

			local function applyTheme(c)
				if applyingTheme then return end
				applyingTheme = true
				if originalCfg.ApplyTheme ~= false then D.accent = c; D.accentDim = rgb(math.floor(c.R*255*0.35), math.floor(c.G*255*0.35), math.floor(c.B*255*0.35)); D.sliderFill = c end
				if originalCfg.Script then originalCfg.Script(c) end
				rawset(originalCfg, "Value", c)
				applyingTheme = false
			end
			local function updateCPPos()
				if not cpPopup or not cpPopup.Parent or not customBox or not customBox.Parent then return end
				local fs = window.AbsoluteSize; local pp = customBox.AbsolutePosition - window.AbsolutePosition; local ps = customBox.AbsoluteSize
				local x = (pp.X + ps.X) / fs.X; local y = pp.Y / fs.Y
				if x + CP_SCALE_X > 1 then x = pp.X / fs.X - CP_SCALE_X end
				if y + CP_SCALE_Y > 1 then y = 1 - CP_SCALE_Y end
				x, y = math.max(0, x), math.max(0, y)
				cpPopup.Position = UDim2.new(x, 0, y, 0); cpPopup.Size = UDim2.new(CP_SCALE_X, 0, CP_SCALE_Y, 0)
			end
			local function closeCPPopup(instant)
				cpOpen = false
				if cpGuiConn then cpGuiConn:Disconnect(); cpGuiConn = nil end
				if cpTrack   then cpTrack:Disconnect();   cpTrack   = nil end
				if cpResize  then cpResize:Disconnect();  cpResize  = nil end
				if not cpPopup then return end
				if instant then cpPopup:Destroy(); cpPopup = nil
				else
					cpPopup.ClipsDescendants = true
					local cs = cpPopup.Size
					tw(cpPopup, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.new(cs.X.Scale, 0, 0, 0), BackgroundTransparency = 1 })
					task.delay(0.16, function() if cpPopup then cpPopup:Destroy(); cpPopup = nil end end)
				end
			end
			local function buildCPPopup()
				if cpPopup then return end
				local fs = window.AbsoluteSize; local pp = customBox.AbsolutePosition - window.AbsolutePosition; local ps = customBox.AbsoluteSize
				local x = (pp.X + ps.X) / fs.X; local y = pp.Y / fs.Y
				if x + CP_SCALE_X > 1 then x = pp.X / fs.X - CP_SCALE_X end
				if y + CP_SCALE_Y > 1 then y = 1 - CP_SCALE_Y end
				x, y = math.max(0, x), math.max(0, y)
				cpPopup = new("Frame", window, { BackgroundColor3 = rgb(20,20,24), BorderSizePixel = 0, ClipsDescendants = false, ZIndex = 60, Size = UDim2.new(CP_SCALE_X,0,CP_SCALE_Y,0), Position = UDim2.new(x,0,y,0) })
				new("UICorner", cpPopup, { CornerRadius = UDim.new(.02,0) }); new("UIStroke", cpPopup, { Color = D.pillBorder, Thickness = 1 })
				local svFrame = new("Frame", cpPopup, { BackgroundColor3 = Color3.fromHSV(h2,1,1), BorderSizePixel=0, Position=UDim2.new(0.04,0,0.04,0), Size=UDim2.new(0.92,0,0.55,0), ClipsDescendants=true, ZIndex=61 })
				new("UICorner", svFrame, { CornerRadius=UDim.new(.02,0) })
				local wGrad = new("Frame", svFrame, { BackgroundColor3=rgb(255,255,255), BorderSizePixel=0, Size=UDim2.new(1,0,1,0), ZIndex=62 }); new("UICorner", wGrad, { CornerRadius=UDim.new(.02,0) }); new("UIGradient", wGrad, { Rotation=0, Color=ColorSequence.new{ColorSequenceKeypoint.new(0,rgb(255,255,255)),ColorSequenceKeypoint.new(1,rgb(255,255,255))}, Transparency=NumberSequence.new{NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)} })
				local bGrad = new("Frame", svFrame, { BackgroundColor3=rgb(0,0,0), BorderSizePixel=0, Size=UDim2.new(1,0,1,0), ZIndex=63 }); new("UICorner", bGrad, { CornerRadius=UDim.new(.02,0) }); new("UIGradient", bGrad, { Rotation=90, Transparency=NumberSequence.new{NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)} })
				local svCursor = new("Frame", svFrame, { AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=rgb(255,255,255), BorderSizePixel=0, Position=UDim2.new(s2,0,1-v3,0), Size=UDim2.fromOffset(isMobile and 14 or 10,isMobile and 14 or 10), ZIndex=65 }); new("UICorner", svCursor, { CornerRadius=UDim.new(1,0) }); new("UIStroke", svCursor, { Color=rgb(0,0,0), Thickness=1.5 })
				local hueBar = new("Frame", cpPopup, { BackgroundColor3=rgb(255,255,255), BorderSizePixel=0, Position=UDim2.new(0.04,0,0.63,0), Size=UDim2.new(0.92,0,0.07,0), ClipsDescendants=true, ZIndex=61 }); new("UICorner", hueBar, { CornerRadius=UDim.new(.02,0) })
				local hueColors = {}; for i=0,6 do table.insert(hueColors, ColorSequenceKeypoint.new(i/6, Color3.fromHSV(i/6,1,1))) end; new("UIGradient", hueBar, { Color=ColorSequence.new(hueColors), Rotation=0 })
				local hueCursor = new("Frame", hueBar, { AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=rgb(255,255,255), BorderSizePixel=0, Position=UDim2.new(h2,0,0.5,0), Size=UDim2.fromOffset(isMobile and 10 or 8,isMobile and 22 or 18), ZIndex=62 }); new("UICorner", hueCursor, { CornerRadius=UDim.new(.02,0) }); new("UIStroke", hueCursor, { Color=rgb(0,0,0), Thickness=1.5 })
				local hexBox = new("Frame", cpPopup, { BackgroundColor3=rgb(30,30,35), BorderSizePixel=0, Position=UDim2.new(0.04,0,0.87,0), Size=UDim2.new(0.92,0,0.1,0), ZIndex=61 }); new("UICorner", hexBox, { CornerRadius=UDim.new(.02,0) }); new("UIStroke", hexBox, { Color=D.pillBorder, Thickness=1 })
				local hexTb = new("TextBox", hexBox, { AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(0.9,0,0.8,0), Font=Enum.Font.Code, Text=colorToHex(customColor), TextColor3=D.pillText, TextScaled=true, ZIndex=62, ClearTextOnFocus=false })
				local function applyCP()
					local c = Color3.fromHSV(h2,s2,v3); customColor = c
					local icon = customBox:FindFirstChild("PlusIcon"); if icon then icon.TextColor3 = getContrastColor(c) end
					if customBox then customBox.BackgroundColor3 = c end
					svFrame.BackgroundColor3 = Color3.fromHSV(h2,1,1)
					svCursor.Position = UDim2.new(s2,0,1-v3,0); hueCursor.Position = UDim2.new(h2,0,0.5,0)
					hexTb.Text = colorToHex(c); applyTheme(c)
				end
				applyCP()
				local dSV, dHue = false, false
				local svBtn = new("TextButton", svFrame, { AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(1,0,1,0), Text="", ZIndex=66 })
				svBtn.InputBegan:Connect(function(i) if isTouchOrMouse(i) then dSV=true end end); svBtn.InputEnded:Connect(function(i) if isTouchOrMouse(i) then dSV=false end end)
				local hBtn = new("TextButton", hueBar, { AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(1,0,1,0), Text="", ZIndex=63 })
				hBtn.InputBegan:Connect(function(i) if isTouchOrMouse(i) then dHue=true end end); hBtn.InputEnded:Connect(function(i) if isTouchOrMouse(i) then dHue=false end end)
				trackConnection(UIS.InputChanged:Connect(function(i)
					if not isMove(i) then return end
					local pos = Vector2.new(i.Position.X, i.Position.Y)
					if dSV then local rel = pos - svFrame.AbsolutePosition; s2 = math.clamp(rel.X/svFrame.AbsoluteSize.X,0,1); v3 = 1-math.clamp(rel.Y/svFrame.AbsoluteSize.Y,0,1); applyCP()
					elseif dHue then local rel = pos - hueBar.AbsolutePosition; h2 = math.clamp(rel.X/hueBar.AbsoluteSize.X,0,1); applyCP() end
				end))
				trackConnection(UIS.InputEnded:Connect(function(i) if isTouchOrMouse(i) then dSV=false; dHue=false end end))
				hexTb.FocusLost:Connect(function() local c = hexToColor3(hexTb.Text); if c then h2,s2,v3 = Color3.toHSV(c); applyCP() end end)
			end
			local function openCPPopup()
				buildCPPopup(); cpOpen = true
				local targetSize = UDim2.new(CP_SCALE_X,0,CP_SCALE_Y,0)
				cpPopup.ClipsDescendants=true; cpPopup.Size=UDim2.new(CP_SCALE_X,0,0,0); cpPopup.BackgroundTransparency=1
				cpTrack = customBox:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateCPPos)
				cpResize = window:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCPPos)
				tw(cpPopup, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size=targetSize, BackgroundTransparency=0 })
				cpGuiConn = UIS.InputBegan:Connect(function(inp)
					if not cpOpen then return end; if not isTouchOrMouse(inp) then return end
					local pos = inp.Position
					if customBox then local bPos=customBox.AbsolutePosition; local bSize=customBox.AbsoluteSize; if pos.X>=bPos.X and pos.X<=bPos.X+bSize.X and pos.Y>=bPos.Y and pos.Y<=bPos.Y+bSize.Y then return end end
					if cpPopup then local pPos=cpPopup.AbsolutePosition; local pSize=cpPopup.AbsoluteSize; if pos.X>=pPos.X and pos.X<=pPos.X+pSize.X and pos.Y>=pPos.Y and pos.Y<=pPos.Y+pSize.Y then return end end
					closeCPPopup()
				end)
			end
			local boxW = isMobile and 36 or 32; local gap = isMobile and 6 or 8
			local totalW2 = (#presets * boxW) + ((#presets - 1) * gap)
			local boxRow = new("Frame", slot, { AnchorPoint=Vector2.new(1,0.5), BackgroundTransparency=1, BorderSizePixel=0, Position=UDim2.new(1,-D.marginR,0.5,0), Size=UDim2.new(0,totalW2,0,boxW) })
			new("UIListLayout", boxRow, { FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Right, VerticalAlignment=Enum.VerticalAlignment.Center, Padding=UDim.new(0,gap) })
			for _, preset in ipairs(presets) do
				local isCustom = preset.name == "Custom"
				local box = new("Frame", boxRow, { BackgroundColor3=preset.color, BorderSizePixel=0, Size=UDim2.fromOffset(boxW,boxW) })
				new("UICorner", box, { CornerRadius=D.rad }); new("UIStroke", box, { Color=D.pillBorder, Thickness=1 })
				if isCustom then
					customBox = box
					new("TextLabel", box, { Name="PlusIcon", AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(0.7,0,0.7,0), Font=Enum.Font.GothamBold, Text="+", TextColor3=getContrastColor(preset.color), TextSize=D.fontIcon, TextTransparency=0.3 })
				end
				local boxBtn = new("TextButton", box, { AnchorPoint=Vector2.new(0.5,0.5), BackgroundTransparency=1, Position=UDim2.new(0.5,0,0.5,0), Size=UDim2.new(1,0,1,0), Text="" })
				boxBtn.MouseButton1Click:Connect(function()
					if isCustom then if cpOpen then closeCPPopup() else openCPPopup() end
					else
						applyTheme(preset.color); customColor=preset.color; h2,s2,v3=Color3.toHSV(preset.color)
						if customBox then customBox.BackgroundColor3=preset.color end
						closeCPPopup(true)
						local icon = customBox:FindFirstChild("PlusIcon"); if icon then icon.TextColor3=getContrastColor(preset.color) end
					end
					ripple(boxBtn)
				end)
			end
			slot.AncestryChanged:Connect(function() if not slot.Parent then closeCPPopup(true) end end)
			setmetatable(proxy, {
				__index = originalCfg,
				__newindex = function(t, k, v)
					rawset(originalCfg, k, v)
					if k == "Value" then customColor=v; h2,s2,v3=Color3.toHSV(v); if customBox then customBox.BackgroundColor3=v end end
				end
			})

			-- ── ColorPicker ──────────────────────
		elseif originalCfg.name == "ColorPicker" then
			local currentColor = originalCfg.Value or rgb(255, 255, 255)
			local h, s, v2 = Color3.toHSV(currentColor)
			local CP_SCALE_X = isMobile and 0.7 or 0.35; local CP_SCALE_Y = isMobile and 0.5 or 0.55
			local swatch = new("Frame", slot, { AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=currentColor, BorderSizePixel=0, Position=UDim2.new(0.88,0,0.5,0), Size=UDim2.new(0.08,0,0.55,0) })
			new("UICorner", swatch, { CornerRadius=D.rad }); new("UIStroke", swatch, { Color=D.pillBorder, Thickness=1 })
			local hexLabel = new("TextLabel", slot, { AnchorPoint=Vector2.new(1,0.5), BackgroundTransparency=1, Position=UDim2.new(0.78,0,0.5,0), Size=UDim2.new(0.2,0,0.4,0), Font=Enum.Font.Code, Text="", TextColor3=D.pillMuted, TextSize=D.fontSmall, TextXAlignment=Enum.TextXAlignment.Right })
			local isOpen,popup,guiConn2,trackConn,resizeConn = false,nil,nil,nil,nil
			local function updateSwatch(c) currentColor=c; swatch.BackgroundColor3=c; hexLabel.Text=colorToHex(c) end
			updateSwatch(currentColor)
			local function updateColorPopupPos()
				if not popup or not popup.Parent then return end
				local frameSize=window.AbsoluteSize; local pillPos=swatch.AbsolutePosition-window.AbsolutePosition; local pillSize=swatch.AbsoluteSize
				local x=(pillPos.X+pillSize.X)/frameSize.X; local y=pillPos.Y/frameSize.Y
				if x+CP_SCALE_X>1 then x=pillPos.X/frameSize.X-CP_SCALE_X end
				if y+CP_SCALE_Y>1 then y=1-CP_SCALE_Y end
				x,y=math.max(0,x),math.max(0,y)
				popup.Position=UDim2.new(x,0,y,0); popup.Size=UDim2.new(CP_SCALE_X,0,CP_SCALE_Y,0)
			end
			local function buildColorPopup()
				if popup then return end
				local frameSize=window.AbsoluteSize; local pillPos=swatch.AbsolutePosition-window.AbsolutePosition; local pillSize=swatch.AbsoluteSize
				local x=(pillPos.X+pillSize.X)/frameSize.X; local y=pillPos.Y/frameSize.Y
				if x+CP_SCALE_X>1 then x=pillPos.X/frameSize.X-CP_SCALE_X end
				if y+CP_SCALE_Y>1 then y=1-CP_SCALE_Y end
				x,y=math.max(0,x),math.max(0,y)
				popup=new("Frame",window,{BackgroundColor3=rgb(20,20,24),BorderSizePixel=0,ClipsDescendants=false,ZIndex=60,Size=UDim2.new(CP_SCALE_X,0,CP_SCALE_Y,0),Position=UDim2.new(x,0,y,0)})
				new("UICorner",popup,{CornerRadius=UDim.new(.02,0)}); new("UIStroke",popup,{Color=D.pillBorder,Thickness=1})
				local svFrame=new("Frame",popup,{BackgroundColor3=Color3.fromHSV(h,1,1),BorderSizePixel=0,Position=UDim2.new(0.04,0,0.04,0),Size=UDim2.new(0.92,0,0.58,0),ClipsDescendants=true,ZIndex=61}); new("UICorner",svFrame,{CornerRadius=UDim.new(.02,0)})
				local wGrad=new("Frame",svFrame,{BackgroundColor3=rgb(255,255,255),BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=62}); new("UICorner",wGrad,{CornerRadius=UDim.new(.02,0)}); new("UIGradient",wGrad,{Rotation=0,Color=ColorSequence.new{ColorSequenceKeypoint.new(0,rgb(255,255,255)),ColorSequenceKeypoint.new(1,rgb(255,255,255))},Transparency=NumberSequence.new{NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}})
				local bGrad=new("Frame",svFrame,{BackgroundColor3=rgb(0,0,0),BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=63}); new("UICorner",bGrad,{CornerRadius=UDim.new(.02,0)}); new("UIGradient",bGrad,{Rotation=90,Transparency=NumberSequence.new{NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}})
				local svCursor=new("Frame",svFrame,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=rgb(255,255,255),BorderSizePixel=0,Position=UDim2.new(s,0,1-v2,0),Size=UDim2.fromOffset(isMobile and 14 or 10,isMobile and 14 or 10),ZIndex=65}); new("UICorner",svCursor,{CornerRadius=UDim.new(1,0)}); new("UIStroke",svCursor,{Color=rgb(0,0,0),Thickness=1.5})
				local hueBar=new("Frame",popup,{BackgroundColor3=rgb(255,255,255),BorderSizePixel=0,Position=UDim2.new(0.04,0,0.66,0),Size=UDim2.new(0.92,0,0.07,0),ClipsDescendants=true,ZIndex=61}); new("UICorner",hueBar,{CornerRadius=UDim.new(.02,0)})
				local hueColors={}; for i=0,6 do table.insert(hueColors,ColorSequenceKeypoint.new(i/6,Color3.fromHSV(i/6,1,1))) end; new("UIGradient",hueBar,{Color=ColorSequence.new(hueColors),Rotation=0})
				local hueCursor=new("Frame",hueBar,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=rgb(255,255,255),BorderSizePixel=0,Position=UDim2.new(h,0,0.5,0),Size=UDim2.fromOffset(isMobile and 10 or 8,isMobile and 22 or 18),ZIndex=62}); new("UICorner",hueCursor,{CornerRadius=UDim.new(.02,0)}); new("UIStroke",hueCursor,{Color=rgb(0,0,0),Thickness=1.5})
				local function makeLabel(pos,text) local lf=new("Frame",popup,{BackgroundColor3=rgb(30,30,35),BorderSizePixel=0,Position=pos,Size=UDim2.new(0.28,0,0.1,0),ZIndex=61}); new("UICorner",lf,{CornerRadius=UDim.new(.02,0)}); return new("TextLabel",lf,{BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Font=Enum.Font.Code,Text=text,TextColor3=D.pillText,TextScaled=true,ZIndex=62}) end
				local rLabel=makeLabel(UDim2.new(0.04,0,0.78,0),"R: 255"); local gLabel=makeLabel(UDim2.new(0.36,0,0.78,0),"G: 255"); local bLabel=makeLabel(UDim2.new(0.68,0,0.78,0),"B: 255")
				local hexBox=new("Frame",popup,{BackgroundColor3=rgb(30,30,35),BorderSizePixel=0,Position=UDim2.new(0.04,0,0.89,0),Size=UDim2.new(0.92,0,0.09,0),ZIndex=61}); new("UICorner",hexBox,{CornerRadius=UDim.new(.02,0)}); new("UIStroke",hexBox,{Color=D.pillBorder,Thickness=1})
				local hexTb=new("TextBox",hexBox,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0.9,0,0.8,0),Font=Enum.Font.Code,Text=colorToHex(currentColor),TextColor3=D.pillText,TextScaled=true,ZIndex=62,ClearTextOnFocus=false})
				local function applyColor()
					local c=Color3.fromHSV(h,s,v2); updateSwatch(c)
					svFrame.BackgroundColor3=Color3.fromHSV(h,1,1); svCursor.Position=UDim2.new(s,0,1-v2,0); hueCursor.Position=UDim2.new(h,0,0.5,0)
					local r2,g2,b2=math.floor(c.R*255),math.floor(c.G*255),math.floor(c.B*255)
					rLabel.Text="R: "..r2; gLabel.Text="G: "..g2; bLabel.Text="B: "..b2
					hexTb.Text=colorToHex(c); proxy.Value=c
				end
				applyColor()
				local draggingSV,draggingHue=false,false
				local svBtn=new("TextButton",svFrame,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,1,0),Text="",ZIndex=66})
				svBtn.InputBegan:Connect(function(i) if isTouchOrMouse(i) then draggingSV=true end end); svBtn.InputEnded:Connect(function(i) if isTouchOrMouse(i) then draggingSV=false end end)
				local hueBtn=new("TextButton",hueBar,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,1,0),Text="",ZIndex=63})
				hueBtn.InputBegan:Connect(function(i) if isTouchOrMouse(i) then draggingHue=true end end); hueBtn.InputEnded:Connect(function(i) if isTouchOrMouse(i) then draggingHue=false end end)
				trackConnection(UIS.InputChanged:Connect(function(i)
					if not isMove(i) then return end
					local pos=Vector2.new(i.Position.X,i.Position.Y)
					if draggingSV then local rel=pos-svFrame.AbsolutePosition; s=math.clamp(rel.X/svFrame.AbsoluteSize.X,0,1); v2=1-math.clamp(rel.Y/svFrame.AbsoluteSize.Y,0,1); applyColor()
					elseif draggingHue then local rel=pos-hueBar.AbsolutePosition; h=math.clamp(rel.X/hueBar.AbsoluteSize.X,0,1); applyColor() end
				end))
				trackConnection(UIS.InputEnded:Connect(function(i) if isTouchOrMouse(i) then draggingSV=false; draggingHue=false end end))
				hexTb.FocusLost:Connect(function() local c=hexToColor3(hexTb.Text); if c then h,s,v2=Color3.toHSV(c); applyColor() end end)
			end
			local function closeColorPopup(instant)
				isOpen=false
				if guiConn2   then guiConn2:Disconnect();   guiConn2=nil end
				if trackConn  then trackConn:Disconnect();  trackConn=nil end
				if resizeConn then resizeConn:Disconnect(); resizeConn=nil end
				if not popup then return end
				if instant then popup:Destroy(); popup=nil
				else
					popup.ClipsDescendants=true
					local curSize=popup.Size
					tw(popup,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.new(curSize.X.Scale,curSize.X.Offset,0,0),BackgroundTransparency=1})
					task.delay(0.16,function() if popup then popup:Destroy(); popup=nil end end)
				end
			end
			local function openColorPopup()
				buildColorPopup(); isOpen=true
				local targetSize=UDim2.new(CP_SCALE_X,0,CP_SCALE_Y,0)
				popup.ClipsDescendants=true; popup.Size=UDim2.new(CP_SCALE_X,0,0,0); popup.BackgroundTransparency=1
				trackConn=swatch:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateColorPopupPos)
				resizeConn=window:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateColorPopupPos)
				tw(popup,TweenInfo.new(0.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=targetSize,BackgroundTransparency=0})
				guiConn2=UIS.InputBegan:Connect(function(inp)
					if not isOpen then return end; if not isTouchOrMouse(inp) then return end
					local pos=inp.Position
					local mPos=mainBtn.AbsolutePosition; local mSize=mainBtn.AbsoluteSize
					if pos.X>=mPos.X and pos.X<=mPos.X+mSize.X and pos.Y>=mPos.Y and pos.Y<=mPos.Y+mSize.Y then return end
					if popup then local pPos=popup.AbsolutePosition; local pSize=popup.AbsoluteSize; if pos.X>=pPos.X and pos.X<=pPos.X+pSize.X and pos.Y>=pPos.Y and pos.Y<=pPos.Y+pSize.Y then return end end
					closeColorPopup()
				end)
			end
			mainBtn.InputBegan:Connect(function(input) if not isTouchOrMouse(input) then return end; if isOpen then closeColorPopup() else openColorPopup() end end)
			slot.AncestryChanged:Connect(function() if not slot.Parent then closeColorPopup(true) end end)
			setmetatable(proxy, {
				__index = originalCfg,
				__newindex = function(t, k, v)
					rawset(originalCfg, k, v)
					if k == "Value" then currentColor=v; h,s,v2=Color3.toHSV(v); updateSwatch(v); if originalCfg.Script then originalCfg.Script(v) end end
				end
			})

			-- ── InstancePicker ───────────────────
		elseif originalCfg.name == "InstancePicker" then
			local isMultiMode = originalCfg.Mode == true
			local currentVal
			if isMultiMode then
				currentVal = {}
				if type(originalCfg.Value) == "table" then for _, v in pairs(originalCfg.Value) do table.insert(currentVal, v) end
				elseif type(originalCfg.Value) == "string" and originalCfg.Value ~= "" then table.insert(currentVal, originalCfg.Value) end
			else currentVal = originalCfg.Value or "" end
			local isOpen2=false; local searchText=""; local trackConn2=nil; local guiConn3=nil; local popup2=nil
			local listScroll2,searchBox2
			local ITEM_H2=isMobile and 38 or 32; local HEADER_H2=24; local HEADER_PAD=4
			local POP_WIDTH2=isMobile and (WIN_W-20) or 280; local POP_MAX_H=isMobile and 280 or 320
			local SEARCH_H=isMobile and 42 or 36; local currentPopupH=SEARCH_H+50
			local pill=createRightControl(slot,D.inputW,D.pillH)
			local pillText=new("TextLabel",pill,{AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,Position=UDim2.new(0.06,0,0.5,0),Size=UDim2.new(0.82,0,0.65,0),Font=Enum.Font.Gotham,Text="",TextColor3=D.pillText,TextSize=D.fontValue,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
			local chevron2=new("TextLabel",pill,{AnchorPoint=Vector2.new(1,0.5),BackgroundTransparency=1,Position=UDim2.new(0.96,0,0.5,0),Size=UDim2.new(0.18,0,0.6,0),Rotation=0,Font=Enum.Font.Gotham,Text="∨",TextColor3=D.pillMuted,TextSize=D.fontSmall})
			local function validateCurrentVal()
				local currentPool={}
				for _,cat in ipairs(originalCfg.Categories or {}) do for _,iN in ipairs(cat.items or {}) do currentPool[iN]=true end end
				if isMultiMode then
					local validated,changed={},false
					for _,sN in ipairs(currentVal) do if currentPool[sN] then table.insert(validated,sN) else changed=true end end
					if changed then currentVal=validated; proxy.Value=currentVal end
				else if currentVal~="" and not currentPool[currentVal] then currentVal=""; proxy.Value=currentVal end end
			end
			local function updatePillText()
				validateCurrentVal()
				if isMultiMode then
					if #currentVal==0 then pillText.Text="Select…"; pillText.TextColor3=D.pillMuted
					else pillText.Text=table.concat(currentVal,", "); pillText.TextColor3=D.pillText end
				else
					if currentVal=="" then pillText.Text="Select…"; pillText.TextColor3=D.pillMuted
					else pillText.Text=currentVal; pillText.TextColor3=D.pillText end
				end
			end
			updatePillText()
			local function setChevron2(open) TweenService:Create(chevron2,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{Rotation=open and 180 or 0}):Play() end
			local function calcPopupPosition2()
				local vp=camera.ViewportSize; local sc=uiScale.Scale
				local pAbs=pill.AbsolutePosition; local pSz=pill.AbsoluteSize
				local x=pAbs.X/sc; local y=pAbs.Y/sc+pSz.Y/sc+4
				local maxY=vp.Y/sc; local ph=currentPopupH
				if y+ph>maxY-10 then y=maxY-ph-10 end; if y<10 then y=10 end
				if x+POP_WIDTH2>vp.X/sc-10 then x=vp.X/sc-POP_WIDTH2-10 end; if x<10 then x=10 end
				return x,y,POP_WIDTH2,ph
			end
			local function closePicker2(instant)
				isOpen2=false
				if activePickerCloser==closePicker2 then activePickerCloser=nil end
				if guiConn3   then guiConn3:Disconnect();  guiConn3=nil end
				if trackConn2 then trackConn2:Disconnect(); trackConn2=nil end
				if not popup2 then setChevron2(false); return end
				setChevron2(false)
				if instant then popup2.Visible=false; if popup2.Parent then popup2:Destroy() end; popup2=nil
				else
					local x,y,pw,ph=calcPopupPosition2()
					popup2.ClipsDescendants=true
					TweenService:Create(popup2,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.fromOffset(pw,SEARCH_H),BackgroundTransparency=1}):Play()
					task.delay(0.16,function() if popup2 and popup2.Parent then popup2:Destroy(); popup2=nil end end)
				end
			end
			local function buildItems2(filter)
				if not listScroll2 then return end
				for _,v in pairs(listScroll2:GetChildren()) do if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end end
				local order=0; local hasItems=false; local calcH=SEARCH_H+1
				for _,cat in ipairs(originalCfg.Categories or {}) do
					local visible={}
					for _,name in ipairs(cat.items or {}) do if filter=="" or name:lower():find(filter:lower(),1,true) then table.insert(visible,name) end end
					if #visible==0 then continue end
					hasItems=true
					if cat.name and cat.name~="" then
						order+=1; calcH=calcH+HEADER_H2+HEADER_PAD
						local headerFrame=new("Frame",listScroll2,{BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=order,Size=UDim2.new(1,0,0,HEADER_H2+HEADER_PAD)})
						new("TextLabel",headerFrame,{AnchorPoint=Vector2.new(0,1),BackgroundTransparency=1,Position=UDim2.new(0,0,1,0),Size=UDim2.new(1,0,0,HEADER_H2),Font=Enum.Font.GothamBold,Text=cat.name,TextColor3=rgb(100,100,115),TextSize=11,TextXAlignment=Enum.TextXAlignment.Left})
					end
					for _,iName in ipairs(visible) do
						order+=1; calcH=calcH+ITEM_H2+2
						local isSel=isMultiMode and (table.find(currentVal,iName)~=nil) or (iName==currentVal)
						local Item=new("Frame",listScroll2,{BackgroundColor3=isSel and rgb(40,40,50) or rgb(28,28,34),BackgroundTransparency=0,BorderSizePixel=0,LayoutOrder=order,Size=UDim2.new(1,0,0,ITEM_H2)})
						new("UICorner",Item,{CornerRadius=UDim.new(0,4)})
						if isSel then new("Frame",Item,{AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=D.accent,BackgroundTransparency=0,BorderSizePixel=0,Position=UDim2.new(0,0,0.5,0),Size=UDim2.new(0,3,0,ITEM_H2*0.5)}) end
						new("TextLabel",Item,{AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,Position=UDim2.new(0,isSel and 12 or 10,0.5,0),Size=UDim2.new(1,-20,0,ITEM_H2-4),Font=isSel and Enum.Font.GothamMedium or Enum.Font.Gotham,Text=iName,TextColor3=isSel and rgb(220,220,230) or rgb(170,170,185),TextSize=isMobile and 13 or 12,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
						if isMultiMode then
							local checkBox=new("Frame",Item,{AnchorPoint=Vector2.new(1,0.5),BackgroundColor3=isSel and D.accent or rgb(50,50,60),BorderSizePixel=0,Position=UDim2.new(1,-10,0.5,0),Size=UDim2.fromOffset(16,16)})
							new("UICorner",checkBox,{CornerRadius=UDim.new(0,3)})
							if isSel then new("TextLabel",checkBox,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,1,0),Text="✓",TextColor3=rgb(255,255,255),TextSize=10,Font=Enum.Font.GothamBold}) end
						end
						local btn2=new("TextButton",Item,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,1,0),Text=""})
						btn2.MouseEnter:Connect(function() if not isSel then tw(Item,0.1,{BackgroundColor3=rgb(35,35,42)}) end end)
						btn2.MouseLeave:Connect(function() if not isSel then tw(Item,0.1,{BackgroundColor3=rgb(28,28,34)}) end end)
						btn2.MouseButton1Click:Connect(function()
							if isMultiMode then
								if table.find(currentVal,iName) then for i2,v2 in ipairs(currentVal) do if v2==iName then table.remove(currentVal,i2); break end end
								else table.insert(currentVal,iName) end
								proxy.Value=currentVal; updatePillText(); buildItems2(searchText)
							else currentVal=iName; proxy.Value=currentVal; updatePillText(); buildItems2(searchText); closePicker2() end
						end)
					end
				end
				if not hasItems then order+=1; calcH=calcH+60; new("TextLabel",listScroll2,{BackgroundTransparency=1,LayoutOrder=order,Size=UDim2.new(1,0,0,60),Font=Enum.Font.Gotham,Text="No results found",TextColor3=rgb(80,80,95),TextSize=12}) end
				currentPopupH=math.clamp(calcH,SEARCH_H+50,POP_MAX_H)
				if isOpen2 and popup2 and popup2.Parent then local _,_,npw,nph=calcPopupPosition2(); popup2.Size=UDim2.fromOffset(npw,nph) end
			end
			local function buildPopup2()
				if popup2 then return end
				popup2=new("Frame",sg,{BackgroundColor3=rgb(22,22,26),BackgroundTransparency=0,BorderSizePixel=0,ClipsDescendants=true,Size=UDim2.fromOffset(POP_WIDTH2,0),Visible=false,ZIndex=200})
				new("UICorner",popup2,{CornerRadius=UDim.new(0,8)}); new("UIStroke",popup2,{Color=rgb(45,45,55),Thickness=1,Transparency=0.3})
				local searchFrame=new("Frame",popup2,{BackgroundColor3=rgb(18,18,22),BorderSizePixel=0,Size=UDim2.new(1,0,0,SEARCH_H),ZIndex=202}); new("UICorner",searchFrame,{CornerRadius=UDim.new(0,8)})
				new("ImageLabel",searchFrame,{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,12,0.5,0),BackgroundTransparency=1,Size=UDim2.fromOffset(20,SEARCH_H),Image=originalCfg.Img or "http://www.roblox.com/asset/?id=6473251976",ScaleType=Enum.ScaleType.Fit,ImageColor3=rgb(255,255,255)})
				searchBox2=new("TextBox",searchFrame,{AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,Position=UDim2.new(0,36,0.5,0),Size=UDim2.new(1,-48,0,SEARCH_H-8),ZIndex=203,Font=Enum.Font.Gotham,PlaceholderText="Search",PlaceholderColor3=rgb(80,80,95),ClearTextOnFocus=false,Text="",TextColor3=rgb(190,190,200),TextSize=isMobile and 14 or 13,TextXAlignment=Enum.TextXAlignment.Left})
				searchBox2:GetPropertyChangedSignal("Text"):Connect(function() searchText=searchBox2.Text; buildItems2(searchText) end)
				new("Frame",popup2,{BackgroundColor3=rgb(40,40,50),BorderSizePixel=0,Position=UDim2.new(0,0,0,SEARCH_H),Size=UDim2.new(1,0,0,1),ZIndex=201})
				listScroll2=new("ScrollingFrame",popup2,{BackgroundTransparency=1,BorderSizePixel=0,ZIndex=201,Position=UDim2.new(0,0,0,SEARCH_H+1),Size=UDim2.new(1,0,1,-(SEARCH_H+1)),CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=isMobile and 3 or 4,ScrollBarImageColor3=rgb(60,60,70),ScrollBarImageTransparency=0.5})
				new("UIListLayout",listScroll2,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2)}); new("UIPadding",listScroll2,{PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6),PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)})
			end
			local function openPicker2()
				if activePickerCloser and activePickerCloser~=closePicker2 then activePickerCloser(true) end
				activePickerCloser=closePicker2
				buildPopup2(); searchBox2.Text=""; searchText=""; buildItems2("")
				local x,y,pw,ph=calcPopupPosition2()
				popup2.Position=UDim2.fromOffset(x,y); popup2.Size=UDim2.fromOffset(pw,SEARCH_H)
				popup2.BackgroundTransparency=0; popup2.ClipsDescendants=true; popup2.Visible=true
				isOpen2=true; setChevron2(true)
				TweenService:Create(popup2,TweenInfo.new(0.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(pw,ph)}):Play()
				trackConn2=pill:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
					if not popup2 or not popup2.Parent then return end
					local nx,ny,npw,nph=calcPopupPosition2(); popup2.Position=UDim2.fromOffset(nx,ny); popup2.Size=UDim2.fromOffset(npw,nph)
				end)
				guiConn3=UIS.InputBegan:Connect(function(inp)
					if not isOpen2 or not popup2 or not popup2.Parent then return end
					if inp.UserInputType~=Enum.UserInputType.MouseButton1 and inp.UserInputType~=Enum.UserInputType.Touch then return end
					if searchBox2 and searchBox2:IsFocused() then return end
					local pos=inp.Position
					local pPos=pill.AbsolutePosition; local pSize=pill.AbsoluteSize
					if pos.X>=pPos.X and pos.X<=pPos.X+pSize.X and pos.Y>=pPos.Y and pos.Y<=pPos.Y+pSize.Y then return end
					local popPos=popup2.AbsolutePosition; local popSize=popup2.AbsoluteSize
					if pos.X>=popPos.X and pos.X<=popPos.X+popSize.X and pos.Y>=popPos.Y and pos.Y<=popPos.Y+popSize.Y then return end
					closePicker2()
				end)
			end
			local pillBtn=new("TextButton",pill,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,1,0),Text=""})
			pillBtn.MouseButton1Click:Connect(function() if isOpen2 then closePicker2() else openPicker2() end end)
			slot.AncestryChanged:Connect(function() if not slot.Parent then closePicker2(true); if popup2 and popup2.Parent then popup2:Destroy(); popup2=nil end end end)
			setmetatable(proxy, {
				__index = originalCfg,
				__newindex = function(t, k, v)
					rawset(originalCfg, k, v)
					if k == "Value" then
						if isMultiMode then
							currentVal={}
							if type(v)=="table" then for _,sv in pairs(v) do table.insert(currentVal,sv) end
							elseif type(v)=="string" and v~="" then table.insert(currentVal,v) end
						else currentVal=v or "" end
						updatePillText()
						if originalCfg.Script then originalCfg.Script(v) end
					end
				end
			})

			-- ── SaveLoad ─────────────────────────
		elseif originalCfg.name == "SaveLoad" then
			mainBtn:Destroy()
			local btnData = {
				{ label=originalCfg.LabelSave   or "Save",   color=rgb(40,80,50),  icon="💾" },
				{ label=originalCfg.LabelLoad   or "Load",   color=rgb(40,50,90),  icon="📂" },
				{ label=originalCfg.LabelDelete or "Delete", color=rgb(90,35,35),  icon="🗑" },
			}
			local btns={}; local btnGap=isMobile and 4 or 6; local btnW2=isMobile and 62 or 70
			local spinnerFrame=new("Frame",slot,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=rgb(35,35,42),BackgroundTransparency=0.5,BorderSizePixel=0,Position=UDim2.new(0.65,0,0.5,0),Size=UDim2.fromOffset(36,36),Visible=false,ZIndex=5})
			new("UICorner",spinnerFrame,{CornerRadius=UDim.new(1,0)})
			local spinner=new("ImageLabel",spinnerFrame,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.fromOffset(20,20),Image="rbxassetid://4915384834",ImageColor3=D.accent,ZIndex=6})
			local spinnerTween
			local function showSpinner() spinnerFrame.Visible=true; spinnerTween=TweenService:Create(spinner,TweenInfo.new(1,Enum.EasingStyle.Linear,Enum.EasingDirection.In,-1),{Rotation=360}); spinnerTween:Play() end
			local function hideSpinner() spinnerFrame.Visible=false; if spinnerTween then spinnerTween:Cancel(); spinnerTween=nil end; spinner.Rotation=0 end
			local startX2=-D.marginR
			for i,d in ipairs(btnData) do
				local pill2=new("Frame",slot,{AnchorPoint=Vector2.new(1,0.5),BackgroundColor3=d.color,BorderSizePixel=0,Position=UDim2.new(1,startX2-(i-1)*(btnW2+btnGap),0.5,0),Size=UDim2.fromOffset(btnW2,D.pillH),ZIndex=3})
				new("UICorner",pill2,{CornerRadius=UDim.new(0,6)}); new("UIStroke",pill2,{Color=rgb(55,55,65),Thickness=1,Transparency=0.3})
				new("TextLabel",pill2,{AnchorPoint=Vector2.new(0.5,0.25),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.28,0),Size=UDim2.new(1,0,0,14),Font=Enum.Font.Gotham,Text=d.icon,TextColor3=rgb(200,200,210),TextSize=isMobile and 12 or 11,ZIndex=4})
				new("TextLabel",pill2,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.68,0),Size=UDim2.new(0.9,0,0,12),Font=Enum.Font.GothamMedium,Text=d.label,TextColor3=rgb(180,180,195),TextSize=isMobile and 11 or 10,ZIndex=4})
				local btn=new("TextButton",pill2,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,1,0),Text="",ZIndex=5})
				btn.MouseEnter:Connect(function() tw(pill2,0.15,{BackgroundColor3=Color3.fromRGB(math.min(255,d.color.R*255*1.2),math.min(255,d.color.G*255*1.2),math.min(255,d.color.B*255*1.2))}) end)
				btn.MouseLeave:Connect(function() tw(pill2,0.15,{BackgroundColor3=d.color}) end)
				btns[d.label]=btn
			end
			local saveLabel=originalCfg.LabelSave or "Save"; local loadLabel=originalCfg.LabelLoad or "Load"; local deleteLabel=originalCfg.LabelDelete or "Delete"
			local slotName=slot.Name
			local function clickAction(action) if originalCfg.Script then task.delay(0.5,function() hideSpinner(); originalCfg.Script(action,slotName,nil) end) end end
			btns[saveLabel].MouseButton1Click:Connect(function() ripple(btns[saveLabel]); clickAction("Save") end)
			btns[loadLabel].MouseButton1Click:Connect(function() ripple(btns[loadLabel]); clickAction("Load") end)
			btns[deleteLabel].MouseButton1Click:Connect(function() ripple(btns[deleteLabel]); clickAction("Delete") end)
			setmetatable(proxy, { __index = originalCfg })

			-- ── Keybind ──────────────────────────
		elseif originalCfg.name == "Keybind" then
			local selVal=(type(originalCfg.Value)=="table" and originalCfg.Value[1]) or tostring(originalCfg.Value) or originalCfg.Config_Value[1] or ""
			local pillW=D.inputW
			local pill3=createRightControl(slot,pillW,D.pillH)
			local pillLbl=new("TextLabel",pill3,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0.85,0,0.7,0),Font=Enum.Font.Gotham,Text=selVal,TextColor3=D.pillText,TextSize=D.fontValue,TextXAlignment=Enum.TextXAlignment.Center})
			new("TextLabel",pill3,{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(0.95,0,0.5,0),Size=UDim2.new(0.15,0,0.5,0),BackgroundTransparency=1,Text="∨",TextColor3=D.pillMuted,TextSize=D.fontSmall})
			local dropdownOpen2=false; local dropdown2=nil; local dropdownConn2=nil; local currentDropdownH2=50
			local ITEM_H3=isMobile and 34 or 30; local POP_WIDTH3=pillW+10
			local function closeDropdown2(instant)
				dropdownOpen2=false
				if dropdownConn2 then dropdownConn2:Disconnect(); dropdownConn2=nil end
				if not dropdown2 then return end
				if instant then if dropdown2.Parent then dropdown2:Destroy() end; dropdown2=nil
				else
					local curX=dropdown2.Position.X.Offset; local curY=dropdown2.Position.Y.Offset
					dropdown2.ClipsDescendants=true
					TweenService:Create(dropdown2,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.fromOffset(curX,curY-currentDropdownH2-20),BackgroundTransparency=1}):Play()
					task.delay(0.17,function() if dropdown2 and dropdown2.Parent then dropdown2:Destroy(); dropdown2=nil end end)
				end
			end
			local function buildDropdown2()
				if dropdown2 then dropdown2:Destroy() end
				dropdown2=new("Frame",window,{BackgroundColor3=rgb(22,22,26),BorderSizePixel=0,ClipsDescendants=true,Visible=false,ZIndex=50})
				new("UICorner",dropdown2,{CornerRadius=UDim.new(0,8)}); new("UIStroke",dropdown2,{Color=rgb(55,55,65),Thickness=1})
				local listFrame=new("ScrollingFrame",dropdown2,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=isMobile and 3 or 4,ScrollBarImageColor3=rgb(60,60,70)})
				new("UIListLayout",listFrame,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2)}); new("UIPadding",listFrame,{PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6),PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6)})
				local calcH=12
				for i,val in ipairs(originalCfg.Config_Value) do
					calcH=calcH+ITEM_H3+2
					local isSelected=(tostring(val)==selVal)
					local itemFrame=new("Frame",listFrame,{BackgroundColor3=isSelected and rgb(40,40,50) or rgb(30,30,38),BorderSizePixel=0,Size=UDim2.new(1,0,0,ITEM_H3)})
					new("UICorner",itemFrame,{CornerRadius=UDim.new(0,6)})
					if isSelected then new("Frame",itemFrame,{AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=D.accent,BorderSizePixel=0,Position=UDim2.new(0,0,0.5,0),Size=UDim2.new(0,3,0,ITEM_H3*0.5)}) end
					new("TextLabel",itemFrame,{AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,Position=UDim2.new(0,isSelected and 12 or 10,0.5,0),Size=UDim2.new(1,-20,0,ITEM_H3-4),Font=isSelected and Enum.Font.GothamMedium or Enum.Font.Gotham,Text=tostring(val),TextColor3=isSelected and rgb(220,220,230) or rgb(180,180,195),TextSize=isMobile and 13 or 12,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
					local itemBtn=new("TextButton",itemFrame,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,Text="",ZIndex=2})
					itemBtn.MouseEnter:Connect(function() if not isSelected then tw(itemFrame,0.1,{BackgroundColor3=rgb(40,40,50)}) end end)
					itemBtn.MouseLeave:Connect(function() if not isSelected then tw(itemFrame,0.1,{BackgroundColor3=rgb(30,30,38)}) end end)
					itemBtn.MouseButton1Click:Connect(function()
						selVal=tostring(val); pillLbl.Text=selVal; proxy.Value={selVal}
						if originalCfg.Script then originalCfg.Script(proxy.Value) end
						closeDropdown2(); ripple(itemBtn)
					end)
				end
				currentDropdownH2=math.clamp(calcH,30,300); dropdown2.Size=UDim2.fromOffset(POP_WIDTH3,currentDropdownH2)
			end
			local function calcDropdownPos2()
				local sc=uiScale.Scale; local winAbs=window.AbsolutePosition
				local pillAbs=pill3.AbsolutePosition; local pillSz=pill3.AbsoluteSize
				local relX=pillAbs.X-winAbs.X; local relY=pillAbs.Y+pillSz.Y-winAbs.Y
				local x=relX/sc-4; local y=relY/sc
				if x+POP_WIDTH3>WIN.w-10 then x=WIN.w-POP_WIDTH3-10 end
				local _,rh=getRefSize()
				if y+currentDropdownH2>rh-10 then local relPillTop=pillAbs.Y-winAbs.Y; y=relPillTop/sc-currentDropdownH2-4 end
				return x,y
			end
			local function openDropdown2()
				if dropdownOpen2 then closeDropdown2(); return end
				buildDropdown2()
				local x,y=calcDropdownPos2()
				dropdown2.Position=UDim2.fromOffset(x,y-currentDropdownH2-20); dropdown2.BackgroundTransparency=0; dropdown2.ClipsDescendants=true; dropdown2.Visible=true; dropdownOpen2=true
				TweenService:Create(dropdown2,TweenInfo.new(0.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(x,y)}):Play()
				dropdownConn2=UIS.InputBegan:Connect(function(inp)
					if not dropdownOpen2 or not dropdown2 or not dropdown2.Parent then return end
					if not isTouchOrMouse(inp) then return end
					local pos=inp.Position
					local bPos=pill3.AbsolutePosition; local bSz=pill3.AbsoluteSize
					if pos.X>=bPos.X and pos.X<=bPos.X+bSz.X and pos.Y>=bPos.Y and pos.Y<=bPos.Y+bSz.Y then return end
					local dPos=dropdown2.AbsolutePosition; local dSz=dropdown2.AbsoluteSize
					if pos.X>=dPos.X and pos.X<=dPos.X+dSz.X and pos.Y>=dPos.Y and pos.Y<=dPos.Y+dSz.Y then return end
					closeDropdown2()
				end)
			end
			local clickBtn=new("TextButton",pill3,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(1,0,1,0),Text=""})
			clickBtn.MouseButton1Click:Connect(function() if dropdownOpen2 then closeDropdown2() else openDropdown2() end; ripple(clickBtn) end)
			setmetatable(proxy, {
				__index = originalCfg,
				__newindex = function(t, k, v)
					rawset(originalCfg, k, v)
					if k == "Value" then
						local newVal=type(v)=="table" and v[1] or tostring(v)
						if selVal~=newVal then selVal=newVal; if not dropdownOpen2 then pillLbl.Text=selVal end end
					end
				end
			})

		else
			setmetatable(proxy, { __index = originalCfg })
		end

		if pageSlots[scroll] then table.insert(pageSlots[scroll], slot) end

		-- ✅ register ทุก item ที่ผ่านมาถึงบรรทัดนี้
		_items[originalCfg.key or itemName] = proxy

		return container, slot
	end

	-- ─────────────────────────────────────────
	-- Public API
	-- ─────────────────────────────────────────
	function self:SetPageTitle(text) pageTitle.Text = text end

	-- ✅ GetItem — คืน proxy ที่ผูกกับ UI แล้ว
	function self:GetItem(key)
		return _items[key]
	end

	function self:AddNavItem(item)
		navCount = navCount + 1
		local TAB_H = isMobile and 40 or 36
		local sel = item.selected or false
		local row = new("Frame", navList, { LayoutOrder=navCount, Size=UDim2.new(1,0,0,TAB_H), BackgroundColor3=rgb(255,255,255), BackgroundTransparency=sel and 0.88 or 1, BorderSizePixel=0 })
		new("UICorner", row, { CornerRadius=UDim.new(0,6) })
		if sel then local bar=new("Frame",row,{Size=UDim2.fromOffset(3,16),Position=UDim2.new(0,0,0.5,-8),BackgroundColor3=C.SEL_BAR,BorderSizePixel=0}); new("UICorner",bar,{CornerRadius=UDim.new(1,0)}) end
		new("TextLabel",row,{Size=UDim2.fromOffset(22,TAB_H),Position=UDim2.fromOffset(12,0),BackgroundTransparency=1,Text=item.icon or "□",TextColor3=sel and C.TEXT or C.ICON,Font=Enum.Font.Gotham,TextSize=isMobile and 14 or 13})
		local lbl=new("TextLabel",row,{Size=UDim2.new(1,-40,1,0),Position=UDim2.fromOffset(40,0),BackgroundTransparency=1,Text=item.label or "",TextColor3=sel and C.TEXT or C.ICON,Font=sel and Enum.Font.GothamBold or Enum.Font.Gotham,TextSize=isMobile and 14 or 13,TextXAlignment=Enum.TextXAlignment.Left})
		if not sel then
			local hb=new("TextButton",row,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,Text="",AutoButtonColor=false})
			hb.MouseEnter:Connect(function() row.BackgroundColor3=C.HOVER; tw(row,0.12,{BackgroundTransparency=0.92}); tw(lbl,0.12,{TextColor3=C.TEXT}) end)
			hb.MouseLeave:Connect(function() tw(row,0.12,{BackgroundTransparency=1}); tw(lbl,0.12,{TextColor3=C.ICON}) end)
			if item.onClick then hb.MouseButton1Click:Connect(item.onClick) end
		end
		return row
	end

	function self:AddCard(info)
		contentOrder=contentOrder+1; info=info or {}
		local card=new("Frame",content,{LayoutOrder=contentOrder,Size=UDim2.new(1,0,0,130),BackgroundColor3=C.SURFACE,BorderSizePixel=0})
		new("UICorner",card,{CornerRadius=UDim.new(0,8)}); new("UIStroke",card,{Color=C.BORDER2,Thickness=1})
		local globe=new("Frame",card,{Size=UDim2.fromOffset(56,56),Position=UDim2.fromOffset(20,37),BackgroundColor3=C.SURFACE2,BorderSizePixel=0})
		new("UICorner",globe,{CornerRadius=UDim.new(1,0)}); new("UIStroke",globe,{Color=C.BORDER2,Thickness=1})
		new("TextLabel",globe,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="🌐",TextSize=24,Font=Enum.Font.Gotham})
		new("TextLabel",card,{Size=UDim2.new(1,-100,0,24),Position=UDim2.fromOffset(92,14),BackgroundTransparency=1,Text=info.company or "Company",TextColor3=C.TEXT,Font=Enum.Font.GothamBold,TextSize=16,TextXAlignment=Enum.TextXAlignment.Left})
		local fields={{x=92,y=42,label="Status",val=info.status or ""},{x=310,y=42,label="Ship to",val=info.shipTo or ""},{x=92,y=86,label="Order date",val=info.orderDate or ""},{x=310,y=86,label="Order total",val=info.orderTotal or ""}}
		for _,f in ipairs(fields) do
			new("TextLabel",card,{Size=UDim2.fromOffset(200,14),Position=UDim2.fromOffset(f.x,f.y),BackgroundTransparency=1,Text=f.label,TextColor3=C.TEXT2,Font=Enum.Font.GothamBold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left})
			new("TextLabel",card,{Size=UDim2.fromOffset(290,16),Position=UDim2.fromOffset(f.x,f.y+15),BackgroundTransparency=1,Text=f.val,TextColor3=C.TEXT,Font=Enum.Font.Gotham,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left})
		end
		return card
	end

	function self:AddNote(noteTitle, noteText)
		contentOrder=contentOrder+1
		local nf=new("Frame",content,{LayoutOrder=contentOrder,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,BorderSizePixel=0})
		new("UIListLayout",nf,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})
		new("TextLabel",nf,{LayoutOrder=1,Size=UDim2.new(1,0,0,24),BackgroundTransparency=1,Text=noteTitle or "",TextColor3=C.TEXT,Font=Enum.Font.GothamBold,TextSize=15,TextXAlignment=Enum.TextXAlignment.Left})
		new("Frame",nf,{LayoutOrder=2,Size=UDim2.new(1,0,0,1),BackgroundColor3=C.DIVIDER,BorderSizePixel=0})
		new("TextLabel",nf,{LayoutOrder=3,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Text=noteText or "",TextColor3=C.TEXT2,Font=Enum.Font.Gotham,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,LineHeight=1.5})
		return nf
	end

	function self:AddDivider()
		contentOrder=contentOrder+1
		return new("Frame",content,{LayoutOrder=contentOrder,Size=UDim2.new(1,0,0,1),BackgroundColor3=C.DIVIDER,BorderSizePixel=0})
	end

	function self:AddCustom(guiObj)
		contentOrder=contentOrder+1; guiObj.LayoutOrder=contentOrder; guiObj.Parent=content; return guiObj
	end

	function self:AddItem(cfg, targetPage)
		local page=targetPage or defaultPage
		local itemKey=cfg.key or cfg.name or ("Item"..tostring(contentOrder))
		contentOrder=contentOrder+1
		return createItem(page,contentOrder,itemKey,cfg)
	end

	function self:LoadConfig(configTable)
		local result={}; local firstTab=nil
		for _,slot2 in ipairs(configTable.Slot or {}) do
			local tabName=slot2.name or "Tab"
			local page=createTabPage(tabName)
			createTabButton(tabName,slot2.Main and "⊞" or "☰",slot2.icon)
			result[tabName]={}
			if firstTab==nil then firstTab=tabName end
			local itemOrder=0
			for _,itemCfg in ipairs(slot2.Script or {}) do
				itemOrder=itemOrder+1
				local itemKey=itemCfg.key or itemCfg.name or ("Item"..itemOrder)
				createItem(page,itemOrder,itemKey,itemCfg)
				result[tabName][itemKey]=itemCfg
			end
		end
		if firstTab then switchTab(firstTab) end
		content.Visible=false
		return result
	end

	function self:Show()
		window.Visible=true
		local targetY=getOffScreenY()
		window.Position=UDim2.new(0.5,WIN.dx,0.5,targetY)
		tw(window,TweenInfo.new(0.4,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,WIN.dx,0.5,WIN.dy)})
	end
	function self:Hide()  window.Visible=false end
	function self:Destroy()
		scaleCon:Disconnect()
		for _,c in ipairs(_connections) do c:Disconnect() end
		cleanupGlobalConnections()
		sg:Destroy()
	end

	-- ── Drag & Resize ────────────────────────
	local EDGE = isMobile and 0 or 7
	local _drag = { active=false, mode=nil, startM=nil, snap=nil }

	local function detectEdge(mx,my)
		local wx,wy=winTopLeft(); local wr,wb=wx+WIN.w,wy+WIN.h
		if mx<wx or mx>wr or my<wy or my>wb then return nil end
		local L=mx<=wx+EDGE; local R=mx>=wr-EDGE; local T=my<=wy+EDGE; local B=my>=wb-EDGE
		if     T and L then return "nw" elseif T and R then return "ne"
		elseif B and L then return "sw" elseif B and R then return "se"
		elseif T then return "n" elseif B then return "s"
		elseif L then return "w" elseif R then return "e" end
		return nil
	end

	local function applyDelta(dx,dy)
		local s=_drag.snap; local mode=_drag.mode
		if mode=="move" then WIN.dx=s.dx+dx; WIN.dy=s.dy+dy
		elseif mode=="e" then local nw=math.max(MIN_W,s.w+dx); WIN.dx=s.dx+(nw-s.w)/2; WIN.w=nw
		elseif mode=="w" then local nw=math.max(MIN_W,s.w-dx); WIN.dx=s.dx-(nw-s.w)/2; WIN.w=nw
		elseif mode=="s" then local nh=math.max(MIN_H,s.h+dy); WIN.dy=s.dy+(nh-s.h)/2; WIN.h=nh
		elseif mode=="n" then local nh=math.max(MIN_H,s.h-dy); WIN.dy=s.dy-(nh-s.h)/2; WIN.h=nh
		elseif mode=="se" then local nw=math.max(MIN_W,s.w+dx); WIN.dx=s.dx+(nw-s.w)/2; WIN.w=nw; local nh=math.max(MIN_H,s.h+dy); WIN.dy=s.dy+(nh-s.h)/2; WIN.h=nh
		elseif mode=="sw" then local nw=math.max(MIN_W,s.w-dx); WIN.dx=s.dx-(nw-s.w)/2; WIN.w=nw; local nh=math.max(MIN_H,s.h+dy); WIN.dy=s.dy+(nh-s.h)/2; WIN.h=nh
		elseif mode=="ne" then local nw=math.max(MIN_W,s.w+dx); WIN.dx=s.dx+(nw-s.w)/2; WIN.w=nw; local nh=math.max(MIN_H,s.h-dy); WIN.dy=s.dy-(nh-s.h)/2; WIN.h=nh
		elseif mode=="nw" then local nw=math.max(MIN_W,s.w-dx); WIN.dx=s.dx-(nw-s.w)/2; WIN.w=nw; local nh=math.max(MIN_H,s.h-dy); WIN.dy=s.dy-(nh-s.h)/2; WIN.h=nh
		end
		applyWin()
	end

	titleBar.InputBegan:Connect(function(inp)
		if not isTouchOrMouse(inp) then return end
		local relX=inp.Position.X-titleBar.AbsolutePosition.X
		if relX>titleBar.AbsoluteSize.X-(ctrlW*3) then return end
		if isMobile and hamburgerBtn then
			local hx=hamburgerBtn.AbsolutePosition.X; local hw=hamburgerBtn.AbsoluteSize.X; local px=inp.Position.X
			if px>=hx and px<=hx+hw then return end
		end
		_drag.active=true; _drag.mode="move"
		_drag.startM=toRef(inp.Position)
		_drag.snap={dx=WIN.dx,dy=WIN.dy,w=WIN.w,h=WIN.h}
	end)

	if not isMobile then
		window.InputBegan:Connect(function(inp)
			if _drag.active then return end; if cornerResizing then return end
			if inp.UserInputType~=Enum.UserInputType.MouseButton1 then return end
			local m=toRef(inp.Position); local e=detectEdge(m.X,m.Y)
			if e then _drag.active=true; _drag.mode=e; _drag.startM=m; _drag.snap={dx=WIN.dx,dy=WIN.dy,w=WIN.w,h=WIN.h} end
		end)
	end

	trackConnection(UIS.InputBegan:Connect(function(key,x)
		if x then return end
		if _G.KeyClose and key.KeyCode.Name==_G.KeyClose and not UIS.TouchEnabled then
			if window.Visible then
				TweenService:Create(window,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(0.5,WIN.dx,0.5,getOffScreenY())}):Play()
				task.delay(0.32,function() window.Visible=false end)
			else self:Show() end
		end
	end))

	trackConnection(UIS.InputChanged:Connect(function(inp)
		if not _drag.active then return end; if not isMove(inp) then return end
		local m=toRef(inp.Position); local dx=m.X-_drag.startM.X; local dy=m.Y-_drag.startM.Y
		applyDelta(dx,dy)
	end))

	trackConnection(UIS.InputEnded:Connect(function(inp)
		if isTouchOrMouse(inp) then _drag.active=false; _drag.mode=nil end
	end))

	-- ── Window Open ──────────────────────────
	window.BackgroundTransparency=1
	window.Position=UDim2.new(0.5,WIN.dx,0.58,WIN.dy)
	tw(window,TweenInfo.new(0.38,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{BackgroundTransparency=.25,Position=UDim2.new(0.5,WIN.dx,0.5,WIN.dy)})

	-- ── Mobile FAB ───────────────────────────
	do-- ใหม่: เช็คแค่ TouchEnabled พอ
		local isMobile2 = game:GetService("UserInputService").TouchEnabled
		
		if isMobile2 then
			local BTN_W=44; local BTN_H=44; local DRAG_THRESHOLD=10
			local fabSg=new("ScreenGui",playerGui,{Name="BenTen_Mobile",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=999,IgnoreGuiInset=true})
			local floatBtn=new("Frame",fabSg,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=rgb(18,18,22),BorderSizePixel=0,Size=UDim2.fromOffset(BTN_W,BTN_H),ZIndex=300,ClipsDescendants=false})
			new("UICorner",floatBtn,{CornerRadius=UDim.new(0,8)})
			local borderHolder=new("Frame",fabSg,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(BTN_W+6,BTN_H+6),ZIndex=299,ClipsDescendants=false})
			sg.AncestryChanged:Connect(function() if not sg.Parent then if fabSg and fabSg.Parent then fabSg:Destroy() end end end)
			local barsHolder=new("Frame",floatBtn,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0.5,0,0.42,0),Size=UDim2.fromOffset(20,13),ZIndex=302})
			local function makeBar(yOff) local b=new("Frame",barsHolder,{AnchorPoint=Vector2.new(0.5,0),BackgroundColor3=rgb(175,175,200),BorderSizePixel=0,Position=UDim2.new(0.5,0,0,yOff),Size=UDim2.fromOffset(16,2)}); new("UICorner",b,{CornerRadius=UDim.new(1,0)}); return b end
			local bar1=makeBar(0); local bar2=makeBar(5.5); local bar3=makeBar(11)
			local nameLabel=new("TextLabel",floatBtn,{AnchorPoint=Vector2.new(0.5,1),BackgroundTransparency=1,Position=UDim2.new(0.5,0,1,-2),Size=UDim2.new(1,0,0,8),Font=Enum.Font.GothamBold,Text="BenTenHub",TextColor3=rgb(80,80,115),TextSize=6,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=302})
			local hitBox=new("TextButton",floatBtn,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.fromOffset(BTN_W,BTN_H),Text="",AutoButtonColor=false,ZIndex=310})
			local isVisible=true; local isDragging=false; local isInteracting=false
			local dragStartX,dragStartY=nil,nil; local curX,curY; local offsetX=0; local offsetY=0
			local function applyPos() floatBtn.Position=UDim2.fromOffset(curX,curY); borderHolder.Position=UDim2.fromOffset(curX,curY) end
			do local vp=camera.ViewportSize; curX=vp.X-BTN_W/2-10; curY=vp.Y*0.5 end
			applyPos()
			trackConnection(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				local vp=camera.ViewportSize
				curX=math.clamp(curX,BTN_W/2,vp.X-BTN_W/2); curY=math.clamp(curY,BTN_H/2,vp.Y-BTN_H/2); applyPos()
			end))
			local function setIcon(open)
				local ti=TweenInfo.new(0.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
				if open then
					tw(bar1,ti,{Rotation=45,Position=UDim2.new(0.5,-8,0,5.5)}); tw(bar2,ti,{BackgroundTransparency=1}); tw(bar3,ti,{Rotation=-45,Position=UDim2.new(0.5,-8,0,5.5)})
					tw(floatBtn,0.15,{BackgroundColor3=rgb(22,22,32)}); tw(nameLabel,0.15,{TextColor3=rgb(120,120,180)})
				else
					tw(bar1,ti,{Rotation=0,Position=UDim2.new(0.5,-8,0,0),Size=UDim2.fromOffset(16,2)}); tw(bar2,ti,{BackgroundTransparency=0}); tw(bar3,ti,{Rotation=0,Position=UDim2.new(0.5,-8,0,11),Size=UDim2.fromOffset(16,2)})
					tw(floatBtn,0.15,{BackgroundColor3=rgb(18,18,22)}); tw(nameLabel,0.15,{TextColor3=rgb(80,80,115)})
				end
			end
			setIcon(true)
			local function toggleWindow()
				if window.Visible then
					isVisible=false; setIcon(isVisible)
					TweenService:Create(window,TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(0.5,WIN.dx,0.5,getOffScreenY())}):Play()
					task.delay(0.3,function() window.Visible=false; applyWin() end)  -- ← ปัญหาอยู่ที่นี่
				else
					isVisible=true; setIcon(isVisible)
					window.Visible=true; window.Position=UDim2.new(0.5,WIN.dx,0.5,getOffScreenY())
					tw(window,TweenInfo.new(0.38,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,WIN.dx,0.5,WIN.dy)})
				end
			end
			hitBox.InputBegan:Connect(function(inp)
				if inp.UserInputType~=Enum.UserInputType.Touch and inp.UserInputType~=Enum.UserInputType.MouseButton1 then return end
				isInteracting=true; isDragging=false; dragStartX=inp.Position.X; dragStartY=inp.Position.Y
				offsetX=curX-inp.Position.X; offsetY=curY-inp.Position.Y
			end)
			trackGlobalConnection(UIS.InputChanged:Connect(function(inp)
				if not isInteracting then return end
				if inp.UserInputType~=Enum.UserInputType.Touch and inp.UserInputType~=Enum.UserInputType.MouseMovement then return end
				local dx=inp.Position.X-dragStartX; local dy=inp.Position.Y-dragStartY
				if not isDragging and (math.abs(dx)>DRAG_THRESHOLD or math.abs(dy)>DRAG_THRESHOLD) then isDragging=true end
				if isDragging then
					local vp=camera.ViewportSize
					curX=math.clamp(inp.Position.X+offsetX,BTN_W/2,vp.X-BTN_W/2)
					curY=math.clamp(inp.Position.Y+offsetY,BTN_H/2,vp.Y-BTN_H/2)
					applyPos()
				end
			end))
			trackGlobalConnection(UIS.InputEnded:Connect(function(inp)
				if not isInteracting then return end
				if inp.UserInputType~=Enum.UserInputType.Touch and inp.UserInputType~=Enum.UserInputType.MouseButton1 then return end
				local wasDragging=isDragging; isDragging=false; dragStartX=nil; dragStartY=nil; isInteracting=false
				if not wasDragging then
					toggleWindow()
					tw(floatBtn,0.07,{Size=UDim2.fromOffset(BTN_W-5,BTN_H-5)})
					task.delay(0.08,function() tw(floatBtn,0.15,{Size=UDim2.fromOffset(BTN_W,BTN_H)}) end)
				end
			end))
		end
	end
	
	return self
end

return Win11UIModule
