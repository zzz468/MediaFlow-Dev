using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

// User-interactive research only. No challenge automation, browser imports,
// content observation, signer, credential export or production integration.
class AuthorizedSessionPoc : Form {
    const string Home="https://www.douyin.com/";
    const string DetailUri="https://www.douyin.com/aweme/v1/web/aweme/detail/";
    readonly JavaScriptSerializer json=new JavaScriptSerializer {MaxJsonLength=2*1024*1024};
    readonly ContextAuthority authority=new ContextAuthority();
    readonly CancellationTokenSource cancel=new CancellationTokenSource();
    readonly Label status=new Label {Dock=DockStyle.Top,Height=70,Text="MediaFlow 专用测试会话：请本人正常完成页面交互。程序不会处理验证。\n完成后勾选确认并点击检查；只有可信 UIFID 才执行一次无签名 E1。关闭会清除本测试会话。"};
    readonly CheckBox completed=new CheckBox {Text="本人已正常完成页面交互，可以检查 context",AutoSize=true};
    readonly CheckBox challengeCompleted=new CheckBox {Text="本人已完成页面 challenge（如有）",AutoSize=true};
    readonly CheckBox loginCompleted=new CheckBox {Text="本人已完成登录（如有）",AutoSize=true};
    readonly Button inspect=new Button {Text="检查 context 并执行一次 E1",AutoSize=true,Enabled=false};
    readonly Button clear=new Button {Text="Clear test session / 取消",AutoSize=true};
    readonly FlowLayoutPanel actions=new FlowLayoutPanel {Dock=DockStyle.Bottom,Height=100,AutoScroll=true};
    readonly string target,parent,profile;
    WebView2 view; CoreWebView2Environment env; Task bootTask;
    TaskCompletionSource<bool> exitSignal;
    string ua; bool stopping,finishing,busy,allowTraffic=true,userConfirmed;
    bool challengeSeen,uifidSeen,ttwidSeen,sessionSeen,retained;
    bool? userChallenge,userLogin;
    int navigations,requests,responses,blockedDetail,detailRequests;
    string result="C4",reason="USER_CANCELLED";
    bool prepareW2,contextReady,sessionContextMode;
    string frozenUa;
    string sessionMetadataPath;
    bool dlStrategyMode;
    const string SecretPath=@"D:\MediaFlow-secrets\douyin-h2-context.env";

