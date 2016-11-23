--[[----------------------------------------------------------------------------

  LiteWeights/LiteWeights.lua

  Copyright 2016 Mike Battersby

  Released under the terms of the GNU General Public License version 2 (GPLv2).
  See the file LICENSE.txt.

----------------------------------------------------------------------------]]--


local FramesToHook = { GameTooltip, ShoppingTooltip1, ShoppingTooltip2 }

local resistanceStats = {
    RESISTANCE0NAME,
}

local socketStats = {
    EMPTY_SOCKET_PRISMATIC,
    EMPTY_SOCKET_FEL,
    EMPTY_SOCKET_IRON,
    EMPTY_SOCKET_ARCANE,
    EMPTY_SOCKET_SHADOW,
}

local primaryStats = {
    ITEM_MOD_AGILITY_SHORT,
    ITEM_MOD_INTELLECT_SHORT,
    ITEM_MOD_STAMINA_SHORT,
    ITEM_MOD_STRENGTH_SHORT,
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT,
}

local secondaryStats = {
    ITEM_MOD_HASTE_RATING_SHORT,
    ITEM_MOD_CRIT_RATING_SHORT,
    ITEM_MOD_VERSATILITY,
    ITEM_MOD_MASTERY_RATING_SHORT,
}

local tertiaryStats = {
    ITEM_MOD_CR_SPEED_SHORT,
}

LiteWeights = CreateFrame("Frame", "LiteWeights")
LiteWeights:RegisterEvent("PLAYER_LOGIN")
LiteWeights:SetScript("OnEvent", function (f,e,...) if f[e] then f[e](f, ...) end end)

function LiteWeights:PLAYER_LOGIN()
    print("LiteWeights loaded")
    LiteWeightsDB = LiteWeightsDB or { }
    for _, f in ipairs(FramesToHook) do
        f:HookScript("OnTooltipSetItem", function (...) self:OnSetItemHook(...) end)
    end
end

function LiteWeights:ParsePawnScale(scaleString)
    
end

function LiteWeights:GetItemWeights(link)
    local weights =  {}

    for stat, value in pairs(GetItemStats(link) or {}) do
        tinsert(weights, { stat, value })
    end

    return weights
end

function LiteWeights:OnSetItemHook(tooltipFrame)
    local name, link = tooltipFrame:GetItem()

    if not name then return end

    local weights = self:GetItemWeights(link)

    if #weights == 0 then return end

    tooltipFrame:AddLine("")
    for _, lineArgs in ipairs(weights) do
        tooltipFrame:AddDoubleLine(unpack(lineArgs))
    end
end

