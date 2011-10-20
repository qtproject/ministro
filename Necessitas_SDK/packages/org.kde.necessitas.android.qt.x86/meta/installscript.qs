/*
    Copyright (c) 2011, BogDan Vatra <bog_dan_ro@yahoo.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        if (installer.value("os") == "x11")
        {
            component.addDownloadableArchive( "qt-framework.7z" );
            component.addDownloadableArchive( "qt-tools-linux-x86.7z" );
        }
        else if (installer.value("os") == "win")
        {
            component.addDownloadableArchive( "qt-framework-windows.7z" );
            component.addDownloadableArchive( "qt-tools-windows.7z" );
        }
        else if (installer.value("os") == "mac")
        {
            component.addDownloadableArchive( "qt-framework.7z" );
            component.addDownloadableArchive( "qt-tools-darwin-x86.7z" );
        }
    }
}

Component.prototype.createOperations = function()
{
    try
    {
        component.createOperations();
        var qtPath = "@TargetDir@/Android/Qt/@@NECESSITAS_QT_VERSION_SHORT@@/x86";
        component.addOperation( "QtPatch2", qtPath );
        component.addOperation( "RegisterQtInCreatorV23",
                                "Necessitas Qt @@NECESSITAS_QT_VERSION@@ for Android x86",
                                qtPath,
                                "Android",
                                "Android_Platform_API_9_x86");
    }
    catch( e )
    {
        print( e );
    }
}
