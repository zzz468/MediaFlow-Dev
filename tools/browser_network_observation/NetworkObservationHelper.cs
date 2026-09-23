using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

internal sealed class NetworkObservationForm : Form {
  internal static string AcquisitionMode="off";
  internal static WindowsPipeInput PipeInput;
  readonly JavaScriptSerializer json=new JavaScriptSerializer {MaxJsonLength=1500000};
  readonly ObservationPolicy policy;
  readonly Uri target;
  readonly WebView2 view=new WebView2 {Dock=DockStyle.Fill};
  readonly ResponseCorrelation pending=new ResponseCorrelation();
  readonly Dictionary<string,int> reasons=new Dictionary<string,int>();
  readonly ResponseMetadataDiagnostics metadataDiagnostics=new ResponseMetadataDiagnostics();
  readonly CancellationTokenSource cancellation=new CancellationTokenSource();
  readonly System.Windows.Forms.Timer timer=new System.Windows.Forms.Timer {Interval=750};
  readonly System.Diagnostics.Stopwatch elapsed=System.Diagnostics.Stopwatch.StartNew();
  TaskCompletionSource<string> acknowledgment;
  Stream activeStream;
  string profile;
  bool finished,busy,polling,navigationSucceeded;
  int responses,candidates,calls,totalBytes,rejected,busySkipped;
#if CONTROLLED_VALIDATION
  internal static ControlledCertificate LocalCertificate;
  // Controlled-only finite lifecycle diagnostics; never emit bodies or URLs.
  void Lifecycle(string phase) {
    if(AcquisitionMode!="immediateHandoff")return;
    // Only the STA owns counters; reader-thread phases carry no shared snapshot.
    if(Thread.CurrentThread.ManagedThreadId!=initializationThread)Console.Error.WriteLine("lifecycleDiagnostic="+json.Serialize(new {phase}));
    else Console.Error.WriteLine("lifecycleDiagnostic="+json.Serialize(new {phase,finished,busy,navigationSucceeded,filterCounts=new Dictionary<string,int>(reasons)}));
  }
  readonly int initializationThread=Thread.CurrentThread.ManagedThreadId;
  readonly string initializationApartment=Thread.CurrentThread.GetApartmentState().ToString();
  void AcquisitionDiagnostic(Exception error,Uri uri,string context,int status,string mime,int ordinal,int callbackThread,string callbackApartment,string phase,bool taskReturned) {
    Func<Exception,object> describe=ex=>ex==null?null:new {
      exceptionType=ex.GetType().FullName,
      message=System.Text.RegularExpressions.Regex.Replace((ex.Message??"").Substring(0,Math.Min(512,(ex.Message??"").Length)),@"https?://\S+|[A-Za-z]:\\\S+|(?i:cookie|authorization|token)\s*[:=]\s*\S+","[redacted]"),
      hresultHex="0x"+ex.HResult.ToString("X8"),hresultDecimal=ex.HResult,
      win32Code=ex is System.ComponentModel.Win32Exception?(int?)((System.ComponentModel.Win32Exception)ex).NativeErrorCode:null
    };
    var methods=error==null?new string[0]:new System.Diagnostics.StackTrace(error,false).GetFrames().Take(6).Select(f=>f.GetMethod().DeclaringType.FullName+"."+f.GetMethod().Name).ToArray();
    Console.Error.WriteLine("acquisitionDiagnostic="+json.Serialize(new {
      mode=AcquisitionMode,phase,taskReturned,error=describe(error),innerException=describe(error==null?null:error.InnerException),stackMethods=methods,
      initializationThread,initializationApartment,callbackThread,callbackApartment,
      callThread=Thread.CurrentThread.ManagedThreadId,callApartment=Thread.CurrentThread.GetApartmentState().ToString(),
      responseHost=uri.Host,route=policy.Route(uri),status,mime=(mime??"").Split(';')[0],resourceContext=context,
      correlationId=ordinal,correlationResolved=context!=null,finished,busy,navigationSucceeded,
      runtimeVersion=view.CoreWebView2.Environment.BrowserVersionString,
      sdkVersion=System.Diagnostics.FileVersionInfo.GetVersionInfo(typeof(CoreWebView2).Assembly.Location).ProductVersion,
      windowsVersion=Environment.OSVersion.Version.ToString()
    }));
  }
  EventHandler<CoreWebView2ServerCertificateErrorDetectedEventArgs> certificateHandler;
  void DetachCertificateHandler() {
    if(certificateHandler==null || view.CoreWebView2==null)return;
    view.CoreWebView2.ServerCertificateErrorDetected-=certificateHandler;
    certificateHandler=null;Count(FilterReason.tlsHandlerDetached);
  }
#endif
  internal NetworkObservationForm(ObservationPolicy p,Uri uri) {
    policy=p;target=uri;Text="MediaFlow anonymous network observation (diagnostic)";
    Width=1100;Height=760;Controls.Add(view);
    Shown+=async(s,e)=>await Start();
    FormClosing+=(s,e)=>{if(!finished){e.Cancel=true;Finish("cancelled");}};
  }
  void Emit(object value) {
#if CONTROLLED_VALIDATION
    Lifecycle("serializationStarted");
#endif
    string frame=json.Serialize(value);
#if CONTROLLED_VALIDATION
    Lifecycle("frameConstructed");
#endif
    Console.WriteLine(frame);
#if CONTROLLED_VALIDATION
    Lifecycle("stdoutWriteReturned");
#endif
    Console.Out.Flush();
#if CONTROLLED_VALIDATION
    Lifecycle("stdoutFlushReturned");
#endif
  }
  void Count(FilterReason reason) {string name=reason.ToString();reasons[name]=reasons.ContainsKey(name)?reasons[name]+1:1;}
  static string Header(CoreWebView2WebResourceResponseView response,string name) {try{return response.Headers.GetHeader(name);}catch{return null;}}
  async Task Start() {
    profile=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"profiles","network-observation-"+Guid.NewGuid().ToString("N"));
    timer.Tick+=async(s,e)=>{
      if(elapsed.ElapsedMilliseconds>=policy.DurationMs){Finish("timeout");return;}
      if(polling || finished)return;
      polling=true;try{await CheckStop();}finally{polling=false;}
    };
    timer.Start();
    var commandReader=Task.Run(()=> {
      try {
#if CONTROLLED_VALIDATION
        Lifecycle("commandReaderStarted");
#endif
        string line;
        while((line=ReadInput(128))!=null && !finished) {
#if CONTROLLED_VALIDATION
          Lifecycle("commandReadReturned");
#endif
          if(line.Length>128){BeginInvoke((Action)(()=>Finish("readFailed")));return;}
          var data=json.Deserialize<Dictionary<string,object>>(line);
          string command=Convert.ToString(data["command"]);
          BeginInvoke((Action)(()=> {
#if CONTROLLED_VALIDATION
            Lifecycle("commandDispatched");
#endif
            if(command=="stop")Finish("cancelled");
            else if(command=="found")Finish("found");
            else if(command=="continue" && acknowledgment!=null)acknowledgment.TrySetResult(command);
            else Finish("readFailed");
          }));
        }
        if(!finished)BeginInvoke((Action)(()=>Finish("cancelled")));
      }catch{
#if CONTROLLED_VALIDATION
        Lifecycle("commandReaderFailed");
#endif
        if(!finished)try{BeginInvoke((Action)(()=>Finish("readFailed")));}catch{}}
    });
    try {
      view.CreationProperties=new CoreWebView2CreationProperties {UserDataFolder=profile,IsInPrivateModeEnabled=true};
      Directory.CreateDirectory(profile);await view.EnsureCoreWebView2Async();if(finished)return;
      var core=view.CoreWebView2;
#if CONTROLLED_VALIDATION
      certificateHandler=(s,e)=> {
        try {
          e.Action=CoreWebView2ServerCertificateErrorAction.Cancel;
          if(!finished && LocalCertificate.Allows(e.RequestUri,e.ErrorStatus,e.ServerCertificate.ToPemEncoding())) {
            e.Action=CoreWebView2ServerCertificateErrorAction.AlwaysAllow;Count(FilterReason.tlsPinnedAccepted);
          }else {Count(FilterReason.tlsRejected);Finish("navigationFailed");}
        }catch {Count(FilterReason.tlsInspectionFailed);Finish("navigationFailed");}
      };
      core.ServerCertificateErrorDetected+=certificateHandler;
#endif
      core.Settings.IsPasswordAutosaveEnabled=false;core.Settings.IsGeneralAutofillEnabled=false;
      core.Settings.AreDefaultContextMenusEnabled=false;core.Settings.AreDevToolsEnabled=false;
      core.PermissionRequested+=(s,e)=>e.State=CoreWebView2PermissionState.Deny;
      core.NewWindowRequested+=(s,e)=>e.Handled=true;
      core.DownloadStarting+=(s,e)=>e.Cancel=true;
      core.ProcessFailed+=(s,e)=>Finish("runtimeUnavailable");
      core.NavigationStarting+=(s,e)=> {
        Uri u;if(!Uri.TryCreate(e.Uri,UriKind.Absolute,out u) || !policy.NavigationAllowed(u)) {
          e.Cancel=true;Finish("navigationRejected");
        } else if(u.AbsolutePath.IndexOf("passport",StringComparison.OrdinalIgnoreCase)>=0 || u.AbsolutePath.IndexOf("login",StringComparison.OrdinalIgnoreCase)>=0) {
          e.Cancel=true;Finish("loginRequired");
        }
      };
      core.NavigationCompleted+=(s,e)=>{
#if CONTROLLED_VALIDATION
        // The SDK raises this failure before the certificate event. The latter
        // validates the exact pin; all other navigation failures still stop.
        if(!e.IsSuccess && e.WebErrorStatus==CoreWebView2WebErrorStatus.CertificateIsInvalid)return;
        if(e.IsSuccess)DetachCertificateHandler();
#endif
        navigationSucceeded=e.IsSuccess;if(!e.IsSuccess){
          Count(e.WebErrorStatus==CoreWebView2WebErrorStatus.ConnectionAborted?FilterReason.navigationConnectionAborted:
            e.WebErrorStatus==CoreWebView2WebErrorStatus.CannotConnect?FilterReason.navigationCannotConnect:
            e.WebErrorStatus==CoreWebView2WebErrorStatus.ServerUnreachable?FilterReason.navigationServerUnreachable:
            e.WebErrorStatus==CoreWebView2WebErrorStatus.ErrorHttpInvalidServerResponse?FilterReason.navigationInvalidResponse:FilterReason.navigationOtherFailure);
          Finish("navigationFailed");
        }
      };
      core.AddWebResourceRequestedFilter("*",CoreWebView2WebResourceContext.All,CoreWebView2WebResourceRequestSourceKinds.All);
      core.WebResourceRequested+=(s,e)=> {
        Uri u;if(finished || !Uri.TryCreate(e.Request.Uri,UriKind.Absolute,out u))return;
        // Observe only. No request headers/body, mutation, response replacement.
        if((u.Host+u.AbsolutePath).IndexOf("waf-jschallenge",StringComparison.OrdinalIgnoreCase)>=0 ||
           (u.Host+u.AbsolutePath).IndexOf("lf-waf-js",StringComparison.OrdinalIgnoreCase)>=0) {Finish("browserVerification");return;}
        string type=e.ResourceContext==CoreWebView2WebResourceContext.Fetch ? "fetch" :
          e.ResourceContext==CoreWebView2WebResourceContext.XmlHttpRequest ? "xhr" : "other";
        pending.Add(e.Request.Uri,e.Request.Method,type);
        Count(FilterReason.correlationCreated);
      };
      core.WebResourceResponseReceived+=async(s,e)=>await Response(e);
      core.Navigate(target.AbsoluteUri);
    } catch {Finish("runtimeUnavailable");}
  }
  async Task CheckStop() {
    if(finished || view.CoreWebView2==null)return;
    try {
      // Read-only fixed stop classification; raw page text never crosses IPC.
      string value=await view.CoreWebView2.ExecuteScriptAsync(@"(()=>{const t=(document.body?.innerText||'').slice(0,20000);if(document.querySelector('input[type=password]')||/扫码登录|请先登录|登录后观看|登录后继续/.test(t))return 'loginRequired';if(/验证码|完成验证|安全验证/.test(t))return 'browserVerification';if(/所在地区不可|地区限制/.test(t))return 'regionRestricted';if(/无权访问|权限不足|付费观看|购买后观看/.test(t))return 'accessRestricted';return '';})()");
      string result=json.Deserialize<string>(value);
      if(result=="")return;
      if(result=="loginRequired" || result=="browserVerification" || result=="regionRestricted" || result=="accessRestricted")Finish(result);
      else {Count(FilterReason.stopClassificationFailed);Finish("readFailed");}
    } catch {if(!finished){Count(FilterReason.stopClassificationFailed);Finish("readFailed");}}
  }
  async Task Response(CoreWebView2WebResourceResponseReceivedEventArgs e) {
    if(finished)return;responses++;
    Count(FilterReason.filterSeen);
    Uri uri;if(!Uri.TryCreate(e.Request.Uri,UriKind.Absolute,out uri)){Count(FilterReason.rejectedScheme);Count(FilterReason.filterRejected);return;}
    string type=pending.Take(e.Request.Uri,e.Request.Method);
    if(type==null)Count(FilterReason.missingCorrelation);
    else Count(FilterReason.correlationResolved);
    string mime=Header(e.Response,"Content-Type");
    var reason=policy.Classify(uri,type,e.Response.StatusCode,mime);
    metadataDiagnostics.Record(uri,e.Request.Method,type,e.Response.StatusCode,mime,reason);
    if(reason!=FilterReason.acceptedCandidate){Count(reason);Count(FilterReason.filterRejected);return;}
    Count(FilterReason.filterAccepted);
    if(busy){busySkipped++;Count(FilterReason.busySkipped);return;}
    if(candidates>=policy.MaxCandidates || calls>=policy.MaxCalls){rejected++;Finish("budgetExceeded");return;}
    candidates++;
    long length;long? declared=long.TryParse(Header(e.Response,"Content-Length"),out length)?(long?)length:null;
    int remaining=policy.MaxTotal-totalBytes;
    if(remaining<=0 || declared<0 || declared>policy.MaxBody || declared>remaining) {
      rejected++;Count(FilterReason.rejectedDeclaredLength);if(remaining<=0 || declared>remaining)Finish("budgetExceeded");return;
    }
    busy=true;byte[] bytes=null;var failureStage=FilterReason.responseViewAcquireFailed;
    var readStats=new BoundedReadStatistics();
#if CONTROLLED_VALIDATION
    int callbackThread=Thread.CurrentThread.ManagedThreadId;string callbackApartment=Thread.CurrentThread.GetApartmentState().ToString();
    int responseOrdinal=responses;int responseStatus=e.Response.StatusCode;
    string acquisitionPhase="beforeCheckStop";bool contentTaskReturned=false;
#endif
    try {
#if CONTROLLED_VALIDATION
      if(AcquisitionMode=="immediate" || AcquisitionMode=="immediateHandoff") {if(finished)return;}
      else {await CheckStop();if(finished)return;}
#else
      if(AcquisitionMode=="douyinPublicObservation") {if(finished)return;}
      else {await CheckStop();if(finished)return;}
#endif
      Count(FilterReason.bodyReadAttempts);
      var response=e.Response;Count(FilterReason.responseViewObtained);
      failureStage=FilterReason.contentAcquireFailed;
#if CONTROLLED_VALIDATION
      acquisitionPhase="getContentInvocation";
      if(AcquisitionMode!="off")AcquisitionDiagnostic(null,uri,type,responseStatus,mime,responseOrdinal,callbackThread,callbackApartment,acquisitionPhase,false);
#endif
      var contentTask=response.GetContentAsync();
#if CONTROLLED_VALIDATION
      contentTaskReturned=true;acquisitionPhase="getContentCompletion";
#endif
      using(var stream=await contentTask) {
#if CONTROLLED_VALIDATION
        if(AcquisitionMode!="off")AcquisitionDiagnostic(null,uri,type,responseStatus,mime,responseOrdinal,callbackThread,callbackApartment,stream==null?"nullStream":"streamObtained",true);
#endif
        if(stream==null){Count(FilterReason.contentAcquireFailed);Count(FilterReason.bodyReadFailed);Finish("readFailed");return;}
        Count(FilterReason.bodyReadStreamObtained);
        activeStream=stream;
        failureStage=FilterReason.boundedReadFailed;
        Count(FilterReason.bodyReadStarted);
        bytes=await Task.Run(()=>ObservationPolicy.ReadBounded(stream,Math.Min(policy.MaxBody,remaining),cancellation.Token,readStats));
        Count(FilterReason.bodyReadSucceeded);
#if CONTROLLED_VALIDATION
        Lifecycle("boundedReadReturned");
#endif
        activeStream=null;
      }
      if(finished)return;totalBytes+=bytes.Length;
#if CONTROLLED_VALIDATION
      if(AcquisitionMode=="afterStop" || AcquisitionMode=="immediate") {AcquisitionDiagnostic(null,uri,type,responseStatus,mime,responseOrdinal,callbackThread,callbackApartment,"boundedReadCompleted",true);Finish("completed");return;}
#endif
      await CheckStop();if(finished)return;
      acknowledgment=new TaskCompletionSource<string>();calls++;
      Count(FilterReason.acceptedCandidate);
      failureStage=FilterReason.ipcWriteFailed;
      Emit(new {kind="candidate",host=uri.Host,route=policy.Route(uri),resourceType=type,status=e.Response.StatusCode,
        mime=(mime??"").Split(';')[0].Trim().ToLowerInvariant(),contentLength=declared,body=Convert.ToBase64String(bytes)});
      Count(FilterReason.ipcSent);
#if CONTROLLED_VALIDATION
      Lifecycle("candidateSendReturned");
#endif
      Array.Clear(bytes,0,bytes.Length);bytes=null;
      failureStage=FilterReason.ipcAckFailed;
      await acknowledgment.Task;
    } catch(BodyBudgetException){rejected++;Count(FilterReason.rejectedActualLength);Finish("budgetExceeded");}
#if CONTROLLED_VALIDATION
    catch(Exception error)
#else
    catch
#endif
    {
#if CONTROLLED_VALIDATION
      if(AcquisitionMode!="off" && failureStage==FilterReason.contentAcquireFailed)AcquisitionDiagnostic(error,uri,type,responseStatus,mime,responseOrdinal,callbackThread,callbackApartment,acquisitionPhase,contentTaskReturned);
#endif
      if(!finished){Count(failureStage);if(failureStage==FilterReason.contentAcquireFailed || failureStage==FilterReason.responseViewAcquireFailed || failureStage==FilterReason.boundedReadFailed)Count(FilterReason.bodyReadFailed);Finish("readFailed");}}
    finally {AddCount(FilterReason.bodyReadChunks,readStats.Chunks);AddCount(FilterReason.bodyBytes,readStats.Bytes);if(bytes!=null)Array.Clear(bytes,0,bytes.Length);activeStream=null;busy=false;acknowledgment=null;}
  }
  void AddCount(FilterReason reason,int count) {string name=reason.ToString();reasons[name]=(reasons.ContainsKey(name)?reasons[name]:0)+count;}
  static string ReadInput(int limit) {
    if(PipeInput!=null)return PipeInput.ReadLine(limit);
    return Console.ReadLine();
  }
  async void Finish(string outcome) {
#if CONTROLLED_VALIDATION
    Lifecycle("finishCalled");
#endif
    if(finished)return;finished=true;timer.Stop();cancellation.Cancel();
#if CONTROLLED_VALIDATION
    Lifecycle("finishEntered");
#endif
    if(acknowledgment!=null)acknowledgment.TrySetResult("stop");pending.Clear();
#if CONTROLLED_VALIDATION
    Lifecycle("ackContinuationReturned");
#endif
    try{if(activeStream!=null)activeStream.Dispose();}catch{}
#if CONTROLLED_VALIDATION
    try {
      DetachCertificateHandler();
      Lifecycle("tlsClearStarted");
      if(view.CoreWebView2!=null){await view.CoreWebView2.ClearServerCertificateErrorActionsAsync();Count(FilterReason.tlsCacheCleared);}
      Lifecycle("tlsClearReturned");
    }catch {Count(FilterReason.tlsCleanupFailed);}
#endif
#if CONTROLLED_VALIDATION
    Lifecycle("viewDisposeStarted");
#endif
    try{view.Dispose();}catch{}
#if CONTROLLED_VALIDATION
    Lifecycle("viewDisposeReturned");
#endif
    bool cleaned=profile==null;
    for(int i=0;i<10 && !cleaned;i++) {
      await Task.Delay(300);
      try {
        string absolute=Path.GetFullPath(profile);
        string allowed=Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"profiles")).TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar+"network-observation-";
        if(!absolute.StartsWith(allowed,StringComparison.OrdinalIgnoreCase))break;
        if(Directory.Exists(absolute))Directory.Delete(absolute,true);cleaned=true;
      }catch{}
    }
