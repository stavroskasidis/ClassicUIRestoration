--[[
	Forevermore Classic UI - Looking For Group window (WoW Forever only)

	Restores the classic Looking For Group window: the Classic Era
	premade group finder (Blizzard_GroupFinder_VanillaStyle, Classic\ XML),
	drawn with the 3.3 LFG art Classic Era reuses: the UI-LFG-FRAME panel
	with the eye portrait (UI-LFG-PORTRAIT) in its ring, the role icons
	(UI-LFG-ICON-ROLES) in the dark band under the title, the page in the
	panel's window and the Back / List Self buttons in the band under it.
	The browse and who pages get the UI-LFR-FRAME-MAIN top, as Classic Era's
	browse page does. The page tabs go under the frame.

	Forever loads the same addon with its Mainline\ XML: LFGParentFrame is
	a 458x535 frame whose pages (LFGListingFrame, LFGBrowseFrame and
	Forever's own LFGWhoListFrame) are PortraitFrameTemplates covering it,
	with modern role atlases, large category buttons, a big eye portrait and
	three icon tabs down its right side (LargeSideTabButtonTemplate; the
	bottom tabs Tab1-3 are hidden on every UpdateTabs and their click
	handler calls a function Forever does not define). The frame is
	re-skinned in place:

	  * LFGParentFrame is sized to the classic art (so the panel manager
	    places the next window at its edge) and the art is drawn on it from
	    ns.ArtOrigin; the pages' frames, backgrounds, insets and scroll lines
	    are faded and their titles moved to the title bar,
	  * the listing page's role, new player friendly and group role buttons
	    get the classic role icons and Classic Era's layout; its category
	    buttons and activity list go into the window (the category buttons,
	    drawn at their atlas size, are scaled down to Classic Era's width),
	  * the browse page's list is managed by a ScrollBox behaviour that
	    re-anchors it to the page's corners, with the offsets in its
	    AnchorOffset* fields, whenever its scroll bar shows or hides; the
	    page is placed so that those anchors put the (scaled down) list in
	    the window. The who page's list is scaled and placed directly. The
	    scroll bars become the classic knob bars,
	  * the icon tabs are Blizzard's own tab frames, moved under the frame
	    and drawn as the vanilla tabs (ns.CharacterWindow.SkinTab), so a
	    click stays Blizzard's.

	Only widget state is touched (sizes, anchors, scales, textures, alpha);
	no Lua field is written on Blizzard's frames, whose views, extents and
	anchors lists are left alone. Nothing here is protected. The addon is
	load-on-demand: it is skinned when it loads. Applied once at login
	(reload to switch off).
]]

local _, ns = ...
if not ns.IS_FOREVER then return end
local T = ns.T
local Point, SetTexture = ns.Point, ns.SetTexture

T.LFG_FRAME            = "Interface\\LFGFrame\\UI-LFG-FRAME"
T.LFR_FRAME            = "Interface\\LFGFrame\\UI-LFR-FRAME-MAIN"
T.LFG_PORTRAIT         = "Interface\\LFGFrame\\UI-LFG-PORTRAIT"
T.LFG_ROLES            = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
T.LFG_ROLE_BACKGROUNDS = "Interface\\LFGFrame\\UI-LFG-ICONS-ROLEBACKGROUNDS"
-- T.TRAINER_ART (TrainerFrame.lua, loaded earlier) holds the horizontal bar.

local ADDON = "Blizzard_GroupFinder_VanillaStyle"

local module = ns:RegisterModule({
	key = "lfgframe",
	name = "Looking For Group",
	tooltip = "Restores the classic Looking For Group window: the classic LFG panel with the eye in its ring, the classic role icons, the categories and listings in the panel's window, and the page tabs under it.",
	live = false,
})

-- Classic Era geometry (Classic\Blizzard_LFGVanilla_*.xml), offsets from
-- the top-left corner of its 384x512 frame, where UI-LFG-FRAME is drawn.
-- The art's border runs from 13 to 351 across and 13 to 437 down.
local FRAME_WIDTH, FRAME_HEIGHT = 337, 424          -- the border's size less ns.CLASSIC_ART_X / Y: the panel
local TOP_ROWS = 121                                -- the browse page's top (UI-LFR-FRAME-MAIN rows 0-120)
local WINDOW_X, WINDOW_Y, WINDOW_WIDTH, WINDOW_HEIGHT = 22, -128, 324, 282 -- the pages' content (the art's hole)
local PORTRAIT_X, PORTRAIT_Y, PORTRAIT_SIZE = 9, -5, 64
local EYE_X, EYE_Y = 39.5, -35.5                    -- the ring's centre
local CLOSE_X, CLOSE_Y = 339, -25                   -- centre of the close button's hole
local TITLE_Y = -17
local ROLES_X, ROLES_Y, ROLE_SIZE, ROLE_GAP = 67, -60, 48, 25
local ROLE_BACKGROUND_SIZE = 80
local ROLE_BACKGROUND_ALPHA = { TANK = 0.6, HEALER = 0.4, DAMAGER = 0.6 }
local FRIENDLY_RIGHT = 337                          -- the new player friendly button's right edge
local OPTIONS_RIGHT, OPTIONS_Y = 344, -44
local CATEGORY_WIDTH = 287                          -- LFGListingCategoryTemplate
local BUTTON_LEFT, BUTTON_RIGHT, BUTTON_BOTTOM, BUTTON_HEIGHT = 19, 344, 79, 22 -- from the frame's bottom (512)
local COMMENT_WIDTH = 285
local BAR_Y = 80                                    -- the activity view's bars (centres): above the comment box, from its bottom,
local BAR_TOP_Y = -41                               -- and under the level range checkbox, from its top (Blizzard's BarTop: -42)
-- The row over the activity list: the playstyle dropdown (1.60.1 build
-- 70170, 210px, laid out for Blizzard's 444px view) on its left and the
-- level range checkbox, its label wrapped to LEVEL_RANGES_WIDTH, on its right.
local PLAYSTYLE_X, ROW_Y = 8, -22.5                 -- the row's centre (Blizzard's dropdown: 25px at -10)
local LEVEL_RANGES_RIGHT, LEVEL_RANGES_WIDTH = -30, 72 -- the label's right edge (the checkbox follows), from the view's right
-- The browse page's dropdowns and the who page's search box are centred in
-- the top band (rows 36-120 of the art, between its rims).
local DROPDOWN_X, BAND_Y = 26, -78.5
-- The browse and who lists: their rows (Blizzard's 52px / 69px cards) are
-- drawn at LIST_SCALE, in the window less the scroll bar.
local LIST_LEFT, LIST_TOP, LIST_RIGHT, LIST_BOTTOM = 22, -130, 322, -408
local LIST_SCALE = 0.75
local SCROLLBAR_GAP = 4
local WHO_SEARCH_X, WHO_SEARCH_WIDTH = 28, 190      -- the search button and filter follow
local TOTALS_X, TOTALS_Y = 183, -424                -- the middle cell of the button band
-- Tabs (1.12 CharacterFrameTabButtonTemplate), the first one's top left.
-- They hang from under the frame's bottom rim (art rows 433-439: its edge
-- and shadow), which is drawn again over them, so the selected tab's 5px
-- rise goes in under the rim.
local TAB_X, TAB_Y = 16, -438
local RIM_TOP, RIM_BOTTOM = 433, 440

local frame  -- LFGParentFrame
local origin -- the art's top-left corner (ns.ArtOrigin), which everything is placed from
local art = {}

local function Fade(region)
	if region then region:SetAlpha(0) end
end

---------------------------------------------------------------------------
-- Frame art
---------------------------------------------------------------------------

-- The art: the top rows (per page), the rest of UI-LFG-FRAME's top half and
-- its bottom half, with the window's background between them (the top half
-- is opaque behind the window's first rows, the bottom half has the hole).
local function CreateArt()
	local function Piece(top, bottom, y, sublevel)
		local texture = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
		SetTexture(texture, T.LFG_FRAME, 0, 1, top / 512, bottom / 512)
		texture:SetSize(512, bottom - top)
		texture:SetPoint("TOPLEFT", origin, "TOPLEFT", 0, y)
		return texture
	end
	art.top = Piece(0, TOP_ROWS, 0, -1)
	art.middle = Piece(TOP_ROWS, 256, -TOP_ROWS, -1)
	art.bottom = Piece(256, 512, -256, 1)

	art.background = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
	if not ns.SetAtlas(art.background, "groupfinder-background-classic") then
		ns.SetAtlas(art.background, "groupfinder-background")
	end
	art.background:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	art.background:SetPoint("TOPLEFT", origin, "TOPLEFT", WINDOW_X, WINDOW_Y - 1)

	-- Under the art: its ring cuts the square portrait round.
	if ns.HasTexture(T.LFG_PORTRAIT) then
		art.portrait = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
		art.portrait:SetTexture(T.LFG_PORTRAIT)
		art.portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
		art.portrait:SetPoint("TOPLEFT", origin, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
	end
end

-- The listing page has UI-LFG-FRAME's own top, the browse and who pages
-- the raid browser's (Classic Era's browse page), 1px further left.
local function SetTopArt(lfr)
	lfr = lfr and ns.HasTexture(T.LFR_FRAME)
	SetTexture(art.top, lfr and T.LFR_FRAME or T.LFG_FRAME, 0, 1, 0, TOP_ROWS / 512)
	Point(art.top, "TOPLEFT", origin, "TOPLEFT", lfr and -1 or 0, 0)
end

-- The parts of a page's PortraitFrameTemplate; its title goes to the title
-- bar. Every texture of the page itself goes: the browse page's own Bg (a
-- stone strip) takes the template's Bg key, which leaves the template's
-- background out of reach by key.
local function SkinPageChrome(page)
	Fade(page.NineSlice)
	for _, region in ipairs({ page:GetRegions() }) do
		if region:IsObjectType("Texture") then region:SetAlpha(0) end
	end
	if page.PortraitContainer then page.PortraitContainer:SetAlpha(0) end
	local title = page.TitleContainer and page.TitleContainer.TitleText
	if title then
		Point(title, "TOP", origin, "TOP", 0, TITLE_Y)
	end
end

local function SkinFrame()
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	frame:SetHitRectInsets(0, 0, 0, 0)
	origin = ns.ArtOrigin(frame)
	CreateArt()

	local close = LFGParentFrameCloseButton
	if close then
		ns.SkinCloseButton(close)
		Point(close, "CENTER", origin, "TOPLEFT", CLOSE_X, CLOSE_Y)
	end

	-- Blizzard's eye: its framed big eye shows while no listing is up and
	-- the animated eye while one is; the frame goes (the classic portrait
	-- shows instead), the animations stay, in the ring.
	local eye = LFGParentFramePortrait
	if eye then
		Point(eye, "CENTER", origin, "TOPLEFT", EYE_X, EYE_Y)
		if art.portrait then Fade(eye.texture) end
	end

	for _, page in ipairs({ LFGListingFrame, LFGBrowseFrame, LFGWhoListFrame }) do
		SkinPageChrome(page)
	end
	LFGListingFrame:HookScript("OnShow", function() SetTopArt(false) end)
	LFGBrowseFrame:HookScript("OnShow", function() SetTopArt(true) end)
	LFGWhoListFrame:HookScript("OnShow", function() SetTopArt(true) end)
	SetTopArt(not LFGListingFrame:IsShown())
end

-- A button in the band under the window (19px in, 79px up from the 512px
-- frame's bottom); `right` places it from the right instead.
local function PlaceBottomButton(button, right)
	if not button then return end
	button:SetHeight(BUTTON_HEIGHT)
	if right then
		Point(button, "BOTTOMRIGHT", origin, "BOTTOMLEFT", BUTTON_RIGHT, BUTTON_BOTTOM)
	else
		Point(button, "BOTTOMLEFT", origin, "BOTTOMLEFT", BUTTON_LEFT, BUTTON_BOTTOM)
	end
end

-- A skinned scroll bar next to its list (Blizzard anchors it with its own
-- offsets; the classic bar is wider).
local function PlaceScrollBar(scrollBar, scrollBox)
	if not scrollBar then return end
	ns.SkinScrollBar(scrollBar)
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", SCROLLBAR_GAP, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", SCROLLBAR_GAP, 0)
end

---------------------------------------------------------------------------
-- Listing page
---------------------------------------------------------------------------

-- A role button with Classic Era's icon (UI-LFG-ICON-ROLES) on its role's
-- background, at Classic Era's size. The not-recommended cover is already
-- the classic file.
local function SkinRoleButton(button, role)
	if not button then return end
	button:SetSize(ROLE_SIZE, ROLE_SIZE)
	button:SetNormalTexture(T.LFG_ROLES)
	local normal = button:GetNormalTexture()
	if normal then
		normal:ClearAllPoints()
		normal:SetAllPoints(button)
		normal:SetTexCoord(GetTexCoordsForRole(role))
	end
	local background = button.Background
	if background and role ~= "GUIDE" then
		background:SetTexture(T.LFG_ROLE_BACKGROUNDS)
		background:SetTexCoord(GetBackgroundTexCoordsForRole(role))
		background:SetSize(ROLE_BACKGROUND_SIZE, ROLE_BACKGROUND_SIZE)
		background:SetAlpha(ROLE_BACKGROUND_ALPHA[role] or 0.6)
	end
end

local function SkinRoles(page)
	local solo = page.SoloRoleButtons
	if solo then
		solo:SetSize(3 * ROLE_SIZE + 2 * ROLE_GAP, ROLE_SIZE)
		Point(solo, "TOPLEFT", origin, "TOPLEFT", ROLES_X, ROLES_Y)
		SkinRoleButton(solo.Tank, "TANK")
		SkinRoleButton(solo.Healer, "HEALER")
		SkinRoleButton(solo.DPS, "DAMAGER")
		if solo.Tank and solo.Healer and solo.DPS then
			Point(solo.Tank, "TOPLEFT", solo, "TOPLEFT", 0, 0)
			Point(solo.Healer, "LEFT", solo.Tank, "RIGHT", ROLE_GAP, 0)
			Point(solo.DPS, "LEFT", solo.Healer, "RIGHT", ROLE_GAP, 0)
		end
	end

	-- In a group: the role icon (Blizzard sets its tex coords from the
	-- role), the role check button and the role dropdown.
	local group = page.GroupRoleButtons
	if group then
		group:SetSize(3 * ROLE_SIZE + 2 * ROLE_GAP, ROLE_SIZE)
		Point(group, "TOPLEFT", origin, "TOPLEFT", ROLES_X, ROLES_Y)
		local icon = group.RoleIcon
		if icon then
			icon:SetSize(ROLE_SIZE, ROLE_SIZE)
			Point(icon, "TOPRIGHT", group, "TOPRIGHT", 0, -2)
			if icon.Background then
				icon.Background:SetSize(ROLE_BACKGROUND_SIZE, ROLE_BACKGROUND_SIZE)
			end
		end
		if group.RolePollButton then
			Point(group.RolePollButton, "TOPLEFT", group, "TOPLEFT", 6, 2)
		end
	end

	-- The new player friendly toggle: Classic Era's guide icon with the
	-- newcomer badge on its corner.
	local friendly = page.NewPlayerFriendlyButton
	if friendly then
		SkinRoleButton(friendly, "GUIDE")
		Point(friendly, "TOPRIGHT", origin, "TOPLEFT", FRIENDLY_RIGHT, ROLES_Y)
		if friendly.CheckButton then
			Point(friendly.CheckButton, "BOTTOMLEFT", friendly, "BOTTOMLEFT", -5, -5)
		end
		for _, region in ipairs({ friendly:GetRegions() }) do
			if region:IsObjectType("Texture") and region:GetAtlas() == "newplayerchat-chaticon-newcomer" then
				region:SetSize(20, 20)
				Point(region, "BOTTOMRIGHT", friendly, "BOTTOMRIGHT", 1, -1)
			end
		end
	end
end

-- The classic horizontal bar (UI-ClassTrainer-HorizontalBar, as Classic
-- Era's activity view has it) across the view, centred `y` above its
-- `relativePoint` (BOTTOMLEFT / TOPLEFT). Returns its three pieces.
local function CreateBar(view, relativePoint, y)
	local file = T.TRAINER_ART and (T.TRAINER_ART .. "HorizontalBar")
	if not (file and ns.HasTexture(file)) then return end
	local function Piece(width, left, right, top, bottom)
		local texture = view:CreateTexture(nil, "OVERLAY")
		SetTexture(texture, file, left, right, top, bottom)
		texture:SetSize(width, 16)
		return texture
	end
	local left = Piece(WINDOW_WIDTH - 71, 0, 1, 0, 0.25)
	left:SetPoint("LEFT", view, relativePoint, -4, y)
	local middle = Piece(4, 0.046875, 0.0625, 0, 0.25)
	middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
	local right = Piece(75, 0, 0.29296875, 0.25, 0.5)
	right:SetPoint("LEFT", middle, "RIGHT", 0, 0)
	return { left, middle, right }
end

-- The bars where Blizzard has its scroll lines: under the level range
-- checkbox (always shown, like Blizzard's BarTop) and above the comment box.
local function CreateActivityBars(view)
	CreateBar(view, "TOPLEFT", BAR_TOP_Y)
	local bottom = CreateBar(view, "BOTTOMLEFT", BAR_Y)
	if not bottom then return end

	-- An activity group that picks its activities itself shows only the
	-- comment box (Blizzard hides the list and its bar).
	local scrollBox = view.ScrollBox
	local function Update()
		local shown = scrollBox:IsShown()
		for _, piece in ipairs(bottom) do
			piece:SetShown(shown)
		end
	end
	scrollBox:HookScript("OnShow", Update)
	scrollBox:HookScript("OnHide", Update)
	Update()
end

local function SkinListing()
	local page = LFGListingFrame
	Fade(page.RolesSection)
	Fade(page.Inset)
	Fade(page.DividerFrame)
	SkinRoles(page)

	-- The category buttons are drawn at the cover atlas's size; the view is
	-- scaled so that they are as wide as Classic Era's.
	local categories = page.CategoryView
	if categories then
		local info = C_Texture.GetAtlasInfo("groupfinder-button-cover")
		local scale = info and info.width > CATEGORY_WIDTH and CATEGORY_WIDTH / info.width or 1
		categories:SetScale(scale)
		categories:ClearAllPoints()
		categories:SetPoint("TOPLEFT", origin, "TOPLEFT", WINDOW_X / scale, WINDOW_Y / scale)
		categories:SetSize(WINDOW_WIDTH / scale, WINDOW_HEIGHT / scale)
	end

	-- Blizzard's ScrollBox anchors are offsets from this view (a list under
	-- the level range checkbox, the comment box at its bottom).
	local view = page.ActivityView
	if view then
		Point(view, "TOPLEFT", origin, "TOPLEFT", WINDOW_X, WINDOW_Y)
		view:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
		Fade(view.BarTop)
		Fade(view.BarMiddle)
		-- Its edit box and instructions were sized to it when it loaded
		-- (UIPanelInputScrollFrame_OnLoad).
		local comment = view.Comment
		if comment then
			comment:SetWidth(COMMENT_WIDTH)
			if comment.EditBox then
				comment.EditBox:SetWidth(COMMENT_WIDTH - 18)
				if comment.EditBox.Instructions then comment.EditBox.Instructions:SetWidth(COMMENT_WIDTH) end
			end
		end
		if view.ScrollBox then
			PlaceScrollBar(view.ScrollBar, view.ScrollBox)
			CreateActivityBars(view)
		end
		-- Both do not fit the classic window side by side: the checkbox's
		-- label goes on two lines. Its label is anchored by its right edge
		-- to the frame's, with the checkbox after it.
		local dropdown, levelRanges = view.PlayStyleDropdown, view.LevelRangesCheckbox
		if dropdown and levelRanges and levelRanges.Text then
			Point(dropdown, "LEFT", view, "TOPLEFT", PLAYSTYLE_X, ROW_Y)
			Point(levelRanges, "RIGHT", view, "TOPRIGHT", LEVEL_RANGES_RIGHT, ROW_Y)
			levelRanges.Text:SetWidth(LEVEL_RANGES_WIDTH)
			levelRanges.Text:SetJustifyH("RIGHT")
		end
	end

	if page.LockedView then
		Point(page.LockedView, "TOPLEFT", origin, "TOPLEFT", WINDOW_X, WINDOW_Y)
	end
	PlaceBottomButton(page.BackButton)
	PlaceBottomButton(page.PostButton, true)
end

---------------------------------------------------------------------------
-- Browse page
---------------------------------------------------------------------------

local function SkinBrowse()
	local page = LFGBrowseFrame
	Fade(page.Inset)
	Fade(page.BarTop)
	Fade(page.BarMiddle)
	-- Hidden; the searching spinner and the "no results" text are anchored
	-- to it.
	if page.BackgroundArt then
		Point(page.BackgroundArt, "TOPLEFT", origin, "TOPLEFT", WINDOW_X, WINDOW_Y)
		page.BackgroundArt:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	end

	-- The list's anchors are the page's corners plus its AnchorOffset*
	-- values (in the list's scaled units), re-applied by Blizzard whenever
	-- the scroll bar shows or hides; the page is placed so that the list
	-- (with the bar) fills LIST_*.
	local scrollBox = page.ScrollBox
	if scrollBox then
		local s = LIST_SCALE
		scrollBox:SetScale(s)
		local left = scrollBox.AnchorOffsetLeft or 0
		local top = scrollBox.AnchorOffsetTop or 0
		local right = (scrollBox.AnchorOffsetRight or 0) - (scrollBox.ScrollBarWidth or 0)
		local bottom = scrollBox.AnchorOffsetBottom or 0
		page:ClearAllPoints()
		page:SetPoint("TOPLEFT", origin, "TOPLEFT", LIST_LEFT - left * s, LIST_TOP - top * s)
		page:SetPoint("BOTTOMRIGHT", origin, "TOPLEFT", LIST_RIGHT - right * s, LIST_BOTTOM - bottom * s)
		PlaceScrollBar(page.ScrollBar, scrollBox)
	end

	if page.CategoryDropdown then
		Point(page.CategoryDropdown, "LEFT", origin, "TOPLEFT", DROPDOWN_X, BAND_Y)
		if page.ActivityDropdown then
			Point(page.ActivityDropdown, "LEFT", page.CategoryDropdown, "RIGHT", 5, 0)
			if page.RefreshButton then
				Point(page.RefreshButton, "LEFT", page.ActivityDropdown, "RIGHT", -1, 0)
			end
		end
	end
	if page.OptionsButton then
		Point(page.OptionsButton, "TOPRIGHT", origin, "TOPLEFT", OPTIONS_RIGHT, OPTIONS_Y)
	end
	PlaceBottomButton(page.SendMessageButton)
	PlaceBottomButton(page.GroupInviteButton, true)
end

---------------------------------------------------------------------------
-- Who page (Forever's own; Classic Era has its who list in the social
-- window)
---------------------------------------------------------------------------

local function SkinWhoList()
	local page = LFGWhoListFrame
	Fade(page.BackgroundArt)
	Fade(page.headerBackground)
	Fade(page.insideFrame)
	Fade(page.BarTop)
	Fade(page.BarMiddle)

	-- The search box, with the search button and the filter dropdown
	-- Blizzard anchors after it, in the top band. Blizzard sizes the box's
	-- height to its instructions' lines (up to two) on every show; they are
	-- kept to one line in the narrower box (Blizzard truncates them and
	-- shows the whole text in a tooltip), and the box is centred on the
	-- band's line of controls.
	local editBox = page.EditBox
	if editBox then
		Point(editBox, "LEFT", origin, "TOPLEFT", WHO_SEARCH_X, BAND_Y)
		editBox:SetWidth(WHO_SEARCH_WIDTH)
		if editBox.Instructions then editBox.Instructions:SetMaxLines(1) end
	end

	local scrollBox = page.ScrollBox
	if scrollBox then
		local s = LIST_SCALE
		scrollBox:SetScale(s)
		scrollBox:ClearAllPoints()
		scrollBox:SetPoint("TOPLEFT", origin, "TOPLEFT", LIST_LEFT / s, LIST_TOP / s)
		scrollBox:SetSize((LIST_RIGHT - LIST_LEFT) / s, (LIST_TOP - LIST_BOTTOM) / s)
		PlaceScrollBar(page.ScrollBar, scrollBox)
	end

	if page.WhoFrameTotals then
		Point(page.WhoFrameTotals, "CENTER", origin, "TOPLEFT", TOTALS_X, TOTALS_Y)
	end
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

-- Blizzard's icon tabs by page, with the labels of Classic Era's bottom
-- tabs. The listing tab reads "Edit Listing" while a listing is up
-- (Blizzard keeps its hidden Tab1's text current).
local TABS = {
	{ key = "ListingTab", label = function() return frame.Tab1 and frame.Tab1:GetText() or LFG_LIST_TAB_1 end },
	{ key = "BrowsingTab", label = function() return LFG_LIST_TAB_2 end },
	{ key = "WhoListingTab", label = function() return LFG_LIST_TAB_3 end },
}

local function LayoutTabs()
	local CW = ns.CharacterWindow
	local previous
	for _, info in ipairs(TABS) do
		local tab = frame[info.key]
		if tab then
			local label = info.label() or ""
			local skin = CW.SkinTab(tab, label)
			skin.text:SetText(label)
			local width = math.max(1, math.ceil(skin.text:GetStringWidth()) - 2 * CW.TAB_TEXT_INTO_END)
			skin.middle:SetWidth(width)
			tab:SetSize(width + 2 * CW.TAB_END, CW.TAB_HEIGHT)
			if previous then
				Point(tab, "TOPLEFT", previous, "TOPRIGHT", -CW.TAB_OVERLAP, 0)
			else
				Point(tab, "TOPLEFT", origin, "TOPLEFT", TAB_X, TAB_Y)
			end
			CW.UpdateTab(tab)
			previous = tab
		end
	end
end

-- The frame's bottom rim again, on a frame over the tabs.
local function CreateTabRim()
	local rim = CreateFrame("Frame", nil, frame)
	local level = frame:GetFrameLevel()
	for _, info in ipairs(TABS) do
		local tab = frame[info.key]
		if tab then level = math.max(level, tab:GetFrameLevel()) end
	end
	rim:SetFrameLevel(level + 1)
	rim:SetSize(512, RIM_BOTTOM - RIM_TOP)
	rim:SetPoint("TOPLEFT", origin, "TOPLEFT", 0, -RIM_TOP)
	local texture = rim:CreateTexture(nil, "ARTWORK")
	SetTexture(texture, T.LFG_FRAME, 0, 1, RIM_TOP / 512, RIM_BOTTOM / 512)
	texture:SetAllPoints(rim)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local function Skin()
	frame = LFGParentFrame
	if not (frame and LFGListingFrame and LFGBrowseFrame and LFGWhoListFrame) then return end
	if not ns.HasTexture(T.LFG_FRAME) then
		ns.Print("This client does not ship " .. T.LFG_FRAME .. "; the Looking For Group window keeps the retail look.")
		return
	end
	SkinFrame()
	SkinListing()
	SkinBrowse()
	SkinWhoList()
	if ns.CharacterWindow and ns.CharacterWindow.SkinTab then
		ns.Hook(frame, "UpdateTabs", LayoutTabs)
		LayoutTabs()
		CreateTabRim()
	end
end

function module:Apply()
	if C_AddOns.IsAddOnLoaded(ADDON) then
		Skin()
		return
	end
	local loader = CreateFrame("Frame")
	loader:RegisterEvent("ADDON_LOADED")
	loader:SetScript("OnEvent", function(self, _, name)
		if name == ADDON then
			self:UnregisterEvent("ADDON_LOADED")
			xpcall(Skin, geterrorhandler())
		end
	end)
end
