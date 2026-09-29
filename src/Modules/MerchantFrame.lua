--[[
	Forevermore Classic UI - Vendor Window icons (part of Window Frames)

	The vendor window gets the pre-Dragonflight frame, close button and tabs
	from the Window Frames option (Windows.lua); what Dragonflight changed
	inside it is put back here:

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
	them when repairs are impossible, which keeps working). Applied with the
	Window Frames option at login (reload to switch off).
]]

local _, ns = ...
local T = ns.T

T.MERCHANT_REPAIR_ICONS = "Interface\\MerchantFrame\\UI-Merchant-RepairIcons"
T.MERCHANT_SELL_JUNK = "Interface\\AddOns\\" .. ns.ADDON_NAME .. "\\Textures\\UI-Merchant-SellJunk"

local module = ns:RegisterModule({
	key = "merchant",
	name = "Vendor Window Icons",
	parent = "windows",
	live = false,
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

-- The unnamed UI-EmptySlot ring Blizzard draws behind each icon.
local function GetSlotRing(button)
	for _, region in ipairs({ button:GetRegions() }) do
		if region ~= button.Icon and region:GetObjectType() == "Texture" and region:GetDrawLayer() == "BACKGROUND" then
			return region
		end
	end
	return nil
end

local function ApplyIcon(button, path, left, right, top, bottom)
	if not button or not button.Icon then return end
	ns.SetTexture(button.Icon, path, left, right, top, bottom)
	local ring = GetSlotRing(button)
	if ring then ring:SetAlpha(0) end
end

---------------------------------------------------------------------------
-- Module entry point
---------------------------------------------------------------------------

function module:Apply()
	if not MerchantRepairItemButton or not MerchantRepairItemButton.Icon then return end
	if not ns.HasTexture(T.MERCHANT_REPAIR_ICONS) then
		ns.Print("This client does not ship the classic vendor repair icons; the vendor window keeps its modern icons.")
		return
	end
	for name, cell in pairs(CELLS) do
		ApplyIcon(_G[name], T.MERCHANT_REPAIR_ICONS, cell * CELL_W, (cell + 1) * CELL_W, 0, CELL_H)
	end
	ApplyIcon(MerchantSellAllJunkButton, T.MERCHANT_SELL_JUNK, 0, JUNK_W, 0, JUNK_H)

	local buyback = MerchantBuyBackItem and MerchantBuyBackItem.ItemButton
	if not buyback then return end
	if buyback.UndoFrame then buyback.UndoFrame:Hide() end
	if buyback.SetItemButtonScale then
		buyback:SetItemButtonScale(1)
		-- Blizzard shrinks the stack count (0.65) under its undo arrow on
		-- every MERCHANT_UPDATE; the arrow is hidden, so keep it full size.
		-- The re-call is a no-op for the hook (scale == 1).
		ns.Hook(buyback, "SetItemButtonScale", function(self, scale)
			if scale ~= 1 then
				self:SetItemButtonScale(1)
			end
		end)
	end
end
