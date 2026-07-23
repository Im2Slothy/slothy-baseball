fx_version 'cerulean'
game 'gta5'

author 'Im2Slothy#0'
description 'Free and open-source Slothy Baseball batting practice'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/camera.lua',
    'client/batting.lua',
    'client/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

