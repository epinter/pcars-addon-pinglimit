--[[
PingLimit Addon for Project Cars Dedicated Server

Copyright (C) 2016  Emerson Pinter <dev@pinter.com.br>

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

--]]

local addon_storage = ...
local config = addon_storage.config

local revision=1
local major,minor=GetAddonVersion()
local VERSION=string.format("%d.%d.%d",major,minor,revision)
local to_kick = {}
local memberPing = {}
local memberNotified = {}
local kickDelay = 7
local notifyInterval = 5
local tolerance = (100/config.tolerance)
local logTag = "PINGLIMITADDON: "
local logPrioDebug = "DEBUG"
local logPrioInfo = "INFO"
local logPrioError = "ERROR"
local scheduled_sends_motd = {}


if type( config.whitelist ) ~= "table" then config.whitelist = {} end

local function pinglimit_getlogprefix(priority)
	return (os.date("[%Y-%m-%d %H:%M:%S] ")..(priority..": ")..logTag)
end

local function pinglimit_log( msg, priority )
	if not priority or string.len(priority) == 0 then
		priority = logPrioInfo
	end
	if (config.debug == 1 and priority == logPrioDebug) or priority ~= logPrioDebug then
		print(pinglimit_getlogprefix(priority)..msg)
	end
end

local function pinglimit_dump( table, logpriority )
	if table == nil then
		return
	end
	if not logpriority or string.len(logpriority) == 0 then
		logpriority = logPrioDebug
	end
	if (config.debug == 1 and logpriority == logPrioDebug) or logpriority ~= logPrioDebug then
		dump(table, pinglimit_getlogprefix(logpriority).."    ")
	end
end

local function pinglimit_send_motd_to( refid )
        local send_time = GetServerUptimeMs() + 1000
        if refid then
                scheduled_sends_motd[ refid ] = send_time
        else
                for k,_ in pairs( session.members ) do
                        scheduled_sends_motd[ k ] = send_time
                end
        end
end

local function pinglimit_send_motd_now( refid )
	SendChatToMember(refid,"* PingLimit addon, version "..VERSION.." by EPinter * https://github.com/epinter/pcars-addon-pinglimit *")
	SendChatToMember(refid,"* PLAYERS WITH PING ABOVE "..config.limit.."ms WILL BE KICKED *")
end

if config.samples < 10 then
	pinglimit_log("samples parameter is too low", logPrioError);
end

local function pinglimit_sendChatToMember( refid, msg )
	pinglimit_log("TO "..refid..": "..msg, logPrioDebug)
	SendChatToMember(refid,msg)
end

local function pinglimit_sendChatToAll( msg )
	pinglimit_log(msg)
	SendChatToAll(msg)
end


local function pinglimit_isSteamUserWhitelisted ( steamId )
	for k,v in pairs ( config.whitelist ) do
		if (""..v) == steamId then
			return true
		end
	end
	return false
end

local function isEveryoneHighPing()
        local countOverLimit = 0
        local countTotal = 0
        for k,v in pairs ( memberPing ) do
                countTotal = countTotal + 1
                if v > config.limit then
                        countOverLimit = countOverLimit + 1
                end
        end

        if countTotal > 0 and countOverLimit > 0 and countOverLimit >= (countTotal-1) then
                return true
        end
        return false
end

local function pinglimit_tick()
	local now = GetServerUptimeMs()
	for refId, time in pairs( to_kick ) do
		if now >= time then
			pinglimit_log( "Kicking " .. refId )
			KickMember( refId, config.tempBanTime )
			to_kick[ refId ] = nil
		end
	end
        for refid,time in pairs( scheduled_sends_motd ) do
                if now >= time then
                        pinglimit_send_motd_now( refid )
                        scheduled_sends_motd[ refid ] = nil
                end
        end
end

