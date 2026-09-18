--[[
	Classic UI Restoration - Trainer Window

	Restores the vanilla class / profession trainer window (1.12
	Blizzard_TrainerUI.xml): the 384x512 panel assembled from the four
	Interface\ClassTrainerFrame\UI-ClassTrainer-* pieces with the trainer's
	portrait in its ring, the trainer's greeting under the name, a compact
	list of 16px skill rows coloured by state (green available, red
	unavailable, grey already known) with the selected row on a tinted
	highlight bar, a detail pane under the list with the selected skill's
	icon, name, requirements, cost and description, the Train / Exit buttons
	and the player's money at the bottom, the filter in the classic dropdown
	box and the classic knob scroll bars.

	Retail's ClassTrainerFrame (Blizzard_TrainerUI, load-on-demand) is a
	ButtonFrameTemplate whose ScrollBox lists 47px card rows
	(ClassTrainerSkillButtonTemplate: icon, name, requirements, price) with a
	tooltip on hover and no detail pane; a filter dropdown and, for
	professions, a skill rank bar sit in its header. The frame is re-skinned
	in place so that Blizzard's selection, training, filters, tooltips and
	the profession "next rank" step button keep working:

	  * the panel's NineSlice, backgrounds and insets are hidden and the
	    vanilla art is drawn on the frame; the title, portrait, close button,
	    Train button, money frame, filter dropdown and rank bar are moved to
	    their vanilla spots (the portrait container is dropped to the LOW
	    strata so the portrait shows through the ring's hole like vanilla),
	  * the rows keep Blizzard's name text (re-anchored and coloured by
	    service type) and get the vanilla highlight bar; their icon, price,
	    requirement text and card textures are faded out. The list view's
	    element extent is set to 16 so the rows stack like the vanilla list,
	    and the MinimalScrollBar is re-skinned into the classic knob bar,
	  * ClassTrainerFrame_Update (which re-anchors the ScrollBox every time)
	    and ClassTrainer_SetSelection are hooked to lay the list out and to
	    fill the addon's own detail pane. The description comes from the
	    service's tooltip data (C_TooltipInfo.GetTrainerService) when the
	    vanilla GetTrainerServiceDescription is not available.

	Two client layouts are handled (structural, not by flavor): on retail
	the ScrollBox is a linear list that also contains the profession step
	service, so the pinned step button is hidden; on WoW Forever the list is
	a tree with collapsible category headers (re-skinned into the vanilla
	+/- header rows) and the step service is only on the pinned button,
	which becomes the list's first row.

	Everything touched is widget state; no Lua field is written on
	Blizzard's frames. Applied once at login (reload to switch off).
]]

local _, ns = ...
local T = ns.T
local Point, SetTexture = ns.Point, ns.SetTexture

T.TRAINER_ART        = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-" -- + TopLeft / TopRight / BotLeft / BotRight / HorizontalBar / ScrollBar
T.TRADESKILL_ART     = "Interface\\TradeSkillFrame\\UI-TradeSkill-"     -- same pieces (the classic trade skill panel), fallback
T.LISTBOX_HIGHLIGHT  = "Interface\\Buttons\\UI-Listbox-Highlight2"
T.LISTBOX_HIGHLIGHT1 = "Interface\\Buttons\\UI-Listbox-Highlight"
T.PLUS_BUTTON        = "Interface\\Buttons\\UI-PlusButton-Up"
T.MINUS_BUTTON       = "Interface\\Buttons\\UI-MinusButton-Up"
T.PLUS_HILIGHT       = "Interface\\Buttons\\UI-PlusButton-Hilight"
T.EMPTY_SLOT         = "Interface\\Buttons\\UI-EmptySlot"
T.SCROLL_KNOB        = "Interface\\Buttons\\UI-ScrollBar-Knob"
T.DROPDOWN_BOX       = "Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame"

local module = ns:RegisterModule({
	key = "trainer",
	name = "Trainer Window",
	tooltip = "Restores the vanilla class / profession trainer window: the classic panel with the trainer's greeting, the compact colour-coded skill list, the selected skill's details below it and the Train / Exit buttons.",
	live = false,
})

-- Vanilla geometry (1.12 Blizzard_TrainerUI.xml). The frame is 384x512 with
-- transparent art in its right 34px and bottom 75px.
local FRAME_WIDTH, FRAME_HEIGHT = 384, 512
local ROW_HEIGHT = 16
local LIST_LEFT, LIST_TOP, LIST_WIDTH = 21, -96, 296 -- ClassTrainerListScrollFrame
local ROW_LEFT, ROW_WIDTH = 22, 294                   -- the rows sit 1px in and 4px down from it
local LIST_HEIGHT_CLASS, LIST_HEIGHT_TRADE = 184, 168 -- 11 / 10 rows
local DETAIL_HEIGHT_CLASS, DETAIL_HEIGHT_TRADE = 119, 135
local SKILL_TEXT_WIDTH = 262                          -- vanilla: 270, minus the tree indent on Forever
local DROPDOWN_WIDTH = 130                            -- UIDropDownMenu_SetWidth(130); the box adds 25px each side

