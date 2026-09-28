--[[
	Forevermore Classic UI - Nameplates

	The pre-Dragonflight nameplate (Interface\Tooltips\Nameplate-Border with
	the flat UI-TargetingFrame-BarFill health bar, the level in the border's
	bubble, the name above it and a small bordered cast bar below it), drawn
	on Blizzard's own plates.

	The 12.x client has a built-in "Classic" nameplate style (the
	"nameplateStyle" CVar), but this module does not use it: the style is one
	setting for every plate, and friendly plates inside dungeons and raids are
	forbidden frames (ForbiddenNamePlate*) no addon can touch. With the classic
	style those showed Blizzard's broken version of it (the 256px-wide border
	file stretched over the bar, the level bubble in its middle). So the style
	is left as the player set it (normally Modern) and the classic look is laid
	out here, after Blizzard's own layout (NamePlateUnitFrameMixin:
	UpdateAnchors), on every plate addon code can reach: the containers get the
	classic sizes, the modern art is faded, and the addon's own border,
	background, level text and cast bar border are added. Forbidden plates
	(IsForbidden) are skipped and keep Blizzard's modern look.

	Only widget state is touched - no Lua fields are written on the plates,
	which matters because nameplate values are "secret" in 12.x. The level
	comes from UnitEffectiveLevel and is simply not shown while it is secret.

	Blizzard re-applies its modern cast bar fill on every cast, so like the
	Cast Bars module this one polls the visible plate cast bars from its own
	frame (the bars themselves cannot be hooked, see Modules\CastBars.lua) and
	puts the flat fill back in the classic colour of the cast type. The modern
	spark, shield, target name and glows are faded or blanked.

	Earlier versions switched "nameplateStyle" to Classic and saved the
	player's style in db.nameplatesPreviousStyle; that style is restored once
	at login.

	Needs a reload to switch off: the plates cannot be handed back to
	Blizzard's layout without calling its (field-writing) layout code.
]]

local _, ns = ...
local T = ns.T

local module = ns:RegisterModule({
	key = "nameplates",
	name = "Nameplates",
	tooltip = "The classic nameplate: the classic border with the level in its bubble, a flat health bar, the name above it and a flat bordered cast bar. Friendly nameplates inside dungeons and raids are locked by Blizzard and keep the modern look.",
	live = false,
})

local CVAR = "nameplateStyle"
local BORDER = "Interface\\Tooltips\\Nameplate-Border"
local CAST_BORDER = "Interface\\Tooltips\\Nameplate-Border-Castbar"
local BAR_FILL = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"

-- The retail client's Nameplate-Border.blp is 256x32 with the classic border
-- art (136x17 px) in the lower-left corner; the rest is empty. It is cropped
-- to that art and drawn 128x16 units, the classic border size.
local BORDER_COORDS = { 0, 136 / 256, 15 / 32, 1 }
local BORDER_ART_WIDTH = 136
-- Nameplate-Border-Castbar.blp is still the regular 128x32 file (art spans the
-- full width in the lower half), so it only needs the vertical crop.
local CAST_BORDER_COORDS = { 0, 1, 15 / 32, 1 }

-- Classic layout in units at the Medium nameplate size (Blizzard's classic
-- style constants); everything is multiplied by the size's scale.
local BORDER_WIDTH, BORDER_HEIGHT = 128, 16
local BAR_HEIGHT = 10         -- health and cast bar containers
local CAST_TO_HEALTH = 4      -- cast bar container to health bar container
local NAME_ABOVE = 4          -- health bar container to the name
local FONT_HEIGHT = 10
-- Health bar inside the border: 4 units in on the left, up to the level
-- bubble (px 108 of the 136px art) on the right, half a unit up.
local BAR_LEFT = 4
local BAR_RIGHT = BORDER_WIDTH - BORDER_WIDTH * (108 / BORDER_ART_WIDTH) + 1.5
local BAR_Y = 0.5
-- Level centred in the bubble (px 120.5 of the art), from the border's right.
local LEVEL_X = -(BORDER_WIDTH - BORDER_WIDTH * (120.5 / BORDER_ART_WIDTH))
local SKULL_SIZE = 12
-- Cast bar inside its border: the spell icon box on the left.
local CAST_LEFT, CAST_RIGHT = 20.75, 3.5
local CAST_ICON_SIZE, CAST_ICON_X = 14, 11.5

local enabled = false

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end

local function GetScale()
	local options = NamePlateSetupOptions
	return (type(options) == "table" and options.verticalScale) or 1
end

---------------------------------------------------------------------------
-- Plates
---------------------------------------------------------------------------

