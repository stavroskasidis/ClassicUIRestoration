--[[
	Forevermore Classic UI - Professions window (WoW Forever only)

	Restores the vanilla trade skill window (1.12 Blizzard_TradeSkillUI.xml):
	the 384x512 panel (the UI-ClassTrainer-* pieces with UI-TradeSkill-BotLeft)
	with the player's portrait in its ring, the profession's rank on the
	classic skill bar under the title, the compact list of 16px recipe rows
	coloured by difficulty (orange, yellow, green, grey) with the selected row
	on a tinted highlight bar and the categories as +/- header rows, and under
	the list the selected recipe's icon, name, required tools, cooldown and
	reagents (two columns of the classic item buttons with "have / need"),
	the Create All / - n + / Create / Exit row at the bottom and the classic
	knob scroll bars.

	Forever's ProfessionsFrame (Blizzard_Professions, load-on-demand) is the
	retail professions frame with the camelot overlay: a 673x594 PortraitFrame
	with a crafting page (recipe list, schematic form, create controls) and
	a professions overview page (BookPage), switched by the icon tabs down its
	right edge. The crafting page is re-skinned in place while it is shown;
	the overview page keeps Blizzard's look:

	  * the vanilla art is drawn where the other windows open (the frame is
	    registered 35px right of the panel spot and lifted higher on small
	    screens, see UpdateOrigin) and Blizzard's border,
	    background and portrait are faded; the frame keeps Blizzard's size
	    (the panel manager positions it by its registered width) and takes
	    the mouse only over the art. The title and the side tabs move
	    to the vanilla frame's title bar and right edge; the round classic
	    close button and Exit are this module's (secure buttons that click
	    Blizzard's close button, so closing works in combat), Blizzard's
	    close button is faded while they show. The frame is protected (the
	    overview page's spell buttons are secure), so its hit rect only
	    changes out of combat,
	  * the recipe list stays Blizzard's ScrollBox, so selecting a recipe,
	    collapsing a category, favourites and links stay Blizzard's own,
	    clicks. The list is scaled down (rowScale) and the rows' text is
	    enlarged back; the rows are flattened (Blizzard indents each tree
	    level) and re-coloured after each Initialize. Vanilla's gapless
	    16px rows need the view's element heights and spacing (its extent
	    calculator and padding, Lua state Blizzard's layout reads, so every
	    layout runs tainted). With the mouse and keyboard nothing protected
	    follows a layout (tested 2026-09-27: the K binding, the spellbook /
	    talents and crafting in combat work without blocked actions), but
	    the controller UI lays the list out from its own code and then sets
	    override bindings, which are Blizzard-only (closing the window was
	    blocked, 2026-10-01). With the controller UI on, the view keeps
	    Blizzard's extents: recipe rows are still 16px, category rows a
	    little taller, with Blizzard's small gap after each category. The
	    choice is made when the window is skinned (taking the calculator
	    off again would be another write); a later switch of the input
	    style asks for a reload,
	  * the vanilla "All" tab collapses / expands every category through
	    Blizzard's data provider (its nodes' collapsed state, read by every
	    layout: with the controller UI on, the tab only shows the state),
	  * the schematic form, rank bar, tool slots and Blizzard's create
	    buttons are moved into a hidden frame (Blizzard's code keeps driving
	    them: the form still holds the recipe's transaction that Create
	    crafts from). The detail pane, rank bar and buttons are this
	    module's, filled from the form's recipe whenever Blizzard validates
	    its controls (every selection, bag change and every 0.75s); the
	    buttons call Blizzard's Create / CreateAll and mirror its buttons'
	    state, and with the controller UI Blizzard's button prompt. The
	    quantity box is Blizzard's (already the classic spinner), and so is
	    the controller UI's "Set Amount" prompt shown in its slot.

	Apart from the list view's heights and the "All" tab's collapsing
	(without the controller UI), only widget state is touched (sizes,
	anchors, parents, textures, colours, alpha, hit rects). Applied once at
	login (reload to switch off).
]]

local _, ns = ...
if not ns.IS_FOREVER then return end
local T = ns.T
local Point, SetTexture = ns.Point, ns.SetTexture

-- T.TRAINER_ART, T.TRADESKILL_ART, T.LISTBOX_HIGHLIGHT(1), T.PLUS_BUTTON,
-- T.MINUS_BUTTON, T.PLUS_HILIGHT (TrainerFrame.lua), T.SKILLS_BAR
-- (CharacterFrame.lua) and T.SKILLS_BAR_BORDER (CharacterSkills.lua) come
-- from files loaded earlier.
T.SORT_TAB = "Interface\\QuestFrame\\UI-QuestLogSortTab-" -- + Middle / Right (the "All" tab)

local module = ns:RegisterModule({
	key = "professions",
	name = "Professions Window",
	tooltip = "Restores the vanilla trade skill window: the classic panel with the profession's rank bar, the compact recipe list coloured by difficulty, the selected recipe's tools and reagents below it and the Create All / Create / Exit buttons. The professions overview keeps its modern look.",
	live = false,
})

-- Vanilla geometry (1.12 Blizzard_TradeSkillUI.xml), offsets from the
-- frame's top-left corner.
local HIT_WIDTH, HIT_HEIGHT = 350, 437            -- the art without its transparent right 34px and bottom 75px
local PORTRAIT_X, PORTRAIT_Y, PORTRAIT_SIZE = 7, -6, 60
local TITLE_LEFT, TITLE_RIGHT, TITLE_Y = 72, 312, -13 -- the title bar (Blizzard's title container), centred on 192
local CLOSE_X, CLOSE_Y = 339, -24                 -- centre
local SIDE_TAB_X, SIDE_TAB_Y = 348, -60           -- the first side tab (the others hang under it)
local RANK_X, RANK_Y, RANK_WIDTH, RANK_HEIGHT = 73, -37, 268, 15 -- TradeSkillRankFrame
local RANK_BORDER_WIDTH, RANK_BORDER_X = 281, -5
local RANK_TEXT_X, RANK_TEXT_Y, RANK_GAP = 6, 1, 13
local SKILL_BORDER_X, SKILL_BORDER_Y = 63, -50    -- TradeSkillSkillBorderLeft
local EXPAND_TAB_X, EXPAND_TAB_Y = 15, -71        -- TradeSkillExpandButtonFrame (the "All" tab)
local SEARCH_X, SEARCH_Y, SEARCH_WIDTH = 80, -70, 125 -- where vanilla had its subclass dropdown
local FILTER_RIGHT, FILTER_Y, FILTER_WIDTH = 358, -64, 110
local FILTER_CLEAR_LEFT = 13                      -- the dropdown box art's see-through left end
-- The controller UI's prompts for the search box and the filter (28px
-- icons Blizzard hangs off their left edges): the first right of the "All"
-- tab, the second against the filter box, the search box between them.
local SEARCH_ICON_X, ICON_SIZE, ICON_GAP = 70, 28, 2
local BAND_CENTER_Y = -80                         -- the search box's and the filter box's middle
local LIST_LEFT, LIST_TOP, LIST_WIDTH, LIST_HEIGHT = 21, -96, 296, 130 -- TradeSkillListScrollFrame
local ROW_LEFT, ROW_WIDTH = 22, 293               -- TradeSkillSkill1..8
local BAR_X, BAR_Y = 15, -221                     -- TradeSkillHorizontalBarLeft
local DETAIL_X, DETAIL_Y, DETAIL_WIDTH, DETAIL_HEIGHT = 20, -234, 297, 176 -- TradeSkillDetailScrollFrame
local BUTTON_Y = -422                             -- the bottom row's centre line
local CREATE_X, EXIT_X, BUTTON_WIDTH = 224, 305, 80 -- centres
local CREATE_ALL_GAP = 86                         -- between Create All's right and Create's left
local INPUT_X, INPUT_GAP = 128, 4                 -- TradeSkillInputBox's left; the - button 4px left of it
local SET_AMOUNT_X = 101                          -- the controller UI's "Set Amount" prompt, in the box's slot
local PROMPT_GAP = 3                              -- between a create button's controller prompt and its text
local CASTBAR_X, CASTBAR_Y = 175, -470            -- Blizzard's crafting cast bar, under the art (bottom centre)

