package com.mediaflow.mediaflow

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.net.Uri
import android.net.http.SslError
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.webkit.ClientCertRequest
import android.webkit.HttpAuthHandler
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.webkit.ProfileStore
import androidx.webkit.ScriptHandler
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.util.UUID

/**
 * One hard-coded, anonymous System WebView observation endpoint. It only
 * transports an already-received allowlisted public Douyin JSON response to
 * the registered Dart consumer. It never exposes cookies, headers, arbitrary
 * URLs, request replay, DevTools, proxying, or a general capture API.
 */
class AndroidBrowserObservationHost(
    private val activity: MainActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private var session: Session? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "observeDouyinPublicWork" -> start(call, result)
            "cancel" -> {
                session?.finish("cancelled")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        session?.finish("cancelled")
        channel.setMethodCallHandler(null)
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        if (session != null) {
            result.success(finalMap("navigationRejected", false, false, 0, 0))
            return
        }
        val navigation = call.argument<String>("navigation")
        val consumerId = call.argument<String>("consumerId")
        val maxBodyBytes = call.argument<Int>("maxBodyBytes")
        val maxTotalBytes = call.argument<Int>("maxTotalBytes")
        val maxCandidates = call.argument<Int>("maxCandidates")
        val maxConsumerCalls = call.argument<Int>("maxConsumerCalls")
        val durationMs = call.argument<Int>("durationMs")
        val uri = navigation?.let(Uri::parse)
        if (consumerId != CONSUMER ||
            uri == null || !validInitialNavigation(uri) ||
            maxBodyBytes == null || maxBodyBytes !in 1..MAX_BODY_BYTES ||
            maxTotalBytes == null || maxTotalBytes !in maxBodyBytes..MAX_TOTAL_BYTES ||
            maxCandidates == null || maxCandidates !in 1..MAX_CANDIDATES ||
            maxConsumerCalls == null || maxConsumerCalls !in 1..MAX_CANDIDATES ||
            durationMs == null || durationMs !in 1..MAX_DURATION_MS
        ) {
            result.success(finalMap("navigationRejected", false, false, 0, 0))
            return
        }
        if (!requiredFeaturesAvailable()) {
            result.success(finalMap("unsupportedCapability", false, false, 0, 0))
            return
        }
        val next = Session(
            navigation = navigation,
            maxBodyBytes = maxBodyBytes,
            maxTotalBytes = maxTotalBytes,
            maxCandidates = minOf(maxCandidates, maxConsumerCalls),
            durationMs = durationMs.toLong(),
            result = result,
        )
        session = next
        try {
            next.start()
        } catch (_: Throwable) {
            next.finish("runtimeUnavailable")
        }
    }

    private fun requiredFeaturesAvailable(): Boolean =
        WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE) &&
            WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT) &&
            WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)

    @SuppressLint("SetJavaScriptEnabled")
    private inner class Session(
        private val navigation: String,
        private val maxBodyBytes: Int,
        private val maxTotalBytes: Int,
        private val maxCandidates: Int,
        private val durationMs: Long,
        private val result: MethodChannel.Result,
    ) {
        private val handler = Handler(Looper.getMainLooper())
        private val profileName = "mf_observe_${UUID.randomUUID().toString().replace("-", "")}"
        private val bridgeName = "mfObserve${UUID.randomUUID().toString().replace("-", "")}"
        private val nonce = UUID.randomUUID().toString()
        private val timeout = Runnable { finish("timeout") }
        private var container: FrameLayout? = null
        private var webView: WebView? = null
        private var scriptHandler: ScriptHandler? = null
        private var finishing = false
        private var candidateBusy = false
        private var navigationSucceeded = false
        private var responses = 0
        private var candidates = 0
        private var totalBytes = 0
        private var budgetRejected = 0
        private val filterCounts = mutableMapOf<String, Int>()
        private val rejectedHosts = mutableMapOf<String, Int>()
        private val navigationStages = mutableListOf<Map<String, String>>()
        private var finalDocument = emptyMap<String, String>()
        private var pageMarkers = emptyMap<String, Any>()
        private var mobileResponse = emptyMap<String, Any>()
        private var userAgentMode = "unknown"
        private var viewDestroyed = false
        private var cleanupStepFailures = 0
        private var profileDeleteIllegalState = 0
        private var profileDeleteOtherFailure = 0
        private var profilePresentAfterDelete = false
        private var profileDeleteAttempts = 0

        fun start() {
            val view = WebView(activity)
            WebViewCompat.setProfile(view, profileName)
            webView = view
            view.visibility = View.INVISIBLE
            view.settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                allowFileAccess = false
                allowContentAccess = false
                mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                javaScriptCanOpenWindowsAutomatically = false
                setSupportMultipleWindows(false)
                cacheMode = WebSettings.LOAD_NO_CACHE
                mediaPlaybackRequiresUserGesture = true
                setGeolocationEnabled(false)
            }
            userAgentMode = when {
                view.settings.userAgentString.contains("Android", ignoreCase = true) &&
                    view.settings.userAgentString.contains("Mobile", ignoreCase = true) -> "androidMobile"
                view.settings.userAgentString.contains("Android", ignoreCase = true) -> "androidOther"
                else -> "other"
            }
            view.clearHistory()
            view.clearFormData()

            WebViewCompat.addWebMessageListener(
                view,
                bridgeName,
                PAGE_ORIGINS,
            ) { _, message, sourceOrigin, isMainFrame, _ ->
                if (!finishing && isMainFrame && sourceOrigin.toString() in PAGE_ORIGINS) {
                    receiveMessage(message)
                }
            }
            scriptHandler = WebViewCompat.addDocumentStartJavaScript(
                view,
                observationScript(),
                PAGE_ORIGINS,
            )
            view.webViewClient = client
            val frame = FrameLayout(activity).apply {
                visibility = View.INVISIBLE
                addView(view, FrameLayout.LayoutParams(1, 1))
            }
            container = frame
            activity.addContentView(frame, ViewGroup.LayoutParams(1, 1))
            handler.postDelayed(timeout, durationMs)
            view.loadUrl(navigation)
        }

        private val client = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                val uri = url?.let(Uri::parse)
                recordNavigation("started", uri)
                val restricted = restrictedNavigationOutcome(uri)
                if (uri == null || !allowedPageNavigation(uri) || restricted != null) {
                    finish(restricted ?: "navigationRejected")
                }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                val uri = url?.let(Uri::parse)
                recordNavigation("finished", uri)
                if (uri?.let(::allowedPageNavigation) == true) {
                    navigationSucceeded = true
                }
            }

            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?,
            ): Boolean {
                if (request?.isForMainFrame != true) return false
                val uri = request.url
                recordNavigation("requested", uri)
                val restricted = restrictedNavigationOutcome(uri)
                if (restricted != null) {
                    finish(restricted)
                    return true
                }
                // Mobile public pages may try to open the native app or an
                // external page. Block that navigation without broadening the
                // allowlist or ending observation of the already loaded page.
                return !allowedPageNavigation(uri)
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?,
            ) {
                if (request?.isForMainFrame == true) finish("navigationFailed")
            }

            override fun onReceivedHttpError(
                view: WebView?,
                request: WebResourceRequest?,
                errorResponse: WebResourceResponse?,
            ) {
                if (request?.isForMainFrame != true) return
                when (errorResponse?.statusCode) {
                    401, 403 -> finish("accessRestricted")
                    451 -> finish("regionRestricted")
                    in 400..599 -> finish("navigationFailed")
                }
            }

            override fun onReceivedSslError(
                view: WebView?,
                handler: SslErrorHandler?,
                error: SslError?,
            ) {
                handler?.cancel()
                finish("accessRestricted")
            }

            override fun onReceivedHttpAuthRequest(
                view: WebView?,
                handler: HttpAuthHandler?,
                host: String?,
                realm: String?,
            ) {
                handler?.cancel()
                finish("loginRequired")
            }

            override fun onReceivedClientCertRequest(
                view: WebView?,
                request: ClientCertRequest?,
            ) {
                request?.cancel()
                finish("accessRestricted")
            }

            override fun onRenderProcessGone(
                view: WebView?,
                detail: android.webkit.RenderProcessGoneDetail?,
            ): Boolean {
                finish("runtimeUnavailable")
                return true
            }
        }

        private fun receiveMessage(message: WebMessageCompat) {
            val data = message.data ?: return
            if (data.length > maxBodyBytes * 2 + 4096) {
                budgetRejected++
                finish("budgetExceeded")
                return
            }
            val json = try {
                JSONObject(data)
            } catch (_: Throwable) {
                return
            }
            if (json.optString("nonce") != nonce) return
            when (json.optString("kind")) {
                "restriction" -> finish(
                    when (json.optString("reason")) {
                        "login" -> "loginRequired"
                        "region" -> "regionRestricted"
                        "access" -> "accessRestricted"
                        else -> "browserVerification"
                    },
                )
                "diagnostic" -> receiveDiagnostics(json)
                "candidate" -> receiveCandidate(json)
            }
        }

        private fun receiveDiagnostics(json: JSONObject) {
            val counts = json.optJSONObject("counts") ?: return
            for (key in DIAGNOSTIC_KEYS) {
                if (!counts.has(key)) continue
                val value = counts.optInt(key, -1)
                if (value in 0..MAX_DIAGNOSTIC_COUNT) {
                    filterCounts[key] = maxOf(filterCounts[key] ?: 0, value)
                }
            }
            val hosts = json.optJSONObject("rejectedHosts")
            if (hosts != null) {
                val keys = hosts.keys()
                while (keys.hasNext() && rejectedHosts.size < MAX_DIAGNOSTIC_HOSTS) {
                    val host = keys.next().lowercase()
                    val value = hosts.optInt(host, -1)
                    if (HOSTNAME.matches(host) && value in 1..MAX_DIAGNOSTIC_COUNT) {
                        rejectedHosts[host] = maxOf(rejectedHosts[host] ?: 0, value)
                    }
                }
            }
            responses = maxOf(responses, filterCounts["filterSeen"] ?: 0)
            val page = json.optJSONObject("page")
            if (page != null) {
                val host = page.optString("host")
                if (host in PAGE_HOSTS) {
                    pageMarkers = mapOf(
                        "host" to host,
                        "route" to safeRouteLabel(page.optString("route")),
                        "videoElementPresent" to page.optBoolean("videoElementPresent"),
                        "sourceElementPresent" to page.optBoolean("sourceElementPresent"),
                        "workIdInDocumentPath" to page.optBoolean("workIdInDocumentPath"),
                    )
                }
            }
            val mobile = json.optJSONObject("mobileResponse")
            if (mobile != null && mobileResponse.isEmpty() &&
                mobile.optString("host") == "m.douyin.com"
            ) {
                val method = mobile.optString("method").takeIf { SAFE_METHOD.matches(it) } ?: "other"
                val mime = mobile.optString("mime")
                    .takeIf { it.length <= 80 && SAFE_MIME.matches(it) } ?: "other"
                val resourceType = mobile.optString("resourceType")
                mobileResponse = mapOf(
                    "host" to "m.douyin.com",
                    "route" to safeRouteLabel(mobile.optString("route")),
                    "method" to method,
                    "status" to mobile.optInt("status", -1).coerceIn(-1, 599),
                    "mime" to mime,
                    "resourceType" to if (resourceType in setOf("fetch", "xhr")) resourceType else "other",
                )
            }
        }

        private fun recordNavigation(stage: String, uri: Uri?) {
            if (navigationStages.size >= MAX_NAVIGATION_STAGES) return
            val host = uri?.host ?: return
            if (host !in PAGE_HOSTS) return
            navigationStages.add(mapOf("stage" to stage, "host" to host, "route" to safeRoute(uri.path)))
        }

        private fun safeRoute(path: String?): String = when {
            path == "/" -> "root"
            path?.matches(Regex("^/video/[1-9][0-9]*/?$")) == true -> "videoWork"
            path?.matches(Regex("^/share/video/[1-9][0-9]*/?$")) == true -> "shareVideoWork"
            path?.startsWith(PATH_PREFIX) == true -> "webDetail"
            else -> "other"
        }

        private fun safeRouteLabel(value: String): String =
            if (value in setOf("root", "videoWork", "shareVideoWork", "webDetail")) value else "other"

        private fun receiveCandidate(json: JSONObject) {
            if (candidateBusy) return
            val host = json.optString("host")
            val path = json.optString("path")
            val method = json.optString("method")
            val resourceType = json.optString("resourceType")
            val status = json.optInt("status", -1)
            val mime = json.optString("mime").substringBefore(';').trim().lowercase()
            if (!json.has("body") || json.isNull("body")) return
            val body = json.getString("body")
            if (host != HOST ||
                !path.startsWith(PATH_PREFIX) ||
                containsExcluded(path) ||
                method != "GET" ||
                resourceType !in setOf("fetch", "xhr") ||
                status !in 200..299 ||
                !isJsonMime(mime)
            ) return
            val bytes = body.toByteArray(StandardCharsets.UTF_8)
            if (bytes.size > maxBodyBytes || totalBytes + bytes.size > maxTotalBytes ||
                candidates >= maxCandidates
            ) {
                bytes.fill(0)
                budgetRejected++
                if (totalBytes + bytes.size > maxTotalBytes || candidates >= maxCandidates) {
                    finish("budgetExceeded")
                }
                return
            }
            candidates++
            totalBytes += bytes.size
            candidateBusy = true
            channel.invokeMethod(
                "candidate",
                mapOf(
                    "host" to HOST,
                    "path" to PATH_PREFIX,
                    "resourceType" to resourceType,
                    "status" to status,
                    "mimeType" to mime,
                    "body" to bytes,
                ),
                object : MethodChannel.Result {
                    override fun success(decision: Any?) {
                        bytes.fill(0)
                        candidateBusy = false
                        when (decision) {
                            "found" -> finish("found")
                            "stop" -> finish("completed")
                        }
                    }

                    override fun error(code: String, message: String?, details: Any?) {
                        bytes.fill(0)
                        candidateBusy = false
                        finish("readFailed")
                    }

                    override fun notImplemented() {
                        bytes.fill(0)
                        candidateBusy = false
                        finish("readFailed")
                    }
                },
            )
        }

        fun finish(outcome: String) {
            if (finishing) return
            finishing = true
            handler.removeCallbacks(timeout)
            val view = webView
            finalDocument = view?.url?.let(Uri::parse)?.let { uri ->
                if (uri.host in PAGE_HOSTS) mapOf("host" to uri.host.orEmpty(), "route" to safeRoute(uri.path))
                else emptyMap()
            } ?: emptyMap()
            fun cleanupStep(action: () -> Unit) {
                try { action() } catch (_: Throwable) { cleanupStepFailures++ }
            }
            cleanupStep { view?.stopLoading() }
            cleanupStep { scriptHandler?.remove() }
            scriptHandler = null
            cleanupStep { if (view != null) WebViewCompat.removeWebMessageListener(view, bridgeName) }
            cleanupStep { (view?.parent as? ViewGroup)?.removeView(view) }
            cleanupStep { container?.let { (it.parent as? ViewGroup)?.removeView(it) } }
            cleanupStep { view?.onPause() }
            cleanupStep { view?.clearHistory() }
            cleanupStep { view?.clearFormData() }
            cleanupStep { if (view != null) AndroidWebViewCleanup.detachClients(view) }
            cleanupStep { view?.removeAllViews() }
            if (view != null) {
                try {
                    view.destroy()
                    viewDestroyed = true
                } catch (_: Throwable) {
                    cleanupStepFailures++
                }
            }
            webView = null
            container = null
            completeAfterProfileDeletion(outcome, attempt = 0)
        }

        private fun completeAfterProfileDeletion(outcome: String, attempt: Int) {
            handler.postDelayed({
                val profileCleaned = try {
                    val store = ProfileStore.getInstance()
                    val deleted = try {
                        profileDeleteAttempts++
                        store.deleteProfile(profileName)
                    } catch (_: IllegalStateException) {
                        profileDeleteIllegalState++
                        false
                    }
                    profilePresentAfterDelete = store.allProfileNames.contains(profileName)
                    deleted || !profilePresentAfterDelete
                } catch (_: Throwable) {
                    profileDeleteOtherFailure++
                    false
                }
                if (!profileCleaned && attempt < MAX_PROFILE_DELETE_RETRIES) {
                    completeAfterProfileDeletion(outcome, attempt + 1)
                    return@postDelayed
                }
                val output = finalMap(
                    outcome,
                    navigationSucceeded,
                    profileCleaned,
                    responses,
                    budgetRejected,
                    filterCounts,
                    rejectedHosts,
                    mapOf(
                        "navigationStages" to navigationStages.toList(),
                        "finalDocument" to finalDocument,
                        "pageMarkers" to pageMarkers,
                        "mobileResponse" to mobileResponse,
                        "userAgentMode" to userAgentMode,
                        "viewport" to "onePixelHidden",
                        "viewDestroyed" to viewDestroyed,
                        "cleanupStepFailures" to cleanupStepFailures,
                        "profileDeleteAttempts" to profileDeleteAttempts,
                        "profileDeleteIllegalState" to profileDeleteIllegalState,
                        "profileDeleteOtherFailure" to profileDeleteOtherFailure,
                        "profilePresentAfterDelete" to profilePresentAfterDelete,
                    ),
                )
                session = null
                result.success(output)
            }, PROFILE_DELETE_DELAY_MS)
        }

        private fun observationScript(): String {
            val bridge = JSONObject.quote(bridgeName)
            val token = JSONObject.quote(nonce)
            return """
                (() => {
                  'use strict';
                  const bridge = window[$bridge];
                  if (!bridge || window.__mfObservationInstalled) return;
                  Object.defineProperty(window, '__mfObservationInstalled', {value: true});
                  const nonce = $token;
                  const workId = ${JSONObject.quote(Uri.parse(navigation).lastPathSegment.orEmpty())};
                  const maxBytes = $maxBodyBytes;
                  const encoder = new TextEncoder();
                  const counts = {
                    filterSeen:0, filterRejected:0, filterAccepted:0,
                    rejectedScheme:0, rejectedHost:0, rejectedPath:0,
                    rejectedMethod:0, rejectedStatus:0, rejectedMime:0,
                    rejectedActualLength:0, bodyReadAttempts:0,
                    bodyBytes:0, bodyReadSucceeded:0, bodyReadFailed:0,
                    ipcSent:0, bridgeReady:1
                  };
                  const rejectedHosts = Object.create(null);
                  let mobileResponse = null;
                  const route = path => {
                    if (path === '/') return 'root';
                    if (/^\/video\/[1-9][0-9]*\/?$/.test(path)) return 'videoWork';
                    if (/^\/share\/video\/[1-9][0-9]*\/?$/.test(path)) return 'shareVideoWork';
                    if (path.startsWith('$PATH_PREFIX')) return 'webDetail';
                    return 'other';
                  };
                  let diagnosticMessages = 0, diagnosticTimer = null;
                  const bump = (key, amount = 1) => {
                    counts[key] = Math.min(10000, (counts[key] || 0) + amount);
                  };
                  const publishDiagnostics = () => {
                    diagnosticTimer = null;
                    if (diagnosticMessages >= 16) return;
                    diagnosticMessages++;
                    let page = null;
                    try {
                      page = {host:location.hostname, route:route(location.pathname),
                        videoElementPresent:!!document.querySelector('video'),
                        sourceElementPresent:!!document.querySelector('video source, source'),
                        workIdInDocumentPath:location.pathname.includes(workId)};
                    } catch (_) {}
                    send({kind:'diagnostic', nonce, counts, rejectedHosts, mobileResponse, page});
                  };
                  const scheduleDiagnostics = () => {
                    if (diagnosticTimer === null && diagnosticMessages < 16) {
                      diagnosticTimer = setTimeout(publishDiagnostics, 250);
                    }
                  };
                  const reject = (reason, host = null) => {
                    if (reason === 'rejectedHost' && host &&
                        (Object.prototype.hasOwnProperty.call(rejectedHosts, host) ||
                         Object.keys(rejectedHosts).length < 16)) {
                      rejectedHosts[host] = Math.min(10000, (rejectedHosts[host] || 0) + 1);
                    }
                    bump(reason); bump('filterRejected'); scheduleDiagnostics(); return null;
                  };
                  const classify = (url, method, status, mime, resourceType) => {
                    bump('filterSeen');
                    try {
                      const parsed = new URL(url, location.href);
                      const baseMime = String(mime || '').split(';')[0].trim().toLowerCase();
                      if (parsed.hostname === 'm.douyin.com' && mobileResponse === null) {
                        mobileResponse = {host:parsed.hostname, route:route(parsed.pathname),
                          method:String(method || 'GET').toUpperCase(), status,
                          mime:baseMime, resourceType};
                      }
                      if (parsed.protocol !== 'https:' || (parsed.port !== '' && parsed.port !== '443')) return reject('rejectedScheme');
                      if (parsed.hostname !== '$HOST') return reject('rejectedHost', parsed.hostname);
                      if (!parsed.pathname.startsWith('$PATH_PREFIX') ||
                          /security|identity|login|passport|captcha|telemetry|analytics|report|tracking|verify|waf/i.test(parsed.pathname)) return reject('rejectedPath');
                      if (String(method || 'GET').toUpperCase() !== 'GET') return reject('rejectedMethod');
                      if (status < 200 || status >= 300) return reject('rejectedStatus');
                      if (!(baseMime === 'application/json' || /^application\/[a-z0-9.-]+\+json$/.test(baseMime))) return reject('rejectedMime');
                      bump('filterAccepted'); scheduleDiagnostics(); return parsed;
                    } catch (_) { return reject('rejectedScheme'); }
                  };
                  const send = value => { try { bridge.postMessage(JSON.stringify(value)); } catch (_) {} };
                  const emit = async (response, method, resourceType) => {
                    const mime = response.headers.get('content-type') || '';
                    const parsed = classify(response.url, method, response.status, mime, resourceType);
                    if (!parsed) return;
                    bump('bodyReadAttempts');
                    const reader = response.clone().body?.getReader();
                    if (!reader) { bump('bodyReadFailed'); scheduleDiagnostics(); return; }
                    const decoder = new TextDecoder('utf-8', {fatal: false});
                    let size = 0, text = '';
                    try {
                      while (true) {
                        const part = await reader.read();
                        if (part.done) break;
                        size += part.value.byteLength;
                        if (size > maxBytes) {
                          bump('rejectedActualLength'); bump('filterRejected');
                          await reader.cancel(); scheduleDiagnostics(); return;
                        }
                        text += decoder.decode(part.value, {stream: true});
                      }
                      text += decoder.decode();
                      bump('bodyBytes', size); bump('bodyReadSucceeded'); bump('ipcSent'); scheduleDiagnostics();
                      send({kind:'candidate', nonce, host:parsed.hostname, path:parsed.pathname,
                        method:String(method || 'GET').toUpperCase(), resourceType,
                        status:response.status, mime, body:text});
                    } catch (_) {
                      bump('bodyReadFailed'); scheduleDiagnostics();
                      try { await reader.cancel(); } catch (_) {}
                    }
                  };
                  const originalFetch = window.fetch;
                  window.fetch = function(input, init) {
                    const method = init?.method || (input instanceof Request ? input.method : 'GET');
                    const promise = originalFetch.apply(this, arguments);
                    promise.then(response => { void emit(response, method, 'fetch'); }, () => {});
                    return promise;
                  };
                  const originalOpen = XMLHttpRequest.prototype.open;
                  const originalSend = XMLHttpRequest.prototype.send;
                  XMLHttpRequest.prototype.open = function(method, url) {
                    this.__mfMethod = String(method || 'GET').toUpperCase();
                    this.__mfUrl = String(url || '');
                    return originalOpen.apply(this, arguments);
                  };
                  XMLHttpRequest.prototype.send = function() {
                    this.addEventListener('loadend', function() {
                      try {
                        const mime = this.getResponseHeader('content-type') || '';
                        const url = this.responseURL || this.__mfUrl;
                        const parsed = classify(url, this.__mfMethod, this.status, mime, 'xhr');
                        if (!parsed) return;
                        bump('bodyReadAttempts');
                        if (this.responseType !== '' && this.responseType !== 'text') {
                          bump('bodyReadFailed'); scheduleDiagnostics(); return;
                        }
                        const body = this.responseText;
                        if (typeof body !== 'string') { bump('bodyReadFailed'); scheduleDiagnostics(); return; }
                        const size = encoder.encode(body).byteLength;
                        if (size > maxBytes) {
                          bump('rejectedActualLength'); bump('filterRejected'); scheduleDiagnostics(); return;
                        }
                        bump('bodyBytes', size); bump('bodyReadSucceeded'); bump('ipcSent'); scheduleDiagnostics();
                        send({kind:'candidate', nonce, host:parsed.hostname, path:parsed.pathname,
                          method:this.__mfMethod, resourceType:'xhr', status:this.status, mime, body});
                      } catch (_) {}
                    }, {once:true});
                    return originalSend.apply(this, arguments);
                  };
                  const restriction = () => {
                    try {
                      const path = location.pathname.toLowerCase();
                      if (/login|passport/.test(path)) return send({kind:'restriction', nonce, reason:'login'});
                      if (/captcha|verify|challenge/.test(path)) return send({kind:'restriction', nonce, reason:'verify'});
                      const text = String(document.title || '') + ' ' + String(document.body?.innerText || '').slice(0, 20000);
                      if (/验证码|人机验证|安全验证|滑块验证/.test(text)) return send({kind:'restriction', nonce, reason:'verify'});
                      if (/地区限制|所在地区不可用|region unavailable/i.test(text)) return send({kind:'restriction', nonce, reason:'region'});
                      if (/访问过于频繁|access denied|禁止访问/i.test(text)) return send({kind:'restriction', nonce, reason:'access'});
                      if (document.querySelector('input[type="password"]')) return send({kind:'restriction', nonce, reason:'login'});
                    } catch (_) {}
                  };
                  setInterval(restriction, 500);
                  scheduleDiagnostics();
                  setTimeout(scheduleDiagnostics, 2000);
                  setTimeout(scheduleDiagnostics, 7000);
                  setTimeout(scheduleDiagnostics, 15000);
                })();
            """.trimIndent()
        }
    }

    private fun validInitialNavigation(uri: Uri): Boolean =
        uri.scheme == "https" && uri.host == HOST && uri.port == -1 &&
            uri.userInfo == null && uri.query == null && uri.fragment == null &&
            Regex("^/video/[1-9][0-9]*$").matches(uri.path.orEmpty())

    private fun allowedPageNavigation(uri: Uri): Boolean =
        uri.scheme == "https" && uri.host in PAGE_HOSTS && uri.port in setOf(-1, 443) &&
            uri.userInfo.isNullOrEmpty()

    private fun restrictedNavigationOutcome(uri: Uri?): String? {
        val value = "${uri?.host.orEmpty()}${uri?.path.orEmpty()}".lowercase()
        return when {
            "login" in value || "passport" in value -> "loginRequired"
            "captcha" in value || "verify" in value || "challenge" in value -> "browserVerification"
            else -> null
        }
    }

    private fun containsExcluded(path: String): Boolean =
        Regex("security|identity|login|passport|captcha|telemetry|analytics|report|tracking|verify|waf", RegexOption.IGNORE_CASE)
            .containsMatchIn(path)

    private fun isJsonMime(mime: String): Boolean =
        mime == "application/json" || Regex("^application/[a-z0-9.-]+\\+json$").matches(mime)

    private fun finalMap(
        outcome: String,
        navigationSucceeded: Boolean,
        profileCleaned: Boolean,
        responses: Int,
        budgetRejected: Int,
        filterCounts: Map<String, Int> = emptyMap(),
        rejectedHosts: Map<String, Int> = emptyMap(),
        diagnostics: Map<String, Any> = emptyMap(),
    ): Map<String, Any> = mapOf(
        "outcome" to outcome,
        "navigationSucceeded" to navigationSucceeded,
        "profileCleaned" to profileCleaned,
        "responses" to responses,
        "budgetRejected" to budgetRejected,
        "filterCounts" to filterCounts.toMap(),
        "rejectedHosts" to rejectedHosts.toMap(),
        "diagnostics" to diagnostics.toMap(),
    )

    companion object {
        private const val CHANNEL = "com.mediaflow.mediaflow/browser_observation"
        private const val CONSUMER = "douyin-public-work"
        private const val ORIGIN = "https://www.douyin.com"
        private const val MOBILE_ORIGIN = "https://m.douyin.com"
        private const val HOST = "www.douyin.com"
        private const val PATH_PREFIX = "/aweme/v1/web/aweme/detail/"
        private const val MAX_BODY_BYTES = 1024 * 1024
        private const val MAX_TOTAL_BYTES = 4 * 1024 * 1024
        private const val MAX_CANDIDATES = 32
        private const val MAX_DURATION_MS = 45_000
        private const val MAX_DIAGNOSTIC_COUNT = 10_000
        private const val MAX_DIAGNOSTIC_HOSTS = 16
        private const val MAX_NAVIGATION_STAGES = 8
        private const val PROFILE_DELETE_DELAY_MS = 500L
        private const val MAX_PROFILE_DELETE_RETRIES = 5
        private val PAGE_ORIGINS = setOf(ORIGIN, MOBILE_ORIGIN)
        private val PAGE_HOSTS = setOf(HOST, "m.douyin.com")
        private val HOSTNAME = Regex("^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$")
        private val SAFE_METHOD = Regex("^[A-Z]{1,12}$")
        private val SAFE_MIME = Regex("^[a-z0-9.+-]+/[a-z0-9.+-]+$")
        private val DIAGNOSTIC_KEYS = setOf(
            "filterSeen",
            "filterRejected",
            "filterAccepted",
            "rejectedScheme",
            "rejectedHost",
            "rejectedPath",
            "rejectedMethod",
            "rejectedStatus",
            "rejectedMime",
            "rejectedActualLength",
            "bodyReadAttempts",
            "bodyBytes",
            "bodyReadSucceeded",
            "bodyReadFailed",
            "ipcSent",
            "bridgeReady",
        )
    }
}
