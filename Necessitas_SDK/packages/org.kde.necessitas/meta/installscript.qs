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

    if (installer.value("os") == "x11" || installer.value("os") == "mac")
    {
        compiler = installer.execute( "/usr/bin/which", new Array( "g++" ) )[0];
        if (!compiler) {
            QMessageBox["warning"]( "compilerError", "No compiler!", "You need a C++ compiler. Please install it using the System Package Management tools." );
        }
        compiler = installer.execute( "/usr/bin/which", new Array( "make" ) )[0];
        if (!compiler) {
            QMessageBox["warning"]( "Error", "No *make* tool!", "You need *make* tool. Please install it using the System Package Management tools." );
        }
        compiler = installer.execute( "/usr/bin/which", new Array( "ant" ) )[0];
        if (!compiler) {
            QMessageBox["warning"]( "Error", "No *ant* tool!", "You need *ant* tool. Please install it using the System Package Management tools." );
        }
        compiler = installer.execute( "/usr/bin/which", new Array( "java" ) )[0];
        if (!compiler) {
            QMessageBox["warning"]( "Error", "No java compiler!", "You need a java compiler. Please install it using the System Package Management tools." );
        }
        compiler = installer.execute( "/usr/bin/which", new Array( "javac" ) )[0];
        if (!compiler) {
            QMessageBox["warning"]( "Error", "No java compiler!", "You need a java compiler. Please install it using the System Package Management tools." );
        }
    }
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
    //remove sources
    if (installer.componentByName("org.kde.necessitas.android.qt.src") != null
        && installer.componentByName("org.kde.necessitas.android.qt.src").selected)
    {
        installer.componentByName("org.kde.necessitas.android.qt.src").selected = false;
    }
    if (installer.componentByName("org.kde.necessitas.android.qtmobility.src") != null &&
        installer.componentByName("org.kde.necessitas.android.qtmobility.src").selected)
    {
        installer.componentByName("org.kde.necessitas.android.qtmobility.src").selected = false;
    }
    if (installer.componentByName("org.kde.necessitas.android.qtwebkit.src") != null &&
        installer.componentByName("org.kde.necessitas.android.qtwebkit.src").selected)
    {
        installer.componentByName("org.kde.necessitas.android.qtwebkit.src").selected = false;
    }

    // deselect all deprecated packages by default
    if (installer.componentByName("org.kde.necessitas.misc.sdk.android_5") != null &&
        installer.componentByName("org.kde.necessitas.misc.sdk.android_5").selected)
    {
        installer.componentByName("org.kde.necessitas.misc.sdk.android_5").selected = false;
    }
    if (installer.componentByName("org.kde.necessitas.misc.sdk.android_6") != null &&
        installer.componentByName("org.kde.necessitas.misc.sdk.android_6").selected)
    {
        installer.componentByName("org.kde.necessitas.misc.sdk.android_6").selected = false;
    }
    if (installer.componentByName("org.kde.necessitas.misc.sdk.android_7") != null &&
        installer.componentByName("org.kde.necessitas.misc.sdk.android_7").selected)
    {
        installer.componentByName("org.kde.necessitas.misc.sdk.android_7").selected = false;
    }
    if (installer.componentByName("org.kde.necessitas.misc.sdk.android_9") != null &&
        installer.componentByName("org.kde.necessitas.misc.sdk.android_9").selected)
    {
        installer.componentByName("org.kde.necessitas.misc.sdk.android_9").selected = false;
    }
}
