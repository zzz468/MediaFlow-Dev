using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

// Offline about:blank facts ONLY. No platform navigation, Cookie API,
// remote scripts, SDK hooks, content observation, or identity substitution.
class RuntimeFacts : Form {
    WebView2 view; CoreWebView2Environment env;
    readonly string profile=Path.Combine(Path.GetFullPath("build/runtime-facts"),"facts-"+Guid.NewGuid().ToString("N"));
    readonly TaskCompletionSource<bool> exited=new TaskCompletionSource<bool>();
    RuntimeFacts() {
        Width=1080;Height=780;Opacity=0;ShowInTaskbar=false;
        StartPosition=FormStartPosition.Manual;Location=new System.Drawing.Point(0,0);
        Shown+=async(s,e)=> {
            try {
                env=await CoreWebView2Environment.CreateAsync(null,profile,new CoreWebView2EnvironmentOptions("--no-proxy-server"));
                env.BrowserProcessExited+=(a,b)=>exited.TrySetResult(true);
                view=new WebView2 {Dock=DockStyle.Fill};Controls.Add(view);await view.EnsureCoreWebView2Async(env);
                view.CoreWebView2.NavigationStarting+=(a,b)=>{if(!b.Uri.StartsWith("about:")&&!b.Uri.StartsWith("data:"))b.Cancel=true;};
                var ready=new TaskCompletionSource<bool>();
                view.CoreWebView2.NavigationCompleted+=(a,b)=>{Console.Error.WriteLine("local-navigation-success="+b.IsSuccess+";error="+b.WebErrorStatus);ready.TrySetResult(b.IsSuccess);};
                view.CoreWebView2.NavigateToString("<!doctype html><html><head><title>Local runtime facts</title></head><body></body></html>");
                await Task.WhenAny(ready.Task,Task.Delay(10000));
                if(!ready.Task.IsCompleted||!ready.Task.Result)throw new InvalidOperationException();
                string facts=await view.CoreWebView2.ExecuteScriptAsync(@"({userAgent:navigator.userAgent, platform:navigator.platform, metrics:[innerWidth,innerHeight,outerWidth,outerHeight,screenX,screenY,pageXOffset,pageYOffset,screen.width,screen.height,screen.availWidth,screen.availHeight,innerWidth,innerHeight,screen.colorDepth,screen.pixelDepth], source:'offline-about-blank-runtime', platformNavigations:0})");
                if(facts=="null")throw new InvalidOperationException();
                Console.WriteLine(facts);
                await view.CoreWebView2.Profile.ClearBrowsingDataAsync();view.Dispose();view=null;
                await Task.WhenAny(exited.Task,Task.Delay(12000));
                string parent=Path.GetFullPath("build/runtime-facts");
                if(!exited.Task.IsCompleted||Path.GetDirectoryName(Path.GetFullPath(profile))!=parent||!Path.GetFileName(profile).StartsWith("facts-"))throw new InvalidOperationException();
                Directory.Delete(Path.GetFullPath(profile),true);
                Console.Error.WriteLine("offline-profile-cleared="+(!Directory.Exists(profile)));
            }catch(Exception ex){Console.Error.WriteLine("offline-facts-error="+ex.GetType().Name);Environment.ExitCode=1;}
            Close();
        };
    }
    [STAThread]static void Main(){Application.EnableVisualStyles();Application.Run(new RuntimeFacts());}
}
