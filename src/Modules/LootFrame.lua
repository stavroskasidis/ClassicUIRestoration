--[[
	Classic UI Restoration - Loot Window

	Restores the vanilla loot panel (1.12 LootFrame.xml): the
	Interface\LootFrame\UI-LootPanel artwork with the skull (fishing bobber
	for fishing loot) under its portrait ring, the "Items" title, the round
	close button, one UI-QuestItemNameFrame row per item and the Prev / Next
	page arrows at the bottom. Four items fit; with more, three are shown per
	page and the arrows page through them, exactly like the original.

	Retail's LootFrame is a ScrollingFlatPanelTemplate (Blizzard_UIPanels_Game\
	LootFrame.xml): a flat panel whose ScrollBox lists LootFrameItemElement /
	LootFrameMoneyElement rows of 46px. The frame and the rows are re-skinned
	in place so that Blizzard's looting, tooltips, quest markers, animations,
	"loot under mouse", the auto-loot slide-out and Edit Mode keep working:

	  * the panel's NineSlice, flat background and scroll bar are hidden and
	    the vanilla panel texture is drawn on the frame; the title and close
	    button are moved to their vanilla spots,
	  * the rows get the vanilla name plate, text size and hit area; the
	    retail card border, quality stripe and click-state glows are hidden.
	    The list view's spacing is set to -5 so the 46px rows sit 41px apart
	    like the vanilla buttons,
	  * ScrollingFlatPanelMixin:Resize (called from Open) and
	    UpdateShownState (Edit Mode) are hooked to enforce the vanilla size
	    and the rows-per-page; the Prev / Next arrows scroll the box by a
	    page (the mouse wheel steps one row).

	Everything touched is widget state; no Lua field is written on Blizzard's
	frames. This module is applied once at login (reload to switch off).
]]

local _, ns = ...
local T = ns.T
local Point, SetTexture = ns.Point, ns.SetTexture

local module = ns:RegisterModule({
	key = "lootframe",
	name = "Loot Window",
	tooltip = "Restores the vanilla loot panel: the classic panel artwork with the skull, the classic item rows and the Prev / Next page arrows.",
	live = false,
})

-- Vanilla geometry (1.12 LootFrame.xml). The panel texture is 256x256 with
-- transparent art in its right 70px, so the frame itself is 186 wide.
local ART_SIZE = 256
local WIDTH, HEIGHT = 186, 256
local MAX_ROWS = 4           -- rows when everything fits
local PAGE_ROWS = 3          -- rows per page once the arrows are needed
local ROW_STRIDE = 41        -- vanilla buttons are 37px, 4px apart
local FIRST_ICON_X, FIRST_ICON_Y = 24, -80
local NAME_FRAME_WIDTH, NAME_FRAME_HEIGHT = 130, 62
local TEXT_WIDTH, TEXT_HEIGHT = 93, 38

local art = {}   -- regions/buttons created by this module
local skinned = setmetatable({}, { __mode = "k" }) -- rows already re-skinned

---------------------------------------------------------------------------
-- Frame art
---------------------------------------------------------------------------

local function ApplyFrameArt(frame)
	if frame.NineSlice then frame.NineSlice:Hide() end
	if frame.Bg then frame.Bg:Hide() end

	-- The skull sits under the panel's portrait ring, so it goes on a lower
	-- layer than the panel art.
	art.portrait = frame:CreateTexture(nil, "BORDER")
	art.portrait:SetSize(58, 58)
	art.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)

	art.panel = frame:CreateTexture(nil, "ARTWORK")
	art.panel:SetTexture(T.LOOT_PANEL)
	art.panel:SetSize(ART_SIZE, ART_SIZE)
	art.panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)

	local title = frame.TitleContainer and frame.TitleContainer.TitleText
	if title then
		Point(title, "CENTER", frame, "TOPLEFT", ART_SIZE / 2 - 12, -(ART_SIZE / 2 - 102))
	end

	local close = frame.ClosePanelButton
	if close and ns.HasTexture(T.PANEL_CLOSE .. "Up") then
		close:SetSize(32, 32)
		Point(close, "CENTER", frame, "TOPRIGHT", -81 + (ART_SIZE - WIDTH), -26)
		close:SetNormalTexture(T.PANEL_CLOSE .. "Up")
		close:SetPushedTexture(T.PANEL_CLOSE .. "Down")
		close:SetDisabledTexture(T.PANEL_CLOSE .. "Disabled")
		close:SetHighlightTexture(T.PANEL_CLOSE .. "Highlight", "ADD")
	elseif close then
		Point(close, "CENTER", frame, "TOPRIGHT", -81 + (ART_SIZE - WIDTH), -26)
	end
end

