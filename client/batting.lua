BaseballState = {
    active = false,
    phase = 'idle',
    sessionId = nil,
    locationId = nil,
    pitcherPed = nil,
    pciX = 0.0,
    pciY = 0.0,
    currentPitch = nil,
    pitchProgress = 0.0,
    pitchX = 0.0,
    pitchY = 0.0,
    pitchToken = 0,
    pitchRequested = false,
    hasSwung = false,
    contactMade = false,
    debugEnabled = Config.Debug,
    ballCameraEnabled = Config.HitCamera.enabledByDefault,
    ballFlightActive = false,
    ballFlightToken = 0,
    battedBall = nil,
    batProp = nil,
    returnPosition = nil
}

local pitchingAnimationLoaded = false
local batterAnimationLoaded = false

local function pitchRandomFloat(minimum, maximum)
    return minimum + ((maximum - minimum) * math.random())
end

local function isPitchControllerActive(token)
    return BaseballState.active
        and BaseballState.pitchToken == token
        and BaseballState.pitcherPed
        and DoesEntityExist(BaseballState.pitcherPed)
end

local function waitForPitchController(milliseconds, token)
    local endsAt = GetGameTimer() + milliseconds

    while GetGameTimer() < endsAt do
        if not isPitchControllerActive(token) then
            return false
        end

        Wait(0)
    end

    return true
end

local function loadPitchAnimation()
    if pitchingAnimationLoaded then
        return true
    end

    RequestAnimDict(Config.Pitching.animationDictionary)
    local timeoutAt = GetGameTimer() + 3000

    while not HasAnimDictLoaded(Config.Pitching.animationDictionary)
        and GetGameTimer() < timeoutAt do
        Wait(0)
    end

    pitchingAnimationLoaded = HasAnimDictLoaded(Config.Pitching.animationDictionary)
    if not pitchingAnimationLoaded then
        SlothyBaseball.Debug('Pitch animation failed to load; simulated pitches will still continue.')
    end

    return pitchingAnimationLoaded
end

local function choosePitchType()
    local totalWeight = 0

    for _, pitch in pairs(Config.Pitches) do
        if pitch.enabled then
            totalWeight = totalWeight + pitch.weight
        end
    end

    if totalWeight <= 0 then
        return nil, nil
    end

    local selection = math.random(1, totalWeight)
    local runningWeight = 0

    for pitchType, pitch in pairs(Config.Pitches) do
        if pitch.enabled then
            runningWeight = runningWeight + pitch.weight

            if selection <= runningWeight then
                return pitchType, pitch
            end
        end
    end

    return nil, nil
end

local function pitchDurationFromSpeed(speed)
    local speedProgress = SlothyBaseball.Clamp((speed - 76.0) / 22.0, 0.0, 1.0)

    return math.floor(
        Config.Pitching.maximumDurationMs
        - ((Config.Pitching.maximumDurationMs - Config.Pitching.minimumDurationMs) * speedProgress)
    )
end

local function generatePitchTarget(strikeChance)
    local location = Config.PitchLocation
    local shouldBeStrike = math.random() <= (strikeChance or 0.68)

    if shouldBeStrike then
        return pitchRandomFloat(-location.strikeMaximumX, location.strikeMaximumX),
            pitchRandomFloat(-location.strikeMaximumY, location.strikeMaximumY)
    end

    local edge = math.random(1, 4)
    local parallel = pitchRandomFloat(
        -location.ballParallelMaximum,
        location.ballParallelMaximum
    )

    if edge == 1 then
        return -pitchRandomFloat(location.ballMinimum, location.ballMaximumX),
            parallel
    end

    if edge == 2 then
        return pitchRandomFloat(location.ballMinimum, location.ballMaximumX),
            parallel
    end

    if edge == 3 then
        return parallel,
            pitchRandomFloat(location.ballMinimum, location.ballMaximumY)
    end

    return parallel,
        -pitchRandomFloat(location.ballMinimum, location.ballMaximumY)
end

local function generatePitch()
    local pitchType, pitchConfig = choosePitchType()
    if not pitchType then
        return nil
    end

    local speed = math.random(pitchConfig.minSpeed, pitchConfig.maxSpeed)
    local horizontalBreak = pitchConfig.breakX * pitchRandomFloat(-1.0, 1.0)
    local targetX, targetY = generatePitchTarget(pitchConfig.strikeChance)

    if pitchType == 'slider' then
        horizontalBreak = pitchConfig.breakX
    end

    return {
        type = pitchType,
        label = pitchConfig.label,
        speedMph = speed,
        durationMs = pitchDurationFromSpeed(speed),
        startX = 0.0,
        startY = 0.35,
        targetX = targetX,
        targetY = targetY,
        breakX = horizontalBreak,
        breakY = pitchConfig.breakY
    }
end

