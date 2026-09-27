--[[
	Forevermore Classic UI - Options

	The addon's page in the game's Settings > AddOns panel, a canvas of the
	addon's own (Settings.RegisterCanvasLayoutCategory): a header with the
	Setup Wizard and All Classic / All Modern buttons, a reload banner shown
	while a reload-type option differs from what is on screen, and every
	top-level option in its group (ns.UI.GetGroups, shared with the wizard),
	each with a picture of the look it is set to, a short description (the full
	one in its tooltip) and a Modern / Classic switch. Live modules switch at
	once, the others after the reload the banner offers.

	The page is built the first time the settings panel shows it (the
	pictures use the player's portrait, bars and gear). The panel's Defaults
	button sets every option back to classic, the addon's defaults.

	Slash commands: /fmcui, /forevermore, /cuir, /classicui (and "/fmcui
	setup" for the setup wizard, "/fmcui reload").
]]

local _, ns = ...
local UI = ns.UI

local THUMB_WIDTH, THUMB_HEIGHT = 128, 64
local ROW_HEIGHT = 76
local SECTION_HEIGHT = 48
local HEADER_HEIGHT = 78
local BANNER_HEIGHT = 38

local panel = CreateFrame("Frame")
panel:Hide() -- the settings panel shows it (OnShow builds it)
local built = false
local switches = {} -- module key -> its Modern / Classic switch
local thumbnails = {} -- module key -> { modern = picture, classic = picture }
local banner, scroll

local function Refresh()
	if not built then return end
	for key, switch in pairs(switches) do
		local classic = ns:IsEnabled(key)
		switch:SetValue(classic)
		for look, canvas in pairs(thumbnails[key] or {}) do
			canvas:SetShown((look == "classic") == classic)
		end
	end
	local reload = ns:NeedsReload()
	banner:SetShown(reload)
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(HEADER_HEIGHT + (reload and BANNER_HEIGHT + 4 or 0)))
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------

local function CreateHeader()
	local icon = panel:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(UI.ICON)
	icon:SetSize(52, 52)
	icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -4)
	title:SetText(ns.TITLE)
	local version = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
	version:SetText("v" .. ns.VERSION)

	local wizardButton = UI.CreateButton(panel, "Setup Wizard", 204, 22, function()
		ns:OpenSetup()
	end)
	wizardButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)
	-- In the rows' switch order: Modern on the left, Classic on the right.
	local allClassic = UI.CreateButton(panel, "All Classic", 100, 22, function()
		UI.SetAll(true)
	end)
	allClassic:SetPoint("TOPRIGHT", wizardButton, "BOTTOMRIGHT", 0, -4)
	local allModern = UI.CreateButton(panel, "All Modern", 100, 22, function()
		UI.SetAll(false)
	end)
	allModern:SetPoint("RIGHT", allClassic, "LEFT", -4, 0)

	local tagline = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	tagline:SetPoint("RIGHT", allModern, "LEFT", -12, 0)
	tagline:SetJustifyH("LEFT")
	tagline:SetText("The classic look on Blizzard's own frames. Pick Modern or Classic for each element; hover one for the details.")

	local line = panel:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.82, 0, 0.25)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -(HEADER_HEIGHT - 4))
	line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -(HEADER_HEIGHT - 4))
end

local function CreateBanner()
	banner = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	banner:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -HEADER_HEIGHT)
	banner:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -HEADER_HEIGHT)
	banner:SetHeight(BANNER_HEIGHT)
	banner:SetBackdrop(UI.CARD_BACKDROP)
	banner:SetBackdropColor(0.3, 0.2, 0.02, 0.9)
	banner:SetBackdropBorderColor(1, 0.82, 0)
	local reload = UI.CreateButton(banner, RELOADUI or "Reload UI", 120, 24, function() ReloadUI() end)
	reload:SetPoint("RIGHT", banner, "RIGHT", -8, 0)
	local text = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("LEFT", banner, "LEFT", 12, 0)
	text:SetPoint("RIGHT", reload, "LEFT", -10, 0)
	text:SetJustifyH("LEFT")
	text:SetText("Some changes take effect after the interface is reloaded.")
	banner:Hide()
end

