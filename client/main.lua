local disabledControls = {
    21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 37, 44, 45, 58, 75,
    140, 141, 142, 143, 257, 263, 264
}

local function drawInteractionMarker(location)
    local marker = Config.Interaction.marker
    if not marker.enabled then
        return
    end

    DrawMarker(
        marker.type,
        location.x,
        location.y,
        location.z - 0.92,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        marker.scale.x,
        marker.scale.y,
        marker.scale.z,
        marker.color.r,
        marker.color.g,
        marker.color.b,
        marker.color.a,
        false,
        false,
        2,
        false,
        nil,
        nil,
        false
    )
end

local function showInteractionPrompt()
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(Config.Interaction.prompt)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

CreateThread(function()
    while true do
        local waitTime = 1000

        if not BaseballState.active then
            local location = Config.Locations[Config.DefaultLocation]
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - location.interaction)

            if distance <= Config.Interaction.drawDistance then
                waitTime = 0
                drawInteractionMarker(location.interaction)

                if distance <= Config.Interaction.radius then
                    showInteractionPrompt()

                    if IsControlJustReleased(0, Config.Controls.enter) then
                        StartBattingPractice(Config.DefaultLocation)
                    end
                end
            end
        end

        Wait(waitTime)
    end
end)

CreateThread(function()
    while true do
        if BaseballState.active then
            Wait(0)

            local playerPed = PlayerPedId()
            for index = 1, #disabledControls do
                DisableControlAction(0, disabledControls[index], true)
            end

            DisablePlayerFiring(PlayerId(), true)

            if Config.Hud.hideRadar then
                DisplayRadar(false)
            end

            for index = 1, #Config.Hud.hiddenComponents do
                HideHudComponentThisFrame(Config.Hud.hiddenComponents[index])
            end

            if IsDisabledControlJustReleased(0, Config.Controls.requestPitch) then
                TriggerEvent('slothy-baseball:client:requestPitch')
            end

            if IsDisabledControlJustReleased(0, Config.Controls.swing) then
                TriggerEvent('slothy-baseball:client:swingInput')
            end

            if IsEntityDead(playerPed) then
                StopBattingPractice(false)
            elseif IsControlJustReleased(0, Config.Controls.exit)
                or IsDisabledControlJustReleased(0, Config.Controls.exit) then
                StopBattingPractice()
            end
        else
            Wait(500)
        end
    end
end)

RegisterCommand(Config.Commands.toggle, function()
    if BaseballState.active then
        StopBattingPractice()
    else
        StartBattingPractice(Config.DefaultLocation)
    end
end, false)

RegisterCommand(Config.Commands.debug, function()
    BaseballState.debugEnabled = not BaseballState.debugEnabled
    SendNUIMessage({
        action = 'setDebug',
        visible = BaseballState.debugEnabled
    })
    SlothyBaseball.Debug(
        ('Debug overlay %s.'):format(BaseballState.debugEnabled and 'enabled' or 'disabled')
    )
end, false)

RegisterCommand('+baseballExit', function()
    if BaseballState.active then
        StopBattingPractice()
    end
end, false)

RegisterCommand('-baseballExit', function() end, false)
RegisterKeyMapping('+baseballExit', 'Exit baseball batting practice', 'keyboard', 'BACK')

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if BaseballState.active or BaseballState.phase ~= 'idle' then
        StopBattingPractice(true, true)
    else
        SetNuiFocus(false, false)
        BaseballCamera.Stop(true)
    end
end)

