--//Services//--
local Players = game:GetService("Players")
local ProfileService = require(12877376020)
--//End of "Services"//--



--//Misc.//--

--//End of "Misc."//--



--//Arrays//--
--//End of "Arrays"//--



--//Main Functions//--

--//End of "Main Functions"//--



--//Main//--
function PlayerAdded(Player)
	if ProfileService.ReturnProfile(Player) then return end
	local Player_Profile = ProfileService:New(Player)

	Player_Profile.Signals.Loaded:Once(function(...)
		print(...)
	end)
	Player_Profile.Signals.Corruption:Once(function()
		print("Detected corruption!")
	end)
	Player_Profile.Signals.ListenToPurge:Once(function()
		print("Purged!")
	end)
	Player_Profile.Signals.ListenToRelease:Once(function()
		print("Replicated release!")
	end)

	local Player_Data = ProfileService.LoadData(Player)
	if not Player_Data then return end 

	Player_Profile.Data = Player_Data

end
function PlayerRemoved(Player)
	local Player_Profile = ProfileService.ReturnProfile(Player)
	if not Player_Profile then return end
	
	Player_Profile:Release()

end
--//End of "Main"//--



--//Connections//--
ProfileService:Initialize({
	StoreName = "TestingProfileService",
	Version = 0,
	Template = {
		Money = 0;
		Cars = {"Prius"};
	},
})
Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoved)
--//End of "Connections"//--
