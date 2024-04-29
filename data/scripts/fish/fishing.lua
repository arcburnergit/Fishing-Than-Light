mods.fishing = {}

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
    local radCrewList = {}
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and crewmem.iRoomId == roomId then
            table.insert(radCrewList, crewmem)
        end
    end
    return radCrewList
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



script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    local fishingData = rods[weaponBlueprint.name]
    if fishingData then
        shipBlueprint = Hyperspace.ships.enemy.myBlueprint.blueprintName
        print(shipBlueprint)
        Hyperspace.playerVariables.fish_this_jump = 1
        Hyperspace.playerVariables.fish_active = 1
        fishNumber = math.random(1,fishingData)
        fishCatch = 92
        xOffset = 650
        projectile:Kill()
    end
end)

script.on_game_event("FISHING_START_NOCOMBAT", false, function()
    local shipManager = Hyperspace.ships.player
    local maxRodStrength = 5
    shipBlueprint = nil
    for weapon in vter(shipManager:GetWeaponList()) do
        local fishingData = rods[weapon.blueprint.name]
        if fishingData then
            local maxRodStrength = math.max(maxRodStrength, fishingData)
        end
    end
    Hyperspace.playerVariables.fish_this_jump = 1
    Hyperspace.playerVariables.fish_active = 1
    fishNumber = math.random(1,maxRodStrength)
    fishCatch = 92
    xOffset = 850
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x, y)
    --print("MousePos "..tostring(x).." "..tostring(y))
    if x >= xOffset+18 and x <= xOffset+18+98 and y >= yOffset+409 and y <= yOffset+409+73 and Hyperspace.playerVariables.fish_active == 1 then
        isJump = true
        hasJump = false
        --print("CLICK")
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    local maxRodStrength = 5
    for weapon in vter(shipManager:GetWeaponList()) do
        local fishingData = rods[weapon.blueprint.name]
        if fishingData then
            local maxRodStrength = math.max(maxRodStrength, fishingData)
            if Hyperspace.playerVariables.fish_this_sector >= 1 then
                weapon.boostLevel = 1
            elseif Hyperspace.playerVariables.fish_active == 1 then
                weapon.boostLevel = 2
            elseif Hyperspace.playerVariables.fish_this_jump == 1 then
                weapon.boostLevel = 1
            end
        end
    end

    local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    if Hyperspace.playerVariables.fish_active == 1 and not commandGui.bPaused then
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
            Hyperspace.Sounds:PlaySoundMix(soundName, -1, true)
            fishTimer = 1 + (2*math.random())
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
            --print("Catching: ".. tostring(fishCatch))
            fishCatch = math.min(fishMax, fishCatch + Hyperspace.FPS.SpeedFactor/16 * 2.75  * ((maxRodStrength/5) + (16-fishNumber)))
            if fishCatch == fishMax then 
                --print("WIN")
                --fishCatch = 0b
                Hyperspace.playerVariables.fish_active = 0
                -- TRIGGER FISH CATCH
                --[[if Hyperspace.ships.enemy then
                    --print("isFighting enemy")
                    if flagShipBlueprints[Hyperspace.ships.enemy.myBlueprint.blueprintName] then
                        --print("FIGHTING FLAGSHIP")
                        Hyperspace.CustomAchievementTracker.instance:SetAchievement("FISHING_SHIP_ACH_3", false)
                    end
                end]]
                if flagShipBlueprints[shipBlueprint] then
                    Hyperspace.CustomAchievementTracker.instance:SetAchievement("FISHING_SHIP_ACH_3", false)
                end
                if fishNumber == 16 then
                    local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
                    Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"FISH_ULTRA_RARE",false,-1)
                else
                    local fishNumber2 = math.ceil(fishNumber/5)
                    local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
                    Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,sectors[Hyperspace.playerVariables.fish_sector]..fishNumber2,false,-1)
                end
            end
        else
            fishCatch = math.max(0, fishCatch - Hyperspace.FPS.SpeedFactor/16 * 3 * (5 - math.ceil(maxRodStrength/5)))
            if fishCatch == 0 then
                Hyperspace.playerVariables.fish_active = 0
                Hyperspace.playerVariables.fish_this_jump = 0
                Hyperspace.playerVariables.fish_this_sector = 2
            end
        end
    end
end)



