--[[
	Classic UI Restoration - Core

	Shared state, module registry, saved variables and small helpers used by
	every module. Each module registers itself with ns:RegisterModule() and is
	activated from PLAYER_LOGIN when its option is enabled.

	Modules come in two flavours:
	  * "live" modules (cast bars, nameplates) implement Enable()/Disable() and
	    can be toggled at any time without a reload.
	  * "reload" modules (unit frames, with portraits and health/power bars as
	    its parts) implement Apply() once at login; turning them off restores
	    the retail look after a UI reload, because Blizzard's frames cannot be
	    safely un-skinned at runtime.
]]

local ADDON_NAME, ns = ...
_G.ClassicUIRestoration = ns

ns.ADDON_NAME = ADDON_NAME
ns.TITLE = "Classic UI Restoration"
ns.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev" -- stamped into the .toc by build.ps1

-- Legacy textures that still ship with the retail client.
ns.T = {
	STATUS_BAR         = "Interface\\TargetingFrame\\UI-StatusBar",
	TARGET_FRAME       = "Interface\\TargetingFrame\\UI-TargetingFrame",
	TARGET_ELITE       = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite",
	TARGET_RARE        = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare",
	TARGET_RARE_ELITE  = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare-Elite",
	TARGET_MINUS       = "Interface\\TargetingFrame\\UI-TargetingFrame-Minus",
	TARGET_FLASH       = "Interface\\TargetingFrame\\UI-TargetingFrame-Flash",
	TARGET_MINUS_FLASH = "Interface\\TargetingFrame\\UI-TargetingFrame-Minus-Flash",
	LEVEL_BG           = "Interface\\TargetingFrame\\UI-TargetingFrame-LevelBackground",
	SKULL              = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
	TOT_FRAME          = "Interface\\TargetingFrame\\UI-TargetofTargetFrame",
	SMALL_FRAME        = "Interface\\TargetingFrame\\UI-SmallTargetingFrame",
	PARTY_FRAME        = "Interface\\TargetingFrame\\UI-PartyFrame",
	PARTY_FLASH        = "Interface\\TargetingFrame\\UI-PartyFrame-Flash",
	BOSS_FRAME         = "Interface\\TargetingFrame\\UI-UnitFrame-Boss",
	BOSS_FLASH         = "Interface\\TargetingFrame\\UI-UnitFrame-Boss-Flash",
	ATTACK_BG          = "Interface\\TargetingFrame\\UI-TargetingFrame-AttackBackground",
	QUEST_BADGE        = "Interface\\TargetingFrame\\PortraitQuestBadge",
	PET_ATTACK         = "Interface\\TargetingFrame\\UI-Player-AttackStatus",
	PORTRAIT_MASK      = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
	STATE_ICON         = "Interface\\CharacterFrame\\UI-StateIcon",
	PLAYER_STATUS      = "Interface\\CharacterFrame\\UI-Player-Status",
	GROUP_INDICATOR    = "Interface\\CharacterFrame\\UI-CharacterFrame-GroupIndicator",
	LEADER_ICON        = "Interface\\GroupFrame\\UI-Group-LeaderIcon",
	ROLE_ICONS         = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",
	LFG_EYE            = "Interface\\LFGFrame\\LFG-Eye",
	VEHICLE_FRAME      = "Interface\\Vehicles\\UI-Vehicle-Frame",
	VEHICLE_FLASH      = "Interface\\Vehicles\\UI-Vehicle-Frame-Flash",
	VEHICLE_PARTY      = "Interface\\Vehicles\\UI-Vehicles-PartyFrame",
	CAST_BORDER        = "Interface\\CastingBar\\UI-CastingBar-Border",
	CAST_BORDER_SMALL  = "Interface\\CastingBar\\UI-CastingBar-Border-Small",
	CAST_SHIELD_SMALL  = "Interface\\CastingBar\\UI-CastingBar-Small-Shield",
	CAST_SPARK         = "Interface\\CastingBar\\UI-CastingBar-Spark",
	CAST_FLASH         = "Interface\\CastingBar\\UI-CastingBar-Flash",
	CAST_FLASH_SMALL   = "Interface\\CastingBar\\UI-CastingBar-Flash-Small",
	RAID_HP_FILL       = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
	RAID_RES_FILL      = "Interface\\RaidFrame\\Raid-Bar-Resource-Fill",
	RAID_RES_BG        = "Interface\\RaidFrame\\Raid-Bar-Resource-Background",
	ABSORB_FILL        = "Interface\\RaidFrame\\Absorb-Fill",
	SHIELD_FILL        = "Interface\\RaidFrame\\Shield-Fill",
	MINIMAP_BORDER     = "Interface\\Minimap\\UI-Minimap-Border",
	MINIMAP_BACKGROUND = "Interface\\Minimap\\UI-Minimap-Background",
	MINIMAP_RING       = "Interface\\Minimap\\MiniMap-TrackingBorder",
	MINIMAP_NORTH_TAG  = "Interface\\Minimap\\CompassNorthTag",
	MINIMAP_COMPASS    = "Interface\\Minimap\\CompassRing",
	MINIMAP_TRACKING   = "Interface\\Minimap\\Tracking\\None",
	MINIMAP_ZOOM_IN    = "Interface\\Minimap\\UI-Minimap-ZoomInButton-",   -- + Up / Down / Disabled
	MINIMAP_ZOOM_OUT   = "Interface\\Minimap\\UI-Minimap-ZoomOutButton-",  -- + Up / Down / Disabled
	MINIMAP_HIGHLIGHT  = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
	MINIMAP_WORLD_MAP  = "Interface\\Minimap\\UI-Minimap-WorldMapSquare",
	CALENDAR_BUTTON    = "Interface\\Calendar\\UI-Calendar-Button",
	CLOCK_BACKGROUND   = "Interface\\TimeManager\\ClockBackground",
	MAIL_ICON          = "Interface\\Icons\\INV_Letter_15",
	MOUSE_HIGHLIGHT    = "Interface\\Buttons\\UI-Common-MouseHilight",
	LOOT_PANEL         = "Interface\\LootFrame\\UI-LootPanel",
	PANEL_CLOSE        = "Interface\\Buttons\\UI-Panel-MinimizeButton-", -- + Up / Down / Disabled / Highlight
	LOOT_NAME_FRAME    = "Interface\\QuestFrame\\UI-QuestItemNameFrame",
	LOOT_SKULL         = "Interface\\TargetingFrame\\TargetDead",
	LOOT_FISHING       = "Interface\\LootFrame\\FishingLoot-Icon",
	CHAT_SCROLL_UP     = "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-",   -- + Up / Down / Disabled
	CHAT_SCROLL_DOWN   = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-", -- + Up / Down / Disabled
	SCROLL_UP          = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-",   -- + Up / Down / Disabled
	SCROLL_DOWN        = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-", -- + Up / Down / Disabled
}

