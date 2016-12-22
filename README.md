# PingLimit addon for [Project Cars Dedicated Server](http://forum.projectcarsgame.com/showthread.php?22370-Dedicated-Server-HowTo-(Work-in-Progress))
____________

Introduction
------------

This software is an **addon** for Project Cars game, it's written in **Lua** language and is installed directly in **Dedicated Server**. The objective is to keep just players with an acceptable [ping (round-trip-time)](https://en.wikipedia.org/wiki/Round-trip_delay_time), kicking players with ping above the limit configured.

Default configuration
----------
The configuration is stored in **lua_config/epinter_pinglimit_config.json** (the file is auto generated when server starts first time with addon enabled). By default, the addon is configured with this parameters:

```
// ping limit - round trip time in milliseconds
limit: 350

// how much samples of ping data we will use to decide if the player is above the limit or not
samples: 45

// Percentage. The tolerance we should have considering the total number of ping above the limit.
// With a tolerance of 20%, all occurences of ping above the limit will have 5x the weight of a ping below the limit.
tolerance: 10

//debug
debug: 0

//When 0, DON'T kick the session host
kickHost: 0

//Time in seconds to keep a player banned after kick.
//10 minutes is recommended, the server seems to ignore something like 1 or 2 minutes.
tempBanTime: 600
```

Installation
----------
All the files must be inside the directory **lua/epinter_pinglimit/**. DON'T rename any files, or the addon won't work. The directory structure should be like this:
```
DedicatedServerCmd
readme.txt
steam_appid.txt
lua/
lua_config/
lua/epinter_pinglimit/
lua/epinter_pinglimit/epinter_pinglimit.json
lua/epinter_pinglimit/README.md
lua/epinter_pinglimit/epinter_pinglimit.lua
lua/epinter_pinglimit/epinter_pinglimit_default_config.json
```

With the files in the correct directory, the addon must be enabled in server.cfg:

```
luaApiAddons : [
    // Core server bootup scripts and helper functions. This will be always loaded first even if not specified here because it's an implicit dependency of all addons.
    "sms_base",
    // Automatic race setup rotation.
    //"sms_rotate",
    // Sends greetings messages to joining members, optionally with race setup info, optionally also whenever returning back to lobby post-race.
    //"sms_motd",
    // Tracks various stats on the server - server, session and player stats.
    //"sms_stats",
    //PingLimit
    "epinter_pinglimit",
]
```
The sms_base, sms_rotate,sms_motd and sms_stats are there by default, the line added to **luaApiAddons** is **"epinter_pinglimit",**
