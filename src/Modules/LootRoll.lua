--[[
	Forevermore Classic UI - Loot Rolls

	The vanilla need / greed roll box (1.12 GroupLootFrame, kept as is in
	Classic Era's Classic\LootFrame.xml): the 243x84 dialog box (the gold
	one, with the gold dragon over the item slot, for a bind on pickup
	item), the item in the empty slot, its name on the merchant label plate,
	the dice (Need) and coin (Greed) buttons, the round close button in the
	top right corner as Pass and the timer as a skill bar under the slot.

	The boxes are Blizzard's (GroupLootFrame1-4, stacked by
	GroupLootContainer), and a roll is a click on Blizzard's own button:
	LootRollButtonTemplate's OnClick is RollOnLoot on the box's rollID, a
	Lua field this module only ever reads. So only widget calls are made,
	and a mistake here can at worst hide a box, never block a roll:

	  * the modern art (the loot toast background and border, the item's
	    border) is hidden; Blizzard never shows those again (the border's
	    colour is set with SetVertexColor on every roll, which would undo an
	    alpha 0),
	  * the classic art is drawn on a frame of the addon's one level under
	    the box, so Blizzard's item name (a region of the box) is drawn on
	    the label plate; it takes no mouse,
	  * Blizzard's buttons, icon, name and timer are moved to the classic
	    spots and the buttons get the classic files. They stay where they
	    are in the hierarchy: on WoW Forever the buttons live in
	    box.LootButtonContainer and click through GetParent():GetParent(),
	    on retail they are the box's own children. Blizzard's disabled look
	    (alpha 0.35, GetNormalTexture():SetDesaturated) works on the classic
	    files, and its "need roll" animation, anchored to the Need button,
	    follows it,
	  * the timer is raised one level over the box (Blizzard puts it one
	    under on every show) so that it draws over the classic art, with the
	    skill bar border on it.

	What each roll needs (the gold box, the levels) is set from an OnShow
	hook, after Blizzard's OnShow has filled the box. Everything is undone
	on disable, so this is a live option. Blizzard re-opens the rolls still
	pending after a reload (GroupLootContainer_RefreshRolls).
]]

local _, ns = ...
local T = ns.T

T.ROLL_SLOT        = "Interface\\Buttons\\UI-EmptySlot"
T.ROLL_NAME_FRAME  = "Interface\\MerchantFrame\\UI-Merchant-LabelSlots"
T.ROLL_DIALOG      = "Interface\\DialogFrame\\UI-DialogBox-"       -- + Background / Border / Corner
T.ROLL_DIALOG_GOLD = "Interface\\DialogFrame\\UI-DialogBox-Gold-"  -- + Background / Border / Corner / Dragon
T.ROLL_NEED        = "Interface\\Buttons\\UI-GroupLoot-Dice-"      -- + Up / Down / Highlight
T.ROLL_GREED       = "Interface\\Buttons\\UI-GroupLoot-Coin-"      -- + Up / Down / Highlight
T.ROLL_BAR_BORDER  = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"

local module = ns:RegisterModule({
	key = "lootroll",
	name = "Loot Rolls",
	tooltip = "Restores the vanilla need / greed roll box: the dialog box (gold for bind on pickup items) with the dice, coin and close buttons and the timer bar.",
	live = true,
})

local NUM_BOXES = 4

-- Classic Era's GroupLootFrameTemplate.
local WIDTH, HEIGHT = 243, 84
local SLOT_X, SLOT_Y, SLOT_SIZE = 3, -3, 64
local ICON_INSET = 15
local NAME_WIDTH, NAME_HEIGHT, NAME_X, NAME_Y = 90, 30, -5, 5
local NAME_FRAME_WIDTH, NAME_FRAME_HEIGHT, NAME_FRAME_X, NAME_FRAME_Y = 128, 64, -9, -10
local CORNER_SIZE, CORNER_X, CORNER_Y = 32, -6, -7
local PASS_X, PASS_Y = 5, 5          -- from the corner's top right
local BUTTON_SIZE = 32
local NEED_X, NEED_Y = -37, -14      -- from the box's top right
local GREED_X, GREED_Y = -2, 2       -- from the Need button's bottom
local TIMER_WIDTH, TIMER_HEIGHT, TIMER_X, TIMER_Y = 152, 10, 13, 10
local BAR_BORDER_WIDTH, BAR_BORDER_HEIGHT, BAR_BORDER_Y = 156, 20, 5
local DRAGON_SIZE, DRAGON_X, DRAGON_Y = 120, -30, 15
local BACKDROP_INSETS = { left = 11, right = 12, top = 12, bottom = 11 }

local enabled = false
local hooked = {}                                  -- box -> true
local art = setmetatable({}, { __mode = "k" })     -- box -> the classic art frame
local saved = setmetatable({}, { __mode = "k" })   -- region -> Blizzard's anchors, size, font, files
local boxSize = setmetatable({}, { __mode = "k" }) -- box -> Blizzard's width, height