local function playPitchAnimation()
    if not loadPitchAnimation() then
        return
    end

    local pitcher = BaseballState.pitcherPed
    if not pitcher or not DoesEntityExist(pitcher) then
        return
    end

    TaskPlayAnim(
        pitcher,
        Config.Pitching.animationDictionary,
        Config.Pitching.animationName,
        8.0,
        -4.0,
        Config.Pitching.animationDurationMs,
        0,
        0.0,
        false,
        false,
        false
    )
end

local function deleteBatterBat()
    local bat = BaseballState.batProp

    if bat and DoesEntityExist(bat) then
        DetachEntity(bat, true, true)
        SetEntityAsMissionEntity(bat, true, true)
        DeleteEntity(bat)
    end

    BaseballState.batProp = nil
end

local function createBatterBat(playerPed)
    if not Config.Bat.enabled then
        return false
    end

    if BaseballState.batProp and DoesEntityExist(BaseballState.batProp) then
        return true
    end

    deleteBatterBat()

    local modelHash = joaat(Config.Bat.model)
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        SlothyBaseball.Debug(('Bat model "%s" is invalid.'):format(Config.Bat.model))
        return false
    end

    RequestModel(modelHash)
    local timeoutAt = GetGameTimer() + Config.Bat.loadTimeoutMs

    while not HasModelLoaded(modelHash) and GetGameTimer() < timeoutAt do
        if not BaseballState.active then
            SetModelAsNoLongerNeeded(modelHash)
            return false
        end

        Wait(0)
    end

    if not HasModelLoaded(modelHash) then
        SlothyBaseball.Debug(('Timed out loading bat model "%s".'):format(Config.Bat.model))
        return false
    end

    if not DoesEntityExist(playerPed) then
        SetModelAsNoLongerNeeded(modelHash)
        return false
    end

    local playerCoords = GetEntityCoords(playerPed)
    local bat = CreateObjectNoOffset(
        modelHash,
        playerCoords.x,
        playerCoords.y,
        playerCoords.z,
        false,
        false,
        false
    )
    SetModelAsNoLongerNeeded(modelHash)

    if bat == 0 then
        SlothyBaseball.Debug('The batter bat prop could not be created.')
        return false
    end

    local position = Config.Bat.position
    local rotation = Config.Bat.rotation
    SetEntityAsMissionEntity(bat, true, true)
    SetEntityCollision(bat, false, false)
    SetEntityInvincible(bat, true)
    AttachEntityToEntity(
        bat,
        playerPed,
        GetPedBoneIndex(playerPed, Config.Bat.bone),
        position.x,
        position.y,
        position.z,
        rotation.x,
        rotation.y,
        rotation.z,
        true,
        true,
        false,
        true,
        1,
        true
    )

    BaseballState.batProp = bat
    SlothyBaseball.Debug(('Bat attached to batter (handle %s).'):format(bat))
    return true
end

local function playBatterSwingAnimation()
    CreateThread(function()
        local playerPed = PlayerPedId()
        createBatterBat(playerPed)

        if not batterAnimationLoaded then
            RequestAnimDict(Config.Swing.animationDictionary)
            local timeoutAt = GetGameTimer() + 2500

            while not HasAnimDictLoaded(Config.Swing.animationDictionary)
                and GetGameTimer() < timeoutAt do
                Wait(0)
            end

            batterAnimationLoaded = HasAnimDictLoaded(Config.Swing.animationDictionary)
        end

        if not batterAnimationLoaded or not BaseballState.active then
            return
        end

        TaskPlayAnim(
            playerPed,
            Config.Swing.animationDictionary,
            Config.Swing.animationName,
            6.0,
            -4.0,
            Config.Swing.animationDurationMs,
            48,
            0.0,
            false,
            false,
            false
        )
    end)
end

local function getTimingLabel(timingError)
    if timingError < -0.12 then
        return 'Very Early'
    end

    if timingError < -0.05 then
        return 'Early'
    end

    if timingError <= 0.05 then
        return 'Good'
    end

    if timingError <= 0.12 then
        return 'Late'
    end

    return 'Very Late'
end

local function getPlacementLabel(distance)
    if distance <= Config.Swing.perfectRadius then
        return 'Perfect'
    end

    if distance <= Config.Swing.goodRadius then
        return 'Good'
    end

    if distance <= Config.Swing.outerRadius then
        return 'Okay'
    end

    return 'Poor'
end

local function classifyHit(contactScore, launchAngle, distance)
    if launchAngle < 5.0 then
        return 'GROUND BALL'
    end

    if distance >= 390.0 and launchAngle >= 18.0 and launchAngle <= 42.0 then
        return 'HOME RUN'
    end

    if contactScore >= 0.78 then
        return 'HARD-HIT BALL'
    end

    if launchAngle >= 28.0 then
        return 'FLY BALL'
    end

    if contactScore >= 0.48 then
        return 'BASE HIT'
    end

    return 'WEAK CONTACT'
end

