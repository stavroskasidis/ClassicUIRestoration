--[[
	Forevermore Classic UI - Quest Tracker

	The vanilla quest watch look (QuestWatchFrame, 1.12) on the modern
	objective tracker: plain gold and white text on the screen, with no
	header plates, glows or check marks.

	Vanilla listed each watched quest as its title (dark gold, bright gold
	once every objective was met) over " - objective" lines in light grey,
	turning white when met. The retail tracker already draws titles and
	open objectives in those colours (OBJECTIVE_TRACKER_COLOR "Header" /
	"Normal"); what it adds is dressed away here:
	  * the header plates (ui-questtracker-primary / -secondary-objective-
	    header) behind "All Objectives" and each section, and their shine
	    and glow, are hidden; the section names stay as plain gold text,
	  * the collapse buttons get the vanilla +/- (UI-MinusButton / UI-Plus-
	    Button, as the quest log's zone headers), re-applied after every
	    Header:SetCollapsed, which puts the modern atlases back,
	  * a met objective is drawn white with its dash, as in vanilla, instead
	    of dimmed grey behind a check mark; the title turns bright gold once
	    the quest is complete (not while WoW Forever's quest difficulty
	    colours are on, which colour the title by level),
	  * the glow sweeps over new and completed lines and titles are hidden,
	  * the quest item buttons get the square UI-Quickslot2 slot the 3.x
	    watch frame drew them in,
	  * in the quest sections the POI button before each title (vanilla had
	    none) is hidden and the quests get vanilla's spacing: titles at the
	    left edge, objectives right under them, 4px between quests (see
	    Compact).
	The tracker stays Blizzard's (its sections, clicks, menus, quest items,
	Edit Mode position and text size): every change is a widget call made
	after Blizzard's own pass, from hooks on each module's EndLayout (blocks
	and lines) and each header's SetCollapsed. No Lua field is written on
	Blizzard's frames; the
	regions changed are kept in weak tables here, so the module can be
	switched off live. It never calls into the tracker: the tracker holds the
	quest item buttons, and a tracker update run from addon code would carry
	the taint into them.

	The tracker's modules are added to ObjectiveTrackerFrame only after
	PLAYER_ENTERING_WORLD (ObjectiveTrackerManager:Init), so the named module
	frames are skinned directly and the container's AddModule is hooked for
	any other.
]]

local _, ns = ...
local T = ns.T

T.PLUS_BUTTON  = "Interface\\Buttons\\UI-PlusButton-"  -- + Up / Down / Hilight
T.MINUS_BUTTON = "Interface\\Buttons\\UI-MinusButton-" -- + Up / Down

local module = ns:RegisterModule({
	key = "questtracker",
	name = "Quest Tracker",
	tooltip = "The vanilla quest watch look on the objective tracker: plain gold titles and white objectives without the modern header plates, glows and check marks, with the classic +/- collapse buttons.",
	live = true,
})

-- The modules Blizzard's ObjectiveTrackerManager:Init puts in the tracker.
local MODULE_NAMES = {
	"ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker",
	"QuestObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker",
	"MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker", "ProfessionsRecipeTracker",
	"BonusObjectiveTracker", "WorldQuestObjectiveTracker",
}

-- Modules whose blocks are quests (block id = quest ID, lines = objectives).
local QUEST_MODULES = { "QuestObjectiveTracker", "CampaignQuestObjectiveTracker" }

local HEADER_ART = { "Background", "Shine", "Glow" }
local LINE_ART = { "Glow", "CheckGlow" }

-- The modern collapse button atlases (Blizzard_ObjectiveTrackerContainer /
-- -Module .xml and SetCollapsed), put back on disable.
local MINIMIZE_ATLAS = {
	container = {
		collapse = "ui-questtrackerbutton-collapse-all", expand = "ui-questtrackerbutton-expand-all",
		highlight = "ui-questtrackerbutton-red-highlight",
	},
	module = {
		collapse = "ui-questtrackerbutton-secondary-collapse", expand = "ui-questtrackerbutton-secondary-expand",
		highlight = "ui-questtrackerbutton-yellow-highlight",
	},
}
local ITEM_FRAME_ATLAS = "UI-QuestTrackerButton-QuestItem-Frame"
local ITEM_BUTTON_TEMPLATE = "QuestObjectiveItemButtonTemplate"

