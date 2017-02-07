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


LiteWeights = CreateFrame("Frame", "LiteWeights")
LiteWeights:RegisterEvent("PLAYER_LOGIN")
LiteWeights:SetScript("OnEvent", function (f,e,...) if f[e] then f[e](f, ...) end end)

-- Default is the enUS Pawn stat names
LiteWeights.ItemStatNameRefs = {
    ["ITEM_MOD_STAMINA_SHORT"]              = "Stamina",

    ["ITEM_MOD_AGILITY_SHORT"]              = "Agility",
    ["ITEM_MOD_INTELLECT_SHORT"]            = "Intellect",
    ["ITEM_MOD_STRENGTH_SHORT"]             = "Strength",

    ["RESISTANCE0_NAME"]                    = "Armor",

    ["ITEM_MOD_HASTE_RATING_SHORT"]         = "HasteRating",
    ["ITEM_MOD_CRIT_RATING_SHORT"]          = "CritRating",
    ["ITEM_MOD_VERSATILITY"]                = "Versatility",
    ["ITEM_MOD_MASTERY_RATING_SHORT"]       = "MasteryRating",

    -- ["EMPTY_SOCKET_PRISMATIC"]              = "PrismaticSocket",

    ["ITEM_MOD_CR_AVOIDANCE_SHORT"]         = "Avoidance",
    ["ITEM_MOD_CR_LIFESTEAL_SHORT"]         = "Leech",
    ["ITEM_MOD_CR_SPEED_SHORT"]             = "MovementSpeed",
}

LiteWeights.ItemStatReverseMap = { }

function LiteWeights:PLAYER_LOGIN()
    LiteWeightsDB = LiteWeightsDB or { }

    local _, class = UnitClass("player")
    LiteWeightsDB[class] = LiteWeightsDB[class] or { }
    self.db = LiteWeightsDB[class]

    -- Both enUS and Localized names
    for n, v in pairs(self.ItemStatNameRefs) do
        self.ItemStatReverseMap[strlower(v)] = n
        self.ItemStatReverseMap[v] = n
        self.ItemStatReverseMap[_G[n]] = n
        self.ItemStatReverseMap[strlower(_G[n])] = n
    end

    for _, f in ipairs(FramesToHook) do
        f:HookScript("OnTooltipSetItem", function (...) self:OnSetItemHook(...) end)
    end

    SLASH_LITEWEIGHTS1 = "/lw"
    SlashCmdList["LITEWEIGHTS"] = function (...) self:SlashCmd(...) end
end

function LiteWeights:PrintHelp()
    self:PrintMessage("%s:", GAMEMENU_HELP)
    self:PrintMessage("  %s show", SLASH_LITEWEIGHTS1)
    self:PrintMessage("  %s (Pawn: v1: ...)", SLASH_LITEWEIGHTS1)
    self:PrintMessage("  %s <name> stat1=value1 ...", SLASH_LITEWEIGHTS1, DELETE)
    self:PrintMessage("  %s <name> %s", SLASH_LITEWEIGHTS1, DELETE)
    self:PrintMessage("")
    self:PrintMessage(STATS_LABEL)
    for k,v in pairs(self.ItemStatNameRefs) do
        self:PrintMessage("  %s / %s", _G[k], v)
    end
end

function LiteWeights:SlashCmd(argStr)

    local name, weights

    name = strlower(argStr)

    if name == "show" or name == strlower(SHOW)  then
        self:PrintScales()
        return
    elseif name == "pawn" then
        self:PrintScales(true)
        return
    elseif name == "" or name == "help" or name == strlower(HELP_LABEL) then
        self:PrintHelp()
        return
    elseif argStr:match("^%(") then
        name, weights = self:ParsePawnScale(argStr)
    else
        name, weights = self:ParseSimpleScale(argStr)
    end

    if name then
        self.db[name] = weights
    end
end

function LiteWeights:FormatScale(scaleName, scale, asPawn)
    local keyOrder = {}
    for k, v in pairs(scale) do
        tinsert(keyOrder, k)
    end

    sort(keyOrder, function (a, b) return scale[a] > scale[b] end)

    for i, k in ipairs(keyOrder) do
        keyOrder[i] = format(
                        "|cffcccccc%s=%0.2f|r",
                        self.ItemStatNameRefs[k], scale[k]
                        )
    end

    if asPawn then
        return format('{ Pawn: v1: "%s": %s }',
                      scaleName, table.concat(keyOrder, ', '))
    else
        return format('%s %s', scaleName, table.concat(keyOrder, ' '))
    end
end

function LiteWeights:PrintScales(asPawn)
    local i = 1
    for scaleName, scale in pairs(self.db) do
        print(format("% 2d. %s", i, self:FormatScale(scaleName, scale, asPawn)))
        i = i + 1
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
    for k, v in valueString:gmatch("(%S+)=([%d.]+)") do
        local statKey = self.ItemStatReverseMap[k]
        if statKey then
            statWeights[statKey] = tonumber(v)
        end
    end

    if next(statWeights) == nil then
        return
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

function LiteWeights:SocketScore(scale)
    return 150 * math.max(
                scale["ITEM_MOD_HASTE_RATING_SHORT"] or 0,
                scale["ITEM_MOD_CRIT_RATING_SHORT"] or 0,
                scale["ITEM_MOD_VERSATILITY"] or 0,
                scale["ITEM_MOD_MASTERY_RATING_SHORT"] or 0
            )
end

function LiteWeights:CalculateScore(stats, scale)
    local sum = 0

    for k, v in pairs(stats) do
        if k == "EMPTY_SOCKET_PRISMATIC" then
            sum = sum + self:SocketScore(scale)
        else
            sum = sum + (scale[k] or 0) * v
        end
    end

    return sum
end

local ReusableStatTable = { }

function LiteWeights:GetItemScores(link)
    local scores = { }

    wipe(ReusableStatTable)
    GetItemStats(link, ReusableStatTable)

    for statName, statWeights in pairs(self.db) do
        local score = self:CalculateScore(ReusableStatTable, statWeights)
        if score and score > 0 then
            tinsert(scores, { statName, score } )
        end
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

function LiteWeights:GetActiveChatFrame()
    for i = 1, NUM_CHAT_WINDOWS do
        local f = _G["ChatFrame"..i]
        if f and f:IsShown() then return f end
    end
    return DEFAULT_CHAT_FRAME
end

function LiteWeights:PrintMessage(...)
    local f = self:GetActiveChatFrame()
    f:AddMessage("|cff00ff00LiteWeights:|r " .. format(...))
end

function LiteWeights:Debug(...)
    self:PrintMessage(...)
end
