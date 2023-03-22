--//Services//--
local Players = game:GetService("Players")
local ProfileService = require(script.Parent.ProfileService)
--//End of "Services"//--



--//Misc.//--

--//End of "Misc."//--



--//Arrays//--
local Profiles = {}
--//End of "Arrays"//--



--//Main Functions//--

--//End of "Main Functions"//--



--//Main//--
function PlayerAdded(Player)
	local Player_Profile = ProfileService:New(Player)
	Player_Profile.Signals.Loaded = function(...)
		print(...)
	end
	Player_Profile.Signals.Corruption = function()
		print("Detected corruption!")
	end
	Player_Profile.Signals.ListenToRelease:Once(function()
		Profiles[Player] = nil
		print("Replicated release!")
	end)
	local Player_Data = ProfileService.LoadData(Player)
	if Player_Data then
		print(Player_Data)
		Player_Profile.Data = Player_Data
		
	end
	Profiles[Player] = Player_Profile
end
function PlayerRemoved(Player)
	local Player_Profile = Profiles[Player]
	if Player_Profile then
		Player_Profile:Release()
		
	end
	
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