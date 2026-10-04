param(
    [switch]$AuditOnly,
    [string]$ExpectedMainCommit,
    [string]$NotesPath = 'v0.6.0/release/release-notes.md',
    [string]$OutputPath = 'dist/v060-publication.json'
)
$ErrorActionPreference = 'Stop'
$repo = 'zzz468/MediaFlow-Dev'
$tag = 'v0.6.0'
$api = "https://api.github.com/repos/$repo"
$previousPrompt = $env:GIT_TERMINAL_PROMPT
$env:GIT_TERMINAL_PROMPT = '0'
try {
    # Use Git's own configured credential manager for the explicitly authorized
    # repository. Never print or persist the credential or HTTP headers.
    $credentialLines = "protocol=https`nhost=github.com`npath=$repo.git`n`n" | git credential fill
    if ($LASTEXITCODE -ne 0) { throw 'GitHub credential manager unavailable.' }
    $credential = @{}
    foreach ($line in $credentialLines) {
        if ($line -match '^([^=]+)=(.*)$') { $credential[$Matches[1]] = $Matches[2] }
    }
    if (-not $credential['password']) { throw 'GitHub credential unavailable.' }
    $headers = @{
        Authorization = "Bearer $($credential['password'])"
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'MediaFlow-release'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    $repository = Invoke-RestMethod -Uri $api -Headers $headers
    if ($repository.default_branch -ne 'main') { throw 'Unexpected default branch.' }
    if ($AuditOnly) {
        [pscustomobject]@{ repository = $repository.full_name; defaultBranch = $repository.default_branch; auth = 'PASS' }
        return
    }
    if ($ExpectedMainCommit -notmatch '^[0-9a-f]{40}$') { throw 'Expected final main commit required.' }
    $main = Invoke-RestMethod -Uri "$api/git/ref/heads/main" -Headers $headers
    $ref = Invoke-RestMethod -Uri "$api/git/ref/tags/$tag" -Headers $headers
    if ($ref.object.type -ne 'tag') { throw 'Annotated tag required.' }
    $annotated = Invoke-RestMethod -Uri "$api/git/tags/$($ref.object.sha)" -Headers $headers
    if ($main.object.sha -ne $ExpectedMainCommit -or $annotated.object.sha -ne $ExpectedMainCommit) {
        throw 'GitHub main/tag do not match expected release commit.'
    }
    $commit = Invoke-RestMethod -Uri "$api/git/commits/$ExpectedMainCommit" -Headers $headers
    $tree = Invoke-RestMethod -Uri "$api/git/trees/$($commit.tree.sha)?recursive=1" -Headers $headers
    if ($tree.truncated) { throw 'Remote tree truncated; completeness cannot be verified.' }
    $required = @(
        'lib/features/parser/data/instagram/instagram_parser.dart',
        'lib/features/parser/data/x/x_parser.dart',
        'test/features/parser/instagram_parser_test.dart',
        'test/features/parser/x_parser_test.dart',
        'v0.6.0/release/README.md', 'third_party/x_syndication/LICENSE'
    )
    $manifest = Get-Content -LiteralPath 'v0.6.0/release/untracked-audit.json' -Raw | ConvertFrom-Json
    $required += @($manifest | Where-Object disposition -eq 'submit' | ForEach-Object path)
    foreach ($path in ($required | Select-Object -Unique)) {
        if ($path -notin $tree.tree.path) { throw "Required published file missing: $path" }
    }
    $assetNames = @('MediaFlow-v0.6.0-windows-x64.zip', 'MediaFlow-v0.6.0-android.apk')
    foreach ($name in $assetNames) {
        if (-not (Test-Path -LiteralPath "dist/$name" -PathType Leaf)) { throw "Missing formal asset: $name" }
    }
    $body = @{
        tag_name = $tag; target_commitish = $ExpectedMainCommit; name = 'MediaFlow v0.6.0'
        body = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $NotesPath))
        draft = $false; prerelease = $false
    } | ConvertTo-Json
    try {
        $release = Invoke-RestMethod -Uri "$api/releases/tags/$tag" -Headers $headers
    } catch {
        if ([int]$_.Exception.Response.StatusCode -ne 404) { throw }
        $release = Invoke-RestMethod -Uri "$api/releases" -Headers $headers -Method Post -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes($body))
    }
    if ($release.draft -or $release.prerelease -or @($release.assets | Where-Object { $_.name -notin $assetNames }).Count) {
        throw 'Unexpected pre-existing release state; stop without replacing it.'
    }
    foreach ($name in $assetNames) {
        if (@($release.assets | Where-Object name -eq $name).Count -eq 1) { continue }
        $upload = "https://uploads.github.com/repos/$repo/releases/$($release.id)/assets?name=$([Uri]::EscapeDataString($name))"
        Invoke-RestMethod -Uri $upload -Headers $headers -Method Post -InFile "dist/$name" -ContentType 'application/octet-stream' | Out-Null
    }
    $remote = Invoke-RestMethod -Uri "$api/releases/$($release.id)" -Headers $headers
    if ($remote.assets.Count -ne 2 -or $remote.draft -or $remote.prerelease) { throw 'Unexpected release/assets state.' }
    $verified = @()
    foreach ($name in $assetNames) {
        $local = Get-Item -LiteralPath "dist/$name"
        $hash = (Get-FileHash -LiteralPath $local.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $asset = @($remote.assets | Where-Object name -eq $name)
        if ($asset.Count -ne 1 -or $asset[0].size -ne $local.Length) { throw "Remote asset size/name mismatch: $name" }
        if ($asset[0].digest) {
            if ($asset[0].digest.ToLowerInvariant() -ne "sha256:$hash") { throw "Remote digest mismatch: $name" }
            $method = 'GitHub server SHA256 digest'
        } else {
            $downloadHeaders = $headers.Clone()
            $downloadHeaders.Accept = 'application/octet-stream'
            $download = "dist/server-verified-$name"
            Invoke-WebRequest -Uri "$api/releases/assets/$($asset[0].id)" -Headers $downloadHeaders -OutFile $download
            if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw "Downloaded server asset mismatch: $name" }
            $method = 'Downloaded GitHub asset SHA256'
        }
        $verified += [pscustomobject]@{ name = $name; bytes = $local.Length; sha256 = $hash; serverVerified = $true; method = $method }
    }
    $result = [pscustomobject]@{ url = $remote.html_url; releaseId = $remote.id; main = $main.object.sha; tagCommit = $annotated.object.sha; mainFileCompleteness = 'PASS'; assets = $verified }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    $result
} finally {
    $env:GIT_TERMINAL_PROMPT = $previousPrompt
    $credentialLines = $null; $credential = $null; $headers = $null
}