local function callback_pinglimit( callback, ... )
	if callback == Callback.Tick then
		pinglimit_tick()
		return
	end

	if config.kickHost == nil or config.tempBanTime == nil or config.tempBanTime < 60 then
		pinglimit_log("Invalid config, addon disabled. Remove or fix the config file (in lua_config directory).", logPrioError)
		do return end
	end
	if config.tolerance < 0 or config.tolerance > 99 then
		pinglimit_log("tolerance parameter is too high ( must be < 100 )", logPrioError)
		do return end
	end


	if callback == Callback.MemberAttributesChanged then
		local refId, dirtyList = ...
		local member = session.members[ refId ]
		for _, field in ipairs( dirtyList ) do
			if field == "Ping" then
				if memberPing[ refId ] == nil then
					 memberPing[ refId ] = 0
				end
				if member.attributes and member.attributes.Ping and member.attributes.Ping > config.limit then
					pinglimit_log( member.name.." " .. field .. " = " .. tostring( member.attributes[ field ] ), logPrioDebug)
					memberPing[ refId ] =  memberPing[ refId ] + ((member.attributes.Ping/config.limit)*(tolerance))
					if not memberNotified[ refId ] or (memberNotified[ refId ] and memberNotified[ refId ] < (GetServerUptimeMs() - (notifyInterval*1000))) then
						pinglimit_sendChatToMember(refId, "WARN your PING is high: "..member.attributes.Ping)
						memberNotified[ refId ] = GetServerUptimeMs()
					end
				else
					if  memberPing[ refId ] > 0 then
						memberPing[ refId ] =  memberPing[ refId ] - 1
					end
				end
			end
		end

		if isEveryoneHighPing() then
			pinglimit_log("EVERYBODY HAS HIGH PING!!", logPrioDebug)
			memberPing = {}
		end

		if  memberPing[ refId ] and memberPing[ refId ] > (config.samples * tolerance)
				and to_kick [ refId ] == nil
				and not pinglimit_isSteamUserWhitelisted(member.steamid)
				and ((config.kickHost==1 and member.host) or not member.host) then
			to_kick [ refId ] = (GetServerUptimeMs() + (kickDelay*1000))
			pinglimit_sendChatToAll(refId, "Ping: KICK "..member.name..", >"..config.limit)
		end
	end
	if callback == Callback.ServerStateChanged then
		local oldState, newState = ...
		pinglimit_log( "Server state changed from " .. oldState .. " to " .. newState,logPrioDebug )
		if oldState == "Starting" and newState == "Running" then
			pinglimit_log("Pinglimit addon v"..VERSION..", config loaded:")
			pinglimit_log("  limit = " .. config.limit)
			pinglimit_log("  samples = " .. config.samples)
			pinglimit_log("  tolerance = " .. config.tolerance)
			pinglimit_log("  kickHost = " .. config.kickHost)
			pinglimit_log("  debug = " .. config.debug)
			pinglimit_log("  tempBanTime = " .. config.tempBanTime)
			for k,v in pairs ( config.whitelist ) do
				pinglimit_log("  steamid whitelisted: "..v)
			end
		end
	end
	if callback == Callback.EventLogged then
		local event = ...
		if ( event.type == "Session" ) and ( event.name == "StateChanged" ) then
			if ( event.attributes.PreviousState ~= "None" ) and ( event.attributes.NewState == "Lobby" ) then
				pinglimit_send_motd_to()
			end
			if ( event.attributes.PreviousState ~= "None" ) and ( event.attributes.NewState == "Race" or  event.attributes.NewState == "Lobby") then
				memberPing = {}
			end
		end
	end
	if callback == Callback.MemberStateChanged then
		local refid, _, new_state = ...
		if new_state == "Connected" then
			pinglimit_send_motd_to( refid )
		end
	end
end

RegisterCallback( callback_pinglimit )
EnableCallback( Callback.Tick )
EnableCallback( Callback.ServerStateChanged )
EnableCallback( Callback.MemberAttributesChanged )
EnableCallback( Callback.MemberStateChanged )
EnableCallback( Callback.EventLogged )

-- EOF --