local function showSwingResult(result)
    SendNUIMessage({
        action = 'showResult',
        headline = result.headline,
        result = result.result,
        timing = result.timing,
        placement = result.placement,
        contactScore = result.contactScore,
        exitVelocity = result.exitVelocity,
        launchAngle = result.launchAngle,
        distance = result.distance
    })
end

local function drawBallTrail(points)
    local color = Config.BallFlight.trailColor

    for index = 2, #points do
        local previous = points[index - 1]
        local current = points[index]

        DrawLine(
            previous.x,
            previous.y,
            previous.z,
            current.x,
            current.y,
            current.z,
            color.r,
            color.g,
            color.b,
            color.a
        )
    end
end

local function deleteBattedBall()
    local ball = BaseballState.battedBall

    if ball and DoesEntityExist(ball) then
        SetEntityAsMissionEntity(ball, true, true)
        DeleteEntity(ball)
    end

    BaseballState.battedBall = nil
end

local function stopBallFlight(returnToBatting)
    BaseballState.ballFlightToken = BaseballState.ballFlightToken + 1
    BaseballState.ballFlightActive = false
    deleteBattedBall()

    if returnToBatting then
        BaseballCamera.ReturnToBatting()
    end
end

local function getBallFlightDirection(sprayAngle)
    local location = Config.Locations[BaseballState.locationId]
    local batter = location.batter.coords
    local pitcher = location.pitcher.coords
    local baseX = pitcher.x - batter.x
    local baseY = pitcher.y - batter.y
    local magnitude = math.sqrt((baseX * baseX) + (baseY * baseY))

    if magnitude <= 0.001 then
        return 1.0, 0.0
    end

    baseX = baseX / magnitude
    baseY = baseY / magnitude

    local radians = math.rad(sprayAngle)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)

    return (baseX * cosine) - (baseY * sine),
        (baseX * sine) + (baseY * cosine)
end

