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

function OsToAnt()
{
    if (installer.value("os") == "x11")
    {
        return "ant";
    }
    else if (installer.value("os") == "win")
    {
        return "ant.bat";
    }
    else if (installer.value("os") == "mac")
    {
        return "ant";
    }
}

// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        component.addDownloadableArchive( "ant.7z" );
    }
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations(unpacking ...)
    component.createOperations();

    component.addOperation( "RegisterPersistentSettings",
                            "android.xml",
                            "AntLocation",
                            "@TargetDir@/apache-ant-1.8.2/bin/"+OsToAnt() );
}

Component.prototype.isDefault = function()
{
    if (installer.value("os") == "x11" || installer.value("os") == "mac")
    {
        ant = installer.execute( "/usr/bin/which", new Array( "ant" ) )[0];
        if (!ant)
        {
            return true;
        }
        else
        {
            return false;
        }
    }
    else
    {
        return true;
    }
}
