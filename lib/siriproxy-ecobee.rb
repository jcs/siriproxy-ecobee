# Copyright (c) 2011 joshua stein <jcs@jcs.org>
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES      
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,      
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require "cora"
require "siri_objects"

class SiriProxy::Plugin::Ecobee < SiriProxy::Plugin
end

require File.dirname(__FILE__) + "/ecobee_thermostat"

class SiriProxy::Plugin::Ecobee
  def initialize(config)
    @thermostat = EcobeeThermostat.new(
      config["ecobee_username"],
      config["ecobee_password"]
    )
  end

  # turn the heat up or down (by one degree)
  listen_for /turn the (heat|air( conditioning)?) (up|down)/i do
    sys = match_data[1]
    dir = match_data[3]

    tstat_info = @thermostat.tstat_info

    new_temp = tstat_info[:hold_temp].to_i + (dir == "up" ? 1 : -1)

    # sanity
    if new_temp < 50
      say "Sorry, I couldn't access the thermostat."
      return request_completed
    end

    say "Adjusting the thermostat to hold the " +
      (tstat_info[:hvac_mode] == "heat" ? "heat" : "air conditioning") +
      " at #{new_temp} degrees."

    @thermostat.set_hold_temp_to!(new_temp, sys)

    request_completed
  end

  # set the heat or air to x degrees
  listen_for /set the (heat|air( conditioning)?) (at|to) (\d+).*/i do
    sys = match_data[1]
    new_temp = match_data[4].to_i

    # sanity
    if new_temp < 50 || new_temp > 90
      say "Sorry, I couldn't understand that temperature."
      return request_completed
    end

    tstat_info = @thermostat.tstat_info

    say "Adjusting the thermostat to hold the " +
      (tstat_info[:hvac_mode] == "heat" ? "heat" : "air conditioning") +
      " at #{new_temp} degrees."

    @thermostat.set_hold_temp_to!(new_temp, sys)

    request_completed
  end

  # turn the heat off - require confirmation on this, getting it wrong can suck
  listen_for /turn the (heat|air( conditioning)?) off/i do
    say "Are you sure you want to turn the #{match_data[1]} off?"
    set_state :turn_sys_off

    request_completed
  end
  listen_for /#{CONFIRM_REGEX}/i, :within_state => :turn_sys_off do
    tstat_info = @thermostat.tstat_info

    @thermostat.turn_hvac_off!

    say "Okay, the " + (tstat_info[:hvac_mode] == "heat" ? "heat" :
      "air conditioning") + " has been turned off."

    request_completed
  end

  # turn the heat or air on
  listen_for /turn the (heat|air( conditioning)?) on/i do
    @thermostat.turn_hvac_on!(match_data[1] == "heat" ? "heat" : "cool")
    tstat_info = @thermostat.tstat_info

    say "The #{match_data[1]} has been turned on and is holding at " +
      "#{tstat_info[:hold_temp].to_i} degrees."

    request_completed
  end

  # what's the temperature in here
  listen_for /what( i|')s the temperature( in (here|the (apartment|house|room)))?/i do
    tstat_info = @thermostat.tstat_info

    str = "It is #{tstat_info[:room_temp].floor} degrees#{match_data[2]}. " +
      case tstat_info[:hvac_mode]
      when "heat"
        "The thermostat is holding the heat at " +
          "#{tstat_info[:hold_temp].to_i} degrees."
      when "cool"
        "The thermostat is holding the air conditioning at " +
          "#{tstat_info[:hold_temp].to_i} degrees."
      else
        ""
      end

    say str

    request_completed
  end
end