local function UpdatePortrait()
	if IsFishingLoot() and ns.HasTexture(T.LOOT_FISHING) then
		SetTexture(art.portrait, T.LOOT_FISHING)
	else
		SetTexture(art.portrait, T.LOOT_SKULL)
	end
end

---------------------------------------------------------------------------
-- Item rows
---------------------------------------------------------------------------

-- Vanilla row (LootButtonTemplate): the icon button with the
-- UI-QuestItemNameFrame plate to its right and the name centred on it.
-- Blizzard re-runs Init on every slot change, so only widget state that Init
-- does not touch is set here; what it does touch is fixed in the Init hook.
local function SkinRow(row)
	if skinned[row] then return end
	skinned[row] = true

	local item = row.Item
	if item then
		-- Hit area: the icon plus the whole name plate.
		item:SetHitRectInsets(0, -(NAME_FRAME_WIDTH + 30 - item:GetWidth()), 0, 0)
	end

	if row.NameFrame then
		SetTexture(row.NameFrame, T.LOOT_NAME_FRAME)
		row.NameFrame:SetSize(NAME_FRAME_WIDTH, NAME_FRAME_HEIGHT)
		Point(row.NameFrame, "LEFT", item or row, "LEFT", 30, 0)
	end

	for _, key in ipairs({ "BorderFrame", "QualityStripe", "QualityText", "HighlightNameFrame", "PushedNameFrame" }) do
		local region = row[key]
		if region then
			-- Init/OnEnter show some of these again; alpha survives that.
			region:SetAlpha(0)
		end
	end

	if row.Text then
		row.Text:SetSize(TEXT_WIDTH, TEXT_HEIGHT)
		row.Text:SetJustifyH("LEFT")
		row.Text:SetJustifyV("MIDDLE")
		Point(row.Text, "LEFT", item or row, "RIGHT", 8, 0)
	end
end

-- After Blizzard's Init: the vanilla plate is not tinted with the item
-- quality (only the name is).
local function OnRowInit(row)
	SkinRow(row)
	if row.NameFrame then
		row.NameFrame:SetVertexColor(1, 1, 1)
	end
end

---------------------------------------------------------------------------
-- Layout & paging
---------------------------------------------------------------------------

local function GetRowHeight()
	local info = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("LootFrameBaseElementTemplate")
	return info and info.height or 46
end

-- Vanilla shows four rows, or three plus the page arrows when there are
-- more than four items.
local function GetRowsPerPage(frame)
	return frame.ScrollBox:GetDataProviderSize() > MAX_ROWS and PAGE_ROWS or MAX_ROWS
end

local function UpdatePageButtons()
	local scrollBox = LootFrame.ScrollBox
	local range = scrollBox:GetDerivedScrollRange()
	local offset = scrollBox:GetDerivedScrollOffset()
	local hasPrev = range > 0 and offset > 0.5
	local hasNext = range > 0 and offset < range - 0.5
	art.prevButton:SetShown(hasPrev)
	art.prevText:SetShown(hasPrev)
	art.nextButton:SetShown(hasNext)
	art.nextText:SetShown(hasNext)
end

local function ScrollPage(direction)
	local scrollBox = LootFrame.ScrollBox
	local offset = scrollBox:GetDerivedScrollOffset() + direction * PAGE_ROWS * ROW_STRIDE
	offset = math.max(0, math.min(offset, scrollBox:GetDerivedScrollRange()))
	scrollBox:ScrollToOffset(offset, ScrollBoxConstants.NoScrollInterpolation)
	UpdatePageButtons()
end

-- Applies the vanilla size after ScrollingFlatPanelMixin:Resize: the fixed
-- 186x256 panel with the list sized to the rows of the current page.
local function LayoutFrame(frame)
	local rows = GetRowsPerPage(frame)
	local rowHeight = GetRowHeight()
	local spacing = ROW_STRIDE - rowHeight

	frame:SetSize(WIDTH, HEIGHT)

	local scrollBox = frame.ScrollBox
	local view = scrollBox:GetView()
	if view and view.SetPadding then
		view:SetPadding(0, 0, 0, 0, spacing)
	end
	scrollBox:ClearAllPoints()
	-- The row's icon sits 5px in and 4px down from the row's corner.
	scrollBox:SetPoint("TOPLEFT", frame, "TOPLEFT", FIRST_ICON_X - 5, FIRST_ICON_Y + 4)
	scrollBox:SetSize(WIDTH - (FIRST_ICON_X - 5), rows * rowHeight + (rows - 1) * spacing)
	scrollBox:SetPanExtent(ROW_STRIDE) -- mouse wheel steps one row

	if frame.ScrollBar then
		frame.ScrollBar:Hide()
	end
	UpdatePageButtons()
end

