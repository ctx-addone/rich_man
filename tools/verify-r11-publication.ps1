$ErrorActionPreference = 'Stop'
$manifestPath = 'docs/feishu-r11-publication.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
function Normalize-Content([string]$content) {
    $content = $content -replace '<title>.*?</title>', ''
    return $content -replace '[\p{P}\p{Z}\s]', ''
}
foreach ($page in $manifest.pages) {
    $original = (Get-Content -Raw -LiteralPath $page.file).Replace('](round-02-report.md)', '](https://dcncd5jl63xs.feishu.cn/wiki/I73vwc6Y4iluPjkW8NMc7yxMnCg)')
    $readback = Get-Content -Raw -LiteralPath $page.readback_file | ConvertFrom-Json
    $remote = $readback.data.document.content
    $equal = (Normalize-Content $original) -ceq (Normalize-Content $remote)
    $page.verified = $equal
    $page | Add-Member -Force NoteProperty revision_id $readback.data.document.revision_id
    $page | Add-Member -Force NoteProperty remote_characters $remote.Length
    $page | Add-Member -Force NoteProperty source_sha256 (Get-FileHash -LiteralPath $page.file -Algorithm SHA256).Hash
    $page | Add-Member -Force NoteProperty verification_method 'Full ordered content equality after removal of document title, whitespace and Markdown punctuation; source hash recorded.'
    Write-Output ($page.title + ': ' + $equal + ', remote chars=' + $remote.Length)
}
$manifest.status = if ($manifest.pages.Count -ge 6 -and @($manifest.pages | Where-Object { -not $_.verified }).Count -eq 0) { if ($manifest.navigation_verified) { 'verified' } else { 'pages_verified_navigation_pending' } } else { 'verification_failed' }
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
if ($manifest.status -eq 'verification_failed') { exit 1 }
