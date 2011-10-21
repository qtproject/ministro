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

package org.kde.necessitas.ministro;

import java.io.File;
import java.io.FileInputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.Set;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.IBinder;
import android.os.RemoteException;
import android.util.Log;

public class MinistroService extends Service
{
    private static final String TAG = "MinistroService";

    private static final String MINISTRO_CHECK_UPDATES_KEY="LASTCHECK";
    private static final String MINISTRO_REPOSITORY_KEY="REPOSITORY";
    private static final String MINISTRO_DEFAULT_REPOSITORY="stable";

    /// Ministro server parameter keys
    private static final String REQUIRED_MODULES_KEY="required.modules";
    private static final String APPLICATION_TITLE_KEY="application.title";
    private static final String QT_PROVIDER_KEY="qt.provider";
    private static final String MINIMUM_MINISTRO_API_KEY="minimum.ministro.api";
    private static final String MINIMUM_QT_VERSION_KEY="minimum.qt.version";
    /// Ministro server parameter keys

    /// loader parameter keys
    private static final String ERROR_CODE_KEY="error.code";
    private static final String ERROR_MESSAGE_KEY="error.message";
    private static final String DEX_PATH_KEY="dex.path";
    private static final String LIB_PATH_KEY="lib.path";
    private static final String LOADER_CLASS_NAME_KEY="loader.class.name";

    private static final String NATIVE_LIBRARIES_KEY="native.libraries";
    private static final String ENVIRONMENT_VARIABLES_KEY="environment.variables";
    private static final String APPLICATION_PARAMETERS_KEY="application.parameters";
    /// loader parameter keys

    /// loader error codes
    private static final int EC_NO_ERROR=0;
    private static final int EC_INCOMPATIBLE=1;
    private static final int EC_NOT_FOUND=2;
    private static final int EC_INVALID_PARAMETERS=3;
    /// loader error codes


    public static String getRepository(Context c)
    {
        SharedPreferences preferences=c.getSharedPreferences("Ministro", MODE_PRIVATE);
        return preferences.getString(MINISTRO_REPOSITORY_KEY,MINISTRO_DEFAULT_REPOSITORY);
    }

    public static void setRepository(Context c, String value)
    {
        SharedPreferences preferences=c.getSharedPreferences("Ministro", MODE_PRIVATE);
        SharedPreferences.Editor editor= preferences.edit();
        editor.putString(MINISTRO_REPOSITORY_KEY,value);
        editor.putLong(MINISTRO_CHECK_UPDATES_KEY,0);
        editor.commit();
    }

    // used to check Ministro Service compatibility
    private static final int MINISTRO_MIN_API_LEVEL=1;
    private static final int MINISTRO_MAX_API_LEVEL=1;

    // MinistroService instance, its used by MinistroActivity to directly access services data (e.g. libraries)
    private static MinistroService m_instance = null;
    private String m_environmentVariables = null;
    private String m_applicationParams = null;
    private String m_loaderClassName = null;
    private String m_pathSeparator = null;
    public static MinistroService instance()
    {
        return m_instance;
    }

    public MinistroService()
    {
        m_instance = this;
    }

    private int m_actionId=0; // last actions id


    // current downloaded libraries
    private ArrayList<Library> m_downloadedLibraries = new ArrayList<Library>();

    ArrayList<Library> getDownloadedLibraries()
    {
        synchronized (this)
        {
            return m_downloadedLibraries;
        }
    }

    // current available libraries
    private ArrayList<Library> m_availableLibraries = new ArrayList<Library>();
    ArrayList<Library> getAvailableLibraries()
    {
        synchronized (this)
        {
            return m_availableLibraries;
        }
    }

