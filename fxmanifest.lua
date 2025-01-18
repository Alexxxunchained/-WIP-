fx_version 'cerulean'
game 'gta5'

author 'MySword傅剑寒'
description '[浩劫:DayZ] 浩劫载具系统 MTASA:DayZ like vehicle system WIP'
version '1.0.0'

shared_script {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

client_script {
    'client/*.lua'
}

lua54 'yes'
use_fxv2_oal 'yes'