-- Classic colours.
ns.C = {
	HEALTH   = { 0, 1, 0 },
	BACKDROP = { 0, 0, 0, 0.5 },
}

---------------------------------------------------------------------------
-- Module registry
---------------------------------------------------------------------------

ns.modules = {}
ns.moduleByKey = {}
ns.appliedState = {} -- what each reload-module was applied with at login

-- A module with a `parent` key is a part of that module: it has no option of
-- its own and follows the parent's setting (e.g. the classic health/power bar
-- textures are part of the "Unit Frames" option).
function ns:RegisterModule(module)
	assert(module.key and module.name, "Module needs a key and a name")
	table.insert(self.modules, module)
	self.moduleByKey[module.key] = module
	return module
end

function ns:IsEnabled(key)
	local module = self.moduleByKey[key]
	if module and module.parent then
		return self:IsEnabled(module.parent)
	end
	return self.db ~= nil and self.db[key] == true
end

-- True if the reload-module's classic look is currently active on screen.
function ns:IsApplied(key)
	return self.appliedState[key] == true
end

-- True when any reload-required module's saved setting differs from what is
-- currently applied on screen.
function ns:NeedsReload()
	for _, module in ipairs(self.modules) do
		local applied = self.appliedState[module.key]
		if not module.live and not module.parent and applied ~= nil and applied ~= self.db[module.key] then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Run a function now, or after the current combat ends if it would touch
-- protected frames while in combat lockdown.
local pendingOutOfCombat = {}
function ns:RunOutOfCombat(fn)
	if InCombatLockdown() then
		table.insert(pendingOutOfCombat, fn)
	else
		fn()
	end
end

