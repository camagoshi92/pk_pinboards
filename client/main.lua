local Core = exports.vorp_core:GetCore()
local spawned = {}
local currentBoard = nil
local nuiOpen = false

local function notify(message)
    if Core and Core.NotifyRightTip then
        Core.NotifyRightTip(message, 4000)
    else
        TriggerEvent('vorp:TipRight', message, 4000)
    end
end

local function boardSetting(board, key)
    if board[key] ~= nil then return board[key] end
    return Config.Defaults[key]
end

local function boardLocations(board)
    if not board.coords then return {} end
    if board.coords.x then return { board.coords } end
    return board.coords
end

local function locationKey(boardIndex, locationIndex)
    return ('%s:%s'):format(boardIndex, locationIndex)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(25) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function spawnBoard(index, locationIndex, board, coords)
    local key = locationKey(index, locationIndex)
    if spawned[key] or boardSetting(board, 'spawnObject') == false then return end
    local hash = loadModel(boardSetting(board, 'model'))
    if not hash then return end
    -- CreateObject applies the model radius to Z. Pinboards placed against a wall
    -- need the configured coordinates to be used without any automatic offset.
    local object = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    if object and object ~= 0 then
        SetEntityHeading(object, coords.w or 0.0)
        if boardSetting(board, 'placeOnGround') == true then
            PlaceObjectOnGroundProperly(object)
        end
        FreezeEntityPosition(object, true)
        SetEntityAsMissionEntity(object, true, true)
        spawned[key] = object
    end
    SetModelAsNoLongerNeeded(hash)
end

local function removeBoard(index, locationIndex)
    local key = locationKey(index, locationIndex)
    local object = spawned[key]
    if object and DoesEntityExist(object) then DeleteObject(object) end
    spawned[key] = nil
end

local function drawText3D(coords, text)
    local visible, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if not visible then return end
    SetTextScale(0.30, 0.30)
    SetTextColor(240, 225, 190, 230)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 180)
    local str = CreateVarString(10, 'LITERAL_STRING', text)
    DisplayText(str, x, y)
end

local function closeBoard()
    nuiOpen = false
    currentBoard = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('pk_pinboards:client:open', function(payload)
    if not payload or not currentBoard then return end
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        board = payload.board,
        posts = payload.posts or {},
        canModerate = payload.canModerate == true,
        canPost = payload.canPost ~= false,
        isNight = GetClockHours() < 6 or GetClockHours() >= 20,
        limits = payload.limits,
        ui = T('ui'),
    })
end)

RegisterNetEvent('pk_pinboards:client:update', function(payload)
    if nuiOpen and payload then
        SendNUIMessage({ action = 'update', posts = payload.posts or {}, canPost = payload.canPost ~= false, limits = payload.limits })
    end
end)

RegisterNetEvent('pk_pinboards:client:error', function(message)
    notify(message or T('failed'))
    if nuiOpen then SendNUIMessage({ action = 'busy', value = false }) end
end)

RegisterNetEvent('pk_pinboards:client:notice', function(message)
    notify(message)
end)

RegisterNUICallback('close', function(_, cb)
    closeBoard()
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    if currentBoard then TriggerServerEvent('pk_pinboards:server:open', currentBoard) end
    cb({ ok = true })
end)

RegisterNUICallback('create', function(data, cb)
    if currentBoard then
        TriggerServerEvent('pk_pinboards:server:create', currentBoard, {
            title = data.title,
            body = data.body,
            imageUrl = data.imageUrl,
            textSize = data.textSize,
        })
    end
    cb({ ok = true })
end)

RegisterNUICallback('delete', function(data, cb)
    if currentBoard then TriggerServerEvent('pk_pinboards:server:delete', currentBoard, tonumber(data.id)) end
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        for index, board in ipairs(Config.Boards) do
            for locationIndex, coords in ipairs(boardLocations(board)) do
                local c = vector3(coords.x, coords.y, coords.z)
                local distance = #(pos - c)
                if distance <= Config.RenderDistance then
                    spawnBoard(index, locationIndex, board, coords)
                else
                    removeBoard(index, locationIndex)
                end
            end
        end
        Wait(2000)
    end
end)

CreateThread(function()
    while true do
        local wait = 1000
        if not nuiOpen then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local closeToBoard = false
            for index, board in ipairs(Config.Boards) do
                for _, coords in ipairs(boardLocations(board)) do
                    local c = vector3(coords.x, coords.y, coords.z)
                    local distance = #(pos - c)
                    local showText = board.show3DText
                    if showText == nil then showText = Config.Show3DText end
                    if showText and distance <= Config.TextDistance then
                        wait = 0
                        drawText3D(c + vector3(0.0, 0.0, 1.35), T('interact'))
                    end
                    if distance <= Config.InteractDistance then
                        wait = 0
                        if IsControlJustReleased(0, Config.OpenControl) then
                            currentBoard = board.id
                            TriggerServerEvent('pk_pinboards:server:open', board.id)
                        end
                        closeToBoard = true
                        break
                    end
                end
                if closeToBoard then break end
            end
        else
            wait = 0
            DisableAllControlActions(0)
            EnableControlAction(0, 0x156F7119, true) -- ESC
        end
        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        if nuiOpen then
            SendNUIMessage({ action = 'time', isNight = GetClockHours() < 6 or GetClockHours() >= 20 })
        end
        Wait(30000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeBoard()
    for key, object in pairs(spawned) do
        if object and DoesEntityExist(object) then DeleteObject(object) end
        spawned[key] = nil
    end
end)
