--[[
	Classic UI Restoration - Cast Bars

	Restores the classic cast bar look (Interface\CastingBar\UI-CastingBar-*)
	on the player, pet, target, focus and boss cast bars.

	IMPORTANT (12.x): cast timing values on Blizzard's bars are "secret" and may
	only be used by untainted code. Writing *any* Lua field on those bars (for
	example the mixin's classicStyleCastBar flag) taints the values Blizzard
	stores afterwards and breaks its OnUpdate. Therefore this module never
	writes fields on the bars: it only post-hooks Blizzard's layout functions
	and changes textures, sizes and anchors, which are widget state and safe.

	The classic fill colour is derived from the retail atlas Blizzard just
	assigned (standard / channel / uninterruptable / interrupted), so the bar
	type never has to be read.

	This module can be toggled live.
]]

local _, ns = ...
local T = ns.T

local module = ns:RegisterModule({
	key = "castbars",
	name = "Cast Bars",
	tooltip = "Restores the classic cast bar artwork (border, spark and colours) on the player, pet, target, focus and boss cast bars.",
	live = true,
})

local enabled = false
local hookedBars = setmetatable({}, { __mode = "k" })

-- Hidden frame that retail-only FX regions are parked in while classic is on.
local fxParkingLot = CreateFrame("Frame", nil, UIParent)
fxParkingLot:Hide()

local FX_REGIONS = {
	"EnergyGlow", "Flakes01", "Flakes02", "Flakes03", "Shine", "BaseGlow", "WispGlow",
	"Sparkles01", "Sparkles02", "StandardGlow", "CraftGlow", "ChannelShadow",
	"InterruptGlow", "ChargeGlow", "ChargeFlash",
}

local YELLOW = { 1.0, 0.7, 0.0 }
local GREEN  = { 0.0, 1.0, 0.0 }
local GRAY   = { 0.7, 0.7, 0.7 }
local RED    = { 1.0, 0.0, 0.0 }

-- Retail fill atlas -> classic colour.
local ATLAS_COLORS = {
	["ui-castingbar-filling-standard"]         = YELLOW,
	["ui-castingbar-full-standard"]            = GREEN,
	["ui-castingbar-filling-applyingcrafting"] = YELLOW,
	["ui-castingbar-full-applyingcrafting"]    = GREEN,
	["ui-castingbar-filling-channel"]          = GREEN,
	["ui-castingbar-full-channel"]             = GREEN,
	["ui-castingbar-uninterruptable"]          = GRAY,
	["ui-castingbar-interrupted"]              = RED,
}

local function IsLarge(bar)
	return bar == PlayerCastingBarFrame or bar == PetCastingBarFrame
end

---------------------------------------------------------------------------
-- Classic look
---------------------------------------------------------------------------

local function ApplyClassicFill(bar)
	local texture = bar:GetStatusBarTexture()
	local atlas = texture and texture:GetAtlas()
	local color = (type(atlas) == "string" and ATLAS_COLORS[string.lower(atlas)]) or YELLOW
	bar:SetStatusBarTexture(T.STATUS_BAR)
	bar:SetStatusBarColor(color[1], color[2], color[3])
end

local function ApplyClassicSpark(bar)
	if not bar.Spark then return end
	bar.Spark:SetTexture(T.CAST_SPARK)
	bar.Spark:SetSize(32, 32)
	bar.Spark:SetBlendMode("ADD")
end

local function ApplyClassicFlash(bar)
	if not bar.Flash then return end
	if IsLarge(bar) then
		bar.Flash:SetTexture(T.CAST_FLASH)
		bar.Flash:SetSize(256, 64)
		bar.Flash:ClearAllPoints()
		bar.Flash:SetPoint("TOP", bar, "TOP", 0, 28)
	else
		bar.Flash:SetTexture(T.CAST_FLASH_SMALL)
		bar.Flash:SetSize(0, 49)
		bar.Flash:ClearAllPoints()
		bar.Flash:SetPoint("TOPLEFT", bar, "TOPLEFT", -23, 20)
		bar.Flash:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 23, 20)
	end
	bar.Flash:SetBlendMode("ADD")
end

