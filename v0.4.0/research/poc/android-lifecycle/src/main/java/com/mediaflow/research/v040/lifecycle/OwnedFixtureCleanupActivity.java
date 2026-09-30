package com.mediaflow.research.v040.lifecycle;

import android.app.Activity;
import android.os.Bundle;
import java.io.File;
import org.json.JSONObject;

// Explicit cleanup of this turn's failed offline prototypes; never part of normal-operation PASS.
public final class OwnedFixtureCleanupActivity extends Activity {
    @Override public void onCreate(Bundle saved){
        super.onCreate(saved);String op=getIntent().getStringExtra("operation");JSONObject result=new JSONObject();
        try{
            // Finite ledger from this turn. Historical orphan operation is deliberately excluded.
            if(!java.util.Set.of("61d6a046e87443ecbe3910363943e739","76786c6879004d9d86f865a23f7109ea","b882dc0817d2476a974c87ee5556b698").contains(op))throw new SecurityException("notThisTurnLedger");
            JSONObject reg=OperationFiles.read(OperationFiles.registration(this,op));
            if(!op.equals(reg.getString("operation"))||!reg.getString("nonce").matches("[a-f0-9]{32}")||new File("/proc/"+reg.getInt("coordinatorPid")).exists())throw new SecurityException("coordinatorOwnershipOrActive");
            File marker=OperationFiles.marker(this,op),profile=OperationFiles.profile(this,op),cache=OperationFiles.cache(this,op),meta=OperationFiles.metadata(this,op);
            if(marker.exists()){
                JSONObject owner=OperationFiles.read(marker);
                if(!op.equals(owner.getString("operation"))||!reg.getString("nonce").equals(owner.getString("nonce"))||!"MediaFlow040OfflineWorker".equals(owner.getString("kind"))||!profile.getAbsolutePath().equals(owner.getString("profile"))||new File("/proc/"+owner.getInt("pid")).exists()||owner.getString("startTicks").isEmpty())throw new SecurityException("workerOwnershipOrActive");
            }else if(profile.exists()||cache.exists()||meta.exists())throw new SecurityException("ownerMissingWithStorage");
            for(File root:new File[]{new File(getApplicationInfo().dataDir),getCacheDir(),getNoBackupFilesDir(),OperationFiles.root(this)})OperationFiles.noLink(root);
            for(File target:new File[]{profile,cache,meta}){
                if(java.nio.file.Files.isSymbolicLink(target.toPath()))throw new SecurityException("symlink");
                OperationFiles.treeCheck(target,target);
            }
            for(File target:new File[]{profile,cache,meta})OperationFiles.erase(target);
            if(marker.exists()&&!marker.delete())throw new IllegalStateException("markerDelete");
            if(!OperationFiles.registration(this,op).delete())throw new IllegalStateException("registrationDelete");
            result.put("operation",op);result.put("status","PASS");result.put("scope","explicitFailedOfflinePrototypeCleanup");
        }catch(Exception e){try{result.put("operation",op);result.put("status","BLOCKED");result.put("reason",e.getMessage());}catch(Exception ignored){}}
        try{OperationFiles.write(new File(getFilesDir(),"failed-fixture-cleanup-result.json"),result);}catch(Exception e){throw new IllegalStateException(e);}
        finish();
    }
}
