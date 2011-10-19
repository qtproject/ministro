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
        component.addDownloadableArchive( "gdbserver-head.7z" );
        if (installer.value("os") == "x11")
        {
            component.addDownloadableArchive( "gdb-head-linux-x86.7z" );
        }
        else if (installer.value("os") == "win")
        {
            component.addDownloadableArchive( "gdb-head-windows.7z" );
        }
        else if (installer.value("os") == "mac")
        {
            component.addDownloadableArchive( "gdb-head-darwin-x86.7z" );
        }
    }
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations(unpacking ...)
    component.createOperations();

    var gdbPath = "@TargetDir@/gdb-head/gdb";
    var gdbserverPath = "@TargetDir@/gdbserver-head/gdbserver";
    var pythonPath="@TargetDir@/gdb-head/python/bin/python2.7"
    if (installer.value("os") == "win")
    {
        gdbPath+=".exe";
        pythonPath+=".exe";
    }

    component.addOperation( "RegisterPersistentSettings",
                            "android.xml",
                            "GdbLocation",
                            gdbPath );

    component.addOperation( "RegisterPersistentSettings",
                            "android.xml",
                            "GdbserverLocation",
                            gdbserverPath );

    component.addOperation( "EnvironmentVariable",
                            "PYTHONHOME",
                            "@TargetDir@/gdb-head/python" );

    // Compile python sources
    component.addOperation( "Execute",
                            pythonPath,
                            "-OO", "@TargetDir@/gdb-head/python/lib/python2.7/compileall.py",
                            "-f", "@TargetDir@/gdb-head/python/lib" );
}