-- Large bars (player/pet): classic geometry for the current SetLook() look.
local function ApplyClassicLook(bar, look)
	if look == "CLASSIC" then
		bar:SetSize(195, 13)
		bar.Border:SetTexture(T.CAST_BORDER)
		bar.Border:SetSize(256, 64)
		bar.Border:ClearAllPoints()
		bar.Border:SetPoint("TOP", bar, "TOP", 0, 28)
		bar.BorderShield:SetSize(256, 64)
		bar.BorderShield:ClearAllPoints()
		bar.BorderShield:SetPoint("TOP", bar, "TOP", 0, 28)
		bar.Text:SetSize(185, 16)
		bar.Text:ClearAllPoints()
		bar.Text:SetPoint("TOP", bar, "TOP", 0, 5)
		bar.Text:SetFontObject("GameFontHighlight")
	elseif look == "UNITFRAME" then
		bar:SetSize(150, 10)
		bar.Border:SetTexture(T.CAST_BORDER_SMALL)
		bar.Border:SetSize(0, 56)
		bar.Border:ClearAllPoints()
		bar.Border:SetPoint("TOPLEFT", bar, "TOPLEFT", -23, 23)
		bar.Border:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 23, 23)
		bar.BorderShield:SetSize(0, 56)
		bar.BorderShield:ClearAllPoints()
		bar.BorderShield:SetPoint("TOPLEFT", bar, "TOPLEFT", -28, 23)
		bar.BorderShield:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 18, 23)
		bar.Text:SetSize(0, 16)
		bar.Text:ClearAllPoints()
		bar.Text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 4)
		bar.Text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 4)
		bar.Text:SetFontObject("SystemFont_Shadow_Small")
	else
		return
	end
	if bar.TextBorder then bar.TextBorder:Hide() end
	if bar.DropShadow then bar.DropShadow:Hide() end
end

-- Small bars (target/focus/boss) never go through SetLook(); static layout.
local function ApplyClassicSmallLayout(bar)
	bar.Border:SetTexture(T.CAST_BORDER_SMALL)
	bar.Border:SetSize(0, 49)
	bar.Border:ClearAllPoints()
	bar.Border:SetPoint("TOPLEFT", bar, "TOPLEFT", -23, 20)
	bar.Border:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 23, 20)

	bar.BorderShield:SetSize(0, 49)
	bar.BorderShield:ClearAllPoints()
	bar.BorderShield:SetPoint("TOPLEFT", bar, "TOPLEFT", -28, 20)
	bar.BorderShield:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 18, 20)

	bar.Text:SetSize(0, 16)
	bar.Text:ClearAllPoints()
	bar.Text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 4)
	bar.Text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 4)

	bar.Icon:SetSize(16, 16)
	bar.Icon:ClearAllPoints()
	bar.Icon:SetPoint("RIGHT", bar, "LEFT", -5, 0)

	if bar.TextBorder then bar.TextBorder:Hide() end
end

local function ApplyClassic(bar)
	if bar.Background then
		bar.Background:SetColorTexture(0, 0, 0, 0.5)
	end
	if bar.BorderShield then
		bar.BorderShield:SetTexture(T.CAST_SHIELD_SMALL)
	end
	for _, key in ipairs(FX_REGIONS) do
		local region = bar[key]
		if region and region.SetParent then
			region:SetParent(fxParkingLot)
		end
	end
	ApplyClassicSpark(bar)
	ApplyClassicFlash(bar)
	ApplyClassicFill(bar)
	if IsLarge(bar) then
		ApplyClassicLook(bar, bar.look) -- reading Blizzard's field is fine
	else
		ApplyClassicSmallLayout(bar)
	end
end

---------------------------------------------------------------------------
-- Retail look (restored when the module is disabled)
---------------------------------------------------------------------------

