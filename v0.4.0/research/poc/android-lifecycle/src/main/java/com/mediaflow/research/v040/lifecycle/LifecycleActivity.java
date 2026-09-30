package com.mediaflow.research.v040.lifecycle;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import androidx.webkit.ProfileStore;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import org.json.JSONObject;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.UUID;

// Independent offline gate, using the project's existing AndroidX WebKit version.
public final class LifecycleActivity extends Activity {
    final Handler handler = new Handler(Looper.getMainLooper());
    final long started = SystemClock.elapsedRealtime();
    String profile;
    WebView view;
    boolean finishing, loaded, destroyed;
    void event(String phase) {
        android.util.Log.i("MF040Lifecycle", "phase="+phase+" elapsedMs="+(SystemClock.elapsedRealtime()-started));
    }
    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        try {
            if(getIntent().getBooleanExtra("cleanupOnly",false)) {
                profile=new String(Files.readAllBytes(new File(getFilesDir(),"owned-profile.txt").toPath()),StandardCharsets.UTF_8);
                if(!profile.matches("mf040_offline_[a-f0-9]{32}"))throw new IllegalArgumentException();
                event("ownedStartupCleanup");deleteProfile();return;
            }
            profile="mf040_offline_"+UUID.randomUUID().toString().replace("-","");
            if(!WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE)) {complete("unsupportedMultiProfile",false,false,null);return;}
            Files.write(new File(getFilesDir(),"owned-profile.txt").toPath(),profile.getBytes(StandardCharsets.UTF_8));
            view=new WebView(this);
            WebViewCompat.setProfile(view,profile);
            event("profileAssigned");
            view.getSettings().setJavaScriptEnabled(false);
            view.getSettings().setBlockNetworkLoads(true);
            view.setWebViewClient(new WebViewClient() {
                @Override public WebResourceResponse shouldInterceptRequest(WebView v,WebResourceRequest r) {
                    return new WebResourceResponse("text/plain","UTF-8",new ByteArrayInputStream(new byte[0]));
                }
                @Override public void onPageFinished(WebView v,String url) {
                    if(finishing)return;
                    loaded=true;event("offlinePageFinished");handler.postDelayed(()->closeSession(),300);
                }
            });
            setContentView(view);
            view.loadDataWithBaseURL(null,"<html><body>offline lifecycle gate</body></html>","text/html","UTF-8",null);
            handler.postDelayed(()->{if(!finishing)closeSession();},5000);
        } catch(Throwable e) {closeFailure(e);}
    }
    void closeFailure(Throwable e) {
        if(view!=null)try{view.destroy();destroyed=true;}catch(Throwable ignored){}
        complete("runtimeFailure",false,true,e.getClass().getName());
    }
    void closeSession() {
        if(finishing)return;finishing=true;
        try {
            view.stopLoading();view.setWebViewClient(null);
            ((android.view.ViewGroup)view.getParent()).removeView(view);
            view.removeAllViews();view.destroy();view=null;destroyed=true;event("viewDestroyed");
            handler.postDelayed(()->deleteProfile(),300);
        }catch(Throwable e){complete("destroyFailure",false,true,e.getClass().getName());}
    }
    void deleteProfile() {
        try {
            ProfileStore store=ProfileStore.getInstance();
            boolean removed=store.deleteProfile(profile);
            boolean present=store.getAllProfileNames().contains(profile);
            event("profileDeletionReturned");
            complete("completed",removed&&!present,present,null);
        }catch(Throwable e){
            boolean present=true;
            try{present=ProfileStore.getInstance().getAllProfileNames().contains(profile);}catch(Throwable ignored){}
            event("profileDeletionFailed");complete("profileDeletionBlocked",false,present,e.getClass().getName());
        }
    }
    void complete(String outcome,boolean cleaned,boolean present,String error) {
        finishing=true;
        try {
            if(cleaned)new File(getFilesDir(),"owned-profile.txt").delete();
            JSONObject data=new JSONObject();data.put("outcome",outcome);data.put("profile",profile);
            data.put("offlineLoaded",loaded);data.put("viewDestroyed",destroyed);data.put("profileCleaned",cleaned);
            data.put("profilePresent",present);data.put("exceptionType",error);data.put("elapsedMs",SystemClock.elapsedRealtime()-started);
            Files.write(new File(getFilesDir(),"result.json").toPath(),data.toString().getBytes(StandardCharsets.UTF_8));
            android.util.Log.i("MF040Lifecycle",data.toString());
        }catch(Throwable e){android.util.Log.e("MF040Lifecycle","resultFailure="+e.getClass().getName());}
        finish();
    }
}
