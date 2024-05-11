mods.fishing = {}
log("FISHIGN WORK")
-----------------------
-- UTILITY FUNCTIONS --
-----------------------


-- Get a table for a userdata value by name
local function userdata_table(userdata, tableName)
    if not userdata.table[tableName] then userdata.table[tableName] = {} end
    return userdata.table[tableName]
end

local function get_random_point_in_radius(center, radius)
    r = radius * math.sqrt(math.random())
    theta = math.random() * 2 * math.pi
    return Hyperspace.Pointf(center.x + r * math.cos(theta), center.y + r * math.sin(theta))
end

local function get_point_local_offset(original, target, offsetForwards, offsetRight)
    local alpha = math.atan((original.y-target.y), (original.x-target.x))
    --print(alpha)
    local newX = original.x - (offsetForwards * math.cos(alpha)) - (offsetRight * math.cos(alpha+math.rad(90)))
    --print(newX)
    local newY = original.y - (offsetForwards * math.sin(alpha)) - (offsetRight * math.sin(alpha+math.rad(90)))
    --print(newY)
    return Hyperspace.Pointf(newX, newY)
end

local function vter(cvec)
    local i = -1
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end

-- Find ID of a room at the given location
local function get_room_at_location(shipManager, location, includeWalls)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

-- Returns a table of all crew belonging to the given ship on the room tile at the given point
local function get_ship_crew_point(shipManager, x, y, maxCount)
    res = {}
    x = x//35
    y = y//35
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and x == crewmem.x//35 and y == crewmem.y//35 then
            table.insert(res, crewmem)
            if maxCount and #res >= maxCount then
                return res
            end
        end
    end
    return res
end

local function get_ship_crew_room(shipManager, roomId)
    local crewList = {}
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and crewmem.iRoomId == roomId then
            table.insert(crewList, crewmem)
        end
    end
    return crewList
end

-- written by kokoro
local function convertMousePositionToEnemyShipPosition(mousePosition)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local combatControl = cApp.gui.combatControl
    local position = 0--combatControl.position -- not exposed yet
    local targetPosition = combatControl.targetPosition
    local enemyShipOriginX = position.x + targetPosition.x
    local enemyShipOriginY = position.y + targetPosition.y
    return Hyperspace.Point(mousePosition.x - enemyShipOriginX, mousePosition.y - enemyShipOriginY)
end

