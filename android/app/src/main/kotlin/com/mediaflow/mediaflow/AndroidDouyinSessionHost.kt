package com.mediaflow.mediaflow

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Dialog
import android.content.pm.ApplicationInfo
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.webkit.ProfileStore
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import androidx.webkit.WebStorageCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.json.JSONArray
import java.io.File

/** Own persistent named profile. No DOM, hydration, storage or response capture. */
class AndroidDouyinSessionHost(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.mediaflow.mediaflow/douyin_session")
    private val preferences = activity.getSharedPreferences("douyin_private_session", 0)
    private var view: WebView? = null
    private var dialog: Dialog? = null
    private var container: LinearLayout? = null
    private var notice: TextView? = null
    private val loginHandler = Handler(Looper.getMainLooper())
    private var loginPoll: Runnable? = null
    private var sessionProbePending = false
    private var loginEntryOpened = false
    private var defaultSmsSelected = false
    private var interactiveOperation = false
    private var pending: MethodChannel.Result? = null
    private val profileName = "mediaflow_douyin_v040"
    private val scope = "https://www.douyin.com/aweme/v1/web/aweme/detail/"
    private val diagnosticsEnabled =
        (activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    // Preserve bounded, value-free lifecycle evidence across process restarts.
    private val states = if (diagnosticsEnabled) try {
        val file = File(activity.filesDir, "douyin-session-state.json")
        if (file.exists()) JSONArray(file.readText()) else JSONArray()
    } catch (_: Throwable) { JSONArray() } else JSONArray()
    private fun state(name: String, fields: Map<String, Any?> = emptyMap()) {
        if (!diagnosticsEnabled) return
        // Debug diagnostics must neither affect session completion nor expose values.
        runCatching {
            val event = JSONObject(fields).put("state", name).put("timestamp", System.currentTimeMillis())
            while (states.length() >= 200) states.remove(0)
            states.put(event)
            File(activity.filesDir, "douyin-session-state.json").writeText(states.toString(2))
        }
    }

    init { channel.setMethodCallHandler { call, result ->
        state("command", mapOf("name" to call.method))
        try {
            if (!WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE) ||
                !WebViewFeature.isFeatureSupported(WebViewFeature.DELETE_BROWSING_DATA)) {
                result.success(mapOf("status" to "unsupported"))
            } else when(call.method) {
                "diagnostics" -> result.success(mapOf("states" to states.toString()))
                "restore" -> start(false, result)
                "establish" -> start(true, result)
                "clear" -> clear(result)
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            state("exception", mapOf("category" to error.javaClass.simpleName))
            if (pending === result) finish(mapOf("status" to "unavailable"))
            else result.success(mapOf("status" to "unavailable"))
        }
    } }

    private fun finish(data: Map<String, Any?>) {
        loginPoll?.let(loginHandler::removeCallbacks); loginPoll = null
        sessionProbePending = false
        interactiveOperation = false
        state("finish", mapOf("status" to data["status"]))
        val result = pending; pending = null
        val old = view; view = null
        old?.stopLoading(); (old?.parent as? ViewGroup)?.removeView(old); old?.destroy()
        dialog?.setOnCancelListener(null); dialog?.dismiss(); dialog = null
        (container?.parent as? ViewGroup)?.removeView(container); container = null
        result?.success(data)
    }

    private fun deletePending(): Boolean {
        if (!preferences.getBoolean("deletePending", false)) return true
        val store = ProfileStore.getInstance()
        try {
            if (store.allProfileNames.contains(profileName)) store.deleteProfile(profileName)
            if (store.allProfileNames.contains(profileName)) return false
            preferences.edit().remove("deletePending").apply()
            return true
        } catch (_: Throwable) { return false }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun start(interactive: Boolean, result: MethodChannel.Result) {
        state("activityAvailable", mapOf("interactive" to interactive, "finishing" to activity.isFinishing))
        if (pending != null) { result.success(mapOf("status" to "busy")); return }
        if (!deletePending()) { result.success(mapOf("status" to "cleanupPendingRestart")); return }
        state("profileRestoreCheck", mapOf("exists" to ProfileStore.getInstance().allProfileNames.contains(profileName),
            "interactive" to interactive))
        if (!interactive && !ProfileStore.getInstance().allProfileNames.contains(profileName)) {
            result.success(mapOf("status" to "noSession")); return
        }
        pending = result
        interactiveOperation = interactive
        loginEntryOpened = false
        defaultSmsSelected = false
        val browser = WebView(activity); view = browser
        state("webViewCreated")
        WebViewCompat.setProfile(browser, profileName)
        state("profileBound", mapOf("profile" to profileName))
        browser.settings.apply {
            javaScriptEnabled = true; domStorageEnabled = true
            allowFileAccess = false; allowContentAccess = false
            setSupportMultipleWindows(false)
        }
        if (!DouyinDesktopSessionHost.configure(browser, ::state)) {
            finish(mapOf("status" to "unsupported")); return
        }
        val box = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        container = box
        box.addView(browser, LinearLayout.LayoutParams(-1, 0, 1f))
        val message = TextView(activity).apply { text = "首次解析抖音图文可能需要完成一次抖音登录或安全验证。登录状态保存在本机，后续通常可直接解析。" }
        notice = message
        if (interactive) box.addView(message)
        val cancel = Button(activity).apply { text = "取消"; setOnClickListener { state("userCancelled"); finish(mapOf("status" to "cancelled")) } }
        if (interactive) box.addView(cancel)
        browser.webViewClient = object : WebViewClient() {
            override fun onPageStarted(v: WebView, url: String, favicon: android.graphics.Bitmap?) {
                state("pageStarted", mapOf("domain" to android.net.Uri.parse(url).host))
            }
            override fun shouldOverrideUrlLoading(v: WebView, request: android.webkit.WebResourceRequest): Boolean {
                val uri = request.url; val host = uri.host ?: return true
                return uri.scheme != "https" || !(host == "douyin.com" || host.endsWith(".douyin.com") || host == "passport.bytedance.com" || host == "sso.bytedance.com")
            }
            override fun onPageFinished(v: WebView, url: String) {
                state("pageFinished", mapOf("domain" to android.net.Uri.parse(url).host))
                if (interactive) {
                    val uri = android.net.Uri.parse(url)
                    state("pageLocation", mapOf("origin" to "${uri.scheme}://${uri.host}", "path" to uri.path))
                    // Read only standard UA metadata; no DOM, account or challenge state.
                    v.evaluateJavascript("JSON.stringify({ua:navigator.userAgent,legacyPlatform:navigator.platform,metadata:navigator.userAgentData?navigator.userAgentData.toJSON():null})") { encoded ->
                        if (view === v && pending != null) {
                            try {
                                val facts = JSONObject(org.json.JSONTokener(encoded).nextValue() as String)
                                state("pageIdentity", mapOf("facts" to facts))
                            } catch (_: Throwable) { state("pageIdentityUnavailable") }
                        }
                    }
                }
                if (!interactive && url == "about:blank") read()
            }
        }
        if (interactive) {
            val surface = Dialog(activity); dialog = surface
            surface.setContentView(box); surface.setOnCancelListener { finish(mapOf("status" to "cancelled")) }
            surface.show(); surface.window?.setLayout(-1, -1)
            state("windowShown", mapOf("initialUrl" to "https://www.douyin.com/"))
            browser.loadUrl("https://www.douyin.com/")
            val poll = object : Runnable {
                override fun run() {
                    if (pending == null || view !== browser || !interactiveOperation) return
                    if (!defaultSmsSelected) selectDefaultSms(browser)
                    if (!sessionProbePending) read(automatic = true)
                    loginHandler.postDelayed(this, 1800)
                }
            }
            loginPoll = poll
            loginHandler.postDelayed(poll, 1500)
        } else {
            // Attached offscreen view for runtime facts; no platform navigation.
            activity.addContentView(box, ViewGroup.LayoutParams(1, 1))
            browser.loadUrl("about:blank")
        }
    }

    private fun selectDefaultSms(browser: WebView) {
        // Click only the platform's visible login controls. Never inspect or
        // handle a phone number, SMS code, account field or security challenge.
        val labels = if (loginEntryOpened)
            "['验证码登录','短信登录','手机验证码登录','手机登录','手机号登录']"
        else "['验证码登录','短信登录','手机验证码登录','手机登录','手机号登录','登录']"
        val script = """(function(){const labels=$labels;for(const label of labels){const el=Array.from(document.querySelectorAll('button,a,[role="button"],[role="tab"],span')).find(e=>e.textContent.trim()===label&&e.getBoundingClientRect().width>0&&e.getBoundingClientRect().height>0);if(el){el.click();return label;}}return '';})()"""
        browser.evaluateJavascript(script) { encoded ->
            if (view !== browser || pending == null) return@evaluateJavascript
            val selected = runCatching { org.json.JSONTokener(encoded).nextValue() as? String }.getOrNull()
            if (selected == "登录") loginEntryOpened = true
            if (selected in setOf("验证码登录", "短信登录", "手机验证码登录", "手机登录", "手机号登录")) {
                defaultSmsSelected = true
                state("defaultLoginMethod", mapOf("method" to "sms"))
            }
        }
    }

    private fun read(automatic: Boolean = false) {
        val browser = view ?: return
        if (!automatic) browser.stopLoading()
        val manager = WebViewCompat.getProfile(browser).cookieManager
        if (!automatic) manager.flush()
        val subset = mutableMapOf<String, String>()
        val allowed = setOf("sessionid", "sessionid_ss", "ttwid", "msToken")
        for (part in (manager.getCookie(scope) ?: "").split(';')) {
            val pair = part.trim().split('=', limit = 2)
            if (pair.size == 2 && pair[0] in allowed) {
                if (subset.containsKey(pair[0])) { finish(mapOf("status" to "unavailable")); return }
                subset[pair[0]] = pair[1]
            }
        }
        for (name in listOf("sessionid", "sessionid_ss", "ttwid")) {
            state("cookieMetadata", mapOf("name" to name, "present" to subset.containsKey(name),
                "length" to (subset[name]?.length ?: 0), "requestDomain" to "www.douyin.com"))
        }
        if (!subset.containsKey("sessionid") && !subset.containsKey("sessionid_ss")) {
            if (interactiveOperation) {
                if (!automatic) state("notReadyWindowRetained")
            } else finish(mapOf("status" to "noSession"))
            return
        }
        if (sessionProbePending) return
        sessionProbePending = true
        manager.flush()
        state("cookiesFlushed")
        val script = """JSON.stringify({ua:navigator.userAgent,platform:navigator.platform,metrics:[innerWidth,innerHeight,outerWidth,outerHeight,screenX,screenY,scrollX,scrollY,screen.width,screen.height,screen.availWidth,screen.availHeight,innerWidth,innerHeight,screen.colorDepth,screen.pixelDepth],query:{screen_width:String(screen.width),screen_height:String(screen.height),browser_language:navigator.language,browser_platform:navigator.platform,browser_name:'Chrome',browser_version:(navigator.userAgent.match(/Chrome[/]([0-9.]+)/)||['',''])[1],browser_online:String(navigator.onLine),engine_name:'Blink',engine_version:(navigator.userAgent.match(/Chrome[/]([0-9.]+)/)||['',''])[1],os_name:'Android',os_version:(navigator.userAgent.match(/Android ([0-9.]+)/)||['',''])[1],cpu_core_num:String(navigator.hardwareConcurrency)}})"""
        browser.evaluateJavascript(script) { encoded ->
            sessionProbePending = false
            if (view !== browser || pending == null) return@evaluateJavascript
            try {
                val json = JSONObject(org.json.JSONTokener(encoded).nextValue() as String)
                val facts = json.getJSONObject("query")
                val query = facts.keys().asSequence().associateWith { facts.getString(it) }
                val metrics = json.getJSONArray("metrics")
                finish(mapOf("status" to "ready", "cookies" to subset,
                    "ua" to json.getString("ua"), "platform" to json.getString("platform"),
                    "metrics" to (0 until metrics.length()).map { metrics.getInt(it) }, "query" to query))
            } catch (_: Throwable) {
                if (!automatic) finish(mapOf("status" to "unavailable"))
            }
        }
    }

    private fun clear(result: MethodChannel.Result) {
        finish(mapOf("status" to "cancelled"))
        if (preferences.getBoolean("deletePending", false) && deletePending()) {
            result.success(mapOf("status" to "cleared")); return
        }
        val store = ProfileStore.getInstance()
        if (!store.allProfileNames.contains(profileName)) { result.success(mapOf("status" to "cleared")); return }
        val profile = store.getProfile(profileName) ?: run { result.success(mapOf("status" to "unavailable")); return }
        // Loaded profiles cannot reliably be deleted in the current process.
        // Clear every data category now, then delete the empty profile on cold start.
        preferences.edit().putBoolean("deletePending", true).commit()
        WebStorageCompat.deleteBrowsingData(profile.webStorage) {
            val empty = profile.cookieManager.getCookie(scope).isNullOrBlank()
            result.success(mapOf("status" to if (empty) "cleared" else "cleanupFailed", "profileDeletionPendingRestart" to true))
        }
    }

    fun dispose() { finish(mapOf("status" to "cancelled")); channel.setMethodCallHandler(null) }
}