    class CheckForUpdates extends AsyncTask<Void, Void, Void>
    {
        @Override
        protected void onPreExecute()
        {
            if (m_version<MinistroActivity.downloadVersionXmlFile(MinistroService.this, true))
            {
                NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

                int icon = R.drawable.icon;
                CharSequence tickerText = getResources().getString(R.string.new_qt_libs_msg);       // ticker-text
                long when = System.currentTimeMillis();                                             // notification time
                Context context = getApplicationContext();                                          // application Context
                CharSequence contentTitle = getResources().getString(R.string.ministro_update_msg); // expanded message title
                CharSequence contentText = getResources().getString(R.string.new_qt_libs_tap_msg);  // expanded message text

                Intent notificationIntent = new Intent(MinistroService.this, MinistroActivity.class);
                PendingIntent contentIntent = PendingIntent.getActivity(MinistroService.this, 0, notificationIntent, 0);

                // the next two lines initialize the Notification, using the configurations above
                Notification notification = new Notification(icon, tickerText, when);
                notification.setLatestEventInfo(context, contentTitle, contentText, contentIntent);
                notification.defaults |= Notification.DEFAULT_SOUND;
                notification.defaults |= Notification.DEFAULT_VIBRATE;
                notification.defaults |= Notification.DEFAULT_LIGHTS;
                try {
                    nm.notify(1, notification);
                } catch(Exception e) {
                    e.printStackTrace();
                }
            }
        }

        @Override
        protected Void doInBackground(Void... params) {
            return null;
        }
    }


