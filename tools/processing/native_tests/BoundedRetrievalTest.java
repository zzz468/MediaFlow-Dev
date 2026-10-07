package com.mediaflow.mediaflow.processing;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicInteger;
public final class BoundedRetrievalTest {
    static int assertions;
    static void check(boolean value){assertions++;if(!value)throw new AssertionError();}
    static void drain() throws Exception {
        long end=System.nanoTime()+2_000_000_000L;
        while(BoundedRetrieval.isBusy() && System.nanoTime()<end)Thread.sleep(1);
        check(!BoundedRetrieval.isBusy());
    }
    public static void main(String[] args) throws Exception {
        AtomicInteger closed=new AtomicInteger();
        check(BoundedRetrieval.run(()->"frame",v->closed.incrementAndGet(),()->{},1000).equals("frame"));
        check(closed.get()==0);
        CountDownLatch release=new CountDownLatch(1);
        try {BoundedRetrieval.run(()->{release.await();return "late";},v->closed.incrementAndGet(),()->{},20);throw new AssertionError();}
        catch(ProcessingRequest.Failure e){check(e.code.equals("processFailed"));}
        check(BoundedRetrieval.isBusy());
        try {BoundedRetrieval.run(()->"overlap",v->{},()->{},1000);throw new AssertionError();}
        catch(ProcessingRequest.Failure e){check(e.code.equals("operationBusy"));}
        release.countDown();drain();check(closed.get()==1);
        CountDownLatch cancelRelease=new CountDownLatch(1);
        try {BoundedRetrieval.run(()->{cancelRelease.await();return "cancelled-frame";},v->closed.incrementAndGet(),()->{throw new ProcessingRequest.Failure("cancelled","cancel");},1000);throw new AssertionError();}
        catch(ProcessingRequest.Failure e){check(e.code.equals("cancelled"));}
        cancelRelease.countDown();drain();check(closed.get()==2);
        try {BoundedRetrieval.run(()->{throw new IllegalArgumentException("codec");},v->{},()->{},1000);throw new AssertionError();}
        catch(IllegalArgumentException e){check(e.getMessage().equals("codec"));}
        drain();
        System.out.println("Bounded frame retrieval: "+assertions+" assertions PASS");
    }
}
