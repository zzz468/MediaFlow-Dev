// Diagnostic infrastructure; no platform content schema or DevTools surface.
using System;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;

internal enum FilterReason { acceptedCandidate, rejectedScheme, rejectedHost, rejectedPath, rejectedResourceContext, rejectedStatus, rejectedMime, rejectedDeclaredLength, rejectedActualLength, missingCorrelation, busySkipped, stopClassificationFailed, contentAcquireFailed, boundedReadFailed, ipcWriteFailed, ipcAckFailed, filterSeen, filterRejected, filterAccepted, correlationCreated, correlationResolved, bodyReadAttempts, responseViewObtained, responseViewAcquireFailed, bodyReadStreamObtained, bodyReadStarted, bodyReadChunks, bodyBytes, bodyReadSucceeded, bodyReadFailed, ipcSent, tlsPinnedAccepted, tlsRejected, tlsHandlerDetached, tlsCacheCleared, tlsCleanupFailed, navigationConnectionAborted, navigationCannotConnect, navigationServerUnreachable, navigationInvalidResponse, navigationOtherFailure, tlsInspectionFailed }

internal sealed class BoundedReadStatistics {internal int Chunks,Bytes;}

// Finite metadata-only diagnostics. Query, headers and bodies never enter the
// key or snapshot. Numeric and opaque path segments are normalized.
internal sealed class ResponseMetadataDiagnostics {
  internal const int MaximumSamples=24;
  sealed class Entry {
    internal string Scheme,Host,Path,Method,ResourceType,Mime,RejectedBy;
    internal int Status,Count;
  }
  readonly List<Entry> entries=new List<Entry>();
  internal int Dropped {get;private set;}
  static string Mime(string value) {
    string mime=(value??"").Split(';')[0].Trim().ToLowerInvariant();
    return mime.Length<=64 && Regex.IsMatch(mime,@"^[a-z0-9!#$&^_.+\-/]+$")?mime:"other";
  }
  static string Method(string value) {
    string method=(value??"").ToUpperInvariant();
    return method=="GET" || method=="POST" || method=="HEAD" || method=="OPTIONS"?method:"other";
  }
  static string Path(Uri uri) {
    var parts=new List<string>();
    foreach(string raw in uri.AbsolutePath.Split('/')) {
      if(raw.Length==0)continue;
      string segment=Regex.IsMatch(raw,@"^[0-9]+$")?"<id>":
        raw.Length>32 || !Regex.IsMatch(raw,@"^[A-Za-z0-9._~-]+$")?"<redacted>":raw.ToLowerInvariant();
      parts.Add(segment);
      if(parts.Count==12)break;
    }
    string path="/"+String.Join("/",parts.ToArray());
    return path.Length<=160?path:path.Substring(0,160);
  }
  internal void Record(Uri uri,string method,string type,int status,string mime,FilterReason reason) {
    string normalizedMime=Mime(mime);
    if(uri==null)return;
    // Prefer the finite subset that can explain a public page/API data source.
    if(type!="xhr" && type!="fetch" && normalizedMime.IndexOf("json",StringComparison.Ordinal)<0 &&
       uri.Host!="www.douyin.com")return;
    string scheme=uri.Scheme=="https"?"https":uri.Scheme=="http"?"http":"other";
    string host=uri.Host.Length<=128 && Regex.IsMatch(uri.Host,@"^[a-z0-9]+(?:[.-][a-z0-9]+)*$")?uri.Host.ToLowerInvariant():"other";
    string path=Path(uri), normalizedMethod=Method(method), normalizedType=type=="xhr"?"xhr":type=="fetch"?"fetch":"other";
    string rejectedBy=reason.ToString();
    var existing=entries.Find(e=>e.Scheme==scheme && e.Host==host && e.Path==path && e.Method==normalizedMethod &&
      e.ResourceType==normalizedType && e.Status==status && e.Mime==normalizedMime && e.RejectedBy==rejectedBy);
    if(existing!=null){existing.Count++;return;}
    if(entries.Count>=MaximumSamples){Dropped++;return;}
    entries.Add(new Entry {Scheme=scheme,Host=host,Path=path,Method=normalizedMethod,ResourceType=normalizedType,
      Status=status,Mime=normalizedMime,RejectedBy=rejectedBy,Count=1});
  }
  internal List<Dictionary<string,object>> Snapshot() {
    var result=new List<Dictionary<string,object>>();
    foreach(var e in entries)result.Add(new Dictionary<string,object> {
      {"scheme",e.Scheme},{"host",e.Host},{"path",e.Path},{"method",e.Method},{"resourceType",e.ResourceType},
      {"status",e.Status},{"mime",e.Mime},{"rejectedBy",e.RejectedBy},{"count",e.Count}
    });
    return result;
  }
}