-- The recipe list: Blizzard's rows are 20 units tall, drawn at vanilla's
-- 16px; its row fonts are sized for 12px text at this scale (Game15Font
-- headers). Every row (category ones too) gets that height, with no spacing
-- and no spacer rows, as in 1.12. With the controller UI on, the view keeps
-- Blizzard's extents (recipe rows 1 unit apart, category rows 25 units, a
-- 10 unit gap after each category) and the recipe rows are 16px a row at
-- CONTROLLER_ROW_SCALE.
local VANILLA_ROW_SCALE, CONTROLLER_ROW_SCALE = 0.8, 16 / 21
local ROW_HEIGHT = 20                             -- list units
local LIST_PAD = 5                                -- Blizzard's view padding (top, bottom, right), list units
local ROW_TEXT_X, ROW_TEXT_Y = 24, 1              -- the name (vanilla: 21px in, after a space)
local HEADER_BUTTON_X, HEADER_TEXT_X = 3, 21      -- the +/- and the category name
local EXPAND_SIZE = 16
local TREE_INDENT = 10                            -- Blizzard's per-level indent (in list units), undone per row

-- 1.12 TradeSkillTypeColor, by Enum.TradeskillRelativeDifficulty.
local DIFFICULTY_COLORS = {
	[0] = { r = 1.00, g = 0.50, b = 0.25 }, -- optimal
	[1] = { r = 1.00, g = 1.00, b = 0.00 }, -- medium
	[2] = { r = 0.25, g = 0.75, b = 0.25 }, -- easy
	[3] = { r = 0.50, g = 0.50, b = 0.50 }, -- trivial
}
local TRIVIAL = DIFFICULTY_COLORS[3]

local MAX_REAGENTS = 8
local REAGENT_ROW_HEIGHT = 43                     -- 41px buttons, 2px apart
local REAGENTS_LABEL = strtrim(((SPELL_REAGENTS or "Reagents:"):gsub("%%s", "")))

local frame, page                                 -- ProfessionsFrame, its CraftingPage
local origin                                      -- the vanilla frame's top-left corner, which everything is placed from
local originX, originY = 0, 0                     -- its offset from the frame's top left (see UpdateOrigin)
local gamepadBox                                  -- round the vanilla window, for the controller UI (ns.SetGamepadBox)
local controllerList                              -- the list was skinned for the controller UI (Blizzard's extents, no "All" collapsing)
local rowScale = VANILLA_ROW_SCALE                -- the list's scale, set when it is skinned
local chrome = {}                                 -- the vanilla frame art (shown with the crafting page)
local art = {}                                    -- this module's widgets on the crafting page
local saved = {}                                  -- Blizzard's anchors / hit rect, restored for the overview page
local hidden                                      -- parent of the Blizzard pieces this window does without
local highlightFile
local UpdateExpandTab                             -- defined with the recipe list

local function Fade(region)
	if region then region:SetAlpha(0) end
end

local function HideTooltip()
	GameTooltip:Hide()
	ResetCursor()
end

-- Fades a frame's own textures that carry an atlas (the module's own
-- textures are files).
local function FadeAtlasRegions(owner)
	for _, region in ipairs({ owner:GetRegions() }) do
		if region:IsObjectType("Texture") and region:GetAtlas() then
			region:SetAlpha(0)
		end
	end
end

local function SavePoints(region)
	local points = {}
	for i = 1, region:GetNumPoints() do
		points[i] = { region:GetPoint(i) }
	end
	return points
end

local function RestorePoints(region, points)
	region:ClearAllPoints()
	for _, point in ipairs(points) do
		region:SetPoint(unpack(point))
	end
end

---------------------------------------------------------------------------
-- Frame chrome
---------------------------------------------------------------------------

local function Piece(file, width, height, x, y, layer)
	local texture = frame:CreateTexture(nil, layer or "BORDER")
	texture:SetTexture(file)
	texture:SetSize(width, height)
	texture:SetPoint("TOPLEFT", origin, "TOPLEFT", x, y)
	table.insert(chrome, texture)
	return texture
end

local function PanelAttribute(name)
	return ns.PanelAttribute(frame, name)
end

-- Blizzard registers the frame with xoffset 35, and the manager lifts its
-- 594px on small screens: the art goes where the other windows are, its
-- border on the panel spot (ns.ClassicArtTop) and on the left edge the
-- frame would have without the xoffset (the panel spot, or right after the
-- panel next to it). Offsets in the frame's units (the manager scales it
-- down to fit the screen); the art's own units are the frame's.
local function UpdateOrigin()
	local scale = frame:GetScale()
	local height = ((PanelAttribute("height") or frame:GetHeight()) + (PanelAttribute("extraHeight") or 0)) * scale
	local top = ns.PanelTop(PanelAttribute("yoffset") or 0, height, PanelAttribute("minYOffset"), PanelAttribute("bottomClampOverride"))
	local x = -(PanelAttribute("xoffset") or 0) / scale - ns.CLASSIC_ART_X
	local y = (ns.ClassicArtTop(scale) - top) / scale
	if x ~= originX or y ~= originY or origin:GetNumPoints() == 0 then
		originX, originY = x, y
		Point(origin, "TOPLEFT", frame, "TOPLEFT", x, y)
		return true
	end
end

