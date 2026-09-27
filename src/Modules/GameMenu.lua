--[[
	Forevermore Classic UI - Game Menu

	Restores the vanilla game menu (the Esc menu, 1.12 GameMenuFrame.xml):
	the 195px wide dialog box (UI-DialogBox-Border with the see-through
	UI-DialogBox-Background), the UI-DialogBox-Header plate with "Main Menu"
	in the small gold font, and the small red panel buttons (144x21
	UI-Panel-Button-* with white text) stacked 1px apart, with a 16px gap
	between the groups.

	Retail's GameMenuFrame (Blizzard_GameMenu, MainMenuFrameTemplate) is a
	VerticalLayoutFrame that rebuilds its buttons from a frame pool on every
	show (InitButtons -> Reset / AddButton / AddSection): 200x36 big red
	three-slice buttons, a DiamondMetal dialog border and header. Those
	buttons call protected functions (Logout, Quit), so the menu is only
	re-skinned from the outside with widget calls, never by writing its
	fields or its layout keys (paddings, spacing):

	  * the metal border is faded and the vanilla dialog box is drawn on a
	    backdrop frame behind the menu; the header's metal plate is faded and
	    the vanilla plate drawn under its text,
	  * each pooled button gets the vanilla panel button textures and fonts
	    as its state textures (the three-slice pieces Blizzard re-atlases on
	    every state change are only faded, so they can keep doing that),
	  * the frame's Layout is hooked: after Blizzard has stacked the buttons,
	    they are resized and re-stacked the vanilla way (Blizzard's section
	    gaps, read from its layout children, become the vanilla 16px gaps)
	    and the frame is sized around them.

	Applied once at login (reload to switch off).
]]

local _, ns = ...
local T = ns.T

-- Also used by CharacterFrame.lua (loaded later).
T.DIALOG_BACKGROUND  = "Interface\\DialogFrame\\UI-DialogBox-Background"
T.DIALOG_BORDER      = "Interface\\DialogFrame\\UI-DialogBox-Border"
T.DIALOG_HEADER      = "Interface\\DialogFrame\\UI-DialogBox-Header"
T.PANEL_BUTTON       = "Interface\\Buttons\\UI-Panel-Button-" -- + Up / Down / Disabled / Highlight

local module = ns:RegisterModule({
	key = "gamemenu",
	name = "Game Menu",
	tooltip = "Restores the vanilla game menu (Esc): the classic dialog box with the Main Menu header plate and the small red classic buttons.",
	live = false,
})

-- Vanilla geometry (GameMenuFrame.xml / GameMenuButtonTemplate). The first
-- button is centred 42px below the top edge; the others hang 1px below the
-- previous one, 16px below it at a group break.
local WIDTH = 195
local BUTTON_WIDTH, BUTTON_HEIGHT = 144, 21
local FIRST_BUTTON_TOP = 42 - BUTTON_HEIGHT / 2
local BUTTON_GAP, SECTION_GAP = 1, 16
local BOTTOM_PADDING = 16
-- The UI-Panel-Button-* files are 128x32 with the 80x22 button in the corner.
local BUTTON_RIGHT, BUTTON_BOTTOM = 0.625, 0.6875
-- UI-DialogBox-Header is 256x64, drawn 12px above the frame's top edge.
local HEADER_SIZE_X, HEADER_SIZE_Y, HEADER_Y = 256, 64, 12

local skinned = setmetatable({}, { __mode = "k" }) -- pooled buttons already re-skinned
local backdrop
local pushedTextX, pushedTextY

---------------------------------------------------------------------------
-- Frame art
---------------------------------------------------------------------------

local function ApplyFrameArt(frame)
	if frame.Border then frame.Border:SetAlpha(0) end

	-- At the menu's own level, behind its buttons and header (its children).
	backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	backdrop:SetAllPoints(frame)
	backdrop:SetFrameLevel(frame:GetFrameLevel())
	backdrop:SetBackdrop({
		bgFile = T.DIALOG_BACKGROUND,
		edgeFile = T.DIALOG_BORDER,
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})

	-- The plate goes on the backdrop so that the buttons draw over its
	-- (transparent) lower half, as they did over vanilla's frame art; the
	-- header's text stays Blizzard's, above it.
	local plate = backdrop:CreateTexture(nil, "ARTWORK")
	plate:SetTexture(T.DIALOG_HEADER)
	plate:SetSize(HEADER_SIZE_X, HEADER_SIZE_Y)
	plate:SetPoint("TOP", frame, "TOP", 0, HEADER_Y)

	local header = frame.Header
	if header then
		for _, key in ipairs({ "LeftBG", "CenterBG", "RightBG" }) do
			if header[key] then header[key]:SetAlpha(0) end
		end
		if header.Text then
			header.Text:SetFontObject(GameFontNormal)
		end
	end
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