-- QuestWatch_Update: a met objective in white, a complete quest's title in
-- NORMAL_FONT_COLOR.
local OBJECTIVE_DONE = { 1, 1, 1 }
local TITLE_DONE = { 1, 0.82, 0 }

local enabled = false
local hooked = false

-- What was changed, so that Disable can put it back.
local headers = setmetatable({}, { __mode = "k" })          -- header -> "container" / "module"
local hidden = setmetatable({}, { __mode = "k" })           -- region -> true
local buttonTextures = setmetatable({}, { __mode = "k" })   -- minimize texture -> { width, height, points }
local doneLines = setmetatable({}, { __mode = "k" })        -- line -> true (drawn white with its dash)
local brightTitles = setmetatable({}, { __mode = "k" })     -- block -> true
local itemButtons = setmetatable({}, { __mode = "k" })      -- item button -> true
local compacted = setmetatable({}, { __mode = "k" })        -- quest block -> true (vanilla spacing, no POI button)
local hookedModules = setmetatable({}, { __mode = "k" })
local hookedBlocks = setmetatable({}, { __mode = "k" })

local function IsQuestModule(trackerModule)
	for _, name in ipairs(QUEST_MODULES) do
		if _G[name] == trackerModule then return true end
	end
	return false
end

-- Hides a piece of art Blizzard only ever fades in and out (its animations
-- set the alpha, which does not show a hidden texture).
local function Hide(region)
	if region and region.GetObjectType and region:GetObjectType() == "Texture" then
		region:Hide()
		hidden[region] = true
	end
end

-- The text colour Blizzard last gave a font string (SetStringText and
-- UpdateHighlight cache the style they applied in `colorStyle`).
local function ResetColor(fontString)
	local style = fontString and fontString.colorStyle
	if style then
		fontString:SetTextColor(style.r, style.g, style.b)
	end
end

-- Blizzard's own colour and dash for a line drawn as a met objective.
local function ResetLine(line)
	ResetColor(line.Text)
	local dash = line.Dash
	if not dash then return end
	if line.dashStyle then
		dash:SetShown(line.dashStyle == OBJECTIVE_DASH_STYLE_SHOW)
	end
	local style = line.Text and line.Text.colorStyle
	if style then
		dash:SetTextColor(style.r, style.g, style.b)
	end
end

---------------------------------------------------------------------------
-- Headers and their collapse buttons
---------------------------------------------------------------------------

local function RememberGeometry(texture)
	if buttonTextures[texture] then return end
	local state = { width = texture:GetWidth(), height = texture:GetHeight(), points = {} }
	for i = 1, texture:GetNumPoints() do
		state.points[i] = { texture:GetPoint(i) }
	end
	buttonTextures[texture] = state
end

local function RestoreGeometry(texture)
	local state = buttonTextures[texture]
	if not state then return end
	texture:ClearAllPoints()
	for _, point in ipairs(state.points) do
		texture:SetPoint(unpack(point))
	end
	texture:SetSize(state.width, state.height)
end

local function ButtonTextures(button)
	return button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()
end

-- The vanilla +/- at the quest log's 16px, centred on Blizzard's button.
local function ClassicTexture(texture, file, button)
	if not texture then return end
	RememberGeometry(texture)
	ns.SetTexture(texture, file)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", button, "CENTER", 0, 0)
	texture:SetSize(16, 16)
end

local function SkinMinimizeButton(header, collapsed)
	local button = header.MinimizeButton
	if not button then return end
	local normal, pushed, highlight = ButtonTextures(button)
	local prefix = collapsed and T.PLUS_BUTTON or T.MINUS_BUTTON
	ClassicTexture(normal, prefix .. "Up", button)
	ClassicTexture(pushed, prefix .. "Down", button)
	ClassicTexture(highlight, T.PLUS_BUTTON .. "Hilight", button)
	if highlight then highlight:SetBlendMode("ADD") end
