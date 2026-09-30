package com.mediaflow.mediaflow

import android.webkit.WebView
import androidx.webkit.UserAgentMetadata
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature

/** Desktop-site compatibility settings, scoped to the owned Douyin session view. */
internal object DouyinDesktopSessionHost {
    // Read from a fresh local Windows WebView2 runtime, without platform navigation.
    const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/154.0.0.0 Safari/537.36 Edg/154.0.0.0"

    fun configure(browser: WebView, record: (String, Map<String, Any?>) -> Unit): Boolean {
        val supported = WebViewFeature.isFeatureSupported(WebViewFeature.USER_AGENT_METADATA)
        record("mobileIdentity", mapOf("ua" to browser.settings.userAgentString,
            "metadataSupported" to supported,
            "webViewVersion" to WebView.getCurrentWebViewPackage()?.versionName))
        if (!supported) return false
        val original = WebSettingsCompat.getUserAgentMetadata(browser.settings)
        record("mobileMetadata", mapOf("mobile" to original.isMobile, "platform" to original.platform))
        browser.settings.userAgentString = USER_AGENT
        val brands = listOf("Chromium", "Microsoft Edge").map {
            UserAgentMetadata.BrandVersion.Builder().setBrand(it)
                .setMajorVersion("154").setFullVersion("154.0.0.0").build()
        }
        val metadata = UserAgentMetadata.Builder().setBrandVersionList(brands)
            .setFullVersion("154.0.0.0").setMobile(false).setPlatform("Windows")
            .setPlatformVersion("10.0.0").setArchitecture("x86").setBitness(64)
            .setModel("").setWow64(false).build()
        WebSettingsCompat.setUserAgentMetadata(browser.settings, metadata)
        val applied = WebSettingsCompat.getUserAgentMetadata(browser.settings)
        browser.settings.useWideViewPort = true
        browser.settings.loadWithOverviewMode = true
        record("desktopIdentity", mapOf("ua" to browser.settings.userAgentString,
            "mobile" to applied.isMobile, "platform" to applied.platform,
            "officialMetadataApi" to true))
        return !applied.isMobile && applied.platform == "Windows"
    }
}
