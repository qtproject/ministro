// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        if (installer.value("os") == "x11")
        {
            component.addDownloadableArchive( "android-1.6_r03-linux.7z" );
        }
        else if (installer.value("os") == "win")
        {
            component.addDownloadableArchive( "android-1.6_r03-windows.7z" );
        }
        else if (installer.value("os") == "mac")
        {
            component.addDownloadableArchive( "android-1.6_r03-macosx.7z" );
        }
    }
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations(unpacking ...)
    component.createOperations();
    // set SDK Location
}
