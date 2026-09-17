--[[
	Classic UI Restoration - WoW Forever adjustments

	WoW Forever (client 1.60.x, Interface 16001) runs the retail "mainline" UI
	code with a "camelot" game-type overlay (wow-ui-source branch `forever`:
	Blizzard_UnitFrame\Camelot\* and Blizzard_NamePlates\Camelot\*). Every
	frame, region and function the shared modules hook is the same as on
	retail, so those modules are used unchanged. The overlay only adds a few
	elements the shared modules do not know about; they are handled here:

	  * Player, target, focus and boss frames show the level in a small circle
	    (<ContentMain>.LevelBackgroundCircle, large white font) in the bottom
	    corner of the frame. Classic shows it in the frame art's own circle,
	    where the shared Unit Frames module already anchors the level text.
	  * PvP status is a small faction circle (PvpBackgroundCircle +
	    PvpBackgroundIcon: in PlayerFrameContentMain on the player frame, in
	    TargetFrameContentContextual on target-style frames). The retail
	    PVPIcon/PrestigePortrait regions that the shared module repositions
	    still exist but are never shown on Forever. Classic used the big 64x64
	    "Interface\TargetingFrame\UI-PVP-*" banners; they are used when the
	    client still has them, otherwise Blizzard's small icon is moved to
	    the classic spot.
	  * Nameplates get a level indicator box (PlayerLevelDiffFrame) to the
	    right of every health bar and shrink the bar to make room for it. The
	    classic border has its own level bubble, so the box is faded out and
	    the bar takes the full width again.

	Everything here runs *after* the shared modules: this file is listed last
	in the .toc, and hooks on the same function fire in installation order.
]]

local _, ns = ...
local T = ns.T
local Point, SetTexture = ns.Point, ns.SetTexture

-- Same classic art offsets as the shared UnitFrames module.
local PLAYER_OFFSET_X, PLAYER_OFFSET_Y = -19, -4
local TARGET_OFFSET_X, TARGET_OFFSET_Y = 20, -4

T.PVP_ALLIANCE = "Interface\\TargetingFrame\\UI-PVP-Alliance"
T.PVP_HORDE    = "Interface\\TargetingFrame\\UI-PVP-Horde"
T.PVP_FFA      = "Interface\\TargetingFrame\\UI-PVP-FFA"

-- Camelot PvP atlas (as set by Blizzard right before our hooks run) -> classic banner.
local CLASSIC_PVP_FILES = {
	["ui-hud-unitframe-smallcircle-alliance"] = T.PVP_ALLIANCE,
	["ui-hud-unitframe-smallcircle-horde"]    = T.PVP_HORDE,
	["ui-hud-unitframe-player-pvp-ffaicon"]   = T.PVP_FFA,
}

local module = ns:RegisterModule({
	key = "forever",
	name = "WoW Forever adjustments",
	parent = "unitframes",
	live = false,
})

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- The legacy banner files may or may not ship with the Forever client;
-- GetFileIDFromPath answers that without drawing a broken texture.
local fileExists = {}
local function TextureExists(path)
	if fileExists[path] == nil then
		local id = GetFileIDFromPath and GetFileIDFromPath(path)
		fileExists[path] = (type(id) == "number" and id > 0)
	end
	return fileExists[path]
end

-- Classic banner for the atlas Blizzard just put on a Camelot PvP icon, or
-- nil when the icon is not carrying a Camelot atlas (already classic) or the
-- banner file is missing.
local function ClassicBannerFor(icon)
	local atlas = icon:GetAtlas()
	if type(atlas) ~= "string" then return nil, nil end
	local file = CLASSIC_PVP_FILES[atlas:lower()]
	if file and TextureExists(file) then
		return file, atlas
	end
	return nil, atlas
end

-- Level text in the frame art's circle: no Camelot background circle and the
-- classic number font instead of the large white one.
local function ClassicLevelText(text, circle)
	if circle then
		circle:Hide()
	end
	if text and GameNormalNumberFont then
		text:SetFontObject(GameNormalNumberFont)
	end
end

---------------------------------------------------------------------------
-- Player frame
---------------------------------------------------------------------------

-- Camelot colours the player level white; classic is gold (green while scaled).
local function ClassicPlayerLevelColor()
	if UnitExists("player") and UnitEffectiveLevel("player") == UnitLevel("player") then
		PlayerLevelText:SetVertexColor(1.0, 0.82, 0.0, 1.0)
	end
end

