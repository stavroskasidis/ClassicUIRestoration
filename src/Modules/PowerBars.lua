--[[
	Classic UI Restoration - Power Bars

	Draws every unit frame power bar (mana, rage, energy, focus, runic power,
	etc.) with the flat classic status bar texture and the classic solid power
	colours instead of the retail resource-specific artwork. The retail end-cap
	"spark" is hidden because classic bars did not have one.

	Part of the "Unit Frames" option. All of Blizzard's unit frame power bars
	funnel through UnitFrameManaBar_UpdateType(), so one hook covers the
	player, pet, target, focus, target-of-target, party and boss frames.
]]

local _, ns = ...
local T = ns.T

local module = ns:RegisterModule({
	key = "powerbars",
	name = "Power Bars",
	parent = "unitframes",
	live = false,
})

local FALLBACK_COLOR = { r = 0, g = 0, b = 1 }

local function GetClassicPowerColor(powerType, powerToken, overrideInfo)
	local info = overrideInfo or (powerToken and PowerBarColor[powerToken])
	if not info and powerType then
		info = PowerBarColor[powerType]
	end
	if info and info.r then
		return info
	end
	return FALLBACK_COLOR
end

local function ApplyClassicPowerBar(manaBar)
	if not manaBar or not manaBar.unit then return end

	local powerType, powerToken, altR, altG, altB = UnitPowerType(manaBar.unit)

	-- With classic unit frames the visible bar is an unprotected mirror.
	local target = ns.GetBar(manaBar)
	if target ~= manaBar then
		target.classicOwned = true
		-- UnitFrameManaBar_UpdateType ends by resetting Blizzard's own fill
		-- to alpha 1 (0.5 when dead), which would show the retail bar art
		-- through the classic mirror on every unit change; keep it hidden.
		manaBar:GetStatusBarTexture():SetAlpha(0)
	end
	ns.SetBarTexture(target, T.STATUS_BAR)
	local texture = target:GetStatusBarTexture()
	texture:SetDesaturated(false)
	if target == manaBar then
		texture:SetAlpha(1)
	end

	local playerDeadOrGhost = manaBar.unit == "player" and (UnitIsDead("player") or UnitIsGhost("player"))
	if playerDeadOrGhost then
		target:SetStatusBarColor(0.6, 0.6, 0.6, 0.5)
	elseif altR then
		target:SetStatusBarColor(altR, altG, altB)
	else
		local info = GetClassicPowerColor(powerType, powerToken, manaBar.overrideInfo)
		target:SetStatusBarColor(info.r, info.g, info.b)
	end

	-- Classic bars have no end-cap spark.
	if manaBar.Spark then
		manaBar.Spark:SetAlpha(0)
	end

	-- Builder/spender feedback flashes use the bar art; keep them flat too.
	if manaBar.FeedbackFrame and manaBar.FeedbackFrame.BarTexture then
		manaBar.FeedbackFrame.BarTexture:SetTexture(T.STATUS_BAR)
	end
end

local function ApplyClassicAlternatePowerBar(self)
	local target = ns.GetBar(self)
	if target ~= self then
		target.classicOwned = true
		-- UpdateIsAliveState resets the retail fill's alpha like the mana bar above.
		self:GetStatusBarTexture():SetAlpha(0)
	end
	ns.SetBarTexture(target, T.STATUS_BAR)
	local info = self.powerName and PowerBarColor[self.powerName]
	if info and info.r then
		target:SetStatusBarColor(info.r, info.g, info.b)
	else
		target:SetStatusBarColor(FALLBACK_COLOR.r, FALLBACK_COLOR.g, FALLBACK_COLOR.b)
	end
	if self.Spark then
		self.Spark:SetAlpha(0)
	end
	if self.PowerBarMask then
		self.PowerBarMask:Hide()
	end
end

local function SkinCompactFrame(frame)
	if not frame or not frame.powerBar then return end
	frame.powerBar:SetStatusBarTexture(T.RAID_RES_FILL)
	frame.powerBar:GetStatusBarTexture():SetDrawLayer("BORDER")
	if frame.powerBar.background then
		frame.powerBar.background:SetTexture(T.RAID_RES_BG)
	end
end

local function ReapplyAllUnitFrameBars()
	local bars = {
		PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar,
		TargetFrame and TargetFrame.TargetFrameContent.TargetFrameContentMain.ManaBar,
		FocusFrame and FocusFrame.TargetFrameContent.TargetFrameContentMain.ManaBar,
		TargetFrame and TargetFrame.totFrame and TargetFrame.totFrame.ManaBar,
		FocusFrame and FocusFrame.totFrame and FocusFrame.totFrame.ManaBar,
		PetFrameManaBar,
	}
	if BossTargetFrameContainer and BossTargetFrameContainer.BossTargetFrames then
		for _, frame in pairs(BossTargetFrameContainer.BossTargetFrames) do
			table.insert(bars, frame.TargetFrameContent.TargetFrameContentMain.ManaBar)
		end
	end
	if PartyFrame and PartyFrame.PartyMemberFramePool then
		for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
			table.insert(bars, frame.ManaBar)
		end
	end
	for _, bar in ipairs(bars) do
		if bar and bar.unit and UnitExists(bar.unit) then
			ApplyClassicPowerBar(bar)
		elseif bar then
			bar:SetStatusBarTexture(T.STATUS_BAR)
			if bar.Spark then bar.Spark:SetAlpha(0) end
		end
	end
end

function module:Apply()
	ns.Hook("UnitFrameManaBar_UpdateType", ApplyClassicPowerBar)
	ReapplyAllUnitFrameBars()

	if AlternatePowerBar then
		ns.Hook(AlternatePowerBar, "UpdateArt", ApplyClassicAlternatePowerBar)
		ns.Hook(AlternatePowerBar, "EvaluateUnit", ApplyClassicAlternatePowerBar)
		ns.Hook(AlternatePowerBar, "UpdateIsAliveState", ApplyClassicAlternatePowerBar)
		ApplyClassicAlternatePowerBar(AlternatePowerBar)
	end

	ns.Hook("DefaultCompactUnitFrameSetup", SkinCompactFrame)
end
