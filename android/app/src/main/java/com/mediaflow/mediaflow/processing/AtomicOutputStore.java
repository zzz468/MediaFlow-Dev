package com.mediaflow.mediaflow.processing;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/** Small owned filesystem bridge, no media codecs or external libraries. */
final class AtomicOutputStore {
    private static boolean loaded;
    private static native int renameNoReplace(byte[] source,byte[] target);
    static synchronized int publish(File source,File target) throws ProcessingRequest.Failure {
        if(!loaded){
            try{System.loadLibrary("mediaflow_processing_storage");loaded=true;}
            catch(UnsatisfiedLinkError e){throw new ProcessingRequest.Failure("platformUnavailable","Atomic output storage is unavailable.");}
        }
        byte[] from=source.getPath().getBytes(StandardCharsets.UTF_8),to=target.getPath().getBytes(StandardCharsets.UTF_8);
        return renameNoReplace(Arrays.copyOf(from,from.length+1),Arrays.copyOf(to,to.length+1));
    }
}
