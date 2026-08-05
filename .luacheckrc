-- Luacheck config. Run `luacheck .` in this folder.
std = "lua51"
max_line_length = false
exclude_files = { ".release/" }

ignore = {
    "212", -- unused argument (event/script handlers)
    "213", -- unused loop variable
}

globals = {
    "TonguesOfAzerothDB", "OldGodTonguesDB",
    "SLASH_TONGUESOFAZEROTH1", "SLASH_TONGUESOFAZEROTH2", "SLASH_TONGUESOFAZEROTH3",
}

read_globals = {
    -- core
    "CreateFrame", "UIParent", "DEFAULT_CHAT_FRAME", "SlashCmdList",
    "hooksecurefunc", "GetTime", "GetBuildInfo", "SendChatMessage",
    "UnitName", "UnitIsDead", "PlaySoundFile", "ChatTypeInfo", "NUM_CHAT_WINDOWS",
    -- metadata (both eras)
    "GetAddOnMetadata", "C_AddOns",
    -- addon messaging (both eras)
    "SendAddonMessage", "RegisterAddonMessagePrefix", "C_ChatInfo",
    -- group state (both eras)
    "IsInRaid", "IsInGroup", "GetNumRaidMembers", "GetNumPartyMembers", "GetNumGroupMembers",
    -- legacy options API (3.3.5a)
    "InterfaceOptions_AddCategory", "InterfaceOptionsFrame_OpenToCategory",
    "InterfaceOptionsFramePanelContainer", "InterfaceAddOnsList_Update",
    -- modern options API
    "Settings",
}
