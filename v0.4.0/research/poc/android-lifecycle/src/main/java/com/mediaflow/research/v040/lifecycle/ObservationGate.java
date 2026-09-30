package com.mediaflow.research.v040.lifecycle;

import org.json.JSONObject;

// Research observation boundary. No payload, credentials or network implementation.
final class ObservationGate {
    enum Kind { OBSERVATION, RESPONSE, BODY, HYDRATION, DECODER, NAVIGATION }
    private boolean cancelled;
    private final int[] consumed = new int[Kind.values().length];
    private final int[] rejected = new int[Kind.values().length];

    synchronized boolean consume(Kind kind, Runnable action) {
        if (cancelled) { rejected[kind.ordinal()]++; return false; }
        // Cancellation and consumption share the same lock; no check/use race.
        action.run();
        consumed[kind.ordinal()]++;
        return true;
    }

    synchronized void cancel() { cancelled = true; }
    synchronized boolean cancelled() { return cancelled; }

    synchronized JSONObject snapshot() throws Exception {
        JSONObject result = new JSONObject();
        result.put("cancelled", cancelled);
        for (Kind kind : Kind.values()) {
            result.put(kind.name() + "Consumed", consumed[kind.ordinal()]);
            result.put(kind.name() + "Rejected", rejected[kind.ordinal()]);
        }
        return result;
    }
}
