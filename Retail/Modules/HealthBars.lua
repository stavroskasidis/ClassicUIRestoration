--[[
	Classic UI Restoration - Health Bars

	Swaps the retail health bar artwork for the flat classic status bar
	texture (Interface\TargetingFrame\UI-StatusBar) on the player, target,
	focus, target-of-target, pet, party, boss and raid-style frames. Heal
	prediction and absorb overlays get their classic textures as well.

	Part of the "Unit Frames" option: bar sizes/positions are handled by the
	Unit Frames module, this file only changes what the bars are drawn with.
]]

local _, ns = ...
local T = ns.T

local module = ns:RegisterModule({
	key = "healthbars",
	name = "Health Bars",
	parent = "unitframes",
	live = false,
})

local HEALTH_R, HEALTH_G, HEALTH_B = unpack(ns.C.HEALTH)

local function SetBarTexture(bar)
	if not bar then return end
	bar:SetStatusBarTexture(T.STATUS_BAR)
end

-- Retail health bars lock their colour because the atlases are pre-coloured;
-- the flat classic texture needs the classic green (grey when disconnected).
-- When the Unit Frames module has created a mirror for the bar, the mirror is
-- what is visible and gets the classic look (ns.GetBar).
local function ColorHealthBar(bar)
	local target = ns.GetBar(bar)
	if bar.disconnected then
		target:SetStatusBarColor(0.5, 0.5, 0.5)
	else
		target:SetStatusBarColor(HEALTH_R, HEALTH_G, HEALTH_B)
	end
end

local function SetHealthBarTexture(bar)
	if not bar then return end
	local target = ns.GetBar(bar)
	ns.SetBarTexture(target, T.STATUS_BAR)
	if target ~= bar then
		target.classicOwned = true
	end
	bar.CUIR_ClassicHealth = true
	ColorHealthBar(bar)
end

-- Heal prediction / absorb children shared by the player, target, pet and party bars.
local function ApplyPredictionTextures(healthBar)
	if not healthBar then return end
	if healthBar.MyHealPredictionBar and healthBar.MyHealPredictionBar.Fill then
		healthBar.MyHealPredictionBar.Fill:SetTexture(T.STATUS_BAR)
	end
	if healthBar.OtherHealPredictionBar and healthBar.OtherHealPredictionBar.Fill then
		healthBar.OtherHealPredictionBar.Fill:SetTexture(T.STATUS_BAR)
	end
	if healthBar.HealAbsorbBar and healthBar.HealAbsorbBar.Fill then
		healthBar.HealAbsorbBar.Fill:SetTexture(T.ABSORB_FILL, true, true)
	end
	if healthBar.TotalAbsorbBar and healthBar.TotalAbsorbBar.Fill then
		healthBar.TotalAbsorbBar.Fill:SetTexture(T.SHIELD_FILL)
	end
end

local function ApplyClassicHealthBar(healthBar)
	SetHealthBarTexture(healthBar)
	ApplyPredictionTextures(healthBar)
end

---------------------------------------------------------------------------
-- Player
---------------------------------------------------------------------------

local function SkinPlayer()
	local hbc = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer
	local function Apply()
		ApplyClassicHealthBar(hbc.HealthBar)
		if hbc.PlayerFrameHealthBarAnimatedLoss then
			SetBarTexture(hbc.PlayerFrameHealthBarAnimatedLoss)
		end
		if hbc.PlayerFrameTempMaxHealthLoss then
			SetBarTexture(hbc.PlayerFrameTempMaxHealthLoss)
		end
	end
	Apply()
	ns.Hook("PlayerFrame_ToPlayerArt", Apply)
	ns.Hook("PlayerFrame_ToVehicleArt", Apply)
end

---------------------------------------------------------------------------
-- Target / focus / boss (TargetFrameTemplate based)
---------------------------------------------------------------------------

local function SkinTargetStyleFrame(frame)
	if not frame or not frame.TargetFrameContent then return end
	local hbc = frame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
	local function Apply()
		ApplyClassicHealthBar(hbc.HealthBar)
		if hbc.TempMaxHealthLoss then
			SetBarTexture(hbc.TempMaxHealthLoss)
		end
	end
	Apply()
	-- CheckClassification re-applies the retail atlas every time the target changes.
	ns.Hook(frame, "CheckClassification", Apply)
	ns.Hook(frame, "Update", Apply)
	module.reapply[frame] = Apply

	if frame.totFrame and frame.totFrame.HealthBar then
		SetHealthBarTexture(frame.totFrame.HealthBar)
	end
