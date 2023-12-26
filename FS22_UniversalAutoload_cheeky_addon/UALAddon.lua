UALAddon = {}
UALAddon.path = g_currentModDirectory

addModEventListener(UALAddon)

function UALAddon:loadMap(name) 
    if g_modIsLoaded["FS22_UniversalAutoload"] then 
        local containerSettingsFile = Utils.getFilename("config/ContainerTypes.xml", UALAddon.path) 
        print("IMPORT Cheeky custom container configurations")
        FS22_UniversalAutoload.UniversalAutoloadManager.ImportGlobalSettings(containerSettingsFile)
        FS22_UniversalAutoload.UniversalAutoloadManager.ImportContainerTypeConfigurations(containerSettingsFile, true)
    else 
        print("FS22_UniversalAutoload is required!") 
    end
end