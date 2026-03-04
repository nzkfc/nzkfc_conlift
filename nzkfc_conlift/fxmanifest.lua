fx_version 'cerulean'
game 'gta5'

name        'nzkfc_conlift'
description 'Construction site lift'
author      'nzkfc'
version     '1.0.0'

dependencies {
    'ox_lib',
    'ox_target',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}
