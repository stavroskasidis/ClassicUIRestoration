--[[
	Classic UI Restoration - Auction House

	Restores the vanilla auction house window (1.12 Blizzard_AuctionUI.xml):
	the 832x447 panel assembled from the six Interface\AuctionFrame\
	UI-AuctionFrame-<Tab>-* pieces (a different set per tab: "Browse" with
	the filter column on the left, "Auction" with the Create Auction panel
	on the left), the NPC's portrait in the ring, the round close button, the
	Browse / Bids / Auctions style tabs hanging under the frame, the classic
	column headers with the UI-SortArrow, the filter buttons on their
	UI-AuctionFrame-FilterBg plates with the tree lines and the locked tab
	highlight on the selected one, the classic knob scroll bars in the
	UI-Character-ScrollBar troughs, the classic dropdown boxes, the player's
	money in the outlined box at the bottom left and 80px Bid / Buyout /
	Close buttons in the three slots at the bottom right.

	Retail's AuctionHouseFrame (Blizzard_AuctionHouseUI, load-on-demand,
	identical on WoW Forever apart from the category data) is an 800x538
	PortraitFrameTemplate whose three tabs (Buy, Sell, Auctions) swap sets of
	sub-frames: the Buy tab has a search bar, a categories list and a browse
	results list (ScrollBox rows laid out by a TableBuilder with its own
	column headers), and turns into an item buy or commodities buy view when
	a result is clicked; the Sell tab has a VerticalLayoutFrame of aligned
	controls (item, quantity, price, duration, deposit, total, Post) beside
	the list of current listings; the Auctions tab has Auctions / Bids top
	tabs, a summary list on the left and the auction list on the right. All
	of it is re-skinned in place so Blizzard's searching, buying, posting,
	favourites, sorting and tooltips keep working:

	  * the frame is resized to 832x447, its NineSlice / rock background hidden
	    and the vanilla art drawn on it; the Browse art is used for the Buy
	    and Auctions tabs (whose left column suits the categories / summary
	    lists) and the Auction art for the Sell tab, swapped from a hook on
	    SetDisplayMode. Every sub-frame is re-anchored into the art's insets;
	    the lists that sit directly in an inset lose their own inset border
	    and background, the ones nested beside another panel (buy display,
	    commodities market, item header) keep the inset border on the classic
	    marble background like Blizzard's own Classic flavour of this code,
	  * the Sell tab's controls are restacked into the narrow vanilla panel
	    (label above input, classic input box art, classic dropdown box) from
	    a hook on the layout frame's Layout, which Blizzard re-runs whenever a
	    control is shown or hidden; the Post button becomes the vanilla
	    Create Auction button below the panel,
	  * list rows keep Blizzard's cells and only get the classic highlight;
	    the row stripes are faded. The round item buttons of the item headers
	    are squared off (mask removed, classic slot art behind them) and the
	    quality ring Blizzard sets on them is swapped for the square frame
	    from a hook on SetItemButtonBorder,
	  * the WoW Token category, dialogs and the multisell progress frame are
	    left to Blizzard.

	Everything touched is widget state; no Lua field is written on Blizzard's
	frames. Applied once at login (reload to switch off).
]]

local _, ns = ...
local T = ns.T
local Point, SetTexture = ns.Point, ns.SetTexture

T.AH_ART           = "Interface\\AuctionFrame\\UI-AuctionFrame-" -- + Browse / Auction + -TopLeft / -Top / -TopRight / -BotLeft / -Bot / -BotRight
T.AH_FILTER_BG     = "Interface\\AuctionFrame\\UI-AuctionFrame-FilterBg"
T.AH_FILTER_LINES  = "Interface\\AuctionFrame\\UI-AuctionFrame-FilterLines"
T.CHAR_SCROLLBAR   = "Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar"
T.TAB_INACTIVE     = "Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab"
T.TAB_HIGHLIGHT    = "Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight"
T.SORT_ARROW       = "Interface\\Buttons\\UI-SortArrow"
T.LIST_HIGHLIGHT   = "Interface\\HelpFrame\\HelpFrameButton-Highlight"
T.INPUT_BORDER     = "Interface\\Common\\Common-Input-Border"
T.QUICKSLOT        = "Interface\\Buttons\\UI-Quickslot2"
T.SQUARE_HIGHLIGHT = "Interface\\Buttons\\ButtonHilight-Square"
T.ICON_FRAME       = "Interface\\Common\\WhiteIconFrame"
T.MARBLE           = "Interface\\FrameGeneral\\UI-Background-Marble"

local module = ns:RegisterModule({
	key = "auctionhouse",
	name = "Auction House",
	tooltip = "Restores the vanilla auction house window: the classic panel with the filter column, the classic column headers, tabs, scroll bars and dropdowns, the Create Auction panel on the Sell tab and the Bid / Buyout / Close buttons at the bottom.",
	live = false,
})

-- Vanilla geometry (1.12 Blizzard_AuctionUI.xml, frame 832x447; the art's
-- bottom pieces are transparent below 447). Measured from the art as the
-- retail client ships it (the Auction set is Cataclysm's redraw of the
-- vanilla panel, the Browse set is unchanged): the Browse set has its left
-- column at x 20..181, its list at x 188..822 and both from y 103 to 410;
-- the Auction set has its list from x 216, y 71, and its left panel at
-- x 19..208 in four boxes: y 71..207 (item and prices), 214..357, 360..383
-- and the Create Auction button slot 386..408.
local FRAME_WIDTH, FRAME_HEIGHT = 832, 447
local COLUMN_LEFT, COLUMN_RIGHT, COLUMN_TOP, COLUMN_BOTTOM = 16, 190, -103, -410
local LIST_LEFT, LIST_RIGHT, LIST_TOP, LIST_BOTTOM = 188, -13, -80, 34 -- an ItemList (its headers sit 2px below its top, in the strip above the inset)
local ITEM_LIST_TOP = -170                                              -- the list under an item header (item buy / own auctions of one item)
local SUB_PANEL_TOP = -106                                              -- item headers / the commodities buy display
local BOTTOM_SLOTS = { -168, -88, -8 }                                  -- BOTTOMRIGHT x of the three 80x22 button slots
local BOTTOM_BUTTON_Y = 14
local SELL_PANEL = { left = 19, top = -71, right = 208, bottom = -386 }
local SELL_BOXES = { -143, -288 }                                       -- panel-relative tops of the second and third box
local SELL_ROD = -136                                                   -- a control reaching past this moves down into the second box
local SELL_LIST_TOP = -50                                               -- headers at -51 (vanilla), the inset starts at 71
local ITEM_BUTTON_SIZE = 37                                             -- vanilla item slots
local FILTER_DROPDOWN_WIDTH, DURATION_DROPDOWN_WIDTH = 110, 100