end

local function RestoreMinimizeButton(header, kind)
	local button = header.MinimizeButton
	local atlas = MINIMIZE_ATLAS[kind]
	if not button or not atlas then return end
	local collapsed = header:GetParent() and header:GetParent().isCollapsed
	local normal, pushed, highlight = ButtonTextures(button)
	local name = collapsed and atlas.expand or atlas.collapse
	if normal then
		RestoreGeometry(normal)
		ns.SetAtlas(normal, name, true)
	end
	if pushed then
		RestoreGeometry(pushed)
		ns.SetAtlas(pushed, name .. "-pressed", true)
	end
	if highlight then
		RestoreGeometry(highlight)
		ns.SetAtlas(highlight, atlas.highlight, true)
	end
end

local function SkinHeader(header, kind)
	if not header then return end
	if not headers[header] then
		headers[header] = kind
		-- Runs after Blizzard put the modern atlas for the new state back.
		ns.Hook(header, "SetCollapsed", function(self, collapsed)
			if enabled then SkinMinimizeButton(self, collapsed) end
		end)
	end
	for _, key in ipairs(HEADER_ART) do
		Hide(header[key])
	end
	local owner = header:GetParent()
	SkinMinimizeButton(header, owner and owner.isCollapsed)
end

---------------------------------------------------------------------------
-- Blocks (one per quest / achievement / ...) and their lines
---------------------------------------------------------------------------

local function DifficultyColorsShown()
	return C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("showQuestDifficultyColor") == true
end

local function SkinTitle(block)
	local text = block.HeaderText
	if not text then return end
	local questID = block.id
	local complete = type(questID) == "number" and not DifficultyColorsShown()
		and C_QuestLog.IsComplete(questID)
	if complete then
		text:SetTextColor(TITLE_DONE[1], TITLE_DONE[2], TITLE_DONE[3])
		brightTitles[block] = true
	elseif brightTitles[block] then
		brightTitles[block] = nil
		ResetColor(text)
	end
end

-- An objective line of a quest that Blizzard marked met (its own key, the
-- objective index, in the "Complete" colour); "QuestComplete" and the other
-- lines Blizzard adds with that colour are not objectives.
local function IsMetObjective(line, objectiveKey)
	return type(objectiveKey) == "number" and line.Text
		and line.Text.colorStyle == OBJECTIVE_TRACKER_COLOR["Complete"]
end

local function SkinLine(line, objectiveKey, questBlock)
	for _, key in ipairs(LINE_ART) do
		Hide(line[key])
	end
	local dash = line.Dash
	if questBlock and IsMetObjective(line, objectiveKey) then
		doneLines[line] = true
		line.Text:SetTextColor(OBJECTIVE_DONE[1], OBJECTIVE_DONE[2], OBJECTIVE_DONE[3])
		if line.Icon then line.Icon:Hide() end
		if dash then
			dash:SetTextColor(OBJECTIVE_DONE[1], OBJECTIVE_DONE[2], OBJECTIVE_DONE[3])
			dash:Show()
		end
	elseif doneLines[line] then
		-- Lines are pooled: one drawn as a met objective may come back as
		-- another line with the same cached colour and dash style, which
		-- Blizzard then leaves as it is.
		doneLines[line] = nil
		ResetLine(line)
	end
end

-- The 3.x watch frame's item slot (WatchFrameItemButtonTemplate): the
-- 42px UI-Quickslot2 over the 26px button, UI-Quickslot-Depress pushed.
local function SkinItemButton(button)
	if itemButtons[button] then return end
	itemButtons[button] = true
	local normal, pushed = button:GetNormalTexture(), button:GetPushedTexture()
	if normal then ns.SetTexture(normal, T.QUICKSLOT2) end
	if pushed then ns.SetTexture(pushed, T.QUICKSLOT_PUSHED) end
end

---------------------------------------------------------------------------
-- The vanilla spacing of the quest blocks
---------------------------------------------------------------------------