local function RestoreRetail(bar)
	if bar.Background then
		bar.Background:SetAtlas("ui-castingbar-background")
	end
	if bar.BorderShield then
		bar.BorderShield:SetAtlas("ui-castingbar-shield")
	end
	for _, key in ipairs(FX_REGIONS) do
		local region = bar[key]
		if region and region.SetParent then
			region:SetParent(bar)
		end
	end
	if bar.Spark then
		bar.Spark:SetAtlas("ui-castingbar-pip")
		bar.Spark:SetBlendMode("BLEND")
		bar.Spark:SetSize(IsLarge(bar) and 8 or 6, IsLarge(bar) and 20 or 16)
	end
	if bar.Flash then
		bar.Flash:SetAtlas("ui-castingbar-full-glow-standard")
		bar.Flash:ClearAllPoints()
		bar.Flash:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
		bar.Flash:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
		bar.Flash:SetBlendMode("ADD")
	end
	-- Neutral fill; Blizzard re-applies the proper atlas on the next cast.
	bar:SetStatusBarTexture("ui-castingbar-filling-standard")
	bar:SetStatusBarColor(1, 1, 1)

	if IsLarge(bar) then
		bar.Border:SetAtlas("ui-castingbar-frame")
		bar.Border:ClearAllPoints()
		bar.Border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
		bar.Border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
		if bar.look == "CLASSIC" then
			bar:SetSize(208, 11)
			bar.BorderShield:SetSize(256, 64)
			bar.BorderShield:ClearAllPoints()
			bar.BorderShield:SetPoint("TOP", bar, "TOP", 0, 28)
			bar.Text:SetSize(185, 16)
			bar.Text:ClearAllPoints()
			bar.Text:SetPoint("TOP", bar, "TOP", 0, -10)
			bar.Text:SetFontObject("GameFontHighlightSmall")
			if bar.TextBorder then bar.TextBorder:Show() end
		elseif bar.look == "UNITFRAME" then
			bar:SetSize(150, 10)
			bar.BorderShield:SetSize(0, 49)
			bar.BorderShield:ClearAllPoints()
			bar.BorderShield:SetPoint("TOPLEFT", bar, "TOPLEFT", -28, 20)
			bar.BorderShield:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 18, 20)
			bar.Text:SetSize(0, 16)
			bar.Text:ClearAllPoints()
			bar.Text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 3)
			bar.Text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 3)
			bar.Text:SetFontObject("SystemFont_Shadow_Small")
			if bar.TextBorder then bar.TextBorder:Hide() end
		end
	else
		bar.Border:SetAtlas("ui-castingbar-frame")
		bar.Border:ClearAllPoints()
		bar.Border:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 2)
		bar.Border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -2)
		bar.BorderShield:SetSize(29, 33)
		bar.BorderShield:ClearAllPoints()
		bar.BorderShield:SetPoint("TOPLEFT", bar, "TOPLEFT", -27, 4)
		bar.Text:SetSize(0, 16)
		bar.Text:ClearAllPoints()
		bar.Text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -8)
		bar.Text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -8)
		bar.Icon:SetSize(20, 20)
		bar.Icon:ClearAllPoints()
		bar.Icon:SetPoint("RIGHT", bar, "LEFT", -2, -5)
		if bar.TextBorder then bar.TextBorder:Show() end
	end
end

---------------------------------------------------------------------------
-- Bars and hooks
---------------------------------------------------------------------------

local function GetBars()
	local bars = {}
	if PlayerCastingBarFrame then table.insert(bars, PlayerCastingBarFrame) end
	if PetCastingBarFrame then table.insert(bars, PetCastingBarFrame) end
	if TargetFrame and TargetFrame.spellbar then table.insert(bars, TargetFrame.spellbar) end
	if FocusFrame and FocusFrame.spellbar then table.insert(bars, FocusFrame.spellbar) end
	if BossTargetFrameContainer and BossTargetFrameContainer.BossTargetFrames then
		for _, frame in pairs(BossTargetFrameContainer.BossTargetFrames) do
			if frame.spellbar then table.insert(bars, frame.spellbar) end
		end
	end
	return bars
end

-- Hooks are installed once per bar and only act while the module is enabled.
local function InstallHooks(bar)
	if hookedBars[bar] then return end
	hookedBars[bar] = true

	-- Blizzard picks a retail fill atlas here; swap it for the classic colour.
	ns.Hook(bar, "UpdateBarFillTexture", function(self)
		if enabled then ApplyClassicFill(self) end
	end)
	-- Blizzard re-sets the spark atlas on every cast start.
	ns.Hook(bar, "ShowSpark", function(self)
		if enabled then ApplyClassicSpark(self) end
	end)
	-- The finish flash atlas is re-set when a cast completes.
	ns.Hook(bar, "HandleCastStop", function(self)
		if enabled then ApplyClassicFlash(self) end
	end)
	ns.Hook(bar, "FinishSpell", function(self)
		if enabled then ApplyClassicFlash(self) end
	end)
	if IsLarge(bar) then
		ns.Hook(bar, "SetLook", function(self, look)
			if enabled then ApplyClassicLook(self, look) end
		end)
	end
end

---------------------------------------------------------------------------
-- Module entry points
---------------------------------------------------------------------------

function module:Enable()
	enabled = true
	for _, bar in ipairs(GetBars()) do
		InstallHooks(bar)
		xpcall(ApplyClassic, geterrorhandler(), bar)
	end
end

function module:Disable()
	enabled = false
	for _, bar in ipairs(GetBars()) do
		xpcall(RestoreRetail, geterrorhandler(), bar)
	end
end