local art = {}                                        -- regions/frames created by this module
local skinned = setmetatable({}, { __mode = "k" })    -- Blizzard frame -> true once its one-time skin ran
local squareButtons = setmetatable({}, { __mode = "k" }) -- circular item buttons squared off by this module
local skinnedBottomTabs = setmetatable({}, { __mode = "k" }) -- the frame's tabs, whose selected text keeps its place

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Hide(region)
	if region then region:Hide() end
end

local function Fade(region)
	if region then region:SetAlpha(0) end
end

-- Anchors a frame to a rectangle of the auction house frame. `left` / `top`
-- are offsets from the frame's TOPLEFT. A negative `bottom` is also from
-- the top (and `right` an x from the left edge); a positive `bottom` is an
-- offset up from the frame's bottom edge (and `right` an offset in from
-- the right edge), for the lists that run down to the bottom strip.
local function Rect(region, left, top, right, bottom)
	local frame = AuctionHouseFrame
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", frame, "TOPLEFT", left, top)
	if bottom > 0 then
		region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, bottom)
	else
		region:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", right, bottom)
	end
end

-- The total / refresh frame of a list under an item header (retail: above
-- the list, which here is the search bar) goes to the right end of the
-- strip above the inset, beside the Back button.
local function RefreshToStrip(list)
	if list.RefreshFrame then
		Point(list.RefreshFrame, "BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT", -17, COLUMN_TOP + 2)
	end
end

-- The UI-Character-ScrollBar trough vanilla drew behind every scroll bar: a
-- 256px top piece and a 106px bottom piece that overlap in the middle. The
-- retail file's arrow cells are 20px at the top of the top piece and 22px
-- at the bottom of the bottom piece, so with the trough 2px beyond each end
-- of the scroll box the bar's 16px steppers sit centred in the cells. The
-- pieces are anchored to the scroll box (`dx` from its right edge, so the
-- trough is centred on the 16px bar the list puts beside it).
local function CreateTrough(list, dx)
	local scrollBox = list.ScrollBox
	if not scrollBox or not ns.HasTexture(T.CHAR_SCROLLBAR) then return end
	local top = list:CreateTexture(nil, "ARTWORK")
	SetTexture(top, T.CHAR_SCROLLBAR, 0, 0.484375, 0, 1)
	top:SetSize(31, 256)
	top:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", dx, 2)
	local bottom = list:CreateTexture(nil, "ARTWORK", nil, 1)
	SetTexture(bottom, T.CHAR_SCROLLBAR, 0.515625, 1, 0, 0.4140625)
	bottom:SetSize(31, 106)
	bottom:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", dx, -2)
end
local LIST_TROUGH_DX, COLUMN_TROUGH_DX = 1, -2 -- bars 9px / 6px right of the box

-- Keeps Blizzard's inset border on a panel that sits beside another one and
-- puts the classic marble behind it (what Blizzard's Classic flavour of the
-- auction house does), instead of the retail parchment atlas.
local function SkinInset(panel)
	local background = panel.Background
	if background then
		background:SetTexture(T.MARBLE, "REPEAT", "REPEAT") -- tiling needs the repeat wrap modes
		background:SetTexCoord(0, 1, 0, 1)
		background:SetHorizTile(true)
		background:SetVertTile(true)
		background:ClearAllPoints()
		background:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
		background:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -3, 3)
	end
end

-- A panel that sits directly in one of the art's insets needs neither its
-- own border nor a background.
local function StripInset(panel)
	Hide(panel.NineSlice)
	Hide(panel.Background)
end