local function CreateChrome()
	origin = CreateFrame("Frame", nil, frame)
	origin:SetSize(1, 1)
	UpdateOrigin()
	gamepadBox = ns.CreateArtBox(frame, origin, HIT_WIDTH, HIT_HEIGHT)

	local botLeft = ns.HasTexture(T.TRADESKILL_ART .. "BotLeft") and T.TRADESKILL_ART or T.TRAINER_ART
	Piece(T.TRAINER_ART .. "TopLeft", 256, 256, 0, 0)
	Piece(T.TRAINER_ART .. "TopRight", 128, 256, 256, 0)
	Piece(botLeft .. "BotLeft", 256, 256, 0, -256)
	Piece(T.TRAINER_ART .. "BotRight", 128, 256, 256, -256)

	-- 1.12 drew the player's portrait under the art, whose ring cuts it round.
	art.portrait = Piece(nil, PORTRAIT_SIZE, PORTRAIT_SIZE, PORTRAIT_X, PORTRAIT_Y, "BACKGROUND")
	art.portrait:SetDrawLayer("BACKGROUND", -8)
	SetPortraitTexture(art.portrait, "player")

	-- The line under the rank bar and the bar between the list and the
	-- detail pane.
	local skillBorder = T.TRADESKILL_ART .. "SkillBorder"
	if ns.HasTexture(skillBorder) then
		local left = Piece(nil, 256, 8, SKILL_BORDER_X, SKILL_BORDER_Y, "ARTWORK")
		SetTexture(left, skillBorder, 0, 1, 0, 0.25)
		local right = Piece(nil, 28, 8, SKILL_BORDER_X + 256, SKILL_BORDER_Y, "ARTWORK")
		SetTexture(right, skillBorder, 0, 0.109375, 0.25, 0.5)
	end
	local bar = T.TRAINER_ART .. "HorizontalBar"
	if ns.HasTexture(bar) then
		local left = Piece(nil, 256, 16, BAR_X, BAR_Y, "ARTWORK")
		SetTexture(left, bar, 0, 1, 0, 0.25)
		local right = Piece(nil, 75, 16, BAR_X + 256, BAR_Y, "ARTWORK")
		SetTexture(right, bar, 0, 0.29296875, 0.25, 0.5)
	end

	-- Anchors restored while the overview page is shown.
	saved.hitRect = { frame:GetHitRectInsets() }
	if frame.TitleContainer then saved.title = SavePoints(frame.TitleContainer) end
	if frame.ProfessionsOverviewTab then saved.tab = SavePoints(frame.ProfessionsOverviewTab) end
	if frame.CloseButton then saved.close = SavePoints(frame.CloseButton) end
end

-- The frame takes the mouse only over the vanilla art while the crafting
-- page is shown (the art hangs out of the frame on the left and at the
-- top: negative insets). The frame is protected (the overview page's spell
-- buttons are secure), and so are the classic close and Exit buttons
-- (anchored to the frame, never to the origin frame, which would become
-- protected with them): the hit rect and their spots cannot change in
-- combat (the K binding shows the frame in combat), they follow the page
-- and the origin once combat ends.
local protectedQueued = false
local buttonsX, buttonsY -- the origin offsets the close / Exit buttons were placed for
local function UpdateProtected()
	if InCombatLockdown() then
		if not protectedQueued then
			protectedQueued = true
			ns:RunOutOfCombat(function()
				protectedQueued = false
				UpdateProtected()
			end)
		end
		return
	end
	if page:IsShown() then
		local top = -originY
		frame:SetHitRectInsets(originX, frame:GetWidth() - originX - HIT_WIDTH, top, frame:GetHeight() - top - HIT_HEIGHT)
	else
		frame:SetHitRectInsets(unpack(saved.hitRect))
	end
	if art.close and (buttonsX ~= originX or buttonsY ~= originY) then
		buttonsX, buttonsY = originX, originY
		Point(art.close, "CENTER", frame, "TOPLEFT", originX + CLOSE_X, originY + CLOSE_Y)
		Point(art.exit, "CENTER", frame, "TOPLEFT", originX + EXIT_X, originY + BUTTON_Y)
	end
end

-- The vanilla window while the crafting page is shown, Blizzard's look on
-- the overview page.
local function UpdateChrome()
	UpdateOrigin()
	local classic = page:IsShown()
	for _, region in ipairs(chrome) do
		region:SetShown(classic)
	end
	local blizzardAlpha = classic and 0 or 1
	if frame.NineSlice then frame.NineSlice:SetAlpha(blizzardAlpha) end
	if frame.Bg then frame.Bg:SetAlpha(blizzardAlpha) end
	if frame.PortraitContainer then frame.PortraitContainer:SetAlpha(blizzardAlpha) end
	-- The controller UI's focus glow and button prompts: round the vanilla
	-- window, or Blizzard's on the overview page.
	ns.SetGamepadBox(frame, classic and gamepadBox or nil)
	-- Blizzard's close button, unless the classic one stands in for it. The
	-- classic X is only created out of combat (see CreateCloseButtons): if
	-- the window first loads in combat, Blizzard's sits on its spot until
	-- then.
	local close = frame.CloseButton
	if close then
		local blizzardClose = not (classic and art.close)
		close:SetAlpha(blizzardClose and 1 or 0)
		close:EnableMouse(blizzardClose)
		if classic and blizzardClose then
			Point(close, "CENTER", origin, "TOPLEFT", CLOSE_X, CLOSE_Y)
		elseif saved.close then
			RestorePoints(close, saved.close)
		end
	end

	local title, tab = frame.TitleContainer, frame.ProfessionsOverviewTab
	if classic then
		if title then
			title:ClearAllPoints()
			title:SetPoint("TOPLEFT", origin, "TOPLEFT", TITLE_LEFT, TITLE_Y)
			title:SetPoint("TOPRIGHT", origin, "TOPLEFT", TITLE_RIGHT, TITLE_Y)
		end
		if tab then Point(tab, "TOPLEFT", origin, "TOPLEFT", SIDE_TAB_X, SIDE_TAB_Y) end
	else
		if title and saved.title then RestorePoints(title, saved.title) end
		if tab and saved.tab then RestorePoints(tab, saved.tab) end
	end
	UpdateProtected()
end

---------------------------------------------------------------------------
-- Blizzard's crafting page
---------------------------------------------------------------------------