-- 1.12 colours: GameFontNormalLeftGreen / GameFontNormalLeftRed /
-- GameFontDisable for the names, ClassTrainer_SetSubTextColor for the
-- "(Rank n)" text and the ClassTrainerSkillHighlight vertex colour.
local TYPE_COLORS = {
	available   = { text = { 0.1, 1, 0.1 },     sub = { 0, 0.6, 0 },       bar = { 0, 1, 0 } },
	unavailable = { text = { 1, 0.1, 0.1 },     sub = { 0.6, 0, 0 },       bar = { 0.9, 0, 0 } },
	used        = { text = { 0.5, 0.5, 0.5 },   sub = { 0.5, 0.5, 0.5 },   bar = { 0.5, 0.5, 0.5 } },
}

local art = {}                                       -- regions/frames created by this module
local rows = setmetatable({}, { __mode = "k" })      -- skill row -> { bar = highlight texture }
local headers = setmetatable({}, { __mode = "k" })   -- category row -> { icon = +/- texture }
local artPrefix                                      -- T.TRAINER_ART or T.TRADESKILL_ART, whichever this client ships
local highlightFile

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- The list's element data is a plain table on retail and a tree node (whose
-- .data holds that table) on Forever.
local function SkillIndexOf(elementData)
	local data = elementData and (elementData.data or elementData)
	return type(data) == "table" and data.skillIndex or nil
end

-- The profession "next rank" service (GetTrainerServiceStepIndex) is shown
-- on Blizzard's pinned skillStepButton. Retail lists it as well, so the pin
-- is redundant there; Forever leaves it out of the list, so the pin becomes
-- the list's first row.
local function IsStepPinned()
	local step = GetTrainerServiceStepIndex()
	if not step then return false end
	local scrollBox = ClassTrainerFrame.ScrollBox
	if not scrollBox:HasDataProvider() then return true end
	local function IsStep(elementData)
		return SkillIndexOf(elementData) == step
	end
	if scrollBox.ContainsElementDataByPredicate then
		return not scrollBox:ContainsElementDataByPredicate(IsStep)
	end
	return scrollBox:FindElementDataByPredicate(IsStep) == nil
end

local function IsPetTrainer()
	return C_Trainer ~= nil and C_Trainer.GetTrainerType ~= nil and Enum.TrainerType ~= nil
		and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet
end

local function ResolveArtPrefix()
	for _, prefix in ipairs({ T.TRAINER_ART, T.TRADESKILL_ART }) do
		if ns.HasTexture(prefix .. "TopLeft") and ns.HasTexture(prefix .. "BotRight") then
			return prefix
		end
	end
end

---------------------------------------------------------------------------
-- Frame art
---------------------------------------------------------------------------

