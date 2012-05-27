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

import android.app.Activity;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemSelectedListener;
import android.widget.ArrayAdapter;
import android.widget.Spinner;
import android.widget.Toast;

public class MinistroConfigActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        setContentView(R.layout.repoconfig);
        Spinner repositoriesSpinner = (Spinner) findViewById(R.id.repositories);
        ArrayAdapter<CharSequence> repositories = ArrayAdapter.createFromResource(
                this, R.array.repositories, android.R.layout.simple_spinner_item);
        repositories.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        repositoriesSpinner.setAdapter(repositories);
        repositoriesSpinner.setSelection(repositories.getPosition(MinistroService.getRepository(this)));
        repositoriesSpinner.setOnItemSelectedListener(new OnItemSelectedListener(){
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int pos,
                    long id) {
                Toast.makeText(parent.getContext()
                        , getResources().getString(R.string.ministro_repository_msg
                        , parent.getItemAtPosition(pos).toString()), Toast.LENGTH_LONG).show();
                MinistroService.setRepository(MinistroConfigActivity.this, parent.getItemAtPosition(pos).toString());
            }
            @Override
            public void onNothingSelected(AdapterView<?> arg0) {
            }
        });

        Spinner checkFrequencySpinner = (Spinner) findViewById(R.id.check_frequency);
        ArrayAdapter<CharSequence> checkFrequency = ArrayAdapter.createFromResource(
                this, R.array.check_frequency, android.R.layout.simple_spinner_item);
        checkFrequency.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        checkFrequencySpinner.setAdapter(checkFrequency);
        checkFrequencySpinner.setSelection(checkFrequency.getPosition(MinistroService.getCheckFrequency(this).toString()));
        checkFrequencySpinner.setOnItemSelectedListener(new OnItemSelectedListener(){
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int pos,
                    long id) {
                Toast.makeText(parent.getContext()
                        , getResources().getString(R.string.ministro_repository_msg
                        , parent.getItemAtPosition(pos).toString()), Toast.LENGTH_LONG).show();
                MinistroService.setCheckFrequency(MinistroConfigActivity.this, Long.parseLong(parent.getItemAtPosition(pos).toString()));
            }

            @Override
            public void onNothingSelected(AdapterView<?> arg0) {
            }
        });
        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onDestroy() {
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        int icon = R.drawable.icon;
        CharSequence tickerText = getResources().getString(R.string.ministro_repository_changed_msg); // ticker-text
        long when = System.currentTimeMillis();         // notification time
        Context context = getApplicationContext();      // application Context
        CharSequence contentTitle = getResources().getString(R.string.ministro_update_msg);  // expanded message title
        CharSequence contentText = getResources().getString(R.string.ministro_repository_changed_tap_msg); // expanded message text

        Intent notificationIntent = new Intent(this, MinistroActivity.class);
        PendingIntent contentIntent = PendingIntent.getActivity(this, 0, notificationIntent, 0);

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
        super.onDestroy();
    }
}