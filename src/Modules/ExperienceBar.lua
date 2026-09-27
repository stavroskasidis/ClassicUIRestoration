--[[
	Forevermore Classic UI - XP & Reputation Bars

	Puts the vanilla look back on the experience and reputation bars (the
	bars of StatusTrackingBarManager's two containers, both Edit Mode
	systems):

	  * The frame: vanilla's segmented XP bar frame, the rows between the
	    action bar strip's pieces in UI-MainMenuBar-Dwarf (twenty segments
	    over its four pieces), over a half-transparent black background.
	  * Experience: the flat UI-StatusBar fill in vanilla's purple (blue
	    while rested), the rested stretch past it in the same colour at 15%
	    and the UI-ExhaustionTick diamond where rest runs out.
	  * Reputation: the same fill in the standing's vanilla colour (blue for
	    renown factions, like retail). While the XP bar is shown too, it is
	    framed by the thinner UI-ReputationWatchBar, as vanilla drew it over
	    the XP bar; without one (at max level) it takes the XP bar's frame,
	    as vanilla's did.
	  * The retail-only honor, artifact, azerite and house favor bars keep
	    Blizzard's fill inside the classic frame.

	The containers and bars keep Blizzard's size and place (Edit Mode's
	position and Size settings, the stacking above the action bars): the
	frame is fitted to each bar's width and the container's height (17px
	for the XP frame's twelve file rows), centred on the bar like
	Blizzard's own frame.

	Blizzard's fill is a GradualAnimatedStatusBar that re-applies its
	atlases on every rest / standing change and plays flipbook flares, so
	for XP and reputation the whole StatusBar is faded and the classic fill
	is drawn on a mirror StatusBar following its min/max/value (the gradual
	gain included). The rested fill and tick stay Blizzard's (Blizzard places
	them on every XP change), re-textured. The colours follow the bars'
	UpdateStatusBarTextures / UpdateBarTextures, which Blizzard calls on
	every rest / standing change.

	The status bars hold no secure widgets and no Lua field is written on
	Blizzard's frames; everything touched is recorded and put back on
	disable, so the option switches live.
]]

local _, ns = ...
local T = ns.T

T.REPUTATION_WATCH_BAR = "Interface\\PaperDollInfoFrame\\UI-ReputationWatchBar"
T.EXHAUSTION_TICK      = "Interface\\MainMenuBar\\UI-ExhaustionTickNormal"
T.EXHAUSTION_HIGHLIGHT = "Interface\\MainMenuBar\\UI-ExhaustionTickHighlight"

local module = ns:RegisterModule({
	key = "xpbar",
	name = "XP & Reputation Bars",
	tooltip = "Restores the vanilla experience and reputation bars: the segmented classic frame, the flat purple XP fill (blue while rested) with the diamond rest marker, and the reputation bar in its standing's colour, drawn thinner while the XP bar is shown like vanilla's.",
	live = true,
})

-- The two frames, as four pieces read left to right, each `height` file
-- rows from the given top row; the fill shows through the `fill` rows in
-- their middle.
--   xp: UI-MainMenuBar-Dwarf (256x256). A 2px border, the window (6px with
--       a 1px shadow above and below) and a 2px border, which is the top of
--       the action bar strip. The first piece starts with a 6px end cap and
--       the last ends with one.
--   watch: UI-ReputationWatchBar (256x64), four 12-row strips with the
--       frame in rows 2-10: 2px borders around a 5px window.
local STYLES = {
	xp    = { file = T.MAINMENUBAR_STRIP,    fileHeight = 256, rows = { 203, 139, 75, 11 }, height = 12, fill = 8 },
	watch = { file = T.REPUTATION_WATCH_BAR, fileHeight = 64,  rows = { 2, 14, 26, 38 },    height = 9,  fill = 5 },
}

local XP_COLOR     = { 0.58, 0, 0.55 }
local RESTED_COLOR = { 0, 0.39, 0.88 }
local RESTED_FILL_ALPHA = 0.15
-- 1.12's FACTION_BAR_COLORS, Hated to Exalted.
local STANDING_COLORS = {
	{ 0.8, 0.3, 0.22 }, { 0.8, 0.3, 0.22 }, { 0.75, 0.27, 0 }, { 0.9, 0.7, 0 },
	{ 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 },
}
local FRIENDLY = 5
-- The 32x32 tick file, drawn at the frame's scale (its diamond reaches
-- past the bar, as vanilla's did).
local TICK_SIZE = 32

