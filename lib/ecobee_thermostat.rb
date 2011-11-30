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

require "httparty"
require "json"

class SiriProxy::Plugin::Ecobee::EcobeeThermostat
  include HTTParty
  base_uri "https://www.ecobee.com/home"

  # TODO: tie this to siri proxy's log_level
  #debug_output

  def self.ecobee_degrees_to_fahrenheit(canon)
    canon.to_f / 10.0
  end

  def self.fahrenheit_degrees_to_ecobee(canon)
    canon.to_f * 10.0
  end

  def initialize(username, password)
    @username = username
    @password = password

    @token = nil
    @tstat_id = nil
  end

  def tstat_id
    if !@tstat_id
      login_and_get_token

      # find and cache the first thermostat id
      resp = get("/ecobee/summary", { "selection" => {} })
      @tstat_id = resp.parsed_response["descriptors"].
        first["thermostatIdentifier"]
      if !@tstat_id
        raise EcobeeError, "Logged in but could not find Thermostat ID"
      end
    end

    return @tstat_id
  end

  def tstat_info
    resp = get("/ecobee/thermostat", {
      "selection" => {
        "criteria" => "csv",
        "criteriaData" => tstat_id
      }
    })

    ret = {
      :hvac_mode => resp.parsed_response["thermostats"].first["hvacMode"],
      :cool_hold_temp => self.class.ecobee_degrees_to_fahrenheit(
        resp.parsed_response["thermostats"].first["auxiliary"]["coolHoldTemp"]),
      :heat_hold_temp => self.class.ecobee_degrees_to_fahrenheit(
        resp.parsed_response["thermostats"].first["auxiliary"]["heatHoldTemp"]),
      :room_temp => self.class.ecobee_degrees_to_fahrenheit(       
        resp.parsed_response["thermostats"].first["auxiliary"]["currentTemp"]),
      :humidity => resp.parsed_response["thermostats"].
        first["auxiliary"]["currentHumidity"],
    }

    if ret[:hvac_mode] == "heat"
      ret[:hold_temp] = ret[:heat_hold_temp]
    elsif ret[:hvac_mode] == "cool"
      ret[:hold_temp] = ret[:cool_hold_temp]
    elsif ret[:hvac_mode] == "off"
      ret[:hold_temp] = nil
    else
      raise EcobeeError, "Could not determine current system"
    end

    ret
  end

  def set_hold_temp_to!(deg_f, sys)
    ps = {
      "selection" => {
        "criteria" => "csv",
        "criteriaData" => tstat_id,
      },
      "holdType" => "holdPermanently",
      "hold" => true,
    }

    if sys == "heat"
      ps["hvacMode"] = "heat"
      ps["holdHeatTemp"] = self.class.fahrenheit_degrees_to_ecobee(deg_f)
    elsif sys == "cool"
      ps["hvacMode"] = "cool"
      ps["holdCoolTemp"] = self.class.fahrenheit_degrees_to_ecobee(deg_f)
    else
      raise EcobeeError, "what system is #{sys}?"
    end

    post("/ecobee/update", ps)
  end

  def turn_hvac_off!
    post("/ecobee/update", {
      "selection" => {
        "criteria" => "csv",
        "criteriaData" => tstat_id,
      },
      "hvacMode" => "off",
    })
  end

  def turn_hvac_on!(sys)
    post("/ecobee/update", {
      "selection" => {
        "criteria" => "csv",
        "criteriaData" => tstat_id,
      },
      "hvacMode" => sys,
    })
  end

private

  # rather than mess around with session expiration and re-login, just login
  # every time.  we're not going to be doing that many queries and we'll
  # probably timeout our session on each one anyway.
  def login_and_get_token
    resp = post("/ecobee/register", {
      :userName => @username,
      :password => @password,
    })

    if !resp || !(@token = resp.parsed_response["token"])
      raise EcobeeError "Could not login"
    end
  end

  def get(url, fields)
    session_wrapper(:get, url, fields)
  end

  def post(url, fields)
    session_wrapper(:post, url, fields)
  end

  # ecobee's server wants data in json format for POSTed fields or query args

  def _post(url, fields)
    if @token
      fields["token"] = @token
    end

    self.class.post(url, {
      :body => JSON.generate(fields),
      :headers => {
        "User-Agent" => "siriproxy-ecobee",
      },
    })
  end

  def _get(url, fields)
    if @token
      fields["token"] = @token
    end

    if fields.any?
      url += (url.match(/\?/) ? "&" : "?") + URI.encode(JSON.generate(fields))
    end

    self.class.get(url, {
      :headers => {
        "User-Agent" => "siriproxy-ecobee",
        "Content-type" => "application/x-www-form-urlencoded"
      },
    })
  end

  def session_wrapper(method, url, fields)
    retried = false
    begin
      resp = self.send("_#{method}", url, fields)

      if !resp
        raise EcobeeError, "Invalid response from Ecobee"
      end

      if resp.parsed_response["error"]
        if resp.parsed_response["errorNumber"] == 313
          raise EcobeeSessionExpired
        else
          raise EcobeeError, "Ecobee error: #{resp.parsed_response["error"]} " +
            "(#{resp.parsed_response["errorNumber"]})"
        end
      end

      return resp

    rescue EcobeeSessionExpired
      if retried
        raise EcobeeError, "expiration re-login failed"
      else
        puts "Ecobee session expired, logging in again"
        retried = true
        login_and_get_token
        retry
      end
    end
  end
end

class SiriProxy::Plugin::Ecobee::EcobeeThermostat::EcobeeError < StandardError
end

class SiriProxy::Plugin::Ecobee::EcobeeThermostat::EcobeeSessionExpired < StandardError
end
