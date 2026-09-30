--[[
	Forevermore Classic UI - Bank

	The bank is BankFrameTemplate on both flavors (Blizzard_UIPanels_Game:
	retail's Mainline\BankFrame.*, Forever's Camelot\BankFrame.* over the
	Mainline templates), a PortraitFrameTemplate window whose BankPanel
	draws the item slots from a pool every time it lays them out
	(GenerateItemSlotsForSelectedTab). Retail shows one bank tab of 98 slots
	at a time (seven rows, filled down its columns), with the bank / warband
	tabs under it; Forever lists every slot of the bank and its bags on 8
	columns, up to 88 a page, with the bank bag slots, their cost and the
	page tabs down its right side.

	This option draws the vanilla bank window (UI-BankFrame: the portrait
	ring, the title bar with its close box, the item slot wells on a metal
	lattice with rivets, the row of bag slot wells and the money bar) around
	Blizzard's slots. The art holds a fixed grid (seven columns and four
	rows in the client's file, the later redraw of vanilla's six), so it is
	cut through the middle of the lattice bars, which are exactly 49px apart
	across and 44px down like vanilla's slots, and the cells are repeated to
	the bank's columns and rows: each piece of the grid is a texture cut
	from the file, neighbouring pieces that are neighbours in the file drawn
	as one. Wells with no slot in them (the end of a partly filled last row)
	are covered with a patch of the art's stone. Without bag slots
	(retail) the bag row is cut out.

	Blizzard's window is sized to the art's border and the slots are moved
	onto the wells: each slot's column and row are worked out from the
	anchors Blizzard chained it with, so Blizzard's order, paging, search,
	sorting and depositing are kept. Forever's bag slots go into the bag
	wells under the vanilla "Bag Slots" label, a slot not bought yet shown as
	vanilla did (the empty bag slot tinted red); the cost and Purchase button
	sit in the stone under them, the money in the money bar, and the page
	tabs become the classic skill line tabs (SpellBook-SkillLineTab), as
	retail's bank tabs already are. Retail's bank / warband tabs become the
	vanilla bottom tabs and its Include Reagents box the classic check box.

	The bank holds no secure widgets, so it can be laid out in combat. No Lua
	field is written on Blizzard's frames: only widget API is used and
	Blizzard's methods are hooked. Blizzard's frames cannot be restored at
	runtime, so this needs a reload to switch off.
]]

local _, ns = ...
local T = ns.T

T.BANK_FRAME         = "Interface\\BankFrame\\UI-BankFrame"
T.EMPTY_BAG_SLOT     = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
T.SPELLBOOK_SKILLTAB = "Interface\\Spellbook\\SpellBook-SkillLineTab"
T.CHECKBOX           = "Interface\\Buttons\\UI-CheckBox-" -- + Up / Down / Highlight / Check / Check-Disabled

local module = ns:RegisterModule({
	key = "bank",
	name = "Bank",
	tooltip = "Restores the vanilla bank window: the stone panel with the slot wells on their riveted lattice, the portrait ring, the money bar and the classic tabs, and on WoW Forever the row of bag slots with their cost under it.",
	live = false,
})

---------------------------------------------------------------------------
-- The art (UI-BankFrame, 512x512; the window in its top-left 400x424)
---------------------------------------------------------------------------

local FILE_SIZE = 512

