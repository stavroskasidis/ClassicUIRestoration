--[[
	Classic UI Restoration - Nameplates

	The 12.x client ships a built-in "Classic" nameplate style (the pre-
	Dragonflight look: Interface\Tooltips\Nameplate-Border with the flat
	UI-TargetingFrame-BarFill health bar, level text and the small classic cast
	bar). It is selected through the "nameplateStyle" CVar; this module drives
	that CVar and remembers the style that was active before, so the retail look
	can be restored when the option is turned off.

	The built-in style is not exposed in Blizzard's own options and its layout
	code is not fully reliable (the border can end up mis-sized), so after
	Blizzard lays a plate out (NamePlateUnitFrameMixin:UpdateAnchors) the
	classic geometry is re-applied here with plain SetSize/SetPoint calls.
	Only widget state is touched - no Lua fields are written on the plates,
	which matters because nameplate values are "secret" in 12.x.

	This module can be toggled live.
]]

local _, ns = ...

local module = ns:RegisterModule({
	key = "nameplates",
	name = "Nameplates",
	tooltip = "Uses the classic nameplate style (classic border, flat health bar, level text and the small classic cast bar). Turning this off restores the nameplate style that was active before.",
	live = true,
})

local CVAR = "nameplateStyle"
local BORDER = "Interface\\Tooltips\\Nameplate-Border"
local CAST_BORDER = "Interface\\Tooltips\\Nameplate-Border-Castbar"
local BAR_FILL = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"

-- The retail client's Nameplate-Border.blp is 256x32 with the classic border
-- art (136x17 px) in the lower-left corner; the rest is empty. Blizzard's own
-- classic style still samples the whole width (0..1), which squashes the
-- border into the left half of the bar and leaves the level bubble in the
-- middle, so the art is cropped to its real extent here.
local BORDER_COORDS = { 0, 136 / 256, 15 / 32, 1 }
local BORDER_ART_WIDTH = 136 -- px of the 128-unit classic border
-- Nameplate-Border-Castbar.blp is still the regular 128x32 file (art spans the
-- full width in the lower half), so it only needs the vertical crop.
local CAST_BORDER_COORDS = { 0, 1, 15 / 32, 1 }

local enabled = false

local function GetClassicStyle()
	return Enum.NamePlateStyle and Enum.NamePlateStyle.Classic
end

local function GetModernStyle()
	return (Enum.NamePlateStyle and Enum.NamePlateStyle.Modern) or 0
end

local function GetCurrentStyle()
	return tonumber(C_CVar.GetCVar(CVAR))
end

local function SetStyle(style)
	if style == nil then return end
	if GetCurrentStyle() ~= style then
		C_CVar.SetCVar(CVAR, tostring(style))
	end
end

---------------------------------------------------------------------------
-- Classic geometry enforcement
---------------------------------------------------------------------------

-- Our own border textures, keyed by unit frame (never stored as fields on the
-- Blizzard frames). Blizzard's bgTexture keeps nine-slice state from the retail
-- atlas that SetTexture() does not clear, which is why it renders wrong with
-- the classic art; a fresh texture has no such baggage.
local ownTextures = setmetatable({}, { __mode = "k" })

local function GetOwnTextures(unitFrame)
	local own = ownTextures[unitFrame]
	if not own then
		local container = unitFrame.HealthBarsContainer
		local castBar = unitFrame.CastBarsContainer and unitFrame.CastBarsContainer.castBar
		own = {}
		own.border = container:CreateTexture(nil, "ARTWORK", nil, 1)
		own.border:SetTexture(BORDER)
		own.border:SetTexCoord(unpack(BORDER_COORDS))
		if castBar then
			own.castBorder = castBar:CreateTexture(nil, "OVERLAY", nil, -1)
			own.castBorder:SetTexture(CAST_BORDER)
			own.castBorder:SetTexCoord(unpack(CAST_BORDER_COORDS))
		end
		ownTextures[unitFrame] = own
	end
	return own
end

-- Retail look: hide our textures and give Blizzard's regions their alpha back.
local function HideOwnTextures(unitFrame)
	local own = ownTextures[unitFrame]
	if not own then return end
	own.border:Hide()
	if own.castBorder then own.castBorder:Hide() end
	local healthBar = unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar
	if healthBar and healthBar.bgTexture then
		healthBar.bgTexture:SetAlpha(1)
	end
	local castBar = unitFrame.CastBarsContainer and unitFrame.CastBarsContainer.castBar
	if castBar and castBar.Border then
		castBar.Border:SetAlpha(1)
	end
end

