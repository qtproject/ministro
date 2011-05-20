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

package eu.licentia.necessitas.ministro;

import java.io.File;
import java.io.FileInputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;

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
import android.os.IBinder;
import android.os.RemoteException;

public class MinistroService extends Service {
    private static final String MINISTRO_CHECK_UPDATES_KEY="LASTCHECK";
    private static final String MINISTRO_REPOSITORY_KEY="REPOSITORY";
    private static final String MINISTRO_DEFAULT_REPOSITORY="stable";

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

    public static MinistroService instance()
    {
        return m_instance;
    }
    public MinistroService() {
        m_instance = this;
    }

    private int m_actionId=0; // last actions id


    // current downloaded libraries
    private ArrayList<Library> m_downloadedLibraries = new ArrayList<Library>();

    ArrayList<Library> getDownloadedLibraries()
    {
        synchronized (this) {
            return m_downloadedLibraries;
        }
    }

    // current available libraries
    private ArrayList<Library> m_availableLibraries = new ArrayList<Library>();
    ArrayList<Library> getAvailableLibraries()
    {
        synchronized (this) {
            return m_availableLibraries;
        }
    }

    class CheckForUpdates extends AsyncTask<Void, Void, Void>
    {
        @Override
        protected void onPreExecute() {
            if (m_version<MinistroActivity.downloadVersionXmlFile(MinistroService.this, true))
            {
                NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);

                int icon = R.drawable.icon;
                CharSequence tickerText = "New Qt libs found";              // ticker-text
                long when = System.currentTimeMillis();         // notification time
                Context context = getApplicationContext();      // application Context
                CharSequence contentTitle = "Ministro update";  // expanded message title
                CharSequence contentText = "New Qt libs has been found tap to update."; // expanded message text

                Intent notificationIntent = new Intent(MinistroService.this, MinistroActivity.class);
                PendingIntent contentIntent = PendingIntent.getActivity(MinistroService.this, 0, notificationIntent, 0);

                // the next two lines initialize the Notification, using the configurations above
                Notification notification = new Notification(icon, tickerText, when);
                notification.setLatestEventInfo(context, contentTitle, contentText, contentIntent);
                notification.defaults |= Notification.DEFAULT_SOUND;
                notification.defaults |= Notification.DEFAULT_VIBRATE;
                notification.defaults |= Notification.DEFAULT_LIGHTS;
                try{
                    nm.notify(1, notification);
                }catch(Exception e)
                {
                    e.printStackTrace();
                }
            }
        }

