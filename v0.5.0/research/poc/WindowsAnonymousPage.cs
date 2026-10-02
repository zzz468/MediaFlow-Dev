using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Web.Script.Serialization;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

// Independent Level1 probe: ordinary own profile, no cookies exported, no fingerprint changes.
internal sealed class AnonymousPage : Form {
  readonly WebView2 view = new WebView2 { Dock = DockStyle.Fill };
  readonly Timer timeout = new Timer { Interval = 20000 };
  readonly JavaScriptSerializer json = new JavaScriptSerializer { MaxJsonLength = 4000000 };
  readonly string target, profile;
  bool finished;
  internal AnonymousPage(string url, string directory) {
    target=url; profile=directory; Text="MediaFlow v050 anonymous page research";
    Width=1000; Height=720; Controls.Add(view);
    Shown+=async(s,e)=>await Start();
    timeout.Tick+=(s,e)=>Finish(new { status="STOPPED", failure="networkFailure", reason="browserTimeout" });
    FormClosing+=(s,e)=>{ if(!finished) { e.Cancel=true; Finish(new {status="STOPPED", failure="unknown", reason="userClosed"}); } };
  }
  static bool PlatformHost(Uri uri) {
    return uri.Scheme=="https" && (uri.Host=="xiaohongshu.com" || uri.Host.EndsWith(".xiaohongshu.com") || uri.Host=="xhslink.cn" || uri.Host=="xhslink.com");
  }
  static bool ResourceHost(Uri uri) {
    return PlatformHost(uri) || ((uri.Scheme=="https" || uri.Scheme=="http") && uri.Host.EndsWith(".xhscdn.com"));
  }
  async Task Start() {
    try {
      var options=new CoreWebView2EnvironmentOptions("--no-proxy-server");
      var env=await CoreWebView2Environment.CreateAsync(null,profile,options);
      await view.EnsureCoreWebView2Async(env);
      view.CoreWebView2.Settings.AreDevToolsEnabled=false;
      view.CoreWebView2.Settings.IsPasswordAutosaveEnabled=false;
      view.CoreWebView2.Settings.IsGeneralAutofillEnabled=false;
      view.CoreWebView2.NewWindowRequested+=(s,e)=>{e.Handled=true;};
      view.CoreWebView2.PermissionRequested+=(s,e)=>{e.State=CoreWebView2PermissionState.Deny;};
      view.CoreWebView2.AddWebResourceRequestedFilter("*",CoreWebView2WebResourceContext.All);
      view.CoreWebView2.WebResourceRequested+=(s,e)=>{
        Uri u;
        if(Uri.TryCreate(e.Request.Uri,UriKind.Absolute,out u) && !ResourceHost(u))
          e.Response=env.CreateWebResourceResponse(new MemoryStream(),403,"Research origin policy","");
      };
      view.CoreWebView2.NavigationStarting+=(s,e)=>{
        Uri u;
        if(!Uri.TryCreate(e.Uri,UriKind.Absolute,out u) || !PlatformHost(u)) {e.Cancel=true;Finish(new {status="STOPPED",failure="unsupportedUrl"});return;}
        if(u.AbsolutePath=="/login" || u.AbsolutePath.Contains("website-login")) {e.Cancel=true;Finish(new {status="STOPPED",failure="loginRequired",path=u.AbsolutePath});}
        else if(u.AbsolutePath.Contains("captcha") || u.AbsolutePath.Contains("/sorry/")) {e.Cancel=true;Finish(new {status="STOPPED",failure="securityChallenge",path=u.AbsolutePath});}
      };
      view.CoreWebView2.NavigationCompleted+=async(s,e)=>{
        if(finished) return;
        if(e.HttpStatusCode==401||e.HttpStatusCode==403||e.HttpStatusCode==429) {Finish(new {status="STOPPED",failure=e.HttpStatusCode==401?"loginRequired":e.HttpStatusCode==429?"rateLimited":"resourceForbidden",http=e.HttpStatusCode});return;}
        if(!e.IsSuccess) {Finish(new {status="STOPPED",failure="networkFailure",reason=e.WebErrorStatus.ToString()});return;}
        // Reads only the target work from already loaded first-party page state.
        var script=@"(()=>{const p=location.pathname; if(p==='/login'||document.querySelector('.login-container'))return JSON.stringify({status:'STOPPED',failure:'loginRequired'}); if(p.includes('captcha')||p.includes('/sorry/'))return JSON.stringify({status:'STOPPED',failure:'securityChallenge'}); const m=p.match(/\/(?:explore|discovery\/item)\/([0-9a-f]{24})/); if(!m)return JSON.stringify({status:'STOPPED',failure:'parseNoMatch',reason:'noteIdMissing'}); const id=m[1],s=window.__INITIAL_STATE__||{}; const unwrap=v=>v&&v.value||v; let n=unwrap(unwrap(unwrap(s.noteData||{}).data||{}).noteData); if(!n||n.noteId!==id){const map=unwrap(unwrap(s.note||{}).noteDetailMap)||{}; n=Object.values(map).map(v=>unwrap(v.note)).find(v=>v&&v.noteId===id);} if(!n)return JSON.stringify({status:'STOPPED',failure:'parseNoMatch',noteId:id,stateKeys:Object.keys(s)}); return JSON.stringify({status:'TARGET_DATA',noteId:id,title:n.title,type:n.type,author:(n.user||{}).nickname||(n.user||{}).nickName,imageCount:(n.imageList||[]).length,images:(n.imageList||[]).map((i,index)=>({index:index+1,url:i.urlDefault||i.url,width:i.width,height:i.height})),videoStreams:Object.values((((n.video||{}).media||{}).stream)||{}).flat().filter(v=>v.masterUrl).map(v=>({url:v.masterUrl,size:v.size})),runtime:'WebView2',sessionLevel:1});})()";
        try {var raw=await view.CoreWebView2.ExecuteScriptAsync(script); var text=json.Deserialize<string>(raw); Console.WriteLine(text);finished=true;timeout.Stop();Close();}
        catch(Exception error) {Finish(new {status="STOPPED",failure="parseNoMatch",reason=error.GetType().Name});}
      };
      timeout.Start(); view.CoreWebView2.Navigate(target);
    } catch(Exception error) { Finish(new {status="STOPPED",failure="dependencyFailure",reason=error.GetType().Name}); }
  }
  void Finish(object result) {if(finished)return;finished=true;timeout.Stop();Console.WriteLine(json.Serialize(result));Close();}
  protected override void Dispose(bool disposing) {if(disposing){timeout.Dispose();view.Dispose();}base.Dispose(disposing);}
  [STAThread] static void Main(string[] args) {
    Console.OutputEncoding=new UTF8Encoding(false);
    Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
    using(var form=new AnonymousPage(args[0],args[1])) Application.Run(form);
  }
}
