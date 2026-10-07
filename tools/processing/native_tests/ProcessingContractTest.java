package com.mediaflow.mediaflow.processing;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
public final class ProcessingContractTest {
    static String absolute(String name){return new java.io.File(name).getAbsolutePath();}
    static void check(boolean value){if(!value)throw new AssertionError();}
    static Map<String,Object> wire(){Map<String,Object> m=new HashMap<>();m.put("id","native_1");m.put("type","mux");m.put("container","mp4");
        m.put("inputs",Arrays.asList(absolute("video.mp4"),absolute("audio.m4a")));m.put("output",absolute("result.mp4"));m.put("startUs",0L);return m;}
    static void fail(Map<String,Object> m,String code)throws Exception{try{ProcessingRequest.decode(m);throw new AssertionError();}catch(ProcessingRequest.Failure e){check(e.code.equals(code));}}
    public static void main(String[] args)throws Exception{
        check(ProcessingRequest.decode(wire()).inputs.length==2);
        Map<String,Object> m=wire();m.put("id","../unsafe");fail(m,"invalidInput");
        m=wire();m.put("container","matroska");fail(m,"unsupportedFormat");
        m=wire();m.put("startUs",-1L);fail(m,"invalidInput");
        m=wire();m.put("type","trim");m.put("inputs",Arrays.asList(absolute("video.mp4")));fail(m,"invalidInput");
        m.put("endUs",3000000L);check(ProcessingRequest.decode(m).endUs==3000000L);
        m=wire();m.put("inputs",Arrays.asList("relative.mp4","/audio"));fail(m,"invalidInput");
        OperationRegistry registry=new OperationRegistry();OperationRegistry.Operation op=registry.claim("one");
        try{registry.claim("one");throw new AssertionError();}catch(ProcessingRequest.Failure e){check(e.code.equals("outputConflict"));}
        try{registry.claim("two");throw new AssertionError();}catch(ProcessingRequest.Failure e){check(e.code.equals("operationBusy"));}
        check(!registry.cancel("other"));check(registry.cancel("one"));check(!registry.cancel("one"));registry.release(op);check(!registry.cancel("one"));
        try{registry.claim("one");throw new AssertionError();}catch(ProcessingRequest.Failure e){check(e.code.equals("outputConflict"));}
        OperationRegistry.Operation two=registry.claim("two");two.committed=true;check(!registry.cancel("two"));registry.release(two);
        System.out.println("Native wire/registry assertions: 15 PASS");
    }
}