-- Classic edit box art (Common-Input-Border, as vanilla's InputBoxTemplate)
-- on a retail edit box (LargeInputBoxTemplate, SearchBoxTemplate), which
-- carries Left / Middle / Right atlas pieces of its own.
local function SkinInputBox(box, width, height)
	box:SetSize(width, height)
	if box.Left and ns.HasTexture(T.INPUT_BORDER) then
		SetTexture(box.Left, T.INPUT_BORDER, 0, 0.0625, 0, 0.625)
		box.Left:SetSize(8, 20)
		Point(box.Left, "LEFT", box, "LEFT", -5, 0)
		SetTexture(box.Right, T.INPUT_BORDER, 0.9375, 1, 0, 0.625)
		box.Right:SetSize(8, 20)
		Point(box.Right, "RIGHT", box, "RIGHT", 0, 0)
		SetTexture(box.Middle, T.INPUT_BORDER, 0.0625, 0.9375, 0, 0.625)
		box.Middle:SetHeight(20)
		Point(box.Middle, "LEFT", box.Left, "RIGHT", 0, 0)
		box.Middle:SetPoint("RIGHT", box.Right, "LEFT", 0, 0)
	end
end

-- PanelTabButtonTemplate draws three atlas pieces for the inactive tab,
-- three for the active one (shown / hidden by PanelTemplates_SelectTab) and
-- three additive highlights. They become the vanilla CharacterFrame tab
-- pieces (UI-Character-InActiveTab, 20px ends) with the classic glow
-- highlight. Vanilla's active tab (UI-Character-ActiveTab) was the same
-- body without its top rim, drawn 5px up into the frame border; the retail
-- client's file of that name is a different, short gold-glow tab, so the
-- active pieces are cut from the inactive file (its rim rows skipped)
-- instead: its body rows (below the top rim, down to the bottom rim) are
-- stretched from 5px above the tab to the inactive tab's bottom edge, and
-- the text stays where the inactive tab has it. Top tabs (the Auctions /
-- Bids sub-tabs) are the same art flipped and cut to 24px, as Blizzard's
-- PanelTopTabButtonMixin does with its atlases; their active state is the
-- same art in place (a shift into the panel would cover its top border).
local TAB_RIM_TOP, TAB_RIM_BOTTOM = 0.15625, 0.875 -- InActiveTab: rows 0-4 rim, 5-27 body, 28-31 empty
local TAB_ACTIVE_RISE = 5

local function SkinTab(tab, isTop)
	local height = isTop and 24 or 32
	local topCoord, bottomCoord = 0, 1
	local activeTop, activeBottom, activeHeight, activeY = TAB_RIM_TOP, TAB_RIM_BOTTOM, 28 + TAB_ACTIVE_RISE, TAB_ACTIVE_RISE
	if isTop then
		topCoord, bottomCoord = 1, 0.25
		activeTop, activeBottom, activeHeight, activeY = topCoord, bottomCoord, height, 0
	end
	local function Piece(texture, left, right, top, bottom, pieceHeight)
		if not texture then return end
		SetTexture(texture, T.TAB_INACTIVE, left, right, top, bottom)
		texture:SetHeight(pieceHeight)
	end
	local function End(texture, left, right, top, bottom, pieceHeight, point, x, y)
		if not texture then return end
		Piece(texture, left, right, top, bottom, pieceHeight)
		texture:SetWidth(20)
		Point(texture, point, tab, point, x, y)
	end
	local topPoint, rightPoint = "TOPLEFT", "TOPRIGHT"
	if isTop then
		topPoint, rightPoint = "BOTTOMLEFT", "BOTTOMRIGHT"
	end
	End(tab.Left, 0, 0.15625, topCoord, bottomCoord, height, topPoint, 0, 0)
	Piece(tab.Middle, 0.15625, 0.84375, topCoord, bottomCoord, height)
	End(tab.Right, 0.84375, 1, topCoord, bottomCoord, height, rightPoint, 0, 0)
	End(tab.LeftActive, 0, 0.15625, activeTop, activeBottom, activeHeight, topPoint, 0, activeY)
	Piece(tab.MiddleActive, 0.15625, 0.84375, activeTop, activeBottom, activeHeight)
	End(tab.RightActive, 0.84375, 1, activeTop, activeBottom, activeHeight, rightPoint, 0, activeY)
	if not isTop then
		skinnedBottomTabs[tab] = true
	end

	for _, key in ipairs({ "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do
		Fade(tab[key])
	end
	if ns.HasTexture(T.TAB_HIGHLIGHT) then
		local glow = tab:CreateTexture(nil, "HIGHLIGHT")
		SetTexture(glow, T.TAB_HIGHLIGHT, 0, 1, topCoord, bottomCoord)
		glow:SetBlendMode("ADD")
		glow:SetHeight(height)
		glow:SetPoint("LEFT", tab, "LEFT", 10, isTop and -2 or 2)
		glow:SetPoint("RIGHT", tab, "RIGHT", -10, isTop and -2 or 2)
	end
end

-- An 80x22 vanilla bottom-strip button in one of the three art slots.
local function ToSlot(button, slot)
	button:SetSize(80, 22)
	Point(button, "BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", BOTTOM_SLOTS[slot], BOTTOM_BUTTON_Y)
end

---------------------------------------------------------------------------
-- Lists (AuctionHouseItemListTemplate and the summary list)
---------------------------------------------------------------------------

-- Retail rows are striped and highlighted with atlases; vanilla rows had
-- the HelpFrameButton glow and no stripes. Blizzard re-sets the stripe
-- atlas on every update, alpha survives that.
local function SkinRow(row)
	if skinned[row] then return end
	skinned[row] = true
	local normal = row.GetNormalTexture and row:GetNormalTexture()
	Fade(normal)
	for _, key in ipairs({ "HighlightTexture", "SelectedHighlight" }) do
		local texture = row[key]
		if texture and ns.HasTexture(T.LIST_HIGHLIGHT) then
			SetTexture(texture, T.LIST_HIGHLIGHT, 0, 1, 0, 0.578125)
			texture:SetBlendMode("ADD")
		end
	end
end

-- The rows are created by the list's ScrollBox as they are needed.
local function SkinScrollBoxRows(scrollBox)
	if not scrollBox or not ScrollUtil.AddAcquiredFrameCallback then return end
	ScrollUtil.AddAcquiredFrameCallback(scrollBox, function(_, row) SkinRow(row) end, module)
end

-- `rows` is false for the categories list, whose buttons are re-skinned
-- after AuctionHouseFilterButton_SetUp instead.
local function SkinScrollBox(scrollBox, rows)
	if rows ~= false then
		SkinScrollBoxRows(scrollBox)
	end
	-- Retail fades the list's edges with shadow textures while it scrolls.
	if scrollBox.GetUpperShadowTexture then
		Fade(scrollBox:GetUpperShadowTexture())
		Fade(scrollBox:GetLowerShadowTexture())
	end
end

-- An AuctionHouseItemListTemplate: header row, ScrollBox, MinimalScrollBar
-- (9px right of the box), refresh frame, spinner. `inArt` lists sit in an
-- art inset and get the classic trough behind their bar.
local function SkinItemList(list, inArt)
	if skinned[list] then return end
	skinned[list] = true
	if inArt then
		StripInset(list)
		CreateTrough(list, LIST_TROUGH_DX)
	else
		SkinInset(list)
	end
	ns.SkinScrollBar(list.ScrollBar)
	SkinScrollBox(list.ScrollBox)
end

---------------------------------------------------------------------------
-- Column headers (AuctionHouseTableHeaderStringTemplate)
---------------------------------------------------------------------------

-- The headers already use the classic WhoFrame-ColumnTabs art; only the
-- sort arrow is an atlas. Header frames are created by the table builder
-- when a list lays out its columns, so the mixin is hooked. Blizzard flips
-- its atlas for the primary sort; the classic arrow file points the other
-- way, so the tex coords are re-set after SetArrowState.
local function SkinHeaders()
	local mixin = AuctionHouseTableHeaderStringMixin
	if not mixin or not ns.HasTexture(T.SORT_ARROW) then return end
	ns.Hook(mixin, "Init", function(header)
		if skinned[header] or not header.Arrow then return end
		skinned[header] = true
		header.Arrow:SetSize(9, 8)
		Point(header.Arrow, "LEFT", header.Text, "RIGHT", 3, -2)
	end)
	ns.Hook(mixin, "SetArrowState", function(header, state)
		if not header.Arrow then return end
		if state == AuctionHouseSortOrderState.PrimaryReversed then
			SetTexture(header.Arrow, T.SORT_ARROW, 0, 0.5625, 1, 0)
		else
			SetTexture(header.Arrow, T.SORT_ARROW, 0, 0.5625, 0, 1)
		end
	end)
end

---------------------------------------------------------------------------
-- Item buttons and item headers
---------------------------------------------------------------------------

-- The item headers use CircularGiantItemButtonTemplate (a masked round icon
-- with a ring border and ring highlight); vanilla item slots were square,
-- 37px, on the UI-Quickslot2 plate.
local function SquareItemButton(button)
	if not button or skinned[button] then return end
	skinned[button] = true
	squareButtons[button] = true
	button:SetSize(ITEM_BUTTON_SIZE, ITEM_BUTTON_SIZE)
	local icon = button.Icon
	if icon then
		ns.StripMask(button.CircleMask, icon)
		ns.StripMask(button.IconMask, icon)
		icon:SetTexCoord(0, 1, 0, 1)
		Point(icon, "TOPLEFT", button, "TOPLEFT", 0, 0)
		icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
		if button.IconBorder then
			button.IconBorder:ClearAllPoints()
			button.IconBorder:SetAllPoints(icon)
		end
		if ns.HasTexture(T.QUICKSLOT) then
			local plate = button:CreateTexture(nil, "BACKGROUND", nil, -1)
			SetTexture(plate, T.QUICKSLOT)
			plate:SetSize(66, 66)
			plate:SetPoint("CENTER", icon, "CENTER", 0, -1)
		end
	end
	Fade(button.EmptyBackground) -- the retail "drop an item" plate; the art has the slot
	if ns.HasTexture(T.SQUARE_HIGHLIGHT) then
		button:SetHighlightTexture(T.SQUARE_HIGHLIGHT, "ADD")
		local highlight = button:GetHighlightTexture()
		if highlight and icon then
			highlight:ClearAllPoints()
			highlight:SetAllPoints(icon)
		end
	end
end

-- Blizzard puts a round quality ring on the circular buttons; the squared
-- ones get the square quality frame instead (the vertex colour is applied
-- by Blizzard right after).
local function HookItemBorders()
	ns.Hook("SetItemButtonBorder", function(button, asset, isAtlas)
		if squareButtons[button] and asset and isAtlas and button.IconBorder and ns.HasTexture(T.ICON_FRAME) then
			button.IconBorder:SetTexture(T.ICON_FRAME)
		end
	end)
end

-- An AuctionHouseItemDisplayTemplate header (icon, name, favourite star)
-- that sits inside an art inset: it keeps its inset border and loses the
-- retail item-header ornament.
local function SkinItemHeader(display, height)
	if skinned[display] then return end
	skinned[display] = true
	SkinInset(display)
	for _, region in ipairs({ display:GetRegions() }) do
		if region.GetAtlas and region:GetAtlas() == "auctionhouse-itemheaderframe" then
			region:Hide()
		end
	end
	display:SetHeight(height)
	SquareItemButton(display.ItemButton)
	if display.Name then
		display.Name:SetHeight(height - 8)
	end
end

---------------------------------------------------------------------------
-- Frame chrome
---------------------------------------------------------------------------

local function CreateArt(frame)
	local function Piece(x, y, width)
		local texture = frame:CreateTexture(nil, "BORDER")
		texture:SetSize(width, 256)
		texture:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
		return texture
	end
	-- Vanilla stretched the two middle pieces to 320px.
	art.pieces = {
		TopLeft = Piece(0, 0, 256), Top = Piece(256, 0, 320), TopRight = Piece(576, 0, 256),
		BotLeft = Piece(0, -256, 256), Bot = Piece(256, -256, 320), BotRight = Piece(576, -256, 256),
	}
end

-- The retail files' bottom pieces have a darker list texture than the top
-- ones, which shows as a rectangle in the lower right of the list inset.
-- The inset's interior is covered with the seamlessly tiling dark marble
-- the art was painted from (UI-Background-Marble, what InsetFrameTemplate
-- tiles as well), so it is one texture throughout.
local INTERIOR = { Browse = { 189, -103, 821, -409 }, Auction = { 217, -73, 821, -409 } } -- left, top, right, bottom

local function TileInterior(set)
	local frame = AuctionHouseFrame
	local rect = INTERIOR[set]
	if not art.interior then
		if not ns.HasTexture(T.MARBLE) then return end
		art.interior = frame:CreateTexture(nil, "BORDER", nil, 1)
		art.interior:SetTexture(T.MARBLE, "REPEAT", "REPEAT") -- tiling needs the repeat wrap modes
		art.interior:SetHorizTile(true)
		art.interior:SetVertTile(true)
	end
	art.interior:ClearAllPoints()
	art.interior:SetPoint("TOPLEFT", frame, "TOPLEFT", rect[1], rect[2])
	art.interior:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", rect[3], rect[4])
end

-- "Browse" (Buy and Auctions tabs) or "Auction" (Sell tab).
local function SetArt(set)
	if art.set == set then return end
	art.set = set
	for name, texture in pairs(art.pieces) do
		texture:SetTexture(T.AH_ART .. set .. "-" .. name)
	end
	TileInterior(set)
end

local function ApplyFrameChrome(frame)
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	Hide(frame.NineSlice)
	Hide(frame.Bg)
	Hide(frame.TopTileStreaks)
	CreateArt(frame)
	SetArt("Browse")

	-- Vanilla drew the square portrait on the BACKGROUND layer and let the
	-- ring in the art cut it round; retail's portrait lives in a masked child
	-- frame drawn above the art, so the container is dropped a strata.
	local container = frame.PortraitContainer
	local portrait = container and container.portrait
	if portrait then
		portrait:SetSize(58, 58)
		Point(portrait, "TOPLEFT", frame, "TOPLEFT", 8, -7)
		container:SetFrameStrata("LOW")
		ns.StripMask(container.CircleMask, portrait)
	end

	local title = frame.TitleContainer and frame.TitleContainer.TitleText
	if title then
		Point(title, "TOP", frame, "TOP", 0, -17)
	end

	if frame.CloseButton then
		ns.SkinCloseButton(frame.CloseButton)
		Point(frame.CloseButton, "TOPRIGHT", frame, "TOPRIGHT", 3, -8)
	end

	-- The player's money: retail draws it in a gold-edged box on an inset at
	-- the bottom left; vanilla's SmallMoneyFrame sat in the box outlined in
	-- the art (x 15..180, y 412..430).
	Hide(frame.MoneyFrameInset)
	local border = frame.MoneyFrameBorder
	if border then
		for _, region in ipairs({ border:GetRegions() }) do
			Fade(region)
		end
		Point(border, "BOTTOMRIGHT", frame, "BOTTOMLEFT", 187, 15)
	end

	-- Tabs: vanilla hung them from the bottom left, 8px into each other.
	if frame.Tabs then
		for _, tab in ipairs(frame.Tabs) do
			SkinTab(tab, false)
		end
	end
	-- PanelTemplates_SelectTab drops the text 5px for its taller active
	-- atlas; the merged classic body keeps the inactive text position.
	ns.Hook("PanelTemplates_SelectTab", function(tab)
		if skinnedBottomTabs[tab] and tab.Text then
			tab.Text:SetPoint("CENTER", tab, "CENTER", 0, 2)
		end
	end)
	if frame.BuyTab then
		Point(frame.BuyTab, "TOPLEFT", frame, "BOTTOMLEFT", 15, 11)
	end
	if frame.SellTab and frame.BuyTab then
		Point(frame.SellTab, "TOPLEFT", frame.BuyTab, "TOPRIGHT", -8, 0)
	end
	if frame.AuctionsTab and frame.SellTab then
		Point(frame.AuctionsTab, "TOPLEFT", frame.SellTab, "TOPRIGHT", -8, 0)
	end

	-- Vanilla had a Close button in the rightmost bottom slot on every tab.
	art.close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	art.close:SetText(CLOSE or "Close")
	art.close:SetScript("OnClick", function() HideUIPanel(frame) end)
	ToSlot(art.close, 3)

	-- The Browse art for buying and the Auction art for selling.
	ns.Hook(frame, "SetDisplayMode", function(self)
		local mode = self.displayMode
		local modes = AuctionHouseFrameDisplayMode
		local selling = mode == modes.ItemSell or mode == modes.CommoditiesSell or mode == modes.WoWTokenSell
		SetArt(selling and "Auction" or "Browse")
	end)
end

---------------------------------------------------------------------------
-- Buy tab: search bar, categories, browse results, item / commodity buy
---------------------------------------------------------------------------

-- Vanilla: "Name" label at (80,-41) with the edit box under it, the rarity
-- dropdown to its right, the Search button at the right end of the strip.
-- Retail's filter dropdown (level range and rarities) takes the dropdown's
-- place, the favourites star sits before the Search button.
local function LayoutSearchBar(frame)
	local bar = frame.SearchBar
	if not bar then return end
	Rect(bar, 76, -38, 812, -78)

	art.nameLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	art.nameLabel:SetText(NAME or "Name")
	art.nameLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 80, -41)

	if bar.SearchBox then
		SkinInputBox(bar.SearchBox, 170, 20)
		Point(bar.SearchBox, "TOPLEFT", frame, "TOPLEFT", 84, -53)
	end
	if bar.FilterButton then
		Point(bar.FilterButton, "TOPLEFT", frame, "TOPLEFT", 262, -49)
		ns.SkinDropdownBox(bar.FilterButton, FILTER_DROPDOWN_WIDTH)
	end
	if bar.SearchButton then
		bar.SearchButton:SetSize(80, 22)
		Point(bar.SearchButton, "TOPRIGHT", frame, "TOPRIGHT", -30, -52)
	end
	if bar.FavoritesSearchButton and bar.SearchButton then
		bar.FavoritesSearchButton:SetSize(22, 22)
		Point(bar.FavoritesSearchButton, "RIGHT", bar.SearchButton, "LEFT", -8, 0)
	end
end

-- The category buttons are re-set by AuctionHouseFilterButton_SetUp on
-- every list update (atlases, sizes, anchors), so the vanilla look is
-- re-applied after it: the FilterBg plate for categories (full), for
-- sub-categories (indented, dimmed as in vanilla), the tree lines for the
-- third level, and the tab highlight glow for hover and, locked, for the
-- selection (vanilla used LockHighlight).
local function OnFilterButtonSetUp(button, info)
	local normal, selected, highlight, lines = button.NormalTexture, button.SelectedTexture, button.HighlightTexture, button.Lines
	if not normal or not selected or not highlight then return end
	local hasPlate = ns.HasTexture(T.AH_FILTER_BG)
	local hasGlow = ns.HasTexture(T.TAB_HIGHLIGHT)
	local function Glow(texture, width, height, point, x, y)
		if hasGlow then
			SetTexture(texture, T.TAB_HIGHLIGHT)
			texture:SetBlendMode("ADD")
		end
		texture:SetSize(width, height)
		Point(texture, point, button, point, x, y)
	end
	if info.type == "category" then
		if hasPlate then
			SetTexture(normal, T.AH_FILTER_BG, 0, 0.53125, 0, 0.625)
			normal:SetSize(136, 20)
			Point(normal, "TOPLEFT", button, "TOPLEFT", -2, 0)
			normal:SetAlpha(1)
		end
		Glow(selected, 132, 21, "LEFT", 0, 0)
		Glow(highlight, 132, 21, "LEFT", 0, 0)
	elseif info.type == "subCategory" then
		if hasPlate then
			SetTexture(normal, T.AH_FILTER_BG, 0, 0.53125, 0, 0.625)
			normal:SetSize(128, 20)
			Point(normal, "TOPLEFT", button, "TOPLEFT", 6, 0)
			normal:SetAlpha(0.4)
		end
		Glow(selected, 122, 21, "TOPLEFT", 10, 0)
		Glow(highlight, 122, 21, "TOPLEFT", 10, 0)
	else
		Glow(selected, 116, 18, "TOPRIGHT", 0, -2)
		Glow(highlight, 116, 18, "TOPRIGHT", 0, -2)
		if lines and ns.HasTexture(T.AH_FILTER_LINES) then
			if info.isLast then
				SetTexture(lines, T.AH_FILTER_LINES, 0.4375, 0.875, 0, 0.625)
			else
				SetTexture(lines, T.AH_FILTER_LINES, 0, 0.4375, 0, 0.625)
			end
			lines:SetSize(7, 20)
			Point(lines, "LEFT", button, "LEFT", 13, 0)
		end
	end
end

local function LayoutCategories(frame)
	local list = frame.CategoriesList
	if not list then return end
	Rect(list, COLUMN_LEFT, COLUMN_TOP, COLUMN_RIGHT, COLUMN_BOTTOM)
	StripInset(list)
	if list.ScrollBox then
		Point(list.ScrollBox, "TOPLEFT", list, "TOPLEFT", 7, -4)
		list.ScrollBox:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -32, 4)
		SkinScrollBox(list.ScrollBox, false)
	end
	if list.ScrollBar and list.ScrollBox then
		ns.SkinScrollBar(list.ScrollBar)
		Point(list.ScrollBar, "TOPLEFT", list.ScrollBox, "TOPRIGHT", 6, 0)
		list.ScrollBar:SetPoint("BOTTOMLEFT", list.ScrollBox, "BOTTOMRIGHT", 6, 0)
	end
	CreateTrough(list, COLUMN_TROUGH_DX)

	-- Vanilla's "Filters" heading over the column.
	art.filtersLabel = list:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	art.filtersLabel:SetText(FILTERS or "Filters")
	art.filtersLabel:SetPoint("TOP", frame, "TOPLEFT", 91, -85)

	ns.Hook("AuctionHouseFilterButton_SetUp", OnFilterButtonSetUp)
end

local function LayoutBrowse(frame)
	local results = frame.BrowseResultsFrame
	if not results or not results.ItemList then return end
	-- The ItemList extends 18px right of this frame (for its scroll bar).
	Rect(results, LIST_LEFT, LIST_TOP, LIST_RIGHT - 18, LIST_BOTTOM)
	SkinItemList(results.ItemList, true)
end

local function LayoutItemBuy(frame)
	local buy = frame.ItemBuyFrame
	if not buy then return end
	buy:ClearAllPoints()
	buy:SetAllPoints(frame)
	if buy.BackButton then
		buy.BackButton:SetSize(80, 22)
		Point(buy.BackButton, "TOPLEFT", frame, "TOPLEFT", 192, -80)
	end
	if buy.ItemDisplay then
		Rect(buy.ItemDisplay, 192, SUB_PANEL_TOP, 815, ITEM_LIST_TOP + 8)
		SkinItemHeader(buy.ItemDisplay, -ITEM_LIST_TOP - 8 + SUB_PANEL_TOP)
	end
	if buy.ItemList then
		Rect(buy.ItemList, LIST_LEFT, ITEM_LIST_TOP, LIST_RIGHT, LIST_BOTTOM)
		SkinItemList(buy.ItemList, true)
		RefreshToStrip(buy.ItemList)
	end
	if buy.BidFrame then
		if buy.BidFrame.BidButton then ToSlot(buy.BidFrame.BidButton, 1) end
		if buy.BidFrame.BidAmount then
			Point(buy.BidFrame.BidAmount, "BOTTOM", frame, "BOTTOM", -12, 18)
		end
	end
	if buy.BuyoutFrame and buy.BuyoutFrame.BuyoutButton then
		ToSlot(buy.BuyoutFrame.BuyoutButton, 2)
	end
end

local function LayoutCommoditiesBuy(frame)
	local buy = frame.CommoditiesBuyFrame
	if not buy then return end
	buy:ClearAllPoints()
	buy:SetAllPoints(frame)
	if buy.BackButton then
		buy.BackButton:SetSize(80, 22)
		Point(buy.BackButton, "TOPLEFT", frame, "TOPLEFT", 192, -80)
	end
	local display = buy.BuyDisplay
	if display then
		Point(display, "TOPLEFT", frame, "TOPLEFT", 192, SUB_PANEL_TOP)
		display:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 192, COLUMN_BOTTOM + 3)
		SkinInset(display)
		if display.ItemDisplay then
			SkinItemHeader(display.ItemDisplay, 56)
		end
	end
	if buy.ItemList and display then
		Point(buy.ItemList, "TOPLEFT", display, "TOPRIGHT", 1, 0)
		buy.ItemList:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", 815, COLUMN_BOTTOM + 3)
		SkinItemList(buy.ItemList, false)
	end