local function ApplyFrameArt(frame)
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	frame:SetHitRectInsets(0, 34, 0, 75)

	if frame.NineSlice then frame.NineSlice:Hide() end
	if frame.Bg then frame.Bg:Hide() end
	if frame.TopTileStreaks then frame.TopTileStreaks:Hide() end
	if frame.BG then frame.BG:Hide() end -- the TrainerTextures list background
	-- Blizzard's Update re-anchors the inset and shows the bottom one; alpha survives that.
	if frame.Inset then frame.Inset:SetAlpha(0) end
	if frame.bottomInset then frame.bottomInset:SetAlpha(0) end
	if ClassTrainerFrameMoneyBg then ClassTrainerFrameMoneyBg:Hide() end

	local function Piece(name, width, height, point)
		local texture = frame:CreateTexture(nil, "BORDER")
		texture:SetTexture(artPrefix .. name)
		texture:SetSize(width, height)
		texture:SetPoint(point, frame, point, 0, 0)
		return texture
	end
	art.topLeft = Piece("TopLeft", 256, 256, "TOPLEFT")
	art.topRight = Piece("TopRight", 128, 256, "TOPRIGHT")
	art.bottomLeft = Piece("BotLeft", 256, 256, "BOTTOMLEFT")
	art.bottomRight = Piece("BotRight", 128, 256, "BOTTOMRIGHT")

	-- The bar between the list and the detail pane; anchored in LayoutFrame.
	if ns.HasTexture(artPrefix .. "HorizontalBar") then
		art.barLeft = frame:CreateTexture(nil, "ARTWORK")
		SetTexture(art.barLeft, artPrefix .. "HorizontalBar", 0, 1, 0, 0.25)
		art.barLeft:SetSize(256, 16)
		art.barRight = frame:CreateTexture(nil, "ARTWORK")
		SetTexture(art.barRight, artPrefix .. "HorizontalBar", 0, 0.29296875, 0.25, 0.5)
		art.barRight:SetSize(75, 16)
		art.barRight:SetPoint("LEFT", art.barLeft, "RIGHT", 0, 0)
	end

	-- Vanilla drew the square portrait on the BACKGROUND layer and let the
	-- ring in the frame art cut it round. Retail's portrait lives in a child
	-- frame (drawn above the frame's own art) with a circle mask; the
	-- container is dropped below the frame's strata instead, so the art's
	-- hole does the masking again.
	local container = frame.PortraitContainer
	local portrait = container and container.portrait or ClassTrainerFramePortrait
	if portrait then
		portrait:SetSize(60, 60)
		Point(portrait, "TOPLEFT", frame, "TOPLEFT", 7, -6)
		if container then
			container:SetFrameStrata("LOW")
			ns.StripMask(container.CircleMask, portrait)
		end
	end

	local title = frame.TitleContainer and frame.TitleContainer.TitleText
	if title then
		Point(title, "TOP", frame, "TOP", 0, -17)
	end

	-- The greeting API went away with the Cataclysm trainer; shown when present.
	if GetTrainerGreetingText then
		art.greeting = frame:CreateFontString(nil, "BORDER", "GameFontHighlight")
		art.greeting:SetSize(260, 30)
		art.greeting:SetJustifyH("LEFT")
		art.greeting:SetJustifyV("TOP")
		art.greeting:SetPoint("TOPLEFT", frame, "TOPLEFT", 76, -38)
	end

	local close = frame.CloseButton
	if close then
		close:SetSize(32, 32)
		Point(close, "TOPRIGHT", frame, "TOPRIGHT", -29, -8)
		if ns.HasTexture(T.PANEL_CLOSE .. "Up") then
			close:SetNormalTexture(T.PANEL_CLOSE .. "Up")
			close:SetPushedTexture(T.PANEL_CLOSE .. "Down")
			close:SetDisabledTexture(T.PANEL_CLOSE .. "Disabled")
			close:SetHighlightTexture(T.PANEL_CLOSE .. "Highlight", "ADD")
		end
	end

	local train = ClassTrainerTrainButton or frame.TrainButton
	if train then
		train:SetSize(80, 22)
		Point(train, "CENTER", frame, "TOPLEFT", 224, -420)
	end
	art.exit = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	art.exit:SetSize(80, 22)
	art.exit:SetText(EXIT or "Exit")
	art.exit:SetPoint("CENTER", frame, "TOPLEFT", 305, -420)
	art.exit:SetScript("OnClick", function() HideUIPanel(frame) end)

	local money = frame.money or ClassTrainerFrameMoneyFrame
	if money then
		Point(money, "BOTTOMRIGHT", frame, "BOTTOMLEFT", 180, 86)
	end
	-- Forever's pet trainer shows training points in place of the money.
	if frame.trainingPoints then
		Point(frame.trainingPoints, "BOTTOMLEFT", frame, "BOTTOMLEFT", 28, 84)
	end

	-- The profession rank bar goes where vanilla had its "All" collapse tab
	-- (retail has no headers to collapse).
	if ClassTrainerStatusBar then
		Point(ClassTrainerStatusBar, "TOPLEFT", frame, "TOPLEFT", 24, -75)
	end
end

-- Retail's filter is a WowStyle1FilterDropdownTemplate button (an atlas
-- swapped by its mixin on every state change, sized to its text on every
-- update). Its background is faded and the classic dropdown box art is drawn
-- on it; the menu logic is untouched.
local function SkinFilterDropdown(frame)
	local dropdown = frame.FilterDropdown
	if not dropdown then return end

	local width = DROPDOWN_WIDTH + 50
	dropdown:SetSize(width, 32)
	Point(dropdown, "TOPRIGHT", frame, "TOPRIGHT", -26, -64)
	if dropdown.Background then dropdown.Background:SetAlpha(0) end
	ns.Hook(dropdown, "UpdateText", function(self) self:SetWidth(width) end)

	local right = dropdown
	if ns.HasTexture(T.DROPDOWN_BOX) then
		local left = dropdown:CreateTexture(nil, "ARTWORK")
		SetTexture(left, T.DROPDOWN_BOX, 0, 0.1953125, 0, 1)
		left:SetSize(25, 64)
		left:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, 17)
		local middle = dropdown:CreateTexture(nil, "ARTWORK")
		SetTexture(middle, T.DROPDOWN_BOX, 0.1953125, 0.8046875, 0, 1)
		middle:SetSize(DROPDOWN_WIDTH, 64)
		middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
		right = dropdown:CreateTexture(nil, "ARTWORK")
		SetTexture(right, T.DROPDOWN_BOX, 0.8046875, 1, 0, 1)
		right:SetSize(25, 64)
		right:SetPoint("LEFT", middle, "RIGHT", 0, 0)
	end

	local arrowPrefix = ns.HasTexture(T.CHAT_SCROLL_DOWN .. "Up") and T.CHAT_SCROLL_DOWN or T.SCROLL_DOWN
	local arrow = dropdown:CreateTexture(nil, "OVERLAY")
	SetTexture(arrow, arrowPrefix .. "Up")
	arrow:SetSize(24, 24)
	arrow:SetPoint("TOPRIGHT", right, "TOPRIGHT", -16, -18)
	dropdown:HookScript("OnMouseDown", function() SetTexture(arrow, arrowPrefix .. "Down") end)
	dropdown:HookScript("OnMouseUp", function() SetTexture(arrow, arrowPrefix .. "Up") end)
	dropdown:SetHighlightTexture(T.MOUSE_HIGHLIGHT, "ADD")
	local highlight = dropdown:GetHighlightTexture()
	if highlight then
		highlight:ClearAllPoints()
		highlight:SetSize(24, 24)
		highlight:SetPoint("CENTER", arrow, "CENTER", 0, 0)
	end

	local text = dropdown.Text
	if text then
		text:SetFontObject(GameFontHighlightSmall)
		text:SetJustifyH("RIGHT")
		Point(text, "RIGHT", right, "RIGHT", -43, 2)
	end
