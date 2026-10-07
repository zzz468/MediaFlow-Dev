package com.mediaflow.research.v070.processing;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMetadataRetriever;
import android.media.MediaMuxer;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CancellationException;

// Phase 2 only: fixed local MP4/AAC scope, no production dependency.
public final class NativeEngine {
    public enum Operation { trim, extractAudio, mux, remux, extractFrame }
    public interface Progress { void update(long processedUs, long totalUs); }
    public static final class Request {
        public final Operation operation;
        public final File[] inputs;
        public final File output;
        public final long startUs, endUs;
        public Request(Operation op, File[] in, File out, long start, long end) {
            operation = op; inputs = in; output = out; startUs = start; endUs = end;
        }
    }
    private volatile boolean cancelled;
    public void cancel() { cancelled = true; }
    private void checkCancelled() { if (cancelled) throw new CancellationException(); }

    public JSONObject execute(Request r, Progress progress) throws Exception {
        if (r.inputs.length != (r.operation == Operation.mux ? 2 : 1) ||
            r.startUs < 0 || r.endUs <= r.startUs || r.output.exists())
            throw new IllegalArgumentException("Invalid request or existing output");
        for (File input : r.inputs) {
            if (!input.isFile() || input.getCanonicalFile().equals(r.output.getCanonicalFile()))
                throw new IllegalArgumentException("Input missing or overwrite requested");
        }
        if (r.output.getParentFile().getUsableSpace() < 4 * 1024 * 1024)
            throw new IllegalStateException("Insufficient storage reserve");
        cancelled = false;
        long started = System.nanoTime();
        File partial = new File(r.output.getParentFile(), r.output.getName() + ".partial");
        if (!partial.createNewFile()) throw new IllegalStateException("Staging already exists");
        JSONObject result = new JSONObject().put("operation", r.operation.name());
        try {
            if (r.operation == Operation.extractFrame) frame(r, partial, progress);
            else copy(r, partial, progress);
            checkCancelled();
            JSONObject metadata = inspect(partial, r.operation == Operation.extractFrame);
            checkCancelled();
            if (r.output.exists() || !partial.renameTo(r.output))
                throw new IllegalStateException("Publish failed");
            result.put("state", "completed").put("bytes", r.output.length()).put("metadata", metadata);
        } catch (CancellationException e) {
            result.put("state", "cancelled").put("bytes", 0);
        } catch (Exception e) {
            result.put("state", "failed").put("error", e.getClass().getSimpleName() + ": " + e.getMessage());
        } finally {
            if (partial.exists() && !partial.delete()) throw new IllegalStateException("Staging cleanup failed");
        }
        return result.put("elapsedMs", (System.nanoTime() - started) / 1000000);
    }