local function CreatePageButton(frame, upDown, direction)
	local prefix = upDown == "Up" and T.CHAT_SCROLL_UP or T.CHAT_SCROLL_DOWN
	if not ns.HasTexture(prefix .. "Up") then
		prefix = upDown == "Up" and T.SCROLL_UP or T.SCROLL_DOWN
	end
	local button = CreateFrame("Button", nil, frame)
	button:SetSize(32, 32)
	button:SetNormalTexture(prefix .. "Up")
	button:SetPushedTexture(prefix .. "Down")
	button:SetDisabledTexture(prefix .. "Disabled")
	button:SetHighlightTexture(T.MOUSE_HIGHLIGHT, "ADD")
	button:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		ScrollPage(direction)
	end)
	button:Hide()
	return button
end

local function CreatePageBar(frame)
	art.prevButton = CreatePageButton(frame, "Up", -1)
	art.prevButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 25, 16)
	art.prevText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	art.prevText:SetText(PREV)
	art.prevText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 57, 27)
	art.prevText:Hide()

	art.nextButton = CreatePageButton(frame, "Down", 1)
	art.nextButton:SetPoint("LEFT", art.prevButton, "RIGHT", 86, 0)
	art.nextText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	art.nextText:SetText(NEXT)
	art.nextText:SetPoint("RIGHT", art.prevText, "LEFT", 85, 0)
	art.nextText:Hide()

	-- The mouse wheel scrolls the list too; keep the arrows in step.
	frame.ScrollBox:RegisterCallback(BaseScrollBoxEvents.OnScroll, UpdatePageButtons, art)
	frame.ScrollBox:RegisterCallback(BaseScrollBoxEvents.OnLayout, UpdatePageButtons, art)
end

---------------------------------------------------------------------------
-- Temporary diagnostics ("/cuir loot"): which legacy files this client has
-- and how the frame/rows ended up. Remove once the look is confirmed.
---------------------------------------------------------------------------

function ns:DebugLoot()
	for _, path in ipairs({ T.LOOT_PANEL, T.PANEL_CLOSE .. "Up", T.LOOT_NAME_FRAME, T.LOOT_SKULL, T.LOOT_FISHING, T.CHAT_SCROLL_UP .. "Up", T.SCROLL_UP .. "Up" }) do
		print(path, ns.HasTexture(path) and "|cff00ff00found|r" or "|cffff0000missing|r")
	end
	local frame = LootFrame
	print(string.format("LootFrame %.0fx%.0f shown=%s rows=%d", frame:GetWidth(), frame:GetHeight(), tostring(frame:IsShown()), frame.ScrollBox:GetDataProviderSize()))
	print(string.format("ScrollBox %.0fx%.0f offset=%.0f range=%.0f", frame.ScrollBox:GetWidth(), frame.ScrollBox:GetHeight(), frame.ScrollBox:GetDerivedScrollOffset(), frame.ScrollBox:GetDerivedScrollRange()))
	frame.ScrollBox:ForEachFrame(function(row)
		local nf = row.NameFrame
		local point, rel, relPoint, x, y = nf:GetPoint(1)
		print(string.format("row %s skinned=%s name=%s %.0fx%.0f %s->%s %.0f,%.0f text=%.0fx%.0f",
			tostring(row.Text and row.Text:GetText()), tostring(skinned[row]), tostring(nf:GetAtlas() or nf:GetTexture()), nf:GetWidth(), nf:GetHeight(),
			point or "?", (rel == row.Item) and "Item" or tostring(rel and rel:GetName() or rel), x or 0, y or 0,
			row.Text and row.Text:GetWidth() or 0, row.Text and row.Text:GetHeight() or 0))
	end)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function module:Apply()
	local frame = LootFrame
	if not frame or not frame.ScrollBox then return end

	if not ns.HasTexture(T.LOOT_PANEL) then
		ns.Print("This client does not ship " .. T.LOOT_PANEL .. "; the loot window keeps the retail look.")
		return
	end

	ApplyFrameArt(frame)
	CreatePageBar(frame)

	-- Retail fades the list's edges with shadow textures while it scrolls.
	local scrollBox = frame.ScrollBox
	if scrollBox.GetUpperShadowTexture then
		scrollBox:GetUpperShadowTexture():SetAlpha(0)
		scrollBox:GetLowerShadowTexture():SetAlpha(0)
	end

	-- Rows are created on demand by the list view from these mixins; the
	-- money row uses the base Init, the item row calls it.
	ns.Hook(LootFrameElementMixin, "Init", OnRowInit)

	ns.Hook(frame, "Resize", LayoutFrame)
	ns.Hook(frame, "UpdateShownState", function(self)
		-- Edit Mode shows the empty panel at its maximum height.
		if self.isInEditMode then
			self:SetSize(WIDTH, HEIGHT)
		end
	end)
	frame:HookScript("OnShow", UpdatePortrait)

	if frame:IsShown() then
		LayoutFrame(frame)
		UpdatePortrait()
	end
end
