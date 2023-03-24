# Clones-Profile-Service
ProfileService is an excellent module with excellent documentation, however I found it to be... cluttered and not really efficient in it's purpose. I have set out on a mission to bring rich features with great performance, and support for features that by default, ProfileService simply does not have.

**Documentation will be expanded later.**

## Instructions
### What ways can I install (use) this?
* Option 1. Get the model [here](https://www.roblox.com/library/12877376020/ProfileService) and paste the ProfileService script wherever you want in ServerScriptService. 
* Option 2. Take the contents of the ProfileService.lua [file](https://raw.githubusercontent.com/clonedsource/Clones-Profile-Service/main/ProfileService.lua) in the repo and paste it into an empty module script. (click the link, ctrl + A, ctrl + C, ctrl + V inside an empty module script)
1. Install it using one of the methods shown above.
2. Require the module in a script with the RunContext as Legacy or Server.
  - ```local ProfileService = require(ServerScriptService.ProfileService) ```

## [Documentation] (https://github.com/clonedsource/Clones-Profile-Service/wiki)
Documentation is in the works.

## Technicals
This is more for the folk who want to know the technicalities of how this (theoretically) works.
> ... and support for features that by default, ProfileService simply does not have.
- ProfileService does not by default cache the players data and dump it into datastores after a certain duration of time. My module script does this, and empties it after 120 seconds, something I will probably end up tweaking and adding settings for later on.
   - Simplified: ensures the safety of player data saving even in cases of data not saving successfully. (loops through the cache every 120 seconds.)
- ProfileService does not by default backup the players data. I have implemented this through the cache system, as updating the players backup is not economically efficient for individuals leaving, as it wastes network and cpu cycles. when the cache is emptied it also saves to a backup if possible.
   - Simplified: Player has a backup no matter what.
- ProfileService does not account for players losing connections and rejoining, by caching the data-- if the player is disconnected and quickly reconnects-- chances are that the data will still be in the cache, and the server does not have to waste network fetching the data again.
   - Simplified: Player loses connection, player rejoins, less time is used fetching data.
- ProfileService will merge data when MergeData is set to true when Initializing the module upon server start up. This will help streamline actually merging data from an old store to a new store-- this will only happen if there is no data in the new store!
   - Simplified: Streamlined data merging.
