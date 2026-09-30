package com.mediaflow.research.v040.lifecycle;

import android.app.Service;
import android.content.*;
import android.os.*;
import java.io.File;
import java.util.UUID;
import org.json.JSONObject;

public final class CoordinatorService extends Service {
    long start;
    enum State { IDLE, ALLOCATING, WORKER_RUNNING, STOPPING, AWAITING_DEATH, CLEANING, COMPLETED, BLOCKED }
    State state=State.IDLE;
    int duplicateRejected;
    boolean holdWorker,holdCleanup,bridgeFixture;
    @Override public IBinder onBind(Intent intent){return new Binder();}
    void transition(State next){
        boolean legal=next==State.BLOCKED||(state==State.IDLE&&next==State.ALLOCATING)||(state==State.ALLOCATING&&next==State.WORKER_RUNNING)||(state==State.WORKER_RUNNING&&next==State.STOPPING)||(state==State.STOPPING&&next==State.AWAITING_DEATH)||(state==State.AWAITING_DEATH&&next==State.CLEANING)||(state==State.CLEANING&&next==State.COMPLETED);
        if(!legal)throw new IllegalStateException("invalidTransition_"+state+"_"+next);
        state=next;event("state_"+next);progress();
    }
    void progress(){try{JSONObject p=new JSONObject();p.put("operation",op);p.put("state",state.name());p.put("duplicateRejected",duplicateRejected);OperationFiles.write(new File(getFilesDir(),"coordinator-progress.json"),p);}catch(Exception e){android.util.Log.e("MF040Coordinator","progressWriteFailed");}}
    String op,nonce,ticks;
    int pid;
    boolean bound,dead,completed,done,activePass;
    boolean securityFixture;
    String targetUrl;
    JSONObject realEvidence;
    JSONObject safetyEvidence;
    Messenger worker;
    final org.json.JSONArray timeline=new org.json.JSONArray();
    org.json.JSONArray workerTimeline;
    IBinder workerBinder;
    boolean startSent;
    JSONObject bridgeEvidence;
    final Handler handler=new Handler(Looper.getMainLooper(),msg->{
        try{
            if(msg.what==OfflineWorkerService.LOADED){
                pid=msg.getData().getInt("pid");ticks=msg.getData().getString("ticks");
                event("workerLoaded");
                JSONObject owner=validate();
                if(!OperationFiles.startTicks(pid).equals(ticks)||!OperationFiles.profile(this,op).exists())throw new SecurityException("activeIdentity");
                // Exercise the actual cleanup guard before permitting the worker to exit.
                activePass=cleanup().equals("ACTIVE_REFUSED")&&OperationFiles.profile(this,op).exists();
                event(activePass?"activeRefusedProfilePreserved":"activeProtectionFailed");
                if(!activePass){finishResult("BLOCKED","activeProtection");return true;}
                transition(State.WORKER_RUNNING);
                if(targetUrl!=null){worker.send(Message.obtain(null,OfflineWorkerService.NAVIGATE));event("navigationCommandSent");}
                else if(!holdWorker)requestStop();
            }else if(msg.what==OfflineWorkerService.COMPLETED){completed=true;if(state==State.WORKER_RUNNING)transition(State.STOPPING);transition(State.AWAITING_DEATH);event("completionReceived");releaseBinding();if(dead)observeExit();}
        }catch(Exception e){finishResult("BLOCKED",e.getClass().getName());}
        return true;
    });
    final Messenger endpoint=new Messenger(handler);
    final ServiceConnection connection=new ServiceConnection(){
        @Override public void onServiceConnected(ComponentName name,IBinder binder){
            try{
                if(startSent){event("binderReconnectRejected");return;}startSent=true;
                workerBinder=binder;worker=new Messenger(binder);
                binder.linkToDeath(()->handler.post(()->{dead=true;event("binderDeath");releaseBinding();observeExit();}),0);
                Message m=Message.obtain(null,OfflineWorkerService.START);m.replyTo=endpoint;
                Bundle b=new Bundle();b.putString("op",op);b.putString("nonce",nonce);b.putLong("start",start);b.putBoolean("securityFixture",securityFixture);b.putString("targetUrl",targetUrl);b.putBoolean("bridgeFixture",bridgeFixture);m.setData(b);worker.send(m);
            }catch(Exception e){finishResult("BLOCKED",e.getClass().getName());}
        }
        @Override public void onServiceDisconnected(ComponentName name){event("serviceDisconnected");}
    };
    @Override public int onStartCommand(Intent intent,int flags,int id){
        String control=intent==null?"":intent.getStringExtra("control");
        if("releaseWorker".equals(control)&&targetUrl==null&&state==State.WORKER_RUNNING){holdWorker=false;requestStop();return START_NOT_STICKY;}
        if("releaseCleanup".equals(control)&&state==State.CLEANING){holdCleanup=false;completeCleanup();return START_NOT_STICKY;}
        if(state!=State.IDLE){duplicateRejected++;event("duplicateRejected_"+state);progress();return START_NOT_STICKY;}
        if(intent==null){stopSelf();return START_NOT_STICKY;}
        targetUrl=intent.getStringExtra("targetUrl");
        if(targetUrl!=null&&(!BuildConfig.PUBLIC_PROBE_ENABLED||!intent.getBooleanExtra("publicProbe",false)||!targetUrl.matches("https://www\\.douyin\\.com/share/note/[0-9]{19}/?"))){android.util.Log.e("MF040Coordinator","publicProbeNotArmed");stopSelf();return START_NOT_STICKY;}
        if(targetUrl!=null){try{if(!new File(getFilesDir(),"public-probe-used-"+BuildConfig.PUBLIC_PROBE_RUN).createNewFile()){android.util.Log.e("MF040Coordinator","publicProbeAlreadyUsed");stopSelf();return START_NOT_STICKY;}}catch(Exception e){stopSelf();return START_NOT_STICKY;}}
        start=SystemClock.elapsedRealtime();securityFixture=targetUrl==null;bridgeFixture=targetUrl==null;
        holdWorker=targetUrl==null&&intent.getBooleanExtra("holdWorker",false);holdCleanup=targetUrl==null&&intent.getBooleanExtra("holdCleanup",false);
        transition(State.ALLOCATING);
        try{
            if(android.os.Build.VERSION.SDK_INT<29)throw new IllegalStateException("API29Required");
            op=UUID.randomUUID().toString().replace("-","");nonce=UUID.randomUUID().toString().replace("-","");
            JSONObject reg=new JSONObject();reg.put("operation",op);reg.put("nonce",nonce);reg.put("coordinatorPid",android.os.Process.myPid());
            reg.put("coordinatorStartTicks",OperationFiles.startTicks(android.os.Process.myPid()));
            OperationFiles.write(OperationFiles.registration(this,op),reg);event("registered");
            bound=bindService(new Intent(this,OfflineWorkerService.class),connection,BIND_AUTO_CREATE);
            if(!bound)throw new IllegalStateException("bindFailed");
            handler.postDelayed(()->{if(!done)finishResult("BLOCKED","deadlineNoDeletion");},45000);
        }catch(Exception e){finishResult("BLOCKED",e.getClass().getName());}
        return START_NOT_STICKY;
    }
    void requestStop(){try{transition(State.STOPPING);worker.send(Message.obtain(null,OfflineWorkerService.SECURITY_STOP));}catch(Exception e){finishResult("BLOCKED",e.getClass().getName());}}
    void event(String phase){try{JSONObject e=new JSONObject();e.put("phase",phase);e.put("elapsedMs",SystemClock.elapsedRealtime()-start);timeline.put(e);}catch(Exception ignored){}android.util.Log.i("MF040Coordinator","op="+op+" phase="+phase+" elapsedMs="+(SystemClock.elapsedRealtime()-start));}
    void releaseBinding(){if(bound){bound=false;try{unbindService(connection);}catch(Exception ignored){}}}
    JSONObject validate() throws Exception {
        if(op==null||!op.matches("[a-f0-9]{32}"))throw new SecurityException("operation");
        File root=OperationFiles.root(this);OperationFiles.noLink(root);OperationFiles.noLink(getFilesDir());
        JSONObject reg=OperationFiles.read(OperationFiles.registration(this,op)),owner=OperationFiles.read(OperationFiles.marker(this,op));
        if(!op.equals(reg.getString("operation"))||!op.equals(owner.getString("operation"))||
           !nonce.equals(reg.getString("nonce"))||!nonce.equals(owner.getString("nonce"))||
           !owner.getString("kind").equals("MediaFlow040OfflineWorker")||owner.getInt("pid")!=pid||
           !owner.getString("startTicks").equals(ticks)||!owner.getString("profile").equals(OperationFiles.profile(this,op).getAbsolutePath()))throw new SecurityException("ownership");
        return owner;
    }
    String cleanup() throws Exception {
        JSONObject owner=validate();
        File proc=new File("/proc/"+pid);
        if(proc.exists()){
            if(!OperationFiles.startTicks(pid).equals(ticks))throw new SecurityException("PIDReuseBlocked");
            return "ACTIVE_REFUSED";
        }
        if(!dead||workerBinder==null||workerBinder.isBinderAlive()||!completed||
           !owner.optBoolean("normalCompletion")||!(owner.optBoolean("loaded")||(targetUrl!=null&&owner.optBoolean("navigationStarted")))||!owner.optBoolean("destroyed")||!owner.optBoolean("rendererGone"))throw new SecurityException("exitNotProven");
        if(targetUrl!=null){
            bridgeEvidence=owner.getJSONObject("bridgeHealth");
            JSONObject before=owner.getJSONObject("beforeStop"),after=owner.getJSONObject("afterStop"),last=owner.getJSONObject("observationFinal");
            if(!last.getBoolean("cancelled"))throw new SecurityException("realObservationNotCancelled");
            for(ObservationGate.Kind kind:ObservationGate.Kind.values())if(last.getInt(kind.name()+"Consumed")!=before.getInt(kind.name()+"Consumed"))throw new SecurityException("realPostStopConsumption");
            realEvidence=new JSONObject();realEvidence.put("stopReason",owner.getString("stopReason"));realEvidence.put("securityStopped",owner.getBoolean("securityStopped"));
            realEvidence.put("beforeStop",before);realEvidence.put("afterStop",after);realEvidence.put("final",last);realEvidence.put("targetEvidence",owner.optJSONObject("targetEvidence"));realEvidence.put("targetId",owner.getString("targetId"));
            realEvidence.put("bridgeBeforeStop",owner.getJSONObject("bridgeBeforeStop"));realEvidence.put("bridgeAfterStop",owner.getJSONObject("bridgeAfterStop"));
            JSONObject bridgeBefore=owner.getJSONObject("bridgeBeforeStop");
            java.util.Iterator<String> keys=bridgeBefore.keys();while(keys.hasNext()){String key=keys.next();if(!bridgeBefore.get(key).equals(bridgeEvidence.get(key)))throw new SecurityException("bridgePostStopConsumption");}
            if(!op.equals(bridgeEvidence.getString("operation"))||owner.getInt("navigationRequests")!=1)throw new SecurityException("realOperationBoundary");
            realEvidence.put("operation",op);realEvidence.put("navigationRequests",owner.getInt("navigationRequests"));
        }
        if(securityFixture){
            if(!owner.getBoolean("securityStopped")||!owner.getBoolean("securityFixturePass")||owner.getInt("queuedConsumed")!=0||owner.getInt("queuedCancelled")!=6)throw new SecurityException("safetyNotProven");
            JSONObject before=owner.getJSONObject("beforeStop"),after=owner.getJSONObject("afterStop"),last=owner.getJSONObject("observationFinal");
            if(!last.getBoolean("cancelled"))throw new SecurityException("observationNotCancelled");
            for(ObservationGate.Kind kind:ObservationGate.Kind.values()){
                if(before.getInt(kind.name()+"Consumed")<1||last.getInt(kind.name()+"Consumed")!=before.getInt(kind.name()+"Consumed")||after.getInt(kind.name()+"Rejected")<=before.getInt(kind.name()+"Rejected"))throw new SecurityException("postStopConsumption");
            }
            safetyEvidence=new JSONObject();safetyEvidence.put("beforeStop",before);safetyEvidence.put("afterStop",after);safetyEvidence.put("final",last);
            safetyEvidence.put("queuedConsumed",owner.getInt("queuedConsumed"));safetyEvidence.put("queuedCancelled",owner.getInt("queuedCancelled"));
            if(bridgeFixture){bridgeEvidence=owner.getJSONObject("bridgeHealth");
                for(String key:new String[]{"initialized","ack","documentReady","hydrationCallbacks","jsonCandidates","responseCallbacks"})if(bridgeEvidence.getInt(key)<1)throw new SecurityException("bridgeLayerMissing_"+key);
                if(bridgeEvidence.getInt("decoderInvocations")!=3||bridgeEvidence.getInt("decoderSuccess")!=3||bridgeEvidence.getInt("bodyCallbacks")!=3)throw new SecurityException("fixtureDecodeFailed");
            }
        }
        OperationFiles.noLink(new File(getApplicationInfo().dataDir));OperationFiles.noLink(getCacheDir());OperationFiles.noLink(getNoBackupFilesDir());
        File profile=OperationFiles.profile(this,op),cache=OperationFiles.cache(this,op);
        File metadata=OperationFiles.metadata(this,op);OperationFiles.treeCheck(metadata,metadata);OperationFiles.treeCheck(profile,profile);OperationFiles.treeCheck(cache,cache);event("ownershipValidated");
        workerTimeline=owner.getJSONArray("timeline");OperationFiles.erase(profile);OperationFiles.erase(cache);OperationFiles.erase(metadata);event("profileDeleted");
        if(profile.exists()||cache.exists()||metadata.exists())throw new IllegalStateException("profileRemaining");
        if(!OperationFiles.marker(this,op).delete()||!OperationFiles.registration(this,op).delete())throw new IllegalStateException("markerDeletion");
        event("markersDeleted");return "CLEANED";
    }
    void observeExit(){
        if(done)return;
        // Binder death signals termination; bounded polling verifies OS absence, not sleep-based inference.
        if(pid==0){finishResult("BLOCKED","workerIdentityMissing");return;}
        if(!completed||new File("/proc/"+pid).exists()){
            if(SystemClock.elapsedRealtime()-start>=44000){finishResult("BLOCKED","workerStillPresent");return;}
            handler.postDelayed(()->observeExit(),50);return;
        }
        try{event("OSExitConfirmed");transition(State.CLEANING);if(!holdCleanup)completeCleanup();}
        catch(Exception e){finishResult("BLOCKED",e.getClass().getName());}
    }
    void completeCleanup(){try{String outcome=cleanup();finishResult(outcome.equals("CLEANED")&&activePass?"PASS":"BLOCKED",outcome);}catch(Exception e){finishResult("BLOCKED",e.getClass().getName());}}
    void finishResult(String status,String reason){
        if(done)return;done=true;releaseBinding();transition(status.equals("PASS")?State.COMPLETED:State.BLOCKED);
        try{
            JSONObject result=new JSONObject();result.put("duplicateRejected",duplicateRejected);result.put("state",state.name());result.put("status",status);result.put("reason",reason);result.put("operation",op);
            result.put("workerPid",pid);result.put("workerStartTicks",ticks);result.put("binderDeath",dead);result.put("normalCompletion",completed);
            result.put("activeProtection",activePass);result.put("workerPresent",pid!=0&&new File("/proc/"+pid).exists());
            result.put("securityFixture",securityFixture);result.put("safetyEvidence",safetyEvidence);
            result.put("realEvidence",realEvidence);
            result.put("bridgeHealth",bridgeEvidence);result.put("workerStartMessages",startSent?1:0);
            result.put("profilePresent",op!=null&&OperationFiles.profile(this,op).exists());result.put("cachePresent",op!=null&&OperationFiles.cache(this,op).exists());
            result.put("metadataPresent",op!=null&&OperationFiles.metadata(this,op).exists());result.put("markerPresent",op!=null&&OperationFiles.marker(this,op).exists());result.put("registrationPresent",op!=null&&OperationFiles.registration(this,op).exists());
            result.put("timeline",timeline);result.put("workerTimeline",workerTimeline);result.put("elapsedMs",SystemClock.elapsedRealtime()-start);
            OperationFiles.write(new File(getFilesDir(),"coordinator-result.json"),result);
            android.util.Log.i("MF040Coordinator",result.toString());
        }catch(Exception e){android.util.Log.e("MF040Coordinator","resultBlocked="+e.getClass().getName());}
        sendBroadcast(new Intent("mf040.FINAL").setPackage(getPackageName()));stopSelf();
    }
}
