local addonName = ...
local DEFAULTS = {
    minimumQuality = 3, -- Raro (azul); também inclui Épico e Lendário.
    sound = "LEVELUP",
    enabled = true,
}
local db
local sounds = {
    LEVELUP = { label = "Subida de nível", kit = SOUNDKIT and SOUNDKIT.LEVELUP or 888 },
    RAID = { label = "Alerta de raide", kit = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959 },
    READY = { label = "Pronto", kit = SOUNDKIT and SOUNDKIT.READY_CHECK or 8960 },
    BELL = { label = "Sino", kit = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856 },
}
local qualityNames = { [3] = "Raro (azul)", [4] = "Épico (roxo)", [5] = "Lendário (laranja)" }
local qualityColors = { [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" }
local lastAlert = 0

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffAlexAlert:|r " .. message)
end

local function PlaySelectedSound()
    local sound = sounds[db.sound] or sounds.LEVELUP
    if PlaySound then PlaySound(sound.kit, "Master") end
end

local function GetQuality(itemLink, itemID)
    if itemLink then
        local color = itemLink:match("|c(%x%x%x%x%x%x%x%x)|Hitem:")
        if color then
            for quality, expected in pairs(qualityColors) do
                if color:lower() == expected then return quality end
            end
        end
    end
    if C_Item and C_Item.GetItemQualityByID then
        local ok, quality = pcall(C_Item.GetItemQualityByID, itemID)
        if ok and quality then return quality end
    end
    if GetItemInfo then
        local _, _, quality = GetItemInfo(itemID)
        if quality then return quality end
    end
end

local function NPCIDFromGUID(guid)
    if not guid then return end
    local kind, _, _, _, _, npcID = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(npcID) end
end

local function LearnCurrentLoot()
    if not db or not GetNumLootItems or not GetLootSlotLink then return end
    local found = {}
    for slot = 1, GetNumLootItems() do
        local guid
        if GetLootSourceInfo then guid = GetLootSourceInfo(slot) end
        local npcID = NPCIDFromGUID(guid)
        local link = GetLootSlotLink(slot)
        local itemID = link and tonumber(link:match("|Hitem:(%d+):"))
        if npcID and itemID then
            found[npcID] = found[npcID] or {}
            found[npcID][itemID] = true
        end
    end
    for npcID, items in pairs(found) do
        db.npcLoot[npcID] = db.npcLoot[npcID] or {}
        local known = {}
        for _, itemID in ipairs(db.npcLoot[npcID]) do known[itemID] = true end
        for itemID in pairs(items) do
            if not known[itemID] then
                table.insert(db.npcLoot[npcID], itemID)
                known[itemID] = true
            end
        end
    end
end

local function IsSelectedQuality(quality)
    return quality and quality >= (db.minimumQuality or 3)
end

local function OnLootMessage(message)
    if not db.enabled then return end
    local itemID = message:match("|Hitem:(%d+):")
    if not itemID then return end
    itemID = tonumber(itemID)
    local quality = GetQuality(message, itemID)
    if not IsSelectedQuality(quality) then return end

    local now = GetTime()
    local shownName = message:match("|h%[([^%]]+)%]|h") or ("Item " .. itemID)
    RaidNotice_AddMessage(RaidWarningFrame, "AlexAlert: " .. shownName, ChatTypeInfo["RAID_WARNING"], 3)
    if now - lastAlert >= 1.2 then
        lastAlert = now
        PlaySelectedSound()
    end
end

local function ParseNPCID(unit)
    if not unit or not UnitGUID then return end
    return NPCIDFromGUID(UnitGUID(unit))
end

local function AppendLootToTooltip(tooltip)
    if not db.enabled then return end
    local _, unit = tooltip:GetUnit()
    if not unit or not UnitExists(unit) then unit = "mouseover" end
    if not UnitExists(unit) or not UnitCanAttack("player", unit) then return end
    local npcID = ParseNPCID(unit)
    if not npcID then return end

    local loot = db.npcLoot and db.npcLoot[npcID]
    local staticLoot = AlexAlertLoot and AlexAlertLoot[npcID]
    if staticLoot then
        loot = loot or {}
        local known = {}
        for _, itemID in ipairs(loot) do known[itemID] = true end
        for _, itemID in ipairs(staticLoot) do
            if not known[itemID] then loot[#loot + 1] = itemID; known[itemID] = true end
        end
    end
    if not loot or #loot == 0 then return end
    local matching = {}
    for _, itemID in ipairs(loot) do
        local _, _, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
        if IsSelectedQuality(quality) then
            local name, link = GetItemInfo(itemID)
            if name then matching[#matching + 1] = { name = name, link = link, quality = quality, icon = icon, id = itemID } end
        end
    end
    if #matching == 0 then return end
    table.sort(matching, function(a, b) return a.quality > b.quality end)
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff33ccffAlexAlert — possíveis drops|r")
    local shown = math.min(#matching, 8)
    for index = 1, shown do
        local item = matching[index]
        local color = qualityColors[item.quality] or "ffffffff"
        tooltip:AddLine((item.icon and ("|T" .. item.icon .. ":14:14:0:0|t ") or "") .. "|c" .. color .. (item.link or item.name or ("Item " .. item.id)) .. "|r")
    end
    if #matching > shown then tooltip:AddLine("e mais " .. (#matching - shown) .. " item(ns)") end
    tooltip:Show()
end

local function BuildOptions()
    local panel = CreateFrame("Frame", "AlexAlertOptions", InterfaceOptionsFramePanelContainer)
    panel.name = "AlexAlert"
    panel:SetScript("OnShow", function(self)
        if self.built then return end
        self.built = true
        local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("AlexAlert — alertas de loot")
        local desc = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        desc:SetText("Avise quando você receber itens e filtre a raridade mínima.")

        local enabled = CreateFrame("CheckButton", "AlexAlertEnabledCheckButton", self, "InterfaceOptionsCheckButtonTemplate")
        enabled:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -4, -16)
        local enabledLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 2, 0)
        enabledLabel:SetText("Ativar AlexAlert")
        enabled:SetChecked(db.enabled)
        enabled:SetScript("OnClick", function(button) db.enabled = button:GetChecked() and true or false end)

        local rarity = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        rarity:SetSize(220, 24)
        rarity:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 4, -12)
        local function UpdateRarityLabel() rarity:SetText("Raridade mínima: " .. qualityNames[db.minimumQuality]) end
        UpdateRarityLabel()
        rarity:SetScript("OnClick", function()
            db.minimumQuality = db.minimumQuality == 3 and 4 or (db.minimumQuality == 4 and 5 or 3)
            UpdateRarityLabel()
            Print("raridade mínima: " .. qualityNames[db.minimumQuality] .. ".")
        end)
        local rarityHelp = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        rarityHelp:SetPoint("LEFT", rarity, "RIGHT", 10, 0)
        rarityHelp:SetText("Inclui essa qualidade e as superiores.")

        local sound = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        sound:SetSize(220, 24)
        sound:SetPoint("TOPLEFT", rarity, "BOTTOMLEFT", 0, -12)
        local soundKeys = { "LEVELUP", "RAID", "READY", "BELL" }
        local function UpdateSoundLabel() sound:SetText("Som: " .. sounds[db.sound].label) end
        UpdateSoundLabel()
        sound:SetScript("OnClick", function()
            local index = 1
            for i, key in ipairs(soundKeys) do if key == db.sound then index = i break end end
            db.sound = soundKeys[index % #soundKeys + 1]
            UpdateSoundLabel()
            PlaySelectedSound()
        end)
        local test = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        test:SetSize(100, 24)
        test:SetPoint("LEFT", sound, "RIGHT", 8, 0)
        test:SetText("Testar som")
        test:SetScript("OnClick", PlaySelectedSound)

        local note = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        note:SetPoint("TOPLEFT", sound, "BOTTOMLEFT", 0, -18)
        note:SetWidth(540)
        note:SetJustifyH("LEFT")
        note:SetText("A prévia de drops precisa dos IDs de itens cadastrados em Data.lua. O jogo não disponibiliza a tabela completa de loot dos NPCs para addons.")
    end)
    if InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel) end
end

local function OpenOptions()
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("AlexAlert")
        InterfaceOptionsFrame_OpenToCategory("AlexAlert")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("LOOT_OPENED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then return end
        AlexAlertDB = AlexAlertDB or {}
        for key, value in pairs(DEFAULTS) do if AlexAlertDB[key] == nil then AlexAlertDB[key] = value end end
        db = AlexAlertDB
        db.npcLoot = db.npcLoot or {}
        BuildOptions()
        if GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnTooltipSetUnit", AppendLootToTooltip) end
        SLASH_ALEXALERT1 = "/alexa"
        SlashCmdList.ALEXALERT = function() OpenOptions() end
        Print("carregado. Use /alexa para configurar.")
    elseif event == "CHAT_MSG_LOOT" and db then
        OnLootMessage(...)
    elseif event == "LOOT_OPENED" and db then
        LearnCurrentLoot()
    end
end)
