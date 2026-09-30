using System;
using System.Text.RegularExpressions;

// Research contract: no WebView or Cookie value crosses this boundary.
enum ContextState { Absent, Establishing, AvailableUnvalidated, Validated, Rejected, Clearing, Cleared }
sealed class ContextHandle {
    internal readonly Guid Owner;
    internal readonly int Epoch;
    internal ContextHandle(Guid owner, int epoch) { Owner = owner; Epoch = epoch; }
    public override string ToString() { return "LocalContextHandle(redacted)"; }
}
sealed class ContextStatus {
    public ContextState State;
    public bool UifidPresent;
    public DateTime? ExpiresUtc;
    public DateTime? LastValidatedUtc;
}
interface IDouyinContextProvider {
    ContextStatus Status { get; }
    ContextHandle Acquire();
    void Invalidate();
}
// Provider-controlled transport receives a handle, not credentials. Production
// would offer a scoped async request operation + establish/clear lifecycle API.
sealed class ContextAuthority : IDouyinContextProvider {
    readonly Guid owner = Guid.NewGuid();
    int epoch;
    bool detailSpent;
    readonly ContextStatus state = new ContextStatus { State = ContextState.Absent };
    public ContextStatus Status { get { return new ContextStatus { State=state.State, UifidPresent=state.UifidPresent, ExpiresUtc=state.ExpiresUtc, LastValidatedUtc=state.LastValidatedUtc }; } }
    public ContextAuthority() { }
    public void Observe(bool present, DateTime? expiry) {
        if(state.State == ContextState.Clearing || state.State == ContextState.Cleared || state.State == ContextState.Rejected) return;
        state.UifidPresent = present; state.ExpiresUtc = expiry;
        state.State = present ? ContextState.AvailableUnvalidated : ContextState.Establishing;
    }
    public ContextHandle Acquire() {
        if(!Usable()) throw new InvalidOperationException("Context unavailable");
        return new ContextHandle(owner, epoch);
    }
    bool Usable() { return state.UifidPresent && (state.State == ContextState.AvailableUnvalidated || state.State == ContextState.Validated) && (!state.ExpiresUtc.HasValue || state.ExpiresUtc > DateTime.UtcNow); }
    public bool ConsumeDetail(ContextHandle handle) {
        if(handle == null || handle.Owner != owner || handle.Epoch != epoch || detailSpent || !Usable()) return false;
        detailSpent = true; return true;
    }
    public void Validated(ContextHandle handle) {
        if(handle == null || handle.Owner != owner || handle.Epoch != epoch || !Usable()) return;
        state.State = ContextState.Validated; state.LastValidatedUtc = DateTime.UtcNow;
    }
    public void Invalidate() { epoch++; state.State = ContextState.Rejected; state.UifidPresent = false; }
    public void BeginClear() { epoch++; state.State = ContextState.Clearing; state.UifidPresent = false; }
    public void Cleared() { state.State = ContextState.Cleared; state.ExpiresUtc = null; state.LastValidatedUtc = null; }
    public static bool SecurityResource(string path) { return Regex.IsMatch(path, "waf[-_/]|jschallenge|captcha|verifycenter|verify_center", RegexOptions.IgnoreCase); }
    public static bool IsOwnedPath(string path, string parent) {
        string full = System.IO.Path.GetFullPath(path), root = System.IO.Path.GetFullPath(parent);
        return string.Equals(System.IO.Path.GetDirectoryName(full), root, StringComparison.OrdinalIgnoreCase) && Regex.IsMatch(System.IO.Path.GetFileName(full), "^session-[a-f0-9]{32}$");
    }
}
