BaseballCamera = {
    handle = nil,
    battingConfig = nil,
    tracking = false
}

local function activateCamera(camera, transitionMs)
    local previousCamera = BaseballCamera.handle

    SetCamActive(camera, true)
    BaseballCamera.handle = camera

    if previousCamera and DoesCamExist(previousCamera) then
        SetCamActiveWithInterp(camera, previousCamera, transitionMs, true, true)

        CreateThread(function()
            Wait(transitionMs)

            if DoesCamExist(previousCamera) then
                DestroyCam(previousCamera, false)
            end
        end)
    else
        RenderScriptCams(true, true, transitionMs, true, true)
    end
end

local function createBattingCamera(cameraConfig, transitionMs)
    local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camera, cameraConfig.position.x, cameraConfig.position.y, cameraConfig.position.z)
    PointCamAtCoord(camera, cameraConfig.target.x, cameraConfig.target.y, cameraConfig.target.z)
    SetCamFov(camera, cameraConfig.fov)
    activateCamera(camera, transitionMs)
end

function BaseballCamera.Start(cameraConfig)
    BaseballCamera.battingConfig = cameraConfig
    BaseballCamera.tracking = false
    createBattingCamera(cameraConfig, Config.Camera.transitionMs)
    SlothyBaseball.Debug(('Batting camera created (handle %s).'):format(BaseballCamera.handle))
end

function BaseballCamera.TrackEntity(cameraConfig, entity)
    if not entity or not DoesEntityExist(entity) then
        return false
    end

    local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camera, cameraConfig.position.x, cameraConfig.position.y, cameraConfig.position.z)
    PointCamAtEntity(camera, entity, 0.0, 0.0, 0.0, true)
    SetCamFov(camera, cameraConfig.fov)
    activateCamera(camera, cameraConfig.transitionMs)

    BaseballCamera.tracking = true
    SlothyBaseball.Debug(('Ball camera activated (handle %s).'):format(camera))
    return true
end

function BaseballCamera.ReturnToBatting()
    if not BaseballCamera.battingConfig or not BaseballCamera.tracking then
        return false
    end

    BaseballCamera.tracking = false
    createBattingCamera(BaseballCamera.battingConfig, Config.HitCamera.transitionMs)
    SlothyBaseball.Debug('Returned to the batting camera.')
    return true
end

function BaseballCamera.Stop(immediate)
    if not BaseballCamera.handle then
        return
    end

    local transition = immediate and 0 or Config.Camera.easeOutMs

    RenderScriptCams(false, not immediate, transition, true, true)
    SetCamActive(BaseballCamera.handle, false)
    DestroyCam(BaseballCamera.handle, false)
    BaseballCamera.handle = nil
    BaseballCamera.battingConfig = nil
    BaseballCamera.tracking = false
end

