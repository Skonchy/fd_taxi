local lastFare = {}

RegisterServerEvent("fd_taxi:payOut")
AddEventHandler("fd_taxi:payOut", function()
    local src = source
    local player = exports["drp_id"]:GetCharacterData(src)
    local playerJob = exports["drp_jobcore"]:GetPlayerJob(src)
    local timeNow = os.clock()
    if playerJob.job == "TAXI" then
        if not lastFare[src] or timeNow - lastFare[src] > 5 then
            lastFare[src]=timeNow
            math.randomseed(os.time())
            local pay = math.random(Taxi.NPCFare[1],Taxi.NPCFare[2])
            TriggerEvent("DRP_Bank:AddBankMoney",player,pay)
        end
    end
end)

RegisterServerEvent("fd_taxi:ToggleDuty")
AddEventHandler("fd_taxi:ToggleDuty", function(unemployed)
    local src = source
    local job = string.upper("taxi")
    local jobLabel = "Taxi Driver"
    local characterInfo = exports["drp_id"]:GetCharacterData(src)
    local currentPlayerJob = exports["drp_jobcore"]:GetPlayerJob(src)
    local unemployed = unemployed
    if unemployed then
        if currentPlayerJob.job ~= "UNEMPLOYED" then
            exports["drp_jobcore"]:RequestJobChange(src, false, false, false)
            TriggerEvent("DRP_Clothing:RestartClothing", src)
        else
            TriggerClientEvent("DRP_Core:Error", src, "Job Manager", tostring("You're already not working"), 2500, true, "leftCenter")
        end
    else
        if exports["drp_jobcore"]:DoesJobExist(job) then
            print(src,job,jobLabel)
            exports["drp_jobcore"]:RequestJobChange(src, job, jobLabel, false)
            --TriggerClientEvent("DRP_Core:Info", src, "Government", tostring("Welcome to "..jobLabel,characterInfo.name..""), 4500, true, "leftCenter")
        end
    end
end)

RegisterServerEvent("fd_taxi:SpawnVehicle")
AddEventHandler("fd_taxi:SpawnVehicle", function(coords)
    local src = source
    local srcJob = exports["drp_jobcore"]:GetPlayerJob(src)
    print(srcJob.job)
    if srcJob.job == "TAXI" then
        TriggerClientEvent("fd_taxi:SpawnVehicle", src, coords)
    end
end)