end

---------------------------------------------------------------------------
-- Sell tab: the Create Auction panel and the listings
---------------------------------------------------------------------------

-- Retail's aligned controls put a right-justified label left of the input;
-- vanilla stacked the label over the input. The label (and its title /
-- sub text variant) go to the control's top left, the input below it.
local function StackLabel(control)
	local label, title, sub = control.Label, control.LabelTitle, control.Subtext
	if label then
		label:SetFontObject(GameFontHighlightSmall)
		label:SetJustifyH("LEFT")
		label:SetWidth(0)
		Point(label, "TOPLEFT", control, "TOPLEFT", 0, 0)
	end
	if title then
		title:SetFontObject(GameFontHighlightSmall)
		title:SetJustifyH("LEFT")
		title:SetWidth(0)
		Point(title, "TOPLEFT", control, "TOPLEFT", 0, 0)
	end
	if sub and title then
		sub:SetJustifyH("LEFT")
		sub:SetWidth(0)
		Point(sub, "LEFT", title, "RIGHT", 4, 0)
	end
	return label
end

local function SkinQuantityInput(control)
	local label = StackLabel(control)
	if control.InputBox and label then
		SkinInputBox(control.InputBox, 80, 22)
		control.InputBox:SetTextInsets(8, 8, 0, 0)
		Point(control.InputBox, "TOPLEFT", label, "BOTTOMLEFT", 5, -3)
	end
	if control.MaxButton and control.InputBox then
		control.MaxButton:SetSize(50, 22)
		Point(control.MaxButton, "LEFT", control.InputBox, "RIGHT", 8, 0)
	end
