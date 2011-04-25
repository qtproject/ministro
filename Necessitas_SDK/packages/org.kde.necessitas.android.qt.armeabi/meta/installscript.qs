// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        component.addDownloadableArchive( "qt-farmework.7z" );
        if (installer.value("os") == "x11")
        {
            component.addDownloadableArchive( "qt-tools-linux-x86.7z" );
        }
        else if (installer.value("os") == "win")
        {
            component.addDownloadableArchive( "qt-tools-windows.7z" );
        }
        else if (installer.value("os") == "mac")
        {
            component.addDownloadableArchive( "qt-tools-darwin-x86.7z" );
        }
    }
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations and afterwards set some registry settings
    component.createOperations();
}

