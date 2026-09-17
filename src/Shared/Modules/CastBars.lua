--[[
	Classic UI Restoration - Cast Bars

	Restores the classic cast bar look (Interface\CastingBar\UI-CastingBar-*)
	on the player, pet, target, focus and boss cast bars.

	IMPORTANT (12.x): cast timing values on Blizzard's bars are "secret" and may
	only be used by untainted code. Two things break that and must be avoided:
	  * Writing *any* Lua field on those bars (for example the mixin's
	    classicStyleCastBar flag) taints the values Blizzard stores afterwards
	    and breaks its OnUpdate.
	  * hooksecurefunc on the bar's cast methods (UpdateBarFillTexture,
	    ShowSpark, HandleCastStop, FinishSpell). Once such a wrapper sits on a
	    bar that carries secret cast data, every call Blizzard makes into it
	    fails with "string conversion on a secret string value (execution
	    tainted)", even when the hook body does nothing.
	  * HookScript on the bars: their script handlers are restricted, an
	    addon-installed OnShow/OnUpdate handler simply never runs.
	This module therefore never writes fields on the bars and never hooks
	them. Blizzard re-applies its retail atlases at cast start, stop,
	interrupt and finish; the module's own OnUpdate polls the visible bars
	and, whenever it finds a retail atlas on the fill, spark or flash, swaps
	the classic art back in before the frame is drawn. Everything it touches
	is widget state.

	The classic fill colour is derived from the retail atlas Blizzard just
	assigned (standard / channel / uninterruptable / interrupted), so the bar
	type never has to be read. For casts whose data is secret the atlas name
	is secret too; those fall back to the standard yellow.

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

-- Whether a region currently carries an atlas (i.e. retail art Blizzard just
-- applied), and its name when addon code is allowed to read it. The name is
-- a secret value for secret casts; it must not be compared or formatted then.
local function GetAtlasName(region)
	local atlas = region and region:GetAtlas()
	if issecretvalue and issecretvalue(atlas) then
		return true, nil
	end
	if type(atlas) == "string" then
		return true, atlas
	end
	return false, nil
end

local function ApplyClassicFill(bar)
	local _, atlas = GetAtlasName(bar:GetStatusBarTexture())
	local color = (atlas and ATLAS_COLORS[string.lower(atlas)]) or YELLOW
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

-- Blizzard puts retail atlases back on the fill (cast start/stop/interrupt/
-- finish), the spark (cast start) and the flash (finish). A region that
-- carries an atlas is therefore one Blizzard has just touched; put the classic
-- art back. Polled from the module's own frame every update while the bar is
-- shown (see the header for why the bar itself cannot be hooked); the checks
-- are a handful of GetAtlas calls and a no-op almost every frame.
local function RepairClassicArt(bar)
	if GetAtlasName(bar:GetStatusBarTexture()) then
		ApplyClassicFill(bar)
	end
	if GetAtlasName(bar.Spark) then
		ApplyClassicSpark(bar)
	end
	if GetAtlasName(bar.Flash) then
		ApplyClassicFlash(bar)
	end
end

-- Shared with the Nameplates module, whose cast bars have the same problem.
ns.CastBarArt = {
	HasAtlas = GetAtlasName,
	ApplyFill = ApplyClassicFill,
	ApplySpark = ApplyClassicSpark,
}

local watchedBars = {}
local updater = CreateFrame("Frame")
updater:Hide()
updater:SetScript("OnUpdate", function()
	for _, bar in ipairs(watchedBars) do
		if bar:IsShown() then
			RepairClassicArt(bar)
		end
	end
end)

-- Installed once per bar and only acting while the module is enabled. See the
-- header: the bar's cast methods and scripts must not be hooked.
local function InstallHooks(bar)
	if hookedBars[bar] then return end
	hookedBars[bar] = true
	table.insert(watchedBars, bar)

	if IsLarge(bar) then
		-- Edit Mode / settings change the player bar's look; no secrets involved.
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
	updater:Show()
end

function module:Disable()
	enabled = false
	updater:Hide()
	for _, bar in ipairs(GetBars()) do
		xpcall(RestoreRetail, geterrorhandler(), bar)
	end
end