end

local function SkinPriceInput(control, width)
	local label = StackLabel(control)
	local money = control.MoneyInputFrame
	if money and label then
		money:SetSize(width, 22)
		Point(money, "TOPLEFT", label, "BOTTOMLEFT", 0, -3)
		for _, key in ipairs({ "GoldBox", "SilverBox", "CopperBox" }) do
			local box = money[key]
			if box then
				SkinInputBox(box, 40, 22)
				box:SetTextInsets(6, 24, 0, 0)
			end
		end
		-- The gold box fills what the two fixed 40px boxes leave.
		if money.GoldBox and money.SilverBox then
			Point(money.GoldBox, "LEFT", money, "LEFT", 5, 0)
			money.GoldBox:SetPoint("RIGHT", money.SilverBox, "LEFT", -6, 0)
		end
	end
	if control.PerItemPostfix and label then
		Point(control.PerItemPostfix, "LEFT", label, "RIGHT", 4, 0)
	end
	if control.PriceError then
		Point(control.PriceError, "TOPRIGHT", control, "TOPRIGHT", 0, 0)
	end
end

local function SkinDuration(control)
	local label = StackLabel(control)
	if control.Dropdown and label then
		ns.SkinDropdownBox(control.Dropdown, DURATION_DROPDOWN_WIDTH)
		Point(control.Dropdown, "TOPLEFT", label, "BOTTOMLEFT", -10, -1)
	end
