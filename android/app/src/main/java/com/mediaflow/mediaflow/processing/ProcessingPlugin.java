package com.mediaflow.mediaflow.processing;

import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import androidx.core.content.FileProvider;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Engine-owned, application-context worker. Activity recreation never starts work. */
public final class ProcessingPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private MethodChannel methods;
    private EventChannel events;
    private EventChannel.EventSink sink;
    private final Handler main=new Handler(Looper.getMainLooper());
    private ExecutorService worker;
    private Context context;
    private volatile boolean attached;
    private volatile OperationRegistry.Operation owned;
    private Map<String,Object> latestProgress;
    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        context=binding.getApplicationContext();attached=true;
        worker=Executors.newSingleThreadExecutor();
        methods=new MethodChannel(binding.getBinaryMessenger(),"com.mediaflow.mediaflow/processing");
        events=new EventChannel(binding.getBinaryMessenger(),"com.mediaflow.mediaflow/processing/events");
        methods.setMethodCallHandler(this);events.setStreamHandler(this);
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        attached=false;methods.setMethodCallHandler(null);events.setStreamHandler(null);sink=null;
        OperationRegistry.Operation op=owned;if(op!=null)op.cancel();
        // Let cooperative cleanup finish; don't interrupt a blocking Retriever call.
        worker.shutdown();
    }
    @Override public void onListen(Object arguments,EventChannel.EventSink value) { sink=value;if(latestProgress!=null)sink.success(latestProgress); }
    @Override public void onCancel(Object arguments) { sink=null; }
    @Override public void onMethodCall(MethodCall call,MethodChannel.Result result) {
        if(call.method.equals("cancel")) {
            String id=call.argument("id");result.success(id!=null&&OperationRegistry.INSTANCE.cancel(id));return;
        }
        if(call.method.equals("openOutput")) {
            // A storage utility for the isolated developer harness, no UI integration.
            try {
                String path=call.argument("path");File file=new File(path).getCanonicalFile();
                File root=new File(context.getFilesDir(),"processing").getCanonicalFile();
                if(!file.isFile()||!file.getPath().startsWith(root.getPath()+File.separator)||file.getName().endsWith(".partial"))throw new SecurityException();
                String mime=file.getName().endsWith(".jpg")?"image/jpeg":file.getName().endsWith(".m4a")?"audio/mp4":"video/mp4";
                Intent view=new Intent(Intent.ACTION_VIEW).setDataAndType(FileProvider.getUriForFile(context,context.getPackageName()+".downloads",file),mime)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                context.startActivity(Intent.createChooser(view,"Open processing output").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));result.success(null);
            } catch(Exception e) {result.error("permissionDenied","Cannot open processing output.",null);} return;
        }
        if(!call.method.equals("process")){result.notImplemented();return;}
        ProcessingRequest request;
        try {request=ProcessingRequest.decode(call.arguments);}
        catch(ProcessingRequest.Failure e){result.error(e.code,e.getMessage(),null);return;}
        if(BoundedRetrieval.isBusy()) {
            result.success(NativeMediaProcessor.failure(request,"operationBusy","A system frame call is still draining.",0,null));return;
        }
        OperationRegistry.Operation op;
        try {op=OperationRegistry.INSTANCE.claim(request.id);}
        catch(ProcessingRequest.Failure e){result.success(NativeMediaProcessor.failure(request,e.code,e.getMessage(),0,null));return;}
        owned=op;
        worker.execute(()-> {
            Map<String,Object> reply;
            try {
                reply=new NativeMediaProcessor(context.getFilesDir()).run(request,op,(state,processed,total,discrete)-> {
                    Map<String,Object> event=new HashMap<>();event.put("id",request.id);event.put("state",state);
                    event.put("processedUs",processed);event.put("totalUs",total);event.put("discrete",discrete);
                    main.post(()->{if(attached){latestProgress=event;if(sink!=null)sink.success(event);}});
                });
            } finally {OperationRegistry.INSTANCE.release(op);owned=null;}
            main.post(()->{if(attached){latestProgress=null;result.success(reply);}});
        });
    }
}
