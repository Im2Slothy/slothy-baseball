Config = {}

Config.Debug = true
Config.DefaultLocation = 'grove_street'

Config.Commands = {
    toggle = 'baseball',
    debug = 'baseballdebug'
}

Config.Controls = {
    enter = 38, -- E / INPUT_CONTEXT
    exit = 177, -- Backspace / INPUT_CELLPHONE_CANCEL
    requestPitch = 22, -- Space / INPUT_JUMP
    swing = 24, -- Left mouse / INPUT_ATTACK
    toggleBallCamera = 26 -- C / INPUT_LOOK_BEHIND
}

Config.Interaction = {
    prompt = 'Press ~INPUT_CONTEXT~ to Bat',
    radius = 2.0,
    drawDistance = 18.0,
    marker = {
        enabled = true,
        type = 1,
        scale = vector3(0.8, 0.8, 0.22),
        color = { r = 220, g = 52, b = 68, a = 125 }
    }
}

Config.StrikeZone = {
    widthVw = 21.0,
    heightVh = 38.0,
    centerXPercent = 50.0,
    centerYPercent = 48.0,
    showGrid = true
}

Config.PCI = {
    defaultRadius = 0.18,
    maximumX = 1.45,
    maximumY = 1.35,
    sensitivity = 1.0,
    smoothing = 0.18,
    resetEveryPitch = true
}

-- Normalized coordinates use +/- 1.0 as the visible strike-zone edges.
Config.PitchLocation = {
    strikeMaximumX = 0.88,
    strikeMaximumY = 0.80,
    ballMinimum = 1.04,
    ballMaximumX = 1.32,
    ballMaximumY = 1.25,
    ballParallelMaximum = 0.95
}

Config.Camera = {
    transitionMs = 750,
    easeOutMs = 500
}

Config.Pitching = {
    enabled = true,
    releaseDelayMs = 700,
    betweenPitchesMs = 1400,
    minimumDurationMs = 600,
    maximumDurationMs = 900,
    animationDictionary = 'weapons@projectile@',
    animationName = 'throw_m_fb_stand',
    animationDurationMs = 1250,
    minimumBallSize = 7,
    maximumBallSize = 34,
    overrunProgress = 1.18,
    maximumOverrunBallSize = 58
}

Config.Swing = {
    idealProgress = 0.98,
    maximumTimingWindow = 0.22,
    perfectTimingWindow = 0.045,
    perfectRadius = 0.10,
    goodRadius = 0.23,
    outerRadius = 0.42,
    placementWeight = 0.60,
    timingWeight = 0.40,
    animationDictionary = 'mini@tennis',
    animationName = 'forehand_ts_md_far',
    animationDurationMs = 700,
    contactDelayMs = 220
}

Config.Bat = {
    enabled = true,
    model = 'p_cs_bbbat_01',
    bone = 28422, -- PH_R_Hand
    position = vector3(0.060, 0.070, 0.010),
    rotation = vector3(-73.8317, 0.8479, -12.8826),
    loadTimeoutMs = 3000
}

Config.HitPhysics = {
    minimumExitVelocity = 35.0,
    maximumExitVelocity = 115.0,
    minimumLaunchAngle = -15.0,
    maximumLaunchAngle = 60.0,
    distanceVelocityMultiplier = 4.8,
    randomExitVelocity = 3.0
}

Config.HitCamera = {
    enabledByDefault = true,
    position = vector3(-320.83, -1653.19, 46.63),
    referenceHeading = 297.44,
    fov = 52.0,
    transitionMs = 450,
    returnDelayMs = 700
}

Config.BallFlight = {
    model = 'w_am_baseball',
    originHeight = 0.95,
    minimumDurationMs = 1800,
    maximumDurationMs = 5500,
    maximumDistanceFeet = 520.0,
    maximumApexMeters = 55.0,
    trailSegments = 55,
    trailColor = { r = 255, g = 35, b = 55, a = 210 }
}

Config.Sounds = {
    enabled = true,
    volume = 0.48
}

Config.Pitches = {
    four_seam = {
        label = '4-Seam Fastball',
        enabled = true,
        weight = 50,
        strikeChance = 0.72,
        minSpeed = 90,
        maxSpeed = 98,
        breakX = 0.025,
        breakY = 0.01
    },
    changeup = {
        label = 'Changeup',
        enabled = true,
        weight = 25,
        strikeChance = 0.64,
        minSpeed = 76,
        maxSpeed = 84,
        breakX = 0.05,
        breakY = -0.16
    },
    slider = {
        label = 'Slider',
        enabled = true,
        weight = 25,
        strikeChance = 0.58,
        minSpeed = 80,
        maxSpeed = 88,
        breakX = 0.24,
        breakY = -0.08
    }
}

Config.Hud = {
    hideRadar = true,
    hiddenComponents = { 1, 2, 3, 4, 6, 7, 8, 9, 13, 17, 20 }
}

Config.Locations = {
    grove_street = {
        label = 'Grove Street Ballfield',

        -- The interaction is intentionally at the batter position for the MVP.
        interaction = vector3(-317.03, -1644.56, 31.85),

        batter = {
            coords = vector4(-317.03, -1644.56, 31.85, 195.84),
            handedness = 'right',
            freezePosition = true,
            restoreOriginalPosition = true
        },

        -- The supplied mound Z was one metre too high for this field.
        pitcher = {
            enabled = true,
            model = 'a_m_y_beach_01',
            coords = vector4(-302.15, -1641.31, 31.15, 106.22)
        },

        -- Catcher-height camera based on the supplied behind-home-plate position.
        -- The configured position is elevated above the ground coordinate so the
        -- camera does not sit inside the dirt.
        camera = {
            position = vector3(-317.34, -1645.50, 32.66),
            target = vector3(-302.15, -1641.31, 32.20),
            fov = 42.0
        }
    }
}

