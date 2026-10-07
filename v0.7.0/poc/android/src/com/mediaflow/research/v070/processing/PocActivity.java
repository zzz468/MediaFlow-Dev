package com.mediaflow.research.v070.processing;

import android.app.Activity;
import android.os.Bundle;
import android.os.Build;
import android.content.Intent;
import android.net.Uri;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.ScrollView;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.concurrent.atomic.AtomicInteger;

public final class PocActivity extends Activity {
    private TextView status;
    private File workspace;
    private volatile NativeEngine engine;
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        workspace = new File(getExternalFilesDir(null), "processing-poc");
        if (!workspace.isDirectory() && !workspace.mkdirs()) throw new IllegalStateException("Storage unavailable");
        LinearLayout layout = new LinearLayout(this); layout.setOrientation(LinearLayout.VERTICAL);
        status = new TextView(this); status.setText("Isolated MediaFlow Phase 2 PoC\nLocal files only; no Internet permission."); layout.addView(status);
        Button run = new Button(this); run.setText("Run five operations twice");
        run.setOnClickListener(v -> start()); layout.addView(run);
        Button cancel = new Button(this); cancel.setText("Cancel current operation");
        cancel.setOnClickListener(v -> { if (engine != null) engine.cancel(); }); layout.addView(cancel);
        for (NativeEngine.Operation op : NativeEngine.Operation.values()) {
            Button open = new Button(this); open.setText("Open " + op.name() + " in system app");
            open.setOnClickListener(v -> open(op)); layout.addView(open);
        }
        ScrollView scroll = new ScrollView(this); scroll.addView(layout); setContentView(scroll);
        String open = getIntent().getStringExtra("open");
        if (open != null) open(NativeEngine.Operation.valueOf(open));
        if (getIntent().getBooleanExtra("run", false)) start();
        if (getIntent().getBooleanExtra("checkRestart", false)) {
            File stale = new File(workspace, "restart-owned.partial");
            File marker = new File(workspace, "restart-owned.marker");
            boolean existed = stale.exists();
            boolean cleaned = !existed;
            if (marker.exists()) { cleaned = !stale.exists() || stale.delete(); if (cleaned) marker.delete(); }
            try {
                JSONObject result = new JSONObject().put("staleExisted", existed).put("cleaned", cleaned)
                    .put("completedOutputPreserved", new File(workspace, "round-0-mux.mp4").exists());
                write(new File(workspace, "restart.json"), result.toString(2)); status.setText(result.toString(2));
            } catch (Exception e) { status.setText(e.toString()); }
        }
    }
    private synchronized void start() {
        if (engine != null) return;
        engine = new NativeEngine();
        new Thread(() -> {
            try { runSuite(); } catch (Exception e) {
                try { write(new File(workspace, "failure.txt"), e.toString()); } catch (Exception ignored) { }
                runOnUiThread(() -> status.setText(e.toString()));
            } finally { engine = null; }
        }, "processing-poc").start();
    }
    private static String extension(NativeEngine.Operation op) {
        return op == NativeEngine.Operation.extractAudio ? "m4a" : op == NativeEngine.Operation.extractFrame ? "jpg" : "mp4";
    }
    private void open(NativeEngine.Operation op) {
        String name = "round-0-" + op.name() + "." + extension(op);
        if (!new File(workspace, name).exists()) { status.setText("Run suite first: output missing"); return; }
        Intent intent = new Intent(Intent.ACTION_VIEW).setDataAndType(
            Uri.parse("content://com.mediaflow.research.v070.processing.outputs/" + name),
            op == NativeEngine.Operation.extractAudio ? "audio/mp4" : op == NativeEngine.Operation.extractFrame ? "image/jpeg" : "video/mp4")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        try { startActivity(intent); } catch (Exception e) { status.setText("System open failed: " + e); }
    }
    private void runSuite() throws Exception {
        JSONObject report = new JSONObject().put("abi", Build.SUPPORTED_ABIS[0]).put("api", Build.VERSION.SDK_INT)
            .put("package", getPackageName()).put("workspace", workspace.getAbsolutePath());
        JSONArray inputs = new JSONArray();
        File input = fixture("sample.mp4"), video = fixture("video-only.mp4"), audio = fixture("audio-only.m4a");
        for (File file : new File[]{input, video, audio}) inputs.put(new JSONObject().put("name", file.getName())
            .put("bytes", file.length()).put("sha256", hash(file)).put("metadata", NativeEngine.inspect(file, false)));
        report.put("inputs", inputs);
        JSONArray operations = new JSONArray();
        for (int round = 0; round < 2; round++) {
            for (NativeEngine.Operation op : NativeEngine.Operation.values()) {
                File output = new File(workspace, "round-" + round + "-" + op.name() + "." + extension(op));
                if (output.exists()) throw new IllegalStateException("Previous output exists; use a new isolated package/workspace");
                File[] files = op == NativeEngine.Operation.mux ? new File[]{video, audio} : new File[]{input};
                long start = op == NativeEngine.Operation.trim ? 2000000 : op == NativeEngine.Operation.extractFrame ? 3000000 : 0;
                long end = op == NativeEngine.Operation.trim ? 6000000 : 12000000;
                JSONArray progress = new JSONArray();
                JSONObject result = engine.execute(new NativeEngine.Request(op, files, output, start, end), (p, total) -> {
                    try { progress.put(new JSONObject().put("processedUs", p).put("totalUs", total)); } catch (Exception e) { throw new RuntimeException(e); }
                }).put("round", round).put("progress", progress).put("output", output.getName());
                if (output.exists()) result.put("sha256", hash(output));
                operations.put(result); report.put("operations", operations);
                write(new File(workspace, "report.json"), report.toString(2));
                if (!"completed".equals(result.getString("state"))) throw new IllegalStateException(result.toString());
            }
        }
        AtomicInteger count = new AtomicInteger();
        File cancelOutput = new File(workspace, "cancel.mp4");
        JSONObject cancel = engine.execute(new NativeEngine.Request(NativeEngine.Operation.remux,
            new File[]{input}, cancelOutput, 0, 12000000), (p, total) -> { count.incrementAndGet(); engine.cancel(); });
        cancel.put("events", count.get()).put("finalExists", cancelOutput.exists()).put("partialExists", new File(workspace, "cancel.mp4.partial").exists());
        if (!"cancelled".equals(cancel.getString("state")) || cancelOutput.exists()) throw new IllegalStateException("Cancel failed");
        report.put("cancel", cancel);
        File bad = new File(workspace, "corrupt.mp4"); write(bad, "not media");
        JSONObject failure = engine.execute(new NativeEngine.Request(NativeEngine.Operation.extractAudio,
            new File[]{bad}, new File(workspace, "failed.m4a"), 0, 12000000), (p, total) -> {});
        if (!"failed".equals(failure.getString("state")) || new File(workspace, "failed.m4a").exists()) throw new IllegalStateException("Failure published");
        report.put("negativeTest", failure);
        for (File file : new File[]{input, video, audio}) if (!hash(file).equals(inputs.getJSONObject(
            file.equals(input) ? 0 : file.equals(video) ? 1 : 2).getString("sha256"))) throw new IllegalStateException("Input changed");
        // Controlled stale-output test: marker authorizes only this fixed filename.
        write(new File(workspace, "restart-owned.partial"), "incomplete owned output");
        write(new File(workspace, "restart-owned.marker"), "poc owned");
        report.put("state", "completed").put("nativeLibraryBytes", 0).put("inputHashesUnchanged", true);
        write(new File(workspace, "report.json"), report.toString(2));
        runOnUiThread(() -> status.setText("Five operations x2 PASS\nProgress/cancel/invalid input PASS\nOpen each output in system app below.\nReport: " + workspace));
    }
    private File fixture(String name) throws Exception {
        File file = new File(workspace, name);
        if (file.exists()) throw new IllegalStateException("Existing fixture: " + name);
        try (InputStream in = getAssets().open(name); FileOutputStream out = new FileOutputStream(file)) {
            byte[] buffer = new byte[65536]; int n; while ((n = in.read(buffer)) >= 0) out.write(buffer, 0, n);
        }
        return file;
    }
    private static void write(File file, String text) throws Exception {
        try (FileOutputStream out = new FileOutputStream(file)) { out.write(text.getBytes(StandardCharsets.UTF_8)); }
    }
    private static String hash(File file) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (InputStream in = new java.io.FileInputStream(file)) { byte[] b = new byte[65536]; int n; while ((n = in.read(b)) >= 0) digest.update(b, 0, n); }
        StringBuilder result = new StringBuilder(); for (byte b : digest.digest()) result.append(String.format("%02x", b & 255)); return result.toString();
    }
}
