// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        component.addDownloadableArchive( "gdbserver-7.2.7z" );
        if (installer.value("os") == "x11")
        {
            component.addDownloadableArchive( "gdb-7.2-linux-x86.7z" );
        }
        else if (installer.value("os") == "win")
        {
            component.addDownloadableArchive( "gdb-7.2-windows.7z" );
        }
        else if (installer.value("os") == "mac")
        {
            component.addDownloadableArchive( "gdb-7.2-darwin-x86.7z" );
        }
    }
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations(unpacking ...)
    component.createOperations();

    var gdbPath = "@TargetDir@/gdb-7.2/gdb";
    var gdbserverPath = "@TargetDir@/gdbserver-7.2/gdbserver";
    if (installer.value("os") == "win")
    {
        gdbPath+=".exe";
    }

    component.addOperation( "SetQtCreatorValue",
                            "@TargetDir@",
                            "AndroidConfigurations",
                            "GdbLocation",
                            gdbPath );
    component.addOperation( "SetQtCreatorValue",
                            "@TargetDir@",
                            "AndroidConfigurations",
                            "GdbserverLocation",
                            gdbserverPath );
}