script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
    local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables.fish_active == 1 and not commandGui.menu_pause then
        --Graphics.CSurface.GL_ClearAll()

        local mousePos = Hyperspace.Mouse.position
        local hoverButton = false
        if mousePos.x >= xOffset+18 and mousePos.x <= xOffset+18+98 and mousePos.y >= yOffset+409 and mousePos.y <= yOffset+409+73 then hoverButton = true else hoverButton = false end
        local fish_back_image = Hyperspace.Resources:CreateImagePrimitiveString(
            "statusUI/fish_back.png",
            xOffset,
            yOffset,
            0,
            Graphics.GL_Color(1, 1, 1, 1),
            1.0,
            false)
        Graphics.CSurface.GL_RenderPrimitive(fish_back_image)
        Graphics.CSurface.GL_DestroyPrimitive(fish_back_image)
        if hoverButton then
            local fish_back_select_image = Hyperspace.Resources:CreateImagePrimitiveString(
                "statusUI/fish_back_select.png",
                xOffset,
                yOffset,
                0,
                Graphics.GL_Color(1, 1, 1, 1),
                1.0,
                false)
            Graphics.CSurface.GL_RenderPrimitive(fish_back_select_image)
            Graphics.CSurface.GL_DestroyPrimitive(fish_back_select_image)
        end
        local barTexture = Hyperspace.Resources:GetImageId("statusUI/fish_bar.png")
        local barImage = Graphics.CSurface.GL_CreateImagePrimitive(barTexture,xOffset+190, 75+18+464-fishCatch, 10, fishCatch, 0, Graphics.GL_Color(1, 1, 1, 1))
        Graphics.CSurface.GL_RenderPrimitive(barImage)
        Graphics.CSurface.GL_DestroyPrimitive(barImage)

        local fishString = "fish/fish"..fishNumber..".png"
        local fish_fish_image = Hyperspace.Resources:CreateImagePrimitiveString(
            fishString,
            xOffset+124,
            yOffset+18+446-fishPos,
            0,
            Graphics.GL_Color(1, 1, 1, 1),
            1.0,
            false)
        Graphics.CSurface.GL_RenderPrimitive(fish_fish_image)
        Graphics.CSurface.GL_DestroyPrimitive(fish_fish_image)
        local fish_select_image = Hyperspace.Resources:CreateImagePrimitiveString(
            "statusUI/fish_select.png",
            xOffset+124,
            yOffset+18+446-36-selectPos,
            0,
            Graphics.GL_Color(1, 1, 1, 1),
            1.0,
            false)
        Graphics.CSurface.GL_RenderPrimitive(fish_select_image)
        Graphics.CSurface.GL_DestroyPrimitive(fish_select_image)
    end
end, function() end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    if Hyperspace.playerVariables.fish_this_jump == 1 then
        Hyperspace.playerVariables.fish_this_jump = 0
        Hyperspace.playerVariables.fish_this_sector = 5
    end
    if Hyperspace.playerVariables.fish_this_sector >= 1 then
        Hyperspace.playerVariables.fish_this_sector = Hyperspace.playerVariables.fish_this_sector - 1
    end
end)


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

script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        local hullData = userdata_table(shipManager, "mods.arc.hullData")
        if hullData.tempHp then
            local hullHP = hullData.tempHp
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
            Graphics.CSurface.GL_RenderPrimitive(tempHpImage)
            Graphics.freetype.easy_print(0, xText, yText, hullHP)
        end
    end
end, function() end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("FISH_AUG_44") > 0 and shipManager:HasSystem(0) then
        shipManager.shieldSystem:SetBonusPower(2,0)
    end
end)
local crystalGun = Hyperspace.Blueprints:GetWeaponBlueprint("CRYSTAL_BURST_1")
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if shipManager:HasAugmentation("FISH_AUG_47") > 0 then
        local targetRoom = get_room_at_location(shipManager, location, true)
        for crewmem in vter(get_ship_crew_room(shipManager, targetRoom)) do
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
        for crewmem in vter(get_ship_crew_point(shipManager, location.x, location.y)) do
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

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if damage.iDamage > 0 then
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager(math.abs(shipManager.iShipId-1))
        if shipManager:HasAugmentation("FISH_AUG_40") > 0 then
            shipManager:ModifyScrapCount(-3,false)
        elseif otherShip:HasAugmentation("FISH_AUG_40") > 0 then
            otherShip:ModifyScrapCount(1,false)
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    if damage.iDamage > 0 and realNewTile then
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager(math.abs(shipManager.iShipId-1))
        if shipManager:HasAugmentation("FISH_AUG_40") > 0 then
            shipManager:ModifyScrapCount(-3,false)
        elseif otherShip:HasAugmentation("FISH_AUG_40") > 0 then
            otherShip:ModifyScrapCount(1,false)
        end
    end
end)