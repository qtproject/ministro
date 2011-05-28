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
    installer.installationFinished.connect( this, Component.prototype.installationFinished );
    if (installer.value("os") == "win")
    {
        component.selectedChanged.connect( this, checkWhetherStopProcessIsNeeded );
        //it can't be unselected so we need to check it manually
        checkWhetherStopProcessIsNeeded();
    }

    if( component.fromOnlineRepository )
    {
        if (installer.value("os") == "x11")
        {
            component.addDownloadableArchive( "qtcreator-linux-x86.7z" );
        }
        else if (installer.value("os") == "win")
        {
            component.addDownloadableArchive( "qtcreator-windows.7z" );
        }
        else if (installer.value("os") == "mac")
        {
            component.addDownloadableArchive( "qtcreator-darwin-x86.7z" );
        }
    }
}

checkWhetherStopProcessIsNeeded = function()
{
    if (installer.value("os") != "win")
        return;
    if (component.installationRequested() || component.uninstallationRequested())
    {
        component.setStopProcessForUpdateRequest("@TargetDir@/QtCreator/bin/qtcreator.exe", true);
        component.setStopProcessForUpdateRequest("@TargetDir@/QtCreator/bin/linguist.exe", true);
        component.setStopProcessForUpdateRequest("@TargetDir@/QtCreator/bin/qmlviewer.exe", true);
    }
    else
    {
        component.setStopProcessForUpdateRequest("@TargetDir@/QtCreator/bin/qtcreator.exe", false);
        component.setStopProcessForUpdateRequest("@TargetDir@/QtCreator/bin/linguist.exe", false);
        component.setStopProcessForUpdateRequest("@TargetDir@/QtCreator/bin/qmlviewer.exe", false);
    }

}


Component.prototype.createOperations = function()
{
    // Call the base createOperations and afterwards set some registry settings
    component.createOperations();

    if (installer.value("os") == "win") {
        var win_application = installer.value("TargetDir") + "/SDKMaintenanceTool.exe";
        component.addOperation( "SetQtCreatorValue",
                                "@TargetDir@",
                                "Updater",
                                "Application",
                                win_application );
    } else if (installer.value("os") == "x11") {
        component.addOperation( "SetQtCreatorValue",
                                "@TargetDir@",
                                "Updater",
                                "Application",
                                "@TargetDir@/SDKMaintenanceTool" );
    } else if (installer.value("os") == "mac") {
        component.addOperation( "SetQtCreatorValue",
                                "@TargetDir@",
                                "Updater",
                                "Application",
                                "@TargetDir@/SDKMaintenanceTool.app/Contents/MacOS/SDKMaintenanceTool" );
    }
    component.addOperation( "SetQtCreatorValue",
                            "@TargetDir@",
                            "Updater",
                            "CheckOnlyArgument",
                            "--checkupdates" );
    component.addOperation( "SetQtCreatorValue",
                            "@TargetDir@",
                            "Updater",
                            "RunUiArgument",
                            "--updater" );

    if ( installer.value("os") == "x11" )
    {
//        component.addOperation( "SetPluginPathOnQtCore",
//                                "@TargetDir@/QtCreator/lib/qtcreator",
//                                "@TargetDir@/QtCreator/lib/qtcreator/plugins");

        component.addOperation( "InstallIcons", "@TargetDir@/QtCreator/icons" );
        component.addOperation( "CreateDesktopEntry",
                                "Necessitas-qtcreator.desktop",
                                "Type=Application\nExec=@TargetDir@/QtCreator/bin/necessitas\nPath=@homeDir@\nName=Necessitas Qt Creator\nGenericName=The IDE of choice for development on Android devices.\nIcon=necessitas\nTerminal=false\nCategories=Development;IDE;Qt;\nMimeType=text/x-c++src;text/x-c++hdr;text/x-xsrc;application/x-designer;application/vnd.nokia.qt.qmakeprofile;application/vnd.nokia.xml.qt.resource;"
                                );
    }
    if ( installer.value("os") == "win" )
    {
        component.addOperation( "SetPluginPathOnQtCore",
                                "@TargetDir@/QtCreator/bin",
                                "@TargetDir@/QtCreator/plugins");
        component.addOperation( "CreateShortcut",
                                "@TargetDir@\\QtCreator\\bin\\qtcreator.exe",
                                "@StartMenuDir@/Qt Creator.lnk",
                                "workingDirectory=@homeDir@" );

        var headerExtensions = new Array("h", "hh", "hxx", "h++", "hpp", "hpp");

        for (var i = 0; i < headerExtensions.length; ++i) {
            component.addOperation( "RegisterFileType",
                                    headerExtensions[i],
                                    "@TargetDir@\\QtCreator\\bin\\qtcreator.exe -client '%1'",
                                    "C++ Header file",
                                    "",
                                    "@TargetDir@\\QtCreator\\bin\\qtcreator.exe,3");
        }

        var cppExtensions = new Array("cc", "cxx", "c++", "cp", "cpp");

        for (var i = 0; i < cppExtensions.length; ++i) {
            component.addOperation( "RegisterFileType",
                                    cppExtensions[i],
                                    "@TargetDir@\\QtCreator\\bin\\qtcreator.exe -client '%1'",
                                    "C++ Source file",
                                    "",
                                    "@TargetDir@\\QtCreator\\bin\\qtcreator.exe,2");
        }

        component.addOperation( "RegisterFileType",
                                "c",
                                "@TargetDir@\\QtCreator\\bin\\qtcreator.exe -client '%1'",
                                "C Source file",
                                "",
                                "@TargetDir@\\QtCreator\\bin\\qtcreator.exe,1");
        component.addOperation( "RegisterFileType",
                                "ui",
                                "@TargetDir@\\QtCreator\\bin\\qtcreator.exe -client '%1'",
                                "Qt UI file",
                                "",
                                "@TargetDir@\\QtCreator\\bin\\qtcreator.exe,4");
        component.addOperation( "RegisterFileType",
                                "pro",
                                "@TargetDir@\\QtCreator\\bin\\qtcreator.exe -client '%1'",
                                "Qt Project file",
                                "",
                                "@TargetDir@\\QtCreator\\bin\\qtcreator.exe,5");
        component.addOperation( "RegisterFileType",
                                "pri",
                                "@TargetDir@\\QtCreator\\bin\\qtcreator.exe -client '%1'",
                                "Qt Project Include file",
                                "",
                                "@TargetDir@\\QtCreator\\bin\\qtcreator.exe,6");

    }
}

Component.prototype.installationFinished = function()
{
    if (installer.isInstaller() && component.selected)
    {
        if (installer.value("os") == "win")
        {
            installer.setValue("RunProgram", installer.value("TargetDir") + "\\QtCreator\\bin\\qtcreator.exe");
            installer.setValue("RunProgramDescription", "Launch Qt Creator");
        }
        else if (installer.value("os") == "x11")
        {
            installer.setValue("RunProgram", installer.value("TargetDir") + "/QtCreator/bin/necessitas");
            installer.setValue("RunProgramDescription", "Launch Qt Creator");
        }
        else if (installer.value("os") == "mac")
        {
            installer.setValue("RunProgram", "\"" + installer.value("TargetDir") + "/QtCreator/bin/NecessitasQtCreator.app/Contents/MacOS/NecessitasQtCreator\"");
            installer.setValue("RunProgramDescription", "Launch Qt Creator");
        }
    }
}