local function CreateThumbnail(parent, key)
	local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	frame:SetSize(THUMB_WIDTH, THUMB_HEIGHT)
	frame:SetBackdrop(UI.CARD_BACKDROP)
	frame:SetBackdropColor(0, 0, 0, 0.8)
	frame:SetBackdropBorderColor(0.45, 0.45, 0.45)
	local area = CreateFrame("Frame", nil, frame)
	area:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
	area:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
	area:SetClipsChildren(true)
	-- Both looks; Refresh shows the one the option is set to.
	local looks = {}
	for _, look in ipairs({ "modern", "classic" }) do
		local canvas = ns.CreatePreview(area, key, look)
		if canvas then
			ns.FitPreview(canvas, THUMB_WIDTH - 8, THUMB_HEIGHT - 8)
			looks[look] = canvas
		end
	end
	thumbnails[key] = looks
	return frame
end

local function CreateSection(parent, group, y)
	local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y - 10)
	title:SetText(group.title)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.82, 0, 0.25)
	line:SetHeight(1)
	line:SetPoint("LEFT", title, "RIGHT", 10, 0)
	line:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	text:SetText(group.text)
end

local function CreateRow(parent, module, y, stripe)
	local row = CreateFrame("Frame", nil, parent)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, y)
	row:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
	row:SetHeight(ROW_HEIGHT - 6)
	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self) UI.ShowModuleTooltip(self, module) end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	if stripe then
		local background = row:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints(row)
		background:SetColorTexture(1, 1, 1, 0.03)
	end

	local thumbnail = CreateThumbnail(row, module.key)
	thumbnail:SetPoint("LEFT", row, "LEFT", 4, 0)

	local switch = UI.CreateSwitch(row, function(classic)
		ns:SetModuleEnabled(module.key, classic)
	end)
	switch:SetPoint("RIGHT", row, "RIGHT", -6, 7)
	local note = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	note:SetPoint("TOP", switch, "BOTTOM", 0, -4)
	note:SetText(module.live and "|cff33ff99Applies at once|r" or "|cffffd200Needs a reload|r")
	switches[module.key] = switch

	local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("TOPLEFT", thumbnail, "TOPRIGHT", 12, -6)
	name:SetText(module.name)
	local summary = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -5)
	summary:SetPoint("RIGHT", switch, "LEFT", -14, 0)
	summary:SetJustifyH("LEFT")
	summary:SetJustifyV("TOP")
	summary:SetMaxLines(3)
	summary:SetText(UI.GetSummary(module))
end

local function CreateList()
	scroll = CreateFrame("ScrollFrame", nil, panel)
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -HEADER_HEIGHT)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 4)
	local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, -4)
	scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 4)
	ScrollUtil.InitScrollFrameWithScrollBar(scroll, scrollBar)
	ns.SkinScrollBar(scrollBar)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetWidth(math.max(scroll:GetWidth(), 560))
	scroll:SetScrollChild(list)
	scroll:SetScript("OnSizeChanged", function(_, width)
		if width and width > 0 then list:SetWidth(width) end
	end)

	local y = 0
	for _, group in ipairs(UI.GetGroups()) do
		CreateSection(list, group, y)
		y = y - SECTION_HEIGHT
		for i, module in ipairs(group.modules) do
			CreateRow(list, module, y, i % 2 == 1)
			y = y - ROW_HEIGHT
		end
	end
	list:SetHeight(-y + 8)
end

local function Build()
	built = true
	CreateHeader()
	CreateBanner()
	CreateList()
end

-- Settings panel hooks (see Blizzard_ImplementationReadme.lua).
function panel:OnRefresh()
	Refresh()
end

function panel:OnDefault()
	UI.SetAll(true)
end

panel:SetScript("OnShow", function()
	if not built then
		xpcall(Build, geterrorhandler())
	end
	Refresh()
end)

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

function ns:BuildOptions()
	local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
	ns.settingsCategory = category
	Settings.RegisterAddOnCategory(category)
	ns:OnSettingsChanged(Refresh)
end

function ns:OpenOptions()
	if ns.settingsCategory then
		Settings.OpenToCategory(ns.settingsCategory:GetID())
	end
end