    // this method reload all downloaded libraries
    synchronized ArrayList<Library> refreshLibraries(boolean checkCrc)
    {
        synchronized (this)
        {
            try
            {
                m_downloadedLibraries.clear();
                m_availableLibraries.clear();
                if (! (new File(m_versionXmlFile)).exists())
                    return m_downloadedLibraries;
                DocumentBuilderFactory documentFactory = DocumentBuilderFactory.newInstance();
                DocumentBuilder documentBuilder = documentFactory.newDocumentBuilder();
                Document dom = documentBuilder.parse(new FileInputStream(m_versionXmlFile));
                Element root = dom.getDocumentElement();
                m_version = Double.valueOf(root.getAttribute("version"));
                m_loaderClassName=root.getAttribute("loaderClassName");
                m_applicationParams=root.getAttribute("applicationParameters");
                m_applicationParams=m_applicationParams.replaceAll("MINISTRO_PATH", getFilesDir().getAbsolutePath());
                m_environmentVariables=root.getAttribute("environmentVariables");
                m_environmentVariables=m_environmentVariables.replaceAll("MINISTRO_PATH", getFilesDir().getAbsolutePath());
                root.normalize();
                Node node = root.getFirstChild();
                while(node != null)
                {
                    if (node.getNodeType() == Node.ELEMENT_NODE)
                    {
                        Library lib= Library.getLibrary((Element)node, true);
                        File file=new File(m_qtLibsRootPath + lib.filePath);
                        if (file.exists())
                        {
                            if (checkCrc && !Library.checkCRC(file.getAbsolutePath(), lib.sha1))
                                file.delete();
                            else
                                m_downloadedLibraries.add(lib);
                        }
                        m_availableLibraries.add(lib);
                    }
                    // Workaround for an unbelievable bug !!!
                    try {
                        node = node.getNextSibling();
                    } catch (Exception e) {
                        e.printStackTrace();
                        break;
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        return m_downloadedLibraries;
    }

    // version xml file
    private String m_versionXmlFile;
    public String getVersionXmlFile()
    {
        return m_versionXmlFile;
    }

    private String m_qtLibsRootPath;
    public String getQtLibsRootPath()
    {
        return m_qtLibsRootPath;
    }

    private double m_version = -1;
    public double getVersion()
    {
        return m_version;
    }

    // class used to fire an action, this class is used
    // to start an activity when user needs more libraries to start its application
    class ActionStruct
    {
        ActionStruct(IMinistroCallback cb, String[] m, ArrayList<String> notFoundMoules, String appName)
        {
            id=++m_actionId;
            callback = cb;
            modules = m;
        }
        public int id;
        public IMinistroCallback callback;
        public String[] modules;
    }

    // we can have more then one action
    ArrayList<ActionStruct> m_actions = new ArrayList<ActionStruct>();

    @Override
    public void onCreate()
    {
        m_versionXmlFile = getFilesDir().getAbsolutePath()+"/version.xml";
        m_qtLibsRootPath = getFilesDir().getAbsolutePath()+"/qt/";
        m_pathSeparator = System.getProperty("path.separator", ":");
        SharedPreferences preferences=getSharedPreferences("Ministro", MODE_PRIVATE);
        long lastCheck = preferences.getLong(MINISTRO_CHECK_UPDATES_KEY,0);
        if (MinistroActivity.isOnline(this) && System.currentTimeMillis()-lastCheck>24l*3600*100) // check once/day
        {
            refreshLibraries(true);
            SharedPreferences.Editor editor= preferences.edit();
            editor.putLong(MINISTRO_CHECK_UPDATES_KEY,System.currentTimeMillis());
            editor.commit();
            new CheckForUpdates().execute((Void[])null);
        }
        else
            refreshLibraries(false);
        super.onCreate();
    }

    @Override
    public void onDestroy()
    {
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent)
    {
        return new IMinistro.Stub()
        {
            @Override
            public void requestLoader(IMinistroCallback callback, Bundle parameters) throws RemoteException
            {

                checkModulesImpl(callback, parameters);
            }
        };
    }

    /**
    * Implements the {@link IMinistro.Stub#checkModules(IMinistroCallback, String[], String, int, int)}
    * service method.
    *
    * @param callback
    * @param modules
    * @param appName
    * @param ministroApiLevel
    * @param necessitasApiLevel
    * @throws RemoteException
    */
    final void checkModulesImpl(IMinistroCallback callback, Bundle parameters) throws RemoteException
    {
        if (!parameters.containsKey(REQUIRED_MODULES_KEY)
                || !parameters.containsKey(APPLICATION_TITLE_KEY)
                || !parameters.containsKey(MINIMUM_MINISTRO_API_KEY)
                || !parameters.containsKey(MINIMUM_QT_VERSION_KEY))
        {
            Bundle loaderParams = new Bundle();
            loaderParams.putInt(ERROR_CODE_KEY, EC_INVALID_PARAMETERS);
            loaderParams.putString(ERROR_MESSAGE_KEY, getResources().getString(R.string.invalid_parameters));
            try
            {
                callback.loaderReady(loaderParams);
            }
            catch (Exception e) {
                e.printStackTrace();
            }
            Log.e(TAG, "Invalid parameters: " + parameters.toString());
            return;
        }
        int ministroApiLevel = parameters.getInt(MINIMUM_MINISTRO_API_KEY);
        String[] modules = parameters.getStringArray(REQUIRED_MODULES_KEY);
        String appName = parameters.getString(APPLICATION_TITLE_KEY);


        @SuppressWarnings("unused")
        int qtApiLevel = parameters.getInt(MINIMUM_QT_VERSION_KEY); // TODO check if current QT version is compatible with required version
        @SuppressWarnings("unused")
        String qtProvider="necessitas";
        if (parameters.containsKey(QT_PROVIDER_KEY))
            qtProvider=parameters.getString(QT_PROVIDER_KEY); // TODO add the possibility to have more than one provider

        if (ministroApiLevel<MINISTRO_MIN_API_LEVEL || ministroApiLevel>MINISTRO_MAX_API_LEVEL)
        {
            // panic !!! Ministro service is not compatible, user should upgrade Ministro package
            Bundle loaderParams = new Bundle();
            loaderParams.putInt(ERROR_CODE_KEY, EC_INCOMPATIBLE);
            loaderParams.putString(ERROR_MESSAGE_KEY, getResources().getString(R.string.incompatible_ministo_api));
            try
            {
                callback.loaderReady(loaderParams);
            }
            catch (Exception e) {
                e.printStackTrace();
            }
            Log.e(TAG, "Ministro cannot satisfy API version: " + ministroApiLevel);
            return;
        }

        // check necessitasApiLevel !!! I'm pretty sure some people will completely ignore my warning
        // and they will deploying apps to Android Market, so let's try to give them a chance.

        // this method is called by the activity client who needs modules.
        ArrayList<String> notFoundModules = new ArrayList<String>();
        Bundle loaderParams = checkModules(modules, notFoundModules);
        if (loaderParams.containsKey(ERROR_CODE_KEY) && EC_NO_ERROR == loaderParams.getInt(ERROR_CODE_KEY))
        {
            try
            {
                callback.loaderReady(loaderParams);
            }
            catch (Exception e)
            {
                e.printStackTrace();
            }
        }
        else
        {
            // Starts a retrieval of the modules which are not readily accessible.
            startRetrieval(callback, modules, notFoundModules, appName);
        }
    }

    /**
    * Creates and sets up a {@link MinistroActivity} to retrieve the modules specified in the
    * <code>notFoundModules</code> argument.
    *
    * @param callback
    * @param modules
    * @param notFoundModules
    * @param appName
    * @throws RemoteException
    */
    private void startRetrieval(IMinistroCallback callback, String[] modules
                                , ArrayList<String> notFoundModules, String appName) throws RemoteException
    {
        ActionStruct as = new ActionStruct(callback, modules, notFoundModules, appName);
        m_actions.add(as); // if not, lets start an activity to do it.

        Intent intent = new Intent(MinistroService.this, MinistroActivity.class);
        intent.putExtra("id", as.id);
        String[] libs = notFoundModules.toArray(new String[notFoundModules.size()]);
        intent.putExtra("modules", libs);
        intent.putExtra("name", appName);

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        boolean failed = false;
        try
        {
            MinistroService.this.startActivity(intent);
        }
        catch(Exception e)
        {
            failed = true;
            throw (RemoteException) new RemoteException().initCause(e);
        }
        finally
        {
            // Removes the dead Activity from our list as it will never finish by itself.
            if (failed)
                m_actions.remove(as);
        }
    }

    /**
    * Called by a finished {@link MinistroActivity} in order to let
    * the service notify the application which caused the activity about
    * the result of the retrieval.
    *
    * @param id
    */
    void retrievalFinished(int id)
    {
        for (int i=0;i<m_actions.size();i++)
        {
            ActionStruct action=m_actions.get(i);
            if (action.id==id)
            {
                postRetrieval(action.callback, action.modules);
                m_actions.remove(i);
                break;
            }
        }
        if (m_actions.size() == 0)
            m_actionId = 0;
    }

    /**
    * Helper method for the last step of the retrieval process.
    *
    * <p>Checks the availability of the requested modules and informs
    * the requesting application about it via the {@link IMinistroCallback}
    * instance.</p>
    *
    * @param callback
    * @param modules
    */
    private void postRetrieval(IMinistroCallback callback, String[] modules)
    {
        // Does a final check whether the libraries are accessible (without caring for
        // the non-accessible ones).
        try
        {
            callback.loaderReady(checkModules(modules, null));
        }
        catch (Exception e)
        {
            e.printStackTrace();
        }
    }

    /**
    * Checks whether a given list of libraries are readily accessible (e.g. usable by a program).
    *
    * <p>If the <code>notFoundModules</code> argument is given, the method fills the list with
    * libraries that need to be retrieved first.</p>
    *
    * @param libs
    * @param notFoundModules
    * @return true if all modules are available
    */
    Bundle checkModules(String[] modules, ArrayList<String> notFoundModules)
    {
        Bundle params = new Bundle();
        boolean res=true;
        ArrayList<Module> libs= new ArrayList<Module>();
        Set<String> jars= new HashSet<String>();
        for (String module: modules)
            res = res & addModules(module, libs, notFoundModules, jars); // don't stop on first error

        ArrayList<String> librariesArray = new ArrayList<String>();
        // sort all libraries
        Collections.sort(libs, new ModuleCompare());
        for (Module lib: libs)
            librariesArray.add(m_qtLibsRootPath+lib.path);
        params.putStringArrayList(NATIVE_LIBRARIES_KEY, librariesArray);

        ArrayList<String> jarsArray = new ArrayList<String>();
        for (String jar: jars)
            jarsArray.add(m_qtLibsRootPath+jar);
        params.putString(DEX_PATH_KEY, Library.join(jarsArray, m_pathSeparator));

        params.putString(LOADER_CLASS_NAME_KEY, m_loaderClassName);
        params.putString(LIB_PATH_KEY, m_qtLibsRootPath);
        params.putString(ENVIRONMENT_VARIABLES_KEY, m_environmentVariables);
        params.putString(APPLICATION_PARAMETERS_KEY, m_applicationParams);
        params.putInt(ERROR_CODE_KEY, res?EC_NO_ERROR:EC_NOT_FOUND);
        if (!res)
            params.putString(ERROR_MESSAGE_KEY, getResources().getString(R.string.dependencies_error));
        return params;
    }

/**
    * Helper method for the module resolution mechanism. It deals with an individual module's
    * resolution request.
    *
    * <p>The method checks whether a given <em>single</em> <code>module</code> is already
    * accessible or needs to be retrieved first. In the latter case the method returns
    * <code>false</code>.</p>
    *
    * <p>The method traverses a <code>module<code>'s dependencies automatically.</p>
    *
    * <p>In order to find out whether a <code>module</code> is accessible the method consults
    * the list of downloaded libraries. If found, an entry to the <code>modules</code> list is
    * added.</p>
    *
    * <p>In case the <code>module</ocde> is not immediately accessible and the <code>notFoundModules</code>
    * argument exists, a list of available libraries is consulted to fill a list of modules which
    * yet need to be retrieved.</p>
    *
    * @param module
    * @param modules
    * @param notFoundModules
    * @param jars
    * @return <code>true</code> if the given module and all its dependencies are readily available.
    */
    private boolean addModules(String module, ArrayList<Module> modules
                            , ArrayList<String> notFoundModules, Set<String> jars)
    {
        // Module argument is not supposed to be null at this point.
        if (modules == null)
            return false; // we are in deep shit if this happens

        // Short-cut: If the module is already in our list of previously found modules then we do not
        // need to consult the list of downloaded modules.
        for (int i=0;i<modules.size();i++)
        {
            if (modules.get(i).name.equals(module))
                return true;
        }

        // Consult the list of downloaded modules. If a matching entry is found, it is added to the
        // list of readily accessible modules and its dependencies are checked via a recursive call.
        for (Library library:m_downloadedLibraries)
        {
            if (library.name.equals(module))
            {
                Module m = new Module();
                m.name=library.name;
                m.path=library.filePath;
                m.level=library.level;
                if (library.needs != null)
                    for(NeedsStruct needed: library.needs)
                        if (needed.type != null && needed.type.equals("jar"))
                            jars.add(needed.filePath);
                modules.add(m);

                boolean res = true;
                if (library.depends != null)
                    for (String depend: library.depends)
                        res &= addModules(depend, modules, notFoundModules, jars);

                if (library.replaces != null)
                    for (String replaceLibrary: library.replaces)
                        for (int mIt=0; mIt<modules.size();mIt++)
                            if (replaceLibrary.equals(modules.get(mIt).name))
                                modules.remove(mIt--);

                return res;
            }
        }

        // Requested module is not readily accessible.
        if (notFoundModules != null)
        {
            // Checks list of modules which are known to not be readily accessible and returns early to
            // prevent double entries.
            for (int i=0;i<notFoundModules.size();i++)
            {
                if (notFoundModules.get(i).equals(module))
                    return false;
            }

            // Deal with not yet readily accessible module's dependencies.
            notFoundModules.add(module);
            for (int i = 0; i< m_availableLibraries.size(); i++)
            {
                if (m_availableLibraries.get(i).name.equals(module))
                {
                    if (m_availableLibraries.get(i).depends != null)
                        for (int depIt=0;depIt<m_availableLibraries.get(i).depends.length;depIt++)
                            addModules(m_availableLibraries.get(i).depends[depIt], modules, notFoundModules, jars);
                    break;
                }
            }
        }
        return false;
    }

    /** Sorter for libraries.
    *
    * Hence the order in which the libraries have to be loaded is important, it is neccessary
    * to sort them.
    */
    static private class ModuleCompare implements Comparator<Module>
    {
        @Override
        public int compare(Module a, Module b)
        {
            return a.level-b.level;
        }
    }

    /** Helper class which allows manipulating libraries.
    *
    * It is similar to the {@link Library} class but has fewer fields.
    */
    static private class Module
    {
        String path;
        String name;
        int level;
    }
}
