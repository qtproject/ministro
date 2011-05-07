// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        component.addDownloadableArchive( "qtmobility.7z" );
    }
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations and afterwards set some registry settings
    component.createOperations();
    try
    {
        component.createOperations();
        var qtPath = "@TargetDir@/Android/Qt/@@COMPACT_VERSION@@/armeabi";
        component.addOperation( "QtPatch", qtPath, "/data/data/eu.licentia.necessitas.ministro/files/qt" );
    }
    catch( e )
    {
        print( e );
    }
}
