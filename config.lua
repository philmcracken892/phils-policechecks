Config = {}

Config.Debug = false -- Set to false in production



Config.ArrestLocation = vector4(3345.23, -689.54, 44.04, 103.8) -- Where arrested NPCs are transported
Config.DeleteArrestedNPCsAfter = 120 -- Delete arrested NPCs after X seconds (300 = 5 minutes), set to false to keep them indefinitely
-- Cooldown in seconds (5 minutes = 300 seconds)
Config.CheckCooldown = 300

Config.FleeChance = 1
Config.CheckDistance = 3.0
Config.FleeDistance = 100.0
Config.FleeSpeed = 2.0
Config.DeleteNPCOnRelease = false

Config.PaperTypes = {
    'identification',
    'travel_permit',
    'work_permit',
    'residency_papers'
}

Config.CrimeTypes = {
    { name = 'Theft', chance = 15 },
    { name = 'Assault', chance = 10 },
    { name = 'Disturbing the Peace', chance = 20 },
    { name = 'Trespassing', chance = 25 },
    { name = 'Public Intoxication', chance = 30 },
    { name = 'Vagrancy', chance = 20 },
    { name = 'Disorderly Conduct', chance = 25 },
    { name = 'Outstanding Debt', chance = 15 },
    { name = 'Property Damage', chance = 12 }
}

Config.HasPapersChance = 70
Config.ValidPaperChance = 80
Config.HasCrimeChance = 70
Config.MaxCrimes = 3

Config.ArrestReward = 10
Config.CheckReward = 10

Config.FirstNames = {
    'Citizen',
}

Config.LastNames = {
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Miller', 'Davis', 'Garcia', 'Rodriguez', 'Wilson',
    'Martinez', 'Anderson', 'Taylor', 'Thomas', 'Hernandez', 'Moore', 'Martin', 'Jackson', 'Thompson', 'White',
    'Harris', 'Clark', 'Lewis', 'Robinson', 'Walker', 'Perez', 'Hall', 'Young', 'Allen', 'Sanchez'
}