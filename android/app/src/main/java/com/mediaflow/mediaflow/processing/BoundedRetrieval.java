package com.mediaflow.mediaflow.processing;

import java.util.concurrent.Callable;
import java.util.concurrent.atomic.AtomicBoolean;

/** Bounded waiting, not forced interruption of an Android codec/Binder call. */
final class BoundedRetrieval {
    private static final AtomicBoolean active = new AtomicBoolean();
    interface Disposal<T> { void close(T value); }
    interface Cancellation { void check() throws ProcessingRequest.Failure; }
    static boolean isBusy() { return active.get(); }
    private static final class Job<T> {
        T value;
        Exception error;
        boolean finished, abandoned;
    }
    static <T> T run(Callable<T> call, Disposal<T> disposal,
                     Cancellation cancellation, long timeoutMs) throws Exception {
        if (!active.compareAndSet(false, true)) {
            throw new ProcessingRequest.Failure("operationBusy", "A system frame call is still draining.");
        }
        Job<T> job = new Job<>();
        Thread thread = new Thread(() -> {
            T value = null;
            Exception error = null;
            try { value = call.call(); }
            catch (Exception e) { error = e; }
            catch (LinkageError | OutOfMemoryError e) { error = new IllegalStateException("System frame retrieval failed", e); }
            finally {
                synchronized (job) {
                    if (job.abandoned && value != null) disposal.close(value);
                    else { job.value = value; job.error = error; }
                    job.finished = true;
                    active.set(false);
                    job.notifyAll();
                }
            }
        }, "mediaflow-frame-retrieval");
        thread.setDaemon(true);
        try { thread.start(); }
        catch (RuntimeException | Error e) { active.set(false); throw e; }
        long deadline = System.nanoTime() + timeoutMs * 1_000_000L;
        synchronized (job) {
            try {
                while (!job.finished) {
                    cancellation.check();
                    long remaining = deadline - System.nanoTime();
                    if (remaining <= 0) {
                        throw new ProcessingRequest.Failure("processFailed", "System frame retrieval timed out.");
                    }
                    job.wait(Math.max(1, Math.min(50, remaining / 1_000_000L)));
                }
                cancellation.check();
                if (job.error != null) throw job.error;
                T value = job.value;
                job.value = null;
                return value;
            } catch (Exception e) {
                job.abandoned = true;
                if (job.value != null) { disposal.close(job.value); job.value = null; }
                // The owned system call may still be blocked. Keep active=true
                // until it returns; no Thread.stop, no unbounded replacement jobs.
                throw e;
            }
        }
    }
}
