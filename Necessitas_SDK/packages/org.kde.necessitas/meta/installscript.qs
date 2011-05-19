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
    component.loaded.connect( this, Component.prototype.loaded );

    if(installer.isInstaller()) {
        //bugfix to get the value at the beginning - before the wizard is not shown, we can't use installer.setDefaultPageVisible
        installer.currentPageChanged.connect( this, updateComponentSelectionPageNeedState );
    }

    if (installer.value("os") == "x11") {
        compiler = installer.execute( "/usr/bin/which", new Array( "g++" ) )[0];
        if (!compiler) {
            QMessageBox["warning"]( "compilerError", "No compiler!", "You need a C++ compiler. Please install it using the System Package Management tools." );
        }
    }

    if (installer.value("os") == "mac") {
        compiler = installer.execute( "/usr/bin/which", new Array( "g++" ) )[0];
        if (!compiler) {
            QMessageBox["warning"]( "compilerError", "No compiler!", "You need a C++ compiler to be able install the Qt SDK. Please install the latest Xcode first before invoking this installer!" );
        }
    }

    if (installer.value("os") == "win") {
        refreshInstalledWindowsCompilerValues();
    }

    if( component.fromOnlineRepository )
    {
        component.addDownloadableArchive( "readme.7z" );
    }
    installer.installationFinished.connect( this, Component.prototype.installationFinishedPageIsShown );
    installer.finishButtonClicked.connect( this, Component.prototype.installationFinished );
}

// called as soon as the component was loaded
Component.prototype.loaded = function()
{
    try
    {
        if(installer.isInstaller()) {
            // preselect the complete component tree
            component.selected = true;

            adjustToDefaultSelection();

            installer.addWizardPageItem( component, "InstallationKindWidget", QInstaller.TargetDirectory );
            component.userInterface( "InstallationKindWidget" ).DefaultRadioButton['toggled(bool)'].connect(this, changeInstallationKind);
            component.userInterface( "InstallationKindWidget" ).CustomRadioButton['toggled(bool)'].connect(this, updateComponentSelectionPageNeedState);

            if (installer.value("QtCreatorSettingsFile") != "")
                installer.addWizardPageItem( component, "CreatorSettingsWidget", QInstaller.TargetDirectory );
        }

        installer.setValue("GlobalExamplesDir", "Examples");
        installer.setValue("GlobalDemosDir", "Demos");
        installer.setValue("QtVersionLabel", "Qt SDK");

    }
    catch( e )
    {
        print( e );
    }
}

refreshMinGWInstallerValue = function()
{
    if( typeof installer.componentByName("com.nokia.ndk.misc.mingw") == 'undefined' ) {
        print("Warning: no MinGW package is available");
        installer.setSharedFlag("compilerMinGW", false);
    } else {
        installer.setSharedFlag("compilerMinGW", installer.componentByName("com.nokia.ndk.misc.mingw").selected);
    }
}

refreshInstalledWindowsCompilerValues = function()
{
    try
    {
        //Visual Studio 2008 check
        if(installer.environmentVariable("VS90COMNTOOLS")) {
            //print("Visual Studio 2008 environment is found")
            installer.setSharedFlag("compilerVS90", true);
        } else {
            installer.setSharedFlag("compilerVS90", false);
        }

        //Visual Studio 2005 check
        if(installer.environmentVariable("VS80COMNTOOLS")) {
            //print("Visual Studio 2005 environment is found")
            installer.setSharedFlag("compilerVS80", true);
        } else {
            installer.setSharedFlag("compilerVS80", false);
        }

        //MinGW check
        refreshMinGWInstallerValue();
        if (typeof installer.componentByName("com.nokia.ndk.misc.mingw") != 'undefined')
        {
            installer.componentByName("com.nokia.ndk.misc.mingw").selectedChanged.connect( this, refreshMinGWInstallerValue );
        }

        installer.setSharedFlag("compilersInitialized", true);
    }
    catch( e )
    {
        print( e );
    }
}

updateComponentSelectionPageNeedState = function()
{
    installer.setDefaultPageVisible( QInstaller.ComponentSelection, component.userInterface( "InstallationKindWidget" ).CustomRadioButton.checked );
}


changeInstallationKind = function()
{
    //if the DefaultRadioButton is choosen we have to select all components again
    if( component.userInterface( "InstallationKindWidget" ).DefaultRadioButton.checked ) {
        //reset all selections
        component.selected = false;
        //now set the full selection again(the change from unselected to selected results in calling the preselect functions in other scripts)
        component.selected = true;
        adjustToDefaultSelection();
    }
}

