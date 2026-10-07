package com.mediaflow.mediaflow.processing;

import java.io.File;
import java.util.List;
import java.util.Arrays;
import java.util.Map;

/** Pure wire validation; Android media APIs live in a separate worker. */
public final class ProcessingRequest {
    public final String id, type, container;
    public final File[] inputs;
    public final File output;
    public final long startUs;
    public final Long endUs;
    private ProcessingRequest(String id, String type, String container, File[] inputs, File output, long start, Long end) {
        this.id=id; this.type=type; this.container=container; this.inputs=inputs;
        this.output=output; this.startUs=start; this.endUs=end;
    }
    public static final class Failure extends Exception {
        public final String code;
        public Failure(String code, String message) { super(message); this.code=code; }
    }
    public static ProcessingRequest decode(Object raw) throws Failure {
        if (!(raw instanceof Map)) throw new Failure("invalidInput", "Invalid processing request.");
        Map<?,?> map=(Map<?,?>)raw;
        String id=string(map,"id"), type=string(map,"type"), container=string(map,"container"), output=string(map,"output");
        if (!id.matches("[a-zA-Z0-9_-]{1,64}") || !Arrays.asList("trim","extractAudio","mux","remux","extractFrame").contains(type))
            throw new Failure("invalidInput","Invalid operation id or type.");
        Object items=map.get("inputs");
        if (!(items instanceof List) || ((List<?>)items).size() != (type.equals("mux")?2:1))
            throw new Failure("invalidInput","Incorrect input count.");
        File[] inputs=new File[((List<?>)items).size()];
        for(int i=0;i<inputs.length;i++) {
            Object item=((List<?>)items).get(i);
            if(!(item instanceof String) || !new File((String)item).isAbsolute()) throw new Failure("invalidInput","Absolute local inputs are required.");
            inputs[i]=new File((String)item);
        }
        if(!new File(output).isAbsolute()) throw new Failure("invalidInput","Absolute local output is required.");
        long start=number(map.get("startUs"),0);
        Long end=map.get("endUs")==null?null:number(map.get("endUs"),0);
        if(start<0 || (end!=null && end<=start) || (type.equals("trim") && end==null)
            || (!type.equals("trim")&&!type.equals("extractFrame")&&start!=0) || (!type.equals("trim")&&end!=null))
            throw new Failure("invalidInput","Invalid media times.");
        boolean allowed=type.equals("extractFrame")?container.equals("jpeg"):
            type.equals("extractAudio")?container.equals("m4a"):container.equals("mp4");
        if(!allowed) throw new Failure("unsupportedFormat","Native processing supports MP4/M4A/JPEG outputs.");
        return new ProcessingRequest(id,type,container,inputs,new File(output),start,end);
    }
    private static String string(Map<?,?> map,String key) throws Failure {
        Object value=map.get(key);
        if(!(value instanceof String) || ((String)value).isEmpty()) throw new Failure("invalidInput","Missing processing field.");
        return (String)value;
    }
    private static long number(Object value,long fallback) throws Failure {
        if(value==null) return fallback;
        if(!(value instanceof Long) && !(value instanceof Integer)) throw new Failure("invalidInput","Media times must be integers.");
        return ((Number)value).longValue();
    }
}
