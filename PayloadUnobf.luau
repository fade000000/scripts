local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local SS = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local ITEM_GIVER_PLACE_ID = 6839171747
local itemGiverAllowed = game.PlaceId == ITEM_GIVER_PLACE_ID
local modifierAllowed = not itemGiverAllowed

local ITEMS = { "Skeleton Key", "Lighter", "Crucifix", "Lockpick" }

-- Raw URL of a text file holding one SHA-256 key hash per line (never the keys themselves).
local KEYS_URL = "https://raw.githubusercontent.com/fade000000/scripts/refs/heads/main/keys.txt"
-- Test key: 50A05-34K4L-4042L. Remove once KEYS_URL is live.
local TEST_HASHES = {}

local NORMAL_COLOR = Color3.fromRGB(255, 255, 255)
local DARK_COLOR = Color3.fromRGB(100, 100, 100)
local ACCENT_COLOR = Color3.fromRGB(92, 247, 255)

local FONT = Font.new(
	"rbxasset://fonts/families/TitilliumWeb.json",
	Enum.FontWeight.Heavy,
	Enum.FontStyle.Italic
)

local MENU_ORIGIN = UDim2.new(0.5, 0, 0, 0)
local MENU_HIDDEN = UDim2.new(0.5, 0, -1, -60)
local WINDOW_ORIGIN = UDim2.fromScale(0.5, 0.5)
local WINDOW_HIDDEN = UDim2.fromScale(0.5, -0.3)

local NOTIFY_POS = UDim2.new(0, -8, 0.105, 0)
local NOTIFY_HIDDEN = UDim2.new(0, -320, 0.105, 0)

local IN_INFO = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local OUT_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local FADE_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
local DRAG_INFO = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function create(className, parent, properties)
	local object = Instance.new(className)
	for property, value in pairs(properties) do
		object[property] = value
	end
	object.Parent = parent
	return object
end

local function addShadow(parent, name)
	pcall(create, "UIShadow", parent, {
		Name = name,
		Color = Color3.new(1, 1, 1),
		BlurRadius = UDim2.fromOffset(100, 100),
		Spread = UDim.new(0, 100),
		Transparency = 0.9,
	})
end

--==================================================
-- KEY HASHING
--==================================================

local K = {
	1116352408,1899447441,3049323471,3921009573,961987163,1508970993,2453635748,2870763221,
	3624381080,310598401,607225278,1426881987,1925078388,2162078206,2614888103,3248222580,
	3835390401,4022224774,264347078,604807628,770255983,1249150122,1555081692,1996064986,
	2554220882,2821834349,2952996808,3210313671,3336571891,3584528711,113926993,338241895,
	666307205,773529912,1294757372,1396182291,1695183700,1986661051,2177026350,2456956037,
	2730485921,2820302411,3259730800,3345764771,3516065817,3600352804,4094571909,275423344,
	430227734,506948616,659060556,883997877,958139571,1322822218,1537002063,1747873779,
	1955562222,2024104815,2227730452,2361852424,2428436474,2756734187,3204031479,3329325298,
}