-- What the vanilla window has no place for goes into a hidden frame: the
-- schematic form (its recipe and transaction keep working there), the
-- modern rank bar, link / tutorial buttons, concentration display, the
-- profession tool slots and the create buttons (replaced by this module's).
local function HideBlizzardPieces()
	hidden = CreateFrame("Frame")
	hidden:Hide()
	for _, key in ipairs({ "SchematicForm", "RankBar", "LinkButton", "TutorialButton", "ConcentrationDisplay",
		"CreateButton", "CreateAllButton", "GearSlotDivider" }) do
		if page[key] then page[key]:SetParent(hidden) end
	end
	for _, slot in ipairs(page.InventorySlots or {}) do
		slot:SetParent(hidden)
	end
	-- The page's own background (a Camelot texture on the page) and the list's.
	FadeAtlasRegions(page)
	FadeAtlasRegions(page.RecipeList)
end

-- The search box on vanilla's subclass dropdown spot; while the controller
-- UI shows the prompts beside it and the filter, it makes room for them
-- (their icons show and hide with the crafting page's prompt footer).
-- Blizzard's controller setup anchors the box to the filter's prompt.
local function LayoutSearchBand()
	local list = page.RecipeList
	local search, filter = list.SearchBox, list.FilterDropdown
	if not search then return end
	local left, right = SEARCH_X, SEARCH_X + SEARCH_WIDTH
	local searchIcon = search.GamepadFocusIcon
	if searchIcon and searchIcon:IsShown() then
		left = SEARCH_ICON_X + ICON_SIZE + ICON_GAP
	end
	local filterIcon = filter and filter.GamepadFocusIcon
	if filterIcon and filterIcon:IsShown() then
		right = math.min(right, FILTER_RIGHT - FILTER_WIDTH - 50 + FILTER_CLEAR_LEFT - ICON_SIZE - 2 * ICON_GAP)
	end
	search:ClearAllPoints()
	search:SetPoint("TOPLEFT", origin, "TOPLEFT", left, SEARCH_Y)
	search:SetSize(right - left, 20)
end

-- The controller UI's "Set Amount" prompt (R3), which Blizzard shows
-- instead of the quantity box, takes the box's slot between Create All and
-- Create: one line in the small font (Blizzard wraps it to two 60px lines,
-- again whenever the controller UI starts, so this runs with every update
-- of the buttons).
local function FitSetAmount()
	local prompt = page.GamepadCreateMultiple
	local label = prompt and prompt.ControlDescText
	if not (label and label.FontString) then return end
	label.FontString:SetFontObject(GameFontNormalSmall)
	label.FontString:SetMaxLines(1)
	label.FontString:SetWidth(0)
	label:SetWidth(label.FontString:GetStringWidth())
	Point(prompt, "LEFT", origin, "TOPLEFT", SET_AMOUNT_X, BUTTON_Y)
end

local function PlaceControls()
	local list = page.RecipeList

	local search = list.SearchBox
	local filter = list.FilterDropdown
	if search then
		LayoutSearchBand()
		local icon = search.GamepadFocusIcon
		if icon then
			Point(icon, "LEFT", origin, "TOPLEFT", SEARCH_ICON_X, BAND_CENTER_Y)
			icon:HookScript("OnShow", LayoutSearchBand)
			icon:HookScript("OnHide", LayoutSearchBand)
		end
	end
	if filter then
		local icon = filter.GamepadFocusIcon
		if icon then
			Point(icon, "RIGHT", filter, "LEFT", FILTER_CLEAR_LEFT - ICON_GAP, 0)
			icon:HookScript("OnShow", LayoutSearchBand)
			icon:HookScript("OnHide", LayoutSearchBand)
		end
		Point(filter, "TOPRIGHT", origin, "TOPLEFT", FILTER_RIGHT, FILTER_Y)
		ns.SkinDropdownBox(filter, FILTER_WIDTH)
		-- Its "reset filters" x never goes away on Forever: Blizzard counts
		-- the filters as default only with unlearned recipes shown, and the
		-- Camelot list turns them off on every rebuild (resetting does too).
		if filter.ResetButton then
			Fade(filter.ResetButton)
			filter.ResetButton:EnableMouse(false)
		end
	end
	if list.NoResultsText then
		Point(list.NoResultsText, "TOP", origin, "TOPLEFT", LIST_LEFT + LIST_WIDTH / 2, LIST_TOP - 24)
	end

	-- The quantity spinner is already the classic one (Common-Input-Border,
	-- the spellbook page arrows); it goes between Create All and Create.
	local input = page.CreateMultipleInputBox
	if input then
		Point(input, "LEFT", origin, "TOPLEFT", INPUT_X, BUTTON_Y)
		if input.DecrementButton then
			Point(input.DecrementButton, "RIGHT", input, "LEFT", -INPUT_GAP, 0)
		end
	end
	FitSetAmount()
	if page.ViewGuildCraftersButton then
		Point(page.ViewGuildCraftersButton, "RIGHT", origin, "TOPLEFT", CREATE_X + BUTTON_WIDTH / 2, BUTTON_Y)
	end
end

---------------------------------------------------------------------------
-- Recipe list
---------------------------------------------------------------------------

-- A row's list data. Blizzard takes GetElementData off a row when the list
-- releases it (a rebuild), and the controller UI's smart navigation can
-- still run the scripts of the row it last selected.
local function NodeOf(row)
	return row.GetElementData and row:GetElementData()
end

local function Indent(row)
	local node = NodeOf(row)
	local depth = node and node.GetDepth and node:GetDepth() or 1
	return math.max(0, depth - 1) * TREE_INDENT
end

local function RecipeInfoOf(row)
	local node = NodeOf(row)
	local data = node and node.GetData and node:GetData()
	local info = data and data.recipeInfo
	if info and Professions.GetHighestLearnedRecipe then
		info = Professions.GetHighestLearnedRecipe(info) or info
	end
	return info
end

local function DifficultyColor(info)
	if not info or not info.learned then return TRIVIAL end
	return DIFFICULTY_COLORS[info.relativeDifficulty] or TRIVIAL
end

-- Blizzard's row fonts at vanilla size in the scaled-down list.
local function EnlargeFont(fontString)
	local file, size, flags = GameFontNormal:GetFont()
	fontString:SetFont(file, size / rowScale, flags or "")
	fontString:SetShadowColor(0, 0, 0, 1)
	fontString:SetShadowOffset(1, -1)
	fontString:SetHeight(20)
end

local function SetExpandTexture(texture, collapsed)
	SetTexture(texture, (collapsed and T.PLUS_BUTTON or T.MINUS_BUTTON) .. "Up")
end

-- The top-level categories of Blizzard's list.
local function TopCategories()
	local dataProvider = page.RecipeList.ScrollBox:GetDataProvider()
	local root = dataProvider and dataProvider.GetRootNode and dataProvider:GetRootNode()
	local categories = {}
	for _, node in ipairs(root and root:GetNodes() or {}) do
		if node:GetData().categoryInfo then
			table.insert(categories, node)
		end
	end
	return categories
end

-- The "All" tab shows - while any category is open (a click collapses
-- them all), + when all are closed (a click opens them), as 1.12.
UpdateExpandTab = function()
	local tab = art.expandTab
	if not tab then return end
	local anyOpen = false
	for _, node in ipairs(TopCategories()) do
		if not node:IsCollapsed() then
			anyOpen = true
			break
		end
	end
	tab.collapsed = not anyOpen
	SetExpandTexture(tab.icon, tab.collapsed)
end

local function CreateExpandTab()
	local holder = CreateFrame("Frame", nil, page)
	holder:SetSize(54, 32)
	holder:SetPoint("TOPLEFT", origin, "TOPLEFT", EXPAND_TAB_X, EXPAND_TAB_Y)
	local left = holder:CreateTexture(nil, "BACKGROUND")
	left:SetTexture(T.TRAINER_ART .. "ExpandTab-Left")
	left:SetSize(8, 32)
	left:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	local middle = holder:CreateTexture(nil, "BACKGROUND")
	middle:SetTexture(T.SORT_TAB .. "Middle")
	middle:SetSize(38, 32)
	middle:SetPoint("LEFT", left, "RIGHT", 0, 6)
	local right = holder:CreateTexture(nil, "BACKGROUND")
	right:SetTexture(T.SORT_TAB .. "Right")
	right:SetSize(8, 32)
	right:SetPoint("LEFT", middle, "RIGHT", 0, 0)

	local tab = CreateFrame("Button", nil, holder)
	tab:SetSize(40, 22)
	tab:SetPoint("LEFT", left, "RIGHT", 0, 3)
	tab.icon = tab:CreateTexture(nil, "ARTWORK")
	tab.icon:SetSize(EXPAND_SIZE, EXPAND_SIZE)
	tab.icon:SetPoint("LEFT", tab, "LEFT", HEADER_BUTTON_X, 0)
	local glow = tab:CreateTexture(nil, "HIGHLIGHT")
	glow:SetTexture(T.PLUS_HILIGHT)
	glow:SetBlendMode("ADD")
	glow:SetAllPoints(tab.icon)
	tab.text = tab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	tab.text:SetPoint("LEFT", tab, "LEFT", HEADER_TEXT_X, 1)
	tab.text:SetText(ALL or "All")
	art.expandTab = tab
	-- With the controller UI the tab only shows whether any category is open.
	if controllerList then
		tab:EnableMouse(false)
		return
	end
	tab:SetScript("OnEnter", function(self) self.text:SetFontObject(GameFontHighlight) end)
	tab:SetScript("OnLeave", function(self) self.text:SetFontObject(GameFontNormal) end)
	tab:SetScript("OnClick", function(self)
		local dataProvider = page.RecipeList.ScrollBox:GetDataProvider()
		if not dataProvider then return end
		local open = self.collapsed
		for _, node in ipairs(TopCategories()) do
			node:SetCollapsed(not open, TreeDataProviderConstants.SetChildCollapse, TreeDataProviderConstants.SkipInvalidation)
		end
		dataProvider:Invalidate()
		if not open then page.RecipeList.ScrollBox:ScrollToBegin() end
		UpdateExpandTab()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end)
end

-- Name and count in the difficulty colour (white while hovered or
-- selected, like the vanilla button's highlight font), the highlight bar
-- tinted with it under the selected row.
local function ColorRecipe(row, skin)
	local color = DifficultyColor(RecipeInfoOf(row))
	skin.bar:SetVertexColor(color.r, color.g, color.b)
	skin.bar:SetShown(skin.selected == true)
	local r, g, b = color.r, color.g, color.b
	if skin.selected or row:IsMouseOver() then
		r, g, b = HIGHLIGHT_FONT_COLOR:GetRGB()
	end
	row.Label:SetVertexColor(r, g, b)
	row.Count:SetVertexColor(r, g, b)
end

local function SkinRecipe(row)
	local skin = {}
	-- The difficulty icon goes (the colour tells it); it still passes clicks
	-- on to the row and shows its skill-up tooltip.
	for _, key in ipairs({ "SkillUps", "SelectedOverlay", "HighlightOverlay" }) do
		Fade(row[key])
	end
	skin.bar = row:CreateTexture(nil, "BACKGROUND")
	SetTexture(skin.bar, highlightFile)
	skin.bar:Hide()
	EnlargeFont(row.Label)
	EnlargeFont(row.Count)

	-- Blizzard colours the name on Init, OnEnter and OnLeave, and marks the
	-- selection after Init and on every selection change.
	ns.Hook(row, "SetSelected", function(self, selected)
		skin.selected = selected and true or false
		ColorRecipe(self, skin)
	end)
	ns.Hook(row, "SetLabelFontColors", function(self, color)
		if color ~= HIGHLIGHT_FONT_COLOR then ColorRecipe(self, skin) end
	end)
	return skin
end

local function UpdateRecipe(row, skin)
	local indent = Indent(row)
	Point(row.Label, "LEFT", row, "LEFT", ROW_TEXT_X / rowScale - indent, ROW_TEXT_Y)
	-- The bar spans the list whatever the row's tree level.
	skin.bar:ClearAllPoints()
	skin.bar:SetPoint("TOPLEFT", row, "TOPLEFT", -indent, 0)
	skin.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	ColorRecipe(row, skin)
end

-- A category row (ListHeaderVisualTemplate): Blizzard's band, highlight and
-- collapse arrow go, the vanilla +/- goes in front of the name. The name is
-- Blizzard's button text (its button font is 12px at the list's scale).
local function SkinCategory(row)
	local skin = {}
	FadeAtlasRegions(row)
	Fade(row.CollapseButton)
	skin.button = row:CreateTexture(nil, "ARTWORK")
	skin.button:SetSize(EXPAND_SIZE / rowScale, EXPAND_SIZE / rowScale)
	local glow = row:CreateTexture(nil, "HIGHLIGHT")
	glow:SetTexture(T.PLUS_HILIGHT)
	glow:SetBlendMode("ADD")
	glow:SetAllPoints(skin.button)
	ns.Hook(row, "UpdateCollapsedState", function(_, collapsed)
		SetExpandTexture(skin.button, collapsed)
		UpdateExpandTab()
	end)
	return skin
end

local function UpdateCategory(row, skin)
	local indent = Indent(row)
	Point(skin.button, "LEFT", row, "LEFT", HEADER_BUTTON_X / rowScale - indent, 0)
	local text = row.ButtonText
	if text then
		text:ClearAllPoints()
		text:SetPoint("LEFT", row, "LEFT", HEADER_TEXT_X / rowScale - indent, 0)
		text:SetPoint("RIGHT", row, "RIGHT", -5, 0)
	end
	local node = NodeOf(row)
	SetExpandTexture(skin.button, node and node.IsCollapsed and node:IsCollapsed())
end

local function SkinRow(row)
	if row.Label and row.Count and row.SkillUps then
		return { kind = "recipe", skin = SkinRecipe(row) }
	elseif row.ButtonText and row.CollapseButton then
		return { kind = "category", skin = SkinCategory(row) }
	end
end

local function UpdateRow(row, entry)
	if entry.kind == "recipe" then
		UpdateRecipe(row, entry.skin)
	else
		UpdateCategory(row, entry.skin)
	end
end

-- The list on the vanilla spot, scaled down: its offsets and size are in
-- its own units. Blizzard's view pads the rows 5 units from the top and
-- right, so the box starts that much above the first vanilla row.
local function SkinList()
	local list = page.RecipeList
	local scrollBox = list.ScrollBox
	local view = scrollBox:GetView()
	if not controllerList and view and view.SetElementExtentCalculator and view.SetPadding then
		view:SetPadding(LIST_PAD, LIST_PAD, 0, LIST_PAD, 0)
		view:SetElementExtentCalculator(function(_, node)
			local data = node:GetData()
			if data.recipeInfo or data.categoryInfo then
				return ROW_HEIGHT
			end
			-- Blizzard's spacer rows and dividers: next to nothing (the view
			-- stops listing rows at the first one of extent 0).
			return 0.001
		end)
	end
	local pad = LIST_PAD * rowScale
	local top = LIST_TOP + pad
	scrollBox:SetScale(rowScale)
	scrollBox:ClearAllPoints()
	scrollBox:SetPoint("TOPLEFT", origin, "TOPLEFT", ROW_LEFT / rowScale, top / rowScale)
	scrollBox:SetSize((ROW_WIDTH + pad) / rowScale, (LIST_HEIGHT + pad) / rowScale)
	if scrollBox.GetUpperShadowTexture then
		Fade(scrollBox:GetUpperShadowTexture())
		Fade(scrollBox:GetLowerShadowTexture())
	end

	local scrollBar = list.ScrollBar
	if scrollBar then
		ns.SkinScrollBar(scrollBar)
		local x = LIST_LEFT + LIST_WIDTH + 6
		scrollBar:ClearAllPoints()
		scrollBar:SetPoint("TOPLEFT", origin, "TOPLEFT", x, LIST_TOP)
		scrollBar:SetPoint("BOTTOMLEFT", origin, "TOPLEFT", x, LIST_TOP - LIST_HEIGHT)
		-- The trough is drawn on the bar, so it goes with it when the list fits.
		local troughTop, troughBottom = ns.CreateScrollTrough(scrollBar, T.TRAINER_ART .. "ScrollBar", 0.0234375)
		if troughTop then
			troughTop:SetPoint("TOPLEFT", origin, "TOPLEFT", LIST_LEFT + LIST_WIDTH - 3, LIST_TOP + 2)
			troughBottom:SetPoint("BOTTOMLEFT", origin, "TOPLEFT", LIST_LEFT + LIST_WIDTH - 3, LIST_TOP - LIST_HEIGHT - 2)
		end
		if ScrollUtil.AddManagedScrollBarVisibilityBehavior then
			ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar)
		end
	end

	local skins = setmetatable({}, { __mode = "k" })
	local function Get(row)
		if skins[row] == nil then
			skins[row] = SkinRow(row) or false
		end
		return skins[row]
	end
	ScrollUtil.AddAcquiredFrameCallback(scrollBox, function(_, row) Get(row) end, module)
	ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, row)
		local entry = Get(row)
		if entry then UpdateRow(row, entry) end
	end, module)