end

-- Deposit and total: one line, "Label: 12s 34c".
local function SkinPriceDisplay(control)
	local label = StackLabel(control)
	if label then
		Point(label, "LEFT", control, "LEFT", 0, 0)
	end
	if control.MoneyDisplayFrame and label then
		Point(control.MoneyDisplayFrame, "LEFT", label, "RIGHT", 5, 0)
		control.MoneyDisplayFrame:SetPoint("RIGHT", control, "RIGHT", 0, 0)
	end
end

-- The sell frame's item slot (GiantItemButtonTemplate: a rounded icon on the
-- retail "drop item" plate) at the vanilla 37px slot drawn in the art.
local function SkinSellItemDisplay(display)
	if skinned[display] then return end
	skinned[display] = true
	Hide(display.NineSlice)
	Hide(display.Background)
	for _, region in ipairs({ display:GetRegions() }) do
		if region.GetAtlas and region:GetAtlas() == "auctionhouse-itemheaderframe" then
			region:Hide()
		end
	end
	local button = display.ItemButton
	if button then
		SquareItemButton(button)
		Point(button, "TOPLEFT", display, "TOPLEFT", 0, 0)
	end
	if display.Name and button then
		display.Name:SetFontObject(GameFontNormal)
		display.Name:SetJustifyH("LEFT")
		display.Name:SetHeight(display:GetHeight())
		Point(display.Name, "LEFT", button, "RIGHT", 5, 0)
		display.Name:SetPoint("RIGHT", display, "RIGHT", -2, 0)
	end
