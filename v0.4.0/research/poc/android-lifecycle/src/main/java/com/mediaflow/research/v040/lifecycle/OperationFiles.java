package com.mediaflow.research.v040.lifecycle;

import android.content.Context;
import android.system.Os;
import android.system.OsConstants;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import org.json.JSONObject;

final class OperationFiles {
    static File root(Context c) {return new File(c.getFilesDir(),"worker_operations");}
    static File registration(Context c,String op) {return new File(root(c),op+".registration.json");}
    static File marker(Context c,String op) {return new File(root(c),op+".worker.json");}
    static File canonicalBase(File file) {try{return file.getCanonicalFile();}catch(Exception e){throw new IllegalStateException("basePath",e);}}
    static File profile(Context c,String op) {return new File(canonicalBase(new File(c.getApplicationInfo().dataDir)),"app_webview_mf040_"+op);}
    static File cache(Context c,String op) {return new File(canonicalBase(c.getCacheDir()),"webview_mf040_"+op);}
    static File metadata(Context c,String op) {return new File(canonicalBase(c.getNoBackupFilesDir()),".webview_mf040_"+op);}
    static String startTicks(int pid) throws Exception {
        String value=new String(Files.readAllBytes(new File("/proc/"+pid+"/stat").toPath()),StandardCharsets.UTF_8);
        // comm may contain spaces and parentheses; field 22 follows the final ')'.
        return value.substring(value.lastIndexOf(')')+2).split("\\s+")[19];
    }
    static void noLink(File file) throws Exception {
        if(OsConstants.S_ISLNK(Os.lstat(file.getAbsolutePath()).st_mode))throw new SecurityException("symlink");
    }
    static void write(File file,JSONObject data) throws Exception {
        if(!file.getParentFile().exists()&&!file.getParentFile().mkdirs())throw new IllegalStateException("markerRoot");
        noLink(file.getParentFile());
        if(file.exists())noLink(file);
        File temporary=new File(file.getParentFile(),file.getName()+".tmp");
        if(temporary.exists())throw new SecurityException("temporaryExists");
        Files.write(temporary.toPath(),data.toString().getBytes(StandardCharsets.UTF_8));
        if(!temporary.renameTo(file))throw new IllegalStateException("markerRename");
    }
    static JSONObject read(File file) throws Exception {
        noLink(file);if(file.length()>8192)throw new SecurityException("markerBudget");
        return new JSONObject(new String(Files.readAllBytes(file.toPath()),StandardCharsets.UTF_8));
    }
    static void treeCheck(File file,File expected) throws Exception {
        if(!file.exists())return;
        noLink(file);
        String base=expected.getAbsolutePath();
        if(!file.getCanonicalPath().equals(file.getAbsolutePath())||
           !(file.getAbsolutePath().equals(base)||file.getAbsolutePath().startsWith(base+File.separator)))throw new SecurityException("pathBoundary");
        if(file.isDirectory()){
            File[] children=file.listFiles();if(children==null)throw new IllegalStateException("directoryUnreadable");
            for(File child:children)treeCheck(child,expected);
        }
    }
    static void erase(File file) throws Exception {
        if(!file.exists())return;
        if(file.isDirectory())for(File child:file.listFiles())erase(child);
        if(!file.delete())throw new IllegalStateException("deleteFailed");
    }
}
