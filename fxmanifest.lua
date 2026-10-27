fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'
author 'Poker Studio'
description 'Responsive VORP pinboards with persistent image notes'
version '1.0.0'

shared_scripts {
    'config.lua',
    'locales.lua'
}
client_script 'client/main.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/pinboard-bg.png',
    'html/assets/hud_menu_5a_red_dirty.png',
    'html/assets/hud_menu_black.png',
    'html/assets/bgPanel.png',
    'html/assets/menu_header_1a.png',
    'html/assets/selection_box_bg_1d.png',
    'html/assets/divider_line.png',
    'html/assets/selection_box_badge_red.png',
    'html/assets/selection_box_badge_green.png',
    'html/assets/selection_box_grey.png',
    'html/assets/selection_box_badge_gold.png',
    'html/assets/foglio_fascicolo.png'
}

dependencies {
    'vorp_core',
    'oxmysql'
}