local function Boxes()
	local boxes = {}
	for i = 1, NUM_BOXES do
		local box = _G["GroupLootFrame" .. i]
		if box then table.insert(boxes, box) end
	end
	return boxes
end

-- The buttons: on the box itself (retail) or in its LootButtonContainer (Forever).
local function Buttons(box)
	local holder = box.LootButtonContainer or box
	return holder.NeedButton, holder.GreedButton, holder.PassButton, holder.TransmogButton
end

---------------------------------------------------------------------------
-- Blizzard's look, recorded before the first change and put back on disable
---------------------------------------------------------------------------

local function Remember(region)
	if not region or saved[region] then return end
	local state = { width = region:GetWidth(), height = region:GetHeight(), points = {} }
	for i = 1, region:GetNumPoints() do
		state.points[i] = { region:GetPoint(i) }
	end
	if region.GetFontObject then state.font = region:GetFontObject() end
	if region.GetNormalTexture then
		state.files = {}
		for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
			local texture = region[getter](region)
			if texture then
				state.files[texture] = { atlas = texture:GetAtlas(), file = texture:GetTexture() }
			end
		end
	end
	saved[region] = state
end

local function Restore(region)
	local state = region and saved[region]
	if not state then return end
	region:ClearAllPoints()
	for _, point in ipairs(state.points) do
		region:SetPoint(unpack(point))
	end
	region:SetSize(state.width, state.height)
	if state.font then region:SetFontObject(state.font) end
	for texture, look in pairs(state.files or {}) do
		if look.atlas then
			texture:SetAtlas(look.atlas)
		elseif look.file then
			ns.SetTexture(texture, look.file)
		end
	end
	saved[region] = nil
end

---------------------------------------------------------------------------
-- The classic box
---------------------------------------------------------------------------

-- The button's three state files, if this client ships them.
local function SetButtonFiles(button, prefix, highlight)
	if not button or not ns.HasTexture(prefix .. "Up") then return end
	Remember(button)
	ns.SetTexture(button:GetNormalTexture(), prefix .. "Up")
	ns.SetTexture(button:GetPushedTexture(), prefix .. "Down")
	local glow = button:GetHighlightTexture()
	if glow then ns.SetTexture(glow, prefix .. highlight) end
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
end

local function CreateArt(box)
	local frame = CreateFrame("Frame", nil, box, "BackdropTemplate")
	frame:SetAllPoints(box)

	frame.slot = frame:CreateTexture(nil, "ARTWORK")
	frame.slot:SetTexture(T.ROLL_SLOT)
	frame.slot:SetSize(SLOT_SIZE, SLOT_SIZE)
	frame.slot:SetPoint("TOPLEFT", frame, "TOPLEFT", SLOT_X, SLOT_Y)

	frame.nameFrame = frame:CreateTexture(nil, "ARTWORK")
	frame.nameFrame:SetTexture(T.ROLL_NAME_FRAME)
	frame.nameFrame:SetSize(NAME_FRAME_WIDTH, NAME_FRAME_HEIGHT)
	frame.nameFrame:SetPoint("LEFT", frame.slot, "RIGHT", NAME_FRAME_X, NAME_FRAME_Y)

	frame.corner = frame:CreateTexture(nil, "OVERLAY")
	frame.corner:SetSize(CORNER_SIZE, CORNER_SIZE)
	frame.corner:SetPoint("TOPRIGHT", frame, "TOPRIGHT", CORNER_X, CORNER_Y)

	frame.dragon = frame:CreateTexture(nil, "OVERLAY")
	frame.dragon:SetTexture(T.ROLL_DIALOG_GOLD .. "Dragon")
	frame.dragon:SetSize(DRAGON_SIZE, DRAGON_SIZE)
	frame.dragon:SetPoint("TOPLEFT", frame, "TOPLEFT", DRAGON_X, DRAGON_Y)
	frame.dragon:Hide()

	-- On the timer, over its fill (Blizzard's fill is on the ARTWORK layer).
	local timer = box.Timer
	if timer then
		frame.barBorder = timer:CreateTexture(nil, "OVERLAY")
		frame.barBorder:SetTexture(T.ROLL_BAR_BORDER)
		frame.barBorder:SetSize(BAR_BORDER_WIDTH, BAR_BORDER_HEIGHT)
		frame.barBorder:SetPoint("TOP", timer, "TOP", 0, BAR_BORDER_Y)
	end

	art[box] = frame
	return frame
end

-- The plain or the gold dialog box, as 1.12 picked it per roll.
local function SetGold(frame, gold)
	if frame.gold == gold then return end
	frame.gold = gold
	local prefix = gold and T.ROLL_DIALOG_GOLD or T.ROLL_DIALOG
	frame:SetBackdrop({
		bgFile = prefix .. "Background",
		edgeFile = prefix .. "Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = BACKDROP_INSETS,
	})
	frame.corner:SetTexture(prefix .. "Corner")
	frame.dragon:SetShown(gold)
end

-- Per roll, after Blizzard's OnShow: the box kind and the levels (the
-- art one under the box, the timer one over it).
local function UpdateBox(box)
	local frame = art[box]
	if not enabled or not frame then return end
	local bindOnPickUp = false
	if box.rollID then
		bindOnPickUp = select(5, GetLootRollItemInfo(box.rollID)) and true or false
	end
	SetGold(frame, bindOnPickUp and ns.HasTexture(T.ROLL_DIALOG_GOLD .. "Border"))
	local level = box:GetFrameLevel()
	frame:SetFrameLevel(math.max(0, level - 1))
	if box.Timer then box.Timer:SetFrameLevel(level + 1) end
