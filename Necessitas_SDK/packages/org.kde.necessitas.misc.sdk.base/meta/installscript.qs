// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        if (installer.value("os") == "x11")
        {
            component.addDownloadableArchive( "android-sdk-linux_x86.7z" );
        }
        else if (installer.value("os") == "win")
        {
            component.addDownloadableArchive( "android-sdk-windows.7z" );
        }
        else if (installer.value("os") == "mac")
        {
            component.addDownloadableArchive( "android-sdk-mac_x86.7z" );
        }
    }
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations(unpacking ...)
    component.createOperations();
    // set SDK Location

    var gdbPath;
    if (installer.value("os") == "x11")
    {
        gdbPath="@TargetDir@/android-sdk-linux_x86";
    }
    else if (installer.value("os") == "win")
    {
        gdbPath="@TargetDir@/android-sdk-windows";
    }
    else if (installer.value("os") == "mac")
    {
        gdbPath="@TargetDir@/android-sdk-mac_x86";
    }

    component.addOperation( "SetQtCreatorValue",
                            "@TargetDir@",
                            "AndroidConfigurations",
                            "SDKLocation",
                            sdkPath );
}
