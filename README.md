###siriproxy-ecobee

by [joshua stein](http://jcs.org/)

This is a [SiriProxy](https://github.com/plamoni/SiriProxy) plugin for controlling an [Ecobee](http://www.ecobee.com/) Internet-connected thermostat. 

Copy the lines from `config-info.yml` to your `~/.siriproxy/config.yml` file, setting the `ecobee_username` and `ecobee_password` parameters to the proper settings you use for ecobee.com.

Commands currently supported ("heat", "air", and "air conditioning" can all be used for a system name):

1. "Turn the heat up", "Turn the heat down", "Turn the air up", "Turn the air down".

    *Adjusts the hold temperature for that system to its current setting, plus or minus one degree.*

2. "Set the heat to 70 degrees"

    *Just that.*

3. "Turn the heat off" or "Turn the air conditioning off"

    *Requires confirmation to make sure Siri heard you right.*

4. "Turn the heat on" or "Turn the air on"

    *Turns that system on and reports back its pre-programmed hold temperature. *

5. "What's the temperature in here" or "What is the temperature in the house" (or "apartment" or "room")

    *Report back the current room and system hold temperature.*

This plugin uses Ecobee's JSON web API that their Android/iPhone app uses (as I [wrote](http://jcs.org/ecobee) about previously).  This API is not public, so it may change or stop working at any time.

I am not responsible if your house catches on fire.

![screenshot](http://i.imgur.com/QKuJ2l.jpg)
