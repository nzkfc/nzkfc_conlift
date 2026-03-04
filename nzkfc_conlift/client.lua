local liftObject      = nil
local currentLevelIdx = 1
local isMoving        = false
local isRiding        = false
local oxTargetAdded   = false
local callButtons     = {}

-- ─────────────────────────────────────────────────────────────
-- Utility
-- ─────────────────────────────────────────────────────────────

local function Notify(msg)
    lib.notify({ title = 'Lift Menu', description = msg, type = 'inform' })
end

local function QuatToHeading(qx, qy, qz, qw)
    local siny_cosp = 2.0 * (qw * qz + qx * qy)
    local cosy_cosp = 1.0 - 2.0 * (qy * qy + qz * qz)
    return math.deg(math.atan(siny_cosp, cosy_cosp))
end

local HEADING = (QuatToHeading(
    Config.LiftRotation.x,
    Config.LiftRotation.y,
    Config.LiftRotation.z,
    Config.LiftRotation.w
) + -40.0) % 360.0 -- because a vec4 from codewalker won't match in-game sigh

-- ─────────────────────────────────────────────────────────────
-- Native Audio
-- ─────────────────────────────────────────────────────────────

local moveSoundId = -1

local function StartMoveSound()
    if moveSoundId ~= -1 then
        StopSound(moveSoundId)
        ReleaseSoundId(moveSoundId)
        moveSoundId = -1
    end
    RequestScriptAudioBank("GTAO_Script_Doors_Sounds", false)
    moveSoundId = GetSoundId()
    PlaySoundFromEntity(moveSoundId, "Garage_Door_Open_Loop", liftObject, "GTAO_Script_Doors_Sounds", false, 0)
end

local function StopMoveSound()
    if moveSoundId ~= -1 then
        StopSound(moveSoundId)
        ReleaseSoundId(moveSoundId)
        moveSoundId = -1
    end
    ReleaseScriptAudioBank("GTAO_Script_Doors_Sounds")
end

local function PlayOneshotFromEntity(soundName, audioRef, entity)
    RequestScriptAudioBank(audioRef, false)
    local id = GetSoundId()
    PlaySoundFromEntity(id, soundName, entity, audioRef, false, 0)
    CreateThread(function()
        Wait(3000)
        StopSound(id)
        ReleaseSoundId(id)
        ReleaseScriptAudioBank(audioRef)
    end)
end

-- ─────────────────────────────────────────────────────────────
-- Structure collision
-- ─────────────────────────────────────────────────────────────

local STRUCTURE_MODELS = {
    `prop_conslift_rail`,
    `prop_conslift_rail2`,
    `prop_conslift_cage`,
    `prop_conslift_base`,
}

local function DisableStructureCollision()
    local found = 0
    for _, level in ipairs(Config.Levels) do
        for _, model in ipairs(STRUCTURE_MODELS) do
            local handle = GetClosestObjectOfType(
                level.coords.x, level.coords.y, level.coords.z,
                10.0, model, false, false, false
            )
            if handle ~= 0 and DoesEntityExist(handle) then
                SetEntityCollision(handle, false, false)
                found = found + 1
            end
        end
    end
end

-- This removes the static prop lift at the top, avoids squashed players
local function RemoveStaticLiftProp()
    local model = `prop_conslift_lift`
    for _, level in ipairs(Config.Levels) do
        local handle = GetClosestObjectOfType(
            level.coords.x, level.coords.y, level.coords.z,
            2.0, model, false, false, false
        )
        if handle ~= 0 and DoesEntityExist(handle) and handle ~= liftObject then
            SetEntityAsMissionEntity(handle, true, true)
            DeleteObject(handle)
        end
    end
end

-- ─────────────────────────────────────────────────────────────
-- Levelssssssss 
-- ─────────────────────────────────────────────────────────────

