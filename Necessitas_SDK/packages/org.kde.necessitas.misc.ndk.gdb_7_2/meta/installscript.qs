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
    var pythonPath="@TargetDir@/gdb-7.2/python2.7"
    if (installer.value("os") == "win")
    {
        gdbPath+=".exe";
        pythonPath+=".exe";
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

    component.addOperation( "EnvironmentVariable",
                            "PYTHONHOME",
                            "@TargetDir@/gdb-7.2/python" );

    // Compile python sources
    component.addOperation( "Execute",
                            pythonPath,
                            "-OO", "@TargetDir@/gdb-7.2/python/lib/python2.7/compileall.py",
                            "-f", "@TargetDir@/gdb-7.2/python/lib" );
}