    AuthorizedSessionPoc(string id,bool prepare=false,string expectedUa=null,bool sessionMode=false,string metadataPath=null,bool dlMode=false) {
        prepareW2=prepare;frozenUa=expectedUa;sessionContextMode=sessionMode;
        sessionMetadataPath=metadataPath;
        dlStrategyMode=dlMode;
        target=id; parent=Path.Combine(Path.GetTempPath(),"mediaflow-v040-authorized-session");
        profile=Path.Combine(parent,"session-"+Guid.NewGuid().ToString("N"));
        Text="MediaFlow 授权 Douyin 测试会话 — 请本人操作"; Width=1150; Height=850;
        if(prepareW2){status.Text="请本人正常完成 challenge / 登录；不要在聊天粘贴凭据。\n完成后勾选并检查，可信UIFID只存仓库外secret；不会执行旧E1。";inspect.Text="检查并准备 W2 context（不发 detail）";}
        if(sessionContextMode){status.Text="请本人正常完成 challenge / 登录，完成后勾选并检查。\n本轮只准备 sessionid/sessionid_ss + ttwid；UIFID缺失不阻止；不会执行旧E1。";inspect.Text="检查并准备正常 session context";}
        if(dlStrategyMode){status.Text="W3-A已遇到context gate；请本人正常完成challenge/登录。\n勾选确认并检查后，只用sessionid/sessionid_ss+ttwid执行一次W3-B并清理，不读取UIFID或其他状态。";inspect.Text="检查正常session并执行唯一W3-B";}
        var panel=actions;
        panel.Controls.Add(completed);panel.Controls.Add(challengeCompleted);panel.Controls.Add(loginCompleted);
        panel.Controls.Add(inspect);panel.Controls.Add(clear);Controls.Add(panel);Controls.Add(status);
        completed.CheckedChanged+=(s,e)=>inspect.Enabled=completed.Checked&&!busy&&!stopping&&view!=null&&view.CoreWebView2!=null;
        inspect.Click+=async(s,e)=> {
            if(busy||stopping||!completed.Checked)return;
            busy=true;inspect.Enabled=false;completed.Enabled=false;
            userConfirmed=true;userChallenge=challengeCompleted.Checked;userLogin=loginCompleted.Checked;
            try { await CheckAndRun(); } catch(OperationCanceledException) { }
            catch(Exception ex) { Log("operation_error",new {type=ex.GetType().Name});reason="context_operation_failure"; }
            if(!contextReady||sessionContextMode)await Finish(reason);
        };
        clear.Click+=async(s,e)=>await Finish("USER_CANCELLED");
        FormClosing+=(s,e)=> {if(!finishing){e.Cancel=true;BeginInvoke(new Action(async()=>await Finish("USER_CANCELLED")));}};
        Shown+=async(s,e)=> {
            try {
                if(Directory.Exists(profile))throw new InvalidOperationException();
                Directory.CreateDirectory(profile);
                var acl=Directory.GetAccessControl(profile);acl.SetAccessRuleProtection(true,false);
                acl.AddAccessRule(new FileSystemAccessRule(WindowsIdentity.GetCurrent().User,FileSystemRights.FullControl,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
                acl.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null),FileSystemRights.FullControl,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
                Directory.SetAccessControl(profile,acl);
                File.WriteAllText(Path.Combine(profile,"mediaflow-owner.txt"),Path.GetFileName(profile));
                Log("profile_created",new {profilePath=profile,appOwned=true,importedState=false});
                bootTask=Boot();await bootTask;if(stopping)return;
                var initial=await view.CoreWebView2.CookieManager.GetCookiesAsync(Home);
                var scoped=await view.CoreWebView2.CookieManager.GetCookiesAsync(DetailUri);
                if(initial.Count!=0||scoped.Count!=0)throw new InvalidOperationException();
                Log("clean_preflight",new {cookies=0,uifidPresent=false,sessionPresent=false});
                inspect.Enabled=completed.Checked;view.CoreWebView2.Navigate(Home);
            } catch(Exception ex) {Log("initialization_error",new {type=ex.GetType().Name});reason="initialization_failure";}
            if(reason=="initialization_failure")await Finish(reason);
        };
    }
    void Log(string kind,object data) {Console.WriteLine(json.Serialize(new {utc=DateTime.UtcNow.ToString("o"),kind,data}));Console.Out.Flush();}
    static bool OwnedDomain(string domain) {
        return domain!=null&&(domain.TrimStart('.').Equals("douyin.com",StringComparison.OrdinalIgnoreCase)||domain.TrimStart('.').Equals("www.douyin.com",StringComparison.OrdinalIgnoreCase));
    }
    static bool SafeValue(string value) {return !string.IsNullOrEmpty(value)&&value.Length<=16384&&!value.Any(c=>char.IsControl(c)||char.IsWhiteSpace(c)||c==';');}
    static bool SafeUa(string value) {return !string.IsNullOrWhiteSpace(value)&&value.Length<=2048&&!value.Any(char.IsControl);}
    static bool MainframeAllowed(Uri uri) {return uri.Scheme=="https"&&uri.Port==443&&uri.UserInfo.Length==0&&(uri.Host=="douyin.com"||uri.Host.EndsWith(".douyin.com",StringComparison.OrdinalIgnoreCase)||uri.Host=="passport.bytedance.com"||uri.Host=="sso.bytedance.com");}
    void PauseForUser(string source) {
        if(stopping||busy||challengeSeen)return;
        challengeSeen=true;
        // Leave platform resources untouched; only the HUMAN can act.
        status.Text="检测到页面验证/拒绝信号：自动 context/E1 流程暂停，窗口保持打开。\n请本人正常完成页面要求；成功后确认并检查，无法完成可取消并清除。";
        Log("automation_paused_for_user",new {source=source,automaticChallengeAction=false,windowKeptOpen=true});
    }
    async Task Boot() {
        exitSignal=new TaskCompletionSource<bool>();env=await CoreWebView2Environment.CreateAsync(null,profile,new CoreWebView2EnvironmentOptions("--no-proxy-server"));
        env.BrowserProcessExited+=(s,e)=>exitSignal.TrySetResult(true);
        if(stopping)return;
        view=new WebView2 {Dock=DockStyle.Fill};Controls.Add(view);view.BringToFront();status.BringToFront();actions.BringToFront();
        await view.EnsureCoreWebView2Async(env);if(stopping)return;
        var core=view.CoreWebView2;ua=core.Settings.UserAgent;
        core.Settings.IsPasswordAutosaveEnabled=false;core.Settings.IsGeneralAutofillEnabled=false;core.Settings.AreDevToolsEnabled=false;
        core.NewWindowRequested+=(s,e)=>e.Handled=true;
        core.PermissionRequested+=(s,e)=>e.State=CoreWebView2PermissionState.Deny;
        core.DownloadStarting+=(s,e)=>e.Cancel=true;
        core.NavigationStarting+=(s,e)=> {
            if(e.Uri=="about:blank")return;
            Uri uri;if(stopping||!allowTraffic||!Uri.TryCreate(e.Uri,UriKind.Absolute,out uri)||!MainframeAllowed(uri)){e.Cancel=true;return;}
            navigations++;Log("platform_navigation",new {number=navigations,host=uri.Host});
        };
        core.AddWebResourceRequestedFilter("*",CoreWebView2WebResourceContext.All);
        core.WebResourceRequested+=(s,e)=> {
            Uri uri;if(!Uri.TryCreate(e.Request.Uri,UriKind.Absolute,out uri))return;
            if(stopping||!allowTraffic){e.Response=env.CreateWebResourceResponse(null,204,"Stopped","");return;}
            if(uri.AbsolutePath.Contains("/aweme/v1/web/aweme/detail/")){blockedDetail++;e.Response=env.CreateWebResourceResponse(null,204,"ResearchBoundary","");return;}
            if(ContextAuthority.SecurityResource(uri.AbsolutePath))PauseForUser("security_resource_marker");
            requests++;
        };
        core.WebResourceResponseReceived+=(s,e)=> {
            if(stopping)return;responses++;
            if(e.Response.StatusCode==401||e.Response.StatusCode==403||e.Response.StatusCode==429)PauseForUser("http_rejection_marker");
        };
        core.DocumentTitleChanged+=(s,e)=> {
            if(Regex.IsMatch(core.DocumentTitle??"","验证码|安全验证|captcha|verify you are human",RegexOptions.IgnoreCase))PauseForUser("visible_verification_marker");
        };
    }
    object Metadata(CoreWebView2Cookie c) {return new {present=true,length=c.Value.Length,domain=c.Domain,path=c.Path,expiry=c.IsSession?null:c.Expires.ToUniversalTime().ToString("o"),session=c.IsSession,httpOnly=c.IsHttpOnly,secure=c.IsSecure,sameSite=c.SameSite.ToString()};}
    bool Usable(CoreWebView2Cookie c) {return OwnedDomain(c.Domain)&&c.Path!=null&&c.Path.StartsWith("/")&&SafeValue(c.Value)&&(c.IsSession||c.Expires.ToUniversalTime()>DateTime.UtcNow);}
    async Task<CoreWebView2Cookie> Observe() {
        var cookies=await view.CoreWebView2.CookieManager.GetCookiesAsync(DetailUri);if(stopping)return null;
        var candidates=cookies.Where(c=>c.Name.Equals("UIFID",StringComparison.OrdinalIgnoreCase)).ToArray();
        var valid=candidates.Where(Usable).ToArray();
        bool found=candidates.Length==1&&valid.Length==1;
        var ttwid=cookies.Where(c=>c.Name=="ttwid").ToArray();
        var session=cookies.Where(c=>c.Name=="sessionid"||c.Name=="sessionid_ss").ToArray();
        ttwidSeen|=ttwid.Length>0;sessionSeen|=session.Length>0;uifidSeen|=found;
        authority.Observe(found,found&&!valid[0].IsSession?(DateTime?)valid[0].Expires.ToUniversalTime():null);
        Log("minimal_context_metadata",new {scope="detail-uri-only",uifidPresent=found,uifidCandidates=candidates.Length,uifid=candidates.Select(Metadata).ToArray(),ttwid=ttwid.Select(Metadata).ToArray(),sessionCookies=session.Select(Metadata).ToArray(),userInteractionConfirmed=userConfirmed,serverValidityVerified=false,accountCookieSent=false});
        return found?valid[0]:null;
    }
    async Task CheckAndRun() {
        Log("user_confirmation",new {normalInteractionCompleted=userConfirmed,challengeCompleted=userChallenge,loginCompleted=userLogin,basis="user-checkbox-self-report"});
        if(dlStrategyMode){await PrepareSessionSubset();return;}
        var cookie=await Observe();if(stopping)return;
        if(sessionContextMode){await PrepareSessionSubset();return;}
        if(prepareW2){
            if(cookie==null){result="AUTHORIZED PROFILE ESTABLISHED, REQUIRED CONTEXT NOT AVAILABLE";reason="required_context_absent";return;}
            if(!String.Equals(ua,frozenUa,StringComparison.Ordinal)){result="CONTEXT NOT ADMITTED";reason="actual_ua_differs_from_frozen_w2";return;}
            allowTraffic=false;view.CoreWebView2.Stop();
            var secretDir=Path.GetDirectoryName(SecretPath);
            if(File.Exists(SecretPath))throw new InvalidOperationException("Existing secret will not be overwritten");
            Directory.CreateDirectory(secretDir);
            var acl=new DirectorySecurity();acl.SetAccessRuleProtection(true,false);
            acl.AddAccessRule(new FileSystemAccessRule(WindowsIdentity.GetCurrent().User,FileSystemRights.FullControl,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
            acl.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null),FileSystemRights.FullControl,InheritanceFlags.ContainerInherit|InheritanceFlags.ObjectInherit,PropagationFlags.None,AccessControlType.Allow));
            Directory.SetAccessControl(secretDir,acl);
            using(var file=new FileStream(SecretPath,FileMode.CreateNew,FileAccess.Write,FileShare.None))
            using(var writer=new StreamWriter(file,new UTF8Encoding(false)))writer.WriteLine("DOUYIN_UIFID="+cookie.Value);
            contextReady=true;result="TRUSTED_CONTEXT_READY";reason="ready_for_single_w2";
            Log("trusted_context_ready",new {sourceType="app-owned-profile-cookie",secretPath=SecretPath,fields=new[]{"DOUYIN_UIFID"},present=true,length=cookie.Value.Length,expiry=cookie.IsSession?null:cookie.Expires.ToUniversalTime().ToString("o"),actualUa=ua,uaMatchesFrozenW2=true,profileKeptOpen=true,ttwidExported=false});
            status.Text="可信 context 已准备；profile 保持打开。等待程序完成一次 W2 后，请点击 Clear test session。";
            return;
        }
        if(cookie==null){result="C5";reason="normal_interaction_confirmed_required_context_absent_or_unusable";return;}
        allowTraffic=false;view.CoreWebView2.Stop();
        // No signature or account cookies. Actual profile UA avoids knowingly
        // mismatching the browser binding; this differs from the old baseline.
        status.Text="已发现本轮自有 profile 的 UIFID：执行一次无签名 E1，随后检查重启保留并清除。";
        await Detail(cookie,authority.Acquire());if(stopping)return;
        if(!await CloseBrowser()){reason="browser_exit_timeout";return;}
        bootTask=Boot();await bootTask;if(stopping)return;
        retained=await Observe()!=null;
        Log("profile_restart",new {uifidRetained=retained,homepageNavigated=false});
    }
    async Task PrepareSessionSubset() {
        if(!userConfirmed||userLogin!=true||!String.Equals(ua,frozenUa,StringComparison.Ordinal)){
            result="CONTEXT NOT ADMITTED";reason="normal_login_or_frozen_ua_not_confirmed";return;
        }
        allowTraffic=false;view.CoreWebView2.Stop();
        var scoped=await view.CoreWebView2.CookieManager.GetCookiesAsync(DetailUri);
        var selected=new List<CoreWebView2Cookie>();
        foreach(var name in new[]{"sessionid","sessionid_ss","ttwid"}){
            var found=scoped.Where(c=>c.Name==name).ToArray();
            if(found.Length>1||found.Any(c=>!Usable(c))){result="CONTEXT NOT ADMITTED";reason="ambiguous_or_expired_subset";return;}
            if(found.Length==1)selected.Add(found[0]);
        }
        if(!selected.Any(c=>c.Name=="ttwid")||!selected.Any(c=>c.Name=="sessionid"||c.Name=="sessionid_ss")){
            result="NORMAL SESSION SUBSET NOT AVAILABLE";reason="session_or_ttwid_absent";return;
        }
        ttwidSeen=true;sessionSeen=true;
        contextReady=true;result="AUTHORIZED_SESSION_SUBSET_READY";reason="ready_for_single_session_w2";
        Log("authorized_session_subset_ready",new {sourceType="app-owned-profile-cookie",contextStorage="child-process-environment",cookieNames=selected.Select(c=>c.Name).ToArray(),cookies=selected.Select(c=>new {name=c.Name,metadata=Metadata(c)}).ToArray(),actualUa=ua,uaMatchesFrozenW2=true,profileKeptOpen=true,uifidRequired=false,uifidExported=false});
        status.Text="正常 session 已准入，执行唯一一次固定W2请求；完成后自动清理本profile。";
        var start=new ProcessStartInfo(@"D:\新建文件夹\Python313\python.exe"){
            Arguments="\"D:\\projects\\mediaflow-v040\\v0.4.0\\research\\poc\\h2\\signer\\session_context_once.py\" --environment-context --metadata \""+sessionMetadataPath+"\"",
            UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true};
        if(dlStrategyMode){status.Text="执行唯一一次W3-B，其他W3条件不变；完成后自动清理。";
            start.Arguments="\"D:\\projects\\mediaflow-v040\\v0.4.0\\research\\poc\\h2\\signer\\w3_dl_strategy.py\" --experiment W3-B --metadata \""+sessionMetadataPath+"\"";}
        foreach(var name in new[]{"DOUYIN_SESSIONID","DOUYIN_SESSIONID_SS","DOUYIN_TTWID"})start.EnvironmentVariables.Remove(name);
        foreach(var c in selected)start.EnvironmentVariables["DOUYIN_"+c.Name.ToUpperInvariant()]=c.Value;
        using(var process=Process.Start(start)){
            var outputTask=process.StandardOutput.ReadToEndAsync();var errorTask=process.StandardError.ReadToEndAsync();
            await Task.Run(()=>process.WaitForExit());var output=await outputTask;var error=await errorTask;
            // Child output is restricted to redacted result metadata.
            Log(dlStrategyMode?"w3_b_child":"single_session_w2_child",new {exitCode=process.ExitCode,stderrBytes=error.Length});
            if(process.ExitCode==0){Console.Write(output);Console.Out.Flush();reason="single_session_w2_completed";}
            else reason="single_session_w2_not_completed";
        }
        start.EnvironmentVariables.Clear();selected.Clear();
    }
    async Task Detail(CoreWebView2Cookie cookie,ContextHandle handle) {
        if(stopping||!Usable(cookie)||!SafeUa(ua)||!authority.ConsumeDetail(handle))throw new InvalidOperationException();
        detailRequests++;
        var handler=new HttpClientHandler {UseProxy=false,UseCookies=false,AllowAutoRedirect=false};
        using(var client=new HttpClient(handler) {Timeout=TimeSpan.FromSeconds(25)})
        using(var request=new HttpRequestMessage(HttpMethod.Get,DetailUri+"?device_platform=webapp&aid=6383&channel=channel_pc_web&aweme_id="+target)) {
            request.Headers.TryAddWithoutValidation("User-Agent",ua);request.Headers.TryAddWithoutValidation("Accept","application/json");
            request.Headers.TryAddWithoutValidation("Referer",Home+"note/"+target);request.Headers.TryAddWithoutValidation("uifid",cookie.Value);
            Log("e1_start",new {targetId=target,maximumRequests=1,contextFields=new[]{"uifid-header"},uaMatchesProfile=true,signer=false,cookieHeader=false,proxy=false});
            using(var response=await client.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,cancel.Token))
            using(var stream=await response.Content.ReadAsStreamAsync())
            using(var memory=new MemoryStream()) {
                var buffer=new byte[8192];int n;while((n=await stream.ReadAsync(buffer,0,buffer.Length,cancel.Token))>0){if(memory.Length+n>2*1024*1024)throw new InvalidDataException();memory.Write(buffer,0,n);}
                if(stopping)return;
                var body=Encoding.UTF8.GetString(memory.ToArray());
                bool missing=body.IndexOf("Uifid Not Found",StringComparison.OrdinalIgnoreCase)>=0;
                bool signature=Regex.IsMatch(body,"(?:signature|signer)\\s+(?:not found|missing|invalid|rejected)",RegexOptions.IgnoreCase);
                bool safety=Regex.IsMatch(body,"captcha|jschallenge|verifycenter|verify_center",RegexOptions.IgnoreCase);
                bool detail=false,matched=false,business=false;int images=0;bool imagePost=false;object type=null;
                if((int)response.StatusCode==200)try {
                    var root=json.DeserializeObject(body) as Dictionary<string,object>;
                    var item=root!=null&&root.ContainsKey("aweme_detail")?root["aweme_detail"] as Dictionary<string,object>:null;
                    detail=item!=null;matched=detail&&item.ContainsKey("aweme_id")&&Convert.ToString(item["aweme_id"])==target;
                    business=matched&&root.ContainsKey("status_code")&&Convert.ToString(root["status_code"])=="0";
                    if(matched){if(item.ContainsKey("aweme_type"))type=item["aweme_type"] is int?item["aweme_type"]:null;
                        if(item.ContainsKey("images")&&item["images"] is IList)images=((IList)item["images"]).Count;
                        var post=item.ContainsKey("image_post_info")?item["image_post_info"] as Dictionary<string,object>:null;imagePost=post!=null;
                        if(images==0&&post!=null&&post.ContainsKey("images")&&post["images"] is IList)images=((IList)post["images"]).Count;}
                } catch(ArgumentException) { } catch(InvalidOperationException) { }
                result=Classify(missing,signature,safety,business);reason="e1_completed";
                if(business)authority.Validated(handle);else authority.Invalidate();
                Log("e1_result",new {classification=result,httpStatus=(int)response.StatusCode,bodyBytes=memory.Length,uifidNotFound=missing,explicitSignatureError=signature,safetyMarker=safety,uifidGateClearedEvidence=!missing&&!safety&&(signature||business),awemeDetail=detail,targetMatch=matched,businessJson=business,awemeType=type,imageCount=images,imagePostInfo=imagePost,galleryStructure=business&&images>0,rawBodyLogged=false,mediaDownloaded=false});
            }
        }
    }
    static string Classify(bool missing,bool signature,bool safety,bool business) {
        if(missing)return "C3";if(safety)return "C4";if(business)return "C2";if(signature)return "C1";
        return "C4"; // Unknown/access failure: no inference of signer acceptance.
    }
    async Task<bool> CloseBrowser() {
        if(view!=null){if(view.CoreWebView2!=null)view.CoreWebView2.Stop();view.Dispose();view=null;}
        if(exitSignal==null)return true;await Task.WhenAny(exitSignal.Task,Task.Delay(12000));return exitSignal.Task.IsCompleted;
    }
    async Task Finish(string why) {
        if(finishing)return;finishing=true;stopping=true;allowTraffic=false;cancel.Cancel();authority.BeginClear();
        if(why=="USER_CANCELLED"){result="C4";reason=why;}else reason=why;
        bool nativeClear=false,absent=false,exited=false,removed=false,secretRemoved=false;
        try {
            if(bootTask!=null)try{await bootTask;}catch(Exception){}
            if(view!=null&&view.CoreWebView2!=null){view.CoreWebView2.Stop();await view.CoreWebView2.Profile.ClearBrowsingDataAsync();nativeClear=true;
                var remaining=await view.CoreWebView2.CookieManager.GetCookiesAsync(DetailUri);absent=remaining.Count==0;}
            exited=await CloseBrowser();
            // Resolve full absolute paths before any recursive deletion.
            if(exited&&Directory.Exists(profile)&&ContextAuthority.IsOwnedPath(profile,parent)&&File.ReadAllText(Path.Combine(profile,"mediaflow-owner.txt"))==Path.GetFileName(profile)){
                Directory.Delete(Path.GetFullPath(profile),true);removed=!Directory.Exists(profile);}
            if(removed)authority.Cleared();
            if(contextReady&&!sessionContextMode&&File.Exists(SecretPath)){File.Delete(SecretPath);secretRemoved=!File.Exists(SecretPath);}
        }catch(Exception ex){Log("cleanup_error",new {type=ex.GetType().Name});}
        Log("finished",new {classification=result,reason=reason,userNormalInteractionConfirmed=userConfirmed,challengeDetected=challengeSeen,challengeCompletedSelfReport=userChallenge,loginCompletedSelfReport=userLogin,uifidObserved=uifidSeen,ttwidObserved=ttwidSeen,sessionCookieObserved=sessionSeen,uifidRetainedAfterRestart=retained,navigations=navigations,webRequestEvents=requests,webResponseEvents=responses,blockedPageDetailRequests=blockedDetail,explicitE1Requests=detailRequests,nativeProfileClear=nativeClear,scopedCookiesAbsentAfterClear=absent,browserProcessExited=exited,profileRemoved=removed,secretRemoved=secretRemoved,profilePath=profile});
        Close();
    }
    static int Test() {
        int n=0;if(Classify(true,true,false,false)=="C3")n++;
        if(Classify(false,true,false,false)=="C1")n++;
        if(Classify(false,true,true,false)=="C4")n++;
        if(Classify(false,false,false,true)=="C2")n++;
        if(Classify(false,false,false,false)=="C4")n++;
        if(OwnedDomain(".douyin.com")&&!OwnedDomain("douyin.com.evil.invalid"))n++;
        if(SafeValue("SYNTHETIC_ONLY")&&!SafeValue("x\r\ny")&&!SafeValue("x;y"))n++;
        if(MainframeAllowed(new Uri(Home))&&!MainframeAllowed(new Uri("https://evil.invalid/")))n++;
        if(SafeUa("Mozilla/5.0 (Windows NT 10.0)")&&!SafeUa("x\r\ny"))n++;
        var a=new ContextAuthority();a.Observe(true,null);var lease=a.Acquire();if(a.ConsumeDetail(lease)&&!a.ConsumeDetail(lease))n++;
        a.BeginClear();if(!a.ConsumeDetail(lease))n++;
        Console.WriteLine("{\"offlineAssertionsPassed\":"+n+",\"expected\":11,\"networkRequests\":0}");return n==11?0:1;
    }
    [STAThread]static int Main(string[] args) {
        if(args.Length==1&&args[0]=="--self-test")return Test();
        if(args.Length==4&&args[0]=="--prepare-w3-session"&&Regex.IsMatch(args[1],"^[0-9]{15,20}$")){
            var facts=new JavaScriptSerializer().DeserializeObject(File.ReadAllText(args[2])) as Dictionary<string,object>;
            var expected=Convert.ToString(facts["userAgent"]);if(!SafeUa(expected))return 2;
            Application.EnableVisualStyles();Application.Run(new AuthorizedSessionPoc(args[1],true,expected,true,Path.GetFullPath(args[3]),true));return 0;
        }
        if(args.Length==4&&args[0]=="--prepare-session-w2"&&Regex.IsMatch(args[1],"^[0-9]{15,20}$")){
            var facts=new JavaScriptSerializer().DeserializeObject(File.ReadAllText(args[2])) as Dictionary<string,object>;
            var expected=Convert.ToString(facts["userAgent"]);if(!SafeUa(expected))return 2;
            Application.EnableVisualStyles();Application.Run(new AuthorizedSessionPoc(args[1],true,expected,true,Path.GetFullPath(args[3])));return 0;
        }
        if(args.Length==3&&(args[0]=="--prepare-w2"||args[0]=="--prepare-session-w2")&&Regex.IsMatch(args[1],"^[0-9]{15,20}$")){
            var facts=new JavaScriptSerializer().DeserializeObject(File.ReadAllText(args[2])) as Dictionary<string,object>;
            var expected=Convert.ToString(facts["userAgent"]);if(!SafeUa(expected))return 2;
            Application.EnableVisualStyles();Application.Run(new AuthorizedSessionPoc(args[1],true,expected,args[0]=="--prepare-session-w2"));return 0;
        }
        if(args.Length!=2||args[0]!="--authorized-session"||!Regex.IsMatch(args[1],"^[0-9]{15,20}$"))return 2;
        Application.EnableVisualStyles();Application.Run(new AuthorizedSessionPoc(args[1]));return 0;
    }
}