-- Returns a table where the indices are the IDs of all rooms adjacent to the given room
-- and the values are the rooms' coordinates
local function get_adjacent_rooms(shipId, roomId, diagonals)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
    local roomShape = shipGraph:GetRoomShape(roomId)
    local adjacentRooms = {}
    local currentRoom = nil
    local function check_for_room(x, y)
        currentRoom = shipGraph:GetSelectedRoom(x, y, false)
        if currentRoom > -1 and not adjacentRooms[currentRoom] then
            adjacentRooms[currentRoom] = Hyperspace.Pointf(x, y)
        end
    end
    for offset = 0, roomShape.w - 35, 35 do
        check_for_room(roomShape.x + offset + 17, roomShape.y - 17)
        check_for_room(roomShape.x + offset + 17, roomShape.y + roomShape.h + 17)
    end
    for offset = 0, roomShape.h - 35, 35 do
        check_for_room(roomShape.x - 17,               roomShape.y + offset + 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
    end
    if diagonals then
        check_for_room(roomShape.x - 17,               roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
        check_for_room(roomShape.x - 17,               roomShape.y + roomShape.h + 17)
    end
    return adjacentRooms
end

local RandomList = {
    New = function(self, table)
        table = table or {}
        self.__index = self
        setmetatable(table, self)
        return table
    end,

    GetItem = function(self)
        local index = Hyperspace.random32() % #self + 1
        return self[index]
    end,
}

-------------the good stuff

fishSounds = RandomList:New {"fishsplash1", "fishsplash2", "fishsplash3", "fishsplash4", "fishsplash5", "fishsplash6", "fishsplash7"}

mods.fishing.rods = {}
local rods = mods.fishing.rods
rods["FISHING_ROD_0"] = 5
rods["FISHING_ROD_1"] = 5
rods["FISHING_ROD_2"] = 10
rods["FISHING_ROD_3"] = 16

--[[

0 - droppoint
1 - civilian
2 - engi
3 - zoltan
4 - orchid
5 - mantis
6 - crystal
7 - rock
8 - rebel
9 - pirate
10 - lanius/ghost
11 - slug
12 - leech
13 - hektar
14 - ancient
15 - nexus
]]

mods.fishing.sectors = {}
local sectors = mods.fishing.sectors
sectors[0] = "FISH_DROPPOINT_"
sectors[1] = "FISH_CIVILIAN_"
sectors[2] = "FISH_ENGI_"
sectors[3] = "FISH_ZOLTAN_"
sectors[4] = "FISH_ORCHID_"
sectors[5] = "FISH_MANTIS_"
sectors[6] = "FISH_CRYSTAL_"
sectors[7] = "FISH_ROCK_"
sectors[8] = "FISH_REBEL_"
sectors[9] = "FISH_PIRATE_"
sectors[10] = "FISH_LANIUS_"
sectors[11] = "FISH_SLUG_"
sectors[12] = "FISH_LEECH_"
sectors[13] = "FISH_HEKTAR_"
sectors[14] = "FISH_ANCIENT_"
sectors[15] = "FISH_NEXUS_"
sectors[16] = "FISH_FR_"
sectors[17] = "FISH_FM_"
sectors[18] = "FISH_AI_"
sectors[19] = "FISH_CHRONO_"

local fishSpeed = 0
local fishPos = 0
local selectSpeed = 0
local selectPos = 200
local fishCatch = 46
local fishMax = 464
local fishNumber = 1
local fishDiff = 1
local fishTimer = 2
local isJump = false
local hasJump = false

local xOffset = 650
local yOffset = 75

local shipBlueprint = nil

local flagShipBlueprints = {}
flagShipBlueprints["MU_MFK_FLAGSHIP_CASUAL"] = true
flagShipBlueprints["MU_MFK_FLAGSHIP_NORMAL"] = true
flagShipBlueprints["MU_MFK_FLAGSHIP_CHALLENGE"] = true
flagShipBlueprints["MU_MFK_FLAGSHIP_EXTREME"] = true
flagShipBlueprints["FLAGSHIP_1"] = true
flagShipBlueprints["FLAGSHIP_2"] = true
flagShipBlueprints["FLAGSHIP_3"] = true
flagShipBlueprints["FLAGSHIP_CONSTRUCTION"] = true
flagShipBlueprints["BOSS_1_EASY"] = true
flagShipBlueprints["BOSS_2_EASY"] = true
flagShipBlueprints["BOSS_3_EASY"] = true
flagShipBlueprints["BOSS_1_NORMAL"] = true
flagShipBlueprints["BOSS_2_NORMAL"] = true
flagShipBlueprints["BOSS_3_NORMAL"] = true
flagShipBlueprints["BOSS_1_HARD"] = true
flagShipBlueprints["BOSS_2_HARD"] = true
flagShipBlueprints["BOSS_3_HARD"] = true
flagShipBlueprints["BOSS_1_EASY_DLC"] = true
flagShipBlueprints["BOSS_2_EASY_DLC"] = true
flagShipBlueprints["BOSS_3_EASY_DLC"] = true
flagShipBlueprints["BOSS_1_NORMAL_DLC"] = true
flagShipBlueprints["BOSS_2_NORMAL_DLC"] = true
flagShipBlueprints["BOSS_3_NORMAL_DLC"] = true
flagShipBlueprints["BOSS_1_HARD_DLC"] = true
flagShipBlueprints["BOSS_2_HARD_DLC"] = true
flagShipBlueprints["BOSS_3_HARD_DLC"] = true

local fishBeingCaught = false

local reelPos = 1
local releasePos = 1
local reelMax = 34
local releaseMax = 27
local soundTimer=0


script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    local fishingData = rods[weaponBlueprint.name]
    if fishingData and Hyperspace.playerVariables.fish_this_jump == 0 then
        shipBlueprint = Hyperspace.ships.enemy.myBlueprint.blueprintName
        --print(shipBlueprint)
        Hyperspace.playerVariables.fish_this_jump = 1
        Hyperspace.playerVariables.fish_active = 1
        local shipManager = Hyperspace.ships.player
        local fishMin = 1
        local hasRepel = shipManager:HasAugmentation("FISH_INAUG_REPEL") > 0
        if hasRepel and fishingData >= 5 then
            fishMin = math.floor(fishingData * 0.41)
        end
        --log(tostring(fishMin).."to"..tostring(maxRodStrength))
        fishNumber = math.random(1,fishingData)
        if fishNumber < fishMin then fishNumber = fishNumber + fishMin end
        fishCatch = 92
        xOffset = 650
        selectSpeed = 0
        selectPos = 200
        fishSpeed = 0
        fishPos = 0
        projectile:Kill()
    end
end)

local function fish_start_event()
    local shipManager = Hyperspace.ships.player
    local maxRodStrength = 5
    shipBlueprint = nil
    for weapon in vter(shipManager:GetWeaponList()) do
        local fishingData = rods[weapon.blueprint.name]
        if fishingData then
            maxRodStrength = math.max(maxRodStrength, fishingData)
        end
    end

    local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    local cargoList = commandGui.equipScreen:GetCargoHold()

    for item in vter(cargoList) do
        --hasCargo = true
        local fishingData = rods[item]
        if fishingData then
            maxRodStrength = math.max(maxRodStrength, fishingData)
        end
    end
    local fishMin = 1
    local hasRepel = shipManager:HasAugmentation("FISH_INAUG_REPEL") > 0
    if hasRepel and maxRodStrength >= 5 then
        fishMin = math.floor(maxRodStrength * 0.41)
    end
    Hyperspace.playerVariables.fish_this_jump = 1
    Hyperspace.playerVariables.fish_active = 1
    Hyperspace.playerVariables.fish_again = Hyperspace.playerVariables.fish_again + 1
    --log(tostring(fishMin).."to"..tostring(maxRodStrength))
    fishNumber = math.random(1,maxRodStrength)
    if fishNumber < fishMin then fishNumber = fishNumber + fishMin end
    fishCatch = 92
    xOffset = 850
    selectSpeed = 0
    selectPos = 200
    fishSpeed = 0
    fishPos = 0
end

script.on_game_event("FISHING_START_NOCOMBAT", false, fish_start_event)
script.on_game_event("FISHING_START_NOCOMBAT2", false, fish_start_event)
script.on_game_event("FISHING_START_NOCOMBAT3", false, fish_start_event)
script.on_game_event("FISHING_START_NOCOMBAT4", false, fish_start_event)
script.on_game_event("FISHING_START_NOCOMBAT5", false, fish_start_event)
script.on_game_event("FISHING_START_NOCOMBAT6", false, fish_start_event)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x, y)
    --print("MousePos "..tostring(x).." "..tostring(y))
    local mousePos = Hyperspace.Mouse.position

    if mousePos.x >= xOffset+18 and mousePos.x <= xOffset+18+98 and mousePos.y >= yOffset+409 and mousePos.y <= yOffset+409+73 and Hyperspace.playerVariables.fish_active == 1 then
        isJump = true
        hasJump = false
        --print("CLICK")
    end