end

-- Vanilla Create Auction panel order: item, (quantity), (bid), buyout,
-- duration, deposit; retail adds the total and the bid-mode checkbox. The
-- item and the price inputs stack in the art's first box, the duration,
-- deposit and total start the second box and the checkbox gets the third;
-- a control that would straddle the rod between the first two boxes (the
-- buyout price in bid mode on a stackable item) moves down into the second
-- box and pushes the rest along. Runs after Blizzard's VerticalLayoutFrame
-- Layout, which re-anchors every child, so the vanilla stacking is put
-- back each time.
local SELL_STACK = {
	{ key = "ItemDisplay", height = 40 },
	{ key = "QuantityInput", height = 38 },
	{ key = "SecondaryPriceInput", height = 42 },
	{ key = "PriceInput", height = 42 },
	{ key = "Duration", height = 42, box = 1 },
	{ key = "Deposit", height = 14 },
	{ key = "TotalPrice", height = 14 },
	{ key = "BuyoutModeCheckButton", height = 20, hitWidth = 20, box = 2 },
}
local SELL_SPACING = 4

local function StackSellFrame(sellFrame)
	local width = sellFrame:GetWidth() - 8
	local y = -6
	for _, entry in ipairs(SELL_STACK) do
		local child = sellFrame[entry.key]
		if child and child:IsShown() then
			if entry.box then
				y = math.min(y, SELL_BOXES[entry.box] - SELL_SPACING)
			elseif y > SELL_ROD and y - entry.height < SELL_ROD then
				y = SELL_BOXES[1] - SELL_SPACING
			end
			child:ClearAllPoints()
			child:SetPoint("TOPLEFT", sellFrame, "TOPLEFT", 4, y)
			child:SetSize(entry.hitWidth or width, entry.height)
			y = y - entry.height - SELL_SPACING
		end
	end
	-- The Create Auction button in the panel's bottom slot.
	local post = sellFrame.PostButton
	if post then
		post:SetSize(SELL_PANEL.right - SELL_PANEL.left - 4, 20)
		Point(post, "BOTTOMLEFT", AuctionHouseFrame, "BOTTOMLEFT", SELL_PANEL.left + 2, 39)
	end
end

local function SkinSellFrame(sellFrame)
	if not sellFrame or skinned[sellFrame] then return end
	skinned[sellFrame] = true
	Rect(sellFrame, SELL_PANEL.left, SELL_PANEL.top, SELL_PANEL.right, SELL_PANEL.bottom)
	StripInset(sellFrame)
	for _, key in ipairs({ "CreateAuctionTabLeft", "CreateAuctionTabMiddle", "CreateAuctionTabRight" }) do
		Hide(sellFrame[key])
	end
	-- Vanilla's "Create Auction" heading sits in the dark plate of the art.
	if sellFrame.CreateAuctionLabel then
		sellFrame.CreateAuctionLabel:SetFontObject(GameFontHighlightSmall)
		Point(sellFrame.CreateAuctionLabel, "CENTER", AuctionHouseFrame, "TOPLEFT", 115, -59)
	end

	if sellFrame.ItemDisplay then
		sellFrame.ItemDisplay:SetHeight(40)
		SkinSellItemDisplay(sellFrame.ItemDisplay)
	end
	if sellFrame.QuantityInput then SkinQuantityInput(sellFrame.QuantityInput) end
	if sellFrame.PriceInput then SkinPriceInput(sellFrame.PriceInput, SELL_PANEL.right - SELL_PANEL.left - 8) end
	if sellFrame.SecondaryPriceInput then SkinPriceInput(sellFrame.SecondaryPriceInput, SELL_PANEL.right - SELL_PANEL.left - 8) end
	if sellFrame.Duration then SkinDuration(sellFrame.Duration) end
	if sellFrame.Deposit then SkinPriceDisplay(sellFrame.Deposit) end
	if sellFrame.TotalPrice then SkinPriceDisplay(sellFrame.TotalPrice) end
	local check = sellFrame.BuyoutModeCheckButton
	if check and check.Text then
		check.Text:SetFontObject(GameFontNormalSmall)
	end

	ns.Hook(sellFrame, "Layout", StackSellFrame)