-- Safe hooksecurefunc wrappers; missing globals/methods are skipped so that a
-- future Blizzard rename does not break the whole addon.
--   ns.Hook("GlobalFunctionName", fn)
--   ns.Hook(frame, "MethodName", fn)
-- Each hook runs in its own protected call: hooks on the same function form a
-- chain, so an error in one would otherwise silently skip every hook installed
-- after it (by this addon or others). Errors still reach the error handler.
local function Protect(fn)
	return function(...)
		xpcall(fn, geterrorhandler(), ...)
	end
end

function ns.Hook(target, method, fn)
	if type(method) == "function" then
		fn = method
		if type(target) == "string" and type(_G[target]) == "function" then
			hooksecurefunc(target, Protect(fn))
			return true
		end
		return false
	end
	if type(target) == "table" and type(target[method]) == "function" then
		hooksecurefunc(target, method, Protect(fn))
		return true
	end
	return false
end

-- Clear anchors and set a single point.
--   ns.Point(region, "TOPLEFT", x, y)
--   ns.Point(region, "TOPLEFT", relativeTo, "BOTTOMLEFT", x, y)
function ns.Point(region, point, relativeTo, relativePoint, x, y)
	region:ClearAllPoints()
	if type(relativeTo) == "number" or relativeTo == nil then
		region:SetPoint(point, relativeTo or 0, relativePoint or 0)
	else
		region:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
	end
end

-- Apply a legacy file texture (with optional tex coords) to a texture region.
function ns.SetTexture(texture, path, left, right, top, bottom)
	texture:SetTexture(path)
	if left then
		texture:SetTexCoord(left, right, top, bottom)
	else
		texture:SetTexCoord(0, 1, 0, 1)
	end
end

-- Whether a texture file exists in this client. The legacy art is referenced
-- by path and not bundled, so pieces a client no longer ships need a fallback;
-- SetTexture reports whether the file was found.
local probe = UIParent:CreateTexture()
probe:Hide()
function ns.HasTexture(path)
	local found = probe:SetTexture(path)
	probe:SetTexture(nil)
	return found == true
end

-- Applies an atlas only if this client has it (SetAtlas errors on unknown
-- names). Returns true when it was applied.
function ns.SetAtlas(texture, name, useAtlasSize)
	if C_Texture.GetAtlasInfo(name) then
		texture:SetAtlas(name, useAtlasSize)
		return true
	end
	return false
end

-- Detach a MaskTexture from the given textures (and hide it) so that the
-- retail bar-shaped masks stop clipping the rectangular classic bars.
function ns.StripMask(mask, ...)
	if not mask then return end
	for i = 1, select("#", ...) do
		local texture = select(i, ...)
		if texture and texture.RemoveMaskTexture then
			pcall(texture.RemoveMaskTexture, texture, mask)
		end
	end
	mask:Hide()
end

-- Create the classic semi-transparent black backdrop that sits behind the
-- name/health/power area of a frame.
function ns.CreateBackdrop(parent, width, height, point, relativeTo, relativePoint, x, y)
	local backdrop = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
	backdrop:SetColorTexture(unpack(ns.C.BACKDROP))
	backdrop:SetSize(width, height)
	backdrop:SetPoint(point, relativeTo, relativePoint, x, y)
	return backdrop
end

