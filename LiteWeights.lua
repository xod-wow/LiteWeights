--[[----------------------------------------------------------------------------

  LiteWeights/LiteWeights.lua

  Copyright 2016 Mike Battersby

  Released under the terms of the GNU General Public License version 2 (GPLv2).
  See the file LICENSE.txt.

----------------------------------------------------------------------------]]--

LiteWeights = CreateFrame("Frame", "LiteWeights")
LiteWeights:RegisterEvent("PLAYER_LOGIN")
LiteWeights:SetScript("OnEvent", function (f,e,...) if f[e] then f[e](f, ...) end end)

function LiteWeights:PLAYER_LOGIN()
    print("LiteWeights loaded")
    LiteWeightsDB = LiteWeightsDB or { }
    GameTooltip:HookScript("OnTooltipSetItem", function (...) self:OnSetItemHook(...) end)
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
    -- tooltipFrame:Show()
end

