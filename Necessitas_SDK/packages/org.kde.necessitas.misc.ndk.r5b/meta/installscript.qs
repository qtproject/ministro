// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        if (installer.value("os") == "x11")
        {
            component.addDownloadableArchive( "android-ndk-r5b-linux-x86.7z" );
        }
        else if (installer.value("os") == "win")
        {
            component.addDownloadableArchive( "android-ndk-r5b-windows.7z" );
        }
        else if (installer.value("os") == "mac")
        {
            component.addDownloadableArchive( "android-ndk-r5b-darwin-x86.7z" );
        }
    }
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations(unpacking ...)
    component.createOperations();
    // set NDK Location
    component.addOperation( "SetQtCreatorValue",
                            "@TargetDir@",
                            "AndroidConfigurations",
                            "NDKLocation",
                            "@TargetDir@/android-ndk-r5b" );
    // set NDK toolchain version
    component.addOperation( "SetQtCreatorValue",
                            "@TargetDir@",
                            "AndroidConfigurations",
                            "NDKToolchainVersion",
                            "arm-linux-androideabi-4.4.3" );

    // set DEFAULT gdb location
    var gdbPath = "@TargetDir@/android-ndk-r5b/toolchains/arm-linux-androideabi-4.4.3/prebuilt/";
    if (installer.value("os") == "x11")
    {
        gdbPath+="linux-x86/bin/arm-linux-androideabi-gdb";
    }
    else if (installer.value("os") == "win")
    {
        gdbPath+="windows/bin/arm-linux-androideabi-gdb.exe";
    }
    else if (installer.value("os") == "mac")
    {
        gdbPath+="darwin-x86/bin/arm-linux-androideabi-gdb";
    }

    component.addOperation( "SetQtCreatorValue",
                            "@TargetDir@",
                            "AndroidConfigurations",
                            "GdbLocation",
                            gdbPath );
}