-- For the option's picture (Previews.lua).
ns.StatusBarArt = {
	STYLES = STYLES, XP_COLOR = XP_COLOR, RESTED_COLOR = RESTED_COLOR,
	RESTED_FILL_ALPHA = RESTED_FILL_ALPHA, STANDING_COLORS = STANDING_COLORS, TICK_SIZE = TICK_SIZE,
}

local enabled = false
local hasWatchArt, hasTickArt = false, false
local skins = {} -- Blizzard bar -> skin
local hookedContainers = {}
local retail = setmetatable({}, { __mode = "k" }) -- region -> its retail look

---------------------------------------------------------------------------
-- Blizzard's regions, recorded before the first change
---------------------------------------------------------------------------

local function Remember(region)
	if retail[region] then return end
	local state = {
		atlas = region:GetAtlas(),
		color = { region:GetVertexColor() },
		width = region:GetWidth(),
		height = region:GetHeight(),
		points = {},
	}
	for i = 1, region:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = region:GetPoint(i)
		state.points[i] = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
	end
	retail[region] = state
end

local function Restore(region)
	local state = region and retail[region]
	if not state then return end
	if state.atlas then region:SetAtlas(state.atlas) end
	region:SetVertexColor(unpack(state.color))
	region:ClearAllPoints()
	if #state.points == 0 then
		region:SetAllPoints(region:GetParent()) -- a region without anchors fills its frame
	else
		for _, p in ipairs(state.points) do
			region:SetPoint(p.point, p.relativeTo, p.relativePoint, p.x, p.y)
		end
	end
	region:SetSize(state.width, state.height)
end

---------------------------------------------------------------------------
-- The classic frame and fill of one bar
---------------------------------------------------------------------------

local function KindOf(bar)
	if not bar.StatusBar then return "other" end
	if bar.isExpBar then return "xp" end
	local bars = StatusTrackingBarInfo and StatusTrackingBarInfo.BarsEnum
	if bars and bars.Reputation and bar.barIndex == bars.Reputation then return "rep" end
	return "other"
end

