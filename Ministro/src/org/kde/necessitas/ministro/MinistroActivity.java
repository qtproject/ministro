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

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLConnection;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Enumeration;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;

import org.apache.http.client.ClientProtocolException;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.NotificationManager;
import android.app.ProgressDialog;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.IBinder;
import android.provider.Settings;

public class MinistroActivity extends Activity
{
    public native static int nativeChmode(String filepath, int mode);
    private static final String DOMAIN_NAME="http://files.kde.org/necessitas/ministro/necessitas/";

    private String[] m_modules;
    private int m_id=-1;
    private String m_qtLibsRootPath;

    private void checkNetworkAndDownload(final boolean update)
    {
        if (isOnline(this))
            new CheckLibraries().execute(update);
        else
        {
            AlertDialog.Builder builder = new AlertDialog.Builder(MinistroActivity.this);
            builder.setMessage(getResources().getString(R.string.ministro_network_access_msg));
            builder.setCancelable(true);
            builder.setNeutralButton(getResources().getString(R.string.settings_msg), new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int id) {
                        final ProgressDialog m_dialog = ProgressDialog.show(MinistroActivity.this, null, getResources().getString(R.string.wait_for_network_connection_msg), true, true, new DialogInterface.OnCancelListener() {
                            @Override
                            public void onCancel(DialogInterface dialog)
                            {
                                finishMe();
                            }
                        });
                        getApplication().registerReceiver(new BroadcastReceiver() {
                            @Override
                            public void onReceive(Context context, Intent intent)
                            {
                                if (isOnline(MinistroActivity.this))
                                {
                                    getApplication().unregisterReceiver(this);
                                    runOnUiThread(new Runnable() {
                                        @Override
                                        public void run()
                                        {
                                            m_dialog.dismiss();
                                            new CheckLibraries().execute(update);
                                        }
                                    });
                                }
                            }
                        }, new IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION));
                        startActivity(new Intent(Settings.ACTION_WIRELESS_SETTINGS));
                        dialog.dismiss();
                    }
                });
            builder.setNegativeButton(android.R.string.cancel, new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int id)
                    {
                            dialog.cancel();
                    }
                });
            builder.setOnCancelListener(new DialogInterface.OnCancelListener() {
                @Override
                public void onCancel(DialogInterface dialog)
                {
                    finishMe();
                }
            });
            AlertDialog alert = builder.create();
            alert.show();
        }
    }

    private ServiceConnection m_ministroConnection=new ServiceConnection()
    {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service)
        {
            if (getIntent().hasExtra("id") && getIntent().hasExtra("modules"))
            {
                m_id=getIntent().getExtras().getInt("id");
                m_modules=getIntent().getExtras().getStringArray("modules");
                AlertDialog.Builder builder = new AlertDialog.Builder(MinistroActivity.this);
                builder.setMessage(getResources().getString(R.string.download_app_libs_msg,
                        getIntent().getExtras().getString("name")))
                    .setCancelable(false)
                    .setPositiveButton(android.R.string.yes, new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dialog, int id) {
                            dialog.dismiss();
                            checkNetworkAndDownload(false);
                        }
                    })
                    .setNegativeButton(android.R.string.no, new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dialog, int id) {
                                dialog.cancel();
                                finishMe();
                        }
                    });
                AlertDialog alert = builder.create();
                alert.show();
            }
            else
                checkNetworkAndDownload(true);
        }

        @Override
        public void onServiceDisconnected(ComponentName name)
        {
            m_ministroConnection = null;
        }
    };

    void finishMe()
    {
        if (-1 != m_id && null != MinistroService.instance())
            MinistroService.instance().retrievalFinished(m_id);
        else
        {
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            nm.cancelAll();
        }
        finish();
    }

    private static URL getVersionUrl(Context c) throws MalformedURLException
    {
        return new URL(DOMAIN_NAME+MinistroService.getRepository(c)+"/android/"+android.os.Build.CPU_ABI+"/android-"+android.os.Build.VERSION.SDK_INT+"/versions.xml");
    }

    private static URL getLibsXmlUrl(Context c, String version) throws MalformedURLException
    {
        return new URL(DOMAIN_NAME+MinistroService.getRepository(c)+"/android/"+android.os.Build.CPU_ABI+"/android-"+android.os.Build.VERSION.SDK_INT+"/libs-"+version+".xml");
    }

    public static boolean isOnline(Context c)
    {
        ConnectivityManager cm = (ConnectivityManager) c.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo netInfo = cm.getActiveNetworkInfo();
        if (netInfo != null && netInfo.isConnectedOrConnecting())
            return true;
        return false;
    }

    private static String deviceSupportedFeatures(String supportedFeatures)
    {
        if (null==supportedFeatures)
            return "";
        String [] serverFeaturesList=supportedFeatures.trim().split(" ");
        String [] deviceFeaturesList=null;
        try {
            FileInputStream fstream = new FileInputStream("/proc/cpuinfo");
            DataInputStream in = new DataInputStream(fstream);
            BufferedReader br = new BufferedReader(new InputStreamReader(in));
            String strLine;
            while ((strLine = br.readLine()) != null)
            {
                if (strLine.startsWith("Features"))
                {
                    deviceFeaturesList=strLine.substring(strLine.indexOf(":")+1).trim().split(" ");
                    break;
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
            return "";
        }

        String features="";
        for(String sfeature: serverFeaturesList)
            for (String dfeature: deviceFeaturesList)
                if (sfeature.equals(dfeature))
                    features+="_"+dfeature;

        return features;
    }


    public static double downloadVersionXmlFile(Context c, boolean checkOnly)
    {
        if (!isOnline(c))
            return-1;
        try
        {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            DocumentBuilder builder = factory.newDocumentBuilder();
            Document dom = null;
            Element root = null;
            URLConnection connection = getVersionUrl(c).openConnection();
            dom = builder.parse(connection.getInputStream());
            root = dom.getDocumentElement();
            root.normalize();
            double version = Double.valueOf(root.getAttribute("latest"));
            if ( MinistroService.instance().getVersion() >= version )
                return MinistroService.instance().getVersion();

            if (checkOnly)
                return version;
            String supportedFeatures=null;
            if (root.hasAttribute("features"))
                supportedFeatures=root.getAttribute("features");
            connection = getLibsXmlUrl(c, version+deviceSupportedFeatures(supportedFeatures)).openConnection();
            File file= new File(MinistroService.instance().getVersionXmlFile());
            file.delete();
            FileOutputStream outstream = new FileOutputStream(MinistroService.instance().getVersionXmlFile());
            InputStream instream = connection.getInputStream();
            byte[] tmp = new byte[2048];
            int downloaded;
            while ((downloaded = instream.read(tmp)) != -1)
                outstream.write(tmp, 0, downloaded);

            outstream.close();
            MinistroService.instance().refreshLibraries(false);
            return version;
        } catch (ClientProtocolException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        } catch (ParserConfigurationException e) {
            e.printStackTrace();
        } catch (IllegalStateException e) {
            e.printStackTrace();
        } catch (Exception e) {
            e.printStackTrace();
        }
        return -1;
    }

    private class DownloadManager extends AsyncTask<Library, Integer, Long>
    {
        private ProgressDialog m_dialog = null;
        private String m_status = getResources().getString(R.string.start_downloading_msg);
        private int m_totalSize=0, m_totalProgressSize=0;

        @Override
        protected void onPreExecute()
        {
            m_dialog = new ProgressDialog(MinistroActivity.this);
            m_dialog.setProgressStyle(ProgressDialog.STYLE_HORIZONTAL);
            m_dialog.setTitle(getResources().getString(R.string.downloading_qt_libraries_msg));
            m_dialog.setMessage(m_status);
            m_dialog.setCancelable(true);
            m_dialog.setOnCancelListener(new DialogInterface.OnCancelListener(){
                        @Override
                        public void onCancel(DialogInterface dialog)
                        {
                            DownloadManager.this.cancel(false);
                            finishMe();
                        }
            });
            m_dialog.show();
            super.onPreExecute();
        }

        private boolean DownloadItem(String url, String file, long size, String fileSha1) throws NoSuchAlgorithmException, MalformedURLException, IOException
        {
            MessageDigest digester = MessageDigest.getInstance("SHA-1");
            URLConnection connection = new URL(url).openConnection();
            Library.mkdirParents(m_qtLibsRootPath, file, 1);
            String filePath=m_qtLibsRootPath+file;
            int progressSize=0;
            try
            {
                FileOutputStream outstream = new FileOutputStream(filePath);
                InputStream instream = connection.getInputStream();
                int downloaded;
                byte[] tmp = new byte[2048];
                int oldProgress=-1;
                while ((downloaded = instream.read(tmp)) != -1)
                {
                    if (isCancelled())
                        break;
                    progressSize+=downloaded;
                    m_totalProgressSize+=downloaded;
                    digester.update(tmp, 0, downloaded);
                    outstream.write(tmp, 0, downloaded);
                    int progress=(int)(progressSize*100/size);
                    if (progress!=oldProgress)
                    {
                        publishProgress(progress
                                , m_totalProgressSize);
                        oldProgress = progress;
                    }
                }
                String sha1 =  Library.convertToHex(digester.digest());
                if (sha1.equalsIgnoreCase(fileSha1))
                {
                    outstream.close();
                    nativeChmode(filePath, 0644);
                    return true;
                }
                outstream.close();
                File f = new File(filePath);
                f.delete();
            } catch (Exception e) {
                e.printStackTrace();
                File f = new File(filePath);
                f.delete();
            }
            m_totalProgressSize-=progressSize;
            return false;
        }

        @Override
        protected Long doInBackground(Library... params)
        {
            try
            {
                for (int i=0;i<params.length;i++)
                {
                    m_totalSize+=params[i].size;
                    if (null != params[i].needs)
                        for (int j=0;j<params[i].needs.length;j++)
                            m_totalSize+=params[i].needs[j].size;
                }

                m_dialog.setMax(m_totalSize);
                int lastId=-1;
                for (int i=0;i<params.length;i++)
                {
                    if (isCancelled())
                        break;
                    synchronized (m_status)
                    {
                        m_status=params[i].name+" ";
                    }
                    publishProgress(0, m_totalProgressSize);
                    if (!DownloadItem(params[i].url, params[i].filePath, params[i].size, params[i].sha1))
                    {
                        // sometimes for some reasons which I don't understand, Ministro receives corrupt data, so let's give it another chance.
                        if (i == lastId)
                            break;
                        lastId=i;
                        --i;
                        continue;
                    }

                    lastId=-1;
                    if (null != params[i].needs)
                        for (int j=0;j<params[i].needs.length;j++)
                        {
                            synchronized (m_status)
                            {
                                m_status=params[i].needs[j].name+" ";
                            }
                            publishProgress(0, m_totalProgressSize);
                            if (!DownloadItem(params[i].needs[j].url, params[i].needs[j].filePath, params[i].needs[j].size, params[i].needs[j].sha1))
                            {
                                // sometimes for some reasons which I don't understand, Ministro receives corrupt data, so let's give it another chance.
                                if (j == lastId)
                                    break;
                                lastId=j;
                                --j;
                                continue;
                            }
                            lastId=-1;
                        }
                }
            } catch (NoSuchAlgorithmException e) {
                e.printStackTrace();
            } catch (MalformedURLException e) {
                e.printStackTrace();
            } catch (IOException e) {
                e.printStackTrace();
            } catch (Exception e) {
                e.printStackTrace();
            }
            return null;
        }

        @Override
        protected void onProgressUpdate(Integer... values)
        {
            synchronized (m_status)
            {
                m_dialog.setMessage(m_status+values[0]+"%");
                m_dialog.setProgress(values[1]);
            }
            super.onProgressUpdate(values);
        }

        @Override
        protected void onPostExecute(Long result)
        {
            super.onPostExecute(result);
            if (m_dialog != null)
            {
                m_dialog.dismiss();
                m_dialog = null;
            }
            MinistroService.instance().refreshLibraries(false);
            finishMe();
        }
    }

    private class CheckLibraries extends AsyncTask<Boolean, Void, Double>
    {
        private ProgressDialog dialog = null;
        private ArrayList<Library> newLibs = new ArrayList<Library>();
        private String m_message;
        @Override
        protected void onPreExecute()
        {
            runOnUiThread(new Runnable()
            {
                @Override
                public void run()
                {
                    dialog = ProgressDialog.show(MinistroActivity.this, null,
                            getResources().getString(R.string.checking_libraries_msg), true, true);
                }
            });
            super.onPreExecute();
        }

        @Override
        protected Double doInBackground(Boolean... update)
        {
            double version=0.0;
            try
            {
                DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
                DocumentBuilder builder = factory.newDocumentBuilder();
                Document dom = null;
                Element root = null;
                double oldVersion=MinistroService.instance().getVersion();
                if (update[0] || MinistroService.instance().getVersion()<0)
                    version = downloadVersionXmlFile(MinistroActivity.this, false);
                else
                    version = MinistroService.instance().getVersion();

                ArrayList<Library> libraries;
                if (update[0])
                {
                    if (oldVersion!=version)
                        libraries = MinistroService.instance().getDownloadedLibraries();
                    else
                        return version;
                }
                else
                    libraries = MinistroService.instance().getAvailableLibraries();

                ArrayList<String> notFoundModules = new ArrayList<String>();
                if (m_modules!=null)
                    MinistroService.instance().checkModules(m_modules, notFoundModules);

                dom = builder.parse(new FileInputStream(MinistroService.instance().getVersionXmlFile()));

                factory = DocumentBuilderFactory.newInstance();
                builder = factory.newDocumentBuilder();
                root = dom.getDocumentElement();
                root.normalize();

                // extract device root certificates
                SharedPreferences preferences=getSharedPreferences("Ministro", MODE_PRIVATE);
                if (!preferences.getString("CODENAME", "").equals(android.os.Build.VERSION.CODENAME) ||
                        !preferences.getString("INCREMENTAL", "").equals(android.os.Build.VERSION.INCREMENTAL) ||
                        !preferences.getString("RELEASE", "").equals(android.os.Build.VERSION.RELEASE))
                {
                    m_message = getResources().getString(R.string.extracting_SSL_msg);
                    publishProgress((Void[])null);
                    String environmentVariables=root.getAttribute("environmentVariables");
                    environmentVariables=environmentVariables.replaceAll("MINISTRO_PATH", "");
                    String environmentVariablesList[]=environmentVariables.split("\t");
                    for (int i=0;i<environmentVariablesList.length;i++)
                    {
                        String environmentVariable[]=environmentVariablesList[i].split("=");
                        if (environmentVariable[0].equals("MINISTRO_SSL_CERTS_PATH"))
                        {
                            String path=Library.mkdirParents(getFilesDir().getAbsolutePath(),environmentVariable[1], 0);
                            Library.removeAllFiles(path);
                            try
                            {
                                KeyStore ks= KeyStore.getInstance(KeyStore.getDefaultType());
                                FileInputStream instream = new FileInputStream(new File("/system/etc/security/cacerts.bks"));
                                ks.load(instream, null);
                                for (Enumeration<String> aliases = ks.aliases(); aliases.hasMoreElements(); )
                                {
                                    String aName = aliases.nextElement();
                                    try
                                    {
                                        X509Certificate cert=(X509Certificate) ks.getCertificate(aName);
                                        if (null==cert)
                                            continue;
                                        String filePath=path+"/"+cert.getType()+"_"+cert.hashCode()+".der";
                                        FileOutputStream outstream = new FileOutputStream(new File(filePath));
                                        byte buff[]=cert.getEncoded();
                                        outstream.write(buff, 0, buff.length);
                                        outstream.close();
                                        nativeChmode(filePath, 0644);
                                    } catch(KeyStoreException e) {
                                        e.printStackTrace();
                                    } catch(Exception e) {
                                        e.printStackTrace();
                                    }
                                }
                            } catch (KeyStoreException e) {
                                e.printStackTrace();
                            } catch (IOException e) {
                                e.printStackTrace();
                            } catch (NoSuchAlgorithmException e) {
                                e.printStackTrace();
                            } catch (CertificateException e) {
                                e.printStackTrace();
                            }
                            SharedPreferences.Editor editor= preferences.edit();
                            editor.putString("CODENAME",android.os.Build.VERSION.CODENAME);
                            editor.putString("INCREMENTAL", android.os.Build.VERSION.INCREMENTAL);
                            editor.putString("RELEASE", android.os.Build.VERSION.RELEASE);
                            editor.commit();
                            break;
                        }
                    }
                }

                Node node = root.getFirstChild();
                while(node != null)
                {
                    if (node.getNodeType() == Node.ELEMENT_NODE)
                    {
                        Library lib= Library.getLibrary((Element)node, true);
                        if (update[0])
                        { // check for updates
                            for (int j=0;j<libraries.size();j++)
                                if (libraries.get(j).name.equals(lib.name))
                                {
                                    newLibs.add(lib);
                                    break;
                                }
                        }
                        else
                        {// download missing libraries
                            for(String module : notFoundModules)
                                if (module.equals(lib.name))
                                {
                                    newLibs.add(lib);
                                    break;
                                }
                        }
                    }

                    // Workaround for an unbelievable bug !!!
                    try {
                        node = node.getNextSibling();
                    } catch (Exception e) {
                        e.printStackTrace();
                        break;
                    }
                }
                return version;
            } catch (ClientProtocolException e) {
                e.printStackTrace();
            } catch (IOException e) {
                e.printStackTrace();
            } catch (ParserConfigurationException e) {
                e.printStackTrace();
            } catch (IllegalStateException e) {
                e.printStackTrace();
            } catch (Exception e) {
                e.printStackTrace();
            }
            return -1.;
        }

        @Override
        protected void onProgressUpdate(Void... nothing)
        {
            dialog.setMessage(m_message);
            super.onProgressUpdate(nothing);
        }

        @Override
        protected void onPostExecute(Double result)
        {
            if (null != dialog)
            {
                dialog.dismiss();
                dialog = null;
            }
            if (newLibs.size()>0 && result>0)
            {
                Library[] libs = new Library[newLibs.size()];
                libs = newLibs.toArray(libs);
                new DownloadManager().execute(libs);
            }
            else
                finishMe();
            super.onPostExecute(result);
        }
    }

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);
        m_qtLibsRootPath = getFilesDir().getAbsolutePath()+"/qt/";
        File dir=new File(m_qtLibsRootPath);
        dir.mkdirs();
        nativeChmode(m_qtLibsRootPath, 0755);
        bindService(new Intent("org.kde.necessitas.ministro.IMinistro"), m_ministroConnection, Context.BIND_AUTO_CREATE);
    }

    @Override
    protected void onDestroy()
    {
        super.onDestroy();
        unbindService(m_ministroConnection);
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig)
    {
        //Avoid activity from being destroyed/created
        super.onConfigurationChanged(newConfig);
    }

    static
    {
        System.loadLibrary("chmode");
    }
}
