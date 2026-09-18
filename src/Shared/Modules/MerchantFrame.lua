--[[
	Classic UI Restoration - Vendor Window

	Blizzard's merchant window still draws the vanilla panel (the
	UI-Merchant-* art with the portrait ring), so only what Dragonflight
	changed in it is put back:

	- the repair buttons: the Repair Item / Repair All / Guild Repair icons
	  are the repainted "SpellIcon-256x256-Repair*" atlases sitting on a
	  UI-EmptySlot ring. Vanilla drew Interface\MerchantFrame\UI-Merchant-
	  RepairIcons (a 128x64 file with three 36px cells: hammer, anvil with a
	  "+", gold anvil) whose bevel frame is part of the art, so the icons are
	  swapped for those cells and the slot ring behind them is hidden.
	- the Sell All Junk button (retail only, there is no vanilla icon): it
	  keeps its function and gets a matching vanilla-style cell, bundled as
	  Textures\UI-Merchant-SellJunk.tga (a vanilla bag with a coin inside the
	  same bevel frame), so the row reads as one set.
	- the buyback slot: retail draws an "undo" arrow (common-icon-undo) over
	  the bought-back item and shrinks its stack count to make room; vanilla
	  showed the item icon plainly. The arrow frame is hidden and the count
	  is kept at full size (Blizzard re-shrinks it on every MERCHANT_UPDATE,
	  so SetItemButtonScale is hooked).

	The icons are the buttons' own .Icon textures (Blizzard only desaturates
	them when repairs are impossible, which keeps working), so everything is
	plain widget state and the module can be toggled live: the retail atlases
	are recorded the first time and put back on disable.
]]

local _, ns = ...
local T = ns.T

T.MERCHANT_REPAIR_ICONS = "Interface\\MerchantFrame\\UI-Merchant-RepairIcons"
T.MERCHANT_SELL_JUNK = "Interface\\AddOns\\" .. ns.ADDON_NAME .. "\\Textures\\UI-Merchant-SellJunk"

local module = ns:RegisterModule({
	key = "merchant",
	name = "Vendor Window",
	tooltip = "Restores the vanilla icons in the vendor window: the classic hammer / anvil / gold anvil repair buttons (with a matching classic-style Sell All Junk button) and the plain buyback item slot without the modern undo arrow.",
	live = true,
})

-- UI-Merchant-RepairIcons is 128x64 with three 36x36 cells in its top rows.
local CELL_W, CELL_H = 36 / 128, 36 / 64
local CELLS = {
	-- button name -> left edge of its cell (in cells)
	MerchantRepairItemButton = 0,      -- hammer
	MerchantRepairAllButton = 1,       -- anvil with "+"
	MerchantGuildBankRepairButton = 2, -- gold anvil
}
-- The bundled junk icon is a 64x64 file with the 36x36 cell at the top left.
local JUNK_W, JUNK_H = 36 / 64, 36 / 64

local enabled = false
local hooked = false
local retail = setmetatable({}, { __mode = "k" }) -- button -> retail state

-- The unnamed UI-EmptySlot ring Blizzard draws behind each icon.
local function GetSlotRing(button)
	for _, region in ipairs({ button:GetRegions() }) do
		if region ~= button.Icon and region:GetObjectType() == "Texture" and region:GetDrawLayer() == "BACKGROUND" then
			return region
		end
	end
	return nil
end

local function RememberRetail(button)
	if retail[button] then return end
	local icon = button.Icon
	retail[button] = {
		atlas = icon:GetAtlas(),
		ring = GetSlotRing(button),
	}
end

local function ApplyIcon(button, path, left, right, top, bottom)
	if not button or not button.Icon then return end
	RememberRetail(button)
	ns.SetTexture(button.Icon, path, left, right, top, bottom)
	local ring = retail[button].ring
	if ring then ring:SetAlpha(0) end
end

local function RestoreIcon(button)
	local state = button and retail[button]
	if not state then return end
	button.Icon:SetTexCoord(0, 1, 0, 1)
	if state.atlas then
		button.Icon:SetAtlas(state.atlas)
	end
	if state.ring then state.ring:SetAlpha(1) end
end

local function GetBuybackButton()
	return MerchantBuyBackItem and MerchantBuyBackItem.ItemButton
end

local function ApplyAll()
	for name, cell in pairs(CELLS) do
		ApplyIcon(_G[name], T.MERCHANT_REPAIR_ICONS, cell * CELL_W, (cell + 1) * CELL_W, 0, CELL_H)
	end
	ApplyIcon(MerchantSellAllJunkButton, T.MERCHANT_SELL_JUNK, 0, JUNK_W, 0, JUNK_H)

	local buyback = GetBuybackButton()
	if buyback then
		if buyback.UndoFrame then buyback.UndoFrame:Hide() end
		buyback:SetItemButtonScale(1)
	end
end

local function RestoreAll()
	for name in pairs(CELLS) do
		RestoreIcon(_G[name])
	end
	RestoreIcon(MerchantSellAllJunkButton)

	local buyback = GetBuybackButton()
	if buyback then
		if buyback.UndoFrame then buyback.UndoFrame:Show() end
		buyback:SetItemButtonScale(0.65) -- Blizzard's MerchantItemBuybackButton_OnLoad value
	end
end

---------------------------------------------------------------------------
-- Module entry points
---------------------------------------------------------------------------

function module:Enable()
	if not MerchantRepairItemButton or not MerchantRepairItemButton.Icon then return end
	if not ns.HasTexture(T.MERCHANT_REPAIR_ICONS) then
		ns.Print("This client does not ship the classic vendor repair icons; the retail vendor window is kept.")
		return
	end
	enabled = true
	if not hooked then
		hooked = true
		local buyback = GetBuybackButton()
		if buyback and buyback.SetItemButtonScale then
			-- Blizzard shrinks the stack count (0.65) under its undo arrow on
			-- every MERCHANT_UPDATE; the arrow is hidden, so keep it full size.
			-- The re-call is a no-op for the hook (scale == 1).
			ns.Hook(buyback, "SetItemButtonScale", function(self, scale)
				if enabled and scale ~= 1 then
					self:SetItemButtonScale(1)
				end
			end)
		end
	end
	ApplyAll()
end

function module:Disable()
	enabled = false
	RestoreAll()
end