end

---------------------------------------------------------------------------
-- Scroll bars
---------------------------------------------------------------------------

-- MinimalScrollBar's steppers swap atlases on their own Texture from their
-- mixin; that texture is faded and a classic arrow drawn over it.
local function SkinStepper(button, prefix)
	if not button then return end
	if button.Texture then button.Texture:SetAlpha(0) end
	button:SetSize(16, 16)
	local texture = button:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints(button)
	local function Update(pushed)
		if not button:IsEnabled() then
			SetTexture(texture, prefix .. "Disabled")
		elseif pushed then
			SetTexture(texture, prefix .. "Down")
		else
			SetTexture(texture, prefix .. "Up")
		end
	end
	button:HookScript("OnMouseDown", function() Update(true) end)
	button:HookScript("OnMouseUp", function() Update(false) end)
	button:HookScript("OnEnable", function() Update(false) end)
	button:HookScript("OnDisable", function() Update(false) end)
	if ns.HasTexture(prefix .. "Highlight") then
		button:SetHighlightTexture(prefix .. "Highlight", "ADD")
	end
	Update(false)
end

local function SkinScrollBar(scrollBar)
	if not scrollBar then return end
	scrollBar:SetWidth(16)
	local track = scrollBar.Track
	if track then
		for _, key in ipairs({ "Begin", "End", "Middle" }) do
			if track[key] then track[key]:SetAlpha(0) end
		end
		local thumb = track.Thumb
		if thumb then
			for _, key in ipairs({ "Begin", "End", "Middle" }) do
				if thumb[key] then thumb[key]:SetAlpha(0) end
			end
			-- The classic knob is a fixed 18x24 whatever the thumb's extent.
			art.knob = thumb:CreateTexture(nil, "ARTWORK")
			SetTexture(art.knob, T.SCROLL_KNOB, 0.2, 0.8, 0.125, 0.875)
			art.knob:SetSize(18, 24)
			art.knob:SetPoint("CENTER", thumb, "CENTER", 0, 0)
		end
	end
	SkinStepper(scrollBar.Back, T.SCROLL_UP)
	SkinStepper(scrollBar.Forward, T.SCROLL_DOWN)
end

-- The scroll trough art (UI-ClassTrainer-ScrollBar) that vanilla drew behind
-- both scroll bars: a top and a bottom piece that overlap in the middle.
local function CreateTrough(frame, topInset)
	local file = artPrefix .. "ScrollBar"
	if not ns.HasTexture(file) then return end
	local top = frame:CreateTexture(nil, "ARTWORK")
	SetTexture(top, file, 0, 0.46875, topInset, 0.9609375)
	top:SetSize(30, 123 * (0.9609375 - topInset) / 0.9609375)
	local bottom = frame:CreateTexture(nil, "ARTWORK")
	SetTexture(bottom, file, 0.53125, 1, 0.03125, 1)
	bottom:SetSize(30, 123)
	return top, bottom
end

---------------------------------------------------------------------------
-- Skill rows
---------------------------------------------------------------------------

-- Name / sub text colours: white while hovered or selected (the vanilla
-- button's highlight font), the service type's colour otherwise; the
-- highlight bar is shown under the selected row.
local function ColorRow(row, hovered)
	local state = rows[row]
	if not state then return end
	local id = row:GetID()
	local _, serviceType = GetTrainerServiceInfo(id)
	local colors = TYPE_COLORS[serviceType] or TYPE_COLORS.available
	local selected = ClassTrainerFrame.selectedService == id
	if hovered or selected then
		row.name:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
		if row.nameSubText then row.nameSubText:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB()) end
	else
		row.name:SetTextColor(unpack(colors.text))
		if row.nameSubText then row.nameSubText:SetTextColor(unpack(colors.sub)) end
	end
	state.bar:SetVertexColor(unpack(colors.bar))
	state.bar:SetShown(selected)
