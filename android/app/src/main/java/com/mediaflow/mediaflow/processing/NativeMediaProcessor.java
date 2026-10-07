package com.mediaflow.mediaflow.processing;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMetadataRetriever;
import android.media.MediaMuxer;
import android.os.SystemClock;
import android.system.ErrnoException;
import android.system.Os;
import android.system.OsConstants;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

final class NativeMediaProcessor {
    interface Progress { void update(String state, Long processedUs, Long totalUs, boolean discrete); }
    private final File allowedRoot;
    NativeMediaProcessor(File root) { allowedRoot=root; }
    static Map<String,Object> failure(ProcessingRequest r, String code, String message,long ms,String diagnostic) {
        Map<String,Object> result=new HashMap<>();
        result.put("id",r.id); result.put("type",r.type); result.put("status",code.equals("cancelled")?"cancelled":"failed");
        result.put("outputs",new ArrayList<>()); result.put("elapsedMs",ms);
        Map<String,Object> error=new HashMap<>(); error.put("code",code); error.put("message",message);
        if(diagnostic!=null) error.put("diagnostic",diagnostic.substring(0,Math.min(diagnostic.length(),4096)));
        result.put("error",error); return result;
    }
    private static void check(OperationRegistry.Operation op) throws ProcessingRequest.Failure {
        if(op.cancelled) throw new ProcessingRequest.Failure("cancelled","Processing cancelled.");
    }
    Map<String,Object> run(ProcessingRequest r,OperationRegistry.Operation op,Progress progress) {
        long started=SystemClock.elapsedRealtime();
        File partial=null;
        boolean partialOwned=false;
        Map<String,Object> response=new HashMap<>();
        try {
            check(op);
            File parent=r.output.getParentFile().getCanonicalFile();
            // SAF/MediaStore exports need separate adapters, not a racy fallback.
            if(!parent.getPath().startsWith(allowedRoot.getCanonicalPath()+File.separator) || !parent.isDirectory())
                throw new ProcessingRequest.Failure("permissionDenied","Use an existing app-private output directory.");
            if(r.output.exists()) throw new ProcessingRequest.Failure("outputConflict","Output already exists.");
            long estimate=4L*1024*1024;
            for(File input:r.inputs) {
                if(!input.isFile()) throw new ProcessingRequest.Failure("inputMissing","Input file is missing.");
                if(input.getCanonicalFile().equals(r.output.getCanonicalFile())) throw new ProcessingRequest.Failure("outputConflict","Input and output must differ.");
                if(!r.type.equals("extractFrame")) estimate+=input.length();
            }
            if(parent.getUsableSpace()<estimate) throw new ProcessingRequest.Failure("insufficientStorage","Insufficient output storage reserve.");
            partial=new File(parent,r.output.getName()+"."+r.id.substring(0,Math.min(8,r.id.length()))+"."+UUID.randomUUID()+".partial");
            if(!partial.createNewFile()) throw new ProcessingRequest.Failure("outputConflict","Staging conflict.");
            partialOwned=true;
            if(r.type.equals("extractFrame")) frame(r,op,partial,progress);
            else copy(r,op,partial,progress);
            check(op); progress.update("validating",null,null,r.type.equals("extractFrame"));
            Map<String,Object> metadata=inspect(partial,r.type.equals("extractFrame"));
            synchronized(op) {
                check(op); progress.update("publishing",null,null,r.type.equals("extractFrame"));
                int error=AtomicOutputStore.publish(partial,r.output);
                if(error!=0)throw new ErrnoException("renameNoReplace",error);
                op.committed=true;
            }
            Map<String,Object> result=new HashMap<>();
            result.put("id",r.id);result.put("type",r.type);result.put("status","completed");
            result.put("outputs",Collections.singletonList(r.output.getPath()));result.put("metadata",metadata);
            result.put("elapsedMs",SystemClock.elapsedRealtime()-started); response.putAll(result);return response;
        } catch(Exception e) {
            String code=e instanceof ProcessingRequest.Failure?((ProcessingRequest.Failure)e).code:
                e instanceof ErrnoException ? errno(((ErrnoException)e).errno):
                e instanceof SecurityException?"permissionDenied":e instanceof IllegalArgumentException?"invalidInput":"processFailed";
            if(op.cancelled && !op.committed) code="cancelled";
            response.putAll(failure(r,code,code.equals("cancelled")?"Processing cancelled.":"Native processing failed.",SystemClock.elapsedRealtime()-started,
                e.getClass().getSimpleName()+": "+e.getMessage()));return response;
        } finally {
            if(partialOwned && partial!=null && partial.exists() && !partial.delete()) {
                // Dedicated owned staging path, no input or completed-output cleanup.
                response.clear();response.putAll(failure(r,"permissionDenied","Unable to clean owned staging file.",SystemClock.elapsedRealtime()-started,"Staging cleanup failed"));
            }
        }
    }
    private static String errno(int n) {
        if(n==OsConstants.EACCES||n==OsConstants.EPERM) return "permissionDenied";
        if(n==OsConstants.ENOSPC) return "insufficientStorage";
        if(n==OsConstants.EEXIST) return "outputConflict";
        if(n==OsConstants.ENOTSUP||n==OsConstants.EXDEV||n==OsConstants.ENOSYS) return "platformUnavailable";
        return "unknown";
    }
    private void frame(ProcessingRequest r,OperationRegistry.Operation op,File partial,Progress progress) throws Exception {
        progress.update("running",null,null,true);
        Bitmap image=null;
        try {
            image=BoundedRetrieval.run(()-> {
                MediaMetadataRetriever retriever=new MediaMetadataRetriever();
                try {
                    retriever.setDataSource(r.inputs[0].getPath());
                    String duration=retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
                    if(duration!=null && r.startUs>=Long.parseLong(duration)*1000) throw new ProcessingRequest.Failure("invalidInput","Frame time is outside media duration.");
                    return retriever.getFrameAtTime(r.startUs,MediaMetadataRetriever.OPTION_CLOSEST);
                } finally { retriever.release(); }
            },Bitmap::recycle,()->check(op),30_000);
            // Cooperative cancellation: blocking retrieval returns, then discard.
            check(op);
            if(image==null) throw new ProcessingRequest.Failure("unsupportedFormat","Frame cannot be decoded.");
            try(FileOutputStream out=new FileOutputStream(partial)) {
                if(!image.compress(Bitmap.CompressFormat.JPEG,90,out)) throw new IOException("JPEG encode failed");
                out.getFD().sync();
            }
            check(op);
        } finally { if(image!=null)image.recycle(); }
    }
    private static class Track {
        MediaExtractor extractor; int destination; MediaFormat format;
    }
    private static void source(MediaExtractor extractor,File input) throws ProcessingRequest.Failure {
        try { extractor.setDataSource(input.getPath()); }
        catch(IOException e) { throw new ProcessingRequest.Failure("invalidInput","Input media cannot be read."); }
    }
    private void copy(ProcessingRequest r,OperationRegistry.Operation op,File partial,Progress progress) throws Exception {
        List<Track> tracks=new ArrayList<>(); MediaMuxer muxer=null; boolean started=false;
        try {
            long base=r.startUs, end=r.endUs==null?Long.MAX_VALUE:r.endUs, duration=0;
            if(r.type.equals("trim")) {
                MediaExtractor p=new MediaExtractor();
                try {
                    source(p,r.inputs[0]);
                    for(int i=0;i<p.getTrackCount();i++) if(p.getTrackFormat(i).getString(MediaFormat.KEY_MIME).startsWith("video/")) {
                        p.selectTrack(i);p.seekTo(r.startUs,MediaExtractor.SEEK_TO_PREVIOUS_SYNC);base=Math.max(0,p.getSampleTime());break;
                    }
                } finally { p.release(); }
            }
            muxer=new MediaMuxer(partial.getPath(),MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
            boolean hasVideo=false,hasAudio=false;
            for(int fileIndex=0;fileIndex<r.inputs.length;fileIndex++) {
                long fileDuration=0;
                MediaExtractor p=new MediaExtractor();
                try {
                    source(p,r.inputs[fileIndex]);
                    boolean selectedVideo=false,selectedAudio=false;
                    for(int i=0;i<p.getTrackCount();i++) {
                        MediaFormat format=p.getTrackFormat(i);String mime=format.getString(MediaFormat.KEY_MIME);
                        boolean video=mime!=null&&mime.startsWith("video/"),audio=mime!=null&&mime.startsWith("audio/");
                        if(!video&&!audio)continue;
                        if(r.type.equals("extractAudio")&&!audio)continue;
                        if(r.type.equals("mux")&&((fileIndex==0&&!video)||(fileIndex==1&&!audio)))continue;
                        if((video&&selectedVideo)||(audio&&selectedAudio))continue;
                        boolean hevcTrim=r.type.equals("trim") && (mime.equals("video/hevc")
                            ||(mime.equals("video/dolby-vision")&&android.os.Build.VERSION.SDK_INT>=33));
                        if(!mime.equals("video/avc")&&!mime.equals("audio/mp4a-latm")&&!hevcTrim) throw new ProcessingRequest.Failure("unsupportedFormat","Selected track cannot be copied to this output.");
                        Track t=new Track(); t.format=format;t.extractor=new MediaExtractor();tracks.add(t);
                        source(t.extractor,r.inputs[fileIndex]);t.extractor.selectTrack(i);t.extractor.seekTo(base,MediaExtractor.SEEK_TO_PREVIOUS_SYNC);
                        t.destination=muxer.addTrack(format);
                        if(video){hasVideo=true;selectedVideo=true;}else{hasAudio=true;selectedAudio=true;}
                        if(format.containsKey(MediaFormat.KEY_DURATION)) fileDuration=Math.max(fileDuration,format.getLong(MediaFormat.KEY_DURATION));
                    }
                } finally {p.release();}
                duration=r.type.equals("mux") && fileIndex>0?Math.min(duration,fileDuration):Math.max(duration,fileDuration);
            }
            if((!r.type.equals("trim")&&!hasAudio)||(!r.type.equals("extractAudio")&&!hasVideo)) throw new ProcessingRequest.Failure("invalidInput","Required media track is missing.");
            if(base>=duration || (r.endUs!=null && r.endUs>duration+100000)) throw new ProcessingRequest.Failure("invalidInput","Requested times are outside media duration.");
            if(r.type.equals("mux"))end=Math.min(end,duration);
            long total=(r.type.equals("trim")?end:duration)-base;
            muxer.start();started=true;
            int capacity=1024*1024;
            for(Track t:tracks) if(t.format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) capacity=Math.max(capacity,t.format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE));
            if(capacity>16*1024*1024)throw new ProcessingRequest.Failure("unsupportedFormat","Media packet exceeds supported buffer size.");
            ByteBuffer buffer=ByteBuffer.allocateDirect(capacity); MediaCodec.BufferInfo info=new MediaCodec.BufferInfo();
            long lastEvent=0,processed=0;
            progress.update("running",0L,total,false);
            while(true) {
                check(op);Track next=null;long timestamp=Long.MAX_VALUE;
                for(Track t:tracks){long time=t.extractor.getSampleTime();while(time>=0&&time<base){t.extractor.advance();time=t.extractor.getSampleTime();}
                    if(time>=0&&time<end&&time<timestamp){timestamp=time;next=t;}}
                if(next==null)break;
                if(next.extractor.getSampleSize()>capacity)throw new ProcessingRequest.Failure("unsupportedFormat","Media packet exceeds buffer size.");
                int flags=next.extractor.getSampleFlags();
                if((flags&(MediaExtractor.SAMPLE_FLAG_ENCRYPTED|MediaExtractor.SAMPLE_FLAG_PARTIAL_FRAME))!=0)throw new ProcessingRequest.Failure("unsupportedFormat","Encrypted or partial samples are unsupported.");
                buffer.clear();int size=next.extractor.readSampleData(buffer,0);
                if(size<0)throw new IOException("Sample read failed");
                info.set(0,size,timestamp-base,(flags&MediaExtractor.SAMPLE_FLAG_SYNC)!=0?MediaCodec.BUFFER_FLAG_KEY_FRAME:0);
                muxer.writeSampleData(next.destination,buffer,info);next.extractor.advance();processed=Math.max(processed,timestamp-base);
                long now=SystemClock.elapsedRealtime();if(now-lastEvent>=50){progress.update("running",processed,total,false);lastEvent=now;}
            }
            check(op);muxer.stop();started=false;progress.update("running",processed,total,false);
        } finally {
            for(Track t:tracks)t.extractor.release();
            if(muxer!=null){if(started){try{muxer.stop();}catch(RuntimeException ignored){}}muxer.release();}
        }
    }
    private static Map<String,Object> inspect(File file,boolean image) throws Exception {
        if(file.length()==0)throw new IOException("Empty output");
        Map<String,Object> data=new HashMap<>();data.put("bytes",file.length());
        if(image){Bitmap bitmap=BitmapFactory.decodeFile(file.getPath());if(bitmap==null)throw new IOException("JPEG verification failed");
            data.put("width",bitmap.getWidth());data.put("height",bitmap.getHeight());bitmap.recycle();}
        else {MediaExtractor extractor=new MediaExtractor();try{extractor.setDataSource(file.getPath());List<Map<String,Object>> tracks=new ArrayList<>();long duration=0;
            for(int i=0;i<extractor.getTrackCount();i++){MediaFormat f=extractor.getTrackFormat(i);Map<String,Object> track=new HashMap<>();track.put("mime",f.getString(MediaFormat.KEY_MIME));tracks.add(track);
                if(f.containsKey(MediaFormat.KEY_DURATION))duration=Math.max(duration,f.getLong(MediaFormat.KEY_DURATION));}
            if(tracks.isEmpty())throw new IOException("No output tracks");data.put("tracks",tracks);data.put("durationUs",duration);
        }finally{extractor.release();}}
        return data;
    }
}