local function sha256(message)
	local H = {
		1779033703, 3144134277, 1013904242, 2773480762,
		1359893119, 2600822924, 528734635, 1541459225,
	}

	local bits = #message * 8
	message = message .. "\128" .. string.rep("\0", (55 - #message) % 64) .. string.char(
		0, 0, 0, 0,
		math.floor(bits / 16777216) % 256,
		math.floor(bits / 65536) % 256,
		math.floor(bits / 256) % 256,
		bits % 256
	)

	for i = 1, #message, 64 do
		local w = {}
		for j = 1, 16 do
			local a, b, c, d = string.byte(message, i + (j - 1) * 4, i + j * 4 - 1)
			w[j] = ((a * 256 + b) * 256 + c) * 256 + d
		end

		for j = 17, 64 do
			local s0 = bit32.bxor(bit32.rrotate(w[j - 15], 7), bit32.rrotate(w[j - 15], 18), bit32.rshift(w[j - 15], 3))
			local s1 = bit32.bxor(bit32.rrotate(w[j - 2], 17), bit32.rrotate(w[j - 2], 19), bit32.rshift(w[j - 2], 10))
			w[j] = (w[j - 16] + s0 + w[j - 7] + s1) % 4294967296
		end

		local a, b, c, d, e, f, g, h = table.unpack(H)
		for j = 1, 64 do
			local s1 = bit32.bxor(bit32.rrotate(e, 6), bit32.rrotate(e, 11), bit32.rrotate(e, 25))
			local ch = bit32.bxor(bit32.band(e, f), bit32.band(bit32.bnot(e), g))
			local t1 = (h + s1 + ch + K[j] + w[j]) % 4294967296
			local s0 = bit32.bxor(bit32.rrotate(a, 2), bit32.rrotate(a, 13), bit32.rrotate(a, 22))
			local maj = bit32.bxor(bit32.band(a, b), bit32.band(a, c), bit32.band(b, c))
			local t2 = (s0 + maj) % 4294967296
			h, g, f, e, d, c, b, a = g, f, e, (d + t1) % 4294967296, c, b, a, (t1 + t2) % 4294967296
		end

		for j, v in ipairs({ a, b, c, d, e, f, g, h }) do
			H[j] = (H[j] + v) % 4294967296
		end
	end

	return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", table.unpack(H))
end

local function fetch(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" then
		return body
	end

	ok, body = pcall(function()
		return HttpService:GetAsync(url)
	end)
	return ok and body or nil
end

local function isValidKey(key)
	local hash = sha256(key)
	if TEST_HASHES[hash] then
		return true
	end

	local body = KEYS_URL ~= "" and fetch(KEYS_URL)
	return body and body:lower():find(hash, 1, true) ~= nil or false
end

--==================================================
-- SOUNDS
--==================================================

local function makeSound(name, id)
	return create("Sound", SS, {
		Name = name,
		SoundId = "rbxassetid://" .. id,
		Volume = 1,
	})
end

local insideSound = makeSound("NotificationIn", "17208209318")
local outsideSound = makeSound("NotificationOut", "17208214688")
local successSound = makeSound("FloorUnlockSuccess", "15675016548")
local failedSound = makeSound("FloorUnlockFailed", "96158989044754")

task.spawn(function()
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync({ insideSound, outsideSound, successSound, failedSound })
	end)
	if not ok then
		warn("[UI] Sound preload failed:", err)
	end
end)

-- Plays a throwaway clone so overlapping sounds never cut each other off.
local function playSound(template)
	if not template then
		return
	end

	local sound = template:Clone()
	sound.Parent = SS
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 10)
	sound:Play()
end

--==================================================
-- NOTIFICATIONS
--==================================================

local notificationGui = create("ScreenGui", playerGui, {
	Name = "FloorNotificationGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 10,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local notificationPanel = create("Frame", notificationGui, {
	Name = "Panel",
	BackgroundColor3 = Color3.fromRGB(22, 22, 22),
	BorderSizePixel = 0,
	Position = NOTIFY_HIDDEN,
	Size = UDim2.fromOffset(287, 78),
	ZIndex = 10,
})

create("UICorner", notificationPanel, { CornerRadius = UDim.new(0, 8) })

local notificationText = create("TextLabel", notificationPanel, {
	Name = "TextLabel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	FontFace = FONT,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -30, 1, -16),
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
	TextWrapped = false,
	ZIndex = 11,
})

create("UITextSizeConstraint", notificationText, { MinTextSize = 8, MaxTextSize = 60 })
addShadow(notificationText, "UIShadow")

local notificationQueue = {}
local notificationBusy = false

local function slideNotification(position, info)
	local tween = TS:Create(notificationPanel, info, { Position = position })
	tween:Play()
	tween.Completed:Wait()
end

