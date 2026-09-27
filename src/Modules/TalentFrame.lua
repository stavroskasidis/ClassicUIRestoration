--[[
	Forevermore Classic UI - Talents (WoW Forever only)

	Restores the vanilla talent frame (1.12 Blizzard_TalentUI): the 384x512
	frame (the character frame's top over UI-TalentFrame-BotLeft / -BotRight)
	with the player's portrait in the ring and the "Talents" title, one tree
	at a time on that tree's painted background, picked with the tabs under
	the frame, the talents on the vanilla grid (four columns, 63px apart) in
	the square slot that is green while a point can go in, gold when maxed
	and grey when out of reach, the rank in the small box at the corner, the
	vanilla branches and arrows between prerequisites, a scroll bar for the
	lower tiers, the tree's spent points in the box under the title and the
	unspent points in the bar at the bottom. Forever's second specialization
	gets 3.x's spec tabs down the right edge (the active one gilded).

	Forever's talents are the retail trait tree (Blizzard_SharedTalentUI)
	with the camelot overlay (Blizzard_PlayerSpells\Camelot\ClassTalents):
	the talents page (TalentsFrame) of PlayerSpellsFrame shows one C_Traits
	tree holding the class's three trees side by side (a node group and a
	header each), a tab per spec group, staged changes that "Apply Changes"
	commits, and a search. Clicks, tooltips, staging and committing stay
	Blizzard's; the page is re-skinned in place:

	  * the talent buttons are Blizzard's own, taken out of its canvas
	    (ButtonsParent, which places them from the node coordinates) into a
	    scroll frame of the vanilla size. Blizzard puts a button back into
	    its canvas whenever it places it (UpdateTalentButtonPosition), so the
	    button is moved again after every one of those calls. The nodes of
	    the other two trees, and the few nodes the data parks far off the
	    grid, wait in a hidden frame. Tree, tier and column come from the
	    node coordinates: the grid is 600 node units (60px) in both
	    directions, the trees lie well apart (see ComputeCells),
	  * Blizzard's lines between the nodes, the tier gates and the tree
	    headers are hidden; the branches and arrows are drawn from the nodes'
	    edges with 1.12's TalentFrame_DrawLines,
	  * the page's backgrounds and their animations (its BACKGROUND and
	    OVERLAY draw layers) are switched off. The frame is drawn where the
	    classic spellbook opens, at its scale (the talents' own panel is a
	    larger, centred panel that closes the other panels when it opens),
	    and PlayerSpellsPanel.lua takes the panel's chrome, close button and
	    mouse out of the way,
	  * "Activate" (for the inactive spec) and the undo / reset button go to
	    the right end of the box under the title, the search box into the
	    bar at the bottom (the bar is its border), and "Apply Changes"
	    becomes 3.x's "Learn" button in the box at the bottom right.

	Only widget state is touched (parents, sizes, anchors, textures, colours,
	alpha); no Lua field is written on Blizzard's frames. Applied once at
	login (reload to switch off).
]]

local _, ns = ...
if not ns.IS_FOREVER then return end
local T = ns.T
local Point = ns.Point

-- T.TAB_INACTIVE / T.TAB_HIGHLIGHT (AuctionHouse.lua) and T.SPELLBOOK_SKILLTAB
-- (SpellBook.lua) come from files loaded earlier.
T.TALENT_FRAME_TOP    = "Interface\\PaperDollInfoFrame\\UI-Character-General-" -- + TopLeft / TopRight
T.TALENT_FRAME_BOTTOM = "Interface\\TalentFrame\\UI-TalentFrame-"             -- + BotLeft / BotRight
T.TALENT_TREE         = "Interface\\TalentFrame\\"                             -- + <tree>-TopLeft / -TopRight / -BottomLeft / -BottomRight
T.TALENT_BRANCHES     = "Interface\\TalentFrame\\UI-TalentBranches"
T.TALENT_ARROWS       = "Interface\\TalentFrame\\UI-TalentArrows"
T.TALENT_RANK_BORDER  = "Interface\\TalentFrame\\TalentFrame-RankBorder"
T.EMPTY_SLOT_WHITE    = "Interface\\Buttons\\UI-EmptySlot-White"
T.CHARACTER_SCROLLBAR = "Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar"
T.INPUT_BORDER_BOX    = "Interface\\Common\\Common-Input-Border"
T.SKILLTAB_GLOW       = "Interface\\Spellbook\\SpellBook-SkillLineTab-Glow"

local module = ns:RegisterModule({
	key = "talents",
	name = "Talents",
	tooltip = "Restores the vanilla talent frame: one tree at a time on its classic painted background with the tree tabs under the frame, the talents in the classic square slots with the rank box, the classic branches and arrows, and the spent and unspent points in the classic boxes. Dual specialization, staged changes (the Learn button), undo / reset and the search keep working.",
	live = false,
})

local BLIZZARD_ADDON = "Blizzard_PlayerSpells"

-- GetTalentTabInfo's background files (1.12), by class and tree.
local TREE_BACKGROUNDS = {
	WARRIOR = { "WarriorArms", "WarriorFury", "WarriorProtection" },
	PALADIN = { "PaladinHoly", "PaladinProtection", "PaladinCombat" },
	HUNTER  = { "HunterBeastMastery", "HunterMarksmanship", "HunterSurvival" },
	ROGUE   = { "RogueAssassination", "RogueCombat", "RogueSubtlety" },
	PRIEST  = { "PriestDiscipline", "PriestHoly", "PriestShadow" },
	SHAMAN  = { "ShamanElementalCombat", "ShamanEnhancement", "ShamanRestoration" },
	MAGE    = { "MageArcane", "MageFire", "MageFrost" },
	WARLOCK = { "WarlockCurses", "WarlockSummoning", "WarlockDestruction" },
	DRUID   = { "DruidBalance", "DruidFeralCombat", "DruidRestoration" },
}
local DEFAULT_BACKGROUND = "MageFire" -- 1.12's "temporary default for classes without talents"