end

local function SkinBox(box)
	local frame = art[box] or CreateArt(box)
	frame:Show()
	if frame.barBorder then frame.barBorder:Show() end

	-- Only its size: GroupLootContainer_Update places the box.
	if not boxSize[box] then boxSize[box] = { box:GetSize() } end
	box:SetSize(WIDTH, HEIGHT)
	if box.Background then box.Background:Hide() end
	if box.Border then box.Border:Hide() end

	local icon = box.IconFrame
	if icon then
		Remember(icon)
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", frame.slot, "TOPLEFT", ICON_INSET, -ICON_INSET)
		if icon.Border then icon.Border:Hide() end
	end

	local name = box.Name
	if name then
		Remember(name)
		name:SetFontObject(GameFontNormalSmall)
		name:SetJustifyH("LEFT")
		name:SetSize(NAME_WIDTH, NAME_HEIGHT)
		name:ClearAllPoints()
		name:SetPoint("LEFT", frame.slot, "RIGHT", NAME_X, NAME_Y)
	end

	local need, greed, pass, transmog = Buttons(box)
	if need then
		SetButtonFiles(need, T.ROLL_NEED, "Highlight")
		Remember(need)
		need:ClearAllPoints()
		need:SetPoint("TOPRIGHT", box, "TOPRIGHT", NEED_X, NEED_Y)
	end
	if greed and need then
		SetButtonFiles(greed, T.ROLL_GREED, "Highlight")
		Remember(greed)
		greed:ClearAllPoints()
		greed:SetPoint("TOP", need, "BOTTOM", GREED_X, GREED_Y)
	end
	-- The transmog button (no classic art) keeps its own, in the Greed
	-- button's place as Blizzard anchors it.
	if pass then
		SetButtonFiles(pass, T.PANEL_CLOSE, "Highlight")
		Remember(pass)
		pass:ClearAllPoints()
		pass:SetPoint("TOPRIGHT", frame.corner, "TOPRIGHT", PASS_X, PASS_Y)
	end
	if transmog then Remember(transmog) end

	local timer = box.Timer
	if timer then
		Remember(timer)
		timer:SetSize(TIMER_WIDTH, TIMER_HEIGHT)
		timer:ClearAllPoints()
		timer:SetPoint("TOPLEFT", frame.slot, "BOTTOMLEFT", TIMER_X, TIMER_Y)
	end

	frame.gold = nil
	UpdateBox(box)
end

local function UnskinBox(box)
	local frame = art[box]
	if not frame then return end
	frame:Hide()
	if frame.barBorder then frame.barBorder:Hide() end
	if box.Background then box.Background:Show() end
	if box.Border then box.Border:Show() end
	if box.IconFrame and box.IconFrame.Border then box.IconFrame.Border:Show() end
	if boxSize[box] then
		box:SetSize(unpack(boxSize[box]))
		boxSize[box] = nil
	end
	local need, greed, pass, transmog = Buttons(box)
	for _, region in ipairs({ box.IconFrame, box.Name, need, greed, pass, transmog, box.Timer }) do
		Restore(region)
	end
	if box.Name then box.Name:SetJustifyH("LEFT") end
	-- Where Blizzard puts it on every show.
	if box.Timer then box.Timer:SetFrameLevel(math.max(0, box:GetFrameLevel() - 1)) end
end

---------------------------------------------------------------------------
-- Module entry points
---------------------------------------------------------------------------

function module:Enable()
	local boxes = Boxes()
	if #boxes == 0 then return end
	enabled = true
	for _, box in ipairs(boxes) do
		if not hooked[box] then
			hooked[box] = true
			box:HookScript("OnShow", UpdateBox)
		end
		SkinBox(box)
	end
end

function module:Disable()
	enabled = false
	for _, box in ipairs(Boxes()) do
		UnskinBox(box)
	end
end