local function GetAvailableLevels()
    local out = {}
    for i = #Config.Levels, 1, -1 do
        local level = Config.Levels[i]
        if level.enabled and i ~= currentLevelIdx then
            out[#out + 1] = { index = i, name = level.name }
        end
    end
    return out
end

-- ─────────────────────────────────────────────────────────────
-- Lift movement
-- ─────────────────────────────────────────────────────────────

local function MoveLiftTo(levelIdx, playerIsRiding)
    if isMoving then return end
    isMoving = true
    isRiding = playerIsRiding

    local ped = PlayerPedId()

    if isRiding then
        SetEntityHasGravity(ped, false)
    end

    CreateThread(function()
        local target   = Config.Levels[levelIdx].coords
        local speed    = Config.LiftSpeed
        local lastTime = GetGameTimer()

        StartMoveSound()

        while true do
            local now = GetGameTimer()
            local dt  = math.min((now - lastTime) / 1000.0, 0.05)
            lastTime  = now

            local pos = GetEntityCoords(liftObject, false)
            local dz  = target.z - pos.z

            if math.abs(dz) < 0.02 then
                FreezeEntityPosition(liftObject, true)
                SetEntityCoords(liftObject, target.x, target.y, target.z, false, false, false, false)
                SetEntityHeading(liftObject, HEADING)

                currentLevelIdx = levelIdx
                isMoving        = false

                StopMoveSound()
                PlayOneshotFromEntity("Enter_1st", "GTAO_FM_Events_Soundset", liftObject)

                if isRiding then
                    SetEntityHasGravity(ped, true)
                    isRiding = false
                end

                Notify("Arrived at " .. Config.Levels[levelIdx].name)
                break
            end

            local step = math.min(speed * dt, math.abs(dz))
            local newZ = pos.z + (dz > 0 and step or -step)

            FreezeEntityPosition(liftObject, true)
            SetEntityCoords(liftObject, target.x, target.y, newZ, false, false, false, false)
            SetEntityHeading(liftObject, HEADING)

            if isRiding then
                SetEntityCoords(ped, target.x, target.y, newZ + 1.0, false, false, false, false)
            end

            Wait(0)
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- Floor select menu
-- ─────────────────────────────────────────────────────────────

local function OpenFloorSelectMenu()
    if isMoving then Notify("Lift is already moving!") return end

    local ped       = PlayerPedId()
    local dist      = #(GetEntityCoords(ped, true) - GetEntityCoords(liftObject, false))
    local riding    = (dist < 2.5)
    local available = GetAvailableLevels()

    if #available == 0 then Notify("No other levels available.") return end

    local options = {}
    for _, item in ipairs(available) do
        local idx, name = item.index, item.name
        options[#options + 1] = {
            title    = name,
            icon     = idx > currentLevelIdx and 'arrow-up' or 'arrow-down',
            onSelect = function()
                Notify("Going to " .. name .. "…")
                MoveLiftTo(idx, riding)
            end,
        }
    end

    lib.registerContext({ id = 'nzkfc_conlift_menu', title = '🏗️ Construction Lift', options = options })
    lib.showContext('nzkfc_conlift_menu')
end

-- ─────────────────────────────────────────────────────────────
-- Call buttons
-- ─────────────────────────────────────────────────────────────

local BUTTON_MODEL  = `prop_gatecom_01`

local function SpawnCallButtons()
    RequestModel(BUTTON_MODEL)
    local timeout = 0
    while not HasModelLoaded(BUTTON_MODEL) do
        Wait(100)
        timeout = timeout + 1
        if timeout > 50 then DebugPrint("Button model failed to load!") return end
    end

    for _, btn in ipairs(Config.CallButtons) do
        local obj = CreateObjectNoOffset(
            BUTTON_MODEL,
            btn.pos.x, btn.pos.y, btn.pos.z,
            false, false, false
        )
        SetEntityHeading(obj, btn.pos.w)
        SetEntityAsMissionEntity(obj, true, true)
        FreezeEntityPosition(obj, true)
        SetEntityCollision(obj, true, true)

        callButtons[#callButtons + 1] = { entity = obj, levelIdx = btn.levelIdx }
    end

    SetModelAsNoLongerNeeded(BUTTON_MODEL)
end

local function RegisterButtonTargets()
    if not exports.ox_target then return end

    local entities = {}
    for _, btn in ipairs(callButtons) do
        entities[#entities + 1] = btn.entity
    end

    for _, btn in ipairs(callButtons) do
        exports.ox_target:addLocalEntity(btn.entity, {
            {
                name        = 'call_lift_btn_' .. btn.levelIdx,
                label       = 'Call Lift',
                icon        = 'fas fa-bell',
                distance    = 3.0,
                canInteract = function()
                    return currentLevelIdx ~= btn.levelIdx and not isMoving
                end,
                onSelect = function()
                    if isMoving then Notify("Lift is already moving!") return end
                    if currentLevelIdx == btn.levelIdx then Notify("Lift is already here.") return end
                    PlayOneshotFromEntity("DOOR_BUZZ", "MP_PLAYER_APARTMENT", btn.entity)
                    Notify("Calling lift to " .. Config.Levels[btn.levelIdx].name .. "…")
                    MoveLiftTo(btn.levelIdx, false)
                end,
            }
        })
    end
end

-- ─────────────────────────────────────────────────────────────
-- ox_target (lift cab)
-- ─────────────────────────────────────────────────────────────

local function RegisterOxTarget()
    if not exports.ox_target then
        DebugPrint("ox_target not installed!")
        return
    end

    exports.ox_target:addLocalEntity(liftObject, {
        {
            name     = 'nzkfc_conlift_open',
            label    = 'Lift Menu',
            icon     = 'fas fa-hard-hat',
            distance = Config.InteractionDistance,
            onSelect = function() OpenFloorSelectMenu() end,
        }
    })
    oxTargetAdded = true
end

-- ─────────────────────────────────────────────────────────────
-- Spawn
-- ─────────────────────────────────────────────────────────────

local function SpawnLift()
    local model = `prop_conslift_lift`

    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) do
        Wait(100)
        timeout = timeout + 1
        if timeout > 50 then DebugPrint("Life model failed to load!") return end
    end

    local bottom = Config.Levels[1].coords

    liftObject = CreateObjectNoOffset(model, bottom.x, bottom.y, bottom.z, false, false, false)

    SetEntityAsMissionEntity(liftObject, true, true)
    SetEntityHeading(liftObject, HEADING)
    SetEntityCollision(liftObject, true, true)
    SetEntityVisible(liftObject, true, false)
    SetEntityAlpha(liftObject, 255, false)
    FreezeEntityPosition(liftObject, true)
    SetModelAsNoLongerNeeded(model)

    currentLevelIdx = 1

    Wait(1000)
    DisableStructureCollision()
    RemoveStaticLiftProp()
    RegisterOxTarget()
    SpawnCallButtons()
    RegisterButtonTargets()
end

-- ─────────────────────────────────────────────────────────────
-- Main thread
-- ─────────────────────────────────────────────────────────────

CreateThread(function()
    Wait(2000)
    SpawnLift()
end)

-- ─────────────────────────────────────────────────────────────
-- Cleanup
-- ─────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    StopMoveSound()
    if exports.ox_target then
        if oxTargetAdded then
            exports.ox_target:removeLocalEntity(liftObject, 'nzkfc_conlift_open')
        end
        for _, btn in ipairs(callButtons) do
            exports.ox_target:removeLocalEntity(btn.entity, 'call_lift_btn_' .. btn.levelIdx)
        end
    end
    for _, btn in ipairs(callButtons) do
        if DoesEntityExist(btn.entity) then DeleteObject(btn.entity) end
    end
    if liftObject and DoesEntityExist(liftObject) then
        DeleteObject(liftObject)
    end
end)
