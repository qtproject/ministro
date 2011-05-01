// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        component.addDownloadableArchive( "qtwebkit-src.7z" );
    }
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations and afterwards set some registry settings
    component.createOperations();
}

