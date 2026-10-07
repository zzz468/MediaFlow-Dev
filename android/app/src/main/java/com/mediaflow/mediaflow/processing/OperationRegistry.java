package com.mediaflow.mediaflow.processing;
import java.util.HashSet;
import java.util.Set;

/** Process-wide guard survives Activity and Flutter engine recreation. */
public final class OperationRegistry {
    public static final OperationRegistry INSTANCE=new OperationRegistry();
    private final Set<String> used=new HashSet<>();
    private Operation active;
    public static final class Operation {
        public final String id;
        public volatile boolean cancelled, committed;
        Operation(String id) { this.id=id; }
        public synchronized boolean cancel() {
            if(cancelled || committed) return false;
            cancelled=true; return true;
        }
    }
    public synchronized Operation claim(String id) throws ProcessingRequest.Failure {
        if(used.contains(id)) throw new ProcessingRequest.Failure("outputConflict","Operation id was already used.");
        if(active!=null) throw new ProcessingRequest.Failure("operationBusy","Another native operation is active.");
        used.add(id); active=new Operation(id); return active;
    }
    public synchronized void release(Operation op) { if(active==op) active=null; }
    public synchronized boolean cancel(String id) { return active!=null && active.id.equals(id) && active.cancel(); }
}
