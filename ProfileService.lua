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
	MergeOld = true;
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

local ProfileBinds = {}
--//End of "Arrays"//--



--//Main Functions//--
local function AttemptCache()
	for UserId, ProfileData in pairs(Cache) do
		if ProfileData then
			task.spawn(function() 
				coroutine.wrap(function()
					for z = 0, 2 do -- Attempts to update Data.
						local success = pcall(DataStore.UpdateAsync, DataStore, UserId, function(...) return ProfileData.Data or ... end)
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
						task.wait(1.75^(z+3))

					end
				end)()	
				coroutine.wrap(function()
					for z = 0, 2 do -- Attempts to update backup Data.
						local success = pcall(BackupStore.UpdateAsync, BackupStore, UserId, function(...) return ProfileData.Data or ... end)
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
						task.wait(1.75^(z+3))

					end
				end)()
				coroutine.wrap(function()
					for z = 0, 2 do -- Attempts to update metadata.
						local success = pcall(MetadataStore.UpdateAsync, MetadataStore, UserId,  function(...) return ProfileData.Metadata or ... end)
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
						task.wait(1.75^(z+3))

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
		if PropertyName and PropertyValue ~= nil then
			settings[PropertyName] = PropertyValue
		end
	end

	DataStore = DataStoreService:GetDataStore(settings.StoreName .. "+" .. settings.Version)
	BackupStore = DataStoreService:GetDataStore(settings.StoreName .. "+" .. settings.Version .. "_Backup")
	if settings.DebugMode then
		print(settings)
	end
	task.spawn(CacheMain) -- HOW DID I FORGET TO ADD THIS???
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
		Metadata = table.clone(TemplateMetadata);
	}

	task.spawn(function() -- Metadata is pretty important ngl, but I want the profile to return fast, so I'll just task it.
		local LastLoadedTick = tick()
		coroutine.wrap(function()
			for z = 0, 2 do
				local success, metadata = pcall(MetadataStore.GetAsync, MetadataStore, UserId)
				if success then
					Profile.Metadata = Reconcile(metadata, TemplateMetadata)
					coroutine.yield()

				end

				if settings.DebugMode then
					print("Reattemping to get metadata... ", "DebugInfo: " .. metadata)

				end

				task.wait(1.75^(z+3))
			end

		end)()
		Profile.Metadata.LastLoaded = LastLoadedTick
		Profile.Metadata.SessionCount += 1

	end)
	ProfileBinds[UserId] = {}


	local ListenToRelease = Instance.new("BindableEvent")
	ProfileBinds[UserId].ListenToRelease = ListenToRelease
	Profile.Signals.ListenToRelease = ListenToRelease.Event

	local ListenToDebug = Instance.new("BindableEvent")
	ProfileBinds[UserId].ListenToDebug = ListenToDebug
	Profile.Signals.ListenToDebug = ListenToDebug.Event

	local ListenToPurge = Instance.new("BindableEvent")
	ProfileBinds[UserId].ListenToPurge = ListenToPurge
	Profile.Signals.ListenToPurge = ListenToPurge.Event

	local Loaded = Instance.new("BindableEvent")
	ProfileBinds[UserId].Loaded = Loaded
	Profile.Signals.Loaded = Loaded.Event

	local Corruption = Instance.new("BindableEvent")
	ProfileBinds[UserId].Corruption = Corruption
	Profile.Signals.Corruption = Corruption.Event



	function Profile:Release()
		Profile.Metadata.LastUnloaded = tick()
		Profile.Metadata.LastServer = game.JobId or "StudioServer"
		Profile.Metadata.LastStoreName = settings.StoreName
		Profile.Metadata.LastVersion = settings.Version

		if settings.DebugMode then
			print("Profile of " .. Player.Name .. " released!")
			print(Profile.Metadata.LastVersion, settings.Version)
			print(Profile.Metadata)
		end
		
		ListenToRelease:Fire()
		ProfileBinds[UserId] = nil
		
		local success = pcall(DataStore.UpdateAsync, DataStore, UserId, function(...) return Profile.Data or ... end)
		
		Cache[UserId] = {Data = Profile.Data, Metadata = Profile.Metadata}
		
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
		if ProfileBinds[Player.UserId] then
			ProfileBinds[Player.UserId].ListenToDebug:Fire(errorCode, "warn")

		end

		warn(errorCode)

	end

end

function Service:Purge(
	Player
)
	local typeCheck = table.find({"number", "string"}, type(Player))
	local UserId = nil
	if not typeCheck then
		if Player then
			UserId = Player.UserId

		end
	else
		if typeCheck == 1 then
			UserId = Player

		else
			UserId = game:GetService("Players"):GetUserIdFromNameAsync(Player)
		end

	end

	local successCount = 0

	if UserId then
		local function Remover(Store, UserId)
			for z = 0, 2 do
				local success = table.pack(pcall(task.spawn, Store.RemoveAsync, Store, UserId))
				if success then
					successCount += 1
					coroutine.yield()

				else
					if settings.DebugMode then
						warn("Failed to purge profile!")

					end

				end
				task.wait(1.75^(z+3))

			end
			coroutine.yield()

		end
		coroutine.wrap(Remover)(DataStore, UserId)
		coroutine.wrap(Remover)(BackupStore, UserId)
		if Profiles[UserId] then
			Profiles[UserId].Metadata.Purged = true
			pcall(task.spawn, MetadataStore.UpdateAsync, MetadataStore, UserId, function(...) return Reconcile(Profiles[UserId].Metadata, TemplateMetadata) or ... end)
			if ProfileBinds[UserId] then
				ProfileBinds[UserId].ListenToPurge:Fire()

			end

		end



	end
	return successCount == 2

end

function Service.LoadData(
	Player
)
	local typeCheck = table.find({"number", "string"}, type(Player))
	local UserId = nil
	if not typeCheck then
		if Player then
			UserId = Player.UserId

		end
	else
		if typeCheck == 1 then
			UserId = Player

		else
			UserId = game:GetService("Players"):GetUserIdFromNameAsync(Player)

		end

	end

	if UserId then
		local pullSuccess, Data = false, nil
		local Metadata = TemplateMetadata

		if Profiles[UserId] then

			Metadata = Profiles[UserId].Metadata
		end

		if Cache[UserId] ~= nil then -- Attempts to pull from cache
			Data = Cache[UserId]
			Cache[UserId] = nil 

		end

		if not Data then -- Validation of data given a failure in pulling.
			for z = 0, 2 do -- Attempts to pull from datastore
				local success, result = pcall(DataStore.GetAsync, DataStore, UserId)
				if not success and settings.DebugMode then
					warn(result)
					if ProfileBinds[UserId] then
						ProfileBinds[UserId].ListenToDebug:Fire(result, "warn")

					end

				end


				if success then
					Data = result
					pullSuccess = success
					break
				end
				task.wait(1.75^(z+3))

			end

			if not Data then -- Validation of data given a failure in pulling.
				if settings.DebugMode then
					warn("Failed to pull from main store!")
					ProfileBinds[UserId].ListenToDebug:Fire("Failed to pull from main store!", "warn")

				end

				local last_pullSuccess = pullSuccess
				pullSuccess = false

				for z = 0, 2 do -- Attempts to pull from backup datastore
					local success, result = pcall(BackupStore.GetAsync, BackupStore, UserId)
					if not success and settings.DebugMode then
						print(result)

					end

					pullSuccess = success

					if success then
						Data = result
						pullSuccess = success
						break

					end
					task.wait(1.75^(z+3))

				end

				if last_pullSuccess and pullSuccess and Data ~= nil then
					warn("Corruption found")
					if ProfileBinds[UserId] then
						ProfileBinds[UserId].Corruption:Fire()
						if settings.DebugMode then
							ProfileBinds[UserId].ListenToDebug:Fire("Corruption found", "warn")

						end


					end

				end

			end

		end

		if ((Metadata.LastVersion ~= settings.Version or Metadata.LastStoreName ~= settings.StoreName) and Metadata.LastPlaceId == game.PlaceId) and settings.MergeOld ~= false and not Data then -- Try merging...
			print(settings.MergeOld, settings.MergeOld ~= false)
			local StoreName = Metadata.LastStoreName .. "+" .. Metadata.LastVersion
			if type(settings.MergeOld) == "string" then
				StoreName = settings.MergeOld

			end

			if settings.DebugMode then
				print("Attempting to merge data")
				if ProfileBinds[UserId] then
					ProfileBinds[UserId].ListenToDebug:Fire("Attempting to merge data", "safe")

				end

			end

			for z = 0, 2 do -- Attempts to pull from old datastore
				local success, result = pcall(DataStoreService:GetDataStore(StoreName).GetAsync, DataStoreService:GetDataStore(StoreName), UserId)
				if not success and settings.DebugMode then
					warn(result)
					if ProfileBinds[UserId] then
						ProfileBinds[UserId].ListenToDebug:Fire(result, "warn")

					end

				end


				if success then
					Data = result
					pullSuccess = success
					break
				end
				task.wait(1.75^(z+3))

			end

			if not Data then -- Validation of data given a failure in pulling.
				if settings.DebugMode then
					warn("Failed to pull from main store!")
					if ProfileBinds[UserId] then
						ProfileBinds[UserId].ListenToDebug:Fire("Failed to pull from main store!", "warn")

					end

				end

				local last_pullSuccess = pullSuccess
				pullSuccess = false

				for z = 0, 2 do -- Attempts to pull from old backup datastore
					local success, result = pcall(DataStoreService:GetDataStore(StoreName).GetAsync, DataStoreService:GetDataStore(StoreName), UserId)
					if not success and settings.DebugMode then
						warn(result)
						ProfileBinds[UserId].ListenToDebug:Fire(result, "warn")
					end

					pullSuccess = success

					if success then
						Data = result
						pullSuccess = success
						break

					end
					task.wait(1.75^(z+3))

				end

				if last_pullSuccess and pullSuccess and Data ~= nil then
					warn("Corruption found")
					if ProfileBinds[UserId] then
						ProfileBinds[UserId].Corruption:Fire()

					end

				end

			end

		end

		if Player then
			if ProfileBinds[UserId] then
				ProfileBinds[UserId].Loaded:Fire(Reconcile(Data, settings.Template))

			end

		else
			if settings.DebugMode and not typeCheck then
				warn("Player left after data loaded!")
				if ProfileBinds[UserId] then
					ProfileBinds[UserId].ListenToDebug:Fire("Player left after data loaded!", "warn")

				end

			end

		end
		return Reconcile(Data, settings.Template)

	end
	return nil

end
--//End of "Main"//--



--//Connections//--
game:BindToClose(ImmediateCache)
return Service
--//End of "Connections"//--