local function startBallFlight(result, timingError)
    stopBallFlight(false)

    BaseballState.ballFlightToken = BaseballState.ballFlightToken + 1
    local token = BaseballState.ballFlightToken
    BaseballState.ballFlightActive = true
    local launchAt = GetGameTimer() + Config.Swing.contactDelayMs

    CreateThread(function()
        local modelHash = joaat(Config.BallFlight.model)
        RequestModel(modelHash)
        local modelTimeoutAt = GetGameTimer() + 3000

        while not HasModelLoaded(modelHash) and GetGameTimer() < modelTimeoutAt do
            if not BaseballState.active or BaseballState.ballFlightToken ~= token then
                BaseballState.ballFlightActive = false
                return
            end

            Wait(0)
        end

        if not HasModelLoaded(modelHash) then
            BaseballState.ballFlightActive = false
            SlothyBaseball.Debug(('Batted-ball model "%s" failed to load.'):format(Config.BallFlight.model))
            return
        end

        while GetGameTimer() < launchAt do
            if not BaseballState.active or BaseballState.ballFlightToken ~= token then
                SetModelAsNoLongerNeeded(modelHash)
                BaseballState.ballFlightActive = false
                return
            end

            Wait(0)
        end

        local location = Config.Locations[BaseballState.locationId]
        local batter = location.batter.coords
        local origin = vector3(
            batter.x,
            batter.y,
            batter.z + Config.BallFlight.originHeight
        )
        local ball = CreateObjectNoOffset(
            modelHash,
            origin.x,
            origin.y,
            origin.z,
            false,
            false,
            false
        )
        SetModelAsNoLongerNeeded(modelHash)

        if ball == 0 then
            BaseballState.ballFlightActive = false
            SlothyBaseball.Debug('The visual batted baseball could not be created.')
            return
        end

        BaseballState.battedBall = ball
        SetEntityAsMissionEntity(ball, true, true)
        SetEntityCollision(ball, false, false)
        SetEntityHasGravity(ball, false)

        local sprayAngle = SlothyBaseball.Clamp(-timingError * 180.0, -42.0, 42.0)
        local directionX, directionY = getBallFlightDirection(sprayAngle)
        local distanceFeet = SlothyBaseball.Clamp(
            tonumber(result.distance) or 60.0,
            20.0,
            Config.BallFlight.maximumDistanceFeet
        )
        local distanceMeters = distanceFeet * 0.3048
        local endX = origin.x + (directionX * distanceMeters)
        local endY = origin.y + (directionY * distanceMeters)
        local groundFound, groundZ = GetGroundZFor_3dCoord(
            endX,
            endY,
            origin.z + 100.0,
            false
        )

        if not groundFound then
            groundZ = origin.z - Config.BallFlight.originHeight
        end

        local launchRadians = math.rad(math.max(tonumber(result.launchAngle) or 10.0, 1.0))
        local apexHeight = SlothyBaseball.Clamp(
            (distanceMeters * math.tan(launchRadians)) * 0.25,
            1.2,
            Config.BallFlight.maximumApexMeters
        )

        if (tonumber(result.launchAngle) or 0.0) < 5.0 then
            apexHeight = 0.8
        end

        local durationMs = math.floor(SlothyBaseball.Clamp(
            1200.0 + (distanceFeet * 8.5),
            Config.BallFlight.minimumDurationMs,
            Config.BallFlight.maximumDurationMs
        ))
        local trail = {}
        local flightStartedAt = GetGameTimer()

        if BaseballState.ballCameraEnabled then
            BaseballCamera.TrackEntity(Config.HitCamera, ball)
        end

        SlothyBaseball.Debug(
            ('BALL FLIGHT distance=%dft launch=%.1f spray=%+.1f duration=%dms ballCam=%s')
                :format(
                    math.floor(distanceFeet + 0.5),
                    result.launchAngle or 0.0,
                    sprayAngle,
                    durationMs,
                    tostring(BaseballState.ballCameraEnabled)
                )
        )

        while BaseballState.active
            and BaseballState.ballFlightToken == token
            and BaseballState.ballFlightActive do
            local progress = SlothyBaseball.Clamp(
                (GetGameTimer() - flightStartedAt) / durationMs,
                0.0,
                1.0
            )
            local currentX = origin.x + ((endX - origin.x) * progress)
            local currentY = origin.y + ((endY - origin.y) * progress)
            local baseZ = origin.z + ((groundZ - origin.z) * progress)
            local currentZ = baseZ + (4.0 * apexHeight * progress * (1.0 - progress))

            SetEntityCoordsNoOffset(ball, currentX, currentY, currentZ, false, false, false)
            SetEntityRotation(ball, progress * 1440.0, progress * 900.0, 0.0, 2, true)

            trail[#trail + 1] = vector3(currentX, currentY, currentZ)
            if #trail > Config.BallFlight.trailSegments then
                table.remove(trail, 1)
            end
            drawBallTrail(trail)

            if progress >= 1.0 then
                break
            end

            Wait(0)
        end

        local holdUntil = GetGameTimer() + Config.HitCamera.returnDelayMs
        while BaseballState.active
            and BaseballState.ballFlightToken == token
            and GetGameTimer() < holdUntil do
            drawBallTrail(trail)
            Wait(0)
        end

        if BaseballState.battedBall == ball then
            deleteBattedBall()
        elseif DoesEntityExist(ball) then
            DeleteEntity(ball)
        end

        if BaseballState.ballFlightToken == token then
            local cameraIsReturning = false

            if BaseballState.active then
                cameraIsReturning = BaseballCamera.ReturnToBatting()
            end

            if cameraIsReturning then
                Wait(Config.HitCamera.transitionMs)
            end

            if BaseballState.ballFlightToken == token then
                BaseballState.ballFlightActive = false
            end
        end
    end)
end

local function toggleBallCamera()
    BaseballState.ballCameraEnabled = not BaseballState.ballCameraEnabled
    SendNUIMessage({
        action = 'setBallCamera',
        enabled = BaseballState.ballCameraEnabled
    })

    if BaseballState.ballFlightActive and BaseballState.battedBall
        and DoesEntityExist(BaseballState.battedBall) then
        if BaseballState.ballCameraEnabled then
            BaseballCamera.TrackEntity(Config.HitCamera, BaseballState.battedBall)
        else
            BaseballCamera.ReturnToBatting()
        end
    end

    SlothyBaseball.Debug(
        ('Ball camera %s.'):format(BaseballState.ballCameraEnabled and 'enabled' or 'disabled')
    )
    return BaseballState.ballCameraEnabled
end

local function resolveSwing(pciX, pciY)
    if not BaseballState.active or BaseballState.phase ~= 'pitching' then
        SlothyBaseball.Debug(('Swing ignored during phase "%s".'):format(BaseballState.phase))
        return false
    end

    if BaseballState.hasSwung or not BaseballState.currentPitch then
        SlothyBaseball.Debug('Swing ignored because this pitch already has a swing.')
        return false
    end

    BaseballState.pciX = SlothyBaseball.Clamp(
        tonumber(pciX) or BaseballState.pciX,
        -Config.PCI.maximumX,
        Config.PCI.maximumX
    )
    BaseballState.pciY = SlothyBaseball.Clamp(
        tonumber(pciY) or BaseballState.pciY,
        -Config.PCI.maximumY,
        Config.PCI.maximumY
    )
    BaseballState.hasSwung = true

    local dx = BaseballState.pitchX - BaseballState.pciX
    local dy = BaseballState.pitchY - BaseballState.pciY
    local distance = math.sqrt((dx * dx) + (dy * dy))
    local timingError = BaseballState.pitchProgress - Config.Swing.idealProgress
    local placementScore = 1.0 - SlothyBaseball.Clamp(
        distance / Config.Swing.outerRadius,
        0.0,
        1.0
    )
    local timingScore = 1.0 - SlothyBaseball.Clamp(
        math.abs(timingError) / Config.Swing.maximumTimingWindow,
        0.0,
        1.0
    )
    local contactScore = (placementScore * Config.Swing.placementWeight)
        + (timingScore * Config.Swing.timingWeight)
    local timingLabel = getTimingLabel(timingError)
    local placementLabel = getPlacementLabel(distance)
    local madeContact = distance <= Config.Swing.outerRadius
        and math.abs(timingError) <= Config.Swing.maximumTimingWindow

    playBatterSwingAnimation()

    local result = {
        headline = madeContact and 'CONTACT' or 'SWING AND MISS',
        result = madeContact and 'BALL IN PLAY' or 'STRIKE',
        timing = timingLabel,
        placement = placementLabel,
        contactScore = contactScore
    }

    if madeContact then
        local randomExit = pitchRandomFloat(
            -Config.HitPhysics.randomExitVelocity,
            Config.HitPhysics.randomExitVelocity
        )
        local exitVelocity = Config.HitPhysics.minimumExitVelocity
            + ((Config.HitPhysics.maximumExitVelocity - Config.HitPhysics.minimumExitVelocity) * contactScore)
            + randomExit
        exitVelocity = SlothyBaseball.Clamp(
            exitVelocity,
            Config.HitPhysics.minimumExitVelocity,
            Config.HitPhysics.maximumExitVelocity
        )

        local verticalOffset = BaseballState.pitchY - BaseballState.pciY
        local launchAngle = SlothyBaseball.Clamp(
            12.0 + (verticalOffset * 48.0),
            Config.HitPhysics.minimumLaunchAngle,
            Config.HitPhysics.maximumLaunchAngle
        )
        local usefulAngle = SlothyBaseball.Clamp(launchAngle, 0.0, 45.0)
        local angleEfficiency = math.max(math.sin(math.rad(usefulAngle * 2.0)), 0.08)
        local distanceFeet = exitVelocity
            * Config.HitPhysics.distanceVelocityMultiplier
            * angleEfficiency
            * (0.55 + (contactScore * 0.45))

        if launchAngle < 5.0 then
            distanceFeet = distanceFeet * 0.35
        elseif launchAngle > 48.0 then
            distanceFeet = distanceFeet * 0.62
        end

        result.exitVelocity = exitVelocity
        result.launchAngle = launchAngle
        result.distance = math.floor(distanceFeet + 0.5)
        result.result = classifyHit(contactScore, launchAngle, result.distance)
        result.headline = contactScore >= 0.88 and 'PERFECT CONTACT' or 'CONTACT'

        BaseballState.contactMade = true
        BaseballState.phase = 'contact'
    end

    SendNUIMessage({
        action = 'swingFeedback',
        contact = madeContact,
        soundDelayMs = madeContact and Config.Swing.contactDelayMs or 0
    })
    showSwingResult(result)

    if madeContact then
        startBallFlight(result, timingError)
    end

    SlothyBaseball.Debug(
        ('SWING progress=%.3f timingError=%+.3f timing=%s '
            .. 'ball=(%.3f,%.3f) pci=(%.3f,%.3f) distance=%.3f '
            .. 'placementScore=%.3f timingScore=%.3f contactScore=%.3f contact=%s result=%s')
            :format(
                BaseballState.pitchProgress,
                timingError,
                timingLabel,
                BaseballState.pitchX,
                BaseballState.pitchY,
                BaseballState.pciX,
                BaseballState.pciY,
                distance,
                placementScore,
                timingScore,
                contactScore,
                tostring(madeContact),
                result.result
            )
    )

    TriggerEvent('slothy-baseball:client:swing', {
        pitch = BaseballState.currentPitch,
        progress = BaseballState.pitchProgress,
        timingError = timingError,
        distance = distance,
        contactScore = contactScore,
        madeContact = madeContact
    })
    TriggerEvent('slothy-baseball:client:hitResult', result)
    return true
end

local function throwRequestedPitch(pitch, token)
    BaseballState.phase = 'windup'
    BaseballState.currentPitch = pitch
    BaseballState.pitchProgress = 0.0
    BaseballState.pitchX = pitch.startX
    BaseballState.pitchY = pitch.startY
    BaseballState.hasSwung = false
    BaseballState.contactMade = false
    SendNUIMessage({ action = 'hideResult' })

    if Config.PCI.resetEveryPitch then
        BaseballState.pciX = 0.0
        BaseballState.pciY = 0.0
        SendNUIMessage({
            action = 'setPCI',
            x = 0.0,
            y = 0.0,
            radius = Config.PCI.defaultRadius
        })
    end

    SendNUIMessage({
        action = 'pitchStatus',
        label = ('%s - %d MPH'):format(pitch.label, pitch.speedMph)
    })
    SlothyBaseball.Debug(
        ('PITCH type=%s speed=%d duration=%d target=(%.3f,%.3f) break=(%.3f,%.3f)')
            :format(
                pitch.type,
                pitch.speedMph,
                pitch.durationMs,
                pitch.targetX,
                pitch.targetY,
                pitch.breakX,
                pitch.breakY
            )
    )

    playPitchAnimation()
    if not waitForPitchController(Config.Pitching.releaseDelayMs, token) then
        return false
    end

    BaseballState.phase = 'pitching'
    local pitchStartedAt = GetGameTimer()

    SendNUIMessage({
        action = 'startPitch',
        pitchType = pitch.type,
        label = pitch.label,
        speedMph = pitch.speedMph,
        x = pitch.startX,
        y = pitch.startY,
        size = Config.Pitching.minimumBallSize
    })

    TriggerEvent('slothy-baseball:client:pitchThrown', pitch)

    local nextDebugUpdateAt = 0

    while isPitchControllerActive(token) do
        local elapsed = GetGameTimer() - pitchStartedAt
        local progress = elapsed / pitch.durationMs
        local travelProgress = SlothyBaseball.Clamp(progress, 0.0, 1.0)
        local breakProgress = travelProgress * travelProgress
        local baseTargetX = pitch.targetX - pitch.breakX
        local baseTargetY = pitch.targetY - pitch.breakY
        local currentX = pitch.startX + ((baseTargetX - pitch.startX) * travelProgress)
            + (pitch.breakX * breakProgress)
        local currentY = pitch.startY + ((baseTargetY - pitch.startY) * travelProgress)
            + (pitch.breakY * breakProgress)
        local size = Config.Pitching.minimumBallSize
            + ((Config.Pitching.maximumBallSize - Config.Pitching.minimumBallSize) * breakProgress)

        if progress > 1.0 then
            local overrunAmount = SlothyBaseball.Clamp(
                (progress - 1.0) / (Config.Pitching.overrunProgress - 1.0),
                0.0,
                1.0
            )
            size = Config.Pitching.maximumBallSize
                + ((Config.Pitching.maximumOverrunBallSize - Config.Pitching.maximumBallSize)
                    * overrunAmount)
        end

        BaseballState.pitchProgress = progress
        BaseballState.pitchX = currentX
        BaseballState.pitchY = currentY
        SendNUIMessage({
            action = 'updatePitch',
            progress = progress,
            x = currentX,
            y = currentY,
            size = size
        })

        if BaseballState.debugEnabled and GetGameTimer() >= nextDebugUpdateAt then
            nextDebugUpdateAt = GetGameTimer() + 75
            local dx = currentX - BaseballState.pciX
            local dy = currentY - BaseballState.pciY

            SendNUIMessage({
                action = 'updateDebug',
                phase = BaseballState.phase,
                pitchType = pitch.type,
                progress = progress,
                ballX = currentX,
                ballY = currentY,
                pciX = BaseballState.pciX,
                pciY = BaseballState.pciY,
                distance = math.sqrt((dx * dx) + (dy * dy)),
                idealProgress = Config.Swing.idealProgress,
                hasSwung = BaseballState.hasSwung
            })
        end

        if BaseballState.contactMade or progress >= Config.Pitching.overrunProgress then
            break
        end

        Wait(0)
    end

    if not isPitchControllerActive(token) then
        return false
    end

    if not BaseballState.hasSwung then
        local isStrike = math.abs(pitch.targetX) <= 1.0
            and math.abs(pitch.targetY) <= 1.0
        showSwingResult({
            headline = 'PITCH TAKEN',
            result = isStrike and 'CALLED STRIKE' or 'BALL',
            timing = 'No Swing',
            placement = 'N/A',
            contactScore = 0.0
        })
        SlothyBaseball.Debug(
            ('TAKEN progress=%.3f target=(%.3f,%.3f) result=%s')
                :format(
                    BaseballState.pitchProgress,
                    pitch.targetX,
                    pitch.targetY,
                    isStrike and 'CALLED STRIKE' or 'BALL'
                )
        )
    end

    SendNUIMessage({ action = 'endPitch' })

    if BaseballState.pitcherPed and DoesEntityExist(BaseballState.pitcherPed) then
        ClearPedTasks(BaseballState.pitcherPed)
    end

    BaseballState.currentPitch = nil
    BaseballState.pitchProgress = 0.0
    BaseballState.pitchX = 0.0
    BaseballState.pitchY = 0.0
    return true
end

local function requestAIPitch()
    if not BaseballState.active
        or BaseballState.phase ~= 'ready'
        or BaseballState.currentPitch
        or BaseballState.pitchRequested then
        return false
    end

    BaseballState.pitchRequested = true
    BaseballState.phase = 'queued'
    SlothyBaseball.Debug('AI pitch requested.')
    SendNUIMessage({
        action = 'pitchStatus',
        label = 'Pitch requested'
    })
    return true
end

local function startPitchingController()
    BaseballState.pitchToken = BaseballState.pitchToken + 1
    local token = BaseballState.pitchToken
    BaseballState.pitchRequested = false

    if not Config.Pitching.enabled then
        return
    end

    SendNUIMessage({ action = 'pitchPrompt' })
    SlothyBaseball.Debug('Pitching controller ready; press Space to request a pitch.')

    CreateThread(function()
        math.randomseed(GetGameTimer() + (PlayerId() * 7919))

        while isPitchControllerActive(token) do
            if not BaseballState.pitchRequested then
                Wait(50)
            else
                BaseballState.pitchRequested = false
                local pitch = generatePitch()

                if not pitch then
                    SlothyBaseball.Debug('No enabled pitch types are configured.')
                    return
                end

                if not throwRequestedPitch(pitch, token) then
                    return
                end

                BaseballState.phase = 'resetting'

                if not waitForPitchController(Config.Pitching.betweenPitchesMs, token) then
                    return
                end

                while isPitchControllerActive(token) and BaseballState.ballFlightActive do
                    Wait(50)
                end

                if not isPitchControllerActive(token) then
                    return
                end

                BaseballState.phase = 'ready'
                SendNUIMessage({ action = 'pitchPrompt' })
            end
        end
    end)
end

local function stopPitchingController()
    BaseballState.pitchToken = BaseballState.pitchToken + 1
    BaseballState.pitchRequested = false

    if BaseballState.pitcherPed and DoesEntityExist(BaseballState.pitcherPed) then
        ClearPedTasksImmediately(BaseballState.pitcherPed)
    end
end

local function notify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function getLocation(locationId)
    local selectedId = locationId or Config.DefaultLocation
    return Config.Locations[selectedId], selectedId
end

local function requestModel(model)
    local modelHash = type(model) == 'number' and model or joaat(model)

    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        SlothyBaseball.Debug(('Pitcher model %s is invalid.'):format(model))
        return nil
    end

    RequestModel(modelHash)
    local timeoutAt = GetGameTimer() + 5000

    while not HasModelLoaded(modelHash) and GetGameTimer() < timeoutAt do
        Wait(0)
    end

    if not HasModelLoaded(modelHash) then
        SlothyBaseball.Debug(('Timed out loading pitcher model %s.'):format(model))
        return nil
    end

    return modelHash
end


local function createPitcher(pitcherConfig)
    if not pitcherConfig.enabled then
        return
    end

    local modelHash = requestModel(pitcherConfig.model)
    if not modelHash then
        return
    end

    local coords = pitcherConfig.coords
    local pitcher = CreatePed(4, modelHash, coords.x, coords.y, coords.z, coords.w, false, false)

    if pitcher == 0 then
        SetModelAsNoLongerNeeded(modelHash)
        SlothyBaseball.Debug('The pitcher ped could not be created.')
        return
    end

    SetEntityAsMissionEntity(pitcher, true, true)
    SetEntityInvincible(pitcher, true)
    SetBlockingOfNonTemporaryEvents(pitcher, true)
    SetPedCanRagdoll(pitcher, false)
    SetPedFleeAttributes(pitcher, 0, false)
    SetPedDropsWeaponsWhenDead(pitcher, false)
    FreezeEntityPosition(pitcher, true)
    SetModelAsNoLongerNeeded(modelHash)

    BaseballState.pitcherPed = pitcher
end

local function deletePitcher()
    local pitcher = BaseballState.pitcherPed

    if pitcher and DoesEntityExist(pitcher) then
        SetEntityAsMissionEntity(pitcher, true, true)
        DeleteEntity(pitcher)
    end

    BaseballState.pitcherPed = nil
end

local function configureInterface(location)
    SendNUIMessage({
        action = 'configure',
        locationLabel = location.label,
        handedness = location.batter.handedness,
        strikeZone = Config.StrikeZone,
        pci = Config.PCI,
        debugEnabled = BaseballState.debugEnabled,
        ballCameraEnabled = BaseballState.ballCameraEnabled,
        sounds = Config.Sounds
    })

    SendNUIMessage({
        action = 'setPCI',
        x = 0.0,
        y = 0.0,
        radius = Config.PCI.defaultRadius
    })

    SendNUIMessage({
        action = 'setVisible',
        visible = true
    })
end

function StartBattingPractice(locationId)
    if BaseballState.active then
        return false
    end

    local location, selectedId = getLocation(locationId)
    if not location then
        notify(('~r~Unknown baseball location:~s~ %s'):format(tostring(locationId)))
        return false
    end

    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then
        notify('Exit your vehicle before starting batting practice.')
        return false
    end

    BaseballState.active = true
    BaseballState.phase = 'entering'
    BaseballState.sessionId = ('%s:%s'):format(GetPlayerServerId(PlayerId()), GetGameTimer())
    BaseballState.locationId = selectedId
    BaseballState.pciX = 0.0
    BaseballState.pciY = 0.0
    BaseballState.pitchProgress = 0.0
    BaseballState.pitchX = 0.0
    BaseballState.pitchY = 0.0
    BaseballState.pitchRequested = false
    BaseballState.hasSwung = false
    BaseballState.contactMade = false
    BaseballState.ballFlightActive = false

    local currentCoords = GetEntityCoords(playerPed)
    BaseballState.returnPosition = vector4(
        currentCoords.x,
        currentCoords.y,
        currentCoords.z,
        GetEntityHeading(playerPed)
    )

    local batterCoords = location.batter.coords
    RequestCollisionAtCoord(batterCoords.x, batterCoords.y, batterCoords.z)
    ClearPedTasksImmediately(playerPed)
    SetEntityCoordsNoOffset(playerPed, batterCoords.x, batterCoords.y, batterCoords.z, false, false, false)
    SetEntityHeading(playerPed, batterCoords.w)
    FreezeEntityPosition(playerPed, location.batter.freezePosition)

    createBatterBat(playerPed)
    createPitcher(location.pitcher)
    BaseballCamera.Start(location.camera)
    configureInterface(location)

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SetCursorLocation(0.5, 0.5)

    BaseballState.phase = 'ready'
    startPitchingController()
    TriggerEvent('slothy-baseball:client:started', selectedId)
    SlothyBaseball.Debug(('Started batting practice at %s.'):format(selectedId))
    return true
end

function StopBattingPractice(restorePosition, immediateCamera)
    if not BaseballState.active and BaseballState.phase == 'idle' then
        return false
    end

    local previousLocationId = BaseballState.locationId
    local location = previousLocationId and Config.Locations[previousLocationId] or nil
    local playerPed = PlayerPedId()

    BaseballState.active = false
    BaseballState.phase = 'exiting'
    stopPitchingController()
    stopBallFlight(false)

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'setVisible', visible = false })
    SendNUIMessage({ action = 'reset' })
    SendNUIMessage({ action = 'resetPitch' })
    SendNUIMessage({ action = 'hideResult' })

    BaseballCamera.Stop(immediateCamera == true)
    deleteBatterBat()
    deletePitcher()

    if Config.Hud.hideRadar then
        DisplayRadar(true)
    end

    if DoesEntityExist(playerPed) then
        FreezeEntityPosition(playerPed, false)

        local shouldRestore = restorePosition
        if shouldRestore == nil then
            shouldRestore = location and location.batter.restoreOriginalPosition
        end

        if shouldRestore and BaseballState.returnPosition and not IsEntityDead(playerPed) then
            local returnPosition = BaseballState.returnPosition
            RequestCollisionAtCoord(returnPosition.x, returnPosition.y, returnPosition.z)
            SetEntityCoordsNoOffset(
                playerPed,
                returnPosition.x,
                returnPosition.y,
                returnPosition.z,
                false,
                false,
                false
            )
            SetEntityHeading(playerPed, returnPosition.w)
        end
    end

    BaseballState.phase = 'idle'
    BaseballState.sessionId = nil
    BaseballState.locationId = nil
    BaseballState.pciX = 0.0
    BaseballState.pciY = 0.0
    BaseballState.pitchRequested = false
    BaseballState.currentPitch = nil
    BaseballState.pitchProgress = 0.0
    BaseballState.pitchX = 0.0
    BaseballState.pitchY = 0.0
    BaseballState.hasSwung = false
    BaseballState.contactMade = false
    BaseballState.ballFlightActive = false
    BaseballState.batProp = nil
    BaseballState.returnPosition = nil

    TriggerEvent('slothy-baseball:client:stopped', previousLocationId)
    SlothyBaseball.Debug('Stopped batting practice and restored controls.')
    return true
