// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        component.addDownloadableArchive( "qtmobility-src.7z" );
    }
}

Component.prototype.createOperations = function()
{
    try
    {
        component.createOperations();
        var qtPath = "";
        component.addOperation( "RegisterQtCreatorSourceMapping", "@TargetDir@", "/var/necessitas/Android/Qt/@@COMPACT_VERSION@@/qtmobility-src", "@TargetDir@/Android/Qt/@@COMPACT_VERSION@@/qtmobility-src" );
    }
    catch( e )
    {
        print( e );
    }
}