end

---------------------------------------------------------------------------
-- Rank bar (1.12 TradeSkillRankFrame)
---------------------------------------------------------------------------

local function CreateRankBar()
	local bar = CreateFrame("Frame", nil, page)
	bar:SetSize(RANK_WIDTH, RANK_HEIGHT)
	bar:SetPoint("TOPLEFT", origin, "TOPLEFT", RANK_X, RANK_Y)
	-- White at 0.2 under the vertex colour (0, 0, 0.75, 0.5), as 1.12.
	local background = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	background:SetAllPoints(bar)
	background:SetColorTexture(0, 0, 0.75, 0.1)
	bar.fill = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	bar.fill:SetTexture(T.SKILLS_BAR)
	bar.fill:SetVertexColor(0, 0, 1, 0.5)
	bar.fill:SetHeight(RANK_HEIGHT)
	bar.fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
	local border = bar:CreateTexture(nil, "ARTWORK")
	border:SetTexture(T.SKILLS_BAR_BORDER)
	border:SetSize(RANK_BORDER_WIDTH, 32)
	border:SetPoint("LEFT", bar, "LEFT", RANK_BORDER_X, 0)
	bar.name = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	bar.name:SetPoint("LEFT", bar, "LEFT", RANK_TEXT_X, RANK_TEXT_Y)
	bar.rank = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.rank:SetJustifyH("LEFT")
	bar.rank:SetPoint("LEFT", bar.name, "RIGHT", RANK_GAP, 0)
	art.rankBar = bar