-- Pieces across: the left border with the first column (the portrait ring
-- over it), the inner columns (cut at the lattice bars' middles, 49px each;
-- used in turn) and the last column with the right border and close box.
-- The last well is a pixel further right in the file than a 49px grid puts
-- it, so the last piece starts a pixel after the inner ones end.
local ART_X = {
	first = { 0, 82 },
	inner = { { 82, 131 }, { 131, 180 }, { 180, 229 }, { 229, 278 }, { 278, 327 } },
	last = { 328, 400 },
}
-- Pieces down: the header with the first row, the inner rows (44px), the
-- last row with the lattice's bottom edge, the "Bag Slots" band and bag row,
-- and the stone with the money bar and bottom border.
local ART_Y = {
	first = { 0, 114 },
	inner = { { 114, 158 }, { 158, 202 } },
	last = { 202, 250 },
	bags = { 250, 322 },
	footer = { 322, 424 },
}
-- The frame border inside the art (the window's edges): 10px in on the
-- left, 13px down, 2px in on the right, 4px up at the bottom.
local BORDER_LEFT, BORDER_TOP, BORDER_RIGHT, BORDER_BOTTOM = 10, 13, 2, 4
-- Vanilla's slots (Classic Era's BankFrame.xml on the same art): the first
-- one 40px in and 73px down, 49 / 44px apart; the bag row 274px down.
local SLOT_X, SLOT_Y, PITCH_X, PITCH_Y = 40, 73, 49, 44
local SLOT_SIZE = 37
local CELL_X = SLOT_X - 7 -- a column's cell, from its bar's middle
local BAG_ROW_Y = 274 - ART_Y.bags[1] -- in the bag band
local BAG_LABEL_Y = 262 - ART_Y.bags[1] -- vanilla's "Bag Slots", centred
local ITEM_LABEL_Y = 62                 -- vanilla's "Item Slots", centred
-- In the footer: vanilla's purchase question and cost row, the money bar.
local PURCHASE_LABEL_Y, COST_Y, MONEY_Y = 341 - ART_Y.footer[1], 371 - ART_Y.footer[1], 401 - ART_Y.footer[1]
local COST_X, PURCHASE_RIGHT = 57, 43
local MONEY_RIGHT = 16
-- The header: the portrait in the ring, the title bar, the close box.
local PORTRAIT_X, PORTRAIT_Y, PORTRAIT_SIZE = 7, -6, 60
local TITLE_LEFT, TITLE_RIGHT, TITLE_Y = 68, 27, 24
local CLOSE_RIGHT, CLOSE_Y = 12, 24
-- Stone from the footer, over wells with no slot (a last-row cell and the
-- lattice edge under it).
local COVER = { 131, 180, 330, 378 }

