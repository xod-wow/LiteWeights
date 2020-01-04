--[[----------------------------------------------------------------------------

  LiteWeights/LiteWeights.lua

  Copyright 2016-2019 Mike Battersby

  Released under the terms of the GNU General Public License version 2 (GPLv2).
  See the file LICENSE.txt.

----------------------------------------------------------------------------]]--

local GEM_SECONDARY_STAT = 40

local FramesToHook = {
    GameTooltip, ShoppingTooltip1, ShoppingTooltip2,
    ItemRefTooltip, ItemRefShoppingTooltip1, ItemRefShoppingTooltip2,
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

    ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]    = "DPS",
}

LiteWeights.ItemStatReverseMap = { }

function LiteWeights:PLAYER_LOGIN()
    LiteWeightsDB = LiteWeightsDB or { }

    local _, class = UnitClass("player")
    LiteWeightsDB[class] = LiteWeightsDB[class] or { }
    self.db = LiteWeightsDB[class]

    -- DB convert
    local badKeys = {}
    for k,v in pairs(self.db) do
        if type(k) ~= "number" then
            badKeys[k] = v
        end
    end
    for k,v in pairs(badKeys) do
        self.db[k] = nil
        table.insert(self.db, { ['name'] = k, ['weights'] = v })
    end
    table.sort(self.db, function (a, b) return a.name < b.name end)

    -- Both enUS and Localized names
    for n, v in pairs(self.ItemStatNameRefs) do
        self.ItemStatReverseMap[strlower(v)] = n
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
    self:PrintMessage("  %s add (Pawn: v1: ...)", SLASH_LITEWEIGHTS1)
    self:PrintMessage("  %s add <name> stat1=value1 ...", SLASH_LITEWEIGHTS1, DELETE)
    self:PrintMessage("  %s del <name>", SLASH_LITEWEIGHTS1, DELETE)
end

function LiteWeights:PrintStats()
    self:PrintMessage(STATS_LABEL)
    for k,v in pairs(self.ItemStatNameRefs) do
        self:PrintMessage("  %s / %s", _G[k], v)
    end
end

function LiteWeights:SlashCmd(arg)

    if arg == "show" or arg == strlower(SHOW)  then
        self:PrintScales()
        return
    end

    if arg == "" or arg == "help" or arg == strlower(HELP_LABEL) then
        self:PrintHelp()
        return
    end

    if arg == "wipe" then
        self:PrintMessage("Deleting all weights.")
        table.wipe(self.db)
        return
    end

    local arg1, arg2 = string.split(' ', arg, 2)

    if arg1 == "add" or arg1 == strlower(ADD) then
        local name, weights

        if arg2:match("^%(") then
            name, weights = self:ParsePawnScale(arg2)
        else
            name, weights = self:ParseSimpleScale(arg2)
        end
        if name and weights then
            self:PrintMessage("Adding weight " .. name)
            table.insert(self.db, { ['name'] = name, ['weights'] = weights })
            table.sort(self.db, function (a, b) return a.name < b.name end)
        end
        return
    end

    if arg1 == "del" or arg1 == "delete" or arg1 == strlower(DELETE) then
        local n = tonumber(arg2)
        if n and self.db[n] then
            local name = self.db[n]
            self:PrintMessage("Deleting weight %d: %s", n, self.db[n].name)
            table.remove(self.db, n)
        end
        return
    end
        
    self:PrintHelp()
end

function LiteWeights:PrintWeights(weights)
    local keyOrder = {}
    for k, v in pairs(weights) do
        table.insert(keyOrder, k)
    end

    table.sort(keyOrder, function (a, b) return weights[a] > weights[b] end)

    for i, k in ipairs(keyOrder) do
        self:PrintMessage(
                    "        |cffcccccc%s = %0.2f|r",
                    self.ItemStatNameRefs[k], weights[k]
                )
    end
end

function LiteWeights:PrintScales()
    for i, scale in ipairs(self.db) do 
        self:PrintMessage(format("% 2d. %s", i, scale.name))
        self:PrintWeights(scale.weights)
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
        local nameFinished
        local nameWords, valueWords = {}, {}
        for word in scaleString:gmatch('%S+') do
            if word:find('=') then nameFinished = true end
            if nameFinished then
                table.insert(valueWords, word)
            else
                table.insert(nameWords, word)
            end
        end
        scaleName = table.concat(nameWords, ' ')
        valueString = table.concat(valueWords, ' ')
    end

    if not scaleName or not valueString then
        self:PrintMessage("Invalid string, aborting.")
        return
    end

    local statWeights = { }
    for k, v in valueString:gmatch("(%S+)=([%d.]+)") do
        local n = k:len()
        for stat, statKey in pairs(self.ItemStatReverseMap) do
            if stat:sub(1,n):lower() == k:lower() then
                statWeights[statKey] = tonumber(v)
                break
            end
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
    return GEM_SECONDARY_STAT * math.max(
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

    for _, scale in ipairs(self.db) do
        local score = self:CalculateScore(ReusableStatTable, scale.weights)
        if score and score > 0 then
            table.insert(scores, { scale.name, string.format('%0.2f', score) } )
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

function LiteWeights:PrintMessage(...)
    local f = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
    f:AddMessage("|cff00ff00LiteWeights:|r " .. format(...))
end

function LiteWeights:Debug(...)
    self:PrintMessage(...)
end
