local Service = {}
--//Services//--
local DataStoreService = game:GetService("DataStoreService")
--//End of "Services"//--



--//Misc.//--
local DataStore, BackupStore, MetadataStore = nil, nil, DataStoreService:GetDataStore("TESTINGMETADATAV0000")
local Frequency = 120
--//End of "Misc."//--



--//Arrays//--
local Profiles = {}
local Cache = {}

local settings = {
	Template = {};
	StoreName = "";
	Version = 0;
	DebugMode = game:GetService("RunService"):IsStudio();
	MergeOld = false;
}

local TemplateMetadata = {
	SessionCount = 1;
	LastLoaded = 0;
	LastUnloaded = 0;
	LastServer = 0;
	LastStoreName = settings.StoreName;
	LastVersion = settings.Version;
	LastPlaceId = game.PlaceId;
	Purged = false;
}
--//End of "Arrays"//--



--//Main Functions//--
local function GetAsync(_DataStore: DataStore, ...) return _DataStore:GetAsync(...) end
local function UpdateAsync(_DataStore: DataStore, UserId, New) return _DataStore:UpdateAsync(UserId, function(Old) if not New and settings.DebugMode then print("new data is not real!") end return New end) end
local function SetAsync(_DataStore: DataStore, ...) return _DataStore:SetAsync(...) end
local function RemoveAsync(_DataStore: DataStore, ...) return _DataStore:RemoveAsync(...) end

local function AttemptCache()
	for UserId, ProfileData in pairs(Cache) do
		if ProfileData then
			task.spawn(function() 
				coroutine.wrap(function()
					for _ = 0, 2 do -- Attempts to update Data.
						local success = pcall(UpdateAsync, DataStore, UserId, ProfileData.Data)
						if settings.DebugMode then
							if not success then
								print("Attempt failed!")

							else
								print("Attempt succeeded!")

							end


						end

						if success then
							task.delay(3, function() Cache[UserId] = nil end) -- Delays the removal of cache incase player rejoins.
							coroutine.yield()

						end
						task.wait(1.75^(_+3))

					end
				end)()	
				coroutine.wrap(function()
					for _ = 0, 2 do -- Attempts to update backup Data.
						local success = pcall(UpdateAsync, BackupStore, UserId, ProfileData.Data)
						if settings.DebugMode then
							if not success then
								print("Attempt to backup failed!")

							else
								print("Attempt to backup succeeded!")

							end


						end
						if success then
							coroutine.yield()

						end
						task.wait(1.75^(_+3))

					end
				end)()
				coroutine.wrap(function()
					for _ = 0, 2 do -- Attempts to update metadata.
						local success = pcall(UpdateAsync, MetadataStore, UserId, ProfileData.Metadata)
						if settings.DebugMode then
							if not success then
								print("Attempt to update metadata failed!")

							else
								print("Attempt to update metadata succeeded!")

							end


						end
						if success then
							coroutine.yield()

						end
						task.wait(1.75^(_+3))

					end
				end)()

			end)

		end

	end
	
end

local function CacheMain()
	while task.wait(Frequency) do
		gcinfo()
		if settings.DebugMode then
			print("Caching, next tick: " .. tick() + Frequency)

		end
		AttemptCache()

	end

end

local function ImmediateCache()
	if settings.DebugMode then
		print("Server closing-- Caching immediately!")
		
	end
	AttemptCache()
	
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
	
	task.spawn(function() -- Metadata is pretty important ngl, but I want the profile to return fast, so I'll just task it.
		local LastLoadedTick = tick()
		coroutine.wrap(function()
			for _ = 0, 2 do
				local success, metadata = pcall(GetAsync, MetadataStore, UserId)
				if success then
					Profile.Metadata = Reconcile(metadata, TemplateMetadata)
					coroutine.yield()
					
				end
				
				if settings.DebugMode then
					print("Reattemping to get metadata... ", "DebugInfo: " .. metadata)
					
				end
				
				task.wait(1.75^(_+3))
			end
			
		end)()
		Profile.Metadata.LastLoaded = LastLoadedTick
		Profile.Metadata.SessionCount += 1
		
	end)
	
	
	
	
	local ListenToRelease = Instance.new("BindableEvent")
	Profile.Signals.ListenToRelease = ListenToRelease.Event

	function Profile:Release()
		if settings.DebugMode then
			print("Profile of " .. Player.Name .. " released!")
			
		end
		
		Profile.Metadata.LastUnloaded = tick()
		Profile.Metadata.LastServer = game.JobId or "StudioServer"
		Profile.Metadata.LastStoreName = settings.StoreName
		Profile.Metadata.LastVersion = settings.Version
		
		print(Profile.Metadata.LastVersion, settings.Version)
		print(Profile.Metadata)
		
		Cache[UserId] = {Data = Profile.Data, Metadata = Profile.Metadata}
		pcall(UpdateAsync, DataStore, UserId, Profile.Data)
		
		ListenToRelease:Fire()

	end
	Profiles[UserId] = Profile

	return Profile