local function notify(message, resultSound)
	table.insert(notificationQueue, { message = message, sound = resultSound })

	if notificationBusy then
		return
	end
	notificationBusy = true

	task.spawn(function()
		while #notificationQueue > 0 do
			local item = table.remove(notificationQueue, 1)
			notificationText.Text = item.message

			playSound(insideSound)
			slideNotification(NOTIFY_POS, IN_INFO)
			playSound(item.sound)

			task.wait(#notificationQueue > 0 and 0.9 or 1.8)

			playSound(outsideSound)
			slideNotification(NOTIFY_HIDDEN, OUT_INFO)
		end

		notificationBusy = false
	end)
end

--==================================================
-- MENU
--==================================================

local screenGui = create("ScreenGui", playerGui, {
	Name = "ScreenGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local slideOut = create("Frame", screenGui, {
	Name = "SlideOut",
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(16, 16, 16),
	BorderSizePixel = 0,
	Position = MENU_HIDDEN,
	Size = UDim2.fromOffset(526, 58),
})

create("UICorner", slideOut, {
	Name = "Cn2",
	TopLeftRadius = UDim.new(0, 0),
	TopRightRadius = UDim.new(0, 0),
	BottomLeftRadius = UDim.new(0, 10),
	BottomRightRadius = UDim.new(0, 10),
})

-- Returns a function that fades the highlight in (true) or out (false).
local function makeHighlight(parent, text)
	local frame = create("Frame", parent, {
		Name = "Highlight",
		BackgroundColor3 = Color3.fromRGB(255, 254, 235),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(-0.546, 0, 1.356, 0),
		Size = UDim2.fromOffset(100, 31),
		Visible = false,
	})

	create("UICorner", frame, { Name = "Cn", CornerRadius = UDim.new(0, 10) })

	local triangle = create("ImageLabel", frame, {
		Name = "Tri",
		BackgroundTransparency = 1,
		Image = "rbxassetid://282305485",
		ImageColor3 = Color3.fromRGB(255, 254, 235),
		ImageTransparency = 1,
		Position = UDim2.new(0.37, 0, -0.29, 0),
		Size = UDim2.fromOffset(26, 15),
	})

	local label = create("TextLabel", frame, {
		Name = "Name",
		BackgroundTransparency = 1,
		FontFace = FONT,
		Position = UDim2.new(0.01, 0, 0, 0),
		Size = UDim2.fromOffset(99, 31),
		Text = text,
		TextColor3 = Color3.fromRGB(34, 34, 34),
		TextScaled = true,
		TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local shown = false

	return function(show)
		shown = show
		local hidden = show and 0 or 1

		if show then
			frame.Visible = true
		else
			task.delay(FADE_INFO.Time, function()
				if not shown then
					frame.Visible = false
				end
			end)
		end

		TS:Create(frame, FADE_INFO, { BackgroundTransparency = hidden }):Play()
		TS:Create(triangle, FADE_INFO, { ImageTransparency = hidden }):Play()
		TS:Create(label, FADE_INFO, { TextTransparency = hidden }):Play()
	end
end

local function makeButton(name, image, position, allowed, label)
	local button = create("ImageButton", slideOut, {
		Name = name,
		AutoButtonColor = allowed,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = image,
		ImageColor3 = allowed and NORMAL_COLOR or DARK_COLOR,
		Position = position,
		Selectable = allowed,
		Size = UDim2.fromOffset(48, 48),
	})

	addShadow(button, "Sh")

	local fadeHighlight = makeHighlight(button, label)
	button.MouseEnter:Connect(function()
		fadeHighlight(true)
	end)
	button.MouseLeave:Connect(function()
		fadeHighlight(false)
	end)

	return button
end

local modifier = makeButton(
	"Modifier", "rbxassetid://125464028645163",
	UDim2.new(0.025, 0, 0.086, 0), modifierAllowed, "Free Mod"
)

local itemGiver = makeButton(
	"ItemGiver", "rbxassetid://128648080634932",
	UDim2.new(0.131, 0, 0.086, 0), itemGiverAllowed, "Item Give"
)

local unlocked = false
local menuOpen = false
local menuTween
local selectingItem = false
local givingItem = false

local function setItemSelection(active)
	selectingItem = active

	TS:Create(itemGiver, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
		ImageColor3 = (active or not itemGiverAllowed) and DARK_COLOR or NORMAL_COLOR,
	}):Play()
end

local function setMenu(open)
	menuOpen = open

	if not open and selectingItem then
		setItemSelection(false)
	end

	if menuTween then
		menuTween:Cancel()
	end

	menuTween = TS:Create(slideOut, open and IN_INFO or OUT_INFO, {
		Position = open and MENU_ORIGIN or MENU_HIDDEN,
	})
	menuTween:Play()

	playSound(open and insideSound or outsideSound)
end

--==================================================
-- MODIFIER
--==================================================

local function forceModdable()
	local ok, floors = pcall(function()
		return require(RS:WaitForChild("ModulesShared"):WaitForChild("AccessibleFloors"))
	end)

	if not ok or type(floors) ~= "table" then
		warn("[Modifier] Could not load AccessibleFloors:", floors)
		return false
	end

	for _, floor in pairs(floors) do
		if type(floor) == "table" then
			floor.Moddable = true
		end
	end

	return true
end

local modifierRetrying = false

modifier.Activated:Connect(function()
	if not modifierAllowed then
		notify("Modifier unavailable", failedSound)
		return
	end

	if forceModdable() then
		notify("Moddable", successSound)
	else
		notify("Failed", failedSound)
	end

	if modifierRetrying then
		return
	end
	modifierRetrying = true

	task.spawn(function()
		for _ = 1, 10 do
			task.wait(1)
			forceModdable()
		end
		modifierRetrying = false
	end)
end)

--==================================================
-- ITEM GIVER
--==================================================

-- Returns "ok", "notLoaded" or "failed".
local function giveItem(number)
	local rooms = workspace:FindFirstChild("CurrentRooms")
	local room = rooms and rooms:FindFirstChild("57")
	local shop = room and room:FindFirstChild("JeffShop_Hotel")
	if not shop then
		return "notLoaded"
	end

	local purchasable = shop:FindFirstChild("PurchasableItem" .. number)
	local event = purchasable and purchasable:FindFirstChild("PurchasedEvent")
	if not event or not event:IsA("BindableEvent") then
		warn("[ItemGiver] PurchasedEvent (BindableEvent) not found for item", number)
		return "failed"
	end

	local ok, err = pcall(function()
		event:Fire()
	end)
	if not ok then
		warn("[ItemGiver] Fire failed:", err)
	end

	return ok and "ok" or "failed"
end

itemGiver.Activated:Connect(function()
	if not itemGiverAllowed then
		notify("Unavailable here", failedSound)
		return
	end

	setItemSelection(not selectingItem)
	if selectingItem then
		notify("Choose item 1-4")
	end
end)

local function chooseItem(number)
	if not selectingItem or givingItem or not ITEMS[number] then
		return
	end

	setItemSelection(false)
	givingItem = true

	local result = giveItem(number)
	if result == "ok" then
		notify(ITEMS[number], successSound)
	elseif result == "notLoaded" then
		notify("57 isn't loaded", failedSound)
	else
		notify("Failed", failedSound)
	end

	givingItem = false
end

--==================================================
-- KEY WINDOW
--==================================================

local window = create("Frame", screenGui, {
	Name = "Window",
	Active = true,
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(16, 16, 16),
	BorderSizePixel = 0,
	Position = WINDOW_HIDDEN,
	Size = UDim2.fromOffset(309, 137),
})

create("UICorner", window, {
	Name = "CnTop",
	TopLeftRadius = UDim.new(0, 0),
	TopRightRadius = UDim.new(0, 0),
	BottomLeftRadius = UDim.new(0, 8),
	BottomRightRadius = UDim.new(0, 8),
})

local topBar = create("Frame", window, {
	Name = "TopBar",
	BackgroundColor3 = ACCENT_COLOR,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, -15),
	Size = UDim2.new(1, 0, 0, 15),
})

create("UICorner", topBar, {
	Name = "CnBottom",
	TopLeftRadius = UDim.new(0, 8),
	TopRightRadius = UDim.new(0, 8),
	BottomLeftRadius = UDim.new(0, 0),
	BottomRightRadius = UDim.new(0, 0),
})

create("TextLabel", topBar, {
	Name = "WindowTitle",
	BackgroundTransparency = 1,
	FontFace = FONT,
	Size = UDim2.fromOffset(34, 15),
	Text = "Key",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
})

create("TextLabel", window, {
	Name = "Description",
	BackgroundTransparency = 1,
	FontFace = FONT,
	Position = UDim2.new(0.026, 0, 0, 0),
	Size = UDim2.fromOffset(156, 25),
	Text = "Enter the key you have received:",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
	TextWrapped = true,
})

local keyBox = create("TextBox", window, {
	Name = "KeyBox",
	BackgroundColor3 = Color3.fromRGB(29, 29, 29),
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	FontFace = FONT,
	PlaceholderColor3 = Color3.fromRGB(128, 128, 128),
	PlaceholderText = "XXXXX-XXXXX-XXXXX",
	Position = UDim2.new(0.026, 0, 0.182, 0),
	Size = UDim2.fromOffset(200, 16),
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
})

create("UICorner", keyBox, { Name = "CnNormal", CornerRadius = UDim.new(0, 2) })

local validateButton = create("TextButton", window, {
	Name = "Validate",
	BackgroundColor3 = ACCENT_COLOR,
	BorderSizePixel = 0,
	FontFace = FONT,
	Position = UDim2.new(0.074, 0, 0.825, 0),
	Size = UDim2.fromOffset(261, 14),
	Text = "Validate",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 12,
})

create("UICorner", validateButton, { Name = "CnNormal", CornerRadius = UDim.new(0, 4) })

-- Dragging: the window eases toward the cursor and every descendant follows.
local dragging, dragStart, startPosition
local dragConnections = {}

local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

table.insert(dragConnections, topBar.InputBegan:Connect(function(input)
	if isPointer(input) then
		dragging = true
		dragStart = input.Position
		startPosition = window.Position
	end
end))

table.insert(dragConnections, UIS.InputChanged:Connect(function(input)
	if not dragging then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		TS:Create(window, DRAG_INFO, {
			Position = UDim2.new(
				startPosition.X.Scale, startPosition.X.Offset + delta.X,
				startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
			),
		}):Play()
	end
end))

table.insert(dragConnections, UIS.InputEnded:Connect(function(input)
	if isPointer(input) then
		dragging = false
	end
end))

local function unlock()
	unlocked = true
	dragging = false

	for _, connection in ipairs(dragConnections) do
		connection:Disconnect()
	end

	playSound(outsideSound)

	local tween = TS:Create(window, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Position = WINDOW_HIDDEN,
	})
	tween.Completed:Once(function()
		window:Destroy()
	end)
	tween:Play()

	notify("Activated", successSound)
end

local validating = false

local function validate()
	if validating or unlocked then
		return
	end
	validating = true
	validateButton.Text = "Checking..."

	local key = keyBox.Text:gsub("%s+", ""):upper()
	local valid = key ~= "" and isValidKey(key)

	validateButton.Text = "Validate"
	validating = false

	if valid then
		unlock()
	else
		notify(key == "" and "Enter a key" or "Invalid key", failedSound)
	end
end

validateButton.Activated:Connect(validate)
keyBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		validate()
	end
end)

playSound(insideSound)
TS:Create(window, TweenInfo.new(0.9, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
	Position = WINDOW_ORIGIN,
}):Play()

--==================================================
-- INPUT
--==================================================

local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
}

UIS.InputBegan:Connect(function(input, processed)
	if processed or not unlocked then
		return
	end

	if input.KeyCode == Enum.KeyCode.V then
		setMenu(not menuOpen)
	elseif selectingItem and NUMBER_KEYS[input.KeyCode] then
		chooseItem(NUMBER_KEYS[input.KeyCode])
	end
end)