end

local function UpdateRankBar()
	local bar = art.rankBar
	if not bar then return end
	local info = Professions.GetProfessionInfo and Professions.GetProfessionInfo()
	local maxRank = info and info.maxSkillLevel or 0
	if maxRank <= 0 then
		bar:Hide()
		return
	end
	local rank = info.skillLevel or 0
	bar:Show()
	bar.name:SetText(info.professionName or info.parentProfessionName or "")
	local modifier = info.skillModifier or 0
	if modifier > 0 then
		bar.rank:SetFormattedText("%d%s(+%d)|r/%d", rank, GREEN_FONT_COLOR_CODE, modifier, maxRank)
	else
		bar.rank:SetFormattedText("%d/%d", rank, maxRank)
	end
	local percent = math.min(1, math.max(0, rank / maxRank))
	bar.fill:SetShown(percent > 0)
	bar.fill:SetWidth(math.max(1, RANK_WIDTH * percent))
	bar.fill:SetTexCoord(0, percent, 0, 1)
end

---------------------------------------------------------------------------
-- Detail pane (1.12 TradeSkillDetailScrollFrame)
---------------------------------------------------------------------------

local function GetRecipe()
	local form = page.SchematicForm
	local info = form and form:GetRecipeInfo()
	local transaction = info and form:GetTransaction()
	local schematic = transaction and transaction:GetRecipeSchematic()
	return info, schematic, transaction
end

local function ReagentName(reagent)
	if reagent.itemID then
		return C_Item.GetItemNameByID(reagent.itemID), C_Item.GetItemIconByID(reagent.itemID)
	elseif reagent.currencyID then
		local currency = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
		if currency then return currency.name, currency.iconFileID end
	end
end

local function ReagentLink(recipeID, slot)
	if C_TradeSkillUI.GetRecipeFixedReagentItemLink then
		local link = C_TradeSkillUI.GetRecipeFixedReagentItemLink(recipeID, slot.dataSlotIndex)
		if link then return link end
	end
	local reagent = slot.reagents and slot.reagents[1]
	if reagent and reagent.itemID then
		return select(2, C_Item.GetItemInfo(reagent.itemID))
	end
end

local function CreateReagentButton(child, index)
	local button = CreateFrame("Button", nil, child, "LargeItemButtonTemplate")
	button:SetScript("OnEnter", function(self)
		local info = GetRecipe()
		if not (info and self.slot) then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		local reagent = self.slot.reagents and self.slot.reagents[1]
		if self.slot.dataSlotIndex and GameTooltip.SetRecipeReagentItem then
			GameTooltip:SetRecipeReagentItem(info.recipeID, self.slot.dataSlotIndex)
		elseif reagent and reagent.itemID then
			GameTooltip:SetItemByID(reagent.itemID)
		elseif reagent and reagent.currencyID then
			GameTooltip:SetCurrencyByID(reagent.currencyID)
		end
		GameTooltip:Show()
		CursorUpdate(self)
	end)
	button:SetScript("OnLeave", HideTooltip)
	button:SetScript("OnClick", function(self)
		local info = GetRecipe()
		if info and self.slot then
			HandleModifiedItemClick(ReagentLink(info.recipeID, self.slot))
		end
	end)
	if index == 1 then
		button:SetPoint("TOPLEFT", art.reagentLabel, "BOTTOMLEFT", -5, -3)
	elseif index % 2 == 0 then
		button:SetPoint("LEFT", art.reagents[index - 1], "RIGHT", 0, 0)
	else
		button:SetPoint("TOPLEFT", art.reagents[index - 2], "BOTTOMLEFT", 0, -2)
	end
	button:Hide()
	return button
end