#if CONTROLLED_VALIDATION
    Lifecycle(cleaned?"profileCleanupSucceeded":"profileCleanupFailed");
    Lifecycle("finalEmitStarted");
#endif
    Emit(new {kind="final",outcome,profileCleaned=cleaned,navigationSucceeded,responses,candidates,calls,totalBytes,budgetRejected=rejected,busySkipped,filterCounts=reasons,
      responseMetadataSamples=metadataDiagnostics.Snapshot(),responseMetadataSamplesDropped=metadataDiagnostics.Dropped,
      correlationEvicted=pending.Evicted,protocolVersion=1});
#if CONTROLLED_VALIDATION
    Lifecycle("finalEmitReturned");
#endif
    Close();
  }
  [STAThread] static void Main(string[] args) {
    var serializer=new JavaScriptSerializer();
    try {
#if CONTROLLED_VALIDATION
      Console.SetError(new StreamWriter(Console.OpenStandardError(),new UTF8Encoding(false)) {AutoFlush=true});
      if(args.Length<1 || args.Length>2)throw new ArgumentException();
      LocalCertificate=new ControlledCertificate(args[0]);
      if(args.Length==2){AcquisitionMode=args[1];if(AcquisitionMode!="afterStop" && AcquisitionMode!="immediate" && AcquisitionMode!="immediateHandoff")throw new ArgumentException();}
      // Explicit experimental mode only; ordinary/default helper is unchanged.
      if(AcquisitionMode=="immediateHandoff")PipeInput=WindowsPipeInput.Open();
#else
      if(args.Length>1)throw new ArgumentException();
      if(args.Length==1){if(args[0]!="douyinPublicObservation")throw new ArgumentException();AcquisitionMode=args[0];PipeInput=WindowsPipeInput.Open();}
#endif
      string config=ReadInput(8192);if(config==null || config.Length>8192)throw new ArgumentException();
      var data=serializer.Deserialize<Dictionary<string,object>>(config);
      if(!data.ContainsKey("enabled") || !Convert.ToBoolean(data["enabled"]) || !data.ContainsKey("registered") || !Convert.ToBoolean(data["registered"])) {
        Console.WriteLine(serializer.Serialize(new {kind="final",outcome="disabled",profileCleaned=true}));return;
      }
      // Body-bearing stdout is private IPC, never an interactive diagnostic log.
      if(!Console.IsInputRedirected || !Console.IsOutputRedirected)throw new ArgumentException();
      Func<string,string[]> strings=name=>((System.Collections.IEnumerable)data[name]).Cast<object>().Select(Convert.ToString).ToArray();
      var p=new ObservationPolicy {Hosts=strings("hosts"),Paths=strings("paths"),MaxBody=Convert.ToInt32(data["maxBodyBytes"]),
        MaxTotal=Convert.ToInt32(data["maxTotalBytes"]),MaxCandidates=Convert.ToInt32(data["maxCandidates"]),
        MaxCalls=Convert.ToInt32(data["maxConsumerCalls"]),DurationMs=Convert.ToInt32(data["durationMs"])};
      p.Validate();Uri uri;if(!Uri.TryCreate(Convert.ToString(data["navigation"]),UriKind.Absolute,out uri) || !p.NavigationAllowed(uri))throw new ArgumentException();
#if CONTROLLED_VALIDATION
      if(uri.Host!="localhost" || p.Hosts.Length!=1 || p.Hosts[0]!="localhost")throw new ArgumentException();
#else
      if(AcquisitionMode=="douyinPublicObservation" &&
        (p.Hosts.Length!=1 || p.Hosts[0]!="www.douyin.com" ||
         p.Paths.Length!=1 || p.Paths[0]!="/aweme/v1/web/aweme/detail/" ||
         uri.Host!="www.douyin.com" || uri.Query.Length!=0 || uri.Fragment.Length!=0 ||
         !System.Text.RegularExpressions.Regex.IsMatch(uri.AbsolutePath,@"^/video/[1-9][0-9]*$")))throw new ArgumentException();
#endif
      Application.EnableVisualStyles();Application.Run(new NetworkObservationForm(p,uri));
#if CONTROLLED_VALIDATION
      if(AcquisitionMode=="immediateHandoff")Console.Error.WriteLine("lifecycleDiagnostic="+serializer.Serialize(new {phase="messageLoopReturned"}));
#endif
    } catch {Console.WriteLine(serializer.Serialize(new {kind="final",outcome="readFailed",profileCleaned=false}));}
    finally {if(PipeInput!=null)PipeInput.Dispose();}
  }
}
