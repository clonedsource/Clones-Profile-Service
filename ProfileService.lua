local Service = {}
--//Services//--
local DataStoreService = game:GetService("DataStoreService")
--//End of "Services"//--



--//Misc.//--
local DataStore, BackupStore, MetadataStore = nil, nil, DataStoreService:GetDataStore("TESTINGMETADATAV0000")
--//End of "Misc."//--



--//Arrays//--
local Profiles = {}
local Cache = {}
local settings = {
	Template = {};
	StoreName = "";
	Version = 0;
	DebugMode = game:GetService("RunService"):IsStudio()
}


--//End of "Arrays"//--



--//Main Functions//--
local function GetAsync(_DataStore: DataStore, ...) return _DataStore:GetAsync(...) end
local function UpdateAsync(_DataStore: DataStore, UserId, New) return _DataStore:UpdateAsync(UserId, function(Old) print(New) if not New and settings.DebugMode then print("new data is not real!") end return New end) end
local function SetAsync(_DataStore: DataStore, ...) return _DataStore:SetAsync(...) end



local function CacheMain()
	while task.wait(120) do
		gcinfo()

		for UserId, ProfileData in pairs(Cache) do
			if ProfileData then
				task.spawn(function() 
					for _ = 1, 3 do -- Attempts to update Data.
						local success = pcall(UpdateAsync, DataStore, UserId, ProfileData)
						if not success and settings.DebugMode then
							print("Attempt failed!")
						end

						if success then
							task.delay(3, function() Cache[UserId] = nil end) -- Delays the removal of cache incase player rejoins.
							break

						end
						task.wait(5)

					end
					for _ = 1, 3 do -- Attempts to backup Data.
						local success = pcall(UpdateAsync, BackupStore, UserId, ProfileData)
						if not success and settings.DebugMode then
							print("Attempt to backup failed!")
						end

						task.wait(5)

					end

				end)

			end

		end

	end

end

local function Reconcile(ArrayA, ArrayB) -- ArrayA | Array B -> ArrayC
	local ArrayC = {}
	for Index, Value in pairs(ArrayB) do
		ArrayC[Index] = 	(((ArrayA ~= nil) and (ArrayA[Index] ~= nil)) and ArrayA[Index]) or Value

	end
	return ArrayC
end
--//End of "Main Functions"//--



--//Main//--
function Service:Initialize(
	...
)
	for PropertyName, PropertyValue in pairs(...) do
		if PropertyName and PropertyValue then
			settings[PropertyName] = PropertyValue
		end
	end

	DataStore = DataStoreService:GetDataStore(settings.StoreName .. "+" .. settings.Version)
	BackupStore = DataStoreService:GetDataStore(settings.StoreName .. "+" .. settings.Version .. "_Backup")
	if settings.DebugMode then
		print(settings)
	end

end

function Service:New(
	Player
)
	local UserId = Player.UserId

	local Metadata = MetadataStore:GetAsync(Player.UserId)
	local Profile = {
		Data = {};
		Signals = {
			Loaded = nil;
			Corruption = nil;

		};
		Metadata = {};
	}
	local ListenToRelease = Instance.new("BindableEvent")
	Profile.Signals.ListenToRelease = ListenToRelease.Event

	function Profile:Release()
		Cache[UserId] = Profile.Data
		pcall(UpdateAsync, DataStore, Player.UserId, Profile.Data)
		ListenToRelease:Fire()

	end
	Profiles[UserId] = Profile

	return Profile

end

function Service.LoadData(
	Player
)

	if Player then
		local UserId = Player.UserId
		local pullSuccess, Data = false, nil
		local CorruptionEvent, LoadedEvent

		if Profiles[Player.UserId] then
			pcall(function() CorruptionEvent = Profiles[Player.UserId].Signals.Corruption end)
			pcall(function() LoadedEvent = Profiles[Player.UserId].Signals.Loaded end)
		end

		if Cache[UserId] ~= nil then -- Attempts to pull from cache
			Data = Cache[UserId]
			Cache[UserId] = nil 

		end

		if not Data then -- Validation of data given a failure in pulling.
			for _ = 1, 3 do -- Attempts to pull from datastore
				local success, result = pcall(GetAsync, DataStore, UserId)
				if not success and settings.DebugMode then
					print(result)

				end


				if success then
					Data = result
					pullSuccess = success
					break
				end
				task.wait(5)

			end

			if not Data then -- Validation of data given a failure in pulling.
				if settings.DebugMode then
					print("Failed to pull from main store!")
				end

				local last_pullSuccess = pullSuccess
				pullSuccess = false

				for _ = 1, 3 do -- Attempts to pull from backup datastore
					local success, result = pcall(GetAsync, BackupStore, UserId)
					if not success and settings.DebugMode then
						print(result)

					end

					pullSuccess = success

					if success then
						Data = result
						pullSuccess = success
						break

					end
					task.wait(5)

				end

				if last_pullSuccess and pullSuccess and Data ~= nil then
					warn("Corruption found")
					pcall(task.spawn, CorruptionEvent)
				end

			end

		end
		pcall(task.delay, 0, LoadedEvent)

		if Player then
			return Reconcile(Data, settings.Template)

		else
			Cache[UserId] = Reconcile(Data, settings.Template)
			if settings.DebugMode then
				warn("Player left after data loaded!")

			end

		end
		return nil

	end
	return nil

end
--//End of "Main"//--



--//Connections//--
return Service
--//End of "Connections"//--
