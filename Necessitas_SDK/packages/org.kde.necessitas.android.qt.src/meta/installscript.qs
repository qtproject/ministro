// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        component.addDownloadableArchive( "qt-src.7z" );
    }
}

Component.prototype.createOperations = function()
{
    try
    {
        component.createOperations();
        var qtPath = "";
        component.addOperation( "RegisterQtCreatorSourceMapping", "@TargetDir@", "/tmp/necessitas/Android/Qt/@@COMPACT_VERSION@@/qt-src", "@TargetDir@/Android/Qt/@@COMPACT_VERSION@@/qt-src" );
    }
    catch( e )
    {
        print( e );
    }
}

