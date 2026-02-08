local RSGCore = exports['rsg-core']:GetCoreObject()


local isCheckingNPC = false
local currentTarget = nil
local checkedNPCs = {}
local escortedNPC = nil


local escortPromptGroup = GetRandomIntInRange(0, 0xffffff)
local stopEscortPrompt = nil
local escortMenuPrompt = nil
local promptsCreated = false


local ARREST_LOCATION = Config.ArrestLocation

-- Debug function
local function DebugPrint(msg)
    if Config.Debug then
        print('[LAWMAN DEBUG] ' .. msg)
    end
end



local function CreateEscortPrompts()
    if promptsCreated then return end
    
   
    CreateThread(function()
        local str = "Stop Escorting"
        stopEscortPrompt = PromptRegisterBegin()
        PromptSetControlAction(stopEscortPrompt, 0x760A9C6F) -- G key
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(stopEscortPrompt, str)
        PromptSetEnabled(stopEscortPrompt, true)
        PromptSetVisible(stopEscortPrompt, true)
        PromptSetHoldMode(stopEscortPrompt, true)
        PromptSetGroup(stopEscortPrompt, escortPromptGroup)
        PromptRegisterEnd(stopEscortPrompt)
        DebugPrint('Stop Escort prompt created')
    end)
    
   
    CreateThread(function()
        local str = "Escort Options"
        escortMenuPrompt = PromptRegisterBegin()
        PromptSetControlAction(escortMenuPrompt, 0xCEFD9220) -- E key
        str = CreateVarString(10, 'LITERAL_STRING', str)
        PromptSetText(escortMenuPrompt, str)
        PromptSetEnabled(escortMenuPrompt, true)
        PromptSetVisible(escortMenuPrompt, true)
        PromptSetHoldMode(escortMenuPrompt, true)
        PromptSetGroup(escortMenuPrompt, escortPromptGroup)
        PromptRegisterEnd(escortMenuPrompt)
        DebugPrint('Escort Menu prompt created')
    end)
    
    promptsCreated = true
    DebugPrint('Escort prompts created')
end


local function IsLawman()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        DebugPrint('IsLawman: No PlayerData or job')
        return false
    end
    
    local jobType = PlayerData.job.type
    DebugPrint('IsLawman check - Job: ' .. tostring(PlayerData.job.name) .. ', Type: ' .. tostring(jobType))
    
    return jobType == 'leo'
end


-- Notification helper using bln_notify
local function Notify(title, message, type)
    local icon = 'warning'
    if type == 'success' then
        icon = 'awards_set_a_009'
    elseif type == 'error' then
        icon = 'warning'
    elseif type == 'info' then
        icon = 'awards_set_c_001'
    end
    
    TriggerEvent('bln_notify:send', {
        title = title,
        description = message,
        icon = icon,
        duration = 5000,
        placement = 'top-right'
    })
end


local function FormatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    if minutes > 0 then
        return string.format('%d min %d sec', minutes, secs)
    else
        return string.format('%d sec', secs)
    end
end