end)


--[[
////////////////////
CUSTOM BUTTON HOTKEYS
////////////////////
]]--

-- Initialize hotkeys
script.on_init(function()
    if Hyperspace.metaVariables.prof_hotkey_fish == 0 then Hyperspace.metaVariables.prof_hotkey_fish = 9 end
end)

-- Track when the hotkeys are being configured
local settingFish = false
script.on_game_event("COMBAT_CHECK_HOTKEYS_FISH_START", false, function() settingFish = true end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_FISH_END_1", false, function() settingFish = false end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_FISH_END_2", false, function() settingFish = false end)

script.on_internal_event(Defines.InternalEvents.ON_KEY_DOWN, function(key)
    --print(key)
    -- Allow player to reconfigure the hotkeys
    if settingFish then Hyperspace.metaVariables.prof_hotkey_fish = key end
    
    -- Do stuff if a hotkey is pressed
    local cmdGui = Hyperspace.Global.GetInstance():GetCApp().gui
    if Hyperspace.ships.player and not (Hyperspace.ships.player.bJumping or cmdGui.event_pause or cmdGui.menu_pause) then
        
        if key == Hyperspace.metaVariables.prof_hotkey_fish and Hyperspace.playerVariables.fish_active == 1 then
            isJump = true
            hasJump = false
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.ON_KEY_UP, function(key)
    local cmdGui = Hyperspace.Global.GetInstance():GetCApp().gui
    if Hyperspace.ships.player and not (Hyperspace.ships.player.bJumping or cmdGui.event_pause or cmdGui.menu_pause) then
        if key == Hyperspace.metaVariables.prof_hotkey_fish and Hyperspace.playerVariables.fish_active == 1 then
            isJump = false
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_UP, function(x, y)
    --print("MousePos "..tostring(x).." "..tostring(y))
    local mousePos = Hyperspace.Mouse.position

    if mousePos.x >= xOffset+18 and mousePos.x <= xOffset+18+98 and mousePos.y >= yOffset+409 and mousePos.y <= yOffset+409+73 and Hyperspace.playerVariables.fish_active == 1 then
        isJump = false
        --print("CLICK")
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    for weapon in vter(shipManager:GetWeaponList()) do
        local fishingData = rods[weapon.blueprint.name]
        if fishingData and shipManager:HasAugmentation("FISH_INAUG_PREIG") > 0 then
            weapon.cooldown.first = math.max(0, weapon.cooldown.second - 0.05)
        elseif fishingData then
            --weapon.cooldown.first = 0
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        local shipManager = Hyperspace.ships.player
        local maxRodStrength = 5
        for weapon in vter(shipManager:GetWeaponList()) do
            local fishingData = rods[weapon.blueprint.name]
            if fishingData then
                maxRodStrength = math.max(maxRodStrength, fishingData)
                if Hyperspace.playerVariables.fish_active == 1 then
                    weapon.boostLevel = 2
                elseif Hyperspace.playerVariables.fish_active == 0 and weapon.boostLevel == 2 then
                    weapon.boostLevel = 1
                elseif weapon.cooldown.first > 1 and Hyperspace.playerVariables.fish_this_jump == 1 and weapon.cooldown.first <= 10 then
                    weapon.boostLevel = 1
                end
            end
        end

        local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
        local cargoList = commandGui.equipScreen:GetCargoHold()

        for item in vter(cargoList) do
            --hasCargo = true
            local fishingData = rods[item]
            if fishingData then
                local maxRodStrength = math.max(maxRodStrength, fishingData)
            end
        end

        local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
        if Hyperspace.playerVariables.fish_active == 1 and not (commandGui.bPaused or commandGui.event_pause) then
            local gravity = 50
            local maxSpeed = 150
            if isJump and not hasJump then
                --print("JUMP")
                hasJump = true
                if selectSpeed < 0 then
                    selectSpeed = selectSpeed / 2
                end
                selectSpeed = math.min(selectSpeed + 50, maxSpeed)
            else
                selectSpeed = math.max(selectSpeed - (gravity+20) * Hyperspace.FPS.SpeedFactor/16, maxSpeed * -1)
            end

            selectPos = math.max(math.min(selectPos + selectSpeed * Hyperspace.FPS.SpeedFactor/16 , 446-36), 0+36)
            if selectPos == 0+36 then
                selectSpeed = selectSpeed / -2
            elseif selectPos == 446-36 then
                selectSpeed = selectSpeed / -2
            end


            if fishSpeed > 0 then 
                fishSpeed = fishSpeed - (gravity) *  Hyperspace.FPS.SpeedFactor/16
            elseif fishSpeed < 0 then
                fishSpeed = fishSpeed + (gravity) *  Hyperspace.FPS.SpeedFactor/16
            end

            fishTimer = math.max(fishTimer - Hyperspace.FPS.SpeedFactor/16, 0)
            if fishTimer == 0 then
                local soundName = fishSounds:GetItem()
                Hyperspace.Sounds:PlaySoundMix(soundName, -1, false)
                fishTimer = 1 - (fishNumber/17) + (2*math.random())
                local negative = math.random()
                local random = ((math.random() + 3) * (fishNumber * 2 + 20))
                if negative >= 0.5 then 
                    random = -1 * random
                end
                fishSpeed = fishSpeed / 2
                fishSpeed = math.max(-100, math.min(100, fishSpeed + random))
            end
            fishPos = math.max(0, math.min(fishPos + fishSpeed * Hyperspace.FPS.SpeedFactor/16, 446))
            if fishPos == 0 then
                fishSpeed = fishSpeed * -1.5
            elseif fishPos == 446 then
                fishSpeed = fishSpeed * -1.5
            end

            if math.abs(selectPos - fishPos) < 46 then
                local maxRandom = 4

                --print("Catching: ".. tostring(fishCatch))
                fishBeingCaught = true
                fishCatch = math.min(fishMax, fishCatch + Hyperspace.FPS.SpeedFactor/16 * 2.75  * ((maxRodStrength/5) + (16-fishNumber)))
                if fishCatch == fishMax then 
                    local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
                    if Hyperspace.playerVariables.fish_music == 0 then
                        Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"FISH_END_MUSIC",false,-1)
                    end
                    Hyperspace.playerVariables.fish_active = 0
                    if flagShipBlueprints[shipBlueprint] then
                        Hyperspace.CustomAchievementTracker.instance:SetAchievement("FISHING_SHIP_ACH_3", false)
                    end
                    if fishNumber == 16 then
                        Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"FISH_ULTRA_RARE",false,-1)
                    else
                        if shipManager:HasAugmentation("FISH_INAUG_BAIT") > 0 then
                            maxRandom = 3
                        end
                        local randomJunk = math.random(1, maxRandom)
                        local fishNumber2 = math.ceil(fishNumber/5)
                        if randomJunk > 1 and Hyperspace.playerVariables.jumps_since_fish <= 7 - fishNumber2 and shipManager:HasAugmentation("FISH_AUG_FISHINGONLY") == 0 and shipManager:HasAugmentation("FISH_AUG_FISH_BOON") == 0 then
                            Hyperspace.playerVariables.jumps_since_fish = Hyperspace.playerVariables.jumps_since_fish + 1
                            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"FISH_JUNK",false,-1)
                        else
                            Hyperspace.playerVariables.jumps_since_fish = 0
                            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,sectors[Hyperspace.playerVariables.fish_sector]..fishNumber2,false,-1)
                        end
                    end
                end
            else
                fishBeingCaught = false
                fishCatch = math.max(0, fishCatch - Hyperspace.FPS.SpeedFactor/16 * 5 * (5 - math.ceil(maxRodStrength/5)))
                if fishCatch == 0 then
                    Hyperspace.playerVariables.fish_active = 0
                    if Hyperspace.playerVariables.fish_music == 0 then
                        local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
                        Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"FISH_END_MUSIC",false,-1)
                        --userdata_table(shipManager,"mods.fish.endMusic").time = 0.2
                    end
                    --Hyperspace.playerVariables.fish_this_sector = 2
                end
            end
        end
        --[[local musicTable = userdata_table(shipManager,"mods.fish.endMusic")
        if musicTable.time then
            musicTable.time = musicTable.time - Hyperspace.FPS.SpeedFactor/16
            if musicTable.time < 0 then
                musicTable.time = nil
                local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"FISH_END_MUSIC",false,-1)
            end
        end]]
    end
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.playerVariables.fish_active == 1 then
        soundTimer = math.max(0, soundTimer - Hyperspace.FPS.SpeedFactor/16)
        if soundTimer == 0 then
            soundTimer = 0.1
            if fishBeingCaught then
                Hyperspace.Sounds:PlaySoundMix("reel"..tostring(reelPos), -1, false)
                reelPos = reelPos + 1
                if reelPos > reelMax then
                    reelPos = 1
                end
            else
                Hyperspace.Sounds:PlaySoundMix("release"..tostring(releasePos), -1, false)
                releasePos = releasePos + 1
                if releasePos > releaseMax then
                    releasePos = 1
                end
            end
        end
    end