-- The unit frame of a unit's plate, nil for none or a forbidden one. The
-- settings' sample plate ("preview" token) makes the lookup error.
local function PlateFor(unit)
	if not unit or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
	local unitFrame = ok and plate and plate.UnitFrame
	if unitFrame and not unitFrame:IsForbidden() then
		return unitFrame
	end
end

local function ForEachPlate(fn)
	if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
	for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
		local unitFrame = plate.UnitFrame
		if unitFrame and not unitFrame:IsForbidden() then
			xpcall(fn, geterrorhandler(), unitFrame)
		end
	end
end

-- Faded rather than hidden: Blizzard shows and hides these itself.
local function Fade(region)
	if region then region:SetAlpha(0) end
end

-- Blanked: Blizzard shows, hides and animates the alpha of these glows; their
-- atlases come from the XML template only.
local function Blank(texture)
	if texture then texture:SetColorTexture(0, 0, 0, 0) end
end

---------------------------------------------------------------------------
-- The addon's own regions (keyed by unit frame, never fields on the plates)
---------------------------------------------------------------------------

local ownRegions = setmetatable({}, { __mode = "k" })

local function FontTemplate(name, fallback)
	return _G[name] and name or fallback
end

-- On the health bar, so they hide with it (names-only and widgets-only plates).
local function GetOwnRegions(unitFrame, healthBar, castBar)
	local own = ownRegions[unitFrame]
	if own then return own end
	own = {}

	own.background = healthBar:CreateTexture(nil, "BACKGROUND", nil, 1)
	own.background:SetColorTexture(0, 0, 0, 0.5)
	own.background:SetAllPoints(healthBar)

	own.border = healthBar:CreateTexture(nil, "OVERLAY", nil, 6)
	own.border:SetTexture(BORDER)
	own.border:SetTexCoord(unpack(BORDER_COORDS))

	own.level = healthBar:CreateFontString(nil, "OVERLAY", FontTemplate("SystemFont_NamePlateLevel", "GameFontNormalSmall"))
	own.level:SetDrawLayer("OVERLAY", 7)
	own.level:SetJustifyH("CENTER")

	own.skull = healthBar:CreateTexture(nil, "OVERLAY", nil, 7)
	own.skull:SetTexture(T.SKULL)
	own.skull:Hide()

	if castBar then
		own.castBorder = castBar:CreateTexture(nil, "OVERLAY", nil, -1)
		own.castBorder:SetTexture(CAST_BORDER)
		own.castBorder:SetTexCoord(unpack(CAST_BORDER_COORDS))
	end

	ownRegions[unitFrame] = own
	return own
end

---------------------------------------------------------------------------
-- Level
---------------------------------------------------------------------------

-- The level in the border's bubble: yellow for units that cannot be attacked,
-- the difficulty colour for the others, and a skull when it is unknown or ten
-- levels above the player (as the classic target frame).
local function UpdateLevel(unitFrame)
	local own = ownRegions[unitFrame]
	if not own then return end
	local unit = unitFrame.unit
	local level = unit and (UnitEffectiveLevel or UnitLevel)(unit)
	if level == nil or IsSecret(level) then
		own.level:Hide()
		own.skull:Hide()
		return
	end

	local canAttack = UnitCanAttack("player", unit)
	if IsSecret(canAttack) then canAttack = false end
	if level <= 0 or (canAttack and level >= UnitLevel("player") + 10) then
		own.level:Hide()
		own.skull:Show()
		return
	end

	own.skull:Hide()
	own.level:SetText(level)
	local color = canAttack and GetCreatureDifficultyColor and GetCreatureDifficultyColor(level)
	if color then
		own.level:SetTextColor(color.r, color.g, color.b)
	else
		own.level:SetTextColor(1, 0.82, 0)
	end
	own.level:Show()
end

---------------------------------------------------------------------------
-- Cast bars
---------------------------------------------------------------------------

-- Plate cast bars laid out while the module is on; polled below.
local watchedCastBars = setmetatable({}, { __mode = "k" })

-- A fill or flash carrying an atlas is one Blizzard has just set; the colour
-- comes from that atlas (standard / channel / uninterruptible / interrupted).
local function RepairCastBarArt(castBar)
	local art = ns.CastBarArt
	if not art then return end
	if art.HasAtlas(castBar:GetStatusBarTexture()) then
		local color = art.GetColor(castBar)
		castBar:SetStatusBarTexture(BAR_FILL)
		castBar:SetStatusBarColor(color[1], color[2], color[3])
	end
	-- Classic plates have no finish flash; blank the retail glow.
	if castBar.Flash and art.HasAtlas(castBar.Flash) then
		castBar.Flash:SetColorTexture(0, 0, 0, 0)
	end
