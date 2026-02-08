local RSGCore = exports['rsg-core']:GetCoreObject()


local playerCooldowns = {}


local function IsPlayerLawman(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not Player.PlayerData.job then return false end
    
    return Player.PlayerData.job.type == 'leo'
end


local function GetPlayerCooldownRemaining(source)
    local lastCheck = playerCooldowns[source]
    if not lastCheck then return 0 end
    
    local currentTime = os.time()
    local elapsed = currentTime - lastCheck
    local remaining = Config.CheckCooldown - elapsed
    
    return remaining > 0 and remaining or 0
end


local function SetPlayerCooldown(source)
    playerCooldowns[source] = os.time()
end


RSGCore.Functions.CreateCallback('lawman:checkCooldown', function(source, cb)
    local remaining = GetPlayerCooldownRemaining(source)
    cb(remaining)
end)


RegisterNetEvent('lawman:setCooldown', function()
    local src = source
    if not IsPlayerLawman(src) then return end
    SetPlayerCooldown(src)
end)


AddEventHandler('playerDropped', function()
    local src = source
    playerCooldowns[src] = nil
end)


local function LogLawmanActivity(source, action, details)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    
    print(('[LAWMAN LOG] %s (%s) - %s: %s'):format(
        Player.PlayerData.name or 'Unknown', 
        Player.PlayerData.job.name or 'Unknown', 
        action, 
        details
    ))
end


RegisterNetEvent('lawman:arrestNPC', function(npcName, crimes)
    local src = source
    if not IsPlayerLawman(src) then return end
    
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if not crimes or type(crimes) ~= 'table' then
        crimes = {}
    end
    
    local reward = Config.ArrestReward or 50
    if #crimes > 1 then
        reward = reward + (#crimes - 1) * 10
    end
    
    Player.Functions.AddMoney('cash', reward, 'lawman-arrest')
    
    local crimesList = #crimes > 0 and table.concat(crimes, ', ') or 'Suspicious behavior'
    LogLawmanActivity(src, 'ARREST', ('Arrested %s for: %s'):format(npcName, crimesList))
    
    TriggerClientEvent('lawman:arrestSuccess', src, npcName, reward)
end)


RegisterNetEvent('lawman:citizenReleased', function(npcName)
    local src = source
    if not IsPlayerLawman(src) then return end
    
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local reward = Config.CheckReward or 10
    Player.Functions.AddMoney('cash', reward, 'lawman-check')
    
    LogLawmanActivity(src, 'RELEASE', ('Released citizen: %s after routine check'):format(npcName))
    
    TriggerClientEvent('lawman:checkReward', src, reward)
end)


RegisterNetEvent('lawman:npcFled', function()
    local src = source
    if not IsPlayerLawman(src) then return end
    
    LogLawmanActivity(src, 'FLEE', 'Suspect fled during papers check')
end)