-- Vanilla geometry (1.12 TalentFrame.xml), offsets from the frame's top-left
-- corner.
local FRAME_WIDTH, FRAME_HEIGHT = 384, 512
local HIT_INSET_RIGHT, HIT_INSET_BOTTOM = 30, 45 -- the transparent art right of and under the frame
local STANDARD_PANEL_HEIGHT = 424               -- as SpellBook.lua: the top line the other panels share
local PORTRAIT_X, PORTRAIT_Y, PORTRAIT_SIZE = 7, -6, 60
local TITLE_Y = -18                             -- top of the title, centred
local CLOSE_X, CLOSE_Y = 340, -25               -- centre
local VIEW_X, VIEW_Y = 23, -77                  -- tree background and scroll frame
local VIEW_WIDTH, VIEW_HEIGHT = 296, 332
local BUTTON_SIZE, SPACING = 37, 63             -- talents, 63px apart
local FIRST_X, FIRST_Y = 35, 20                 -- INITIAL_TALENT_OFFSET_X / _Y
local PIECE_SIZE = 32                           -- TALENT_BUTTON_SIZE: the branch and arrow pieces
local MAX_TIERS, NUM_COLUMNS = 11, 4
-- The box under the title (1.12's spent points): Common-Input-Border.
local BOX_LEFT, BOX_Y, BOX_RIGHT, BOX_HEIGHT = 75, -48, 339, 20
-- The bar and the box at the bottom (UI-TalentFrame-BotLeft / -BotRight).
local BAR_Y = -420                              -- their centre line
local BAR_LEFT, POINTS_RIGHT = 32, 252          -- search box start, talent points' right end
local LEARN_X = 305                             -- 1.12's Close button, centre
-- Tabs: the first one's bottom left from the frame's bottom left, each one
-- 15px into the previous one (PanelTemplates_TabResize(10, tab): the text
-- plus 10, between 20px ends).
local TAB_X, TAB_Y, TAB_OVERLAP, TAB_END, TAB_PADDING = 15, 46, 15, 20, 10
-- 3.x's spec tabs (PlayerSpecTab1 / 2) down the right edge.
local SPEC_TAB_X, SPEC_TAB_Y, SPEC_TAB_SIZE, SPEC_TAB_GAP = 352, -65, 32, 22

-- Blizzard's node coordinates are tenths of a pixel, 600 between columns and
-- between tiers; a node may be off its grid point by a pixel or so.
local NODE_GRID, NODE_SLACK = 600, 100
local TREE_SPAN = (NUM_COLUMNS - 1) * NODE_GRID + NODE_SLACK -- widest a tree gets from its first column

local SLOT_AVAILABLE = { 0.1, 1, 0.1 }
local SLOT_MAXED = { 1, 0.82, 0 }
local SLOT_DIMMED = { 0.5, 0.5, 0.5 }
local SLOT_ERROR = { 1, 0.1, 0.1 }

-- 1.12 TALENT_BRANCH_TEXTURECOORDS / TALENT_ARROW_TEXTURECOORDS: [1] gold
-- (the talent's requirements are met), [-1] grey.
local BRANCH_COORDS = {
	up          = { [1] = { 0.12890625, 0.25390625, 0, 0.484375 }, [-1] = { 0.12890625, 0.25390625, 0.515625, 1 } },
	down        = { [1] = { 0, 0.125, 0, 0.484375 },               [-1] = { 0, 0.125, 0.515625, 1 } },
	left        = { [1] = { 0.2578125, 0.3828125, 0, 0.5 },        [-1] = { 0.2578125, 0.3828125, 0.5, 1 } },
	right       = { [1] = { 0.2578125, 0.3828125, 0, 0.5 },        [-1] = { 0.2578125, 0.3828125, 0.5, 1 } },
	topright    = { [1] = { 0.515625, 0.640625, 0, 0.5 },          [-1] = { 0.515625, 0.640625, 0.5, 1 } },
	topleft     = { [1] = { 0.640625, 0.515625, 0, 0.5 },          [-1] = { 0.640625, 0.515625, 0.5, 1 } },
	bottomright = { [1] = { 0.38671875, 0.51171875, 0, 0.5 },      [-1] = { 0.38671875, 0.51171875, 0.5, 1 } },
	bottomleft  = { [1] = { 0.51171875, 0.38671875, 0, 0.5 },      [-1] = { 0.51171875, 0.38671875, 0.5, 1 } },
	tdown       = { [1] = { 0.64453125, 0.76953125, 0, 0.5 },      [-1] = { 0.64453125, 0.76953125, 0.5, 1 } },
	tup         = { [1] = { 0.7734375, 0.8984375, 0, 0.5 },        [-1] = { 0.7734375, 0.8984375, 0.5, 1 } },
}
local ARROW_COORDS = {
	top   = { [1] = { 0, 0.5, 0, 0.5 },   [-1] = { 0, 0.5, 0.5, 1 } },
	right = { [1] = { 1, 0.5, 0, 0.5 },   [-1] = { 1, 0.5, 0.5, 1 } },
	left  = { [1] = { 0.5, 1, 0, 0.5 },   [-1] = { 0.5, 1, 0.5, 1 } },
}

local SIDE_TAB_ART = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive", "LeftHighlight", "MiddleHighlight", "RightHighlight", "SquareBackground", "SquareBackgroundActive", "SquareBackgroundActiveGlow", "Icon", "Text" }

local book, talents        -- PlayerSpellsFrame and its talents page (TalentsFrame)
local VisualState          -- TalentButtonUtil.BaseVisualState
local frame                -- the vanilla frame
local scroll, canvas, arrowLayer, parking -- scroll frame, its child (the buttons' parent), the arrows above the buttons, the hidden frame
local scrollBar, scrollUp, scrollDown, scrollThumb
local portrait, spentText, pointsText, pointsLabel
local background = {}      -- the tree background's four pieces
local box = {}             -- the spent points box's three pieces
local treeTabs = {}
local branchPool, arrowPool = {}, {}
local skins = setmetatable({}, { __mode = "k" }) -- Blizzard frame -> what this module added to it
local trees = {}           -- tree index -> { groupID, name, icon, spent } (the page's node groups, left to right)
local cells = {}           -- nodeID -> { tree, tier, column }
local treeTiers = {}       -- tree index -> tiers in use
local selectedTree = 1
local branchesQueued = false

local function Round(value)
	return math.floor(value + 0.5)
end

---------------------------------------------------------------------------
-- Trees
---------------------------------------------------------------------------

-- The page's trees (node groups) with their names, icons and the points
-- spent in them, as its tree headers show them (RefreshTreeHeaders).
local function UpdateTrees()
	wipe(trees)
	local treeID, configID = talents:GetTalentTreeID(), talents:GetConfigID()
	if not (treeID and C_Traits.GetGroupDisplayInfoByTreeID) then return end
	local groupIDs = {}
	for index, displayInfo in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}) do
		trees[index] = { groupID = displayInfo.groupID, name = displayInfo.displayName, icon = displayInfo.icon, spent = 0 }
		groupIDs[index] = displayInfo.groupID
	end
	if not configID or #groupIDs == 0 then return end
	for _, groupInfo in ipairs(C_Traits.GetGroupCurrencyInfo(configID, groupIDs) or {}) do
		local currency = groupInfo.currencyInfos and groupInfo.currencyInfos[1]
		for _, tree in ipairs(trees) do
			if tree.groupID == groupInfo.traitNodeGroupID then
				tree.spent = currency and currency.spent or 0
			end
		end
	end
end

local function TreeBackground(index)
	local classInfo = C_CreatureInfo.GetClassInfo(talents:GetClassID() or 0)
	local names = classInfo and TREE_BACKGROUNDS[classInfo.classFile]
	return names and names[index] or DEFAULT_BACKGROUND
end

-- Sorts the page's buttons into trees, tiers and columns. The nodes, sorted
-- by x, fall into runs no wider than a tree; the trees are the largest runs
-- (a node parked far off the canvas makes a run of its own), left to right,
-- like the tree headers. Tiers count from the topmost node, columns from each
-- tree's leftmost one; a node that is not on the grid is left out.
local function ComputeCells()
	wipe(cells)
	wipe(treeTiers)
	local nodes = {}
	for button in talents:EnumerateAllTalentButtons() do
		local nodeID, info = button:GetNodeID(), button:GetNodeInfo()
		if nodeID and info and info.posX and info.posY then
			table.insert(nodes, { id = nodeID, x = info.posX, y = info.posY })
		end
	end
	table.sort(nodes, function(a, b) return a.x < b.x end)

	local runs, run = {}, nil
	for _, node in ipairs(nodes) do
		if not run or node.x - run.left > TREE_SPAN then
			run = { left = node.x, nodes = {} }
			table.insert(runs, run)
		end
		table.insert(run.nodes, node)
	end
	table.sort(runs, function(a, b) return #a.nodes > #b.nodes end)
	for index = #runs, math.max(#trees, 1) + 1, -1 do
		runs[index] = nil
	end
	table.sort(runs, function(a, b) return a.left < b.left end)

	local top
	for _, treeRun in ipairs(runs) do
		for _, node in ipairs(treeRun.nodes) do
			top = math.min(top or node.y, node.y)
		end
	end
	for index, treeRun in ipairs(runs) do
		local tiers = 0
		for _, node in ipairs(treeRun.nodes) do
			local column, tier = Round((node.x - treeRun.left) / NODE_GRID), Round((node.y - top) / NODE_GRID)
			local offGrid = math.abs(node.x - treeRun.left - column * NODE_GRID) > NODE_SLACK or math.abs(node.y - top - tier * NODE_GRID) > NODE_SLACK
			if column < NUM_COLUMNS and tier < MAX_TIERS and not offGrid then
				cells[node.id] = { tree = index, tier = tier + 1, column = column + 1 }
				tiers = math.max(tiers, tier + 1)
			end
		end
		treeTiers[index] = tiers
	end
end

---------------------------------------------------------------------------
-- Talent buttons
---------------------------------------------------------------------------

local function IsDimmed(state)
	return state == VisualState.Gated or state == VisualState.Locked or state == VisualState.Disabled or state == VisualState.Invisible
end

local QueueBranches

-- After Blizzard's SetBorderAtlas (on every state change): the retail node
-- border and its hover copy stay hidden.
local function ClearBorder(button)
	if button.StateBorder then button.StateBorder:SetAlpha(0) end
	if button.StateBorderHover then button.StateBorderHover:SetAlpha(0) end
end

-- After UpdateSpendText: the rank box shows with the rank (Blizzard leaves
-- the rank out of reach and unspent empty, as 1.12 hid it).
local function UpdateRank(button)
	local skin = skins[button]
	local text = button.SpendText and button.SpendText:GetText()
	skin.rank:SetShown(text ~= nil and text ~= "")
end

-- After ApplyVisualState: 1.12's slot and rank colours (TalentFrame_Update).
-- Blizzard desaturates and darkens the icon itself.
local function UpdateButtonState(button)
	local skin = skins[button]
	local state = button:GetVisualState()
	local slot, text, rank = SLOT_AVAILABLE, GREEN_FONT_COLOR, 1
	if state == VisualState.Maxed then
		slot, text = SLOT_MAXED, NORMAL_FONT_COLOR
	elseif state == VisualState.RefundInvalid or state == VisualState.DisplayError then
		slot, text = SLOT_ERROR, RED_FONT_COLOR
	elseif IsDimmed(state) then
		slot, text, rank = SLOT_DIMMED, GRAY_FONT_COLOR, 0.5
	end
	skin.slot:SetVertexColor(unpack(slot))
	skin.rank:SetVertexColor(rank, rank, rank)
	if button.SpendText then
		button.SpendText:SetTextColor(text:GetRGB())
	end
	QueueBranches()
end

-- 1.12 TalentButtonTemplate (an ItemButtonTemplate): the 37px icon in the
-- UI-Quickslot2 frame over the UI-EmptySlot-White slot, the rank in the
-- TalentFrame-RankBorder box on its bottom right corner.
local function SkinButton(button)
	local skin = {}
	skins[button] = skin

	for _, key in ipairs({ "Shadow", "BorderShadow" }) do
		if button[key] then button[key]:SetAlpha(0) end
	end
	-- The sheen and the "selectable" glow are animated (alpha too): no art.
	for _, key in ipairs({ "BorderSheen", "SelectableGlow" }) do
		if button[key] then button[key]:SetTexture(nil) end
	end
	for _, shadow in ipairs(button.spendTextShadows or {}) do
		shadow:SetAlpha(0)
	end
	ns.StripMask(button.IconMask, button.Icon)
	ns.StripMask(button.DisabledOverlayMask, button.DisabledOverlay)
	ClearBorder(button)
	ns.Hook(button, "SetBorderAtlas", ClearBorder)

	skin.slot = button:CreateTexture(nil, "BACKGROUND", nil, -1)
	skin.slot:SetTexture(T.EMPTY_SLOT_WHITE)
	skin.slot:SetSize(64, 64)
	skin.slot:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:SetNormalTexture(T.QUICKSLOT2)
	local normal = button:GetNormalTexture()
	normal:ClearAllPoints()
	normal:SetSize(64, 64)
	normal:SetPoint("CENTER", button, "CENTER", 0, -1)
	button:SetPushedTexture(T.QUICKSLOT_PUSHED)
	button:SetHighlightTexture(T.BUTTON_HIGHLIGHT, "ADD")

	skin.rank = button:CreateTexture(nil, "OVERLAY", nil, 1)
	skin.rank:SetTexture(T.TALENT_RANK_BORDER)
	skin.rank:SetSize(32, 32)
	skin.rank:SetPoint("CENTER", button, "BOTTOMRIGHT", 0, 0)
	if button.SpendText then
		button.SpendText:SetFontObject(GameFontNormalSmall)
		Point(button.SpendText, "CENTER", skin.rank, "CENTER", 0, 0)
	end
	ns.Hook(button, "UpdateSpendText", UpdateRank)
	ns.Hook(button, "ApplyVisualState", UpdateButtonState)
	UpdateRank(button)
	UpdateButtonState(button)
end

-- The button goes onto the vanilla grid if its tree is the one shown,
-- otherwise into the hidden frame. Called after every placement of
-- Blizzard's, which also re-sizes some of the button's regions.
local function PlaceButton(button)
	if not skins[button] then SkinButton(button) end
	local nodeID = button:GetNodeID()
	local cell = nodeID and cells[nodeID]
	if cell and cell.tree == selectedTree then
		button:SetParent(canvas)
		Point(button, "TOPLEFT", canvas, "TOPLEFT", FIRST_X + (cell.column - 1) * SPACING, -(FIRST_Y + (cell.tier - 1) * SPACING))
	else
		button:SetParent(parking)
	end
	button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	for _, key in ipairs({ "Icon", "DisabledOverlay" }) do
		if button[key] then button[key]:SetSize(BUTTON_SIZE, BUTTON_SIZE) end
	end
end

---------------------------------------------------------------------------
-- Branches (1.12 TalentFrame_DrawLines and TalentFrame_Update)
---------------------------------------------------------------------------

local function IsLit(button)
	return not IsDimmed(button:GetVisualState())
end

-- Marks the grid cells a line from the prerequisite (tier, column) to the
-- talent (buttonTier, buttonColumn) runs through, as 1.12 did (a blocked
-- line is not drawn).
local function DrawLines(grid, buttonTier, buttonColumn, tier, column, met)
	met = met and 1 or -1
	if buttonColumn == column then
		for i = tier + 1, buttonTier - 1 do
			if grid[i][buttonColumn].id then return end
		end
		for i = tier, buttonTier - 1 do
			grid[i][buttonColumn].down = met
			if i + 1 <= buttonTier - 1 then
				grid[i + 1][buttonColumn].up = met
			end
		end
		grid[buttonTier][buttonColumn].topArrow = met
		return
	end

	local left, right = math.min(buttonColumn, column), math.max(buttonColumn, column)
	if buttonTier == tier then
		for i = left + 1, right - 1 do
			if grid[tier][i].id then return end
		end
		for i = left, right - 1 do
			grid[tier][i].right = met
			grid[tier][i + 1].left = met
		end
		if buttonColumn < column then
			grid[buttonTier][buttonColumn].rightArrow = met
		else
			grid[buttonTier][buttonColumn].leftArrow = met
		end
		return
	end

	-- Diagonal: across the prerequisite's tier first, then down.
	local from, to = left, right
	if from == column then from = from + 1 else to = to - 1 end
	local blocked = false
	for i = from, to do
		if grid[tier][i].id then blocked = true end
	end
	if not blocked then
		for i = tier, buttonTier - 1 do
			grid[i][buttonColumn].down = met
			grid[i + 1][buttonColumn].up = met
		end
		for i = left, right - 1 do
			grid[tier][i].right = met
			grid[tier][i + 1].left = met
		end
		grid[buttonTier][buttonColumn].topArrow = met
		return
	end
	-- Down first, then across the talent's tier.
	from, to = left, right
	if from == buttonColumn then from = from + 1 else to = to - 1 end
	for i = from, to do
		if grid[buttonTier][i].id then return end
	end
	for i = tier, buttonTier - 1 do
		grid[i][column].up = met
		grid[i + 1][column].down = met
	end
	if buttonColumn < column then
		grid[buttonTier][buttonColumn].rightArrow = met
	else
		grid[buttonTier][buttonColumn].leftArrow = met
	end
end

local function Piece(pool, index, parent, file, layer, coords, x, y)
	local texture = pool[index]
	if not texture then
		texture = parent:CreateTexture(nil, layer)
		texture:SetTexture(file)
		texture:SetSize(PIECE_SIZE, PIECE_SIZE)
		pool[index] = texture
	end
	texture:SetTexCoord(unpack(coords))
	Point(texture, "TOPLEFT", parent, "TOPLEFT", x, y)
	texture:Show()
end

-- The prerequisites come from the shown nodes' edges. The prerequisite is
-- the upper node (a few edges in the data point up); on one tier it is the
-- edge's source. A line is gold when its talent is within reach.
local function DrawBranches()
	branchesQueued = false
	local grid = {}
	for tier = 1, MAX_TIERS do
		grid[tier] = {}
		for column = 1, NUM_COLUMNS do
			grid[tier][column] = { up = 0, down = 0, left = 0, right = 0, leftArrow = 0, rightArrow = 0, topArrow = 0 }
		end
	end
	local shown = {}
	for button in talents:EnumerateAllTalentButtons() do
		local nodeID = button:GetNodeID()
		local cell = nodeID and cells[nodeID]
		if cell and cell.tree == selectedTree and button:GetVisualState() ~= VisualState.Invisible then
			shown[nodeID] = button
			grid[cell.tier][cell.column].id = nodeID
		end
	end
	local lines = {}
	for nodeID, button in pairs(shown) do
		local info = button:GetNodeInfo()
		for _, edge in ipairs(info and info.visibleEdges or {}) do
			local target = shown[edge.targetNode]
			if target then
				local from, to, talent = cells[nodeID], cells[edge.targetNode], target
				if to.tier < from.tier then
					from, to, talent = to, from, button
				end
				table.insert(lines, { from = from, to = to, met = IsLit(talent) })
			end
		end
	end
	-- 1.12 went through the talents in order (tier by tier).
	table.sort(lines, function(a, b)
		if a.to.tier ~= b.to.tier then return a.to.tier < b.to.tier end
		if a.to.column ~= b.to.column then return a.to.column < b.to.column end
		if a.from.tier ~= b.from.tier then return a.from.tier < b.from.tier end
		return a.from.column < b.from.column
	end)
	for _, line in ipairs(lines) do
		DrawLines(grid, line.to.tier, line.to.column, line.from.tier, line.from.column, line.met)
	end

	local branches, arrows = 0, 0
	local function Branch(coords, x, y)
		branches = branches + 1
		Piece(branchPool, branches, canvas, T.TALENT_BRANCHES, "BACKGROUND", coords, x, y)
	end
	local function Arrow(coords, x, y)
		arrows = arrows + 1
		Piece(arrowPool, arrows, arrowLayer, T.TALENT_ARROWS, "OVERLAY", coords, x, y)
	end
	local ignoreUp
	for tier = 1, MAX_TIERS do
		for column = 1, NUM_COLUMNS do
			local node = grid[tier][column]
			local x = (column - 1) * SPACING + FIRST_X + 2
			local y = -((tier - 1) * SPACING) - FIRST_Y - 2
			if node.id then
				if node.up ~= 0 then
					if not ignoreUp then
						Branch(BRANCH_COORDS.up[node.up], x, y + PIECE_SIZE)
					else
						ignoreUp = nil
					end
				end
				if node.down ~= 0 then
					Branch(BRANCH_COORDS.down[node.down], x, y - PIECE_SIZE + 1)
				end
				if node.left ~= 0 then
					Branch(BRANCH_COORDS.left[node.left], x - PIECE_SIZE, y)
				end
				if node.right ~= 0 then
					-- A grey line down from the next cell keeps the joint grey.
					local nextNode = grid[tier][column + 1]
					if nextNode and nextNode.left ~= 0 and nextNode.down < 0 then
						Branch(BRANCH_COORDS.right[nextNode.down], x + PIECE_SIZE, y)
					else
						Branch(BRANCH_COORDS.right[node.right], x + PIECE_SIZE + 1, y)
					end
				end
				if node.rightArrow ~= 0 then
					Arrow(ARROW_COORDS.right[node.rightArrow], x + PIECE_SIZE / 2 + 5, y)
				end
				if node.leftArrow ~= 0 then
					Arrow(ARROW_COORDS.left[node.leftArrow], x - PIECE_SIZE / 2 - 5, y)
				end
				if node.topArrow ~= 0 then
					Arrow(ARROW_COORDS.top[node.topArrow], x, y + PIECE_SIZE / 2 + 5)
				end
			elseif node.up ~= 0 and node.left ~= 0 and node.right ~= 0 then
				Branch(BRANCH_COORDS.tup[node.up], x, y)
			elseif node.down ~= 0 and node.left ~= 0 and node.right ~= 0 then
				Branch(BRANCH_COORDS.tdown[node.down], x, y)
			elseif node.left ~= 0 and node.down ~= 0 then
				Branch(BRANCH_COORDS.topright[node.left], x, y)
				Branch(BRANCH_COORDS.down[node.down], x, y - PIECE_SIZE)
			elseif node.left ~= 0 and node.up ~= 0 then
				Branch(BRANCH_COORDS.bottomright[node.left], x, y)
			elseif node.left ~= 0 and node.right ~= 0 then
				Branch(BRANCH_COORDS.right[node.right], x + PIECE_SIZE, y)
				Branch(BRANCH_COORDS.left[node.left], x + 1, y)
			elseif node.right ~= 0 and node.down ~= 0 then
				Branch(BRANCH_COORDS.topleft[node.right], x, y)
				Branch(BRANCH_COORDS.down[node.down], x, y - PIECE_SIZE)
			elseif node.right ~= 0 and node.up ~= 0 then
				Branch(BRANCH_COORDS.bottomleft[node.right], x, y)
			elseif node.up ~= 0 and node.down ~= 0 then
				Branch(BRANCH_COORDS.up[node.up], x, y)
				Branch(BRANCH_COORDS.down[node.down], x, y - PIECE_SIZE)
				ignoreUp = true
			end
		end
	end
	for index = branches + 1, #branchPool do
		branchPool[index]:Hide()
	end
	for index = arrows + 1, #arrowPool do
		arrowPool[index]:Hide()
	end
end

-- Button states change one node at a time; the branches are redrawn once,
-- on the next frame.
function QueueBranches()
	if branchesQueued or not canvas then return end
	branchesQueued = true
	C_Timer.After(0, function()
		xpcall(DrawBranches, geterrorhandler())
	end)
end

---------------------------------------------------------------------------
-- Scroll frame (1.12 UIPanelScrollFrameTemplate on UI-Character-ScrollBar)
---------------------------------------------------------------------------

local function UpdateScrollButtons()
	local value = scrollBar:GetValue()
	local _, range = scrollBar:GetMinMaxValues()
	scrollUp:SetEnabled(value > 0)
	scrollDown:SetEnabled(value < range)
	scrollThumb:SetShown(range > 0)
end

local function UpdateScrollRange(tiers)
	local height = FIRST_Y + (math.max(tiers, 1) - 1) * SPACING + BUTTON_SIZE
	canvas:SetHeight(math.max(height, VIEW_HEIGHT))
	scrollBar:SetMinMaxValues(0, math.max(0, height - VIEW_HEIGHT))
	scroll:SetVerticalScroll(scrollBar:GetValue())
	UpdateScrollButtons()
end

local function ScrollBy(steps)
	scrollBar:SetValue(scrollBar:GetValue() + steps * scrollBar:GetHeight() / 2)
end

local function CreateScrollButton(prefix, point, relativePoint, steps)
	local button = CreateFrame("Button", nil, scrollBar)
	button:SetSize(16, 16)
	button:SetPoint(point, scrollBar, relativePoint, 0, 0)
	button:SetNormalTexture(prefix .. "Up")
	button:SetPushedTexture(prefix .. "Down")
	button:SetDisabledTexture(prefix .. "Disabled")
	button:SetHighlightTexture(prefix .. "Highlight", "ADD")
	for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(), button:GetHighlightTexture() }) do
		texture:SetTexCoord(0.25, 0.75, 0.25, 0.75)
	end
	button:SetScript("OnClick", function()
		ScrollBy(steps)
		PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
	end)
	return button
end

local function CreateScrollFrame()
	scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetSize(VIEW_WIDTH, VIEW_HEIGHT)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", VIEW_X, VIEW_Y)

	-- The buttons keep the frame levels Blizzard gives them relative to its
	-- canvas, so the frames they move between share its level.
	local level = talents.ButtonsParent:GetFrameLevel()
	canvas = CreateFrame("Frame", nil, scroll)
	canvas:SetSize(VIEW_WIDTH, VIEW_HEIGHT)
	scroll:SetScrollChild(canvas)
	canvas:SetFrameLevel(level)
	parking = CreateFrame("Frame", nil, frame)
	parking:SetFrameLevel(level)
	parking:Hide()
	-- 1.12's arrows were drawn over the buttons.
	arrowLayer = CreateFrame("Frame", nil, canvas)
	arrowLayer:SetAllPoints(canvas)
	arrowLayer:SetFrameLevel(level + 600)

	local trough = scroll:CreateTexture(nil, "ARTWORK")
	ns.SetTexture(trough, T.CHARACTER_SCROLLBAR, 0, 0.484375, 0, 1)
	trough:SetSize(31, 256)
	trough:SetPoint("TOPLEFT", scroll, "TOPRIGHT", -2, 5)
	local troughEnd = scroll:CreateTexture(nil, "ARTWORK")
	ns.SetTexture(troughEnd, T.CHARACTER_SCROLLBAR, 0.515625, 1, 0, 0.4140625)
	troughEnd:SetSize(31, 106)
	troughEnd:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -2, -2)

	scrollBar = CreateFrame("Slider", nil, scroll)
	scrollBar:SetWidth(16)
	scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, -16)
	scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 16)
	scrollBar:SetOrientation("VERTICAL")
	scrollThumb = scrollBar:CreateTexture(nil, "OVERLAY")
	ns.SetTexture(scrollThumb, T.SCROLL_KNOB, 0.2, 0.8, 0.125, 0.875)
	scrollThumb:SetSize(18, 24)
	scrollBar:SetThumbTexture(scrollThumb)
	scrollBar:SetMinMaxValues(0, 0)
	scrollBar:SetValue(0)
	scrollUp = CreateScrollButton(T.SCROLL_UP, "BOTTOM", "TOP", -1)
	scrollDown = CreateScrollButton(T.SCROLL_DOWN, "TOP", "BOTTOM", 1)
	scrollBar:SetScript("OnValueChanged", function(_, value)
		scroll:SetVerticalScroll(value)
		UpdateScrollButtons()
	end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		ScrollBy(-delta)
	end)