end)

local fish_back_image = Hyperspace.Resources:CreateImagePrimitiveString(
    "statusUI/fish_back.png",
    0,
    0,
    0,
    Graphics.GL_Color(1, 1, 1, 1),
    1.0,
    false)

local fish_pressed = Hyperspace.Resources:CreateImagePrimitiveString(
    "statusUI/fish_pressed.png",
    0,
    0,
    0,
    Graphics.GL_Color(1, 1, 1, 1),
    1.0,
    false)

local fish_back_select_image = Hyperspace.Resources:CreateImagePrimitiveString(
    "statusUI/fish_back_select.png",
    0,
    0,
    0,
    Graphics.GL_Color(1, 1, 1, 1),
    1.0,
    false)

local barTexture = Hyperspace.Resources:GetImageId("statusUI/fish_bar.png")
local barImage = Graphics.CSurface.GL_CreateImagePrimitive(barTexture,0, 0, 10, 1, 0, Graphics.GL_Color(1, 1, 1, 1))

--local fishString = "fish/fish"..fishNumber..".png"
local fish_fish_image = {}
fish_fish_image[1] = Hyperspace.Resources:CreateImagePrimitiveString("fish/fish1.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[2] = Hyperspace.Resources:CreateImagePrimitiveString("fish/fish2.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[3] = Hyperspace.Resources:CreateImagePrimitiveString("fish/fish3.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[4] = Hyperspace.Resources:CreateImagePrimitiveString("fish/fish4.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[5] = Hyperspace.Resources:CreateImagePrimitiveString("fish/fish5.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[6] = Hyperspace.Resources:CreateImagePrimitiveString( "fish/fish6.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[7] = Hyperspace.Resources:CreateImagePrimitiveString( "fish/fish7.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[8] = Hyperspace.Resources:CreateImagePrimitiveString( "fish/fish8.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[9] = Hyperspace.Resources:CreateImagePrimitiveString( "fish/fish9.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[10] = Hyperspace.Resources:CreateImagePrimitiveString( "fish/fish10.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[11] = Hyperspace.Resources:CreateImagePrimitiveString( "fish/fish11.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[12] = Hyperspace.Resources:CreateImagePrimitiveString( "fish/fish12.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[13] = Hyperspace.Resources:CreateImagePrimitiveString( "fish/fish13.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[14] = Hyperspace.Resources:CreateImagePrimitiveString( "fish/fish14.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[15] = Hyperspace.Resources:CreateImagePrimitiveString( "fish/fish15.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
fish_fish_image[16] = Hyperspace.Resources:CreateImagePrimitiveString( "fish/fish16.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

local fish_select_image = Hyperspace.Resources:CreateImagePrimitiveString(
    "statusUI/fish_select.png",
    0,
    0,
    0,
    Graphics.GL_Color(1, 1, 1, 1),
    1.0,
    false)



script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
    local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables.fish_active == 1 and not commandGui.menu_pause then
        --Graphics.CSurface.GL_ClearAll()

        local mousePos = Hyperspace.Mouse.position
        local hoverButton = false
        if mousePos.x >= xOffset+18 and mousePos.x <= xOffset+18+98 and mousePos.y >= yOffset+409 and mousePos.y <= yOffset+409+73 then hoverButton = true else hoverButton = false end
        
        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(xOffset,yOffset,0)
        Graphics.CSurface.GL_RenderPrimitive(fish_back_image)
        if isJump then 
            Graphics.CSurface.GL_RenderPrimitive(fish_pressed)
        end

        if hoverButton then
            Graphics.CSurface.GL_RenderPrimitive(fish_back_select_image)
        end
        Graphics.CSurface.GL_PopMatrix()

        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(xOffset+190,yOffset+18+464-fishCatch,0)
        Graphics.CSurface.GL_Scale(1,fishCatch,0)
        Graphics.CSurface.GL_RenderPrimitive(barImage)
        Graphics.CSurface.GL_PopMatrix()

        
        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(xOffset+124,yOffset+18+446-fishPos,0)
        Graphics.CSurface.GL_RenderPrimitive(fish_fish_image[fishNumber])
        Graphics.CSurface.GL_PopMatrix()
        
        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(xOffset+124,yOffset+18+446-36-selectPos,0)
        Graphics.CSurface.GL_RenderPrimitive(fish_select_image)
        Graphics.CSurface.GL_PopMatrix()
    end
end, function() end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
    local scrapLeft = 0
    Hyperspace.playerVariables.fish_again = 0
    if Hyperspace.playerVariables.fish_this_jump == 1 then
        Hyperspace.playerVariables.fish_this_jump = 0
        --Hyperspace.playerVariables.fish_this_sector = 5
    end
    if Hyperspace.playerVariables.fish_this_sector >= 1 then
        Hyperspace.playerVariables.fish_this_sector = Hyperspace.playerVariables.fish_this_sector - 1
    end
    --[[for weapon in vter(shipManager:GetWeaponList()) do
        local fishingData = rods[weapon.blueprint.name]
        if fishingData then
            weapon.boostLevel = 0
        end
    end]]
end)

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
    --print(event.eventName)
    if event.eventName == "STORAGE_CHECK_FISHING_STATS" then
        print()
        event.text.data = "Fishing Stats: \n" .. 
            "Successful Fishing Attempts: " .. tostring(math.floor(Hyperspace.playerVariables.fish_caught)) .. "\n" ..
            "Basic Fish Caught: " .. tostring(math.floor(Hyperspace.playerVariables.fish_caught_basic)) .. "\n" ..
            "Uncommon Fish Caught: " .. tostring(math.floor(Hyperspace.playerVariables.fish_caught_uncom)) .. "\n" ..
            "Rare Fish Caught: " .. tostring(math.floor(Hyperspace.playerVariables.fish_caught_rare)) .. "\n" ..
            "Legendary Fish Caught: " .. tostring(math.floor(Hyperspace.playerVariables.fish_caught_leg)) .. "\n" ..
            "Unique Fish Caught: " .. tostring(math.floor(Hyperspace.playerVariables.fish_caught_unique)) .. "\n" ..
            "Gun Fish Caught: " .. tostring(math.floor(Hyperspace.playerVariables.fish_caught_guns)) --.. "\n\n\n" ..
            --"Fishes Consumed:"
    end
end)

--[[local loopCount = 0
for choice in vter(event.choices) do
    if loopCount == 1 then
        print(choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught))
        choice.text.data = choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught)
    elseif loopCount == 2 then
        print(choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_basic))
        choice.text.data = choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_basic)
    elseif loopCount == 3 then
        print(choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_uncom))
        choice.text.data = choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_uncom)
    elseif loopCount == 4 then
        print(choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_rare))
        choice.text.data = choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_rare)
    elseif loopCount == 5 then
        print(choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_leg))
        choice.text.data = choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_leg)
    elseif loopCount == 6 then
        print(choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_unique))
        choice.text.data = choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_unique)
    elseif loopCount == 7 then
        print(choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_guns))
        choice.text.data = choice.text.data .. tostring(Hyperspace.playerVariables.fish_caught_guns)
    end
    loopCount = loopCount + 1
