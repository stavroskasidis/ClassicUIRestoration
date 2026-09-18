--[[
	Classic UI Restoration - Mirror Timers (breath, fatigue, feign death)

	Restores the classic look of the mirror timer bars: the 195x13 bar on the
	black backdrop with the label drawn on the bar, framed by the large
	Interface\CastingBar\UI-CastingBar-Border art, and the classic colours per
	timer (blue breath, yellow fatigue, orange death / feign death) on the
	UI-StatusBar fill.

	Retail (Blizzard_MirrorTimer, 10.0+) draws each timer as a 206x32 frame
	inside MirrorTimerContainer (a VerticalLayoutFrame and Edit Mode system):
	the cast bar atlases for the fill, frame and background, the label in a
	text box under the bar. The container is left alone (Edit Mode's position
	and Size settings keep working); each timer frame is re-skinned in place
	and shrunk to the classic 26px so stacked timers sit as close as they did.

	Blizzard puts a retail fill atlas back on the bar every time a timer is
	(re)started (MirrorTimerMixin:Setup); that method is hooked to re-apply
	the classic fill and colour. Only widget state is touched (no Lua fields
	are written on Blizzard's frames), so the module can be toggled live.
]]

local _, ns = ...
local T = ns.T

local module = ns:RegisterModule({
	key = "mirrortimers",
	name = "Breath & Fatigue Bars",
	tooltip = "Restores the classic look and colours of the breath, fatigue and feign death timer bars.",
	live = true,
})

-- Classic MirrorTimerColors.
local TIMER_COLORS = {
	EXHAUSTION = { 1.00, 0.90, 0.00 },
	BREATH     = { 0.00, 0.50, 1.00 },
	DEATH      = { 1.00, 0.70, 0.00 },
	FEIGNDEATH = { 1.00, 0.70, 0.00 },
}
local DEFAULT_COLOR = TIMER_COLORS.DEATH

local RETAIL_WIDTH, RETAIL_HEIGHT = 206, 32
local CLASSIC_HEIGHT = 26

local enabled = false
local hooked = setmetatable({}, { __mode = "k" })      -- timer frame -> true
local backgrounds = setmetatable({}, { __mode = "k" }) -- timer frame -> its background texture

local function GetTimers()
	local container = MirrorTimerContainer
	return container, container and container.mirrorTimers or {}
end

-- The unnamed background texture of a timer frame (retail: the
-- ui-castingbar-background atlas anchored 1px around the bar). It has no
-- key, so it is the BACKGROUND-layer texture that is not the text box.
local function GetBackground(frame)
	if backgrounds[frame] then return backgrounds[frame] end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:GetObjectType() == "Texture" and region ~= frame.TextBorder and region:GetDrawLayer() == "BACKGROUND" then
			backgrounds[frame] = region
			return region
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Classic look
---------------------------------------------------------------------------

-- Classic fill and colour for the timer type Blizzard just set up. The type
-- is a plain string ("BREATH", ...); should it ever be secret it cannot be
-- used as a table key, so the default colour is used then.
local function ApplyClassicFill(frame, timer)
	local bar = frame.StatusBar
	if not bar then return end
	if issecretvalue and issecretvalue(timer) then
		timer = nil
	end
	local color = (timer and TIMER_COLORS[timer]) or DEFAULT_COLOR
	bar:SetStatusBarTexture(T.STATUS_BAR)
	bar:SetStatusBarColor(color[1], color[2], color[3])
end

local function ApplyClassic(frame)
	local bar = frame.StatusBar
	if not bar then return end

	frame:SetSize(RETAIL_WIDTH, CLASSIC_HEIGHT)

	local background = GetBackground(frame)
	if background then
		background:SetColorTexture(0, 0, 0, 0.5)
		background:ClearAllPoints()
		background:SetAllPoints(bar)
	end
	if frame.TextBorder then
		frame.TextBorder:Hide()
	end
	if frame.Text then
		frame.Text:SetFontObject("GameFontHighlight")
		frame.Text:SetSize(195, 16)
		frame.Text:ClearAllPoints()
		frame.Text:SetPoint("TOP", frame, "TOP", 0, 0)
	end
	if frame.Border then
		frame.Border:SetTexture(T.CAST_BORDER)
		frame.Border:SetSize(256, 64)
		frame.Border:ClearAllPoints()
		frame.Border:SetPoint("TOP", frame, "TOP", 0, 25)
	end
	ApplyClassicFill(frame, frame.timer) -- reading Blizzard's field is fine
end

---------------------------------------------------------------------------
-- Retail look (restored when the module is disabled); see MirrorTimer.xml.
---------------------------------------------------------------------------

local function RestoreRetail(frame)
	local bar = frame.StatusBar
	if not bar then return end

	frame:SetSize(RETAIL_WIDTH, RETAIL_HEIGHT)

	local background = GetBackground(frame)
	if background then
		background:SetAtlas("ui-castingbar-background")
		background:ClearAllPoints()
		background:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
		background:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
	end
	if frame.TextBorder then
		frame.TextBorder:Show()
	end
	if frame.Text then
		frame.Text:SetFontObject("GameFontHighlightSmall")
		frame.Text:ClearAllPoints()
		frame.Text:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
		frame.Text:SetPoint("BOTTOMRIGHT", frame.TextBorder or bar, "BOTTOMRIGHT", 0, 2)
	end
	if frame.Border then
		frame.Border:SetAtlas("ui-castingbar-frame")
		frame.Border:ClearAllPoints()
		frame.Border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
		frame.Border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
	end
	-- Blizzard's atlas per timer type (MirrorTimerAtlas in MirrorTimer.lua);
	-- the next Setup re-applies it anyway.
	local atlas = frame.timer and MirrorTimerAtlas and MirrorTimerAtlas[frame.timer]
	bar:SetStatusBarTexture(atlas or "ui-castingbar-filling-standard")
	bar:SetStatusBarColor(1, 1, 1)
end

---------------------------------------------------------------------------
-- Module entry points
---------------------------------------------------------------------------

local function InstallHook(frame)
	if hooked[frame] then return end
	hooked[frame] = true
	-- Runs after Blizzard put its fill atlas back for a (re)started timer.
	ns.Hook(frame, "Setup", function(self, timer)
		if enabled then ApplyClassicFill(self, timer) end
	end)
end

function module:Enable()
	local container, timers = GetTimers()
	if not container then return end
	enabled = true
	for _, frame in ipairs(timers) do
		InstallHook(frame)
		xpcall(ApplyClassic, geterrorhandler(), frame)
	end
	if container.Layout then container:Layout() end -- the frames changed height
end

function module:Disable()
	local container, timers = GetTimers()
	enabled = false
	if not container then return end
	for _, frame in ipairs(timers) do
		xpcall(RestoreRetail, geterrorhandler(), frame)
	end
	if container.Layout then container:Layout() end
end