end

---------------------------------------------------------------------------
-- Tree tabs (1.12 TalentTabTemplate: CharacterFrameTabButtonTemplate)
---------------------------------------------------------------------------

-- UI-Character-InActiveTab pieces with 20px ends (the retail
-- UI-Character-ActiveTab is a different tab). The tab's body is black up to
-- its top row and the frame's bottom border reaches 7px into it, so the
-- border's bottom rows are drawn again over the tabs (CreateFrameArt): the
-- tabs hang behind the border. That hides 1.12's rise of the selected tab,
-- so all hang alike; the selected one has the white text.
local TAB_BORDER_TOP, TAB_BORDER_BOTTOM = 433, 441 -- the border rows drawn over the tabs (frame y)

local ShowTree

local function CreateTreeTab(index)
	local tab = CreateFrame("Button", nil, frame)
	tab:SetHeight(32)
	tab:SetFrameLevel(frame:GetFrameLevel() + 4)
	local left = tab:CreateTexture(nil, "BACKGROUND")
	ns.SetTexture(left, T.TAB_INACTIVE, 0, 0.15625, 0, 1)
	left:SetSize(TAB_END, 32)
	left:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
	tab.middle = tab:CreateTexture(nil, "BACKGROUND")
	ns.SetTexture(tab.middle, T.TAB_INACTIVE, 0.15625, 0.84375, 0, 1)
	tab.middle:SetHeight(32)
	tab.middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
	local right = tab:CreateTexture(nil, "BACKGROUND")
	ns.SetTexture(right, T.TAB_INACTIVE, 0.84375, 1, 0, 1)
	right:SetSize(TAB_END, 32)
	right:SetPoint("LEFT", tab.middle, "RIGHT", 0, 0)

	tab:SetNormalFontObject(GameFontNormalSmall)
	tab:SetHighlightFontObject(GameFontHighlightSmall)
	tab:SetDisabledFontObject(GameFontHighlightSmall)
	tab:SetText(" ")
	Point(tab:GetFontString(), "CENTER", tab, "CENTER", 0, 2)
	tab:SetHighlightTexture(T.TAB_HIGHLIGHT, "ADD")
	local highlight = tab:GetHighlightTexture()
	highlight:ClearAllPoints()
	highlight:SetHeight(32)
	highlight:SetPoint("LEFT", tab, "LEFT", 10, 2)
	highlight:SetPoint("RIGHT", tab, "RIGHT", -10, 2)

	if index == 1 then
		tab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", TAB_X, TAB_Y)
	else
		tab:SetPoint("LEFT", treeTabs[index - 1], "RIGHT", -TAB_OVERLAP, 0)
	end
	tab:SetScript("OnClick", function()
		selectedTree = index
		ShowTree()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	end)
	treeTabs[index] = tab
	return tab
