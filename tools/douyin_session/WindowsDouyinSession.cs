// MediaFlow-owned session helper. No platform content observation or detail
// requests. Only redirected private IPC, owned profile and standard runtime facts.
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

internal sealed class WindowsDouyinSession : Form {
  static readonly string Profile=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"MediaFlow","private-session","douyin-v040");
  const string Scope="https://www.douyin.com/aweme/v1/web/aweme/detail/";
  readonly string command; readonly JavaScriptSerializer json=new JavaScriptSerializer();
  WebView2 view; CoreWebView2Environment env; TaskCompletionSource<bool> exited=new TaskCompletionSource<bool>();
  object result=new{status="unavailable"}; bool finishing; bool checkingSession;
  readonly Timer loginTimer=new Timer{Interval=1500};
  WindowsDouyinSession(string command){this.command=command;Text="MediaFlow 抖音会话";Width=1100;Height=800;
    var cancel=new Button{Text="取消",Dock=DockStyle.Bottom,Height=35};
    Controls.Add(cancel);
    Controls.Add(new Label{Text="首次解析抖音图文可能需要完成一次抖音登录或安全验证。登录状态保存在本机，后续通常可直接解析。",Dock=DockStyle.Bottom,Height=42,TextAlign=System.Drawing.ContentAlignment.MiddleCenter});
    loginTimer.Tick+=async(s,e)=>{
      if(finishing||checkingSession||view==null)return;
      checkingSession=true;
      try{
        await ReadSession(false);
        var data=json.Deserialize<Dictionary<string,object>>(json.Serialize(result));
        if((string)data["status"]=="ready")await Finish();
      }catch{result=new{status="noSession"};}
      finally{checkingSession=false;}
    };
    cancel.Click+=async(s,e)=>{result=new{status="cancelled"};await Finish();};
    FormClosing+=(s,e)=>{if(!finishing){e.Cancel=true;BeginInvoke(new Action(async()=>{result=new{status="cancelled"};await Finish();}));}};
    Shown+=async(s,e)=>{bool failed=false;try{await Initialize();}catch{failed=true;}if(failed)await Finish();};
  }
  async Task Initialize(){
    if(command=="restore"&&!File.Exists(Path.Combine(Profile,"mediaflow-owned.txt"))){result=new{status="noSession"};await Finish();return;}
    if(command=="clear"){
      if(Directory.Exists(Profile)&&!File.Exists(Path.Combine(Profile,"mediaflow-owned.txt"))){await Finish();return;}
      var full=Path.GetFullPath(Profile);
      var expected=Path.GetFullPath(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"MediaFlow","private-session"));
      if(Path.GetDirectoryName(full)!=expected||Path.GetFileName(full)!="douyin-v040")throw new InvalidOperationException();
      if(Directory.Exists(full)&&File.ReadAllText(Path.Combine(full,"mediaflow-owned.txt"))!="MediaFlow Douyin v040")throw new InvalidOperationException();
      if(Directory.Exists(full))Directory.Delete(full,true);
      result=new{status=Directory.Exists(Profile)?"cleanupFailed":"cleared"};await Finish();return;
    }
    if(command!="restore"&&command!="establish"){await Finish();return;}
    if(Directory.Exists(Profile)&&!File.Exists(Path.Combine(Profile,"mediaflow-owned.txt"))){await Finish();return;}
    Directory.CreateDirectory(Profile);File.WriteAllText(Path.Combine(Profile,"mediaflow-owned.txt"),"MediaFlow Douyin v040");
    env=await CoreWebView2Environment.CreateAsync(null,Profile,new CoreWebView2EnvironmentOptions("--no-proxy-server"));
    env.BrowserProcessExited+=(s,e)=>exited.TrySetResult(true);
    view=new WebView2{Dock=DockStyle.Fill};Controls.Add(view);view.SendToBack();await view.EnsureCoreWebView2Async(env);
    var core=view.CoreWebView2;core.Settings.IsPasswordAutosaveEnabled=false;core.Settings.IsGeneralAutofillEnabled=false;core.Settings.AreDevToolsEnabled=false;
    core.DownloadStarting+=(s,e)=>e.Cancel=true;core.NewWindowRequested+=(s,e)=>e.Handled=true;core.PermissionRequested+=(s,e)=>e.State=CoreWebView2PermissionState.Deny;
    core.NavigationStarting+=(s,e)=>{if(e.Uri=="about:blank")return;Uri u;if(!Uri.TryCreate(e.Uri,UriKind.Absolute,out u)||u.Scheme!="https"||!(u.Host=="douyin.com"||u.Host.EndsWith(".douyin.com")||u.Host=="passport.bytedance.com"||u.Host=="sso.bytedance.com"))e.Cancel=true;};
    if(command=="restore"){await ReadSession();await Finish();}else{Show();Activate();core.Navigate("https://www.douyin.com/");loginTimer.Start();}
  }
  async Task ReadSession(bool stopNavigation=true){
    if(stopNavigation)view.CoreWebView2.Stop();var all=await view.CoreWebView2.CookieManager.GetCookiesAsync(Scope);
    var allowed=new[]{"sessionid","sessionid_ss","ttwid","msToken"};var selected=new Dictionary<string,string>();DateTime? expiry=null;
    foreach(var name in allowed){var found=all.Where(c=>c.Name==name&&c.Domain.TrimStart('.')=="douyin.com").ToArray();if(found.Length>1)throw new InvalidOperationException();
      if(found.Length==0)continue;var cookie=found[0];if(!cookie.IsSession&&cookie.Expires.ToUniversalTime()<=DateTime.UtcNow)continue;
      if(String.IsNullOrEmpty(cookie.Value)||cookie.Value.Any(ch=>ch<33||ch>126||ch==';'))throw new InvalidOperationException();
      selected[name]=cookie.Value;
      if((name=="sessionid"||name=="sessionid_ss")&&!cookie.IsSession){var end=cookie.Expires.ToUniversalTime();if(!expiry.HasValue||end<expiry.Value)expiry=end;}
    }
    if(!selected.ContainsKey("sessionid")&&!selected.ContainsKey("sessionid_ss")){result=new{status="noSession"};return;}
    // Read standard browser/window measurements only, not DOM/storage/SDK data.
    var script="JSON.stringify({ua:navigator.userAgent,metrics:[innerWidth,innerHeight,outerWidth,outerHeight,screenX,screenY,scrollX,scrollY,screen.width,screen.height,screen.availWidth,screen.availHeight,innerWidth,innerHeight,screen.colorDepth,screen.pixelDepth],query:{screen_width:String(screen.width),screen_height:String(screen.height),browser_language:navigator.language,browser_platform:navigator.platform,browser_name:'Edge',browser_version:(navigator.userAgent.match(/Edg\\/([0-9.]+)/)||['',''])[1],browser_online:String(navigator.onLine),engine_name:'Blink',engine_version:(navigator.userAgent.match(/Chrome\\/([0-9.]+)/)||['',''])[1],os_name:'Windows',os_version:'10',cpu_core_num:String(navigator.hardwareConcurrency)}})";
    var raw=await view.CoreWebView2.ExecuteScriptAsync(script);var facts=json.Deserialize<Dictionary<string,object>>(json.Deserialize<string>(raw));
    result=new{status="ready",cookies=selected,ua=facts["ua"],metrics=facts["metrics"],query=facts["query"],expiresAt=expiry.HasValue?expiry.Value.ToString("o"):null};
  }
  async Task Finish(){if(finishing)return;finishing=true;loginTimer.Stop();try{if(view!=null){view.CoreWebView2.Stop();view.Dispose();view=null;
      await Task.WhenAny(exited.Task,Task.Delay(12000));if(!exited.Task.IsCompleted)result=new{status="unavailable"};}
    }catch{result=new{status="unavailable"};}
    var stream=Console.OpenStandardOutput();var data=System.Text.Encoding.UTF8.GetBytes(json.Serialize(result));stream.Write(data,0,data.Length);stream.Flush();Close();
  }
  [STAThread] static void Main(){
    if(!Console.IsInputRedirected||!Console.IsOutputRedirected)return;
    try{var text=Console.In.ReadLine();if(text==null||text.Length>256)return;var data=new JavaScriptSerializer().Deserialize<Dictionary<string,string>>(text);
      Application.EnableVisualStyles();var form=new WindowsDouyinSession(data["command"]);if(data["command"]!="establish"){form.WindowState=FormWindowState.Minimized;form.ShowInTaskbar=false;}Application.Run(form);
    }catch{} // No raw exception, context, URL or credential output.
  }
}