end

local function LayoutSell(frame)
	SkinSellFrame(frame.ItemSellFrame)
	SkinSellFrame(frame.CommoditiesSellFrame)
	for _, key in ipairs({ "ItemSellList", "CommoditiesSellList" }) do
		local list = frame[key]
		if list then
			Rect(list, 214, SELL_LIST_TOP, LIST_RIGHT, LIST_BOTTOM)
			SkinItemList(list, true)
			-- Retail puts the total / refresh above the list, which would be
			-- the title bar here; the Auction art's left bottom slot is free.
			if list.RefreshFrame then
				Point(list.RefreshFrame, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", BOTTOM_SLOTS[2] - 2, BOTTOM_BUTTON_Y)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Auctions tab: Auctions / Bids sub-tabs, summary column, lists
---------------------------------------------------------------------------

local function LayoutAuctions(frame)
	local auctions = frame.AuctionsFrame
	if not auctions then return end
	auctions:ClearAllPoints()
	auctions:SetAllPoints(frame)

	-- The sub-tabs sit on top of the summary column, in the strip.
	if auctions.Tabs then
		for _, tab in ipairs(auctions.Tabs) do
			SkinTab(tab, true)
		end
	end
	if auctions.AuctionsTab then
		Point(auctions.AuctionsTab, "TOPLEFT", frame, "TOPLEFT", 18, COLUMN_TOP + 32)
	end
	if auctions.BidsTab and auctions.AuctionsTab then
		Point(auctions.BidsTab, "TOPLEFT", auctions.AuctionsTab, "TOPRIGHT", -8, 0)
	end

	local summary = auctions.SummaryList
	if summary then
		Rect(summary, COLUMN_LEFT, COLUMN_TOP, COLUMN_RIGHT, COLUMN_BOTTOM)
		StripInset(summary)
		if summary.ScrollBox then
			Point(summary.ScrollBox, "TOPLEFT", summary, "TOPLEFT", 7, -4)
			summary.ScrollBox:SetPoint("BOTTOMRIGHT", summary, "BOTTOMRIGHT", -32, 4)
			SkinScrollBox(summary.ScrollBox)
		end
		if summary.ScrollBar and summary.ScrollBox then
			ns.SkinScrollBar(summary.ScrollBar)
			Point(summary.ScrollBar, "TOPLEFT", summary.ScrollBox, "TOPRIGHT", 6, 0)
			summary.ScrollBar:SetPoint("BOTTOMLEFT", summary.ScrollBox, "BOTTOMRIGHT", 6, 0)
		end
		CreateTrough(summary, COLUMN_TROUGH_DX)
	end

	for _, key in ipairs({ "AllAuctionsList", "BidsList" }) do
		local list = auctions[key]
		if list then
			Rect(list, LIST_LEFT, LIST_TOP, LIST_RIGHT, LIST_BOTTOM)
			SkinItemList(list, true)
		end
	end
	if auctions.ItemDisplay then
		Rect(auctions.ItemDisplay, 192, SUB_PANEL_TOP, 815, ITEM_LIST_TOP + 8)
		SkinItemHeader(auctions.ItemDisplay, -ITEM_LIST_TOP - 8 + SUB_PANEL_TOP)
	end
	for _, key in ipairs({ "ItemList", "CommoditiesList" }) do
		local list = auctions[key]
		if list then
			Rect(list, LIST_LEFT, ITEM_LIST_TOP, LIST_RIGHT, LIST_BOTTOM)
			SkinItemList(list, true)
			RefreshToStrip(list)
		end
	end

	-- Vanilla's 126px Cancel Auction sat in the Auction art's wide slot; the
	-- Browse art has three 80px slots, so it spans the first two exactly.
	if auctions.CancelAuctionButton then
		auctions.CancelAuctionButton:SetSize(BOTTOM_SLOTS[3] - BOTTOM_SLOTS[1], 22)
		Point(auctions.CancelAuctionButton, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", BOTTOM_SLOTS[2], BOTTOM_BUTTON_Y)
	end
	if auctions.BidFrame then
		if auctions.BidFrame.BidButton then ToSlot(auctions.BidFrame.BidButton, 1) end
		if auctions.BidFrame.BidAmount then
			Point(auctions.BidFrame.BidAmount, "BOTTOM", frame, "BOTTOM", -12, 18)
		end
	end
	if auctions.BuyoutFrame and auctions.BuyoutFrame.BuyoutButton then
		ToSlot(auctions.BuyoutFrame.BuyoutButton, 2)
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local function Skin()
	local frame = AuctionHouseFrame
	if not frame or art.pieces then return end

	for _, name in ipairs({ "Browse-TopLeft", "Browse-BotRight", "Auction-TopLeft", "Auction-BotRight" }) do
		if not ns.HasTexture(T.AH_ART .. name) then
			ns.Print("This client does not ship " .. T.AH_ART .. "*; the auction house keeps the retail look.")
			return
		end
	end

	ApplyFrameChrome(frame)
	SkinHeaders()
	HookItemBorders()
	LayoutSearchBar(frame)
	LayoutCategories(frame)
	LayoutBrowse(frame)
	LayoutItemBuy(frame)
	LayoutCommoditiesBuy(frame)
	LayoutSell(frame)
	LayoutAuctions(frame)
end

-- Blizzard_AuctionHouseUI is load-on-demand: it loads the first time an
-- auctioneer is talked to.
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, _, addon)
	if addon == "Blizzard_AuctionHouseUI" then
		self:UnregisterEvent("ADDON_LOADED")
		xpcall(Skin, geterrorhandler())
	end
end)

function module:Apply()
	if C_AddOns.IsAddOnLoaded("Blizzard_AuctionHouseUI") then
		Skin()
	else
		eventFrame:RegisterEvent("ADDON_LOADED")
	end
end
