fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'sandbox-bridge-lib'
author 'SKITTLE6969'
description 'Shared compatibility layer that exposes QBCore/QBX style APIs on top of sandbox-base.'
version '1.2.0'

provide 'qb-core'
provide 'qbx_core'
provide 'es_extended'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/util.lua',
    'shared/compat.lua',
    'shared/vehicles.lua',
    'modules/lib.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'modules/hooks.lua',
}

client_scripts {
    'client/main.lua',
    'modules/playerdata.lua',
}

files {
    'shared/*.lua',
    'server/*.lua',
    'client/*.lua',
    'modules/*.lua',
    'README.md',
}

dependencies {
    'sandbox-base',
    'sandbox-characters',
    'sandbox-jobs',
    'sandbox-status',
    'ox_inventory',
    'oxmysql',
    'ox_lib',
}