-- Piece bounds for `count` cells: the first, the inner ones in turn, the
-- last, neighbours in the file merged into one piece.
local function Slices(spec, count, tail)
	local slices = { { spec.first[1], spec.first[2] } }
	local function Add(piece)
		local last = slices[#slices]
		if last[2] == piece[1] then
			last[2] = piece[2]
		else
			slices[#slices + 1] = { piece[1], piece[2] }
		end
	end
	for k = 1, count - 2 do
		Add(spec.inner[(k - 1) % #spec.inner + 1])
	end
	Add(spec.last)
	for _, piece in ipairs(tail or {}) do
		Add(piece)
	end
	return slices
end

local art = {} -- the frames and textures, made in Apply

local function Piece(index)
	local texture = art.pieces[index]
	if not texture then
		texture = BankFrame:CreateTexture(nil, "BACKGROUND", nil, 2)
		art.pieces[index] = texture
	end
	return texture
end

local function Cover(index)
	local texture = art.covers[index]
	if not texture then
		texture = BankFrame:CreateTexture(nil, "BACKGROUND", nil, 3)
		ns.SetTexture(texture, T.BANK_FRAME, COVER[1] / FILE_SIZE, COVER[2] / FILE_SIZE, COVER[3] / FILE_SIZE, COVER[4] / FILE_SIZE)
		texture:SetSize(COVER[2] - COVER[1], COVER[4] - COVER[3])
		art.covers[index] = texture
	end
	return texture
end

-- Blizzard sizes the window for its own layout (retail when a tab is
-- picked, Forever with every layout of the slots); it is put back to the
-- art's border after each.
local function FitFrame()
	local width, height = art.origin:GetSize()
	if width > 0 then
		BankFrame:SetSize(width - BORDER_LEFT - BORDER_RIGHT, height - BORDER_TOP - BORDER_BOTTOM)
	end
end

-- Draws the window for `columns` x `rows` wells (`missing`: the columns of
-- the last row without a slot), sizes Blizzard's frame to its border and
-- moves the parts that depend on its size.
local function DrawArt(columns, rows, missing)
	columns, rows = math.max(columns, 2), math.max(rows, 2)
	local key = columns .. "x" .. rows .. ":" .. table.concat(missing, ",")
	if art.key == key then
		FitFrame()
		return
	end
	art.key = key

	local xs = Slices(ART_X, columns)
	local ys = Slices(ART_Y, rows, art.bags and { ART_Y.bags, ART_Y.footer } or { ART_Y.footer })
	local index, y, width = 0, 0, 0
	for _, sliceY in ipairs(ys) do
		local x = 0
		for _, sliceX in ipairs(xs) do
			index = index + 1
			local texture = Piece(index)
			local w, h = sliceX[2] - sliceX[1], sliceY[2] - sliceY[1]
			ns.SetTexture(texture, T.BANK_FRAME, sliceX[1] / FILE_SIZE, sliceX[2] / FILE_SIZE, sliceY[1] / FILE_SIZE, sliceY[2] / FILE_SIZE)
			texture:ClearAllPoints()
			texture:SetSize(w, h)
			texture:SetPoint("TOPLEFT", art.origin, "TOPLEFT", x, -y)
			texture:Show()
			x = x + w
		end
		width = x
		y = y + sliceY[2] - sliceY[1]
	end
	for i = index + 1, #art.pieces do
		art.pieces[i]:Hide()
	end
	local height = y

	local lastRowTop = ART_Y.first[2] + (rows - 2) * PITCH_Y
	for i, column in ipairs(missing) do
		local texture = Cover(i)
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", art.origin, "TOPLEFT", CELL_X + column * PITCH_X, -lastRowTop)
		texture:Show()
	end
	for i = #missing + 1, #art.covers do
		art.covers[i]:Hide()
	end

	art.origin:SetSize(width, height)
	FitFrame()
	local itemsBottom = lastRowTop + ART_Y.last[2] - ART_Y.last[1]
	art.bagBand:SetPoint("TOPLEFT", art.origin, "TOPLEFT", 0, -itemsBottom)
	art.footer:SetPoint("TOPLEFT", art.origin, "TOPLEFT", 0, -(height - (ART_Y.footer[2] - ART_Y.footer[1])))
	art.bagBand:SetWidth(width)
	art.footer:SetWidth(width)
	art.width = width
	if art.OnResize then art.OnResize(width) end
end

---------------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------------

local skinned = setmetatable({}, { __mode = "k" })

-- The modern slot art is faded (Forever re-applies its NormalTexture atlas
-- on every refresh, which leaves the alpha alone); the slot gets
-- ItemButtonTemplate's UI-Quickslot2 (64:37) over the art's well.
local function SkinSlot(button)
	if skinned[button] then return end
	skinned[button] = true
	if button.Background then button.Background:SetAlpha(0) end
	local normal = button:GetNormalTexture()
	if normal then normal:SetAlpha(0) end
	local size = button:GetWidth() * 64 / 37
	local frame = button:CreateTexture(nil, "ARTWORK", nil, -1)
	frame:SetTexture(T.QUICKSLOT2)
	frame:SetSize(size, size)
	frame:SetPoint("CENTER", button, "CENTER", 0, -1)
end

-- Where a frame's top left sits relative to `root`'s, followed through the
-- anchors Blizzard gave it (each slot hangs off the one before it). Nil when
-- the chain leads anywhere else or has more than one point per frame.
local POINT_X = { TOPLEFT = 0, LEFT = 0, BOTTOMLEFT = 0, TOP = 0.5, CENTER = 0.5, BOTTOM = 0.5, TOPRIGHT = 1, RIGHT = 1, BOTTOMRIGHT = 1 }
local POINT_Y = { TOPLEFT = 0, TOP = 0, TOPRIGHT = 0, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, BOTTOMLEFT = 1, BOTTOM = 1, BOTTOMRIGHT = 1 }

local function Offset(frame, root, cache, depth)
	if frame == root then return 0, 0 end
	local known = cache[frame]
	if known then return known[1], known[2] end
	if depth > 256 or frame:GetNumPoints() ~= 1 then return nil end
	local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
	if not relativeTo or not POINT_X[point] or not POINT_X[relativePoint] then return nil end
	local relativeLeft, relativeTop = Offset(relativeTo, root, cache, depth + 1)
	if not relativeLeft then return nil end
	local relativeWidth, relativeHeight = relativeTo:GetSize()
	local width, height = frame:GetSize()
	local left = relativeLeft + POINT_X[relativePoint] * relativeWidth + x - POINT_X[point] * width
	local top = relativeTop - POINT_Y[relativePoint] * relativeHeight + y + POINT_Y[point] * height
	cache[frame] = { left, top }
	return left, top
end

-- The distinct values of `values`, each mapped to its 0-based rank in
-- sorted order; also their count.
local function Ranks(values, descending)
	local list, seen = {}, {}
	for _, value in pairs(values) do
		if not seen[value] then
			seen[value] = true
			table.insert(list, value)
		end
	end
	table.sort(list, descending and function(a, b) return a > b end or nil)
	local ranks = {}
	for i, value in ipairs(list) do ranks[value] = i - 1 end
	return ranks, #list
end

local widestRow = 0 -- a page of a single row keeps the window's width

-- After Blizzard's GenerateItemSlotsForSelectedTab: reads every slot's
-- column and row back from Blizzard's grid, draws the window for that grid
-- and moves each slot onto its well.
local function LayoutSlots(panel)
	local pool = panel.itemButtonPool
	if not pool then return end
	local buttons, lefts, tops, cache = {}, {}, {}, {}
	for button in pool:EnumerateActive() do
		local left, top = Offset(button, panel, cache, 0)
		if not left then return end -- an unknown layout: keep Blizzard's
		table.insert(buttons, button)
		lefts[button], tops[button] = math.floor(left + 0.5), math.floor(top + 0.5)
	end
	if #buttons == 0 then return end

	local columns, numColumns = Ranks(lefts)
	local rows, numRows = Ranks(tops, true)
	if numRows > 1 then
		widestRow = numColumns
	else
		numColumns = math.max(numColumns, widestRow)
	end
	numRows = math.max(numRows, 2)

	local lastRow = {}
	for _, button in ipairs(buttons) do
		local column, row = columns[lefts[button]], rows[tops[button]]
		if row == numRows - 1 then lastRow[column] = true end
		SkinSlot(button)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", art.origin, "TOPLEFT", SLOT_X + column * PITCH_X, -(SLOT_Y + row * PITCH_Y))
	end
	local missing = {}
	for column = 0, math.max(numColumns, 2) - 1 do
		if not lastRow[column] then table.insert(missing, column) end
	end
	DrawArt(numColumns, numRows, missing)
end

---------------------------------------------------------------------------
-- Forever's bank bags
---------------------------------------------------------------------------

local LOCKED_COLOR = { 1, 0.1, 0.1 } -- vanilla's tint of a bag slot not bought yet

local emptyBags = setmetatable({}, { __mode = "k" }) -- bag button -> empty bag slot texture

-- The empty bag slot under the button's icon (a bag's icon covers it), red
-- while the slot is not bought, in place of Blizzard's padlock.
local function SkinBagButton(button)
	local empty = emptyBags[button]
	if not empty then
		SkinSlot(button)
		if button.DisabledOverlay then button.DisabledOverlay:SetAlpha(0) end
		empty = button:CreateTexture(nil, "BACKGROUND", nil, 1)
		empty:SetTexture(T.EMPTY_BAG_SLOT)
		empty:SetAllPoints(button)
		emptyBags[button] = empty
	end
	if button.DisabledOverlay and button.DisabledOverlay:IsShown() then
		empty:SetVertexColor(LOCKED_COLOR[1], LOCKED_COLOR[2], LOCKED_COLOR[3])
	else
		empty:SetVertexColor(1, 1, 1)
	end
end

-- After Blizzard's RefreshBagButtons, which lines the bag slots up at 3/4
-- size beside the label: full size, in bag order, in the bag row's wells.
local function LayoutBagButtons(frame)
	local buttons = {}
	for button in frame.itemButtonBagPool:EnumerateActive() do
		table.insert(buttons, button)
	end
	table.sort(buttons, function(a, b) return (a.bagSlotID or 0) < (b.bagSlotID or 0) end)
	for i, button in ipairs(buttons) do
		button:SetScale(1)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", art.bagBand, "TOPLEFT", SLOT_X + (i - 1) * PITCH_X, -BAG_ROW_Y)
		SkinBagButton(button)
	end
end

local function SkinBagArea(frame, panel)
	if frame.BagText then
		frame.BagText:SetFontObject(GameFontNormal)
		if BAGSLOTTEXT then frame.BagText:SetText(BAGSLOTTEXT) end
		frame.BagText:ClearAllPoints()
		frame.BagText:SetPoint("CENTER", art.bagBand, "TOP", 0, -BAG_LABEL_Y)
	end
	-- Vanilla's purchase question over the cost row (on the cost's money
	-- frame, which Blizzard shows and hides with the rest of the row).
	local cost = panel.MoneyDisplay
	if cost and BANKSLOTPURCHASE_LABEL then
		local question = cost:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		question:SetText(BANKSLOTPURCHASE_LABEL)
		question:SetPoint("CENTER", art.footer, "TOP", 0, -PURCHASE_LABEL_Y)
	end
	if frame.BagCost then
		frame.BagCost:SetFontObject(GameFontNormal)
		frame.BagCost:ClearAllPoints()
		frame.BagCost:SetPoint("LEFT", art.footer, "TOPLEFT", COST_X, -COST_Y)
	end
	if panel.PurchaseButton then
		panel.PurchaseButton:ClearAllPoints()
		panel.PurchaseButton:SetPoint("RIGHT", art.footer, "TOPRIGHT", -PURCHASE_RIGHT, -COST_Y)
	end
	-- The modern ornament between the slots and the bags.
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:GetObjectType() == "Texture" and region:GetAtlas() == "bank-divider" then
			region:SetAlpha(0)
		end
	end
	ns.Hook(frame, "RefreshBagButtons", LayoutBagButtons)
end

---------------------------------------------------------------------------
-- Forever's page tabs (LargeSideTabButtonTemplate) as skill line tabs
---------------------------------------------------------------------------

local PAGE_TAB_SIZE, PAGE_TAB_X, PAGE_TAB_Y, PAGE_TAB_GAP = 32, 2, -25, 17 -- retail's bank tabs
local PAGE_TAB_ART = { "Background", "Icon", "SelectedTexture", "HighlightTexture" }

local pageTabs = setmetatable({}, { __mode = "k" }) -- tab -> { icon, checked }

local function SkinPageTab(tab)
	local skin = pageTabs[tab]
	if skin then return skin end
	skin = {}
	pageTabs[tab] = skin
	for _, key in ipairs(PAGE_TAB_ART) do
		if tab[key] then tab[key]:SetAlpha(0) end
	end
	if tab.TabGlow then tab.TabGlow:Hide() end
	tab:SetSize(PAGE_TAB_SIZE, PAGE_TAB_SIZE)

	local border = tab:CreateTexture(nil, "BACKGROUND")
	border:SetTexture(T.SPELLBOOK_SKILLTAB)
	border:SetSize(64, 64)
	border:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)

	skin.icon = tab:CreateTexture(nil, "ARTWORK")
	skin.icon:SetAllPoints(tab)

	skin.checked = tab:CreateTexture(nil, "OVERLAY")
	skin.checked:SetTexture(T.BUTTON_CHECKED)
	skin.checked:SetBlendMode("ADD")
	skin.checked:SetAllPoints(tab)
	skin.checked:Hide()

	local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture(T.BUTTON_HIGHLIGHT)
	highlight:SetBlendMode("ADD")
	highlight:SetAllPoints(tab)

	ns.Hook(tab, "SetChecked", function(_, checked)
		skin.checked:SetShown(checked == true)
	end)
	return skin
end

-- After Blizzard's RefreshPageTabs, which acquires a tab per page (the
-- character bank's, then the warband bank's) and sets its icon.
local function LayoutPageTabs(frame)
	local tabs = {}
	for tab in frame.bankPageTabPool:EnumerateActive() do
		table.insert(tabs, tab)
	end
	local character = Enum.BankType and Enum.BankType.Character
	local function Order(tab)
		return (tab.bankType == character and 0 or 1000) + (tab.pageNumber or 0)
	end
	table.sort(tabs, function(a, b) return Order(a) < Order(b) end)
	for i, tab in ipairs(tabs) do
		local skin = SkinPageTab(tab)
		skin.icon:SetTexture(tab.Icon and tab.Icon:GetTexture())
		skin.checked:SetShown(tab.SelectedTexture ~= nil and tab.SelectedTexture:IsShown())
		tab:ClearAllPoints()
		tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", PAGE_TAB_X, PAGE_TAB_Y - (i - 1) * (PAGE_TAB_SIZE + PAGE_TAB_GAP))
	end