end]]

--[[

0 - droppoint
1 - civilian
2 - engi
3 - zoltan
4 - orchid
5 - mantis
6 - crystal
7 - rock
8 - rebel
9 - pirate
10 - lanius/ghost
11 - slug
12 - leech
13 - hektar
14 - ancient
15 - nexus


Old Boot

Tin Can


Fish Weapons
2 Fish Laser

2 Fish Flak

2 Fissile
    causes errosion and crew damage

1 Fish Minelauncher
    anti submarine mines

1 bomb fish bomb

2 Fishion

2 Fish Beam

1 fish pinpoint

Fishes

+5% hp

+15% hp

+50% hp

+5% damage

+15% damage

+50% damage

+5% damageReduction

+15% damageReduction

+50% damage Reduction

+5% speed

+15% speed

+50% speed



]]

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("FISH_AUG_33") > 0 then
        for system in vter(shipManager.vSystemList) do
            if system:NeedsRepairing() then
                system:PartialRepair(2,false)
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    local hullData = userdata_table(shipManager, "mods.arc.hullData")
    if shipManager:HasAugmentation("ARC_SUPER_HULL") > 0   then
        hullData.tempHp = math.floor(shipManager:GetAugmentationValue("ARC_SUPER_HULL"))
    else
        hullData.tempHp = nil
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    --log(beamHitType)
    if shipManager:HasAugmentation("ARC_SUPER_HULL") > 0 and beamHitType == 2 then
       local hullData = userdata_table(shipManager, "mods.arc.hullData")
        if hullData.tempHp then 
            if hullData.tempHp > 0 and damage.iDamage > 0 then
                hullData.tempHp = hullData.tempHp - damage.iDamage
                shipManager:DamageHull((-1 * damage.iDamage), true)
            end
        end
    end 
    return Defines.Chain.CONTINUE, beamHitType