function ns.Print(msg)
	print("|cff33ccff" .. ns.TITLE .. "|r: " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Mirror bars
--
-- Blizzard's unit frame status bars and their containers inherit
-- SecureFrameTemplate, so an addon cannot move or resize them while in
-- combat (the calls are blocked, and Blizzard's secure code restores the
-- retail geometry on every target change). The classic layout therefore
-- draws its bars on unprotected StatusBars that mirror the min/max/value of
-- Blizzard's bar (secret values may be passed through) and only fades
-- Blizzard's fill texture, which is always allowed.
---------------------------------------------------------------------------

ns.mirrors = setmetatable({}, { __mode = "k" }) -- Blizzard bar -> mirror

-- Sets a bar's fill texture. SetStatusBarTexture resets the fill's draw
-- layer, so for mirrors the BACKGROUND layer (behind the frame art) and full
-- alpha are re-applied afterwards.
function ns.SetBarTexture(bar, file)
	bar:SetStatusBarTexture(file)
	if bar.source then
		local fill = bar:GetStatusBarTexture()
		if fill then
			fill:SetAlpha(1)
			fill:SetDrawLayer("BACKGROUND", 0)
		end
	end
end

-- Copies the retail fill texture and colour from the source bar unless a
-- classic module has taken ownership of the mirror's appearance.
function ns.SyncMirrorAppearance(mirror)
	if mirror.classicOwned then return end
	local sourceFill = mirror.source:GetStatusBarTexture()
	local fill = mirror:GetStatusBarTexture()
	if sourceFill and fill then
		local atlas = sourceFill:GetAtlas()
		if atlas then
			fill:SetAtlas(atlas, false)
		else
			local texture = sourceFill:GetTexture()
			if texture then
				fill:SetTexture(texture)
			end
		end
		fill:SetAlpha(1)
		fill:SetDrawLayer("BACKGROUND", 0)
	end
	mirror:SetStatusBarColor(mirror.source:GetStatusBarColor())
end

-- Creates a mirror for a Blizzard status bar. The mirror is a child of the
-- source (so it shows/hides with it) but is given the unit frame's own frame
-- level so it draws behind the classic frame art.
function ns.CreateMirrorBar(source, level)
	local mirror = CreateFrame("StatusBar", nil, source)
	mirror:SetFrameLevel(level)
	mirror.source = source
	ns.SetBarTexture(mirror, ns.T.STATUS_BAR)
	mirror:SetMinMaxValues(source:GetMinMaxValues())
	mirror:SetValue(source:GetValue())
	ns.SyncMirrorAppearance(mirror)

	source:HookScript("OnValueChanged", function(_, value)
		mirror:SetValue(value)
	end)
	source:HookScript("OnMinMaxChanged", function(_, minValue, maxValue)
		mirror:SetMinMaxValues(minValue, maxValue)
	end)

	-- Blizzard's own fill (and spark) become invisible; everything else on
	-- the source bar (texts, overlays) keeps working.
	local fill = source:GetStatusBarTexture()
	if fill then fill:SetAlpha(0) end
	if source.Spark then source.Spark:SetAlpha(0) end

	ns.mirrors[source] = mirror
	return mirror
end

-- The bar that should carry classic textures/colours for a Blizzard bar.
function ns.GetBar(source)
	return ns.mirrors[source] or source
end

-- Moves an unprotected companion frame (loss bars, prediction segments,
-- feedback glows) onto a mirror so it is drawn with the classic bar.
function ns.AttachToMirror(companion, mirror, level)
	if not companion or not companion.SetParent then return end
	companion:SetParent(mirror)
	companion:ClearAllPoints()
	companion:SetAllPoints(mirror)
	if companion.SetFrameLevel then
		companion:SetFrameLevel(level)
	end
end

-- Heal prediction / absorb segments are anchored by Blizzard to the edge of
-- its own (now invisible) fill texture; re-anchor the first segment of each
-- chain to the mirror's fill. Offsets are kept at zero because the values
-- Blizzard uses may be secret and cannot be read by addon code.
local function RetargetSegment(segment, fill)
	if segment and segment.FillMask and segment:IsShown() then
		segment.FillMask:ClearAllPoints()
		segment.FillMask:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
		segment.FillMask:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
	end
end

local function RetargetHealPrediction(frame)
	local mirror = frame and frame.healthbar and ns.mirrors[frame.healthbar]
	if not mirror then return end
	local fill = mirror:GetStatusBarTexture()
	local mine, other, absorb, healAbsorb = frame.myHealPredictionBar, frame.otherHealPredictionBar, frame.totalAbsorbBar, frame.healAbsorbBar
	local mineShown = mine and mine:IsShown()
	local otherShown = other and other:IsShown()
	local healAbsorbShown = healAbsorb and healAbsorb:IsShown()
	if mineShown then
		RetargetSegment(mine, fill)
	end
	if otherShown and not mineShown then
		RetargetSegment(other, fill)
	end
	if absorb and absorb:IsShown() and not healAbsorbShown and not mineShown and not otherShown then
		RetargetSegment(absorb, fill)
	end
end

local function RetargetManaCostPrediction(frame)
	local mirror = frame and frame.manabar and ns.mirrors[frame.manabar]
	if mirror and frame.myManaCostPredictionBar then
		RetargetSegment(frame.myManaCostPredictionBar, mirror:GetStatusBarTexture())
	end
end

local function SyncMirrorOf(bar)
	local mirror = bar and ns.mirrors[bar]
	if mirror then
		ns.SyncMirrorAppearance(mirror)
	end
end

ns.Hook("UnitFrameHealthBar_Update", SyncMirrorOf)
ns.Hook("UnitFrameManaBar_UpdateType", SyncMirrorOf)
ns.Hook("UnitFrameHealPredictionBars_Update", RetargetHealPrediction)
ns.Hook("UnitFrameManaCostPredictionBars_Update", RetargetManaCostPrediction)

---------------------------------------------------------------------------
-- Saved variables & lifecycle
---------------------------------------------------------------------------

-- The options are account-wide (ClassicUIRestorationDB). The WoW Forever beta
-- client writes account-wide saved variables but does not load them back, so
-- the same table is also declared per character (ClassicUIRestorationCharDB):
-- both globals point at one table, the client serialises it into both files,
-- and at load the per-character copy is used whenever the account copy comes
-- back empty. On a working client the account copy wins.
local function InitializeDB()
	local account = ClassicUIRestorationDB
	local character = ClassicUIRestorationCharDB
	local db = account
	if type(db) ~= "table" or next(db) == nil then
		db = (type(character) == "table" and next(character) ~= nil) and character or {}
	end
	ClassicUIRestorationDB = db
	ClassicUIRestorationCharDB = db
	ns.db = db
	for _, module in ipairs(ns.modules) do
		if module.parent then
			ns.db[module.key] = nil -- follows the parent's setting
		elseif ns.db[module.key] == nil then
			ns.db[module.key] = true
		end
	end
end

local function SafeCall(module, methodName)
	local fn = module[methodName]
	if type(fn) ~= "function" then return end
	xpcall(fn, geterrorhandler(), module)
end

local function ActivateModules()
	for _, module in ipairs(ns.modules) do
		local enabled = ns:IsEnabled(module.key)
		if module.live then
			if enabled then
				SafeCall(module, "Enable")
			end
		else
			if not module.parent then
				ns.appliedState[module.key] = enabled
			end
			if enabled then
				SafeCall(module, "Apply")
			end
		end
	end
	ns.activated = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			InitializeDB()
			if ns.BuildOptions then
				xpcall(ns.BuildOptions, geterrorhandler(), ns)
			end
			self:UnregisterEvent("ADDON_LOADED")
		end
	elseif event == "PLAYER_LOGIN" then
		ActivateModules()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if #pendingOutOfCombat > 0 then
			local queue = pendingOutOfCombat
			pendingOutOfCombat = {}
			for _, fn in ipairs(queue) do
				xpcall(fn, geterrorhandler())
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Temporary diagnostics ("/cuir debug"): dumps the target frame's health bar
-- geometry. Will be removed once the bar overflow issue is resolved.
---------------------------------------------------------------------------

local function Geo(region)
	local ok, text = pcall(function()
		local w, h = region:GetSize()
		local l, b, rw, rh = region:GetRect()
		local n = region:GetNumPoints()
		local points = {}
		for i = 1, n do
			local point, rel, relPoint, x, y = region:GetPoint(i)
			table.insert(points, string.format("%s->%s.%s(%.0f,%.0f)", point, rel and (rel.GetName and rel:GetName() or "?") or "nil", relPoint or "", x or 0, y or 0))
		end
		return string.format("size=%.1fx%.1f rect=%s,%s %sx%s points=[%s]", w or 0, h or 0, tostring(l and math.floor(l)), tostring(b and math.floor(b)), tostring(rw and math.floor(rw)), tostring(rh and math.floor(rh)), table.concat(points, " "))
	end)
	return ok and text or ("(restricted: " .. tostring(text) .. ")")
end

local function Desc(region, label)
	if not region then print(label .. " = nil") return end
	local ok, text = pcall(function()
		local parts = {}
		table.insert(parts, "shown=" .. tostring(region:IsShown()) .. " visible=" .. tostring(region:IsVisible()))
		table.insert(parts, string.format("alpha=%.2f eff=%.2f", region:GetAlpha() or -1, region.GetEffectiveAlpha and region:GetEffectiveAlpha() or -1))
		if region.GetFrameLevel then
			table.insert(parts, "strata=" .. tostring(region:GetFrameStrata()) .. " level=" .. tostring(region:GetFrameLevel()))
		end
		if region.GetDrawLayer then
			local layer, sub = region:GetDrawLayer()
			table.insert(parts, "layer=" .. tostring(layer) .. "/" .. tostring(sub))
		end
		if region.GetMinMaxValues then
			local mn, mx = region:GetMinMaxValues()
			table.insert(parts, string.format("min=%s max=%s value=%s", tostring(mn), tostring(mx), tostring(region:GetValue())))
			local r, g, b, a = region:GetStatusBarColor()
			table.insert(parts, string.format("color=%.2f,%.2f,%.2f,%.2f", r or -1, g or -1, b or -1, a or -1))
			local fill = region:GetStatusBarTexture()
			if fill then
				table.insert(parts, "tex=" .. tostring(fill:GetAtlas() or fill:GetTexture()) .. " fillshown=" .. tostring(fill:IsShown()) .. string.format(" fillalpha=%.2f", fill:GetAlpha()))
				local l, sub = fill:GetDrawLayer()
				table.insert(parts, "filllayer=" .. tostring(l) .. "/" .. tostring(sub) .. " " .. Geo(fill))
			end
		elseif region.GetTexture then
			table.insert(parts, "tex=" .. tostring(region:GetAtlas() or region:GetTexture()))
		end
		table.insert(parts, "parent=" .. tostring(region:GetParent() and (region:GetParent():GetName() or "(anon)")))
		return table.concat(parts, " ")
	end)
	print(label .. " " .. (ok and text or ("(restricted: " .. tostring(text) .. ")")) .. " " .. Geo(region))
end

local function DebugMirror(label, source)
	local mirror = source and ns.mirrors[source]
	Desc(source, label .. " source")
	Desc(mirror, label .. " mirror")
	if mirror then
		print(label .. " mirror classicOwned=" .. tostring(mirror.classicOwned))
		for i, child in ipairs({ mirror:GetChildren() }) do
			Desc(child, label .. " child" .. i .. " " .. tostring(child:GetName() or child.fillAtlas or child.fillTexture or "?"))
			if child.Fill then Desc(child.Fill, label .. " child" .. i .. ".Fill") end
			if child.FillMask then Desc(child.FillMask, label .. " child" .. i .. ".FillMask") end
		end
		for i, region in ipairs({ mirror:GetRegions() }) do
			Desc(region, label .. " region" .. i)
		end
	end
end

function ns:DebugTarget()
	local frame = TargetFrame
	local main = frame.TargetFrameContent.TargetFrameContentMain
	local hbc = main.HealthBarsContainer
	print("modules: healthbars=" .. tostring(ns:IsEnabled("healthbars")) .. " powerbars=" .. tostring(ns:IsEnabled("powerbars")) .. " unitframes=" .. tostring(ns:IsEnabled("unitframes")))
	print("== TargetFrame " .. Geo(frame) .. " level=" .. tostring(frame:GetFrameLevel()) .. " strata=" .. tostring(frame:GetFrameStrata()))
	print("HealthBarsContainer " .. Geo(hbc) .. " level=" .. tostring(hbc:GetFrameLevel()))
	DebugMirror("T.Health", hbc.HealthBar)
	DebugMirror("T.Mana", main.ManaBar)
	Desc(frame.CUIR_Backdrop, "T.Backdrop")

	local pmain = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
	print("== PlayerFrame " .. Geo(PlayerFrame) .. " level=" .. tostring(PlayerFrame:GetFrameLevel()) .. " strata=" .. tostring(PlayerFrame:GetFrameStrata()))
	DebugMirror("P.Health", pmain.HealthBarsContainer.HealthBar)
	DebugMirror("P.Mana", pmain.ManaBarArea.ManaBar)
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

SLASH_CLASSICUIRESTORATION1 = "/cuir"
SLASH_CLASSICUIRESTORATION2 = "/classicui"
SlashCmdList.CLASSICUIRESTORATION = function(msg)
	msg = strtrim((msg or ""):lower())
	if msg == "reload" or msg == "rl" then
		ReloadUI()
		return
	elseif msg == "debug" then
		xpcall(ns.DebugTarget, geterrorhandler(), ns)
		return
	elseif msg == "loot" and ns.DebugLoot then
		xpcall(ns.DebugLoot, geterrorhandler(), ns)
		return
	end
	if ns.OpenOptions then
		ns:OpenOptions()
	end
end