// Bounded FIFO multiset: equal URI+method requests do not overwrite each other.
// Only transient hashes are retained; records are removed on response or eviction.
internal sealed class ResponseCorrelation {
  sealed class Entry {internal string Key,Type;}
  readonly List<Entry> records=new List<Entry>();
  internal int Count {get{return records.Count;}}
  internal int Evicted {get;private set;}
  static string Key(string uri,string method) {
    using(var hash=SHA256.Create())return Convert.ToBase64String(hash.ComputeHash(Encoding.UTF8.GetBytes(method+"\n"+uri)));
  }
  internal void Add(string uri,string method,string type) {
    if(records.Count==64){records.RemoveAt(0);Evicted++;}
    records.Add(new Entry {Key=Key(uri,method),Type=type});
  }
  internal string Take(string uri,string method) {
    string key=Key(uri,method);
    int index=records.FindIndex(e=>e.Key==key);
    if(index<0)return null;
    string type=records[index].Type;records.RemoveAt(index);return type;
  }
  internal void Clear(){records.Clear();}
}

internal sealed class ObservationPolicy {
  internal string[] Hosts, Paths;
  internal int MaxBody=1048576, MaxTotal=4194304, MaxCandidates=32, MaxCalls=32, DurationMs=45000;
  static readonly Regex Excluded=new Regex("security|identity|login|passport|captcha|telemetry|analytics|report|tracking|verify|waf",RegexOptions.IgnoreCase);
  internal void Validate() {
    if(Hosts==null || Hosts.Length==0 || Hosts.Length>8 || Paths==null || Paths.Length==0 || Paths.Length>8 ||
       MaxBody<=0 || MaxBody>1048576 || MaxTotal<MaxBody || MaxTotal>4194304 ||
       MaxCandidates<=0 || MaxCandidates>32 || MaxCalls<=0 || MaxCalls>32 || DurationMs<=0 || DurationMs>45000)
      throw new ArgumentException("Invalid observation budget");
    foreach(string h in Hosts) if(!Regex.IsMatch(h,"^[a-z0-9]+(?:[.-][a-z0-9]+)*$"))throw new ArgumentException("Invalid host policy");
    foreach(string p in Paths) if(p=="/" || !p.StartsWith("/") || p.Length>256 || p.Contains("?") || p.Contains("#"))throw new ArgumentException("Invalid path policy");
  }
  internal bool NavigationAllowed(Uri uri) {
    return uri!=null && uri.Scheme=="https" && uri.Port==443 && uri.UserInfo=="" && Array.IndexOf(Hosts,uri.Host)>=0;
  }
  internal int Route(Uri uri) {
    if(!NavigationAllowed(uri) || Excluded.IsMatch(uri.Host+uri.AbsolutePath))return -1;
    for(int i=0;i<Paths.Length;i++)if(uri.AbsolutePath.StartsWith(Paths[i],StringComparison.Ordinal))return i;
    return -1;
  }
  internal bool Eligible(Uri uri,string type,int status,string mime) {
    return Classify(uri,type,status,mime)==FilterReason.acceptedCandidate;
  }
  internal FilterReason Classify(Uri uri,string type,int status,string mime) {
    mime=(mime??"").Split(';')[0].Trim().ToLowerInvariant();
    if(uri==null || uri.Scheme!="https" || uri.Port!=443 || uri.UserInfo!="")return FilterReason.rejectedScheme;
    if(Array.IndexOf(Hosts,uri.Host)<0)return FilterReason.rejectedHost;
    if(Route(uri)<0)return FilterReason.rejectedPath;
    if(type!="xhr" && type!="fetch")return FilterReason.rejectedResourceContext;
    if(status<200 || status>=300)return FilterReason.rejectedStatus;
    if(mime!="application/json" && !Regex.IsMatch(mime,"^application/[a-z0-9.-]+\\+json$"))return FilterReason.rejectedMime;
    return FilterReason.acceptedCandidate;
  }
  internal static byte[] ReadBounded(Stream stream,int maximum,CancellationToken cancellation,BoundedReadStatistics statistics=null) {
    using(var output=new MemoryStream()) {
      byte[] buffer=new byte[8192];
      try {
        while(true) {
          cancellation.ThrowIfCancellationRequested();
          int read=stream.Read(buffer,0,Math.Min(buffer.Length,maximum-(int)output.Length+1));
          if(read==0)return output.ToArray();
          if(statistics!=null){statistics.Chunks++;statistics.Bytes+=read;}
          if(output.Length+read>maximum)throw new BodyBudgetException();
          output.Write(buffer,0,read);
        }
      } finally {Array.Clear(buffer,0,buffer.Length);byte[] backing=output.GetBuffer();Array.Clear(backing,0,backing.Length);}
    }
  }
}
internal sealed class BodyBudgetException : Exception {}