end) 

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if shipManager:HasAugmentation("ARC_SUPER_HULL") > 0 then
        local hullData = userdata_table(shipManager, "mods.arc.hullData")
        if hullData.tempHp then 
            if hullData.tempHp > 0 and damage.iDamage > 0 then
                hullData.tempHp = hullData.tempHp - damage.iDamage
                shipManager:DamageHull((-1 * damage.iDamage), true)
            end
        end
    end
end)

local xPos = 380
local yPos = 47
local xText = 413
local yText = 58
local tempHpImage = Hyperspace.Resources:CreateImagePrimitiveString(
    "statusUI/arc_tempHull.png",
    xPos,
    yPos,
    0,
    Graphics.GL_Color(1, 1, 1, 1),
    1.0,
    false)
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        local hullData = userdata_table(shipManager, "mods.arc.hullData")
        if hullData.tempHp then
            local hullHP = math.floor(hullData.tempHp)
            Graphics.CSurface.GL_RenderPrimitive(tempHpImage)
            Graphics.freetype.easy_print(0, xText, yText, hullHP)
        end
    end
end, function() end)


script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("ARC_WEAPON_POWER") > 0 and Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then 
        local first = true
        local powerNum = math.floor(shipManager:GetAugmentationValue("ARC_WEAPON_POWER"))

        --print("loop start: "..tostring(powerNum))
        for weapon in vter(shipManager:GetWeaponList()) do 
            --print("Powernum: "..tostring(powerNum))
            local powerReduction = powerNum
            if powerNum > weapon.blueprint.power then
                powerReduction = weapon.blueprint.power
            end
            --print(powerReduction)
            if weapon.powered and weapon.requiredPower ~= (weapon.blueprint.power - powerReduction) then
                shipManager.weaponSystem:ForceDecreasePower(shipManager.weaponSystem:GetMaxPower())
            end
            weapon.requiredPower = weapon.blueprint.power - powerReduction
            powerNum = powerNum - powerReduction
            --[[if weapon.blueprint.power >= 1 and first then
                first = false
                if weapon.requiredPower == weapon.blueprint.power and weapon.powered then 
                    shipManager.weaponSystem:ForceDecreasePower(shipManager.weaponSystem:GetMaxPower())
                end
                weapon.requiredPower = weapon.blueprint.power - 1
            elseif weapon.requiredPower ~= weapon.blueprint.power then
                if weapon.powered then
                    shipManager.weaponSystem:ForceDecreasePower(shipManager.weaponSystem:GetMaxPower())
                end
                weapon.requiredPower = weapon.blueprint.power
            end]]
        end 
    end
