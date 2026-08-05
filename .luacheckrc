-- Luacheck config. Run `luacheck .` in this folder.
std = "lua51"
max_line_length = false
exclude_files = { ".release/" }

ignore = {
    "212", -- unused argument (event/script handlers)
    "213", -- unused loop variable
}

globals = {
    "TonguesOfAzerothDB",
    "SLASH_OLDGODTONGUES1", "SLASH_OLDGODTONGUES2", "SLASH_OLDGODTONGUES3",
}

read_globals = {
    "CreateFrame", "UIParent", "DEFAULT_CHAT_FRAME", "GetAddOnMetadata",
    "SlashCmdList", "hooksecurefunc", "GetTime", "SendChatMessage",
    "InterfaceOptions_AddCategory", "InterfaceOptionsFrame_OpenToCategory",
    "InterfaceOptionsFramePanelContainer",
    "UIDropDownMenu_Initialize", "UIDropDownMenu_SetWidth", "UIDropDownMenu_SetText",
    "UIDropDownMenu_SetSelectedValue", "UIDropDownMenu_CreateInfo", "UIDropDownMenu_AddButton",
}
