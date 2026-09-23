package com.mediaflow.mediaflow;

import android.webkit.WebView;

/** Java shim for the framework cleanup sequence, whose Kotlin stub is non-null. */
final class AndroidWebViewCleanup {
    private AndroidWebViewCleanup() {}

    static void detachClients(WebView webView) {
        webView.setWebChromeClient(null);
        webView.setWebViewClient(null);
    }
}
