--[[
	Classic UI Restoration - Options

	Registers the addon's page in the game's Settings > AddOns panel. Each
	module gets a checkbox; live modules (cast bars, nameplates) toggle at once,
	the others prompt for a UI reload.

	Slash commands: /cuir, /classicui  (and "/cuir reload").
]]

local _, ns = ...

local RELOAD_POPUP = "CLASSICUIRESTORATION_RELOAD"

StaticPopupDialogs[RELOAD_POPUP] = {
	text = ns.TITLE .. "\n\nThis change takes effect after the interface is reloaded.\nReload now?",
	button1 = RELOADUI or "Reload UI",
	button2 = CANCEL or "Cancel",
	OnAccept = function() ReloadUI() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function CreateModuleSetting(category, module)
	local variable = "CUIR_" .. module.key

	local function GetValue()
		return ns.db[module.key] == true
	end

	local function SetValue(value)
		value = (value == true)
		if ns.db[module.key] == value then
			return
		end
		ns.db[module.key] = value

		if not ns.activated then
			return
		end

		if module.live then
			if value then
				if module.Enable then xpcall(module.Enable, geterrorhandler(), module) end
			else
				if module.Disable then xpcall(module.Disable, geterrorhandler(), module) end
			end
		elseif ns:NeedsReload() then
			StaticPopup_Show(RELOAD_POPUP)
		else
			-- Toggled back to what is already on screen; nothing pending.
			StaticPopup_Hide(RELOAD_POPUP)
		end
	end

	local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Boolean, module.name, true, GetValue, SetValue)

	local tooltip = module.tooltip or ""
	if module.live then
		tooltip = tooltip .. "\n\n|cff33ff99Takes effect immediately.|r"
	else
		tooltip = tooltip .. "\n\n|cffffd200Requires a UI reload to take effect.|r"
	end
	Settings.CreateCheckbox(category, setting, tooltip)
end

function ns:BuildOptions()
	local category, layout = Settings.RegisterVerticalLayoutCategory(ns.TITLE)
	ns.settingsCategory = category

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
		"Classic elements",
		"Enable an option to restore the classic (pre-Dragonflight) look of that element, or disable it to keep the retail look."))

	for _, module in ipairs(ns.modules) do
		if not module.parent then
			CreateModuleSetting(category, module)
		end
	end

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(
		"Apply changes",
		"Unit Frames, the Minimap and the Loot Window are applied when the interface loads; reload after changing those options."))

	layout:AddInitializer(CreateSettingsButtonInitializer(
		"Reload the interface",
		RELOADUI or "Reload UI",
		function() ReloadUI() end,
		"Reloads the interface so that pending unit frame, minimap and loot window changes take effect.",
		true))

	Settings.RegisterAddOnCategory(category)
end

function ns:OpenOptions()
	if ns.settingsCategory then
		Settings.OpenToCategory(ns.settingsCategory:GetID())
	end
end