        @Override
        protected Void doInBackground(Void... params) {
            // TODO Auto-generated method stub
            return null;
        }
    }


    // this method reload all downloaded libraries
    synchronized ArrayList<Library> refreshLibraries(boolean checkCrc)
    {
        synchronized (this) {
            try {
                m_downloadedLibraries.clear();
                m_availableLibraries.clear();
                if (! (new File(m_versionXmlFile)).exists())
                    return m_downloadedLibraries;
                DocumentBuilderFactory documentFactory = DocumentBuilderFactory.newInstance();
                DocumentBuilder documentBuilder = documentFactory.newDocumentBuilder();
                Document dom = documentBuilder.parse(new FileInputStream(m_versionXmlFile));
                Element root = dom.getDocumentElement();
                m_version = Double.valueOf(root.getAttribute("version"));
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
                        Library lib= Library.getLibrary((Element)node, false);
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
    public void onCreate() {
        m_versionXmlFile = getFilesDir().getAbsolutePath()+"/version.xml";
        m_qtLibsRootPath = getFilesDir().getAbsolutePath()+"/qt/";
        SharedPreferences preferences=getSharedPreferences("Ministro", MODE_PRIVATE);
        long lastCheck = preferences.getLong(MINISTRO_CHECK_UPDATES_KEY,0);
        if (System.currentTimeMillis()-lastCheck>24l*3600*100) // check once/day
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

    public void activityFinished(int id)
    {
        for (int i=0;i<m_actions.size();i++)
        {
            ActionStruct action=m_actions.get(i);
            if (action.id==id)
            {
                try {
                    ArrayList<String> libraries = new ArrayList<String>();
                    Collections.addAll(libraries, action.modules);
                    boolean res = checkModules(libraries, null);
                    String[] libs = new String[libraries.size()];
                    libs = libraries.toArray(libs);
                    if (res)
                        action.callback.libs(libs, m_environmentVariables, m_applicationParams ,0, null);
                    else
                        action.callback.libs(libs, m_environmentVariables, m_applicationParams, 1, "Can't find all modules");
                } catch (RemoteException e) {
                    e.printStackTrace();
                }
                m_actions.remove(i);
                break;
            }
        }
        if (m_actions.size() == 0)
            m_actionId = 0;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent){
        return new IMinistro.Stub() {
            @Override
            public void checkModules(IMinistroCallback callback,
                    String[] modules, String appName, int ministroApiLevel, int necessitasApiLevel) throws RemoteException {
                checkModules(callback, modules, appName, ministroApiLevel, necessitasApiLevel);
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
    final void checkModulesImpl(IMinistroCallback callback,
            String[] modules, String appName, int ministroApiLevel, int necessitasApiLevel) throws RemoteException {

        if (ministroApiLevel<MINISTRO_MIN_API_LEVEL || ministroApiLevel>MINISTRO_MAX_API_LEVEL)
        {
            // panic !!! Ministro service is not compatible, user should upgrade Ministro package
            return;
        }

        // check necessitasApiLevel !!! I'm pretty sure some people will completely ignore my warning
        // and they will deploying apps to Android Market, so let's try to give them a chance.

        // this method is called by the activity client who needs modules.
        ArrayList<String> notFoundModules = new ArrayList<String>();
        ArrayList<String> libraries = new ArrayList<String>();
        Collections.addAll(libraries, modules);
        if (checkModules(libraries, notFoundModules))
        {
            // All modules are available, as such the other application can be notified that it
            // can start without problems.
            String[] libs = new String[libraries.size()];
            libs = libraries.toArray(libs);
            callback.libs(libs, m_environmentVariables, m_applicationParams, 0, null);
        }
        else
        {
            // Starts a retrieval of the modules which are not readily accessible. 
            startRetrieval(callback, modules, notFoundModules, appName);
        }
    }

    private void startRetrieval(IMinistroCallback callback,
		String[] modules, ArrayList<String> notFoundModules, String appName)
        throws RemoteException
    {
        ActionStruct as = new ActionStruct(callback, modules, notFoundModules, appName);
        m_actions.add(as); // if not, lets start an activity to do it.

        Intent intent = new Intent(MinistroService.this, MinistroActivity.class);
        intent.putExtra("id", as.id);
        String[] libs = notFoundModules.toArray(new String[notFoundModules.size()]);
        intent.putExtra("modules", libs);
        intent.putExtra("name", appName);

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try
        {
            MinistroService.this.startActivity(intent);
        }
        catch(Exception e)
        {
            throw (RemoteException) new RemoteException().initCause(e);
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
     * @return
     */
    boolean checkModules(ArrayList<String> libs, ArrayList<String> notFoundModules)
    {
        ArrayList<Module> modules= new ArrayList<Module>();
        boolean res=true;
        for (int i=0;i<libs.size();i++)
            res = res & addModules(libs.get(i), modules, notFoundModules); // don't stop on first error

        // sort all libraries
        Collections.sort(modules, new ModuleCompare());
        libs.clear();
        for (int i=0;i<modules.size();i++)
            libs.add(m_qtLibsRootPath+modules.get(i).path);
        return res;
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
    * @return <code>true</code> if the given module and all its dependencies are readily available.
    */
    private boolean addModules(String module, ArrayList<Module> modules, ArrayList<String> notFoundModules)
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
        for (int i = 0; i< m_downloadedLibraries.size(); i++)
        {
            if (m_downloadedLibraries.get(i).name.equals(module))
            {
                Module m = new Module();
                m.name=m_downloadedLibraries.get(i).name;
                m.path=m_downloadedLibraries.get(i).filePath;
                m.level=m_downloadedLibraries.get(i).level;
                modules.add(m);
                boolean res = true;
                if (m_downloadedLibraries.get(i).depends != null)
                    for (int depIt=0;depIt<m_downloadedLibraries.get(i).depends.length;depIt++)
                        res &= addModules(m_downloadedLibraries.get(i).depends[depIt], modules, notFoundModules);
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
                            addModules(m_availableLibraries.get(i).depends[depIt], modules, notFoundModules);
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
static private class ModuleCompare implements Comparator<Module> {
    @Override
    public int compare(Module a, Module b) {
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