adjustToDefaultSelection = function()
{
    //unselect all experimental things
    if (installer.componentByName("com.nokia.ndk.experimental") != null
        && installer.componentByName("com.nokia.ndk.experimental").selected)
    {
        installer.componentByName("com.nokia.ndk.experimental").selected = false;
    }

    //remove sources
    if (installer.componentByName("com.nokia.ndk.misc.qtsources") != null &&
        installer.componentByName("com.nokia.ndk.misc.qtsources").selected)
    {
        installer.componentByName("com.nokia.ndk.misc.qtsources").selected = false;
    }
    // deselect Desktop Qt 4.7.1 by default
    if (installer.componentByName("com.nokia.ndk.tools.desktop.471") != null &&
        installer.componentByName("com.nokia.ndk.tools.desktop.471").selected)
    {
        installer.componentByName("com.nokia.ndk.tools.desktop.471").selected = false;
    }
    if (installer.componentByName("com.nokia.ndk.tools.desktop.471.2005") != null &&
        installer.componentByName("com.nokia.ndk.tools.desktop.471.2005").selected)
    {
        installer.componentByName("com.nokia.ndk.tools.desktop.471.2005").selected = false;
    }
    if (installer.componentByName("com.nokia.ndk.tools.desktop.471.2008") != null &&
        installer.componentByName("com.nokia.ndk.tools.desktop.471.2008").selected)
    {
        installer.componentByName("com.nokia.ndk.tools.desktop.471.2008").selected = false;
    }
    if (installer.componentByName("com.nokia.ndk.tools.desktop.471.gcc") != null &&
        installer.componentByName("com.nokia.ndk.tools.desktop.471.gcc").selected)
    {
        installer.componentByName("com.nokia.ndk.tools.desktop.471.gcc").selected = false;
    }
    if (installer.componentByName("com.nokia.ndk.tools.desktop.471.mingw") != null &&
        installer.componentByName("com.nokia.ndk.tools.desktop.471.mingw").selected)
    {
        installer.componentByName("com.nokia.ndk.tools.desktop.471.mingw").selected = false;
    }
    // deselect Desktop Qt 4.7.2 by default
    if (installer.componentByName("com.nokia.ndk.tools.desktop.472") != null &&
        installer.componentByName("com.nokia.ndk.tools.desktop.472").selected)
    {
        installer.componentByName("com.nokia.ndk.tools.desktop.472").selected = false;
    }
    if (installer.componentByName("com.nokia.ndk.tools.desktop.472.2005") != null &&
        installer.componentByName("com.nokia.ndk.tools.desktop.472.2005").selected)
    {
        installer.componentByName("com.nokia.ndk.tools.desktop.472.2005").selected = false;
    }
    if (installer.componentByName("com.nokia.ndk.tools.desktop.472.2008") != null &&
        installer.componentByName("com.nokia.ndk.tools.desktop.472.2008").selected)
    {
        installer.componentByName("com.nokia.ndk.tools.desktop.472.2008").selected = false;
    }
    if (installer.componentByName("com.nokia.ndk.tools.desktop.472.gcc") != null &&
        installer.componentByName("com.nokia.ndk.tools.desktop.472.gcc").selected)
    {
        installer.componentByName("com.nokia.ndk.tools.desktop.472.gcc").selected = false;
    }
    if (installer.componentByName("com.nokia.ndk.tools.desktop.472.mingw") != null &&
        installer.componentByName("com.nokia.ndk.tools.desktop.472.mingw").selected)
    {
        installer.componentByName("com.nokia.ndk.tools.desktop.472.mingw").selected = false;
    }
}


Component.prototype.createOperations = function()
{
    // Call the base createOperations and afterwards set some registry settings
    component.createOperations();
    if (component.userInterface( "CreatorSettingsWidget" ).removeCheckBox.checked ) {
        component.addOperation( "SimpleMoveFile", "@QtCreatorSettingsFile@", "@QtCreatorSettingsFile@_backup");
    }
    if ( installer.value("os") == "win" )
    {
        component.addOperation( "CreateShortcut", "@TargetDir@/readme/index.html", "@StartMenuDir@/Getting Started with the Qt SDK.lnk" );
    }
}

Component.prototype.installationFinishedPageIsShown = function()
{
    try
    {
        if (installer.isInstaller() && installer.status == QInstaller.InstallerSucceeded)
        {
            installer.addWizardPageItem( component, "ReadMeCheckBoxForm", QInstaller.InstallationFinished );
        }
    }
    catch( e )
    {
        print( e );
    }
}

Component.prototype.installationFinished = function()
{
    try
    {
        if (installer.isInstaller() && installer.status == QInstaller.InstallerSucceeded)
        {
            var isReadMeCheckBoxChecked = component.userInterface( "ReadMeCheckBoxForm" ).readMeCheckBox.checked;
            if (isReadMeCheckBoxChecked)
            {
                QDesktopServices.openUrl("file:///" + installer.value("TargetDir") + "/readme/index.html");
            }
        }
    }
    catch( e )
    {
        print( e );
    }
}

