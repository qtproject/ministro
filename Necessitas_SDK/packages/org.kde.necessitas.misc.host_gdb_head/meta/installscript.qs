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

function OsToHostTag()
{
    if (installer.value("os") == "x11")
    {
        return "linux-x86";
    }
    else if (installer.value("os") == "win")
    {
        return "windows";
    }
    else if (installer.value("os") == "mac")
    {
        return "darwin-x86";
    }
}

// constructor
function Component()
{
    if( component.fromOnlineRepository )
    {
        component.addDownloadableArchive( "gdb_"+OsToHostTag()+"-head.7z" );
    }
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations(unpacking ...)
    component.createOperations();

    var basePath = "@TargetDir@/gdb_"+OsToHostTag()+"-head/";
    var gdbPath = basePath+"gdb";
    var pythonPath=basePath+"python/bin/python2.7"
    if (installer.value("os") == "win")
    {
        gdbPath+=".exe";
        pythonPath+=".exe";
    }

/*    component.addOperation( "SetQtCreatorValue",
                            "@TargetDir@",
                            "AndroidConfigurations",
                            "GdbLocation",
                            gdbPath );
*/
    if (installer.value("os") != "win")
    {
        component.addOperation( "EnvironmentVariable",
                                "PYTHONHOME",
                                basePath+"python" );
    }

    // Compile python sources
    component.addOperation( "Execute",
                            pythonPath,
                            "-OO", basePath+"python/lib/python2.7/compileall.py",
                            "-f",  basePath+"python/lib" );
}