local function CreateDetailPane()
	-- UIPanelScrollFrameTemplate is the classic knob scroll frame; with
	-- scrollBarHideable the bar only appears when the details overflow.
	local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", origin, "TOPLEFT", DETAIL_X, DETAIL_Y)
	scroll:SetSize(DETAIL_WIDTH, DETAIL_HEIGHT)
	scroll.scrollBarHideable = 1
	if scroll.ScrollBar then
		scroll.ScrollBar:Hide() -- the template's OnLoad ran before scrollBarHideable was set
		local troughTop, troughBottom = ns.CreateScrollTrough(scroll.ScrollBar, T.TRAINER_ART .. "ScrollBar", 0)
		if troughTop then
			troughTop:SetPoint("TOPLEFT", origin, "TOPLEFT", DETAIL_X + DETAIL_WIDTH - 2, DETAIL_Y + 5)
			troughBottom:SetPoint("BOTTOMLEFT", origin, "TOPLEFT", DETAIL_X + DETAIL_WIDTH - 2, DETAIL_Y - DETAIL_HEIGHT - 1)
		end
	end
	art.detail = scroll

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(DETAIL_WIDTH, 150)
	scroll:SetScrollChild(child)
	art.detailChild = child

	-- The icon and name's frame (the trainer's detail header art).
	for _, piece in ipairs({ { "DetailHeaderLeft", 256, 0 }, { "DetailHeaderRight", 64, 256 } }) do
		local file = T.TRAINER_ART .. piece[1]
		if ns.HasTexture(file) then
			local texture = child:CreateTexture(nil, "BACKGROUND")
			texture:SetTexture(file)
			texture:SetSize(piece[2], 64)
			texture:SetPoint("TOPLEFT", child, "TOPLEFT", piece[3], 3)
		end
	end

	local icon = CreateFrame("Button", nil, child)
	icon:SetSize(37, 37)
	icon:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -3)
	icon.count = icon:CreateFontString(nil, "ARTWORK", "NumberFontNormal")
	icon.count:SetJustifyH("RIGHT")
	icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -5, 2)
	icon:SetScript("OnEnter", function(self)
		local info = GetRecipe()
		if not info then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetRecipeResultItem(info.recipeID, {}, nil, page.SchematicForm:GetCurrentRecipeLevel())
		GameTooltip:Show()
		CursorUpdate(self)
	end)
	icon:SetScript("OnLeave", HideTooltip)
	icon:SetScript("OnClick", function()
		local info = GetRecipe()
		if not info then return end
		local output = C_TradeSkillUI.GetRecipeOutputItemData(info.recipeID, {}, nil)
		HandleModifiedItemClick(output and output.hyperlink or C_TradeSkillUI.GetRecipeLink(info.recipeID))
	end)
	art.icon = icon

	art.name = child:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	art.name:SetWidth(244)
	art.name:SetJustifyH("LEFT")
	art.name:SetPoint("TOPLEFT", child, "TOPLEFT", 50, -5)

	art.requiresLabel = child:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
	art.requiresLabel:SetText(REQUIRES_LABEL)
	art.requiresLabel:SetPoint("TOPLEFT", art.name, "BOTTOMLEFT", 0, 0)
	art.requires = child:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
	art.requires:SetWidth(180)
	art.requires:SetJustifyH("LEFT")
	art.requires:SetJustifyV("TOP")
	art.requires:SetPoint("TOPLEFT", art.requiresLabel, "TOPRIGHT", 4, 0)

	art.cooldown = child:CreateFontString(nil, "BACKGROUND", "GameFontRedSmall")
	art.cooldown:SetJustifyH("LEFT")
	art.cooldown:SetPoint("TOPLEFT", art.requiresLabel, "BOTTOMLEFT", 0, 0)

	-- 1.12's craft window (enchanting) showed the spell's description here;
	-- used for recipes that make no item.
	art.description = child:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
	art.description:SetWidth(DETAIL_WIDTH - 12)
	art.description:SetJustifyH("LEFT")
	art.description:SetJustifyV("TOP")
	art.description:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -47)

	art.reagentLabel = child:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
	art.reagentLabel:SetText(REAGENTS_LABEL)

	art.reagents = {}
	for i = 1, MAX_REAGENTS do
		art.reagents[i] = CreateReagentButton(child, i)
	end
end

local function RequirementsText(recipeID)
	local requirements = C_TradeSkillUI.GetRecipeRequirements(recipeID) or {}
	local parts = {}
	for _, requirement in ipairs(requirements) do
		local color = requirement.met and HIGHLIGHT_FONT_COLOR or RED_FONT_COLOR
		table.insert(parts, color:WrapTextInColorCode(requirement.name or ""))
	end
	return table.concat(parts, ", ")
end

local function CooldownText(info)
	if info.disabled then
		return info.disabledReason or ""
	end
	local cooldown = C_TradeSkillUI.GetRecipeCooldown(info.recipeID)
	if cooldown and cooldown > 0 then
		return COOLDOWN_REMAINING .. " " .. SecondsToTime(cooldown)
	end
	return ""
end

local function UpdateReagents(info, schematic, transaction)
	local inventoryOnly = transaction and transaction.ShouldUseCharacterInventoryOnly and transaction:ShouldUseCharacterInventoryOnly()
	local shown = 0
	for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
		local reagent = slot.reagents and slot.reagents[1]
		if reagent and slot.reagentType == Enum.CraftingReagentType.Basic and shown < MAX_REAGENTS then
			shown = shown + 1
			local button = art.reagents[shown]
			button.slot = slot
			local name, icon = ReagentName(reagent)
			if reagent.itemID and not name then
				C_Item.RequestLoadItemDataByID(reagent.itemID) -- the next refresh has it
			end
			local have = 0
			for _, variant in ipairs(slot.reagents) do
				have = have + (ProfessionsUtil.GetReagentQuantityInPossession(variant, inventoryOnly) or 0)
			end
			local need = slot.quantityRequired or 0
			button.Icon:SetTexture(icon)
			button.Name:SetText(name or "")
			if have < need then
				button.Icon:SetVertexColor(0.5, 0.5, 0.5)
				button.Name:SetTextColor(GRAY_FONT_COLOR:GetRGB())
			else
				button.Icon:SetVertexColor(1, 1, 1)
				button.Name:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
			end
			button.Count:SetText((have >= 100 and "*" or have) .. " /" .. need)
			button:Show()
		end
	end
	for i = shown + 1, MAX_REAGENTS do
		art.reagents[i]:Hide()
		art.reagents[i].slot = nil
	end
	return shown
end

local function UpdateDetails()
	if not art.detail then return end
	local info, schematic, transaction = GetRecipe()
	local child = art.detailChild
	if not (info and schematic) then
		child:Hide()
		return
	end
	child:Show()

	local recipeID = info.recipeID
	local output = C_TradeSkillUI.GetRecipeOutputItemData(recipeID, {}, nil)
	local texture = (output and output.icon) or schematic.icon or info.icon
	if texture then
		art.icon:SetNormalTexture(texture)
	else
		art.icon:ClearNormalTexture()
	end
	local minMade, maxMade = schematic.quantityMin or 1, schematic.quantityMax or 1
	if maxMade > 1 then
		art.icon.count:SetText(minMade == maxMade and minMade or (minMade .. "-" .. maxMade))
		if art.icon.count:GetStringWidth() > 39 then
			art.icon.count:SetText("~" .. math.floor((minMade + maxMade) / 2))
		end
	else
		art.icon.count:SetText("")
	end
	art.name:SetText(info.name or schematic.name or "")

	local requirements = RequirementsText(recipeID)
	art.requiresLabel:SetShown(requirements ~= "")
	art.requires:SetText(requirements)
	art.cooldown:SetText(CooldownText(info))

	local description = ""
	if not schematic.outputItemID and C_TradeSkillUI.GetRecipeDescription then
		description = C_TradeSkillUI.GetRecipeDescription(recipeID, {}, nil) or ""
	end
	art.description:SetText(description)
	art.description:SetShown(description ~= "")
	local reagentTop = 47
	if description ~= "" then
		Point(art.reagentLabel, "TOPLEFT", art.description, "BOTTOMLEFT", 0, -10)
		reagentTop = reagentTop + art.description:GetStringHeight() + 10
	else
		Point(art.reagentLabel, "TOPLEFT", child, "TOPLEFT", 8, -reagentTop)
	end

	local shown = UpdateReagents(info, schematic, transaction)
	art.reagentLabel:SetShown(shown > 0)

	-- Size the scroll child to its content so the bar only shows when needed.
	local rows = math.ceil(shown / 2)
	child:SetHeight(math.max(DETAIL_HEIGHT, reagentTop + 15 + rows * REAGENT_ROW_HEIGHT))
	art.detail:UpdateScrollChildRect()
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