end

---------------------------------------------------------------------------
-- Retail's bank / warband tabs and check box
---------------------------------------------------------------------------

-- TabSystemButtonTemplate has PanelTabButtonTemplate's pieces; its
-- SetTabSelected drops the selected tab's text 5px for the taller modern
-- active art, which the flat classic tab does not have.
local function KeepTabText(tab)
	if tab.Text then tab.Text:SetPoint("CENTER", tab, "CENTER", 0, 2) end
end

local function SkinTabSystem(frame)
	local tabSystem = frame.TabSystem
	if not tabSystem or not tabSystem.tabs or not ns.LayoutClassicTabs then return end
	for _, tab in ipairs(tabSystem.tabs) do
		ns.SkinPanelTab(tab, false, true)
		ns.Hook(tab, "SetTabSelected", KeepTabText)
		KeepTabText(tab)
	end
	local function Layout()
		ns.LayoutClassicTabs(frame, tabSystem.tabs)
	end
	-- The tab system (a HorizontalLayoutFrame) lines its tabs up again
	-- whenever one is shown, hidden or enabled.
	ns.Hook(tabSystem, "Layout", Layout)
	frame:HookScript("OnShow", Layout)
	Layout()
end

local function SkinCheckbox(check)
	if not check or not ns.HasTexture(T.CHECKBOX .. "Up") then return end
	check:SetNormalTexture(T.CHECKBOX .. "Up")
	check:SetPushedTexture(T.CHECKBOX .. "Down")
	check:SetHighlightTexture(T.CHECKBOX .. "Highlight", "ADD")
	check:SetCheckedTexture(T.CHECKBOX .. "Check")
	check:SetDisabledCheckedTexture(T.CHECKBOX .. "Check-Disabled")
	for _, texture in ipairs({ check:GetNormalTexture(), check:GetPushedTexture(), check:GetHighlightTexture(), check:GetCheckedTexture(), check:GetDisabledCheckedTexture() }) do
		texture:ClearAllPoints()
		texture:SetAllPoints(check)
	end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