end

-- Vanilla row (ClassTrainerSkillButtonTemplate): 293x16, the name 21px in,
-- the "(Rank n)" sub text 10px after it. Blizzard's Init only sets texts,
-- so the anchors are set once here; what Init touches is fixed in OnRowInit.
local function SkinRow(row)
	local state = { bar = row:CreateTexture(nil, "BACKGROUND") }
	rows[row] = state

	for _, key in ipairs({ "icon", "subText", "selectedTex", "disabledBG", "lock", "money", "alternateCost" }) do
		if row[key] then row[key]:SetAlpha(0) end -- Init shows some of these again; alpha survives that
	end
	local normal, highlight = row:GetNormalTexture(), row:GetHighlightTexture()
	if normal then normal:SetAlpha(0) end
	if highlight then highlight:SetAlpha(0) end

	SetTexture(state.bar, highlightFile)
	state.bar:SetAllPoints(row)
	state.bar:Hide()

	if row.name then
		row.name:SetWordWrap(false)
		row.name:SetJustifyH("LEFT")
		Point(row.name, "LEFT", row, "LEFT", 21, 1)
	end
	if row.nameSubText and row.name then
		row.nameSubText:SetJustifyH("LEFT")
		Point(row.nameSubText, "LEFT", row.name, "RIGHT", 10, 0)
	end

	row:HookScript("OnEnter", function(self) ColorRow(self, true) end)
	row:HookScript("OnLeave", function(self) ColorRow(self, false) end)
end

-- After Blizzard's ClassTrainerFrame_InitServiceButton (rows and the step button).
local function OnRowInit(row)
	if not row.name then return end
	if not rows[row] then SkinRow(row) end

	if row == ClassTrainerFrame.skillStepButton and not IsStepPinned() then
		row:Hide()
		return
	end

	-- Vanilla let the name run free when a sub text followed it and capped
	-- it (no wrap, so it truncates) otherwise.
	local sub = row.nameSubText and row.nameSubText:GetText()
	row.name:SetWidth((sub and sub ~= "") and 0 or SKILL_TEXT_WIDTH)
	ColorRow(row, row:IsMouseOver())
end

-- Forever's category headers (TrainerUICategoryTemplate): the atlas pieces
-- and collapse arrow are faded and the vanilla +/- box drawn in their place.
-- Blizzard re-sets the header's scripts on every Init, so the font hooks
-- are re-added each time; the +/- follows the CollapseIcon atlas Blizzard
-- swaps when the category is toggled.
local function OnCategoryInit(button, node)
	local state = headers[button]
	if not state then
		state = { icon = button:CreateTexture(nil, "ARTWORK") }
		headers[button] = state
		for _, key in ipairs({ "LeftPiece", "RightPiece", "CenterPiece", "CollapseIcon", "CollapseIconAlphaAdd" }) do
			if button[key] then button[key]:SetAlpha(0) end
		end
		state.icon:SetSize(16, 16)
		state.icon:SetPoint("LEFT", button, "LEFT", 3, 0)
		if button.Label then
			Point(button.Label, "LEFT", button, "LEFT", 21, 1)
		end
		if ns.HasTexture(T.PLUS_HILIGHT) then
			button:SetHighlightTexture(T.PLUS_HILIGHT, "ADD")
			local highlight = button:GetHighlightTexture()
			if highlight then
				highlight:ClearAllPoints()
				highlight:SetSize(16, 16)
				highlight:SetPoint("LEFT", button, "LEFT", 3, 0)
			end
		end
		if button.CollapseIcon then
			ns.Hook(button.CollapseIcon, "SetAtlas", function(_, atlas)
				SetTexture(state.icon, (type(atlas) == "string" and atlas:find("expand")) and T.PLUS_BUTTON or T.MINUS_BUTTON)
			end)
		end
	end

	local collapsed = node and node.IsCollapsed and node:IsCollapsed()
	SetTexture(state.icon, collapsed and T.PLUS_BUTTON or T.MINUS_BUTTON)
	if button.Label then
		button.Label:SetFontObject(GameFontNormal)
		button:HookScript("OnEnter", function(self) self.Label:SetFontObject(GameFontHighlight) end)
		button:HookScript("OnLeave", function(self) self.Label:SetFontObject(GameFontNormal) end)
	end
end

---------------------------------------------------------------------------
-- Detail pane (vanilla ClassTrainerDetailScrollFrame)
---------------------------------------------------------------------------

