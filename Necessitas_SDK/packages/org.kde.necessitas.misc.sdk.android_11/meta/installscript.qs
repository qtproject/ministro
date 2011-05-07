// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        if (installer.value("os") == "x11")
        {
            component.addDownloadableArchive( "android-3.0_r01-linux.7z" );
        }
        else if (installer.value("os") == "win")
        {
            component.addDownloadableArchive( "android-3.0_r01-windows.7z" );
        }
        else if (installer.value("os") == "mac")
        {
            component.addDownloadableArchive( "android-3.0_r01-macosx.7z" );
        }
    }
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations(unpacking ...)
    component.createOperations();
}
