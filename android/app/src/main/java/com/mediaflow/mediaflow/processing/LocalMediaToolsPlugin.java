package com.mediaflow.mediaflow.processing;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMetadataRetriever;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.provider.OpenableColumns;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/** User-selected SAF input only. No broad storage permission or directory scan. */
public final class LocalMediaToolsPlugin implements FlutterPlugin, ActivityAware,
        MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {
    private static final int PICK = 7051;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Map<String, Uri> selected = new ConcurrentHashMap<>();
    private final Map<String, AtomicBoolean> copies = new ConcurrentHashMap<>();
    private ExecutorService worker;
    private Context context;
    private ActivityPluginBinding activityBinding;
    private MethodChannel channel;
    private MethodChannel.Result pending;
    private volatile boolean attached;
    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        context=binding.getApplicationContext(); attached=true;
        worker=Executors.newSingleThreadExecutor();
        channel=new MethodChannel(binding.getBinaryMessenger(),"com.mediaflow.mediaflow/media_tools");
        channel.setMethodCallHandler(this);
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        attached=false; channel.setMethodCallHandler(null);
        copies.values().forEach(flag->flag.set(true)); selected.clear(); worker.shutdown();
    }
    @Override public void onAttachedToActivity(ActivityPluginBinding binding) {activityBinding=binding;binding.addActivityResultListener(this);}
    private void detach() {if(activityBinding!=null)activityBinding.removeActivityResultListener(this);activityBinding=null;}
    @Override public void onDetachedFromActivityForConfigChanges(){detach();}
    @Override public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding){onAttachedToActivity(binding);}
    @Override public void onDetachedFromActivity(){detach();if(pending!=null){pending.error("cancelled","File selection closed.",null);pending=null;}}
    @Override public void onMethodCall(MethodCall call,MethodChannel.Result result) {
        if(call.method.equals("pickVideo")) {
            if(pending!=null||activityBinding==null){result.error("operationBusy","File picker unavailable or busy.",null);return;}
            pending=result;
            Intent intent=new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("video/*")
                .addCategory(Intent.CATEGORY_OPENABLE).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            try {activityBinding.getActivity().startActivityForResult(intent,PICK);}
            catch(Exception e){pending=null;result.error("platformUnavailable","No system document picker.",null);} return;
        }
        String token=call.argument("reference");
        if(call.method.equals("releaseInput")){if(token!=null)selected.remove(token);result.success(null);return;}
        String id=call.argument("id");
        if(call.method.equals("cancelInput")){AtomicBoolean flag=copies.get(id);if(flag!=null)flag.set(true);result.success(null);return;}
        if(!call.method.equals("materializeInput")){result.notImplemented();return;}
        Uri uri=selected.get(token);
        if(uri==null||id==null||!id.matches("[A-Za-z0-9_-]{1,48}")){result.error("inputMissing","Please select the video again.",null);return;}
        AtomicBoolean cancelled=new AtomicBoolean();
        if(copies.putIfAbsent(id,cancelled)!=null){result.error("operationBusy","Input preparation is active.",null);return;}
        worker.execute(()-> {
            File output=null;boolean outputOwned=false;
            try {
                File directory=new File(context.getFilesDir(),"processing/user/"+id).getCanonicalFile();
                File root=new File(context.getFilesDir(),"processing/user").getCanonicalFile();
                if(!directory.getPath().startsWith(root.getPath()+File.separator)||!directory.isDirectory())throw new SecurityException();
                output=new File(directory,"input.mp4");
                if(!output.createNewFile())throw new ProcessingRequest.Failure("outputConflict","Input working copy already exists.");
                outputOwned=true;
                try(InputStream input=context.getContentResolver().openInputStream(uri);FileOutputStream out=new FileOutputStream(output)) {
                    if(input==null)throw new ProcessingRequest.Failure("inputMissing","Selected input is unavailable.");
                    byte[] buffer=new byte[256*1024];int count;
                    while((count=input.read(buffer))!=-1) {
                        if(cancelled.get())throw new ProcessingRequest.Failure("cancelled","Input preparation cancelled.");
                        if(directory.getUsableSpace()<count+4L*1024*1024)throw new ProcessingRequest.Failure("insufficientStorage","Insufficient input working storage.");
                        out.write(buffer,0,count);
                    }
                    out.getFD().sync();
                }
                if(cancelled.get())throw new ProcessingRequest.Failure("cancelled","Input preparation cancelled.");
                String path=output.getPath();main.post(()->{if(attached)result.success(path);});
            } catch(Exception e) {
                if(outputOwned&&output!=null&&output.exists())output.delete();
                fail(result,e);
            } finally {copies.remove(id);}
        });
    }
    @Override public boolean onActivityResult(int requestCode,int resultCode,Intent data) {
        if(requestCode!=PICK)return false;
        MethodChannel.Result result=pending;pending=null;if(result==null)return true;
        if(resultCode!=Activity.RESULT_OK||data==null||data.getData()==null){result.success(null);return true;}
        Uri uri=data.getData();
        if(!"content".equals(uri.getScheme())){result.error("invalidInput","Expected a selected document URI.",null);return true;}
        worker.execute(()-> {
            try {
                String name="video.mp4";Long bytes=null;
                try(Cursor cursor=context.getContentResolver().query(uri,new String[]{OpenableColumns.DISPLAY_NAME,OpenableColumns.SIZE},null,null,null)) {
                    if(cursor!=null&&cursor.moveToFirst()){name=cursor.getString(0);if(!cursor.isNull(1))bytes=cursor.getLong(1);}
                }
                MediaExtractor extractor=new MediaExtractor();Map<String,Object> metadata=new HashMap<>();
                try {
                    extractor.setDataSource(context,uri,null);long duration=0;String videoMime=null;
                    ArrayList<Map<String,Object>> tracks=new ArrayList<>();
                    for(int i=0;i<extractor.getTrackCount();i++) {
                        MediaFormat format=extractor.getTrackFormat(i);Map<String,Object> track=new HashMap<>();
                        track.put("mime",format.getString(MediaFormat.KEY_MIME));
                        String mime=format.getString(MediaFormat.KEY_MIME);
                        if(videoMime==null && mime!=null && mime.startsWith("video/"))videoMime=mime;
                        if(format.containsKey(MediaFormat.KEY_DURATION))duration=Math.max(duration,format.getLong(MediaFormat.KEY_DURATION));
                        tracks.add(track);
                    }
                    if(duration<=0)throw new ProcessingRequest.Failure("invalidInput","Media duration cannot be read.");
                    metadata.put("durationUs",duration);metadata.put("tracks",tracks);
                    // Probe the chosen document, not a global codec assumption.
                    // A bounded retriever call does not persist any decoded media.
                    boolean decodable="video/avc".equals(videoMime);
                    if("video/hevc".equals(videoMime)||"video/dolby-vision".equals(videoMime)) {
                        try {
                            final long atUs=Math.min(3_000_000,Math.max(0,duration-1000));
                            Bitmap frame=BoundedRetrieval.run(()-> {
                                MediaMetadataRetriever retriever=new MediaMetadataRetriever();
                                try {retriever.setDataSource(context,uri);
                                    return retriever.getFrameAtTime(atUs,MediaMetadataRetriever.OPTION_CLOSEST);
                                } finally {retriever.release();}
                            },Bitmap::recycle,()->{},30_000);
                            decodable=frame!=null;
                            if(frame!=null)frame.recycle();
                        } catch(Exception ignored) {decodable=false;}
                    }
                    metadata.put("frameDecodeSupported",decodable);
                    metadata.put("videoCopySupported","video/avc".equals(videoMime)||"video/hevc".equals(videoMime)
                        ||("video/dolby-vision".equals(videoMime)&&android.os.Build.VERSION.SDK_INT>=33));
                } finally {extractor.release();}
                String reference=UUID.randomUUID().toString();selected.put(reference,uri);
                metadata.put("reference",reference);metadata.put("name",name);metadata.put("bytes",bytes);metadata.put("kind","saf");
                main.post(()->{if(attached)result.success(metadata);});
            } catch(Exception e){fail(result,e);}
        });return true;
    }
    private void fail(MethodChannel.Result result,Exception e) {
        String code=e instanceof ProcessingRequest.Failure?((ProcessingRequest.Failure)e).code:
            e instanceof SecurityException?"permissionDenied":"invalidInput";
        main.post(()->{if(attached)result.error(code,"Unable to read or prepare the selected video.",null);});
    }
}
