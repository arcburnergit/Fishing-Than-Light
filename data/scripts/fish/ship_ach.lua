----------------------
-- HELPER FUNCTIONS --
----------------------

local function vter(cvec)
    local i = -1
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end
--local is_first_shot = mods.vertexutil.is_first_shot
local function userdata_table(userdata, tableName)
    if not userdata.table[tableName] then userdata.table[tableName] = {} end
    return userdata.table[tableName]
end

local function string_starts(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

local function should_track_achievement(achievement, ship, shipClassName)
    return ship and
           Hyperspace.App.world.bStartedGame and
           Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achievement) < Hyperspace.Settings.difficulty and
           string_starts(ship.myBlueprint.blueprintName, shipClassName)
end

local function current_sector()
    return Hyperspace.App.world.starMap.worldLevel + 1
end

local function count_ship_achievements(achPrefix)
    local count = 0
    for i = 1, 3 do
        if Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achPrefix.."_"..tostring(i)) > -1 then
            count = count + 1
        end
    end
    return count
end

-------------
-- FISHING --
-------------

local function check_fish_ach(itemName)
    if string_starts(itemName, "FISH_FOOD_") then
        if itemName == "FISH_FOOD_4E" then
            unlockTracker:UnlockShip("PLAYER_SHIP_FISHING_3", false)
        end
        local fishId = string.sub(itemName, 11, string.len(itemName))
        --print(itemName)
        --print("fish_obtained_"..tostring(fishId))
        Hyperspace.metaVariables["fish_obtained_"..tostring(fishId)] = 1
        return true
    elseif string_starts(itemName, "FISH_WEAPON_") then
        return true
    end
    return false
end

local function ach_check_loop()
    local shipManager = Hyperspace.ships.player
    if shipManager.iShipId == 0 then
        local weaponList = shipManager:GetWeaponList()
        local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
        local cargoList = commandGui.equipScreen:GetCargoHold()
        for weapon in vter(weaponList) do
            local itemName = weapon.blueprint.name
            check_fish_ach(itemName)
        end
        local allFishCargo = true
        --local hasCargo = false
        for item in vter(cargoList) do
            --hasCargo = true
            local itemName = item
            if not check_fish_ach(itemName) then
                allFishCargo = false
            end
        end
        if allFishCargo and cargoList:size() >=4 then
            print("FISHING_SHIP_ACH_1")
            Hyperspace.CustomAchievementTracker.instance:SetAchievement("FISHING_SHIP_ACH_1", false)
        end
    end
end

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, ach_check_loop)
script.on_game_event("STORAGE_CHECK_FISHING", false, ach_check_loop)
script.on_game_event("FISHING_CHECK_ACH", false, ach_check_loop)

local achLayoutUnlocks = {
    {
        achPrefix = "FISHING_SHIP_ACH",
        unlockShip = "PLAYER_SHIP_FISHING_2"
    }
}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local unlockTracker = Hyperspace.CustomShipUnlocks.instance
    for _, unlockData in ipairs(achLayoutUnlocks) do
        if not unlockTracker:GetCustomShipUnlocked(unlockData.unlockShip) and count_ship_achievements(unlockData.achPrefix) >= 2 then
            unlockTracker:UnlockShip(unlockData.unlockShip, false)
        end
    end
end)