end

local updater = CreateFrame("Frame")
updater:Hide()
updater:SetScript("OnUpdate", function()
	for castBar in pairs(watchedCastBars) do
		if castBar:IsShown() then
			RepairCastBarArt(castBar)
		end
	end
end)

local function LayoutCastBar(castContainer, castBar, own, scale)
	watchedCastBars[castBar] = true

	castBar:ClearAllPoints()
	castBar:SetPoint("TOPLEFT", castContainer, "TOPLEFT", CAST_LEFT * scale, BAR_Y * scale)
	castBar:SetPoint("BOTTOMRIGHT", castContainer, "BOTTOMRIGHT", -CAST_RIGHT * scale, BAR_Y * scale)

	own.castBorder:ClearAllPoints()
	own.castBorder:SetPoint("CENTER", castContainer, "CENTER", 0, 0)
	own.castBorder:SetSize(BORDER_WIDTH * scale, BORDER_HEIGHT * scale)

	if castBar.Icon then
		castBar.Icon:ClearAllPoints()
		castBar.Icon:SetPoint("CENTER", own.castBorder, "LEFT", CAST_ICON_X * scale, 0)
		castBar.Icon:SetSize(CAST_ICON_SIZE * scale, CAST_ICON_SIZE * scale)
	end
	if castBar.Text then
		castBar.Text:ClearAllPoints()
		castBar.Text:SetPoint("TOPLEFT", castBar, "TOPLEFT", 0, -1 * scale)
		castBar.Text:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 0, -1 * scale)
		castBar.Text:SetJustifyH("CENTER")
	end
	if castBar.Background then
		castBar.Background:SetColorTexture(0, 0, 0, 0.5)
	end
	-- Blizzard's own border (the classic style's), the modern spark, the
	-- uninterruptible shield (the grey fill shows it) and the target's name.
	Fade(castBar.Border)
	Fade(castBar.Spark)
	Fade(castBar.BorderShield)
	Fade(castBar.CastTargetNameText)
	-- The "casting at you" glow and the pulsing important-cast glow.
	Blank(castBar.CastTargetIndicator)
	Blank(castBar.ImportantCastIndicator)
	RepairCastBarArt(castBar)
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

-- Runs after Blizzard's UpdateAnchors, which lays the whole plate out again
-- (unit set, size, options and name-only changes).
local function Layout(unitFrame)
	if not enabled or not unitFrame or unitFrame:IsForbidden() then return end
	local container, castContainer = unitFrame.HealthBarsContainer, unitFrame.CastBarsContainer
	local healthBar = container and container.healthBar
	if not healthBar or not castContainer then return end
	local castBar = castContainer.castBar
	local own = GetOwnRegions(unitFrame, healthBar, castBar)
	local scale = GetScale()

	-- From the bottom: the cast bar slot, the health bar above it, both the
	-- classic border's width and centred on the plate.
	castContainer:ClearAllPoints()
	castContainer:SetPoint("BOTTOM", unitFrame, "BOTTOM", 0, 0)
	castContainer:SetSize(BORDER_WIDTH * scale, BAR_HEIGHT * scale)
	container:ClearAllPoints()
	container:SetPoint("BOTTOM", castContainer, "TOP", 0, CAST_TO_HEALTH * scale)
	container:SetSize(BORDER_WIDTH * scale, BAR_HEIGHT * scale)

	-- Health bar: the flat classic fill inside the border, up to the bubble.
	healthBar:ClearAllPoints()
	healthBar:SetPoint("TOPLEFT", container, "TOPLEFT", BAR_LEFT * scale, BAR_Y * scale)
	healthBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -BAR_RIGHT * scale, BAR_Y * scale)
	if healthBar.barTexture then
		healthBar.barTexture:SetTexture(BAR_FILL)
	end
	-- The modern background, target border and the dimming of the others.
	Fade(healthBar.bgTexture)
	Fade(healthBar.selectedBorder)
	Fade(healthBar.deselectedOverlay)

	own.border:ClearAllPoints()
	own.border:SetPoint("CENTER", container, "CENTER", 0, 0)
	own.border:SetSize(BORDER_WIDTH * scale, BORDER_HEIGHT * scale)

	own.level:ClearAllPoints()
	own.level:SetPoint("CENTER", own.border, "RIGHT", LEVEL_X * scale, 0)
	own.level:SetTextHeight(FONT_HEIGHT * scale)
	own.skull:ClearAllPoints()
	own.skull:SetPoint("CENTER", own.border, "RIGHT", LEVEL_X * scale, 0)
	own.skull:SetSize(SKULL_SIZE * scale, SKULL_SIZE * scale)
	UpdateLevel(unitFrame)

	-- Blizzard's level (classic style), Forever's level box and the modern
	-- classification icon: the level is in the bubble.
	Fade(unitFrame.LevelFrame)
	Fade(unitFrame.PlayerLevelDiffFrame)
	Fade(unitFrame.ClassificationFrame)

	-- The name centred above the border, in the classic (not outlined) font.
	local name = unitFrame.name
	if name then
		name:SetFontObject(FontTemplate("SystemFont_NamePlate", "GameFontNormalSmall"))
		name:SetTextHeight(FONT_HEIGHT * scale)
		name:ClearAllPoints()
		name:SetPoint("BOTTOM", container, "TOP", 0, NAME_ABOVE * scale)
		name:SetWidth(0)
		name:SetJustifyH("CENTER")
	end

	-- Debuffs above the name; crowd control, loss of control and the raid
	-- icon beside the (now narrower) bar.
	local auras = unitFrame.AurasFrame
	if auras then
		if auras.DebuffListFrame and name then
			local padding = tonumber(C_CVar.GetCVar("nameplateDebuffPadding")) or 0
			auras.DebuffListFrame:SetPoint("BOTTOM", name, "TOP", 0, padding)
		end
		if auras.CrowdControlListFrame then
			auras.CrowdControlListFrame:SetPoint("LEFT", container, "RIGHT", 5, 0)
		end
		if auras.LossOfControlFrame then
			auras.LossOfControlFrame:SetPoint("LEFT", container, "RIGHT", 5, 0)
		end
	end
	if unitFrame.RaidTargetFrame and not unitFrame.showOnlyName then
		unitFrame.RaidTargetFrame:ClearAllPoints()
		unitFrame.RaidTargetFrame:SetPoint("RIGHT", container, "LEFT", 0, 0)
	end

	if castBar and own.castBorder then
		LayoutCastBar(castContainer, castBar, own, scale)
	end
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------

