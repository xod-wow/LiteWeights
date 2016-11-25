--[[----------------------------------------------------------------------------

  LiteWeights/LiteWeights.lua

  Copyright 2016 Mike Battersby

  Released under the terms of the GNU General Public License version 2 (GPLv2).
  See the file LICENSE.txt.

----------------------------------------------------------------------------]]--

local FramesToHook = {
    GameTooltip, ShoppingTooltip1, ShoppingTooltip2,
    ItemRefTooltip, ItemRefShoppingTooltip1, ItemRefShoppingTooltip2,
    WorldMapTooltip, WorldMapCompareTooltip1, WorldMapCompareTooltip2,
}

-- Default is the enUS Pawn stat names

local ItemStatNameRefs = {
    ["ITEM_MOD_STAMINA_SHORT"]              = "Stamina",

    ["ITEM_MOD_AGILITY_SHORT"]              = "Agility",
    ["ITEM_MOD_INTELLECT_SHORT"]            = "Intellect",
    ["ITEM_MOD_STRENGTH_SHORT"]             = "Strength",

    ["RESISTANCE0NAME"]                     = "Armor",

    ["ITEM_MOD_HASTE_RATING_SHORT"]         = "HasteRating",
    ["ITEM_MOD_CRIT_RATING_SHORT"]          = "CritRating",
    ["ITEM_MOD_VERSATILITY"]                = "Versatility",
    ["ITEM_MOD_MASTERY_RATING_SHORT"]       = "MasteryRating",

    ["EMPTY_SOCKET_PRISMATIC"]              = "PrismaticSocket",

    ["ITEM_MOD_CR_AVOIDANCE_SHORT"]         = "Avoidance",
    ["ITEM_MOD_CR_LEECH_SHORT"]             = "Leech",
    ["ITEM_MOD_CR_SPEED_SHORT"]             = "MovementSpeed",
}

local ItemStatReverseMap = { }

LiteWeights = CreateFrame("Frame", "LiteWeights")
LiteWeights:RegisterEvent("PLAYER_LOGIN")
LiteWeights:SetScript("OnEvent", function (f,e,...) if f[e] then f[e](f, ...) end end)

function LiteWeights:PLAYER_LOGIN()
    LiteWeightsDB = LiteWeightsDB or { }

    local _, class = UnitClass("player")
    LiteWeightsDB[class] = LiteWeightsDB[class] or { }
    self.db = LiteWeightsDB[class]

    -- Both enUS and Localized names
    for n, v in ipairs(ItemStatNameRefs) do
        ItemStatReverseMap[v] = n
        ItemStatReverseMap[_G[n]] = n
    end

    for _, f in ipairs(FramesToHook) do
        f:HookScript("OnTooltipSetItem", function (...) self:OnSetItemHook(...) end)
    end

    SLASH_LITEWEIGHTS1 = "/lw"
    SlashCmdList["LITEWEIGHTS"] = function (...) self:SlashCmd(...) end
end

function LiteWeights:SlashCmd(argStr)
    local name, weights

    if argStr:match("^%(") then
        name, weights = self:ParsePawnScale(argStr)
    else
        name, weights = self:ParseSimpleScale(argStr)
    end

    if name then
        self.db[name] = weights
    end
end

-- Simple scales just have a name followed by many Stat=Val strings. The name
-- can have spaces in it, so we just stop appending name parts once we get
-- something with an equals sign in it.

function LiteWeights:ParseSimpleScale(scaleString)

    local scaleName, valueString

    if scaleString:match('^"') then
        scaleName, valueString = scaleString:match('^"([^"]+)"%s+(.*)$')
    elseif scaleString:match("^'") then
        scaleName, valueString = scaleString:match("^'([^']+)'%s+(.*)$")
    else
        scaleName, valueString = scaleString:match('^(%S+)%s+(%S+)$')
    end

    if not scaleName or not valueString then
        return
    end

    if valueString == DELETE or valueString == "delete" then
        return scaleName, nil
    end

    local statWeights = { }
    for k, v in valueString:gmatch("([^=%s]+)=[%d.]+)") do
        local statKey = ItemStatReverseMap[v]
        if statKey then
            statWeights[statKey] = tonumber(v)
        end
    end
    return scaleName, statWeights
end

-- Pawn scales look like this, with arbitary whitespace anywhere.
--- ( Pawn: v1: "PvE-Demon_hunter-Havoc-Noxxic": CritRating=7.54, MasteryRating=3.04, Agility=9.04, HasteRating=4.54, Versatility=6.04 )
function LiteWeights:ParsePawnScale(scaleString)
    local scaleName, valueString = scaleString:match('^%(%s*Pawn%s*:%s*v1%s*:%s*"([^"]+)"%s*:%s*(.*)%)$')
    if scaleName and valueString then
        local simpleString = format('"%s" %s', scaleName, valueString)
        return self:ParseSimpleScale(simpleString)
    end
end

function LiteWeights:CalculateScore(stats, scale)
    local sum = 0

    for k, v in pairs(stats) do
        sum = sum + (scale[k] or 0) * v
    end

    return sum
end

local ReusableStatTable = { }

function LiteWeights:GetItemScores(link)
    local scores = { }

    wipe(ReusableStatTable)
    GetItemStats(link, ReusableStatTable)

    for n, s in pairs(self.db) do
        tinsert(scores, { n, self:CalculateScore(ReusableStatTable, s) })
    end

    return scores
end

function LiteWeights:OnSetItemHook(tooltipFrame)
    local name, link = tooltipFrame:GetItem()

    if not name then return end

    local scores = self:GetItemScores(link)

    if #scores == 0 then return end

    tooltipFrame:AddLine("")
    for _, lineArgs in ipairs(scores) do
        tooltipFrame:AddDoubleLine(unpack(lineArgs))
    end
end

