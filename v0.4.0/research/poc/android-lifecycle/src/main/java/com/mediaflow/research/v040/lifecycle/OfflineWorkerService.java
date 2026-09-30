package com.mediaflow.research.v040.lifecycle;

import android.app.Service;
import android.content.Intent;
import android.os.*;
import android.webkit.*;
import java.io.ByteArrayInputStream;
import org.json.JSONObject;

// One WebView per fresh private process; explicit one-shot public research mode only.
public final class OfflineWorkerService extends Service {
    static final int START=1,LOADED=2,CLOSE=3,COMPLETED=4,SECURITY_STOP=5,NAVIGATE=6;
    String op,nonce,ticks;
    int pid;
    long start;
    boolean loaded,closing,rendererGone;
    boolean securityFixture,securityStopped,fixturePass;
    static final java.util.concurrent.atomic.AtomicBoolean processClaim=new java.util.concurrent.atomic.AtomicBoolean();
    boolean bridgeFixture,readySent;
    int scriptInjection,bridgeInitialized,bridgeAck,documentReady,hydrationCallbacks,jsonCandidates,responseCallbacks,bodyCallbacks,decoderInvocations,decoderSuccess,decoderNoMatch,decoderError,bodyReadErrors,fixtureExpectedDecodes;
    int queuedConsumed,queuedCancelled;
    final ObservationGate observations=new ObservationGate();
    final Handler observationTasks=new Handler(Looper.getMainLooper());
    JSONObject beforeStop,afterStop,bridgeBeforeStop,bridgeAfterStop;
    int requestObservations,navigationRequests,securityStopCount,hydrationInputs,jsonInputs,responseInputs;
    boolean realTarget,navigationStarted;
    String targetUrl,targetId,stopReason;
    JSONObject targetEvidence;
    androidx.webkit.ScriptHandler pageScript;
    WebView view;
    Messenger coordinator;
    final org.json.JSONArray timeline=new org.json.JSONArray();
    final Handler handler=new Handler(Looper.getMainLooper(),msg->{
        try{
            if(msg.what==START){coordinator=msg.replyTo;start(msg.getData());}
            else if(msg.what==CLOSE)closeView();
            else if(msg.what==SECURITY_STOP)securitySignal();
            else if(msg.what==NAVIGATE&&realTarget&&!navigationStarted&&!observations.cancelled()){navigationStarted=true;navigationRequests++;event("targetNavigationRequested");view.loadUrl(targetUrl);observationTasks.postDelayed(()->realStop("windowEnded",false),10000);}
        }catch(Exception e){android.util.Log.e("MF040Worker","blocked="+e.getClass().getName()+":"+e.getMessage());}
        return true;
    });
    final Messenger endpoint=new Messenger(handler);
    @Override public IBinder onBind(Intent intent){return endpoint.getBinder();}
    synchronized void event(String phase){try{JSONObject e=new JSONObject();e.put("phase",phase);e.put("elapsedMs",SystemClock.elapsedRealtime()-start);timeline.put(e);}catch(Exception ignored){}android.util.Log.i("MF040Worker","op="+op+" phase="+phase+" elapsedMs="+(SystemClock.elapsedRealtime()-start));}
    void start(Bundle data) throws Exception {
        if(op!=null||!processClaim.compareAndSet(false,true))throw new SecurityException("workerProcessAlreadyClaimed");
        start=data.getLong("start");op=data.getString("op");nonce=data.getString("nonce");securityFixture=data.getBoolean("securityFixture");
        targetUrl=data.getString("targetUrl");realTarget=targetUrl!=null;
        if(realTarget&&!BuildConfig.PUBLIC_PROBE_ENABLED)throw new SecurityException("publicProbeBuildDisabled");
        bridgeFixture=data.getBoolean("bridgeFixture");if(bridgeFixture)targetId="fixture-gallery";
        if(realTarget){
            if(securityFixture||bridgeFixture||!targetUrl.matches("https://www\\.douyin\\.com/share/note/[0-9]{19}/?"))throw new SecurityException("targetBoundary");
            targetId=android.net.Uri.parse(targetUrl).getLastPathSegment();
        }
        if(op==null||!op.matches("[a-f0-9]{32}")||nonce==null||!nonce.matches("[a-f0-9]{32}"))throw new SecurityException("operation");
        JSONObject reg=OperationFiles.read(OperationFiles.registration(this,op));
        if(!reg.getString("nonce").equals(nonce)||!reg.getString("operation").equals(op))throw new SecurityException("registration");
        pid=android.os.Process.myPid();ticks=OperationFiles.startTicks(pid);
        JSONObject owner=new JSONObject();owner.put("kind","MediaFlow040OfflineWorker");owner.put("operation",op);owner.put("nonce",nonce);
        owner.put("pid",pid);owner.put("startTicks",ticks);owner.put("profile",OperationFiles.profile(this,op).getAbsolutePath());
        OperationFiles.write(OperationFiles.marker(this,op),owner);
        event("workerStarted");
        WebView.setDataDirectorySuffix("mf040_"+op); // Before any WebView/provider call.
        view=new WebView(this);view.getSettings().setJavaScriptEnabled(realTarget||bridgeFixture);view.getSettings().setBlockNetworkLoads(!realTarget);
        view.getSettings().setLoadsImagesAutomatically(false);view.getSettings().setMediaPlaybackRequiresUserGesture(true);
        if(realTarget||bridgeFixture){
            if(!androidx.webkit.WebViewFeature.isFeatureSupported(androidx.webkit.WebViewFeature.DOCUMENT_START_SCRIPT)||!androidx.webkit.WebViewFeature.isFeatureSupported(androidx.webkit.WebViewFeature.WEB_MESSAGE_LISTENER))throw new IllegalStateException("documentGuardUnavailable");
            java.util.Set<String> origins=java.util.Collections.singleton(bridgeFixture?"https://mediaflow.invalid":"https://www.douyin.com");
            androidx.webkit.WebViewCompat.addWebMessageListener(view,"MF040Public",origins,(v,message,origin,main,reply)->{
                if(bridgeFixture)event("bridgeCallback_"+main);
                if(!main||observations.cancelled())return;
                try{
                    JSONObject dataMessage=new JSONObject(message.getData());
                    consumePageMessage(dataMessage);
                }catch(Exception e){realStop("invalidPageSummary",false);}
            });
            pageScript=androidx.webkit.WebViewCompat.addDocumentStartJavaScript(view,PublicPageScript.source(targetId,op),origins);scriptInjection++;
        }
        view.setWebViewClient(new WebViewClient(){
            @Override public WebResourceResponse shouldInterceptRequest(WebView v,WebResourceRequest r){
                // No body read or network started. Even metadata observation uses the cancellation gate.
                if(bridgeFixture){
                    event("localRequest_"+r.getUrl().getPath());
                    if(observations.cancelled())return empty();
                    if(!"mediaflow.invalid".equals(r.getUrl().getHost()))return empty();
                    String path=r.getUrl().getPath();
                    if("/fixture/index.html".equals(path))return new WebResourceResponse("text/html","UTF-8",new ByteArrayInputStream(fixtureHtml().getBytes(java.nio.charset.StandardCharsets.UTF_8)));
                    if("/fixture/data.json".equals(path))return new WebResourceResponse("application/json","UTF-8",new ByteArrayInputStream(fixturePayload().getBytes(java.nio.charset.StandardCharsets.UTF_8)));
                    return empty();
                }
                if(realTarget){
                    String u=(r.getUrl().getHost()+r.getUrl().getPath()).toLowerCase(java.util.Locale.ROOT);
                    if(u.contains("waf-jschallenge")||u.contains("lf-waf-js")||u.contains("captcha")||u.contains("/verify")||u.contains("/challenge")){
                        realStop("securityResourceDetected",true);return empty();
                    }
                    if(observations.cancelled())return empty();
                    if(u.matches(".*\\.(jpg|jpeg|png|webp|gif|avif|mp4|m3u8).*"))return empty();
                    observations.consume(ObservationGate.Kind.OBSERVATION,()->requestObservations++);return null;
                }
                observations.consume(ObservationGate.Kind.OBSERVATION,()->{});
                return new WebResourceResponse("text/plain","UTF-8",new ByteArrayInputStream(new byte[0]));
            }
            @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){
                // Offline fixture never permits a follow-up navigation, before or after cancellation.
                if(realTarget){
                    String path=r.getUrl().getPath();
                    if(path!=null&&path.startsWith("/note/")){realStop("blockedNoteRedirect",true);return true;}
                    if(path!=null&&path.matches(".*(login|passport|captcha|verify|challenge).*")){realStop("restrictedNavigation",true);return true;}
                    if(!r.getUrl().toString().equals(targetUrl)){realStop("navigationBoundary",false);return true;}
                }
                observations.consume(ObservationGate.Kind.NAVIGATION,()->{});return true;
            }
            @Override public void onPageStarted(WebView v,String url,android.graphics.Bitmap icon){
                if(realTarget&&android.net.Uri.parse(url).getPath()!=null&&android.net.Uri.parse(url).getPath().startsWith("/note/")){realStop("blockedNoteRedirect",true);return;}
                if(realTarget)observations.consume(ObservationGate.Kind.NAVIGATION,()->event("navigationStarted"));
            }
            @Override public void onPageFinished(WebView v,String url){
                if(loaded||closing||observations.cancelled())return;loaded=true;event("offlineLoaded");
                if(securityFixture&&!bridgeFixture)for(ObservationGate.Kind kind:ObservationGate.Kind.values())observations.consume(kind,()->{});
                if(bridgeFixture){maybeReady();return;}
                if(realTarget){event("targetPageFinished");return;}
                try{Bundle b=new Bundle();b.putInt("pid",pid);b.putString("ticks",ticks);send(LOADED,b);}catch(Exception e){event("ipcFailed");}
            }
            @Override public boolean onRenderProcessGone(WebView v,RenderProcessGoneDetail d){
                rendererGone=true;event("rendererGone");
                if(closing)destroyAndExit();return true;
            }
        });
        if(bridgeFixture)view.setWebChromeClient(new WebChromeClient(){@Override public boolean onConsoleMessage(ConsoleMessage m){event("fixtureConsole_"+m.messageLevel()+"_line"+m.lineNumber());return true;}});
        event("profileAllocated");
        if(realTarget){Bundle b=new Bundle();b.putInt("pid",pid);b.putString("ticks",ticks);send(LOADED,b);}
        else if(bridgeFixture)view.loadUrl("https://mediaflow.invalid/fixture/index.html");
        else view.loadDataWithBaseURL(null,"<html><body>operation-owned offline page</body></html>","text/html","UTF-8",null);
    }
    String fixturePayload(){return "{\"aweme_id\":\"fixture-gallery\",\"desc\":\"offline fixture\",\"author\":{\"nickname\":\"fixture\"},\"image_post_info\":{\"images\":[{\"url_list\":[\"https://mediaflow.invalid/image/a\"]},{\"url_list\":[\"https://mediaflow.invalid/image/b\"]}]}}";}
    String fixtureHtml(){return "<html><body>local fixture<script id='RENDER_DATA' type='application/json'>"+fixturePayload()+"</script><script id='GENERIC_JSON' type='application/json'>"+fixturePayload()+"</script><script>document.addEventListener('DOMContentLoaded',()=>fetch('/fixture/data.json').then(r=>r.text()).then(()=>{}));</script></body></html>";}
    void consumePageMessage(JSONObject message){
        if(!op.equals(message.optString("operation")))throw new SecurityException("bridgeOperationMismatch");
        String kind=message.optString("kind");
        if(kind.equals("restriction")){realStop(message.optString("reason","restriction"),true);return;}
        observations.consume(ObservationGate.Kind.OBSERVATION,()->{
            if(kind.equals("bridgeInitialized")){bridgeInitialized++;event("bridgeInitialized");view.evaluateJavascript("window.__mf040Ack()",null);}
            else if(kind.equals("bridgeAck")){bridgeAck++;event("bridgeAck");}
            else if(kind.equals("documentReady")){documentReady++;event("documentReady");}
            else if(kind.equals("bodyReadError")){bodyReadErrors++;event("bodyReadError");}
            else if(kind.equals("responseMetadata")){observations.consume(ObservationGate.Kind.RESPONSE,()->{responseCallbacks++;event("responseMetadata");});}
            else if(kind.equals("hydration")||kind.equals("jsonCandidate")||kind.equals("responseBody")){
                ObservationGate.Kind type=kind.equals("responseBody")?ObservationGate.Kind.OBSERVATION:ObservationGate.Kind.HYDRATION;
                observations.consume(type,()->{
                    if(kind.equals("hydration"))hydrationCallbacks++;else if(kind.equals("jsonCandidate"))jsonCandidates++;
                    observations.consume(ObservationGate.Kind.BODY,()->{bodyCallbacks++;
                        observations.consume(ObservationGate.Kind.DECODER,()->{decoderInvocations++;if(kind.equals("hydration"))hydrationInputs++;else if(kind.equals("jsonCandidate"))jsonInputs++;else responseInputs++;JSONObject decoded=PublicPageScript.summary(message,targetId);
                            if("SUCCESS".equals(decoded.optString("decodeStatus")))decoderSuccess++;else if("ERROR".equals(decoded.optString("decodeStatus")))decoderError++;else decoderNoMatch++;
                            if(bridgeFixture&&decoded.optBoolean("targetMatch")&&decoded.optInt("imageCount")==2&&decoded.optInt("differentImageUrlCount")==2)fixtureExpectedDecodes++;
                            if(decoded.optBoolean("targetMatch"))targetEvidence=decoded;
                            event("pageDecoded_"+kind+"_"+decoded.optString("decodeStatus"));
                        });
                    });
                });
            }
        });
        if(bridgeFixture)maybeReady();
    }
    void maybeReady(){
        if(readySent||!loaded||bridgeInitialized<1||bridgeAck<1||documentReady<1||hydrationCallbacks<1||jsonCandidates<1||responseCallbacks<1||fixtureExpectedDecodes<3)return;
        readySent=true;event("bridgeHealthReady");observations.consume(ObservationGate.Kind.NAVIGATION,()->{});
        try{Bundle b=new Bundle();b.putInt("pid",pid);b.putString("ticks",ticks);send(LOADED,b);}catch(Exception e){event("fixtureReadyIPCFailed");}
    }
    JSONObject bridgeHealth() throws Exception {JSONObject b=new JSONObject();b.put("operation",op);b.put("requestObservations",requestObservations);b.put("navigationRequests",navigationRequests);b.put("securityStopCount",securityStopCount);b.put("hydrationInputs",hydrationInputs);b.put("jsonInputs",jsonInputs);b.put("responseInputs",responseInputs);b.put("scriptInjection",scriptInjection);b.put("decoderNoMatch",decoderNoMatch);b.put("decoderError",decoderError);b.put("bodyReadErrors",bodyReadErrors);b.put("initialized",bridgeInitialized);b.put("ack",bridgeAck);b.put("documentReady",documentReady);b.put("hydrationCallbacks",hydrationCallbacks);b.put("jsonCandidates",jsonCandidates);b.put("responseCallbacks",responseCallbacks);b.put("bodyCallbacks",bodyCallbacks);b.put("decoderInvocations",decoderInvocations);b.put("decoderSuccess",decoderSuccess);return b;}
    WebResourceResponse empty(){return new WebResourceResponse("text/plain","UTF-8",new ByteArrayInputStream(new byte[0]));}
    void realStop(String reason,boolean safety){
        // Called by resource callbacks too: cancel synchronously BEFORE posting main-thread shutdown.
        synchronized(observations){
            if(observations.cancelled())return;
            try{beforeStop=observations.snapshot();if(safety)securityStopCount++;bridgeBeforeStop=bridgeHealth();stopReason=reason;securityStopped=safety;event(reason);cancelObservation();afterStop=observations.snapshot();bridgeAfterStop=bridgeHealth();}
            catch(Exception e){observations.cancel();}
        }
        handler.post(()->{try{closeView();}catch(Exception e){event("realCloseBlocked");}});
    }
    void send(int what,Bundle data) throws Exception {Message m=Message.obtain(null,what);m.setData(data);coordinator.send(m);}
    void securitySignal() throws Exception {
        if(!securityFixture||!loaded||closing)throw new IllegalStateException("securitySignalOutsideActiveFixture");
        // Queue offline stand-ins before triggering the signal, then prove they cannot run.
        for(ObservationGate.Kind kind:ObservationGate.Kind.values()){
            observationTasks.post(()->observations.consume(kind,()->queuedConsumed++));queuedCancelled++;
        }
        beforeStop=observations.snapshot();event("securityStopTriggered");securityStopped=true;securityStopCount++;
        cancelObservation();
        // Same guarded consumer entry points receive late stand-ins. No payload/network/real decoder.
        for(ObservationGate.Kind kind:ObservationGate.Kind.values())observations.consume(kind,()->{});
        afterStop=observations.snapshot();fixturePass=queuedConsumed==0&&observations.cancelled();
        for(ObservationGate.Kind kind:ObservationGate.Kind.values()){
            fixturePass&=afterStop.getInt(kind.name()+"Consumed")==beforeStop.getInt(kind.name()+"Consumed");
            fixturePass&=afterStop.getInt(kind.name()+"Rejected")>beforeStop.getInt(kind.name()+"Rejected");
        }
        event(fixturePass?"lateEventsRejected":"securityFixtureFailed");
        closeView(); // Exact same core exit path as normal shutdown; no observation grace period.
    }
    void cancelObservation(){
        observations.cancel();observationTasks.removeCallbacksAndMessages(null);
        // Resource callbacks may run off the UI thread. Native gate cancels synchronously;
        // only the JS reader/observer disposal is dispatched, with no observation grace period.
        Runnable stopScript=()->{if(pageScript!=null&&view!=null)view.evaluateJavascript("window.__mf040Stop()",null);};
        if(Looper.myLooper()==Looper.getMainLooper())stopScript.run();else handler.post(stopScript);
        event("observationCancelled");
    }
    void closeView() throws Exception {
        if(closing)return;closing=true;if(!observations.cancelled())cancelObservation();event("closeRequested");view.stopLoading();
        WebViewRenderProcess renderer=view.getWebViewRenderProcess();
        if(renderer==null){rendererGone=true;destroyAndExit();return;}
        // Only this isolated worker owns this renderer; no other WebViews exist here.
        if(!renderer.terminate())throw new IllegalStateException("rendererTerminationRejected");
        event("rendererTerminationRequested");
    }
    void destroyAndExit(){
        try{
            view.destroy();view=null;event("viewDestroyed");
            JSONObject owner=OperationFiles.read(OperationFiles.marker(this,op));
            owner.put("timeline",timeline);owner.put("loaded",loaded);owner.put("destroyed",true);owner.put("rendererGone",rendererGone);owner.put("normalCompletion",true);
            if(realTarget){
                owner.put("bridgeHealth",bridgeHealth());owner.put("bridgeBeforeStop",bridgeBeforeStop);owner.put("bridgeAfterStop",bridgeAfterStop);owner.put("navigationRequests",navigationRequests);owner.put("realTarget",true);owner.put("targetId",targetId);owner.put("navigationStarted",navigationStarted);owner.put("stopReason",stopReason);owner.put("securityStopped",securityStopped);
                owner.put("beforeStop",beforeStop);owner.put("afterStop",afterStop);owner.put("observationFinal",observations.snapshot());owner.put("targetEvidence",targetEvidence);
                if(pageScript!=null)pageScript.remove();
            }
            if(securityFixture){
                owner.put("securityStopped",securityStopped);owner.put("securityFixturePass",fixturePass);
                owner.put("beforeStop",beforeStop);owner.put("afterStop",afterStop);owner.put("observationFinal",observations.snapshot());
                owner.put("queuedConsumed",queuedConsumed);owner.put("queuedCancelled",queuedCancelled);
                if(bridgeFixture)owner.put("bridgeHealth",bridgeHealth());
            }
            OperationFiles.write(OperationFiles.marker(this,op),owner);
            Bundle b=new Bundle();b.putBoolean("normalCompletion",true);send(COMPLETED,b);
            event("workerNormalExit");stopSelf();System.exit(0);
        }catch(Exception e){event("completionBlocked");}
    }
}