-- The frame spans the bar and is centred on it; its four pieces share its
-- width (Edit Mode's Size setting changes it).
local function CreateArt(skin, level)
	local bar = skin.bar
	local art = CreateFrame("Frame", nil, bar)
	art:SetFrameLevel(level)
	art:SetPoint("LEFT", bar, "LEFT", 0, 0)
	art:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
	local pieces = {}
	for i = 1, 4 do
		local piece = art:CreateTexture(nil, "OVERLAY")
		local previous = pieces[i - 1]
		if previous then
			piece:SetPoint("TOPLEFT", previous, "TOPRIGHT", 0, 0)
			piece:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", 0, 0)
		else
			piece:SetPoint("TOPLEFT", art, "TOPLEFT", 0, 0)
			piece:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", 0, 0)
		end
		pieces[i] = piece
	end
	local function SizePieces(width)
		for _, piece in ipairs(pieces) do
			piece:SetWidth(width / 4)
		end
	end
	art:SetScript("OnSizeChanged", function(_, width) SizePieces(width) end)
	SizePieces(bar:GetWidth())
	skin.art, skin.pieces = art, pieces
end

-- The classic fill, over the black background. The background is on
-- Blizzard's bar, under its rested fill; the mirror's fill covers that up to
-- the current value.
local function CreateMirror(skin, level)
	local bar, source = skin.bar, skin.bar.StatusBar
	local mirror = CreateFrame("StatusBar", nil, bar)
	mirror:SetFrameLevel(level)
	mirror:SetPoint("LEFT", bar, "LEFT", 0, 0)
	mirror:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
	mirror:SetStatusBarTexture(T.STATUS_BAR)
	mirror:SetMinMaxValues(source:GetMinMaxValues())
	mirror:SetValue(source:GetValue())
	source:HookScript("OnMinMaxChanged", function(_, minValue, maxValue)
		mirror:SetMinMaxValues(minValue, maxValue)
	end)
	source:HookScript("OnValueChanged", function(_, value)
		mirror:SetValue(value)
	end)
	local background = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	background:SetColorTexture(unpack(ns.C.BACKDROP))
	background:SetAllPoints(mirror)
	skin.mirror, skin.background = mirror, background
end

local function SetStyle(skin, name)
	if skin.style == name then return end
	skin.style = name
	local style = STYLES[name]
	for i, piece in ipairs(skin.pieces) do
		local top = style.rows[i]
		ns.SetTexture(piece, style.file, 0, 1, top / style.fileHeight, (top + style.height) / style.fileHeight)
	end
	skin.art:SetHeight(style.height * skin.scale)
	if skin.mirror then
		skin.mirror:SetHeight(style.fill * skin.scale)
	end
end

local function TickTextures(bar)
	local tick = bar.ExhaustionTick
	if not tick then return nil end
	return tick, tick.Normal or tick:GetNormalTexture(), tick.Highlight or tick:GetHighlightTexture()
end

local function ApplyRestColor(skin, rested)
	local r, g, b = unpack(rested and RESTED_COLOR or XP_COLOR)
	skin.mirror:SetStatusBarColor(r, g, b)
	local fill = skin.bar.ExhaustionLevelFillBar
	if fill then
		fill:SetVertexColor(r, g, b, RESTED_FILL_ALPHA)
	end
	local _, _, highlight = TickTextures(skin.bar)
	if highlight and hasTickArt then
		highlight:SetVertexColor(r, g, b)
	end
end

local function ApplyStandingColor(skin, standing, renown)
	local color = renown and RESTED_COLOR or STANDING_COLORS[standing] or STANDING_COLORS[FRIENDLY]
	skin.mirror:SetStatusBarColor(color[1], color[2], color[3])
end

-- The watched faction's standing as Blizzard's reputation bar colours it
-- (friendships as Friendly, renown factions blue), for the colour before
-- Blizzard next updates the bar.
local function WatchedStanding()
	local data = C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
	if not data or not data.factionID or data.factionID == 0 then return nil end
	if C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(data.factionID) then
		return nil, true
	end
	local friendship = C_GossipInfo and C_GossipInfo.GetFriendshipReputation and C_GossipInfo.GetFriendshipReputation(data.factionID)
	if friendship and (friendship.friendshipFactionID or 0) > 0 then
		return FRIENDLY
	end
	return data.reaction
end

local function SkinTickTexture(texture, file, tick, size, offset)
	if not texture then return end
	Remember(texture)
	ns.SetTexture(texture, file)
	texture:ClearAllPoints()
	texture:SetSize(size, size)
	texture:SetPoint("CENTER", tick, "CENTER", 0, -offset)
end

-- Blizzard's rested fill (sized on every XP change) is fitted to the
-- classic fill's height; its tick keeps Blizzard's position and gets the
-- vanilla diamond. Blizzard centres the tick `offset` above the bar's
-- middle (retail 2px, Forever 0), the diamond sits on the middle.
local function SkinRested(skin)
	local bar = skin.bar
	local fill = bar.ExhaustionLevelFillBar
	if fill then
		Remember(fill)
		ns.SetTexture(fill, T.STATUS_BAR)
		fill:ClearAllPoints()
		fill:SetPoint("TOPLEFT", skin.mirror, "TOPLEFT", 0, 0)
		fill:SetPoint("BOTTOMLEFT", skin.mirror, "BOTTOMLEFT", 0, 0)
	end
	local tick, normal, highlight = TickTextures(bar)
	if tick and hasTickArt then
		local offset = tonumber(tick.yOffset) or tonumber(EXHAUSTION_TICK_OFFSET_Y) or 0
		local size = TICK_SIZE * skin.scale
		SkinTickTexture(normal, T.EXHAUSTION_TICK, tick, size, offset)
		SkinTickTexture(highlight, T.EXHAUSTION_HIGHLIGHT, tick, size, offset)
	end
end

local function HookBar(skin)
	if skin.kind == "xp" then
		ns.Hook(skin.bar, "UpdateStatusBarTextures", function(_, rested)
			if enabled then ApplyRestColor(skin, rested) end
		end)
	elseif skin.kind == "rep" then
		ns.Hook(skin.bar, "UpdateBarTextures", function(_, standing, renown)
			if enabled then ApplyStandingColor(skin, standing, renown) end
		end)
	end
end

local function CreateSkin(container, bar)
	local height = container:GetHeight()
	local skin = {
		bar = bar,
		kind = KindOf(bar),
		scale = (height and height > 0 and height or 17) / STYLES.xp.height,
	}
	local level = (bar.StatusBar or bar):GetFrameLevel()
	if skin.kind ~= "other" then
		CreateMirror(skin, level + 1)
	end
	CreateArt(skin, level + 2)
	HookBar(skin)
	skins[bar] = skin
	return skin
end

local function ApplySkin(skin)
	skin.style = nil
	SetStyle(skin, "xp")
	skin.art:Show()
	if skin.mirror then
		skin.mirror:Show()
		skin.background:Show()
		skin.bar.StatusBar:SetAlpha(0)
	end
	if skin.kind == "xp" then
		SkinRested(skin)
		ApplyRestColor(skin, GetRestState() == 1)
	elseif skin.kind == "rep" then
		ApplyStandingColor(skin, WatchedStanding())
	end
end

local function RemoveSkin(skin)
	skin.art:Hide()
	if skin.mirror then
		skin.mirror:Hide()
		skin.background:Hide()
		skin.bar.StatusBar:SetAlpha(1)
	end
	if skin.kind == "xp" then
		Restore(skin.bar.ExhaustionLevelFillBar)
		local _, normal, highlight = TickTextures(skin.bar)
		Restore(normal)
		Restore(highlight)
	end
end

---------------------------------------------------------------------------
-- Containers
---------------------------------------------------------------------------

-- The retail frame atlas and Forever's segment dividers (pooled frames,
-- re-acquired in UpdateDividers; alpha sticks to them) give way to the
-- classic frame.
local function UpdateContainer(container)
	if container.BarFrameTexture then
		container.BarFrameTexture:SetAlpha(enabled and 0 or 1)
	end
	local pool = container.HorizontalDividersPool
	if pool then
		for divider in pool:EnumerateActive() do
			divider:SetAlpha(enabled and 0 or 1)
		end
	end
