# Clones-Profile-Service
ProfileService is an excellent module with excellent documentation, however I found it to be... cluttered and not really efficient in it's purpose. I have set out on a mission to bring rich features with great performance, and support for features that by default, ProfileService simply does not have.

**Documentation will be expanded later.**

## Instructions
### What ways can I install (use) this?
* Get the package [here](https://create.roblox.com/marketplace/asset/12860449232/ProfileService) and paste it wherever you want in ServerScriptService. 
1. Install it using one of the methods shown above.
2. Require the package in a script with the RunContext as Legacy or Server.
  - ```local ProfileService = require(ServerScriptService.ProfileService) ```

## [Documentation] (https://github.com/clonedsource/Clones-Profile-Service/wiki)
[here].

## Technicals
This is more for the folk who want to know the technicalities of how this (theoretically) works.
> ... and support for features that by default, ProfileService simply does not have.
- ProfileService does not by default cache the players data and dump it into datastores after a certain duration of time. My module script does this, and empties it after 120 seconds, something I will probably end up tweaking and adding settings for later on.
- ProfileService does not by default backup the players data. I have implemented this through the cache system, as updating the players backup is not economically efficient for individuals leaving, as it wastes network and cpu cycles. when the cache is emptied it also saves to a backup if possible.
- ProfileService does not account for players losing connections and rejoining, by caching the data-- if the player is disconnected and quickly reconnects-- chances are that the data will still be in the cache, and the server does not have to waste network fetching the data again.