end

---------------------------------------------------------------------------
-- Pet
---------------------------------------------------------------------------

local function SkinPet()
	if not PetFrameHealthBar then return end
	SetHealthBarTexture(PetFrameHealthBar)
	if PetFrameMyHealPredictionBar and PetFrameMyHealPredictionBar.Fill then
		PetFrameMyHealPredictionBar.Fill:SetTexture(T.STATUS_BAR)
	end
	if PetFrameOtherHealPredictionBar and PetFrameOtherHealPredictionBar.Fill then
		PetFrameOtherHealPredictionBar.Fill:SetTexture(T.STATUS_BAR)
	end
	if PetFrameHealAbsorbBar and PetFrameHealAbsorbBar.Fill then
		PetFrameHealAbsorbBar.Fill:SetTexture(T.ABSORB_FILL, true, true)
	end
	if PetFrameTotalAbsorbBar and PetFrameTotalAbsorbBar.Fill then
		PetFrameTotalAbsorbBar.Fill:SetTexture(T.SHIELD_FILL)
	end
end

---------------------------------------------------------------------------
-- Party
---------------------------------------------------------------------------

local function SkinPartyMember(frame)
	local hbc = frame.HealthBarContainer
	local function Apply()
		ApplyClassicHealthBar(hbc.HealthBar)
		if hbc.TempMaxHealthLoss then
			SetBarTexture(hbc.TempMaxHealthLoss)
		end
	end
	Apply()
	ns.Hook(frame, "ToPlayerArt", Apply)
	ns.Hook(frame, "ToVehicleArt", Apply)
	if frame.PetFrame and frame.PetFrame.HealthBar then
		SetHealthBarTexture(frame.PetFrame.HealthBar)
	end
end

local function SkinParty()
	if not PartyFrame or not PartyFrame.PartyMemberFramePool then return end
	for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
		if not frame.CUIR_HealthSkinned then
			frame.CUIR_HealthSkinned = true
			SkinPartyMember(frame)
		end
	end
end

---------------------------------------------------------------------------
-- Raid-style (compact) frames
---------------------------------------------------------------------------

local function SkinCompactFrame(frame)
	if not frame or not frame.healthBar then return end
	frame.healthBar:SetStatusBarTexture(T.RAID_HP_FILL)
	frame.healthBar:GetStatusBarTexture():SetDrawLayer("BORDER")
	if frame.myHealAbsorb then
		frame.myHealAbsorb:SetTexture(T.ABSORB_FILL, true, true)
	end
	if frame.totalAbsorb then
		frame.totalAbsorb:SetTexture(T.SHIELD_FILL, true, true)
	end
end

---------------------------------------------------------------------------
-- Module entry point
---------------------------------------------------------------------------

-- Re-applies the classic textures on target/focus/boss frames whenever the
-- displayed unit changes, independently of Blizzard's hook chain.
module.reapply = {}
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function()
	for frame, fn in pairs(module.reapply) do
		if frame:IsShown() then
			xpcall(fn, geterrorhandler())
		end
	end
end)

function module:Apply()
	for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_CLASSIFICATION_CHANGED", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "PLAYER_ENTERING_WORLD" }) do
		eventFrame:RegisterEvent(event)
	end

	SkinPlayer()
	SkinTargetStyleFrame(TargetFrame)
	SkinTargetStyleFrame(FocusFrame)
	if BossTargetFrameContainer and BossTargetFrameContainer.BossTargetFrames then
		for _, frame in pairs(BossTargetFrameContainer.BossTargetFrames) do
			SkinTargetStyleFrame(frame)
		end
	end
	SkinPet()

	SkinParty()
	if PartyFrame then
		ns.Hook(PartyFrame, "InitializePartyMemberFrames", SkinParty)
	end

	ns.Hook("DefaultCompactUnitFrameSetup", SkinCompactFrame)

	-- Keep the classic colour after Blizzard refreshes a bar (connected/disconnected).
	ns.Hook("UnitFrameHealthBar_Update", function(statusbar)
		if statusbar and statusbar.CUIR_ClassicHealth then
			ColorHealthBar(statusbar)
		end
	end)
end
