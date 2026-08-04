package com.danish.m2m;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

public class CallForegroundService extends Service {
    private static final String CHANNEL_ID = "m2m_ongoing_calls_v1";
    private static final int NOTIFICATION_ID = 900100;
    private static final String TAG = "M2MCallService";

    // NOTE: this service deliberately does NOT touch AudioManager (mode/focus).
    // The Amazon Chime SDK is the SOLE owner of the call audio session  it sets
    // MODE_IN_COMMUNICATION, requests audio focus, owns routing, and runs the
    // voice-processing unit that does acoustic echo cancellation. When this
    // service also set the mode/focus (and reset the mode on its racy stop), it
    // disrupted Chime's AEC unit and the user heard their own voice echoed.
    // Routing (speaker/earpiece) is handled by the plugin via chooseAudioDevice.
    // This service's only job is the ongoing-call notification + the microphone
    // FGS type that legally keeps the mic alive in the background.

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        createNotificationChannel();

        if (!hasRecordAudioPermission()) {
            Log.w(TAG, "Cannot start call foreground service without RECORD_AUDIO permission");
            stopSelf();
            return START_NOT_STICKY;
        }

        try {
            startForegroundCompat(buildNotification());
        } catch (SecurityException exception) {
            Log.e(TAG, "Call foreground service security failure", exception);
            stopSelf();
            return START_NOT_STICKY;
        } catch (RuntimeException exception) {
            Log.e(TAG, "Call foreground service start failed", exception);
            stopSelf();
            return START_NOT_STICKY;
        }
        return START_STICKY;
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private Notification buildNotification() {
        Intent launchIntent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launchIntent == null) {
            launchIntent = new Intent(this, MainActivity.class);
        }
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                : PendingIntent.FLAG_UPDATE_CURRENT
        );

        return new NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(getApplicationInfo().icon)
            .setContentTitle("M2M call in progress")
            .setContentText("Tap to return to your call")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .build();
    }

    private void startForegroundCompat(Notification notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            );
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
    }

    private boolean hasRecordAudioPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true;
        return checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;

        NotificationChannel channel = new NotificationChannel(
            CHANNEL_ID,
            "Ongoing calls",
            NotificationManager.IMPORTANCE_LOW
        );
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            manager.createNotificationChannel(channel);
        }
    }
}