local function ClassicPlayerPvPIcon()
	local main = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
	local icon, circle = main.PvpBackgroundIcon, main.PvpBackgroundCircle
	if not icon or not circle then return end

	circle:Hide()
	if not icon:IsShown() then return end

	local file, atlas = ClassicBannerFor(icon)
	if not file and not atlas then return end -- already classic

	icon:SetScale(1)
	if file then
		SetTexture(icon, file)
		icon:SetSize(64, 64)
		Point(icon, "TOPLEFT", PlayerFrame, "TOPLEFT", 18 + PLAYER_OFFSET_X, -20 + PLAYER_OFFSET_Y)
	else
		-- Keep Blizzard's small icon, centred where the classic banner sits.
		Point(icon, "CENTER", PlayerFrame, "TOPLEFT", 50 + PLAYER_OFFSET_X, -52 + PLAYER_OFFSET_Y)
	end
	if PlayerPVPTimerText then
		Point(PlayerPVPTimerText, "CENTER", PlayerFrame, "TOPLEFT", 38 + PLAYER_OFFSET_X, -8 + PLAYER_OFFSET_Y)
	end
end

local function SkinPlayerFrame()
	local main = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
	ClassicLevelText(PlayerLevelText, main.LevelBackgroundCircle)
	ns.Hook("PlayerFrame_UpdateLevel", ClassicPlayerLevelColor)
	ClassicPlayerLevelColor()
	ns.Hook("PlayerFrame_UpdatePvPStatus", ClassicPlayerPvPIcon)
	ClassicPlayerPvPIcon()
end

---------------------------------------------------------------------------
-- Target / focus / boss frames
---------------------------------------------------------------------------

local function ClassicTargetPvPIcon(frame)
	local contextual = frame.TargetFrameContent.TargetFrameContentContextual
	local icon, circle = contextual.PvpBackgroundIcon, contextual.PvpBackgroundCircle
	if not icon or not circle then return end

	circle:Hide()
	if not icon:IsShown() then return end

	local file, atlas = ClassicBannerFor(icon)
	if not file and not atlas then return end

	icon:SetScale(1)
	if file then
		SetTexture(icon, file)
		icon:SetSize(64, 64)
		Point(icon, "TOPRIGHT", frame, "TOPRIGHT", 3 + TARGET_OFFSET_X, -20 + TARGET_OFFSET_Y)
	else
		Point(icon, "CENTER", frame, "TOPRIGHT", -29 + TARGET_OFFSET_X, -52 + TARGET_OFFSET_Y)
	end
end

local function SkinTargetStyleFrame(frame, hasPvP)
	if not frame or not frame.TargetFrameContent then return end
	local main = frame.TargetFrameContent.TargetFrameContentMain
	ClassicLevelText(main.LevelText, main.LevelBackgroundCircle)
	if hasPvP then
		ns.Hook(frame, "CheckFaction", ClassicTargetPvPIcon)
		ClassicTargetPvPIcon(frame)
	end
end

---------------------------------------------------------------------------
-- Nameplates: hide the Camelot level box next to the classic health bar
---------------------------------------------------------------------------

local function AdjustNamePlateLevelBox(unitFrame)
	local box = unitFrame.PlayerLevelDiffFrame
	if not box then return end

	local options = NamePlateSetupOptions
	local classic = ns:IsEnabled("nameplates") and type(options) == "table" and options.useClassicHealthBar
	if not classic then
		box:SetAlpha(1)
		return
	end

	-- Fade rather than hide: Blizzard re-shows it on every unit update.
	box:SetAlpha(0)

	-- Blizzard shrank the health bar by the box's width; take it back. The
	-- shared module's border and bar are anchored to the container and follow.
	local container, castContainer = unitFrame.HealthBarsContainer, unitFrame.CastBarsContainer
	if container and castContainer then
		container:SetPoint("BOTTOMRIGHT", castContainer, "TOPRIGHT", 0, options.castBarToHealthBarSpacing or 2)
		local auras = unitFrame.AurasFrame
		if auras then
			if auras.CrowdControlListFrame then
				auras.CrowdControlListFrame:SetPoint("LEFT", container, "RIGHT", 5, 0)
			end
			if auras.LossOfControlFrame then
				auras.LossOfControlFrame:SetPoint("LEFT", container, "RIGHT", 5, 0)
			end
		end
	end
end

-- Installed at load time, like the shared Nameplates module's own hook, so
-- every plate created afterwards copies the hooked mixin function. Runs after
-- the shared module's layout hook on the same function.
if type(NamePlateUnitFrameMixin) == "table" then
	ns.Hook(NamePlateUnitFrameMixin, "UpdateAnchors", AdjustNamePlateLevelBox)
end

---------------------------------------------------------------------------
-- Module entry point (unit frame part; follows the Unit Frames option)
---------------------------------------------------------------------------

function module:Apply()
	SkinPlayerFrame()
	SkinTargetStyleFrame(TargetFrame, true)
	SkinTargetStyleFrame(FocusFrame, true)
	if BossTargetFrameContainer and BossTargetFrameContainer.BossTargetFrames then
		for _, frame in pairs(BossTargetFrameContainer.BossTargetFrames) do
			SkinTargetStyleFrame(frame, false)
		end
	end
end