local function CreateDetailPane(frame)
	-- UIPanelScrollFrameTemplate is the classic knob scroll frame; with
	-- scrollBarHideable the bar only appears when the text overflows.
	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetSize(LIST_WIDTH, DETAIL_HEIGHT_CLASS)
	scroll.scrollBarHideable = 1
	if scroll.ScrollBar then
		scroll.ScrollBar:Hide() -- the template's OnLoad ran before scrollBarHideable was set
	end
	art.detail = scroll

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(LIST_WIDTH, 50)
	scroll:SetScrollChild(child)
	art.detailChild = child

	local icon = CreateFrame("Button", nil, child)
	icon:SetSize(37, 37)
	icon:SetPoint("TOPLEFT", child, "TOPLEFT", 5, -4)
	local slot = icon:CreateTexture(nil, "BACKGROUND")
	slot:SetTexture(T.EMPTY_SLOT)
	slot:SetSize(64, 64)
	slot:SetPoint("TOPLEFT", icon, "TOPLEFT", -13, 13)
	icon:SetScript("OnEnter", function(self)
		local id = ClassTrainerFrame.selectedService
		if not id then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetTrainerService(id)
		GameTooltip:Show()
	end)
	icon:SetScript("OnLeave", GameTooltip_Hide)
	icon:SetScript("OnClick", function()
		local id = ClassTrainerFrame.selectedService
		if id and GetTrainerServiceItemLink then
			HandleModifiedItemClick(GetTrainerServiceItemLink(id))
		end
	end)
	art.icon = icon

	art.name = child:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	art.name:SetJustifyH("LEFT")
	art.name:SetWordWrap(false)
	art.name:SetPoint("TOPLEFT", child, "TOPLEFT", 46, -2)

	art.subName = child:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	art.subName:SetJustifyH("LEFT")
	art.subName:SetPoint("LEFT", art.name, "RIGHT", 5, 0)

	art.requirements = child:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
	art.requirements:SetWidth(244)
	art.requirements:SetJustifyH("LEFT")
	art.requirements:SetPoint("TOPLEFT", art.name, "BOTTOMLEFT", 0, 0)

	art.costLabel = child:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
	art.costLabel:SetJustifyH("LEFT")
	art.costLabel:SetText(COSTS_LABEL or "Costs:")
	art.costLabel:SetPoint("TOPLEFT", child, "TOPLEFT", 5, -50)

	art.money = CreateFrame("Frame", nil, child, "SmallMoneyFrameTemplate")
	art.money:SetPoint("LEFT", art.costLabel, "RIGHT", 5, 0)
	MoneyFrame_SetType(art.money, "STATIC")
	MoneyFrame_SetMaxDisplayWidth(art.money, 100)

	art.pointsCost = child:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
	art.pointsCost:SetJustifyH("LEFT")
	art.pointsCost:SetPoint("LEFT", art.costLabel, "RIGHT", 5, 0)

	art.description = child:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
	art.description:SetWidth(290)
	art.description:SetJustifyH("LEFT")
	art.description:SetJustifyV("TOP")
	art.description:SetPoint("TOPLEFT", art.costLabel, "BOTTOMLEFT", 0, -10)
end

-- Mirrors the requirement text ClassTrainerFrame_InitServiceButton builds
-- for the (now hidden) row sub text.
local function BuildRequirements(id, serviceType, reqLevel, unit)
	if serviceType == "used" then
		return ITEM_SPELL_KNOWN
	end
	local parts = {}
	if reqLevel and reqLevel > 1 then
		local met = UnitLevel(unit) >= reqLevel
		table.insert(parts, format(met and TRAINER_REQ_LEVEL or TRAINER_REQ_LEVEL_RED, reqLevel))
	end
	local skill, rank, hasSkill = GetTrainerServiceSkillReq(id)
	if skill then
		table.insert(parts, format(hasSkill and TRAINER_REQ_SKILL_RANK or TRAINER_REQ_SKILL_RANK_RED, skill, rank))
	end
	for i = 1, GetTrainerServiceNumAbilityReq(id) or 0 do
		local ability, hasAbility = GetTrainerServiceAbilityReq(id, i)
		if ability then
			table.insert(parts, format(hasAbility and TRAINER_REQ_ABILITY or TRAINER_REQ_ABILITY_RED, ability))
		end
	end
	if #parts == 0 then
		return ""
	end
	return REQUIRES_LABEL .. " " .. table.concat(parts, PLAYER_LIST_DELIMITER)
end

local function GetTooltipLines(id)
	if not (C_TooltipInfo and C_TooltipInfo.GetTrainerService) then return end
	local data = C_TooltipInfo.GetTrainerService(id)
	local lines = data and data.lines
	if not lines then return end
	-- Pre-10.1 tooltip data needs its arguments surfaced first.
	if lines[1] and lines[1].leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
		TooltipUtil.SurfaceArgs(data)
		for _, line in ipairs(lines) do
			TooltipUtil.SurfaceArgs(line)
		end
	end
	return lines