local function GetRandomNPCName()
    return Config.FirstNames[math.random(#Config.FirstNames)] .. ' ' .. Config.LastNames[math.random(#Config.LastNames)]
end


local function GeneratePapersStatus()
    local hasPapers = math.random(1, 100) <= Config.HasPapersChance
    local papers = {}
    if hasPapers then
        for _, paperType in pairs(Config.PaperTypes) do
            papers[paperType] = math.random(1, 100) <= Config.ValidPaperChance
        end
    end
    return papers, hasPapers
end


local function GenerateCrimeStatus()
    local hasCrime = math.random(1, 100) <= Config.HasCrimeChance
    local crimes = {}
    if hasCrime then
        local crimeCount = math.random(1, Config.MaxCrimes)
        for i = 1, crimeCount do
            local crime = Config.CrimeTypes[math.random(#Config.CrimeTypes)]
            table.insert(crimes, crime.name)
        end
    end
    return crimes, hasCrime
end


local function GetStoredNPCData(npc)
    for _, npcData in pairs(checkedNPCs) do
        if npcData.entity == npc then
            return npcData
        end
    end
    return nil
end


local function IsDetainedNPC(entity)
    return GetStoredNPCData(entity) ~= nil
end


local function IsNPCEscorted(npc)
    return escortedNPC == npc and DoesEntityExist(npc)
end


local function IsCurrentlyEscorting()
    return escortedNPC ~= nil and DoesEntityExist(escortedNPC)
end


local function HandcuffNPC(npc)
    if not DoesEntityExist(npc) then return end
    
    ClearPedTasksImmediately(npc)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetEntityInvincible(npc, true)
    SetPedCanRagdoll(npc, false)
    SetEnableHandcuffs(npc, true)
    SetPedCanPlayGestureAnims(npc, false)
    
    TaskStandStill(npc, -1)
    Wait(300)
    FreezeEntityPosition(npc, true)
    
    DecorSetBool(npc, "IsHandcuffed", true)
end


local function SoftCuffNPC(npc)
    if not DoesEntityExist(npc) then return end
    
    ClearPedTasksImmediately(npc)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetEntityInvincible(npc, true)
    SetPedCanRagdoll(npc, false)
    SetEnableHandcuffs(npc, true)
    SetPedCanPlayGestureAnims(npc, false)
    FreezeEntityPosition(npc, false)
    
    DecorSetBool(npc, "IsHandcuffed", true)
end


local function UncuffNPC(npc)
    if not DoesEntityExist(npc) then return end
    
    ClearPedTasksImmediately(npc)
    FreezeEntityPosition(npc, false)
    SetBlockingOfNonTemporaryEvents(npc, false)
    SetEntityInvincible(npc, false)
    SetPedCanRagdoll(npc, true)
    SetEnableHandcuffs(npc, false)
    SetPedCanPlayGestureAnims(npc, true)
    
    DecorSetBool(npc, "IsHandcuffed", false)
end


local ShowLawmanMenu
local ShowEscortMenu


local function StopEscortNPC()
    if not escortedNPC or not DoesEntityExist(escortedNPC) then 
        escortedNPC = nil
        return 
    end
    
    local npc = escortedNPC
    
    
    DetachEntity(npc, true, false)
    
    
    PlaceEntityOnGroundProperly(npc)
    
   
    Wait(100)
    HandcuffNPC(npc)
    
    DecorSetBool(npc, "IsEscorted", false)
    escortedNPC = nil
    
    Notify('Lawman', 'Suspect is no longer being escorted.', 'info')
end


local function StartEscortNPC(npc)
    if not DoesEntityExist(npc) then return end
    
    
    if escortedNPC and DoesEntityExist(escortedNPC) then
        StopEscortNPC()
    end
    
    local playerPed = PlayerPedId()
    
    
    FreezeEntityPosition(npc, false)
    ClearPedTasksImmediately(npc)
    
   
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetEntityInvincible(npc, true)
    SetPedCanRagdoll(npc, false)
    SetEnableHandcuffs(npc, true)
    
    
    SetEntityCoords(npc, GetOffsetFromEntityInWorldCoords(playerPed, 0.5, 0.3, 0.0))
    
    
    AttachEntityToEntity(npc, playerPed, 11816, 0.5, 0.3, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    
    
    escortedNPC = npc
    DecorSetBool(npc, "IsEscorted", true)
    DecorSetBool(npc, "IsFollowing", false)
    
    Notify('Lawman', 'You are now escorting the suspect.', 'success')
end


local function ToggleEscortNPC(npc)
    if not DoesEntityExist(npc) then return end
    
    local isEscorted = IsNPCEscorted(npc)
    
    if isEscorted then
        StopEscortNPC()
    else
        StartEscortNPC(npc)
    end
end


local function TransportNPCToJail(npc, npcData)
    if not DoesEntityExist(npc) then return end
    
   
    if IsNPCEscorted(npc) then
        DetachEntity(npc, true, false)
        escortedNPC = nil
    end
    
   
    DoScreenFadeOut(500)
    Wait(500)
    
    
    FreezeEntityPosition(npc, false)
    SetEntityCollision(npc, true, true)
    
    
    SetEntityAsMissionEntity(npc, true, true)
    
    
    SetEntityCoordsNoOffset(npc, ARREST_LOCATION.x, ARREST_LOCATION.y, ARREST_LOCATION.z, false, false, false)
    
    
    Wait(100)
    
    
    SetEntityHeading(npc, ARREST_LOCATION.w)
    
    
    Wait(100)
    
    
    PlaceEntityOnGroundProperly(npc)
    
    
    Wait(200)
    
    
    HandcuffNPC(npc)
    
   
    DoScreenFadeIn(500)
    
    
    if Config.DeleteArrestedNPCsAfter then
        SetTimeout(Config.DeleteArrestedNPCsAfter * 1000, function()
            if DoesEntityExist(npc) then
                SetEntityAsMissionEntity(npc, true, true)
                DeletePed(npc)
            end
        end)
    end
    
    DebugPrint('Transported ' .. npcData.name .. ' to jail at ' .. tostring(ARREST_LOCATION))
end


local function MakeNPCFlee(npc)
    if not DoesEntityExist(npc) then return end
    
    UncuffNPC(npc)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    DecorSetBool(npc, "IsFleeing", true)
    ClearPedTasks(npc)
    SetPedFleeAttributes(npc, 2, true)
    SetPedDesiredMoveBlendRatio(npc, 3.0)
    SetPedMoveRateOverride(npc, 3.0)
    TaskFleeCoord(npc, playerCoords.x, playerCoords.y, playerCoords.z, 3, -1)
    
    Notify('Lawman', 'The suspect is fleeing!', 'error')
end


local function MakeNPCFollow(npc)
    if not DoesEntityExist(npc) then return end
    
    SoftCuffNPC(npc)
    local playerPed = PlayerPedId()
    TaskFollowToOffsetOfEntity(npc, playerPed, -1.0, -1.0, 0.0, 1.0, -1, 1.5, true)
    
    DecorSetBool(npc, "IsFollowing", true)
    Notify('Lawman', 'The suspect is following you.', 'success')
end


local function MakeNPCStay(npc)
    if not DoesEntityExist(npc) then return end
    
   
    if IsNPCEscorted(npc) then
        StopEscortNPC()
    end
    
    HandcuffNPC(npc)
    DecorSetBool(npc, "IsFollowing", false)
    Notify('Lawman', 'The suspect is staying in place.', 'success')
end


local function IsValidHumanNPC(entity)
    if not DoesEntityExist(entity) then return false end
    if IsPedAPlayer(entity) then return false end
    if IsEntityDead(entity) then return false end
    if not IsPedHuman(entity) then return false end
    if IsPedInAnyVehicle(entity, false) then return false end
    return true
end


local function CheckNPC(npc)
    if not DoesEntityExist(npc) or not IsValidHumanNPC(npc) then
        Notify('Lawman', 'Invalid target!', 'error')
        return
    end
    
    if not IsLawman() then
        Notify('Lawman', 'Only lawmen can perform checks', 'error')
        return
    end
    
   
    local existingData = GetStoredNPCData(npc)
    if existingData then
        ShowLawmanMenu(npc)
        return
    end
    
    
    RSGCore.Functions.TriggerCallback('lawman:checkCooldown', function(remaining)
        if remaining > 0 then
            Notify('Lawman', 'You must wait ' .. FormatTime(remaining) .. ' before checking another citizen.', 'error')
            return
        end
        
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        Notify('Lawman', 'Approaching suspect...', 'info')
        
        ClearPedTasksImmediately(npc)
        TaskGoToEntity(npc, playerPed, -1, 1.5, 1.0, 0, 0)
        
        CreateThread(function()
            local attempts = 0
            while DoesEntityExist(npc) and attempts < 50 do
                Wait(200)
                local dist = #(GetEntityCoords(npc) - playerCoords)
                if dist <= 2.5 then break end
                attempts = attempts + 1
            end
            
           
            TriggerServerEvent('lawman:setCooldown')
            
            
            if math.random(1, 100) <= Config.FleeChance then
                local npcData = {
                    entity = npc,
                    name = GetRandomNPCName(),
                    isFleeing = true
                }
                table.insert(checkedNPCs, npcData)
                MakeNPCFlee(npc)
                TriggerServerEvent('lawman:npcFled')
                return
            end
            
            HandcuffNPC(npc)
            
            local npcName = GetRandomNPCName()
            local papers, hasPapers = GeneratePapersStatus()
            local crimes, hasCrimes = GenerateCrimeStatus()
            
            local npcData = {
                entity = npc,
                name = npcName,
                papers = papers,
                hasPapers = hasPapers,
                crimes = crimes,
                hasCrimes = hasCrimes
            }
            
            table.insert(checkedNPCs, npcData)
            
            Notify('Lawman', 'Suspect detained. Checking papers...', 'info')
            Wait(1500)
            
            ShowLawmanMenu(npc)
        end)
    end)
end


ShowLawmanMenu = function(npc)
    if not DoesEntityExist(npc) then return end
    
    local npcData = GetStoredNPCData(npc)
    if not npcData then return end
    
    currentTarget = npc
    
    local isEscorted = IsNPCEscorted(npc)
    
    
    local escortText = isEscorted and 'Stop Escorting' or 'Escort Suspect'
    local escortIcon = isEscorted and 'fas fa-user-minus' or 'fas fa-user-plus'
    
    lib.registerContext({
        id = 'lawman_menu',
        title = npcData.name,
        icon = 'fas fa-user',
        options = {
            {
                title = 'Citizen Information',
                icon = 'fas fa-id-card',
                description = 'Name: ' .. npcData.name,
            onSelect = function()
                    Notify('Citizen Info', 'Citizen: ' .. npcData.name, 'info')
                    ShowLawmanMenu(npc)
                end
            },
            {
                title = 'Check Papers',
                icon = 'fas fa-scroll',
                description = 'Examine identification documents',
                onSelect = function()
                    local message = ""
                    if not npcData.hasPapers then
                        message = "No identification documents found"
                    else
                        for paperType, isValid in pairs(npcData.papers) do
                            local status = isValid and 'Valid' or 'Invalid'
                            message = message .. paperType .. ": " .. status .. "\n"
                        end
                    end
                    Notify('Papers Check', message, 'info')
                    ShowLawmanMenu(npc)
                end
            },
            {
                title = 'Criminal Background Check',
                icon = 'fas fa-search',
                description = 'Search for outstanding warrants',
            onSelect = function()
                    if not npcData.hasCrimes or #npcData.crimes == 0 then
                        Notify('Criminal Check', 'No warrants found', 'success')
                    else
                        local crimesList = table.concat(npcData.crimes, ', ')
                        Notify('Criminal Check', 'Warrants: ' .. crimesList, 'error')
                    end
                    ShowLawmanMenu(npc)
                end
            },
            {
                title = escortText,
                icon = escortIcon,
                description = isEscorted and 'Release from escort hold' or 'Grab and escort the suspect',
                onSelect = function()
                    ToggleEscortNPC(npc)
                    Wait(300)
                    if not IsCurrentlyEscorting() then
                        ShowLawmanMenu(npc)
                    end
                end
            },
            {
                title = 'Make Stay',
                icon = 'fas fa-hand-paper',
                description = 'Make suspect stay in place',
                onSelect = function()
                    MakeNPCStay(npc)
                    ShowLawmanMenu(npc)
                end
            },
            {
                title = 'Send Citizen to prison',
                icon = 'fas fa-lock',
                description = 'Take into custody and transport to prison',
                onSelect = function()
                    Notify('Lawman', 'Transporting ' .. npcData.name .. ' to prison...', 'info')
                    
                    TransportNPCToJail(npc, npcData)
                    
                    for i, data in ipairs(checkedNPCs) do
                        if data.entity == npc then
                            table.remove(checkedNPCs, i)
                            break
                        end
                    end
                    
                    Notify('Lawman', npcData.name .. ' has been booked into custody!', 'success')
                    TriggerServerEvent('lawman:arrestNPC', npcData.name, npcData.crimes or {})
                end
            },
            {
                title = 'Release Citizen',
                icon = 'fas fa-unlock',
                description = 'End the interaction',
                onSelect = function()
                    if IsNPCEscorted(npc) then
                        StopEscortNPC()
                    end
                    
                    UncuffNPC(npc)
                    if Config.DeleteNPCOnRelease then
                        DeletePed(npc)
                    else
                        TaskWanderStandard(npc, 10.0, 10)
                    end
                    for i, data in ipairs(checkedNPCs) do
                        if data.entity == npc then
                            table.remove(checkedNPCs, i)
                            break
                        end
                    end
                    Notify('Lawman', npcData.name .. ' released', 'success')
                    TriggerServerEvent('lawman:citizenReleased', npcData.name)
                end
            }
        }
    })
    
    lib.showContext('lawman_menu')
end


ShowEscortMenu = function()
    if not escortedNPC or not DoesEntityExist(escortedNPC) then
        Notify('Lawman', 'No suspect being escorted.', 'error')
        return
    end
    
    local npc = escortedNPC
    local npcData = GetStoredNPCData(npc)
    
    if not npcData then return end
    
    lib.registerContext({
        id = 'escort_menu',
        title = 'Escorting: ' .. npcData.name,
        icon = 'fas fa-user-lock',
        options = {
            {
                title = 'Stop Escorting',
                icon = 'fas fa-user-minus',
                description = 'Release suspect from escort',
                onSelect = function()
                    StopEscortNPC()
                end
            },
            {
                title = 'Arrest Citizen',
                icon = 'fas fa-lock',
                description = 'Take into custody and transport to jail',
                onSelect = function()
                    Notify('Lawman', 'Transporting ' .. npcData.name .. ' to jail...', 'info')
                    
                    TransportNPCToJail(npc, npcData)
                    
                    for i, data in ipairs(checkedNPCs) do
                        if data.entity == npc then
                            table.remove(checkedNPCs, i)
                            break
                        end
                    end
                    
                    Notify('Lawman', npcData.name .. ' has been booked into custody!', 'success')
                    TriggerServerEvent('lawman:arrestNPC', npcData.name, npcData.crimes or {})
                end
            },
            {
                title = 'Release Citizen',
                icon = 'fas fa-unlock',
                description = 'Let them go free',
                onSelect = function()
                    StopEscortNPC()
                    
                    UncuffNPC(npc)
                    if Config.DeleteNPCOnRelease then
                        DeletePed(npc)
                    else
                        TaskWanderStandard(npc, 10.0, 10)
                    end
                    
                    for i, data in ipairs(checkedNPCs) do
                        if data.entity == npc then
                            table.remove(checkedNPCs, i)
                            break
                        end
                    end
                    
                    Notify('Lawman', npcData.name .. ' released', 'success')
                    TriggerServerEvent('lawman:citizenReleased', npcData.name)
                end
            },
            {
                title = 'Check Papers',
                icon = 'fas fa-scroll',
                description = 'Examine identification documents',
                onSelect = function()
                    local message = ""
                    if not npcData.hasPapers then
                        message = "No identification documents found"
                    else
                        for paperType, isValid in pairs(npcData.papers) do
                            local status = isValid and 'Valid' or 'Invalid'
                            message = message .. paperType .. ": " .. status .. "\n"
                        end
                    end
                    Notify('Papers Check', message, 'info')
                end
            },
            {
                title = 'Criminal Background Check',
                icon = 'fas fa-search',
                description = 'Search for outstanding warrants',
            onSelect = function()
                    if not npcData.hasCrimes or #npcData.crimes == 0 then
                        Notify('Criminal Check', 'No warrants found', 'success')
                    else
                        local crimesList = table.concat(npcData.crimes, ', ')
                        Notify('Criminal Check', 'Warrants: ' .. crimesList, 'error')
                    end
                end
            }
        }
    })
    
    lib.showContext('escort_menu')
end


local function RegisterNPCTargeting()
    exports['ox_target']:addGlobalPed({
        {
            name = 'lawman_interact',
            icon = 'fas fa-comment',
            label = 'Talk to Citizen',
            distance = 3.0,
            canInteract = function(entity)
                return IsLawman() and IsValidHumanNPC(entity) and not IsDetainedNPC(entity)
            end,
            onSelect = function(data)
                if data.entity then
                    CheckNPC(data.entity)
                end
            end
        },
        {
            name = 'lawman_detained_interact',
            icon = 'fas fa-user-lock',
            label = 'Manage Suspect',
            distance = 3.0,
            canInteract = function(entity)
                return IsLawman() and IsValidHumanNPC(entity) and IsDetainedNPC(entity) and not IsNPCEscorted(entity)
            end,
            onSelect = function(data)
                if data.entity then
                    ShowLawmanMenu(data.entity)
                end
            end
        }
    })
end


CreateThread(function()
    Wait(2000)
    CreateEscortPrompts()
    Wait(500) 
    RegisterNPCTargeting()
    DebugPrint('Lawman NPC system initialized')
end)


CreateThread(function()
    while true do
        Wait(0)

        
        if IsCurrentlyEscorting() and IsLawman() and stopEscortPrompt and escortMenuPrompt then
            
            local npcData = GetStoredNPCData(escortedNPC)
            local promptTitle = npcData and ('Escorting: ' .. npcData.name) or 'Escorting Suspect'
            local str = CreateVarString(10, 'LITERAL_STRING', promptTitle)

           
            PromptSetActiveGroupThisFrame(escortPromptGroup, str)

            
            if PromptHasHoldModeCompleted(stopEscortPrompt) then
                DebugPrint('[Prompt] G held - stopping escort')
                StopEscortNPC()
            end

            if PromptHasHoldModeCompleted(escortMenuPrompt) then
                DebugPrint('[Prompt] E held - opening escort menu')
                ShowEscortMenu()
            end

        else
            Wait(500) 
        end
    end
end)


CreateThread(function()
    while true do
        Wait(30000)
        
        
        for i = #checkedNPCs, 1, -1 do
            if not DoesEntityExist(checkedNPCs[i].entity) then
                table.remove(checkedNPCs, i)
            end
        end
        
       
        if escortedNPC and not DoesEntityExist(escortedNPC) then
            escortedNPC = nil
        end
    end
end)


CreateThread(function()
    while true do
        Wait(2000)
        local playerPed = PlayerPedId()
        for _, npcData in pairs(checkedNPCs) do
            if DoesEntityExist(npcData.entity) then
                local isFollowing = DecorGetBool(npcData.entity, "IsFollowing") or false
                local isEscorted = DecorGetBool(npcData.entity, "IsEscorted") or false
                
                if isFollowing and not isEscorted then
                    local dist = #(GetEntityCoords(npcData.entity) - GetEntityCoords(playerPed))
                    if dist > 10.0 then
                        TaskFollowToOffsetOfEntity(npcData.entity, playerPed, -1.0, -1.0, 0.0, 1.0, -1, 1.5, true)
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('lawman:arrestSuccess', function(npcName, reward)
    Notify('Lawman', 'Arrested ' .. npcName .. '. Received $' .. reward, 'success')
end)

RegisterNetEvent('lawman:checkReward', function(reward)
    Notify('Lawman', 'Received $' .. reward .. ' for routine check', 'success')
end)


AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
       
        if escortedNPC and DoesEntityExist(escortedNPC) then
            DetachEntity(escortedNPC, true, false)
        end
        
        
        if stopEscortPrompt then
            PromptDelete(stopEscortPrompt)
        end
        if escortMenuPrompt then
            PromptDelete(escortMenuPrompt)
        end
    end
end)