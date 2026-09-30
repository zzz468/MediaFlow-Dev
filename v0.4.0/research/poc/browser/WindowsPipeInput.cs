using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

// Explicit Windows helper modes only. On this host Console's redirected
// stream stalls after the configuration line although the pipe contains bytes.
// FileStream on the same non-owned stdin handle receives the acknowledgement.
internal sealed class WindowsPipeInput : IDisposable {
  readonly StreamReader reader;
  [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr GetStdHandle(int identifier);
  internal static WindowsPipeInput Open() {
    var handle=new SafeFileHandle(GetStdHandle(-10),false);
    if(handle.IsInvalid){handle.Dispose();throw new IOException("Controlled stdin unavailable");}
    return new WindowsPipeInput(new FileStream(handle,FileAccess.Read,128,false));
  }
  internal WindowsPipeInput(Stream stream) {reader=new StreamReader(stream,new UTF8Encoding(false,true),false,128);}
  internal string ReadLine(int limit) {
    if(limit<1 || limit>8192)throw new ArgumentOutOfRangeException("limit");
    var line=new StringBuilder();int c;
    while((c=reader.Read())!=-1) {
      if(c=='\n')return line.ToString().TrimEnd('\r');
      if(line.Length>=limit)throw new IOException("Controlled command limit exceeded");
      line.Append((char)c);
    }
    // An unterminated command is not accepted as an acknowledgement.
    if(line.Length!=0)throw new IOException("Controlled command interrupted");
    return null;
  }
  public void Dispose(){reader.Dispose();}
}