end

local function XPBarShown()
	for _, container in ipairs(StatusTrackingBarManager.barContainers) do
		local bar = container:IsShown() and container.GetShownBar and container:GetShownBar()
		if bar and bar.isExpBar then
			return true
		end
	end
	return false
end

-- Vanilla drew the reputation bar thinner above the XP bar, and with the XP
-- bar's frame in its place once the XP bar was gone.
local function RefreshStyles()
	if not enabled then return end
	local thin = hasWatchArt and XPBarShown()
	for _, skin in pairs(skins) do
		if skin.kind == "rep" then
			SetStyle(skin, thin and "watch" or "xp")
		end
	end
end

local function HookContainer(container)
	hookedContainers[container] = true
	ns.Hook(container, "UpdateDividers", UpdateContainer)
	-- A bar is swapped in (ApplyPendingBarToShow) or the container shown /
	-- hidden (UpdateShownState) whenever the tracked bars change.
	ns.Hook(container, "ApplyPendingBarToShow", RefreshStyles)
	ns.Hook(container, "UpdateShownState", RefreshStyles)
end

---------------------------------------------------------------------------
-- Module entry points
---------------------------------------------------------------------------

function module:Enable()
	local manager = StatusTrackingBarManager
	if not manager or type(manager.barContainers) ~= "table" then return end
	if not ns.HasTexture(T.MAINMENUBAR_STRIP) then
		ns.Print("This client does not ship the vanilla XP bar art; the modern XP and reputation bars are kept.")
		return
	end
	hasWatchArt = ns.HasTexture(T.REPUTATION_WATCH_BAR)
	hasTickArt = ns.HasTexture(T.EXHAUSTION_TICK) and ns.HasTexture(T.EXHAUSTION_HIGHLIGHT)
	enabled = true
	for _, container in ipairs(manager.barContainers) do
		if not hookedContainers[container] then
			HookContainer(container)
		end
		UpdateContainer(container)
		for _, bar in pairs(container.bars or {}) do
			ApplySkin(skins[bar] or CreateSkin(container, bar))
		end
	end
	RefreshStyles()
end

function module:Disable()
	enabled = false
	for _, skin in pairs(skins) do
		RemoveSkin(skin)
	end
	for container in pairs(hookedContainers) do
		UpdateContainer(container)
	end
end
