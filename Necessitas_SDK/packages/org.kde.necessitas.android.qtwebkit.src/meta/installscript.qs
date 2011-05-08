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
    try
    {
        component.createOperations();
        var qtPath = "";
        component.addOperation( "RegisterQtCreatorSourceMapping", "@TargetDir@", "/var/necessitas/Android/Qt/@@COMPACT_VERSION@@/qtwebkit-src", "@TargetDir@/Android/Qt/@@COMPACT_VERSION@@/qtwebkit-src" );
    }
    catch( e )
    {
        print( e );
    }
}

