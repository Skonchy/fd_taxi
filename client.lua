local taxi, onJob, AiCustomer, AiDestination, AiBlip, AiInTaxi, AiEntering, IsNearCustomer

--- Functions ---
function SpawnVehicle(coords)
    local hash = GetHashKey("taxi")
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        RequestModel(hash)
        Citizen.Wait(0)
    end
    local newCar = CreateVehicle(hash, coords.x,coords.y,coords.z,coords.h,true,false)
    exports["drp_LegacyFuel"]:SetFuel(newCar,100)
    return newCar
end

function GetPeds(player)
    local peds = {}
    local numpeds,sizeAndPeds = GetPedNearbyPeds(player, nil)
    -- for ped in EnumeratePeds() do
    --     local found = false
    --     for j=1, #ignoreList, 1 do
    --         if ignoreList[j] == ped then
    --                 found = true
    --         end
    --     end
    --     if not found then
    --         table.insert(peds, ped)
    --     end
    -- end
    print(player,numpeds,dump(sizeAndPeds))
    return peds
end

function GetRandomWalkingNPC(player)
	local search = {}
	local peds   = GetPeds(player)
	for i=1, #peds, 1 do
		if IsPedHuman(peds[i]) and IsPedWalking(peds[i]) and not IsPedAPlayer(peds[i]) then
			table.insert(search, peds[i])
		end
	end
	if #search > 0 then
		return search[GetRandomIntInRange(1, #search)]
	end
	for i=1, 250, 1 do
		local ped = GetRandomPedAtCoord(0.0, 0.0, 0.0, math.huge + 0.0, math.huge + 0.0, math.huge + 0.0, 26)

		if DoesEntityExist(ped) and IsPedHuman(ped) and IsPedWalking(ped) and not IsPedAPlayer(ped) then
			table.insert(search, ped)
		end
	end
	if #search > 0 then
		return search[GetRandomIntInRange(1, #search)]
	end
end

function ClearCurrentMission()
	if DoesBlipExist(AiBlip) then
		RemoveBlip(AiBlip)
    end
	AiCustomer           = nil
    AiDestination       = nil
    AiInTaxi = false
    AiEntering = false
    IsNearCustomer = false
end

function StartJob()
    ClearCurrentMission()
    onJob = true
end

function StopJob()
    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed,false) and AiCustomer ~= nil then
        local vehicle = GetVehiclePedIsIn(playerPed,false)
        TaskLeaveVehicle(AiCustomer,false)
        TaskGoStraightToCoord(AiCustomer,  AiDestination.x,  AiDestination.y,  AiDestination.z,  1.0,  -1,  0.0,  0.0)
    end
    ClearCurrentMission()
    onJob = false
    TriggerEvent("DRP_Core:Info","Taxi Dispatch", tostring("Fare completed"),4500,false,"leftCenter")
end

function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

--- Events ---
RegisterNetEvent("fd_taxi:SpawnVehicle")
AddEventHandler("fd_taxi:SpawnVehicle", function(coords)
    local ped = PlayerPedId()
    taxi = SpawnVehicle(coords)
    SetPedIntoVehicle(ped,taxi,-1)
end)


--- Threads ---
-- On/Offduty Zones --
Citizen.CreateThread(function()
    local sleep = 1000
    while true do
        for i=1, #Taxi.SignOnAndOff do
            local ped = PlayerPedId()
            local pedPos = GetEntityCoords(ped)
            local distance = Vdist(pedPos.x, pedPos.y, pedPos.z, Taxi.SignOnAndOff[i].x, Taxi.SignOnAndOff[i].y, Taxi.SignOnAndOff[i].z)
            if distance <= 5.0 then
                sleep = 10
                exports["drp_core"]:DrawText3Ds(Taxi.SignOnAndOff[i].x, Taxi.SignOnAndOff[i].y, Taxi.SignOnAndOff[i].z,tostring("~b~[E]~w~ to sign on duty or ~r~[X]~w~ to sign off duty"))
                if IsControlJustPressed(1, 86) then
                    TriggerServerEvent("fd_taxi:ToggleDuty", false)
                    StartJob()
                elseif IsControlJustPressed(1, 73) then
                    TriggerServerEvent("fd_taxi:ToggleDuty", true)
                    StopJob()
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)
-- Garages --
Citizen.CreateThread(function()
    local sleepTimer=1000
    while true do
        for a=1, #Taxi.Garages do
            local ped = PlayerPedId()
            local pedPos = GetEntityCoords(ped)
            local distance = Vdist(pedPos.x,pedPos.y,pedPos.z, Taxi.Garages[a].x, Taxi.Garages[a].y, Taxi.Garages[a].z)
            if distance <= 5.0 then
               sleepTimer = 10
               exports['drp_core']:DrawText3Ds(Taxi.Garages[a].x, Taxi.Garages[a].y, Taxi.Garages[a].z, tostring("~b~[E]~w~ to spawn a Taxi ~r~[X]~w~ to delete your Taxi"))
               if IsControlJustPressed(1,86) then
                TriggerServerEvent("fd_taxi:SpawnVehicle",Taxi.CarSpawns[a])
               elseif IsControlJustPressed(1,73) then
                DeleteVehicle(GetVehiclePedIsIn(ped,true))
               end
            end
        end
        Citizen.Wait(sleepTimer)
    end
end)

-- Job Thread --
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local playerPed = PlayerPedId()
        if onJob then
            if AiCustomer == nil then
                TriggerEvent("DRP_Core:Info","Taxi Dispatch", tostring("Drive around and search for fares"),4500,false,"leftCenter")
                if IsPedInAnyVehicle(playerPed,false) and GetEntitySpeed(playerPed) > 0 then
                    local waiting = GetGameTimer() + GetRandomIntInRange(3000, 4500)
                    while onJob and waiting > GetGameTimer() do
                        Citizen.Wait(1000)
                        print("Waiting for Fare")
                    end
                    if onJob and IsPedInAnyVehicle(playerPed,false) and GetEntitySpeed(playerPed) > 0 then
                        AiCustomer = GetRandomWalkingNPC(playerPed)
                        if AiCustomer ~= nil then
                            AiBlip = AddBlipForEntity(AiCustomer)
                            AiBlip = AddBlipForEntity(AiCustomer)
							SetBlipAsFriendly(AiBlip, true)
							SetBlipColour(AiBlip, 2)
							SetBlipCategory(AiBlip, 3)
							SetBlipRoute(AiBlip, true)
							SetEntityAsMissionEntity(AiCustomer, true, false)
							ClearPedTasksImmediately(AiCustomer)
							SetBlockingOfNonTemporaryEvents(AiCustomer, true)
							local standTime = GetRandomIntInRange(60000, 180000)
                            TaskStandStill(AiCustomer, standTime)
                            TriggerEvent("DRP_Core:Info","Taxi Dispatch", tostring("A local has called for a taxi. Proceed to the marker to pick them up"),4500,false,"leftCenter")
                        end
                    end
                end
            else
                if IsPedFatallyInjured(AiCustomer) then
					TriggerEvent("DRP_Core:Warning","Taxi Dispatch",tostring("Your fare has been injured and is being taken to the hospital"),4500,false,"leftCenter")

					if DoesBlipExist(AiBlip) then
						RemoveBlip(AiBlip)
					end
                    SetEntityAsMissionEntity(AiCustomer, false, true)
                    AiCustomer,AiBlip = nil,nil
                end
                if IsPedInAnyVehicle(playerPed,false) then
                    local playerLoc = GetEntityCoords(playerPed)
                    local customerLoc = GetEntityCoords(AiCustomer)
                    local aiDist = #(playerLoc - customerLoc)
                    if IsPedSittingInVehicle(AiCustomer,taxi) then
                        if AiInTaxi then
                            local targetDistance = #(playerLoc - AiDestination)

							if targetDistance <= 10.0 then
								TaskLeaveVehicle(AiCustomer, taxi, 0)

								TriggerEvent("DRP_Core:Info","Taxi Dispatch",tostring("You have arrived at your fare's destination"),4500,false,"leftCenter")

								TaskGoStraightToCoord(AiCustomer, AiDestination.x, AiDestination.y, AiDestination.z, 1.0, -1, 0.0, 0.0)
								SetEntityAsMissionEntity(AiCustomer, false, true)
								TriggerServerEvent('esx_taxijob:success')
								RemoveBlip(AiBlip)

								local scope = function(customer)
									DeletePed(customer)
								end
                                scope(AiCustomer)
                                AiCustomer, AiBlip, AiIntaxi, AiEntering, AiDestination, IsNearCustomer = nil, nil, false, false, nil, false
                        end
                        if AiDestination then
                            DrawMarker(36, AiDestination.x, AiDestination.y, AiDestination.z + 1.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 234, 223, 72, 155, false, false, 2, true, nil, nil, false)
                        end
                    else
                        RemoveBlip(AiBlip)
						AiBlip = nil
						AiDestination = Taxi.JobLocations[GetRandomIntInRange(1, #Taxi.JobLocations)]
						local distance = #(playerLoc - AiDestination)
						while distance < Taxi.MinimumDistance do
							Citizen.Wait(5)
							AiDestination = Taxi.JobLocations[GetRandomIntInRange(1, #Taxi.JobLocations)]
							distance = #(playerLoc - AiDestination)
						end
						local street = table.pack(GetStreetNameAtCoord(AiDestination.x, AiDestination.y, AiDestination.z))
						local msg    = nil
						if street[2] ~= 0 and street[2] ~= nil then
							msg = string.format("Take me to ~y~%s~s~, near ~y~%s", GetStreetNameFromHashKey(street[1]), GetStreetNameFromHashKey(street[2]))
						else
							msg = string.format("Take me to ~y~%s", GetStreetNameFromHashKey(street[1]))
						end
						TriggerEvent('chat:addMessage', {
                            color = { 255, 255, 0},
                            multiline = true,
                            args = {"Client", msg}
                          })
						AiBlip = AddBlipForCoord(AiDestination.x, AiDestination.y, AiDestination.z)
						BeginTextCommandSetBlipName('STRING')
						AddTextComponentSubstringPlayerName('Destination')
						EndTextCommandSetBlipName(blip)
						SetBlipRoute(AiBlip, true)
						AiInTaxi = true
                    end
                else
                    DrawMarker(36, customerLoc.x, customerLoc.y, customerLoc.z + 1.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 234, 223, 72, 155, false, false, 2, true, nil, nil, false)

					if not AiInTaxi then
						if aiDist <= 40.0 then

							if not IsNearCustomer then
								IsNearCustomer = true
							end

						end

						if aiDist <= 20.0 then
							if not AiEntering then
								ClearPedTasksImmediately(AiCustomer)

								local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(taxi)

								for i=maxSeats - 1, 0, -1 do
									if IsVehicleSeatFree(taxi, i) then
										freeSeat = i
										break
									end
								end

								if freeSeat then
									TaskEnterVehicle(AiCustomer, taxi, -1, freeSeat, 2.0, 0)
									AiEntering = true
                                end
                            end
                        end
                    end
                end
            end
        end
        Citizen.Wait(500)
    end
end
end)

-- Blips --
Citizen.CreateThread(function()
    local blip = AddBlipForCoord(Taxi.SignOnAndOff[1].x, Taxi.SignOnAndOff[1].y, Taxi.SignOnAndOff[1].z)
    SetBlipSprite(blip, 198)
    SetBlipColour(blip,60)
	BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Taxi Depot')
    EndTextCommandSetBlipName(blip)
    SetBlipAsShortRange(blip,true)
end)