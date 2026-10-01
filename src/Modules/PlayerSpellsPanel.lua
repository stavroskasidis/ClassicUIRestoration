--[[
	Forevermore Classic UI - Player spells panel (WoW Forever only)

	Forever's spellbook and talents are two pages of one panel,
	PlayerSpellsFrame (Blizzard_PlayerSpells, load-on-demand), shown one at a
	time like the classic separate windows. The Spellbook and Talents options
	each draw a vanilla frame for their page; while such a page is shown the
	panel's own chrome has to go, and it comes back for a page that keeps the
	retail look:

	  * the NineSlice border, background, portrait and title are hidden,
	  * the close button becomes the round classic one, at the spot the page
	    gives,
	  * the panel's mouse is switched off, so the invisible panel does not
	    block clicks around the classic frame (each classic frame takes its
	    own). The spellbook page holds a secure button, which makes the panel
	    protected, so this waits for the end of combat,
	  * the controller UI's focus glow and button prompt footers go round
	    the page's classic frame (ns.SetGamepadBox, the box the page gives).

	The modules register their pages here. On a tab change Blizzard shows the
	new page and hides the old one one after the other (in the order of its
	tabs), so the panel is set up from the pages' shown state after every
	one of those calls, never from the page that triggered it: the last call
	leaves the right state whatever the order. Only widget state is changed.
]]

local _, ns = ...
if not ns.IS_FOREVER then return end

local panel = {}
ns.PlayerSpellsPanel = panel

local RETAIL_CHROME = { "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "TitleContainer" }
local BUTTON_STATES = { "Normal", "Pushed", "Disabled", "Highlight" }

local book                 -- PlayerSpellsFrame
local pages = {}           -- registered page -> function(closeButton) placing the classic close button
local boxes = {}           -- registered page -> the box round its classic frame (ns.CreateArtBox)
local retail               -- the panel state the classic pages replace
local classicShown = false -- whether the classic chrome is on the panel
local mouseQueued = false

local function SaveRetail()
	local close = book.CloseButton
	-- ignoreRect: the set size (the panel is still hidden, nothing is laid out yet)
	retail = { mouse = book:IsMouseEnabled(), width = close:GetWidth(true), height = close:GetHeight(true), points = {}, textures = {} }
	for i = 1, close:GetNumPoints() do
		retail.points[i] = { close:GetPoint(i) }
	end
	for _, state in ipairs(BUTTON_STATES) do
		local texture = close["Get" .. state .. "Texture"](close)
		if texture then
			retail.textures[state] = { atlas = texture:GetAtlas(), file = texture:GetTexture() }
		end
	end
end

-- The retail close button (the red X in the panel's corner) is put back.
local function RestoreCloseButton()
	local close = book.CloseButton
	close:SetSize(retail.width, retail.height)
	close:ClearAllPoints()
	for _, point in ipairs(retail.points) do
		close:SetPoint(unpack(point))
	end
	for state, texture in pairs(retail.textures) do
		local blend = state == "Highlight" and "ADD" or nil
		if texture.atlas then
			close["Set" .. state .. "Atlas"](close, texture.atlas, blend)
		elseif texture.file then
			close["Set" .. state .. "Texture"](close, texture.file, blend)
		end
	end
end

-- The registered page that is the panel's shown tab (its own shown flag;
-- the panel itself may be hidden). Only one page is shown at a time once
-- Blizzard has finished a tab change.
local function ShownPage()
	for page in pairs(pages) do
		if page:IsShown() then
			return page
		end
	end
end

local function UpdateMouse()
	if InCombatLockdown() then
		if not mouseQueued then
			mouseQueued = true
			ns:RunOutOfCombat(function()
				mouseQueued = false
				UpdateMouse()
			end)
		end
		return
	end
	book:EnableMouse(retail.mouse and ShownPage() == nil)
end

-- The classic chrome is (re)applied whenever a classic page is shown, since
-- Blizzard re-shows parts of the panel on tab changes; the retail chrome is
-- put back once, when a retail page takes over.
function panel.Update()
	local page = ShownPage()
	if not page and not classicShown then return end
	classicShown = page ~= nil
	for _, key in ipairs(RETAIL_CHROME) do
		if book[key] then book[key]:SetShown(not page) end
	end
	if page then
		ns.SkinCloseButton(book.CloseButton)
		pages[page](book.CloseButton)
	else
		RestoreCloseButton()
	end
	ns.SetGamepadBox(book, page and boxes[page])
	UpdateMouse()
end

-- page: a page of PlayerSpellsFrame that draws its own classic frame;
-- placeCloseButton(close): anchors the classic close button to that frame;
-- box: the controller UI's box round that frame (ns.CreateArtBox).
function panel.Register(page, placeCloseButton, box)
	if not book then
		book = PlayerSpellsFrame
		SaveRetail()
		book:HookScript("OnShow", panel.Update)
	end
	pages[page] = placeCloseButton
	boxes[page] = box
	-- The tab tracker shows / hides the pages on every tab change.
	ns.Hook(page, "SetShown", panel.Update)
	panel.Update()
end