-- The first point of a region with the given name.
local function FindPoint(region, wanted)
	for i = 1, region:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = region:GetPoint(i)
		if point == wanted then
			return relativeTo, relativePoint, x, y
		end
	end
end

local function Near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.01
end

-- Moves the lines Blizzard stacked `from` apart (AddObjective anchors each
-- line `lineSpacing` under the previous region) to `to` apart, and returns
-- how much taller the block is with them, per line moved.
local function RestackLines(block, from, to)
	local moved = 0
	for _, line in pairs(block.usedLines) do
		local relativeTo, relativePoint, x, y = FindPoint(line, "TOPLEFT")
		if relativeTo and relativePoint == "BOTTOMLEFT" and (Near(y, -from) or Near(y, -to)) then
			line:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", x, -to)
			moved = moved + 1
		end
	end
	return moved
end

-- QuestWatch_Update's layout: the title at the left edge (vanilla had no
-- POI button before it; here it lines up with the section name), the
-- objectives under it on 13px rows (1px under the 12px font), the next
-- quest 4px down.
-- Blizzard lays the blocks out 20px in, lines 4px and blocks 10px apart
-- (the module's blockOffsetX / lineSpacing / fromBlockOffsetY); the block
-- and line anchors it set are read back and only their offsets changed,
-- and the block is made as much shorter as its lines moved up. The module
-- keeps the height Blizzard measured, so the tracker ends in empty space
-- where the retail layout would have ended.
local BLOCK_LEFT, BLOCK_GAP, LINE_GAP = 7, 4, 1

local function Compact(block, trackerModule)
	local spacing = trackerModule.lineSpacing or 0
	local moved = RestackLines(block, spacing, LINE_GAP)
	if type(block.height) == "number" then
		block:SetHeight(math.max(block.height - moved * (spacing - LINE_GAP), 1))
	end
	local relativeTo, relativePoint, x, y = FindPoint(block, "TOP")
	if relativeTo and relativePoint == "BOTTOM" and (Near(y, trackerModule.fromBlockOffsetY) or Near(y, -BLOCK_GAP)) then
		block:SetPoint("TOP", relativeTo, "BOTTOM", x, -BLOCK_GAP)
	end
	local leftTo, leftPoint = FindPoint(block, "LEFT")
	if leftTo then
		block:SetPoint("LEFT", leftTo, leftPoint, BLOCK_LEFT, 0)
	end
	compacted[block] = true
end

local function Uncompact(block)
	local trackerModule = block.parentModule
	if not block.used or type(trackerModule) ~= "table" then return end
	local spacing = trackerModule.lineSpacing or 0
	RestackLines(block, LINE_GAP, spacing)
	if type(block.height) == "number" then
		block:SetHeight(block.height)
	end
	local relativeTo, relativePoint, x, y = FindPoint(block, "TOP")
	if relativeTo and relativePoint == "BOTTOM" and Near(y, -BLOCK_GAP) and trackerModule.fromBlockOffsetY then
		block:SetPoint("TOP", relativeTo, "BOTTOM", x, trackerModule.fromBlockOffsetY)
	end
	local leftTo, leftPoint = FindPoint(block, "LEFT")
	local left = block.offsetX or trackerModule.blockOffsetX
	if leftTo and left then
		block:SetPoint("LEFT", leftTo, leftPoint, left, 0)
	end
	if block.poiButton then
		block.poiButton:Show()
	end
end

local function SkinBlock(block, questBlock, trackerModule)
	Hide(block.HeaderGlow)
	if type(block.usedLines) == "table" then
		for objectiveKey, line in pairs(block.usedLines) do
			SkinLine(line, objectiveKey, questBlock)
		end
	end
	if type(block.addedRegions) == "table" then
		for region in pairs(block.addedRegions) do
			if region.template == ITEM_BUTTON_TEMPLATE then
				SkinItemButton(region)
			end
		end
	end
	if questBlock then
		SkinTitle(block)
		-- The quest's POI button: Blizzard shows it on every layout of the
		-- block (GetPOIButton), before the module's EndLayout.
		if block.poiButton then
			block.poiButton:Hide()
		end
		Compact(block, trackerModule)
		if not hookedBlocks[block] then
			hookedBlocks[block] = true
			-- Hovering the title re-colours it (and the open objectives).
			ns.Hook(block, "UpdateHighlight", function(self)
				if enabled then SkinTitle(self) end
			end)
		end
	end
end

local function SkinBlocks(trackerModule)
	local blocks = trackerModule.usedBlocks
	if type(blocks) ~= "table" then return end
	local quests = IsQuestModule(trackerModule)
	for template, byID in pairs(blocks) do
		-- The quest modules' other blocks are the auto quest pop-ups.
		local questBlocks = quests and template == trackerModule.blockTemplate
		for _, block in pairs(byID) do
			SkinBlock(block, questBlocks, trackerModule)
		end
	end
end

local function SkinModule(trackerModule)
	if type(trackerModule) ~= "table" then return end
	SkinHeader(trackerModule.Header, "module")
	if not hookedModules[trackerModule] then
		hookedModules[trackerModule] = true
		-- Runs after every layout of the module: blocks, lines and item
		-- buttons are pooled and set up again each time.
		ns.Hook(trackerModule, "EndLayout", function(self)
			if enabled then SkinBlocks(self) end
		end)
	end
	SkinBlocks(trackerModule)
end

local function SkinAll()
	local tracker = ObjectiveTrackerFrame
	SkinHeader(tracker.Header, "container")
	for _, name in ipairs(MODULE_NAMES) do
		SkinModule(_G[name])
	end
	if type(tracker.modules) == "table" then
		for _, trackerModule in ipairs(tracker.modules) do
			SkinModule(trackerModule)
		end
	end
end

---------------------------------------------------------------------------
-- Putting the modern look back
---------------------------------------------------------------------------

local function RestoreAll()
	for region in pairs(hidden) do
		region:Show()
	end
	wipe(hidden)
	for header, kind in pairs(headers) do
		RestoreMinimizeButton(header, kind)
	end
	local LINE_STATE = ObjectiveTrackerAnimLineState
	for line in pairs(doneLines) do
		ResetLine(line)
		-- The check mark of an objective Blizzard shows as met.
		if line.Icon and line.used and not line.noIcon and LINE_STATE
			and (line.state == LINE_STATE.Completed or line.state == LINE_STATE.Completing) then
			line.Icon:Show()
		end
	end
	wipe(doneLines)
	for block in pairs(brightTitles) do
		ResetColor(block.HeaderText)
	end
	wipe(brightTitles)
	for button in pairs(itemButtons) do
		local normal, pushed = button:GetNormalTexture(), button:GetPushedTexture()
		if normal then ns.SetAtlas(normal, ITEM_FRAME_ATLAS) end
		if pushed then ns.SetAtlas(pushed, ITEM_FRAME_ATLAS) end
	end
	wipe(itemButtons)
	for block in pairs(compacted) do
		Uncompact(block)
	end
	wipe(compacted)
end

---------------------------------------------------------------------------
-- Module entry points
---------------------------------------------------------------------------

local function Setup()
	if hooked then return end
	hooked = true
	ns.Hook(ObjectiveTrackerFrame, "AddModule", function(_, trackerModule)
		if enabled then SkinModule(trackerModule) end
	end)
end

local waiter
local function WhenTrackerLoaded(fn)
	if ObjectiveTrackerFrame then
		fn()
		return
	end
	if not waiter then
		waiter = CreateFrame("Frame")
		waiter:RegisterEvent("ADDON_LOADED")
	end
	waiter:SetScript("OnEvent", function(self, _, name)
		if name == "Blizzard_ObjectiveTracker" and ObjectiveTrackerFrame then
			self:UnregisterEvent("ADDON_LOADED")
			self:SetScript("OnEvent", nil)
			fn()
		end
	end)
end

function module:Enable()
	enabled = true
	WhenTrackerLoaded(function()
		if not enabled then return end
		Setup()
		SkinAll()
	end)
end

function module:Disable()
	enabled = false
	RestoreAll()
end
