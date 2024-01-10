WorkCameraAddon = {}
WorkCameraAddon.path = g_currentModDirectory

addModEventListener(WorkCameraAddon)

function WorkCameraAddon:loadMap(name)
    if g_modIsLoaded["FS22_WorkCamera"] then
        local cameraSettingsFile = Utils.getFilename("config/CustomCameras.xml", WorkCameraAddon.path)
        print("IMPORT Cheeky custom camera configurations")
        FS22_WorkCamera.WorkCameraMain:loadItemsDataFromXml(cameraSettingsFile)
        -- FS22_WorkCamera.WorkCamera:onLoad(savegame)
    else
        print("FS22_WorkCamera is required!")
    end
end