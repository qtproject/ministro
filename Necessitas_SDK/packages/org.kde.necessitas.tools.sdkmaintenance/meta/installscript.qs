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
    if ( component.fromOnlineRepository )
    {
        if (installer.value("os") == "x11")
        {
            component.addDownloadableArchive( "sdkmaintenance-linux-x86.7z" );
        }
        else if (installer.value("os") == "win")
        {
            component.addDownloadableArchive( "sdkmaintenance-windows.7z" );
        }
        else if (installer.value("os") == "mac")
        {
            component.addDownloadableArchive( "sdkmaintenance-darwin-x86.7z" );
        }
    }

    if (installer.value("os") == "win") {
        component.installerbaseBinaryPath = "@TargetDir@/temp/SDKMaintenanceToolBase.exe";
    }
    else if (installer.value("os") == "x11" || installer.value("os") == "mac")
    {
        component.installerbaseBinaryPath = "@TargetDir@/.tempSDKMaintenanceTool";
    }
    installer.setInstallerBaseBinary(component.installerbaseBinaryPath);
}


Component.prototype.createOperationsForArchive = function(archive)
{
    //installer.performOperation in older versions of the installer framework don't supports @TargetDir@
    var normalizedInstallerbaseBinaryPath = component.installerbaseBinaryPath.replace(/@TargetDir@/,
        installer.value("TargetDir"));

    installer.performOperation("SimpleMoveFile",
        new Array(normalizedInstallerbaseBinaryPath, normalizedInstallerbaseBinaryPath + "_backup"));
    component.createOperationsForArchive(archive);
}

Component.prototype.createOperations = function()
{
    // Call the base createOperations(unpacking ...)
    component.createOperations();
    if (installer.value("os") == "win") {
        var win_application = installer.value("TargetDir") + "/SDKMaintenanceTool.exe";
        component.addOperation( "RegisterPersistentSettings",
                                "updateInfo.xml",
                                "Application",
                                win_application );
        component.addOperation( "CreateShortcut",
                                win_application,
                                "@StartMenuDir@/Maintain Qt SDK.lnk",
                                " --manage-packages");
        component.addOperation( "CreateShortcut",
                                win_application,
                                "@StartMenuDir@/Update Qt SDK.lnk",
                                " --updater");
    }
    else if (installer.value("os") == "x11")
    {
        component.addOperation( "RegisterPersistentSettings",
                                "updateInfo.xml",
                                "Application",
                                "@TargetDir@/SDKMaintenanceTool" );
        component.addOperation( "InstallIcons", "@TargetDir@/icons" );
        component.addOperation( "CreateDesktopEntry",
                                "Necessitas-SDKMaintenanceTool.desktop",
                                "Type=Application\nExec=@TargetDir@/SDKMaintenanceTool\nPath=@TargetDir@\nName=SDK-Maintenance-Tool\nGenericName=Install or uninstall components of the Qt SDK.\nIcon=Nokia-SDKPM\nTerminal=false\nCategories=Development;Qt;"
                               );
        component.addOperation( "CreateDesktopEntry",
                                "Necessitas-SDKUpdater.desktop",
                                "Type=Application\nExec=@TargetDir@/SDKMaintenanceTool --updater\nPath=@TargetDir@\nName=SDK-Update-Tool\nGenericName=Update components of the Qt SDK.\nIcon=Nokia-SDKUp\nTerminal=false\nCategories=Development;Qt;"
                               );
    }
    else if (installer.value("os") == "mac")
    {
        component.addOperation( "RegisterPersistentSettings",
                                "updateInfo.xml",
                                "Application",
                                "@TargetDir@/SDKMaintenanceTool.app/Contents/MacOS/SDKMaintenanceTool" );
    }

    component.addOperation( "RegisterPersistentSettings",
                            "updateInfo.xml",
                            "CheckOnlyArgument",
                            "--checkupdates" );
    component.addOperation( "RegisterPersistentSettings",
                            "updateInfo.xml",
                            "RunUiArgument",
                            "--updater" );
}
