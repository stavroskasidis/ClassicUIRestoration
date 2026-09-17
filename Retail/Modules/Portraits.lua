--[[
	Classic UI Restoration - Portraits

	Restores the classic portrait treatment:
	  * the classic circular portrait mask on every unit frame portrait
	  * the classic "Zzz" resting bubble and crossed-swords combat indicator
	    next to the player portrait (with their pulsing glow), replacing the
	    retail corner embellishment, combat icon and animated rest loop.

	Part of the "Unit Frames" option; portrait size/position is part of the
	frame layout and lives in the Unit Frames module.
]]

local _, ns = ...
local T = ns.T
local Point, SetTexture = ns.Point, ns.SetTexture

local module = ns:RegisterModule({
	key = "portraits",
	name = "Portraits",
	parent = "unitframes",
	live = false,
})

local function ApplyClassicMask(mask, portrait)
	if not mask or not portrait then return end
	mask:SetTexture(T.PORTRAIT_MASK)
	mask:ClearAllPoints()
	mask:SetAllPoints(portrait)
	mask:Show()
end

---------------------------------------------------------------------------
-- Player status icons (rest / combat)
---------------------------------------------------------------------------

local function CreatePlayerStatusIcons()
	local frame = PlayerFrame
	local container = frame.PlayerFrameContainer
	local contextual = frame.PlayerFrameContent.PlayerFrameContentContextual
	local portrait = container.PlayerPortrait

	local restIcon = contextual:CreateTexture(nil, "OVERLAY")
	restIcon:SetSize(31, 31)
	SetTexture(restIcon, T.STATE_ICON, 0, 0.5, 0, 0.421875)
	restIcon:SetPoint("TOPLEFT", portrait, "TOPLEFT", -3, -38)

	local restGlow = contextual:CreateTexture(nil, "OVERLAY")
	restGlow:SetSize(32, 32)
	SetTexture(restGlow, T.STATE_ICON, 0, 0.5, 0.5, 1)
	restGlow:SetBlendMode("ADD")
	restGlow:SetPoint("TOPLEFT", restIcon, "TOPLEFT")

	local attackIcon = contextual:CreateTexture(nil, "OVERLAY")
	attackIcon:SetSize(32, 31)
	SetTexture(attackIcon, T.STATE_ICON, 0.5, 1, 0, 0.484375)
	attackIcon:SetPoint("TOPLEFT", restIcon, "TOPLEFT", 1, 1)

	local attackGlow = contextual:CreateTexture(nil, "OVERLAY")
	attackGlow:SetSize(32, 32)
	SetTexture(attackGlow, T.STATE_ICON, 0.5, 1, 0.5, 1)
	attackGlow:SetVertexColor(1, 0, 0)
	attackGlow:SetBlendMode("ADD")
	attackGlow:SetPoint("TOPLEFT", attackIcon, "TOPLEFT")

	local attackBackground = contextual:CreateTexture(nil, "ARTWORK")
	attackBackground:SetSize(32, 32)
	SetTexture(attackBackground, T.ATTACK_BG)
	attackBackground:SetVertexColor(0.8, 0.1, 0.1)
	attackBackground:SetAlpha(0.4)
	attackBackground:SetPoint("TOPLEFT", attackIcon, "TOPLEFT", -3, -1)

	local icons = {
		restIcon = restIcon,
		restGlow = restGlow,
		attackIcon = attackIcon,
		attackGlow = attackGlow,
		attackBackground = attackBackground,
	}
	frame.CUIR_StatusIcons = icons

	local function SetShown(rest, attack, attackGlowShown, background)
		restIcon:SetShown(rest)
		restGlow:SetShown(rest)
		attackIcon:SetShown(attack)
		attackGlow:SetShown(attackGlowShown)
		attackBackground:SetShown(background)
	end

	local function UpdateStatus()
		-- Retail decorations that classic replaces.
		contextual.AttackIcon:Hide()
		contextual.PlayerPortraitCornerIcon:Hide()

		if UnitHasVehiclePlayerFrameUI("player") then
			SetShown(false, false, false, false)
		elseif IsResting() then
			SetShown(true, false, false, false)
		elseif frame.inCombat then
			SetShown(false, true, true, true)
		elseif frame.onHateList then
			SetShown(false, true, false, false)
		else
			SetShown(false, false, false, false)
		end
	end

	ns.Hook("PlayerFrame_UpdateStatus", UpdateStatus)
	ns.Hook("PlayerFrame_UpdatePlayerRestLoop", function()
		local loop = contextual.PlayerRestLoop
		if loop then
			loop:Hide()
			if loop.PlayerRestLoopAnim then
				loop.PlayerRestLoopAnim:Stop()
			end
		end
	end)

	-- The glows pulse in sync with Blizzard's own status texture alpha.
	frame:HookScript("OnUpdate", function(self)
		local statusTexture = self.PlayerFrameContent.PlayerFrameContentMain.StatusTexture
		if statusTexture:IsShown() then
			local alpha = statusTexture:GetAlpha()
			if attackGlow:IsShown() then attackGlow:SetAlpha(alpha) end
			if restGlow:IsShown() then restGlow:SetAlpha(alpha) end
		end
	end)

	UpdateStatus()
end

---------------------------------------------------------------------------
-- Party portraits are pooled, so they are (re)applied whenever the party
-- frame lays itself out.
---------------------------------------------------------------------------

local function ApplyPartyMasks()
	if not PartyFrame or not PartyFrame.PartyMemberFramePool then return end
	for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
		ApplyClassicMask(frame.PortraitMask, frame.Portrait)
		if frame.PetFrame then
			ApplyClassicMask(frame.PetFrame.PortraitMask, frame.PetFrame.Portrait)
		end
	end
end

---------------------------------------------------------------------------
-- Module entry point
---------------------------------------------------------------------------

function module:Apply()
	-- Player.
	local container = PlayerFrame.PlayerFrameContainer
	ApplyClassicMask(container.PlayerPortraitMask, container.PlayerPortrait)
	CreatePlayerStatusIcons()

	-- Target / focus (+ their targets).
	for _, frame in ipairs({ TargetFrame, FocusFrame }) do
		if frame and frame.TargetFrameContainer then
			ApplyClassicMask(frame.TargetFrameContainer.PortraitMask, frame.TargetFrameContainer.Portrait)
			if frame.totFrame then
				ApplyClassicMask(frame.totFrame.PortraitMask, frame.totFrame.Portrait)
			end
		end
	end

	-- Pet.
	if PetFrame and PetFrame.PortraitMask then
		ApplyClassicMask(PetFrame.PortraitMask, PetPortrait)
	end

	-- Party.
	ApplyPartyMasks()
	if PartyFrame then
		ns.Hook(PartyFrame, "InitializePartyMemberFrames", ApplyPartyMasks)
	end
end
