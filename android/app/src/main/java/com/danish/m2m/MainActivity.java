package com.danish.m2m;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.danish.m2m/ringtone";
    private Ringtone ringtone;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("startIncomingCallRingtone")) {
                    startRingtone();
                    result.success(null);
                } else if (call.method.equals("stopIncomingCallRingtone")) {
                    stopRingtone();
                    result.success(null);
                } else {
                    result.notImplemented();
                }
            });
    }

    private void startRingtone() {
        try {
            stopRingtone();
            Uri defaultRingtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
            ringtone = RingtoneManager.getRingtone(getApplicationContext(), defaultRingtoneUri);
            if (ringtone != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    AudioAttributes audioAttributes = new AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build();
                    ringtone.setAudioAttributes(audioAttributes);
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    ringtone.setLooping(true);
                }
                ringtone.play();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void stopRingtone() {
        try {
            if (ringtone != null && ringtone.isPlaying()) {
                ringtone.stop();
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            ringtone = null;
        }
    }

    @Override
    protected void onDestroy() {
        stopRingtone();
        super.onDestroy();
    }
}