end

RegisterNUICallback('pciMove', function(data, callback)
    if BaseballState.active then
        local x = tonumber(data.x) or 0.0
        local y = tonumber(data.y) or 0.0

        BaseballState.pciX = SlothyBaseball.Clamp(x, -Config.PCI.maximumX, Config.PCI.maximumX)
        BaseballState.pciY = SlothyBaseball.Clamp(y, -Config.PCI.maximumY, Config.PCI.maximumY)
    end

    callback({ ok = true })
end)

AddEventHandler('slothy-baseball:client:requestPitch', function()
    requestAIPitch()
end)

AddEventHandler('slothy-baseball:client:swingInput', function()
    resolveSwing(BaseballState.pciX, BaseballState.pciY)
end)

AddEventHandler('slothy-baseball:client:toggleBallCamera', function()
    toggleBallCamera()
end)

RegisterNUICallback('requestPitch', function(_, callback)
    callback({ ok = requestAIPitch() })
end)

RegisterNUICallback('swing', function(data, callback)
    callback({
        ok = resolveSwing(data.pciX, data.pciY)
    })
end)

RegisterNUICallback('toggleBallCamera', function(_, callback)
    callback({
        enabled = toggleBallCamera()
    })
end)

RegisterNUICallback('exit', function(_, callback)
    StopBattingPractice()
    callback({ ok = true })
end)

RegisterNUICallback('uiReady', function(_, callback)
    SlothyBaseball.Debug('NUI is ready.')
    callback({ ok = true })
end)

exports('StartBattingPractice', StartBattingPractice)
exports('StopBattingPractice', StopBattingPractice)
exports('IsBatting', function()
    return BaseballState.active
end)