end)

local crystalGun = Hyperspace.Blueprints:GetWeaponBlueprint("CRYSTAL_HEAVY_1")
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if shipManager:HasAugmentation("FISH_AUG_47") > 0 then
        local targetRoom = get_room_at_location(shipManager, location, true)
        for i, crewmem in ipairs(get_ship_crew_room(shipManager, targetRoom)) do
            local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
            local otherShip = Hyperspace.Global.GetInstance():GetShipManager(math.abs(shipManager.iShipId-1))
            local crystal = spaceManager:CreateMissile(
                crystalGun,
                projectile.position,
                projectile.currentSpace,
                shipManager.iShipId,
                otherShip:GetRandomRoomCenter(),
                math.abs(shipManager.iShipId-1),
                0.0)
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    if shipManager:HasAugmentation("FISH_AUG_47") > 0 and realNewTile then
        local targetRoom = get_room_at_location(shipManager, location, true)
        for i, crewmem in ipairs(get_ship_crew_point(shipManager, location.x, location.y)) do
            local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
            local otherShip = Hyperspace.Global.GetInstance():GetShipManager(math.abs(shipManager.iShipId-1))
            local crystal = spaceManager:CreateMissile(
                crystalGun,
                projectile.position,
                projectile.currentSpace,
                shipManager.iShipId,
                otherShip:GetRandomRoomCenter(),
                math.abs(shipManager.iShipId-1),
                0.0)
        end
    end