end

local function IsWhite(color)
	return color.r == nil or (color.r > 0.99 and color.g > 0.99 and color.b > 0.99)
end

-- The description text and, when known, the service's sub text ("Rank 2").
-- Vanilla's GetTrainerServiceDescription is used when the client has it;
-- otherwise the service tooltip's lines after the name are shown.
local function GetDescription(id)
	if GetTrainerServiceDescription then
		local text = GetTrainerServiceDescription(id)
		if text and text ~= "" then
			return text
		end
	end
	local lines = GetTooltipLines(id)
	if not lines then return "" end
	local out = {}
	for i = 2, #lines do
		local line = lines[i]
		local text = line.leftText
		if text and text ~= "" then
			if line.rightText and line.rightText ~= "" then
				text = text .. "  " .. line.rightText
			end
			local color = line.leftColor
			if type(color) == "table" and color.WrapTextInColorCode and not IsWhite(color) then
				text = color:WrapTextInColorCode(text)
			end
			table.insert(out, text)
		end
	end
	return table.concat(out, "\n"), lines[1] and lines[1].rightText
end

local function HideDetails()
	for _, key in ipairs({ "icon", "name", "subName", "requirements", "costLabel", "money", "pointsCost", "description" }) do
		art[key]:Hide()
	end
end

local function UpdateDetails()
	local frame = ClassTrainerFrame
	if not art.detail or not frame:IsShown() then return end

	local id = frame.selectedService
	local name, serviceType, texture, reqLevel, subText
	if id then
		name, serviceType, texture, reqLevel, subText = GetTrainerServiceInfo(id)
	end
	if not name then
		HideDetails()
		return
	end

	local isPet = IsPetTrainer()
	local description, tooltipSubText = GetDescription(id)
	if not subText or subText == "" then
		subText = tooltipSubText
	end

	if texture then
		art.icon:SetNormalTexture(texture)
	else
		art.icon:ClearNormalTexture()
	end
	art.name:SetText(name)
	art.name:SetWidth(0) -- fit the text so the sub text follows it; vanilla's 244px cap otherwise
	if art.name:GetStringWidth() > 244 then
		art.name:SetWidth(244)
	end
	if subText and subText ~= "" then
		art.subName:SetText(PARENS_TEMPLATE:format(subText))
		art.subName:Show()
	else
		art.subName:Hide()
	end
	art.requirements:SetText(BuildRequirements(id, serviceType, reqLevel, isPet and "pet" or "player"))

	local cost = GetTrainerServiceCost(id) or 0
	local showCost = cost > 0 and serviceType ~= "used"
	art.costLabel:SetShown(showCost)
	art.money:SetShown(showCost and not isPet)
	art.pointsCost:SetShown(showCost and isPet)
	if showCost and isPet then
		art.pointsCost:SetText(format(TRAINING_POINTS_ABBREV or TRAINING_POINTS or "%s", cost))
	elseif showCost then
		MoneyFrame_Update(art.money, cost)
		SetMoneyFrameColorByFrame(art.money, GetMoney() >= cost and "white" or "red")
	end

	art.description:ClearAllPoints()
	local descriptionTop = 50
	if showCost then
		descriptionTop = descriptionTop + art.costLabel:GetStringHeight() + 10
		art.description:SetPoint("TOPLEFT", art.costLabel, "BOTTOMLEFT", 0, -10)
	else
		art.description:SetPoint("TOPLEFT", art.costLabel, "TOPLEFT", 0, 0)
	end
	art.description:SetText(description or "")

	art.icon:Show()
	art.name:Show()
	art.requirements:Show()
	art.description:Show()

	-- Size the scroll child to its content so the bar only shows when needed.
	art.detailChild:SetHeight(math.max(50, descriptionTop + art.description:GetStringHeight() + 8))
	art.detail:UpdateScrollChildRect()
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