-- Re-applies the classic border/bar geometry after Blizzard's UpdateAnchors.
local function EnforceClassicLayout(unitFrame)
	if not enabled then
		HideOwnTextures(unitFrame)
		return
	end
	local options = NamePlateSetupOptions
	if type(options) ~= "table" or not options.useClassicHealthBar then
		HideOwnTextures(unitFrame)
		return
	end

	local hScale = options.horizontalScale or 1
	local vScale = options.verticalScale or 1
	local borderW = options.healthBarBorderWidth or (128 * hScale)
	local borderH = options.healthBarBorderHeight or (16 * vScale)

	local container = unitFrame.HealthBarsContainer
	local healthBar = container and container.healthBar
	if not healthBar then return end
	local own = GetOwnTextures(unitFrame)

	-- Blizzard's own background/border region is replaced by ours.
	if healthBar.bgTexture then
		healthBar.bgTexture:SetAlpha(0)
	end
	own.border:ClearAllPoints()
	own.border:SetPoint("CENTER", container, "CENTER", 0, 0)
	own.border:SetSize(borderW, borderH)
	own.border:Show()

	-- Health bar: flat classic fill, inset so the level bubble on the right is free.
	if healthBar.barTexture then
		healthBar.barTexture:SetTexture(BAR_FILL)
	end
	-- In the 136px art the bubble starts at px 108 (border units: 128 * 108/136).
	local bubbleLeft = 128 * (108 / BORDER_ART_WIDTH)
	local bubbleCenter = 128 * (120.5 / BORDER_ART_WIDTH)
	healthBar:ClearAllPoints()
	healthBar:SetPoint("TOPLEFT", container, "TOPLEFT", 4 * hScale, 0.5 * vScale)
	healthBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -(128 - bubbleLeft + 1.5) * hScale, 0.5 * vScale)

	-- Level text sits in the bubble.
	if unitFrame.LevelFrame then
		unitFrame.LevelFrame:ClearAllPoints()
		unitFrame.LevelFrame:SetPoint("CENTER", own.border, "RIGHT", -(128 - bubbleCenter) * hScale, 0)
	end

	-- Cast bar border (only visible while casting).
	local castContainer = unitFrame.CastBarsContainer
	local castBar = castContainer and castContainer.castBar
	if castBar and own.castBorder then
		if castBar.Border then
			castBar.Border:SetAlpha(0)
		end
		own.castBorder:ClearAllPoints()
		own.castBorder:SetPoint("CENTER", castContainer, "CENTER", 0, 0)
		own.castBorder:SetSize(options.castBarBorderWidth or borderW, options.castBarBorderHeight or borderH)
		own.castBorder:Show()
	end
end

local mixinHooked = false
local hookedFrames = setmetatable({}, { __mode = "k" })

local function HookFrame(unitFrame)
	if not unitFrame or hookedFrames[unitFrame] then return end
	hookedFrames[unitFrame] = true
	ns.Hook(unitFrame, "UpdateAnchors", EnforceClassicLayout)
end

local function InstallHooks()
	-- Frames created from now on copy the hooked mixin function.
	if not mixinHooked and type(NamePlateUnitFrameMixin) == "table" then
		mixinHooked = ns.Hook(NamePlateUnitFrameMixin, "UpdateAnchors", EnforceClassicLayout)
	end
end

local function ApplyToExistingPlates()
	if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
	for _, plate in pairs(C_NamePlate.GetNamePlates()) do
		local ok, unitFrame = pcall(function() return plate.UnitFrame end)
		if ok and unitFrame then
			if not mixinHooked then
				HookFrame(unitFrame)
			end
			xpcall(EnforceClassicLayout, geterrorhandler(), unitFrame)
		end
	end
end

-- Plates that appear later are laid out by Blizzard (UpdateAnchors) which
-- triggers the hook; plates created before the mixin was hooked are covered
-- by hooking them individually when they are added.
local driverHooked = false
local function HookDriver()
	if driverHooked or not NamePlateDriverFrame then return end
	driverHooked = ns.Hook(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unitToken)
		if not enabled or mixinHooked then return end
		local plate = C_NamePlate.GetNamePlateForUnit(unitToken)
		local ok, unitFrame = pcall(function() return plate and plate.UnitFrame end)
		if ok and unitFrame then
			HookFrame(unitFrame)
			xpcall(EnforceClassicLayout, geterrorhandler(), unitFrame)
		end
	end)
end

---------------------------------------------------------------------------
-- Module entry points
---------------------------------------------------------------------------

function module:Enable()
	local classic = GetClassicStyle()
	if not classic then
		ns.Print("This client has no classic nameplate style; the Nameplates option has no effect.")
		return
	end

	enabled = true
	InstallHooks()
	HookDriver()

	local current = GetCurrentStyle()
	if current ~= nil and current ~= classic then
		-- Remember what to go back to when the option is disabled.
		ns.db.nameplatesPreviousStyle = current
	end
	SetStyle(classic)
	ApplyToExistingPlates()
end

function module:Disable()
	enabled = false
	local classic = GetClassicStyle()
	local restore = ns.db.nameplatesPreviousStyle
	if restore == nil or restore == classic then
		restore = GetModernStyle()
	end
	ns.db.nameplatesPreviousStyle = nil
	-- Blizzard re-lays every plate out for the new style (hooks stay idle).
	SetStyle(restore)
end

-- Hook the mixin as early as possible so every plate created later is covered.
InstallHooks()