local mixinHooked = false
local hookedFrames = setmetatable({}, { __mode = "k" })

local function HookFrame(unitFrame)
	if hookedFrames[unitFrame] then return end
	hookedFrames[unitFrame] = true
	ns.Hook(unitFrame, "UpdateAnchors", Layout)
end

local function InstallHooks()
	-- Frames created from now on copy the hooked mixin function.
	if not mixinHooked and type(NamePlateUnitFrameMixin) == "table" then
		mixinHooked = ns.Hook(NamePlateUnitFrameMixin, "UpdateAnchors", Layout)
	end
end

-- Blizzard lays a plate out before it sets its unit, so the level is only
-- known once the plate has been added. Plates created before the mixin was
-- hooked are hooked here as well.
local driverHooked = false
local function HookDriver()
	if driverHooked or not NamePlateDriverFrame then return end
	driverHooked = ns.Hook(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unitToken)
		local unitFrame = enabled and PlateFor(unitToken)
		if not unitFrame then return end
		if not mixinHooked then
			HookFrame(unitFrame)
		end
		Layout(unitFrame)
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UNIT_LEVEL")
events:RegisterEvent("UNIT_FACTION")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_LOGIN" then
		-- Earlier versions set the style to Classic; give the player's back.
		local previous = ns.db and ns.db.nameplatesPreviousStyle
		if previous ~= nil then
			ns.db.nameplatesPreviousStyle = nil
			local classic = Enum.NamePlateStyle and Enum.NamePlateStyle.Classic
			if classic and previous ~= classic and tonumber(C_CVar.GetCVar(CVAR)) == classic then
				C_CVar.SetCVar(CVAR, tostring(previous))
			end
		end
		if ns.db then
			ns.db.nameplatesinstances = nil -- a removed option
		end
	elseif not enabled then
		return
	elseif event == "PLAYER_LEVEL_UP" then
		-- The difficulty colours follow the player's level.
		ForEachPlate(UpdateLevel)
	else
		local unitFrame = PlateFor(unit)
		if unitFrame then
			UpdateLevel(unitFrame)
		end
	end
end)

---------------------------------------------------------------------------
-- Module entry point
---------------------------------------------------------------------------

function module:Apply()
	enabled = true
	InstallHooks()
	HookDriver()
	ForEachPlate(Layout)
	updater:Show()
end

-- Hook the mixin as early as possible so every plate created later is covered.
InstallHooks()
