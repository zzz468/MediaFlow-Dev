using System;
using System.Collections;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

// Windows-specific research adapter. No WebView response bodies, DOM content
// decoder, network hooks, Cookie imports, signers or production dependencies.
class LocalSessionPoc : Form {
    const string Home = "https://www.douyin.com/";
    const string BaselineUa = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
    readonly ContextAuthority authority = new ContextAuthority();
    readonly JavaScriptSerializer json = new JavaScriptSerializer { MaxJsonLength = 2 * 1024 * 1024 };
    readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer { Interval = 1000 };
    readonly CancellationTokenSource cancel = new CancellationTokenSource();
    readonly Label status = new Label { Dock = DockStyle.Top, Height = 65, Text = "MediaFlow 独立研究会话。请仅完成抖音正常页面交互；出现安全验证将停止。\n会话只在本工具临时 profile 内，关闭后清除。" };
    readonly string target, parent, profile;
    readonly DateTime started = DateTime.UtcNow;
    WebView2 view; CoreWebView2Environment env;
    TaskCompletionSource<bool> exitSignal;
    bool stopping, busy, allowNavigation = true, normalSessionOpened, uifidSeen, survivedRestart;
    int navigationCount, requests, responses, blockedDetail, detailRequests;
    string runtimeUa;
    Task bootTask;
    LocalSessionPoc(string id) {
        target = id;
        parent = Path.Combine(Path.GetTempPath(), "mediaflow-v040-local-session");
        profile = Path.Combine(parent, "session-" + Guid.NewGuid().ToString("N"));
        Text = "MediaFlow Douyin Local Session — Research PoC"; Width = 1080; Height = 780;
        Controls.Add(status);
        var clear = new Button { Text = "停止并清除本轮抖音会话", Dock = DockStyle.Bottom, Height = 40 };
        Controls.Add(clear); clear.Click += async (s,e) => await Finish("user_cancelled");
        FormClosing += (s,e) => { if(!stopping) { e.Cancel = true; StopSoon("window_closed"); } };
        Shown += async (s,e) => {
            try {
                if(Directory.Exists(profile)) throw new InvalidOperationException();
                Directory.CreateDirectory(profile);
                // Scope credentials to this user's newly created profile only.
                var access = Directory.GetAccessControl(profile);
                access.SetAccessRuleProtection(true,false);
                var currentUser = WindowsIdentity.GetCurrent().User;
                access.AddAccessRule(new FileSystemAccessRule(currentUser,FileSystemRights.FullControl,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
                access.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null),FileSystemRights.FullControl,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
                Directory.SetAccessControl(profile,access);
                File.WriteAllText(Path.Combine(profile,"mediaflow-owner.txt"), Path.GetFileName(profile));
                Log("profile_created", new { profilePath = profile, appOwned = true, importedState = false, credentialFilesInRepo = false });
                bootTask=Boot(); await bootTask;
                if(stopping) return;
                var initial = await view.CoreWebView2.CookieManager.GetCookiesAsync(Home);
                if(initial.Count != 0) throw new InvalidOperationException();
                Log("initial_context", new { scopedCookieCount = 0, uifidPresent = false, loginStatePresent = false });
                normalSessionOpened = true; view.CoreWebView2.Navigate(Home); timer.Start();
            } catch(Exception ex) { Log("error", new { type = ex.GetType().Name }); StopSoon("initialization_failure"); }
        };
        timer.Tick += async (s,e) => {
            if(stopping || busy) return; busy = true;
            try {
                if((DateTime.UtcNow-started).TotalMinutes >= 5) { StopSoon("bounded_user_window_timeout"); return; }
                if(await Observe()) { timer.Stop(); await PositiveFlow(); }
            } catch(Exception ex) { Log("error",new {type=ex.GetType().Name}); StopSoon("context_operation_failure"); }
            finally { busy = false; }
        };
    }
    void Log(string kind, object data) { Console.WriteLine(json.Serialize(new {utc=DateTime.UtcNow.ToString("o"),kind,data})); Console.Out.Flush(); }
    async Task Boot() {
        exitSignal = new TaskCompletionSource<bool>();
        env = await CoreWebView2Environment.CreateAsync(null, profile);
        env.BrowserProcessExited += (s,e) => exitSignal.TrySetResult(true);
        if(stopping) return;
        view = new WebView2 { Dock = DockStyle.Fill }; Controls.Add(view); view.BringToFront(); status.BringToFront();
        await view.EnsureCoreWebView2Async(env);
        if(stopping) return;
        var core = view.CoreWebView2;
        runtimeUa = core.Settings.UserAgent;
        core.Settings.IsPasswordAutosaveEnabled = false; core.Settings.IsGeneralAutofillEnabled = false;
        core.Settings.AreDevToolsEnabled = false;
        core.NewWindowRequested += (s,e) => e.Handled = true;
        core.PermissionRequested += (s,e) => e.State = CoreWebView2PermissionState.Deny;
        core.DownloadStarting += (s,e) => e.Cancel = true;
        core.NavigationStarting += (s,e) => {
            if(e.Uri == "about:blank") return;
            Uri uri;
            if(stopping || !allowNavigation || !Uri.TryCreate(e.Uri,UriKind.Absolute,out uri)) { e.Cancel=true; return; }
            bool ownedPlatform = uri.Scheme == "https" && (uri.Host == "douyin.com" || uri.Host.EndsWith(".douyin.com",StringComparison.OrdinalIgnoreCase) || uri.Host == "passport.bytedance.com" || uri.Host == "sso.bytedance.com");
            if(!ownedPlatform || ContextAuthority.SecurityResource(uri.AbsolutePath)) { e.Cancel=true; StopSoon("navigation_boundary_or_security"); return; }
            navigationCount++; Log("platform_navigation",new {host=uri.Host,number=navigationCount});
        };
        core.AddWebResourceRequestedFilter("*", CoreWebView2WebResourceContext.All);
        core.WebResourceRequested += (s,e) => {
            Uri uri; if(!Uri.TryCreate(e.Request.Uri,UriKind.Absolute,out uri)) return;
            if(stopping || !allowNavigation) { e.Response=env.CreateWebResourceResponse(null,204,"Stopped",""); return; }
            if(ContextAuthority.SecurityResource(uri.AbsolutePath)) {
                e.Response=env.CreateWebResourceResponse(null,204,"Blocked","");
                Log("security_resource_blocked",new {host=uri.Host,path=uri.AbsolutePath}); StopSoon("explicit_security_challenge"); return;
            }
            if(uri.AbsolutePath.Contains("/aweme/v1/web/aweme/detail/")) { blockedDetail++; e.Response=env.CreateWebResourceResponse(null,204,"Blocked",""); return; }
            requests++;
        };
        core.WebResourceResponseReceived += (s,e) => {
            if(stopping) return; responses++;
            if(e.Response.StatusCode==401 || e.Response.StatusCode==403 || e.Response.StatusCode==429) StopSoon("http_access_or_security_rejection");
        };
        core.DocumentTitleChanged += (s,e) => {
            if(!stopping && Regex.IsMatch(core.DocumentTitle ?? "","验证码|安全验证|captcha|verify you are human",RegexOptions.IgnoreCase)) StopSoon("visible_security_verification");
        };
    }
    async Task<bool> Observe() {
        if(stopping) return false;
        var cookies = await view.CoreWebView2.CookieManager.GetCookiesAsync("https://www.douyin.com/aweme/v1/web/aweme/detail/");
        if(stopping) return false;
        var valid = cookies.Where(c => c.Name.Equals("UIFID",StringComparison.OrdinalIgnoreCase) && !string.IsNullOrEmpty(c.Value) && (c.IsSession || c.Expires.ToUniversalTime()>DateTime.UtcNow)).ToArray();
        bool found=valid.Length==1;
        authority.Observe(found,found && !valid[0].IsSession ? (DateTime?)valid[0].Expires.ToUniversalTime() : null);
        Log("context_metadata",new {
            uifidPresent=found, uifidCandidates=valid.Length,
            uifid=valid.Select(c=>new {domain=c.Domain,path=c.Path,httpOnly=c.IsHttpOnly,secure=c.IsSecure,sameSite=c.SameSite.ToString(),length=c.Value.Length,session=c.IsSession,expiresUtc=c.IsSession ? null : c.Expires.ToUniversalTime().ToString("o")}).ToArray(),
            uifidTempPresent=cookies.Any(c=>c.Name.Equals("UIFID_TEMP",StringComparison.OrdinalIgnoreCase)),
            ttwidPresent=cookies.Any(c=>c.Name=="ttwid"), msTokenPresent=cookies.Any(c=>c.Name=="msToken"),
            loginCookiePresent=cookies.Any(c=>c.Name=="sessionid" || c.Name=="sessionid_ss"),
            status=authority.Status.State.ToString(), scope="detail-uri-only", validityVerified=false
        });
        uifidSeen |= found; return found;
    }
    async Task PositiveFlow() {
        allowNavigation=false; view.CoreWebView2.Stop();
        status.Text="已检测到正常 profile 的 UIFID。正在验证重启保留及一次 detail 对照，随后清除会话。";
        if(!await CloseBrowser()) { await Finish("browser_exit_timeout"); return; }
        if(stopping) return;
        bootTask=Boot(); await bootTask; // Same owned profile, offline: no homepage navigation.
        if(stopping) return;
        survivedRestart=await Observe();
        Log("profile_restart",new {uifidPresent=survivedRestart,networkNavigations=0});
        if(stopping) return;
        if(survivedRestart) await Detail(authority.Acquire());
        await Finish(survivedRestart ? "single_detail_completed" : "uifid_not_retained_after_restart");
    }
    async Task Detail(ContextHandle handle) {
        if(stopping) return;
        var cookies=await view.CoreWebView2.CookieManager.GetCookiesAsync("https://www.douyin.com/aweme/v1/web/aweme/detail/");
        if(stopping) return;
        var uifid=cookies.SingleOrDefault(c=>c.Name.Equals("UIFID",StringComparison.OrdinalIgnoreCase));
        if(uifid==null || string.IsNullOrEmpty(uifid.Value) || !authority.ConsumeDetail(handle)) { Log("detail_skipped",new {reason="context_lease_unavailable"}); return; }
        detailRequests++;
        // Single changed request input: uifid header only. Login Cookies,
        // ttwid/msToken/signers and query UIFID are deliberately not sent.
        var handler=new HttpClientHandler {AllowAutoRedirect=false,UseCookies=false,UseProxy=false};
        using(var client=new HttpClient(handler) {Timeout=TimeSpan.FromSeconds(25)})
        using(var request=new HttpRequestMessage(HttpMethod.Get,"https://www.douyin.com/aweme/v1/web/aweme/detail/?device_platform=webapp&aid=6383&channel=channel_pc_web&aweme_id="+target)) {
            request.Headers.TryAddWithoutValidation("User-Agent",BaselineUa);
            request.Headers.TryAddWithoutValidation("Accept","application/json");
            request.Headers.TryAddWithoutValidation("Referer",Home+"note/"+target);
            request.Headers.TryAddWithoutValidation("uifid",uifid.Value);
            Log("detail_start",new {targetId=target,maximumRequests=1,addedFields=new[]{"uifid-header"},cookieSent=false,aBogusSent=false,xBogusSent=false,baselineUaEqualsProfileUa=BaselineUa==runtimeUa,proxy="DIRECT"});
            using(var response=await client.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,cancel.Token)) {
                using(var stream=await response.Content.ReadAsStreamAsync())
                using(var memory=new MemoryStream()) {
                    byte[] buffer=new byte[8192]; int count;
                    while((count=await stream.ReadAsync(buffer,0,buffer.Length,cancel.Token))>0) { if(memory.Length+count>2*1024*1024) throw new InvalidDataException(); memory.Write(buffer,0,count); }
                    string body=Encoding.UTF8.GetString(memory.ToArray());
                    bool missing=body.Contains("ArgusSecurityPlugin Uifid Not Found");
                    bool signer=Regex.IsMatch(body,"(?:signature|signer)\\s+(?:not found|missing|invalid)",RegexOptions.IgnoreCase);
                    bool detail=false,matched=false; int images=0;
                    if((int)response.StatusCode==200) {
                        try { var root=json.DeserializeObject(body) as System.Collections.Generic.Dictionary<string,object>;
                            var item=root!=null && root.ContainsKey("aweme_detail") ? root["aweme_detail"] as System.Collections.Generic.Dictionary<string,object> : null;
                            detail=item!=null; matched=detail && item.ContainsKey("aweme_id") && Convert.ToString(item["aweme_id"])==target;
                            if(matched && item.ContainsKey("images") && item["images"] is IList) images=((IList)item["images"]).Count;
                        } catch(ArgumentException) { }
                    }
                    bool argus=body.IndexOf("ArgusSecurityPlugin",StringComparison.OrdinalIgnoreCase)>=0;
                    bool positiveGateChange=!missing && (signer || matched);
                    // Passing the UIFID layer is not full context/account validation.
                    if(matched && (int)response.StatusCode==200) authority.Validated(handle); else authority.Invalidate();
                    Log("detail_result",new {httpStatus=(int)response.StatusCode,bodyBytes=memory.Length,argusUifidMissing=missing,argusMarker=argus,explicitSignatureError=signer,uifidGateClearedEvidence=positiveGateChange,detailPresent=detail,targetMatch=matched,imageCount=images,rawBodyLogged=false});
                }
            }
        }
    }
    void StopSoon(string why) {
        if(stopping) return;
        // Revoke immediately, before queued callbacks or native cleanup.
        stopping=true; allowNavigation=false; authority.Invalidate(); cancel.Cancel(); timer.Stop();
        BeginInvoke(new Action(async()=>await Finish(why)));
    }
    async Task<bool> CloseBrowser() {
        if(view!=null) { if(view.CoreWebView2!=null) view.CoreWebView2.Stop(); view.Dispose(); view=null; }
        if(exitSignal==null) return true;
        await Task.WhenAny(exitSignal.Task,Task.Delay(12000)); return exitSignal.Task.IsCompleted;
    }
    bool finishing;
    async Task Finish(string why) {
        if(finishing) return; finishing=true; stopping=true; allowNavigation=false; timer.Stop(); cancel.Cancel(); authority.BeginClear();
        bool nativeClear=false, absent=false, exited=false, removed=false;
        try {
            if(bootTask!=null) { try {await bootTask;} catch(Exception) { } }
            if(view!=null && view.CoreWebView2!=null) {
                view.CoreWebView2.Stop();
                await view.CoreWebView2.Profile.ClearBrowsingDataAsync(); nativeClear=true;
                var remaining=await view.CoreWebView2.CookieManager.GetCookiesAsync("https://www.douyin.com/aweme/v1/web/aweme/detail/");
                absent=!remaining.Any(c=>c.Name.Equals("UIFID",StringComparison.OrdinalIgnoreCase));
            }
            exited=await CloseBrowser();
            if(exited && ContextAuthority.IsOwnedPath(profile,parent) && File.ReadAllText(Path.Combine(profile,"mediaflow-owner.txt"))==Path.GetFileName(profile)) { Directory.Delete(profile,true); removed=!Directory.Exists(profile); }
            if(removed) authority.Cleared();
        } catch(Exception ex) { Log("cleanup_error",new {type=ex.GetType().Name}); }
        Log("finished",new {reason=why,normalSessionWindowOpened=normalSessionOpened,uifidObserved=uifidSeen,uifidRetainedAfterRestart=survivedRestart,navigations=navigationCount,observedRequests=requests,observedResponses=responses,webviewDetailRequestsBlocked=blockedDetail,explicitDetailRequests=detailRequests,nativeProfileClear=nativeClear,uifidAbsentAfterClear=absent,browserProcessExited=exited,profileRemoved=removed,profilePath=profile,status=authority.Status.State.ToString(),accountLoginCompleted="not_observed"});
        Close();
    }
    static int Test() {
        int passed=0;
        var a=new ContextAuthority(); if(!a.ConsumeDetail(null)) passed++;
        a.Observe(true,DateTime.UtcNow.AddMinutes(1)); var lease=a.Acquire();
        var b=new ContextAuthority(); b.Observe(true,null); if(!b.ConsumeDetail(lease)) passed++;
        if(a.ConsumeDetail(lease) && !a.ConsumeDetail(lease)) passed++;
        var bLease=b.Acquire(); b.BeginClear(); if(!b.ConsumeDetail(bLease)) passed++;
        a.Invalidate(); a.Validated(lease); if(a.Status.State==ContextState.Rejected) passed++;
        var c=new ContextAuthority(); c.Observe(true,DateTime.UtcNow.AddMinutes(-1)); bool expired=false; try {c.Acquire();} catch(InvalidOperationException){expired=true;} if(expired) passed++;
        string p=Path.Combine(Path.GetTempPath(),"mediaflow-v040-local-session");
        if(!ContextAuthority.IsOwnedPath(Path.Combine(p,"..","session-"+new string('a',32)),p)) passed++;
        if(ContextAuthority.IsOwnedPath(Path.Combine(p,"session-"+new string('a',32)),p)) passed++;
        if(ContextAuthority.SecurityResource("/obj/waf-jschallenge/test.js") && !ContextAuthority.SecurityResource("/normal/login.js")) passed++;
        var forged=a.Status; forged.State=ContextState.Validated; forged.UifidPresent=true; if(a.Status.State==ContextState.Rejected && !a.Status.UifidPresent) passed++;
        Console.WriteLine("{\"offlineAssertionsPassed\":"+passed+",\"expected\":10,\"networkRequests\":0}"); return passed==10 ? 0 : 1;
    }
    [STAThread] static int Main(string[] args) {
        if(args.Length==1 && args[0]=="--self-test") return Test();
        if(args.Length!=2 || args[0]!="--user-session" || !Regex.IsMatch(args[1],"^[0-9]{15,20}$")) { Console.Error.WriteLine("Use --self-test or --user-session <public-target-id>"); return 2; }
        Application.EnableVisualStyles(); Application.Run(new LocalSessionPoc(args[1])); return 0;
    }
}