    private void frame(Request r, File partial, Progress progress) throws Exception {
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        Bitmap bitmap = null;
        try {
            retriever.setDataSource(r.inputs[0].getAbsolutePath());
            bitmap = retriever.getFrameAtTime(r.startUs, MediaMetadataRetriever.OPTION_CLOSEST);
            checkCancelled();
            if (bitmap == null) throw new IllegalStateException("Frame missing");
            try (FileOutputStream stream = new FileOutputStream(partial)) {
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 90, stream))
                    throw new IllegalStateException("JPEG encode failed");
            }
            progress.update(r.startUs, r.endUs);
        } finally {
            if (bitmap != null) bitmap.recycle();
            retriever.release();
        }
    }

    private static final class Track {
        MediaExtractor extractor;
        int destination;
        MediaFormat format;
    }
    private void copy(Request r, File partial, Progress progress) throws Exception {
        List<Track> tracks = new ArrayList<>();
        MediaMuxer muxer = null;
        boolean started = false;
        try {
            muxer = new MediaMuxer(partial.getAbsolutePath(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
            long baseUs = r.startUs;
            // One shared origin preserves audio/video offsets. Trim seeks to a
            // video sync frame; it does not promise sample-accurate editing.
            if (r.operation == Operation.trim) {
                MediaExtractor probe = new MediaExtractor();
                try {
                    probe.setDataSource(r.inputs[0].getAbsolutePath());
                    for (int i = 0; i < probe.getTrackCount(); i++) {
                        if (probe.getTrackFormat(i).getString(MediaFormat.KEY_MIME).startsWith("video/")) {
                            probe.selectTrack(i); probe.seekTo(r.startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC);
                            baseUs = Math.max(0, probe.getSampleTime()); break;
                        }
                    }
                } finally { probe.release(); }
            }
            for (int fileIndex = 0; fileIndex < r.inputs.length; fileIndex++) {
                MediaExtractor probe = new MediaExtractor();
                try {
                    probe.setDataSource(r.inputs[fileIndex].getAbsolutePath());
                    for (int i = 0; i < probe.getTrackCount(); i++) {
                        MediaFormat format = probe.getTrackFormat(i);
                        String mime = format.getString(MediaFormat.KEY_MIME);
                        boolean video = mime.startsWith("video/"), audio = mime.startsWith("audio/");
                        if (!video && !audio) continue;
                        if (r.operation == Operation.extractAudio && !audio) continue;
                        if (r.operation == Operation.mux && ((fileIndex == 0 && !video) || (fileIndex == 1 && !audio))) continue;
                        Track track = new Track(); track.format = format;
                        track.extractor = new MediaExtractor();
                        tracks.add(track); // register before operations that may throw
                        track.extractor.setDataSource(r.inputs[fileIndex].getAbsolutePath());
                        track.extractor.selectTrack(i);
                        track.extractor.seekTo(baseUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC);
                        track.destination = muxer.addTrack(format);
                    }
                } finally { probe.release(); }
            }
            if (tracks.isEmpty() || (r.operation == Operation.mux && tracks.size() != 2))
                throw new IllegalStateException("Required tracks missing");
            muxer.start(); started = true;
            int capacity = 1024 * 1024;
            for (Track t : tracks) if (t.format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE))
                capacity = Math.max(capacity, t.format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE));
            if (capacity > 16 * 1024 * 1024) throw new IllegalStateException("Packet buffer exceeds PoC limit");
            ByteBuffer buffer = ByteBuffer.allocateDirect(capacity);
            android.media.MediaCodec.BufferInfo info = new android.media.MediaCodec.BufferInfo();
            long processedUs = 0;
            int samples = 0;
            while (true) {
                checkCancelled();
                Track next = null;
                long timestamp = Long.MAX_VALUE;
                for (Track t : tracks) {
                    long time = t.extractor.getSampleTime();
                    while (time >= 0 && time < baseUs) { t.extractor.advance(); time = t.extractor.getSampleTime(); }
                    if (time >= 0 && time < r.endUs && time < timestamp) { timestamp = time; next = t; }
                }
                if (next == null) break;
                if (next.extractor.getSampleSize() > capacity) throw new IllegalStateException("Packet too large");
                buffer.clear(); int size = next.extractor.readSampleData(buffer, 0);
                if (size < 0) throw new IllegalStateException("Sample read failed");
                int flags = next.extractor.getSampleFlags();
                if ((flags & MediaExtractor.SAMPLE_FLAG_ENCRYPTED) != 0)
                    throw new IllegalStateException("Encrypted input unsupported");
                if ((flags & MediaExtractor.SAMPLE_FLAG_PARTIAL_FRAME) != 0)
                    throw new IllegalStateException("Partial packets unsupported");
                info.set(0, size, timestamp - baseUs,
                    (flags & MediaExtractor.SAMPLE_FLAG_SYNC) != 0 ? android.media.MediaCodec.BUFFER_FLAG_KEY_FRAME : 0);
                muxer.writeSampleData(next.destination, buffer, info);
                next.extractor.advance();
                processedUs = Math.max(processedUs, timestamp - baseUs);
                if (++samples % 10 == 0) progress.update(processedUs, r.endUs - baseUs);
            }
            progress.update(processedUs, r.endUs - baseUs);
            checkCancelled();
            muxer.stop(); started = false;
        } finally {
            for (Track t : tracks) if (t.extractor != null) t.extractor.release();
            if (muxer != null) {
                if (started) { try { muxer.stop(); } catch (RuntimeException ignored) { /* cancelled incomplete container */ } }
                muxer.release();
            }
        }
    }

    public static JSONObject inspect(File file, boolean image) throws Exception {
        if (file.length() == 0) throw new IllegalStateException("Empty output");
        JSONObject result = new JSONObject();
        if (image) {
            Bitmap bitmap = BitmapFactory.decodeFile(file.getAbsolutePath());
            if (bitmap == null) throw new IllegalStateException("JPEG decode failed");
            result.put("width", bitmap.getWidth()).put("height", bitmap.getHeight()); bitmap.recycle();
        } else {
            MediaExtractor extractor = new MediaExtractor();
            try {
                extractor.setDataSource(file.getAbsolutePath());
                JSONArray formats = new JSONArray();
                for (int i = 0; i < extractor.getTrackCount(); i++) formats.put(extractor.getTrackFormat(i).toString());
                if (formats.length() == 0) throw new IllegalStateException("No output tracks");
                result.put("tracks", formats);
            } finally { extractor.release(); }
        }
        return result;
    }
}