-- PortraitFrameTemplate's and BankFrameTemplate's modern art, and the bank
-- panel's inset border and edge shadows.
local MODERN_ART = { "NineSlice", "Bg", "Background", "TopTileStreaks", "PortraitContainer" }
local MODERN_PANEL_ART = { "NineSlice", "EdgeShadows" }

local function SkinWindow(frame, panel)
	for _, key in ipairs(MODERN_ART) do
		if frame[key] then frame[key]:SetAlpha(0) end
	end
	for _, key in ipairs(MODERN_PANEL_ART) do
		if panel[key] then panel[key]:SetAlpha(0) end
	end

	-- The art hangs out of the window by its margin; the panel covers the
	-- window, so what Blizzard anchors to it (the bank tabs, the prompts)
	-- follows the art's border.
	art.origin = CreateFrame("Frame", nil, frame)
	art.origin:SetPoint("TOPLEFT", frame, "TOPLEFT", -BORDER_LEFT, BORDER_TOP)
	art.bagBand = CreateFrame("Frame", nil, art.origin)
	art.bagBand:SetHeight(ART_Y.bags[2] - ART_Y.bags[1])
	art.footer = CreateFrame("Frame", nil, art.origin)
	art.footer:SetHeight(ART_Y.footer[2] - ART_Y.footer[1])
	art.pieces, art.covers = {}, {}
	panel:ClearAllPoints()
	panel:SetAllPoints(frame)

	-- The NPC's portrait under the ring (BankFrame_Open sets Blizzard's).
	local portrait = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait:SetPoint("TOPLEFT", art.origin, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
	ns.Hook(frame, "SetPortraitToUnit", function(_, unit)
		SetPortraitTexture(portrait, unit)
	end)

	local title = frame.TitleContainer
	if title then
		title:ClearAllPoints()
		title:SetPoint("TOPLEFT", art.origin, "TOPLEFT", TITLE_LEFT, -(TITLE_Y - 10))
		title:SetHeight(20)
		if title.TitleText then title.TitleText:SetFontObject(GameFontHighlight) end
	end
	if frame.CloseButton then ns.SkinCloseButton(frame.CloseButton) end

	-- Retail's tab name, or vanilla's "Item Slots", over the wells.
	local header = panel.Header
	if not header and ITEMSLOTTEXT then
		header = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		header:SetText(ITEMSLOTTEXT)
	end

	local money = panel.MoneyFrame
	if money and money.Border then money.Border:SetAlpha(0) end

	art.OnResize = function(width)
		if title then
			title:SetPoint("TOPRIGHT", art.origin, "TOPLEFT", width - TITLE_RIGHT, -(TITLE_Y - 10))
		end
		if frame.CloseButton then
			ns.Point(frame.CloseButton, "CENTER", art.origin, "TOPLEFT", width - CLOSE_RIGHT, -CLOSE_Y)
		end
		if header then
			local center = (BORDER_LEFT + width - BORDER_RIGHT) / 2
			ns.Point(header, "CENTER", art.origin, "TOPLEFT", center, -ITEM_LABEL_Y)
		end
		if money then
			ns.Point(money, "RIGHT", art.footer, "TOPRIGHT", -MONEY_RIGHT, -MONEY_Y)
		end
	end
end

---------------------------------------------------------------------------
-- Module entry point
---------------------------------------------------------------------------

function module:Apply()
	local panel = BankFrame and BankFrame.BankPanel
	if not panel or not panel.itemButtonPool then return end
	if not ns.HasTexture(T.BANK_FRAME) then
		ns.Print("This client does not ship the vanilla bank art; the modern bank is kept.")
		return
	end
	art.bags = BankFrame.itemButtonBagPool ~= nil
	SkinWindow(BankFrame, panel)
	SkinTabSystem(BankFrame)
	local autoDeposit = panel.AutoDepositFrame
	SkinCheckbox(autoDeposit and autoDeposit.IncludeReagentsCheckbox)
	if art.bags then SkinBagArea(BankFrame, panel) end
	if BankFrame.bankPageTabPool then
		ns.Hook(BankFrame, "RefreshPageTabs", LayoutPageTabs)
	end

	ns.Hook(panel, "GenerateItemSlotsForSelectedTab", LayoutSlots)
	ns.Hook(BankFrame, "UpdateWidthForSelectedTab", FitFrame)
	-- Until the first layout: the file's own grid.
	DrawArt(7, 4, {})
end