-- Vanilla shows 11 rows for a class trainer and 10 (with a taller detail
-- pane) for a profession trainer. Runs after ClassTrainerFrame_Update, which
-- anchors the ScrollBox to the retail insets every time.
local function LayoutFrame()
	local frame = ClassTrainerFrame
	local trade = IsTradeskillTrainer()
	local listHeight = trade and LIST_HEIGHT_TRADE or LIST_HEIGHT_CLASS
	local listBottom = LIST_TOP - listHeight
	local rowsTop = LIST_TOP - 4
	local rowsHeight = listHeight - 8

	local scrollBox = frame.ScrollBox
	local step = frame.skillStepButton
	scrollBox:ClearAllPoints()
	if step and IsStepPinned() then
		step:SetSize(ROW_WIDTH, ROW_HEIGHT)
		Point(step, "TOPLEFT", frame, "TOPLEFT", ROW_LEFT, rowsTop)
		step:Show()
		scrollBox:SetPoint("TOPLEFT", frame, "TOPLEFT", ROW_LEFT, rowsTop - ROW_HEIGHT)
		scrollBox:SetSize(ROW_WIDTH, rowsHeight - ROW_HEIGHT)
	else
		if step then step:Hide() end
		scrollBox:SetPoint("TOPLEFT", frame, "TOPLEFT", ROW_LEFT, rowsTop)
		scrollBox:SetSize(ROW_WIDTH, rowsHeight)
	end

	local scrollBar = frame.ScrollBar
	if scrollBar then
		local x = LIST_LEFT + LIST_WIDTH + 6
		scrollBar:ClearAllPoints()
		scrollBar:SetPoint("TOPLEFT", frame, "TOPLEFT", x, LIST_TOP)
		scrollBar:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", x, listBottom)
	end
	if art.listTroughTop then
		Point(art.listTroughTop, "TOPLEFT", frame, "TOPLEFT", LIST_LEFT + LIST_WIDTH - 3, LIST_TOP + 2)
		Point(art.listTroughBottom, "BOTTOMLEFT", frame, "TOPLEFT", LIST_LEFT + LIST_WIDTH - 3, listBottom - 2)
	end
	if art.barLeft then
		Point(art.barLeft, "TOPLEFT", frame, "TOPLEFT", 15, listBottom + 5)
	end

	local detailTop = listBottom - 8
	local detailHeight = trade and DETAIL_HEIGHT_TRADE or DETAIL_HEIGHT_CLASS
	Point(art.detail, "TOPLEFT", frame, "TOPLEFT", LIST_LEFT, detailTop)
	art.detail:SetSize(LIST_WIDTH, detailHeight)
	if art.detailTroughTop then
		Point(art.detailTroughTop, "TOPLEFT", frame, "TOPLEFT", LIST_LEFT + LIST_WIDTH - 2, detailTop + 5)
		Point(art.detailTroughBottom, "BOTTOMLEFT", frame, "TOPLEFT", LIST_LEFT + LIST_WIDTH - 2, detailTop - detailHeight - 1)
	end

	if art.greeting then
		art.greeting:SetText(GetTrainerGreetingText() or "")
	end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local function Skin()
	local frame = ClassTrainerFrame
	if not frame or not frame.ScrollBox or art.topLeft then return end

	artPrefix = ResolveArtPrefix()
	if not artPrefix then
		ns.Print("This client does not ship " .. T.TRAINER_ART .. "*; the trainer window keeps the retail look.")
		return
	end
	highlightFile = ns.HasTexture(T.LISTBOX_HIGHLIGHT) and T.LISTBOX_HIGHLIGHT or T.LISTBOX_HIGHLIGHT1

	ApplyFrameArt(frame)
	SkinFilterDropdown(frame)
	SkinScrollBar(frame.ScrollBar)
	art.listTroughTop, art.listTroughBottom = CreateTrough(frame, 0.0234375)
	art.detailTroughTop, art.detailTroughBottom = CreateTrough(frame, 0)
	CreateDetailPane(frame)

	local scrollBox = frame.ScrollBox
	local view = scrollBox:GetView()
	if view then
		if view.SetElementExtent then view:SetElementExtent(ROW_HEIGHT) end
		if view.SetPadding then view:SetPadding(0, 0, 0, 0, 0) end
	end
	-- Retail fades the list's edges with shadow textures while it scrolls.
	if scrollBox.GetUpperShadowTexture then
		scrollBox:GetUpperShadowTexture():SetAlpha(0)
		scrollBox:GetLowerShadowTexture():SetAlpha(0)
	end
	-- Vanilla hid the list's scroll bar when everything fit.
	if frame.ScrollBar and ScrollUtil and ScrollUtil.AddManagedScrollBarVisibilityBehavior then
		ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, frame.ScrollBar)
	end

	ns.Hook("ClassTrainerFrame_InitServiceButton", OnRowInit)
	ns.Hook("ClassTrainerFrame_InitCategoryButton", OnCategoryInit) -- Forever only
	ns.Hook("ClassTrainerFrame_Update", function()
		LayoutFrame()
		UpdateDetails()
	end)
	ns.Hook("ClassTrainer_SetSelection", UpdateDetails)

	if frame:IsShown() then
		LayoutFrame()
		UpdateDetails()
	end
end

-- Blizzard_TrainerUI is load-on-demand: it loads the first time a trainer is
-- talked to.
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, _, addon)
	if addon == "Blizzard_TrainerUI" then
		self:UnregisterEvent("ADDON_LOADED")
		xpcall(Skin, geterrorhandler())
	end
end)

function module:Apply()
	if C_AddOns.IsAddOnLoaded("Blizzard_TrainerUI") then
		Skin()
	else
		eventFrame:RegisterEvent("ADDON_LOADED")
	end
end