local function SetButtonTexture(button, setter, getter, file, blendMode)
	button[setter](button, file, blendMode)
	local texture = button[getter](button)
	if texture then
		texture:SetTexCoord(0, BUTTON_RIGHT, 0, BUTTON_BOTTOM)
	end
end

local function SkinButton(button)
	if not skinned[button] then
		skinned[button] = true
		-- ThreeSliceButtonMixin re-atlases these on every state change;
		-- alpha survives that.
		for _, key in ipairs({ "Left", "Center", "Right" }) do
			if button[key] then button[key]:SetAlpha(0) end
		end
		SetButtonTexture(button, "SetNormalTexture", "GetNormalTexture", T.PANEL_BUTTON .. "Up")
		SetButtonTexture(button, "SetPushedTexture", "GetPushedTexture", T.PANEL_BUTTON .. "Down")
		SetButtonTexture(button, "SetDisabledTexture", "GetDisabledTexture", T.PANEL_BUTTON .. "Disabled")
		button:SetNormalFontObject(GameFontHighlight)
		button:SetHighlightFontObject(GameFontHighlight)
		button:SetDisabledFontObject(GameFontDisable)
		button:SetPushedTextOffset(pushedTextX, pushedTextY)
	end
	-- The three-slice template sets its highlight atlas when it initializes
	-- a button, so this is re-applied on every layout.
	SetButtonTexture(button, "SetHighlightTexture", "GetHighlightTexture", T.PANEL_BUTTON .. "Highlight", "ADD")
	button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
end

-- After LayoutMixin:Layout (on show, and on the next frame after every
-- rebuild): the vanilla stack. Blizzard's section breaks are the buttons'
-- topPadding (AddSection), which is only read here.
local function LayoutMenu(frame)
	local y = FIRST_BUTTON_TOP
	local first = true
	for _, button in ipairs(frame:GetLayoutChildren()) do
		if button:IsObjectType("Button") then
			SkinButton(button)
			if first then
				first = false
			else
				local padding = button.topPadding
				y = y + ((padding and padding > 0) and SECTION_GAP or BUTTON_GAP)
			end
			button:ClearAllPoints()
			button:SetPoint("TOP", frame, "TOP", 0, -y)
			y = y + BUTTON_HEIGHT
		end
	end
	frame:SetSize(WIDTH, y + BOTTOM_PADDING)
	-- The menu is a toplevel frame; keep the backdrop at its level when it
	-- is raised.
	backdrop:SetFrameLevel(frame:GetFrameLevel())
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local function Skin()
	local frame = GameMenuFrame
	if not frame or not frame.Layout or not frame.GetLayoutChildren then return end

	if not ns.HasTexture(T.PANEL_BUTTON .. "Up") or not ns.HasTexture(T.DIALOG_BORDER) then
		ns.Print("This client does not ship the classic dialog box and panel buttons; the game menu keeps the retail look.")
		return
	end

	-- The engine's default pushed-text offset (a plain button's): vanilla's
	-- panel buttons did not set their own.
	pushedTextX, pushedTextY = CreateFrame("Button"):GetPushedTextOffset()

	ApplyFrameArt(frame)
	ns.Hook(frame, "Layout", LayoutMenu)

	if frame:IsShown() then
		LayoutMenu(frame)
	end
end

-- Blizzard_GameMenu loads with the interface; wait for it just in case.
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, _, addon)
	if addon == "Blizzard_GameMenu" then
		self:UnregisterEvent("ADDON_LOADED")
		xpcall(Skin, geterrorhandler())
	end
end)

function module:Apply()
	if GameMenuFrame then
		Skin()
	else
		eventFrame:RegisterEvent("ADDON_LOADED")
	end
end
