--[[
	Forevermore Classic UI - Character window: Skills tab (WoW Forever only)

	Restores the vanilla skills page (1.12 SkillFrame.xml) inside the vanilla
	character window (CharacterFrame.lua, whose option this is part of): one
	271x15 bar per skill in the UI-Character-Skills-BarBorder frame, the name
	in yellow at its left with the rank in white after it, the bar blue (grey
	and full for a proficiency, which has no rank), the border lit while the
	row is hovered or selected; the skill groups as white +/- header rows;
	under the list the trainer's divider and the selected skill's bar and
	description, as 1.12's detail pane.

	Forever's page (Blizzard_UIPanels_Game\Camelot\SkillsFrame.*) lists the
	skill lines in a ScrollBox of header, sub-header and entry rows with a
	ColoredProgressBar, and shows the selected skill in the right pane
	(SkillDetailFrame, kept: the weapon skill figures are there). The rows
	are re-skinned in place (the list's layout, scaling and row callbacks:
	CharacterFrame.lua, CharacterList):

	  * the bar is resized to the vanilla bar at the row's left, its atlas
	    art and fill hidden and the vanilla fill, background and border
	    drawn on it, from the row's skill data after each Initialize,
	  * the name (Blizzard's, on the row) is moved onto the bar, so the fill
	    draws under it, and the bar's own text (the rank) goes after it,
	  * the rows are 1.12's 18px apart: the list is scaled down from
	    Blizzard's 33px entry rows (ROW_SCALE) and each row's content back
	    up to full size,
	  * the detail pane under the list is this module's, filled from
	    C_SkillInfo for the selected skill whenever Blizzard refreshes its
	    own detail pane.

	Only widget state is touched; no Lua field is written on Blizzard's
	frames. Applied once at login with the Character Window option.
]]

local _, ns = ...
if not ns.IS_FOREVER then return end
local T = ns.T
local Point = ns.Point
local List = ns.CharacterList

-- T.SKILLS_BAR and the +/- buttons (CharacterFrame.lua) and T.TRAINER_ART
-- (TrainerFrame.lua) come from files loaded earlier.
T.SKILLS_BAR_BORDER    = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"
T.SKILLS_BAR_HIGHLIGHT = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorderHighlight"

local module = ns:RegisterModule({
	key = "characterskills",
	name = "Character Window: Skills",
	parent = "characterframe",
	live = false,
})

-- Vanilla geometry (1.12 SkillFrame.xml), offsets from the character
-- frame's top-left corner.
local LIST_LEFT, LIST_TOP, LIST_RIGHT, LIST_BOTTOM = 21, -75, 317, -295 -- SkillListScrollFrame (12 rows)
local BAR_X = 10                                 -- the bar's left end from the row content's (1.12: x 38)
local BAR_WIDTH, BAR_HEIGHT = 271, 15            -- SkillStatusBarTemplate
local BORDER_WIDTH, BORDER_X = 281, -5           -- its border, from the bar's left
local NAME_X, NAME_Y, RANK_GAP = 6, 1, 13
local HEADER_BUTTON_X, HEADER_TEXT_X = 3, 25     -- SkillLabelTemplate
local DIVIDER_X, DIVIDER_Y = 15, -290            -- SkillFrameHorizontalBarLeft
local DETAIL_BAR_X, DETAIL_BAR_Y, DETAIL_BAR_WIDTH = 66, -316, 211 -- SkillDetailStatusBar (top left)
local DETAIL_TEXT_X, DETAIL_TEXT_Y, DETAIL_TEXT_WIDTH = 38, -338, 275
-- The list's scale: 1.12's row pitch (a 15px bar every 18px) over
-- Blizzard's (SkillsEntryTemplate, 30px, plus 3px spacing).
local ROW_SCALE = 18 / 33

-- 1.12's bar colours (SkillFrame_SetStatusBar): a skill, and a proficiency
-- (a skill with a maximum rank of 1, drawn full and grey). The background
-- was white at alpha 0.2 with these vertex colours on it, so its alpha is
-- a fifth of theirs (0.5 * 0.2): a dark well the fill stands out from.
local SKILL_FILL, SKILL_BACKGROUND = { 0, 0, 1, 0.5 }, { 0, 0, 0.75, 0.1 }
local PROFICIENCY_FILL, PROFICIENCY_BACKGROUND = { 0.5, 0.5, 0.5, 1 }, { 1, 1, 1, 0.1 }

local function Fade(region)
	if region then region:SetAlpha(0) end
end

---------------------------------------------------------------------------
-- The vanilla skill bar (rows and detail pane)
---------------------------------------------------------------------------

-- Background, fill, border and highlight on a bar frame of the vanilla size.
local function CreateBarArt(bar, width)
	local art = { width = width }
	art.background = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
	art.background:SetAllPoints(bar)
	art.fill = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
	art.fill:SetTexture(T.SKILLS_BAR)
	art.fill:SetHeight(BAR_HEIGHT)
	art.fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
	art.border = bar:CreateTexture(nil, "ARTWORK", nil, -1)
	art.border:SetTexture(T.SKILLS_BAR_BORDER)
	art.border:SetSize(width + BORDER_WIDTH - BAR_WIDTH, 32)
	art.border:SetPoint("LEFT", bar, "LEFT", BORDER_X, 0)
	art.highlight = bar:CreateTexture(nil, "OVERLAY", nil, -1)
	art.highlight:SetTexture(T.SKILLS_BAR_HIGHLIGHT)
	art.highlight:SetBlendMode("ADD")
	art.highlight:SetAllPoints(art.border)
	art.highlight:Hide()
	return art
end

-- 1.12's look for a skill's rank: blue, filled to the rank; a proficiency
-- grey and full. Returns whether the rank is shown.
local function SetBarRank(art, rank, maxRank)
	local proficiency = maxRank == 1
	local fill = proficiency and PROFICIENCY_FILL or SKILL_FILL
	local background = proficiency and PROFICIENCY_BACKGROUND or SKILL_BACKGROUND
	art.fill:SetVertexColor(unpack(fill))
	art.background:SetColorTexture(unpack(background))
	local percent = proficiency and 1 or (maxRank and maxRank > 0 and (rank or 0) / maxRank or 0)
	List.SetFill(art.fill, art.width, percent)
	return not proficiency
end

local function RankText(info)
	local modifier = info.modifier or 0
	if modifier ~= 0 then
		return string.format("%d%s(+%d)|r/%d", info.rank or 0, GREEN_FONT_COLOR_CODE, modifier, info.maxRank or 0)
	end
	return string.format("%d/%d", info.rank or 0, info.maxRank or 0)
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

-- An entry row (and a sub-header row, which is an entry with a +/- button).
local function SkinEntry(row)
	local content, bar = row.Content, row.Content.SkillsBar
	-- Full size again in the scaled-down list; it spans its row.
	content:SetScale(1 / ROW_SCALE)

	List.FadeAtlasRegions(bar)
	bar.Fill:Hide()
	bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	Point(bar, "LEFT", content, "LEFT", BAR_X, 0)
	local skin = { art = CreateBarArt(bar, BAR_WIDTH) }

	-- The name goes onto the bar (over its fill), the rank after it.
	content.Name:SetParent(bar)
	content.Name:SetFontObject(GameFontNormalSmall)
	content.Name:SetJustifyH("LEFT")
	bar.Text:SetFontObject(GameFontHighlightSmall)
	bar.Text:SetJustifyH("LEFT")
	Point(bar.Text, "LEFT", content.Name, "RIGHT", RANK_GAP, 0)

	for _, texture in ipairs(content.BackgroundHighlight.TextureRegions or {}) do
		Fade(texture)
	end
	ns.Hook(row, "RefreshBackgroundHighlight", function()
		skin.art.highlight:SetShown(row:IsSelected() or row:IsMouseOver())
	end)
	return skin
end

local function UpdateEntry(row, skin)
	local content, bar = row.Content, row.Content.SkillsBar
	-- Blizzard anchors a sub-header's name to its button on every Initialize.
	Point(content.Name, "LEFT", bar, "LEFT", NAME_X, NAME_Y)
	local info = row.elementData or {}
	local hasRank = SetBarRank(skin.art, info.rank, info.maxRank)
	bar.Text:SetAlpha(hasRank and 1 or 0)
	skin.art.highlight:SetShown(row:IsSelected() or row:IsMouseOver())
end

local function SkinRow(row)
	if row.StateIcon then
		-- 1.12's skill group labels were white.
		local skin = List.SkinHeader(row, ROW_SCALE, GameFontHighlight, HEADER_BUTTON_X, HEADER_TEXT_X)
		row.Name:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
		return skin
	elseif row.Content and row.Content.SkillsBar then
		local skin = SkinEntry(row)
		if row.ToggleCollapseButton then
			List.SkinToggle(row.ToggleCollapseButton, ROW_SCALE)
		end
		return skin
	end
end

local function UpdateRow(row, skin)
	if row.StateIcon then
		List.SetExpandTexture(skin.button, row:IsCollapsed(), "Up")
		return
	end
	if row.ToggleCollapseButton then
		List.UpdateToggle(row.ToggleCollapseButton, row:IsCollapsed())
	end
	UpdateEntry(row, skin)
end

---------------------------------------------------------------------------
-- Detail pane (1.12 SkillDetailScrollFrame)
---------------------------------------------------------------------------

local detail -- { bar, art, name, rank, description }

local function CreateDetail(overlay)
	local divider = overlay:CreateTexture(nil, "ARTWORK")
	ns.SetTexture(divider, T.TRAINER_ART .. "HorizontalBar", 0, 1, 0, 0.25)
	divider:SetSize(256, 16)
	divider:SetPoint("TOPLEFT", ns.ArtOrigin(CharacterFrame), "TOPLEFT", DIVIDER_X, DIVIDER_Y)
	local dividerEnd = overlay:CreateTexture(nil, "ARTWORK")
	ns.SetTexture(dividerEnd, T.TRAINER_ART .. "HorizontalBar", 0, 0.29296875, 0.25, 0.5)
	dividerEnd:SetSize(75, 16)
	dividerEnd:SetPoint("LEFT", divider, "RIGHT", 0, 0)

	detail = {}
	detail.bar = CreateFrame("Frame", nil, overlay)
	detail.bar:SetSize(DETAIL_BAR_WIDTH, BAR_HEIGHT)
	detail.bar:SetPoint("TOPLEFT", ns.ArtOrigin(CharacterFrame), "TOPLEFT", DETAIL_BAR_X, DETAIL_BAR_Y)
	detail.art = CreateBarArt(detail.bar, DETAIL_BAR_WIDTH)
	detail.name = detail.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	detail.name:SetPoint("LEFT", detail.bar, "LEFT", NAME_X, NAME_Y)
	detail.rank = detail.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	detail.rank:SetPoint("LEFT", detail.name, "RIGHT", RANK_GAP, 0)
	detail.description = overlay:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	detail.description:SetPoint("TOPLEFT", ns.ArtOrigin(CharacterFrame), "TOPLEFT", DETAIL_TEXT_X, DETAIL_TEXT_Y)
	detail.description:SetWidth(DETAIL_TEXT_WIDTH)
	detail.description:SetJustifyH("LEFT")
end

-- The selected skill (Blizzard's detail pane shows the same one; a header
-- or nothing selected leaves the pane empty).
local function UpdateDetail()
	local index = C_SkillInfo.GetSelectedSkill()
	local info = index and index > 0 and C_SkillInfo.GetSkillLineInfo(index)
	local shown = info and not info.isHeader
	detail.bar:SetShown(shown and true or false)
	detail.description:SetShown(shown and true or false)
	if not shown then return end
	detail.name:SetText(info.name or "")
	detail.rank:SetText(RankText(info))
	detail.rank:SetShown(SetBarRank(detail.art, info.rank, info.maxRank))
	detail.description:SetText(info.description or "")
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------

function module:Apply()
	local page = SkillsFrame
	if not (page and page.ScrollBox and page.ScrollBar and page.SkillDetailFrame and C_SkillInfo and ScrollUtil
		and ScrollUtil.AddAcquiredFrameCallback and ScrollUtil.AddInitializedFrameCallback) then
		return
	end
	-- Only inside the vanilla character window (CharacterFrame.lua, applied
	-- before this file's part).
	if not ns.characterWindowSkinned then return end

	local overlay = List.SkinList(page, LIST_LEFT, LIST_TOP, LIST_RIGHT, LIST_BOTTOM, ROW_SCALE)
	List.OnRows(page, module, SkinRow, UpdateRow)

	CreateDetail(overlay)
	-- Blizzard refreshes its detail pane on every selection and list update
	-- (shown or not).
	ns.Hook(page.SkillDetailFrame, "Refresh", UpdateDetail)
	page:HookScript("OnShow", UpdateDetail)
end