end

function Service.ReturnProfile(Player, waitTime)
	local errorCode = "Player isn't in server!"
	if Player then
		local Profile = Profiles[Player.UserId]
		if Profile then
			return Profile
			
		else
			if not waitTime then
				errorCode = "Profile doesn't exist."
				
			else
				local waitTick = tick()
				repeat task.wait(1) until Profiles[Player.UserId] ~= nil or (tick() - waitTick) >= waitTime
				if Profiles[Player.UserId] then
					return Profiles[Player.UserId]
					
				end
				errorCode = "Function execution took longer than provided wait time of"  .. waitTime .. " seconds"
				
			end

		end
		
	end
	
	if settings.DebugMode then
		warn(errorCode)
		
	end
	
end

function Service.LoadData(
	Player
)

	if Player then
		local UserId = Player.UserId
		local pullSuccess, Data = false, nil
		local CorruptionEvent, LoadedEvent
		local Metadata = TemplateMetadata
		
		if Profiles[Player.UserId] then
			pcall(function() CorruptionEvent = Profiles[Player.UserId].Signals.Corruption end)
			pcall(function() LoadedEvent = Profiles[Player.UserId].Signals.Loaded end)
			Metadata = Profiles[Player.UserId].Metadata
		end

		if Cache[UserId] ~= nil then -- Attempts to pull from cache
			Data = Cache[UserId]
			Cache[UserId] = nil 

		end

		if not Data then -- Validation of data given a failure in pulling.
			for _ = 0, 2 do -- Attempts to pull from datastore
				local success, result = pcall(GetAsync, DataStore, UserId)
				if not success and settings.DebugMode then
					print(result)

				end


				if success then
					Data = result
					pullSuccess = success
					break
				end
				task.wait(1.75^(_+3))

			end

			if not Data then -- Validation of data given a failure in pulling.
				if settings.DebugMode then
					print("Failed to pull from main store!")
				end

				local last_pullSuccess = pullSuccess
				pullSuccess = false

				for _ = 0, 2 do -- Attempts to pull from backup datastore
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
					task.wait(1.75^(_+3))

				end

				if last_pullSuccess and pullSuccess and Data ~= nil then
					warn("Corruption found")
					pcall(task.spawn, CorruptionEvent)
				end

			end

		end
		
		if ((Metadata.LastVersion ~= settings.Version or Metadata.LastStoreName ~= settings.StoreName) and Metadata.LastPlaceId == game.PlaceId) and settings.MergeOld and not Data then -- Try merging...
			if settings.DebugMode then
				print("Attempting to merge data")
				
			end
			
			for _ = 0, 2 do -- Attempts to pull from old datastore
				local success, result = pcall(GetAsync, DataStoreService:GetDataStore(Metadata.LastStoreName .. "+" .. Metadata.LastVersion), UserId)
				if not success and settings.DebugMode then
					print(result)

				end


				if success then
					Data = result
					pullSuccess = success
					break
				end
				task.wait(1.75^(_+3))

			end

			if not Data then -- Validation of data given a failure in pulling.
				if settings.DebugMode then
					print("Failed to pull from main store!")
				end

				local last_pullSuccess = pullSuccess
				pullSuccess = false

				for _ = 0, 2 do -- Attempts to pull from old backup datastore
					local success, result = pcall(GetAsync, DataStoreService:GetDataStore(Metadata.LastStoreName .. "+" .. Metadata.LastVersion .. "_Backup"), UserId)
					if not success and settings.DebugMode then
						print(result)

					end

					pullSuccess = success

					if success then
						Data = result
						pullSuccess = success
						break

					end
					task.wait(1.75^(_+3))

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
game:BindToClose(ImmediateCache)
return Service
--//End of "Connections"//--