-- A classic panel button standing in for one of Blizzard's (hidden) create
-- buttons: it calls the page's own method and shows the Blizzard button's
-- state, text (without the " [count]" Create All gets) and failure tooltip.
-- With the controller UI it gets Blizzard's button prompt (Square: tap to
-- create, hold to create all) before its text, as Blizzard's buttons do.
local function CreateProxyButton(source, method)
	local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	button:SetSize(BUTTON_WIDTH, 22)
	button:SetMotionScriptsWhileDisabled(true)
	button:SetScript("OnClick", function()
		page[method](page)
	end)
	button:SetScript("OnEnter", function(self)
		local text = source.tooltipText
		if not text then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, nil, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button.source = source
	if GAMEPAD_FACE_LEFT then
		local ok, icon = pcall(CreateFrame, "Frame", nil, button, "InputIconTextureFrameTemplate")
		if ok and icon then
			icon:SetInputKey(GAMEPAD_FACE_LEFT)
			icon:SetSize(22, 22)
			icon:Hide()
			button.prompt = icon
		end
	end
	return button
end

-- The prompt shows while the button can be pressed, its text moving right
-- to make room (GamepadMode.UpdateGamepadIconAnchor).
local function UpdatePrompt(button)
	local prompt, text = button.prompt, button:GetFontString()
	if not (prompt and text) then return end
	local shown = ns.IsControllerUI() and button:IsEnabled()
	prompt:SetShown(shown)
	text:ClearAllPoints()
	text:SetPoint("CENTER", button, "CENTER", shown and (prompt:GetWidth() + PROMPT_GAP) / 2 or 0, 0)
	Point(prompt, "RIGHT", text, "LEFT", -PROMPT_GAP, 0)
end

local function CreateButtons()
	art.create = CreateProxyButton(page.CreateButton, "Create")
	art.create:SetPoint("CENTER", origin, "TOPLEFT", CREATE_X, BUTTON_Y)
	art.createAll = CreateProxyButton(page.CreateAllButton, "CreateAll")
	art.createAll:SetPoint("RIGHT", art.create, "LEFT", -CREATE_ALL_GAP, 0)
end

-- The round classic close button and Exit. Addon code may not hide a panel
-- in combat, so they are secure buttons that click Blizzard's own close
-- button (its click stays Blizzard's, in combat too; it is faded while the
-- crafting page shows). They are on the page, so they go with it; being
-- protected, they are created out of combat, and they make the page
-- protected (the frame already is: the overview's spell buttons are secure).
local function CreateCloseButtons()
	local function Create()
		local button = CreateFrame("Button", nil, page, "SecureActionButtonTemplate")
		-- On release: acting on the press would hide the window before the
		-- button gets its mouse-up, and it would come back drawn pressed.
		button:RegisterForClicks("AnyUp")
		button:SetAttribute("useOnKeyDown", false)
		button:SetAttribute("type", "click")
		button:SetAttribute("clickbutton", frame.CloseButton)
		return button
	end
	art.close = Create()
	ns.SkinCloseButton(art.close)
	art.exit = Create()
	ns.SkinPanelTextButton(art.exit, EXIT or "Exit")
	art.exit:SetSize(BUTTON_WIDTH, 22)
	-- Placed by UpdateProtected (UpdateChrome runs right after).
end

local function SyncButtons()
	for _, button in ipairs({ art.create, art.createAll }) do
		local source = button.source
		button:SetShown(source:IsShown())
		button:SetEnabled(source:IsEnabled())
		-- Create keeps the amount set with the controller UI ("Create [3]"),
		-- which has no quantity box to show it.
		local text = source:GetText() or ""
		if not (button == art.create and ns.IsControllerUI()) then
			text = text:gsub("%s*%[%d+%]$", "")
		end
		button:SetText(text)
		UpdatePrompt(button)
	end
	FitSetAmount()
	-- Blizzard puts its crafting cast bar at the bottom of the page on every
	-- validation; the page is Blizzard's size, so it goes under the art.
	if page.OverlayCastBarAnchor then
		Point(page.OverlayCastBarAnchor, "BOTTOM", origin, "TOPLEFT", CASTBAR_X, CASTBAR_Y)
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local function Skin()
	frame = ProfessionsFrame
	page = frame and frame.CraftingPage
	if not (page and page.RecipeList and page.RecipeList.ScrollBox and page.SchematicForm and page.CreateButton
		and page.CreateAllButton and Professions and ProfessionsUtil and ScrollUtil
		and ScrollUtil.AddAcquiredFrameCallback and ScrollUtil.AddInitializedFrameCallback) then
		return
	end
	if chrome[1] then return end
	for _, piece in ipairs({ "TopLeft", "TopRight", "BotRight" }) do
		if not ns.HasTexture(T.TRAINER_ART .. piece) then
			ns.Print("This client does not ship " .. T.TRAINER_ART .. piece .. "; the professions window keeps the retail look.")
			return
		end
	end
	highlightFile = ns.HasTexture(T.LISTBOX_HIGHLIGHT) and T.LISTBOX_HIGHLIGHT or T.LISTBOX_HIGHLIGHT1
	controllerList = ns.IsControllerUI()
	rowScale = controllerList and CONTROLLER_ROW_SCALE or VANILLA_ROW_SCALE
	-- The list keeps the input style it was skinned for (see the header).
	local styleWatcher = CreateFrame("Frame")
	styleWatcher:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
	styleWatcher:SetScript("OnEvent", function()
		if ns.IsControllerUI() ~= controllerList then
			ns.Print("/reload to fit the professions window's recipe list to the " .. (controllerList and "mouse and keyboard." or "controller UI."))
		end
	end)

	CreateChrome()
	HideBlizzardPieces()
	PlaceControls()
	SkinList()
	CreateRankBar()
	CreateExpandTab()
	CreateDetailPane()
	CreateButtons()
	ns:RunOutOfCombat(function()
		CreateCloseButtons()
		UpdateChrome()
	end)

	page:HookScript("OnShow", UpdateChrome)
	page:HookScript("OnHide", UpdateChrome)
	frame:HookScript("OnShow", UpdateChrome)
	-- The manager scales the frame to fit the screen when it shows it or
	-- lays the panels out again.
	local function Reposition()
		if frame:IsShown() and UpdateOrigin() then
			UpdateProtected()
		end
	end
	for _, name in ipairs({ "ShowUIPanel", "UpdateUIPanelPositions" }) do
		ns.Hook(name, Reposition)
	end
	ns.Hook(page, "ValidateControls", function()
		SyncButtons()
		UpdateDetails()
	end)
	ns.Hook(frame, "Refresh", UpdateRankBar)
	ns.Hook(page, "Init", UpdateExpandTab) -- a new list (profession, search, filters)

	local events = CreateFrame("Frame", nil, page)
	events:RegisterEvent("SKILL_LINES_CHANGED")
	events:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
	events:SetScript("OnEvent", function(_, event)
		if event == "UNIT_PORTRAIT_UPDATE" then
			SetPortraitTexture(art.portrait, "player")
		else
			UpdateRankBar()
		end
	end)

	UpdateChrome()
	UpdateRankBar()
	SyncButtons()
	UpdateDetails()
end

-- Blizzard_Professions is load-on-demand: it loads the first time a
-- profession is opened.
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, _, addon)
	if addon == "Blizzard_Professions" then
		self:UnregisterEvent("ADDON_LOADED")
		xpcall(Skin, geterrorhandler())
	end
end)

function module:Apply()
	if C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
		Skin()
	else
		eventFrame:RegisterEvent("ADDON_LOADED")
	end
end