end)

local scrapLeft = 10

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if damage.iDamage > 0 and scrapLeft < 10 then
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager(math.abs(shipManager.iShipId-1))
        if shipManager:HasAugmentation("FISH_AUG_40") > 0 then
            shipManager:ModifyScrapCount((-3 * shipManager:HasAugmentation("FISH_AUG_40")),false)
            scrapLeft = scrapLeft - (3 * shipManager:HasAugmentation("FISH_AUG_40"))
        elseif otherShip:HasAugmentation("FISH_AUG_40") > 0 then
            otherShip:ModifyScrapCount(shipManager:HasAugmentation("FISH_AUG_40"),false)
            scrapLeft = scrapLeft + shipManager:HasAugmentation("FISH_AUG_40")
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    if damage.iDamage > 0 and realNewTile and scrapLeft < 10 then
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager(math.abs(shipManager.iShipId-1))
        if shipManager:HasAugmentation("FISH_AUG_40") > 0 then
            shipManager:ModifyScrapCount((-3 * shipManager:HasAugmentation("FISH_AUG_40")),false)
            scrapLeft = scrapLeft - (3 * shipManager:HasAugmentation("FISH_AUG_40"))
        elseif otherShip:HasAugmentation("FISH_AUG_40") > 0 then
            otherShip:ModifyScrapCount(shipManager:HasAugmentation("FISH_AUG_40"),false)
            scrapLeft = scrapLeft + shipManager:HasAugmentation("FISH_AUG_40")
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if projectile.extend.name == "FISH_FOOD_ION" then
        local targetRoom = get_room_at_location(shipManager, location, true)
        for i, crewmem in ipairs(get_ship_crew_room(shipManager, targetRoom)) do
            local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
            local otherShip = Hyperspace.Global.GetInstance():GetShipManager(math.abs(shipManager.iShipId-1))
            local randomRoom = get_room_at_location(shipManager, shipManager:GetRandomRoomCenter(), false)
            crewmem:SetRoomPath(0, randomRoom)
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    if weaponBlueprint.name == "FISH_FOOD_MISSILE_1" then 
        local damage = projectile.damage
        damage.iDamage = 0
        projectile:SetDamage(damage)
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if projectile.extend.name == "FISH_FOOD_MISSILE_1" then
        local damage2 = Hyperspace.Damage()
        damage2.iDamage = 3
        local weaponName = projectile.extend.name
        projectile.extend.name = ""
        shipManager:DamageArea(location, damage2, true)
        projectile.extend.name = weaponName
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    if projectile.extend.name == "FISH_FOOD_BEAM" and beamHitType == Defines.BeamHit.NEW_ROOM then
        local damage2 = Hyperspace.Damage()
        damage2.bLockdown = true
        local weaponName = projectile.extend.name
        projectile.extend.name = ""
        shipManager:DamageArea(location, damage2, true)
        projectile.extend.name = weaponName
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("FISH_AUG_35") > 0 then
        for system in vter(shipManager.vSystemList) do 
            system.iActiveManned = 3
        end
    end
end)