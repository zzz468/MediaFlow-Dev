package com.mediaflow.research.v040.lifecycle;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import java.io.File;
import org.json.JSONObject;

// UI trigger only. Operation ownership lives in CoordinatorService, never in an Activity instance.
public final class CoordinatorActivity extends Activity {
    static int dryCreateCount;
    boolean bound,receiverRegistered;
    final android.content.ServiceConnection connection=new android.content.ServiceConnection(){public void onServiceConnected(android.content.ComponentName n,android.os.IBinder b){}public void onServiceDisconnected(android.content.ComponentName n){}};
    final android.content.BroadcastReceiver finished=new android.content.BroadcastReceiver(){public void onReceive(android.content.Context c,Intent i){finish();}};
    @Override public void onCreate(Bundle saved){
        super.onCreate(saved);
        android.util.Log.i("MF040Activity","onCreate saved="+(saved!=null)+" instance="+System.identityHashCode(this));
        if(getIntent().getBooleanExtra("diagnoseLegacy",false)){
            // Reproduce legacy unconditional onCreate allocation in memory only: no Worker/profile/marker.
            dryCreateCount++;
            if(saved==null){recreate();return;}
            try{JSONObject r=new JSONObject();r.put("dryRun",true);r.put("externalTriggerCount",1);r.put("onCreateAllocationCount",dryCreateCount);r.put("restoredInstance",true);OperationFiles.write(new File(getFilesDir(),"legacy-reentry-diagnosis.json"),r);}catch(Exception e){throw new IllegalStateException(e);}
            finish();return;
        }
        androidx.core.content.ContextCompat.registerReceiver(this,finished,new android.content.IntentFilter("mf040.FINAL"),androidx.core.content.ContextCompat.RECEIVER_NOT_EXPORTED);receiverRegistered=true;
        if(saved!=null){android.util.Log.i("MF040Activity","restoredAttachOnly_noNewTrigger");bound=bindService(new Intent(this,CoordinatorService.class),connection,0);return;}
        dispatch(getIntent());bound=bindService(new Intent(this,CoordinatorService.class),connection,0);
        if(getIntent().getBooleanExtra("recreate",false)){recreate();return;}
    }
    @Override public void onNewIntent(Intent intent){super.onNewIntent(intent);dispatch(intent);}
    void dispatch(Intent source){
        if(source.hasExtra("targetUrl")&&(!BuildConfig.PUBLIC_PROBE_ENABLED||!source.getBooleanExtra("publicProbe",false)))throw new SecurityException("publicProbeNotArmed");
        Intent command=new Intent(this,CoordinatorService.class);if(source.getExtras()!=null)command.putExtras(source.getExtras());startService(command);
    }
    @Override public void onSaveInstanceState(Bundle out){out.putBoolean("triggerDispatched",true);super.onSaveInstanceState(out);}
    @Override public void onDestroy(){android.util.Log.i("MF040Activity","onDestroy changingConfig="+isChangingConfigurations());if(bound)unbindService(connection);if(receiverRegistered)unregisterReceiver(finished);super.onDestroy();}
}