end

local function UpdateTreeTabs()
	for index = 1, math.max(#trees, #treeTabs) do
		local tab = treeTabs[index] or CreateTreeTab(index)
		local tree = trees[index]
		tab:SetShown(tree ~= nil)
		if tree then
			local selected = index == selectedTree
			tab:SetText(tree.name)
			local width = tab:GetFontString():GetStringWidth() + TAB_PADDING
			tab.middle:SetWidth(width)
			tab:SetWidth(width + 2 * TAB_END)
			tab:SetEnabled(not selected)
		end
	end
end

---------------------------------------------------------------------------
-- Spec tabs (3.x PlayerSpecTab: SpellBook-SkillLineTab, gilded when active)
---------------------------------------------------------------------------

-- The icon of the tree the spec group has most points in (3.x's primary
-- tree), none while nothing is spent.
local function SpecIcon(specGroup)
	local configID = C_SpecializationInfo.GetCombatConfigIDForSpecGroup and C_SpecializationInfo.GetCombatConfigIDForSpecGroup(specGroup)
	if not configID or #trees == 0 then return end
	local groupIDs = {}
	for index, tree in ipairs(trees) do
		groupIDs[index] = tree.groupID
	end
	local best, bestSpent = nil, 0
	for _, groupInfo in ipairs(C_Traits.GetGroupCurrencyInfo(configID, groupIDs) or {}) do
		local currency = groupInfo.currencyInfos and groupInfo.currencyInfos[1]
		local spent = currency and currency.spent or 0
		if spent > bestSpent then
			best, bestSpent = groupInfo.traitNodeGroupID, spent
		end
	end
	for _, tree in ipairs(trees) do
		if tree.groupID == best then return tree.icon end
	end
end

local function UpdateSpecTab(tab)
	local skin = skins[tab]
	local active = tab.IsActive and tab:IsActive()
	skin.background:SetTexture(active and ns.HasTexture(T.SKILLTAB_GLOW) and T.SKILLTAB_GLOW or T.SPELLBOOK_SKILLTAB)
	skin.checked:SetShown(tab.isSelected == true)
	local icon = tab.GetTabID and SpecIcon(tab:GetTabID())
	skin.icon:SetTexCoord(0, 1, 0, 1)
	if icon then
		skin.icon:SetTexture(icon)
	else
		SetPortraitTexture(skin.icon, "player")
	end
	-- The locked second spec (Blizzard disables it with the reason as its tooltip).
	skin.icon:SetDesaturated(not tab.isSelected and not tab:IsEnabled())
end

local function SkinSpecTab(tab)
	local skin = skins[tab]
	if skin then return skin end
	skin = {}
	skins[tab] = skin

	skin.background = tab:CreateTexture(nil, "BACKGROUND")
	skin.background:SetSize(64, 64)
	skin.background:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
	skin.icon = tab:CreateTexture(nil, "ARTWORK")
	skin.icon:SetAllPoints(tab)
	skin.checked = tab:CreateTexture(nil, "OVERLAY")
	skin.checked:SetTexture(T.BUTTON_CHECKED)
	skin.checked:SetBlendMode("ADD")
	skin.checked:SetAllPoints(tab)
	skin.checked:Hide()

	tab:SetHighlightTexture(T.BUTTON_HIGHLIGHT, "ADD")
	ns.Hook(tab, "SetTabSelected", UpdateSpecTab)
	return skin
end

-- After the spec tab bar's Layout (and whenever the specs change): the tabs
-- go down the frame's right edge. The bar itself stays invisible.
local function LayoutSpecTabs()
	local index = 0
	for _, tab in ipairs(talents.TabSystem.tabs or {}) do
		if tab:IsShown() then
			SkinSpecTab(tab)
			for _, key in ipairs(SIDE_TAB_ART) do
				if tab[key] then tab[key]:SetAlpha(0) end
			end
			tab:SetSize(SPEC_TAB_SIZE, SPEC_TAB_SIZE)
			Point(tab, "TOPLEFT", frame, "TOPLEFT", SPEC_TAB_X, SPEC_TAB_Y - index * (SPEC_TAB_SIZE + SPEC_TAB_GAP))
			UpdateSpecTab(tab)
			index = index + 1
		end
	end
end

---------------------------------------------------------------------------
-- Boxes: the spent points (top), the search and talent points (bottom bar)
---------------------------------------------------------------------------

local function UpdateSpentText()
	local tree = trees[selectedTree]
	if tree then
		spentText:SetFormattedText(MASTERY_POINTS_SPENT or "%s Talents: %s", tree.name, HIGHLIGHT_FONT_COLOR_CODE .. tree.spent .. FONT_COLOR_CODE_CLOSE)
	else
		spentText:SetText("")
	end
end

-- The box under the title ends left of the buttons Blizzard shows at its
-- right end: "Activate" (while the inactive spec is looked at) and undo /
-- reset (one of them). Only unprotected frames are anchored here.
local function LayoutBox()
	local anchor, relativePoint, x, y = frame, "TOPLEFT", BOX_RIGHT, BOX_Y - BOX_HEIGHT / 2
	local activate = talents.ActiveSpec and talents.ActiveSpec.ActivateButton
	if activate and talents.ActiveSpec:IsShown() and activate:IsShown() then
		Point(activate, "RIGHT", anchor, relativePoint, x, y)
		anchor, relativePoint, x, y = activate, "LEFT", -4, 0
	end
	for _, button in ipairs({ talents.UndoButton, talents.ResetButton }) do
		if button then
			Point(button, "RIGHT", anchor, relativePoint, x, y)
		end
	end
	local undo, reset = talents.UndoButton, talents.ResetButton
	if (undo and undo:IsShown()) or (reset and reset:IsShown()) then
		anchor, relativePoint, x, y = undo and undo:IsShown() and undo or reset, "LEFT", -4, 0
	end
	box[3]:ClearAllPoints()
	box[3]:SetPoint("RIGHT", anchor, relativePoint, x, y)
end

-- The search box sits in the bottom bar without its own border, then its
-- options arrow, then the talent points (1.12's place).
local function LayoutBar()
	local search, options = talents.SearchBox, talents.SearchOptionsDropdown
	local right, relativePoint = pointsLabel, "LEFT"
	if options then
		Point(options, "RIGHT", pointsLabel, "LEFT", -4, 0)
		right = options
	end
	if search then
		search:ClearAllPoints()
		search:SetPoint("LEFT", frame, "TOPLEFT", BAR_LEFT, BAR_Y)
		search:SetPoint("RIGHT", right, relativePoint, -4, 0)
	end
end

local function CreateBoxes()
	local function BoxPiece(left, right, width)
		local texture = frame:CreateTexture(nil, "OVERLAY")
		ns.SetTexture(texture, T.INPUT_BORDER_BOX, left, right, 0, 0.625)
		texture:SetSize(width, BOX_HEIGHT)
		return texture
	end
	box[1] = BoxPiece(0, 0.0625, 8)
	box[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", BOX_LEFT, BOX_Y)
	box[3] = BoxPiece(0.9375, 1, 8)
	box[2] = BoxPiece(0.0625, 0.9375, 8)
	box[2]:SetPoint("TOPLEFT", box[1], "TOPRIGHT", 0, 0)
	box[2]:SetPoint("BOTTOMRIGHT", box[3], "BOTTOMLEFT", 0, 0)
	spentText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	spentText:SetPoint("TOP", box[2], "TOP", 0, -5)

	pointsText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pointsText:SetPoint("RIGHT", frame, "TOPLEFT", POINTS_RIGHT, BAR_Y)
	pointsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pointsLabel:SetPoint("RIGHT", pointsText, "LEFT", -3, 0)
	pointsLabel:SetText(CHARACTER_POINTS1_COLON or (UNSPENT_POINTS or "Talent Points") .. ":")
end

---------------------------------------------------------------------------
-- The frame
---------------------------------------------------------------------------

local function CreateFrameArt()
	frame = CreateFrame("Frame", nil, talents)
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	frame:SetFrameLevel(talents:GetFrameLevel())
	frame:SetHitRectInsets(0, HIT_INSET_RIGHT, 0, HIT_INSET_BOTTOM)
	frame:EnableMouse(true)

	portrait = frame:CreateTexture(nil, "BACKGROUND")
	portrait:SetSize(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
	local function Art(file, width, x, y)
		local texture = frame:CreateTexture(nil, "BORDER")
		texture:SetTexture(file)
		texture:SetSize(width, 256)
		texture:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
	end
	Art(T.TALENT_FRAME_TOP .. "TopLeft", 256, 2, -1)
	Art(T.TALENT_FRAME_TOP .. "TopRight", 128, 258, -1)
	Art(T.TALENT_FRAME_BOTTOM .. "BotLeft", 256, 2, -257)
	Art(T.TALENT_FRAME_BOTTOM .. "BotRight", 128, 258, -257)
	-- The bottom border again, over the tree tabs (see CreateTreeTab).
	local borderOver = CreateFrame("Frame", nil, frame)
	borderOver:SetAllPoints(frame)
	borderOver:SetFrameLevel(frame:GetFrameLevel() + 5)
	for _, piece in ipairs({ { "BotLeft", 256, 2 }, { "BotRight", 128, 258 } }) do
		local texture = borderOver:CreateTexture(nil, "ARTWORK")
		ns.SetTexture(texture, T.TALENT_FRAME_BOTTOM .. piece[1], 0, 1, (TAB_BORDER_TOP - 257) / 256, (TAB_BORDER_BOTTOM - 257) / 256)
		texture:SetSize(piece[2], TAB_BORDER_BOTTOM - TAB_BORDER_TOP)
		texture:SetPoint("TOPLEFT", frame, "TOPLEFT", piece[3], -TAB_BORDER_TOP)
	end
	for index, size in ipairs({ { 256, 256, 0, 0 }, { 64, 256, 256, 0 }, { 256, 128, 0, -256 }, { 64, 128, 256, -256 } }) do
		local texture = frame:CreateTexture(nil, "ARTWORK")
		texture:SetSize(size[1], size[2])
		texture:SetPoint("TOPLEFT", frame, "TOPLEFT", VIEW_X + size[3], VIEW_Y + size[4])
		background[index] = texture
	end

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", frame, "TOP", 0, TITLE_Y)
	title:SetText(TALENTS or "Talents")

	CreateBoxes()
	CreateScrollFrame()

	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
	frame:SetScript("OnEvent", function()
		SetPortraitTexture(portrait, "player")
	end)
end

local BACKGROUND_PIECES = { "TopLeft", "TopRight", "BottomLeft", "BottomRight" }

-- The selected tree: its buttons onto the grid (the others away), its
-- background, tab, spent points, scroll range and branches.
function ShowTree()
	if selectedTree > math.max(#trees, 1) then
		selectedTree = 1
	end
	for button in talents:EnumerateAllTalentButtons() do
		PlaceButton(button)
	end
	local name = TreeBackground(selectedTree)
	if not ns.HasTexture(T.TALENT_TREE .. name .. "-TopLeft") then
		name = DEFAULT_BACKGROUND
	end
	for index, piece in ipairs(BACKGROUND_PIECES) do
		background[index]:SetTexture(T.TALENT_TREE .. name .. "-" .. piece)
	end
	UpdateTreeTabs()
	UpdateSpentText()
	UpdateScrollRange(treeTiers[selectedTree] or 1)
	QueueBranches()
end

-- After RefreshTreeHeaders (every currency update): Blizzard's headers stay
-- hidden, the trees' names and points go to the tabs and boxes.
local function RefreshTrees()
	for _, header in ipairs(talents.treeHeaders or {}) do
		header:SetAlpha(0)
	end
	UpdateTrees()
	UpdateTreeTabs()
	UpdateSpentText()
	LayoutSpecTabs()
end

-- After LoadTalentTreeInternal: every button of the tree has been (re)made.
local function Layout()
	ComputeCells()
	ShowTree()
end

-- The spot and scale of the classic spellbook (SpellBook.lua draws it at
-- the left edge of Blizzard's compact spellbook panel, on the other panels'
-- line). The panel manager scales a panel down to fit the screen with its
-- checkFit margins (FrameUtil.UpdateScaleForFitSpecific) and puts the
-- compact panel, alone, centred with centerXOffset -405
-- (PlayerSpellsFrameMixin:SetMinimized), in panel units.
local COMPACT_CENTER_OFFSET = -405

local function SpellBookSpot()
	local width = book.spellBookMinimizedWidth or 809
	local height = book.spellBookHeight or 720
	local extraWidth = GetUIPanelAttribute and GetUIPanelAttribute(book, "checkFitExtraWidth") or 200
	local extraHeight = GetUIPanelAttribute and GetUIPanelAttribute(book, "checkFitExtraHeight") or 140
	local scale = math.min(1, UIParent:GetWidth() / (width + extraWidth), UIParent:GetHeight() / (height + extraHeight))
	local left = UIParent:GetWidth() / 2 + (COMPACT_CENTER_OFFSET - width / 2) * scale
	return left, ns.PlayerSpellsPanel.Top(0, STANDARD_PANEL_HEIGHT), scale
end

-- On every show of the page: the frame goes where the classic spellbook
-- opens, at its scale (the talents' own panel is centred and larger).
local function UpdateFrame()
	local left, top, scale = SpellBookSpot()
	frame:SetScale(scale * UIParent:GetEffectiveScale() / talents:GetEffectiveScale())
	Point(frame, "TOPLEFT", UIParent, "TOPLEFT", left / scale, top / scale)
	SetPortraitTexture(portrait, book.GetInspectUnit and book:GetInspectUnit() or "player")
	LayoutBox()
	LayoutBar()
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

local function SkinPage()
	-- Blizzard's backgrounds, borders, dividers and their animations.
	talents:SetDrawLayerEnabled("BACKGROUND", false)
	talents:SetDrawLayerEnabled("OVERLAY", false)
	for _, key in ipairs({ "ClassCurrencyDisplay", "HeroTalentsContainer" }) do
		if talents[key] then talents[key]:SetAlpha(0) end
	end
	-- The canvas stays at the panel's centre, empty: it gives up the mouse
	-- it takes for panning and zooming.
	talents.ButtonsParent:EnableMouse(false)
	talents.ButtonsParent:EnableMouseWheel(false)
	-- Shown while a change is committed or the spec switched: over the tree.
	if talents.DisabledOverlay then
		talents.DisabledOverlay:ClearAllPoints()
		talents.DisabledOverlay:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
		talents.DisabledOverlay:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
	end

	ns.Hook(talents, "UpdateTalentButtonPosition", function(_, button)
		PlaceButton(button)
		QueueBranches()
	end)
	ns.Hook(talents, "LoadTalentTreeInternal", Layout)
	-- Edges are parented to their start button's parent, gates to the
	-- canvas, and anchored to the buttons: both go out of sight.
	ns.Hook(talents, "UpdateEdgeFrameLevel", function(_, edge)
		edge:SetParent(parking)
	end)
	ns.Hook(talents, "AnchorGate", function(_, gate)
		gate:SetParent(parking)
	end)
	ns.Hook(talents, "RefreshTreeHeaders", RefreshTrees)

	if talents.ClassCurrencyDisplay then
		ns.Hook(talents.ClassCurrencyDisplay, "SetAmount", function(_, amount)
			pointsText:SetText(amount)
		end)
	end

	-- Spec tabs.
	local tabs = talents.TabSystem
	Point(tabs, "TOPRIGHT", frame, "TOPLEFT", 0, SPEC_TAB_Y)
	ns.Hook(tabs, "Layout", LayoutSpecTabs)
	ns.Hook(talents, "UpdateTabs", LayoutSpecTabs)

	-- "Activate", undo / reset: the box under the title. 3.x marked the
	-- active spec by its tab only.
	local activeSpec = talents.ActiveSpec
	if activeSpec then
		if activeSpec.ActiveLabel then activeSpec.ActiveLabel:SetAlpha(0) end
		if activeSpec.ActivateButton then
			activeSpec.ActivateButton:SetSize(80, 22)
			activeSpec.ActivateButton:HookScript("OnShow", LayoutBox)
			activeSpec.ActivateButton:HookScript("OnHide", LayoutBox)
		end
		activeSpec:HookScript("OnShow", LayoutBox)
		activeSpec:HookScript("OnHide", LayoutBox)
	end
	for _, button in ipairs({ talents.UndoButton, talents.ResetButton }) do
		button:HookScript("OnShow", LayoutBox)
		button:HookScript("OnHide", LayoutBox)
	end

	-- Search: the bottom bar is its border. Its results hang below it (their
	-- art has no top edge), over the tabs; the box is narrower than the list.
	local search = talents.SearchBox
	for _, key in ipairs({ "Left", "Middle", "Right" }) do
		if search[key] then search[key]:SetAlpha(0) end
	end
	search:SetHeight(20)
	if talents.SearchPreviewContainer then
		Point(talents.SearchPreviewContainer, "TOPLEFT", search, "BOTTOMLEFT", 0, 2)
	end
	ns.Hook(talents, "UpdateInspecting", LayoutBar)

	-- "Apply Changes" is 3.x's "Learn" (its talent preview) in 1.12's slot of
	-- the Close button; while inspecting, the copy button takes the slot.
	local apply = talents.ApplyButton
	apply:SetSize(80, 22)
	apply:SetText(LEARN or "Learn")
	Point(apply, "CENTER", frame, "TOPLEFT", LEARN_X, BAR_Y)
	if talents.InspectCopyButton then
		Point(talents.InspectCopyButton, "RIGHT", apply, "RIGHT", 0, 0)
	end
end

local function Skin()
	book = PlayerSpellsFrame
	talents = book and book.TalentsFrame
	if frame or not (talents and talents.ButtonsParent and talents.TabSystem and talents.EnumerateAllTalentButtons
		and talents.SearchBox and talents.ApplyButton and talents.UndoButton and talents.ResetButton
		and talents.SetDrawLayerEnabled and book.CloseButton and TalentButtonUtil and TalentButtonUtil.BaseVisualState) then
		return
	end
	VisualState = TalentButtonUtil.BaseVisualState

	CreateFrameArt()
	SkinPage()
	-- The round classic close button sits in the frame's top right corner.
	ns.PlayerSpellsPanel.Register(talents, function(close)
		Point(close, "CENTER", frame, "TOPLEFT", CLOSE_X, CLOSE_Y)
	end)
	talents:HookScript("OnShow", UpdateFrame)
	LayoutBox()
	LayoutBar()
	RefreshTrees()
	if talents:IsShown() then
		UpdateFrame()
		Layout()
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, _, name)
	if name == BLIZZARD_ADDON then
		self:UnregisterEvent("ADDON_LOADED")
		xpcall(Skin, geterrorhandler())
	end
end)

function module:Apply()
	if not (C_Traits and C_Traits.GetGroupDisplayInfoByTreeID) then return end
	local required = {
		T.TALENT_FRAME_TOP .. "TopLeft", T.TALENT_FRAME_TOP .. "TopRight",
		T.TALENT_FRAME_BOTTOM .. "BotLeft", T.TALENT_FRAME_BOTTOM .. "BotRight",
		T.TALENT_BRANCHES, T.TALENT_ARROWS, T.TALENT_RANK_BORDER,
	}
	for _, file in ipairs(required) do
		if not ns.HasTexture(file) then
			ns.Print("This client does not ship " .. file .. "; the talents keep the retail look.")
			return
		end
	end
	if C_AddOns.IsAddOnLoaded(BLIZZARD_ADDON) then
		Skin()
	else
		eventFrame:RegisterEvent("ADDON_LOADED")
	end
end
