// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        component.addDownloadableArchive( "qtwebkit.7z" );
    }
}

Component.prototype.createOperations = function()
{
    try
    {
        component.createOperations();
        var qtPath = "@TargetDir@/Android/Qt/@@COMPACT_VERSION@@/armeabi-v7a";
        component.addOperation( "QtPatch", qtPath, "/data/data/eu.licentia.necessitas.ministro/files/qt" );
    }
    catch( e )
    {
        print( e );
    }
}
