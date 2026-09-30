using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

// Independent, bounded metadata experiment. No production parser or signer.
class ContextBootstrapProbe : Form {
    const string Home = "https://www.douyin.com/";
    const string Note = "https://www.douyin.com/note/7690029886242009957";
    readonly JavaScriptSerializer json = new JavaScriptSerializer();
    readonly Timer timer = new Timer { Interval = 500 };
    readonly TaskCompletionSource<bool> browserExited = new TaskCompletionSource<bool>();
    WebView2 view; CoreWebView2Environment env;
    bool fixture = true, stopped, sampling;
    string phase = "A", profile, reason;
    int requests, responses, navigationCount, blockedDetail, blockedMedia;
    DateTime phaseStart;
    readonly HashSet<string> sdkScripts = new HashSet<string>();
    TaskCompletionSource<string> storageResult;
    static bool Uifid(string name) { return Regex.IsMatch(name, "^uifid(_temp)?$", RegexOptions.IgnoreCase); }
    static bool Challenge(string path) { return Regex.IsMatch(path, "waf[-_/]|jschallenge|captcha|verifycenter|verify_center", RegexOptions.IgnoreCase); }
    static string[] CookieNames(string header) {
        return Regex.Matches(header ?? "", @"(?:^|,\s*)([^\s=;,]+)=").Cast<Match>().Select(m => m.Groups[1].Value).ToArray();
    }
    void Log(string kind, object data) {
        Console.WriteLine(json.Serialize(new { utc = DateTime.UtcNow.ToString("o"), phase, kind, data }));
        Console.Out.Flush();
    }
    ContextBootstrapProbe(string root) {
        Opacity = 0; ShowInTaskbar = false; Width = 900; Height = 700;
        profile = Path.Combine(Path.GetFullPath(root), "uifid-" + Guid.NewGuid().ToString("N"));
        Shown += async (s,e) => { try { await Run(); } catch(Exception ex) { Log("error", new { type = ex.GetType().Name }); StopSoon("probe_error"); } };
        timer.Tick += async (s,e) => {
            if(stopped || sampling || phase == "A") return;
            sampling = true;
            try {
                if(await Snapshot()) { await Finish("anonymous_uifid_observed"); return; }
                if(stopped) return;
                if((DateTime.UtcNow - phaseStart).TotalSeconds >= 12) {
                    if(phase == "B") Navigate("C", Note);
                    else await Finish("no_uifid_in_bounded_window");
                }
            } catch(Exception ex) { Log("snapshot_error", new { type = ex.GetType().Name }); StopSoon("snapshot_error"); }
            finally { sampling = false; }
        };
    }
    async Task Run() {
        if(Directory.Exists(profile)) throw new InvalidOperationException("Profile must be new");
        Log("profile", new { path = profile, existedBefore = false, importedState = false });
        env = await CoreWebView2Environment.CreateAsync(null, profile);
        env.BrowserProcessExited += (s,e) => browserExited.TrySetResult(true);
        view = new WebView2 { Dock = DockStyle.Fill }; Controls.Add(view);
        await view.EnsureCoreWebView2Async(env);
        var core = view.CoreWebView2;
        core.WebMessageReceived += (s,e) => { if(storageResult != null && e.Source.StartsWith(Home, StringComparison.Ordinal)) storageResult.TrySetResult(e.WebMessageAsJson); };
        core.Settings.IsPasswordAutosaveEnabled = false;
        core.Settings.IsGeneralAutofillEnabled = false;
        core.Settings.AreDevToolsEnabled = false;
        core.NewWindowRequested += (s,e) => { e.Handled = true; };
        core.PermissionRequested += (s,e) => e.State = CoreWebView2PermissionState.Deny;
        core.DownloadStarting += (s,e) => { e.Cancel = true; };
        core.AddWebResourceRequestedFilter("*", CoreWebView2WebResourceContext.All);
        core.WebResourceRequested += (s,e) => {
            Uri uri; if(!Uri.TryCreate(e.Request.Uri, UriKind.Absolute, out uri)) return;
            if(fixture && uri.AbsoluteUri == Home) {
                e.Response = env.CreateWebResourceResponse(new MemoryStream(System.Text.Encoding.UTF8.GetBytes("<!doctype html><title>offline fresh-origin metadata fixture</title>")), 200, "OK", "Content-Type: text/html");
                return;
            }
            if(stopped) { e.Response = env.CreateWebResourceResponse(null, 204, "Stopped", ""); return; }
            if(Challenge(uri.AbsolutePath)) {
                e.Response = env.CreateWebResourceResponse(null, 204, "Blocked", "");
                Log("security_resource_blocked", new { host = uri.Host, path = uri.AbsolutePath });
                StopSoon("explicit_security_resource"); return;
            }
            if(uri.AbsolutePath.Contains("/aweme/v1/web/aweme/detail/")) {
                blockedDetail++; e.Response = env.CreateWebResourceResponse(null, 204, "Blocked", ""); return;
            }
            if(e.ResourceContext == CoreWebView2WebResourceContext.Image || e.ResourceContext == CoreWebView2WebResourceContext.Media) {
                blockedMedia++; e.Response = env.CreateWebResourceResponse(null, 204, "Blocked", ""); return;
            }
            requests++;
            if(e.ResourceContext == CoreWebView2WebResourceContext.Script) sdkScripts.Add(uri.GetLeftPart(UriPartial.Path));
        };
        core.WebResourceResponseReceived += (s,e) => {
            if(stopped || fixture) return;
            responses++; Uri uri; if(!Uri.TryCreate(e.Request.Uri, UriKind.Absolute, out uri)) return;
            var names = new List<string>();
            var iterator = e.Response.Headers.GetIterator();
            while(iterator.HasCurrentHeader) {
                string name = iterator.Current.Key, value = iterator.Current.Value;
                if(name.Equals("Set-Cookie", StringComparison.OrdinalIgnoreCase)) names.AddRange(CookieNames(value));
                iterator.MoveNext();
            }
            if(names.Count > 0 || e.Response.StatusCode >= 400)
                Log("response_metadata", new { host = uri.Host, path = uri.AbsolutePath, status = e.Response.StatusCode, setCookieNames = names });
            if(e.Response.StatusCode == 401 || e.Response.StatusCode == 403 || e.Response.StatusCode == 429) StopSoon("http_access_or_security_rejection");
        };
        core.NavigationStarting += (s,e) => {
            if(stopped || (e.Uri != Home && e.Uri != Note && e.Uri != "about:blank")) { e.Cancel = true; if(!stopped) StopSoon("unexpected_navigation"); }
        };
        core.NavigationCompleted += async (s,e) => {
            if(stopped) return;
            Log("navigation_completed", new { success = e.IsSuccess, status = e.HttpStatusCode, offline = fixture });
            if(fixture) {
                bool found = await Snapshot();
                var cookies = await core.CookieManager.GetCookiesAsync(null);
                if(found || cookies.Count != 0) { await Finish("fresh_profile_invariant_failed"); return; }
                Log("fresh_origin_verified", new { cookieCount = 0, origin = "https://www.douyin.com", fixtureNetworkRequests = 0 });
                fixture = false; Navigate("B", Home); timer.Start();
            } else if(!e.IsSuccess) await Finish("navigation_failure");
        };
        core.Navigate(Home); // Locally intercepted Phase A, no Douyin request.
    }
    void Navigate(string next, string url) {
        phase = next; phaseStart = DateTime.UtcNow; navigationCount++;
        Log("navigation", new { url, publicNavigationNumber = navigationCount });
        view.CoreWebView2.Navigate(url);
    }
    async Task<bool> Snapshot() {
        if(stopped) return false;
        var cookies = await view.CoreWebView2.CookieManager.GetCookiesAsync(null);
        Log("cookie_metadata", cookies.Select(c => new { name = c.Name, domain = c.Domain, path = c.Path, httpOnly = c.IsHttpOnly, secure = c.IsSecure, sameSite = c.SameSite.ToString(), session = c.IsSession, expiresUtc = c.IsSession ? null : (string)c.Expires.ToUniversalTime().ToString("o"), uifidLength = Uifid(c.Name) ? (int?)c.Value.Length : null }).ToArray());
        storageResult = new TaskCompletionSource<string>();
        await view.CoreWebView2.ExecuteScriptAsync(@"(async()=>{
            if(location.origin!=='https://www.douyin.com') return {originUnavailable:true};
            const meta=s=>Object.keys(s).map(k=>({key:k,uifidLength:/^uifid(_temp)?$/i.test(k)?(s.getItem(k)||'').length:null}));
            const names=document.cookie.split(';').map(x=>x.split('=')[0].trim()).filter(Boolean);
            let databases=[],indexedDBError=false;
            try {if(indexedDB.databases) databases=(await indexedDB.databases()).map(x=>({name:x.name,version:x.version})); else indexedDBError=true;} catch(e){indexedDBError=true;}
            const t=document.body?document.body.innerText:'';
            return {origin:location.origin,readyState:document.readyState,documentCookieNames:names,local:meta(localStorage),session:meta(sessionStorage),databases,indexedDBError,securityVisible:/验证码|安全验证|访问过于频繁|完成验证|captcha|verify you are human/i.test(t)};
        })().then(x=>chrome.webview.postMessage(x))");
        if(await Task.WhenAny(storageResult.Task, Task.Delay(3000)) != storageResult.Task) throw new TimeoutException();
        string raw = await storageResult.Task;
        storageResult = null;
        Log("storage_metadata", json.DeserializeObject(raw));
        if(raw.Contains("\"securityVisible\":true")) { await Finish("visible_security_verification"); return false; }
        return cookies.Any(c => Uifid(c.Name)) || Regex.IsMatch(raw, "\"(?:key|documentCookieNames)\"[^}]*\"UIFID(?:_TEMP)?\"", RegexOptions.IgnoreCase);
    }
    void StopSoon(string why) {
        if(stopped) return;
        stopped = true; reason = why; timer.Stop();
        BeginInvoke(new Action(async () => await Finish(why)));
    }
    async Task Finish(string why) {
        if(reason == "finished") return;
        stopped = true; timer.Stop(); reason = "finished";
        if(view != null) { view.CoreWebView2.Stop(); view.Dispose(); }
        await Task.WhenAny(browserExited.Task, Task.Delay(12000));
        Log("finished", new { reason = why, publicNavigations = navigationCount, observedRequests = requests, observedResponses = responses, blockedDetailRequests = blockedDetail, blockedImageMediaRequests = blockedMedia, scriptUrls = sdkScripts.ToArray(), browserProcessExited = browserExited.Task.IsCompleted, profilePath = profile, profileCleaned = false, explicitDetailExperiments = 0 });
        Close();
    }
    [STAThread] static int Main(string[] args) {
        if(args.Length == 1 && args[0] == "--self-test") {
            bool ok = CookieNames("__ac_nonce=secret; Path=/, UIFID=hidden; Expires=Wed, 01 Jan 2030 00:00:00 GMT").SequenceEqual(new[]{"__ac_nonce","UIFID"}) && Challenge("/waf_verify/") && !Challenge("/normal-sdk.js") && Uifid("uifid_temp") && !Uifid("ttwid");
            Console.WriteLine("{\"offlinePolicyTestPassed\":" + ok.ToString().ToLowerInvariant() + "}"); return ok ? 0 : 1;
        }
        if(args.Length != 2 || args[0] != "--run-public") { Console.Error.WriteLine("Use --self-test or --run-public <isolated-profile-parent>"); return 2; }
        Application.EnableVisualStyles(); Application.Run(new ContextBootstrapProbe(args[1])); return 0;
    }
}
