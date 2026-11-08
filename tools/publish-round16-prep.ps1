$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$manifestPath = 'docs/feishu-r11-publication.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
function Invoke-Lark([string[]]$Arguments) {
    $raw = & 'D:/Program Files/nodejs/npx.cmd' --yes '@larksuite/cli@1.0.96' @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'lark-cli failed' }
    $result = ($raw -join "`n") | ConvertFrom-Json
    if ($result.ok -eq $false) { throw 'lark-cli returned an error' }
    return $result
}
function Save-Manifest { $manifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $manifestPath -Encoding UTF8 }
function Normalize-Content([string]$content) { return (($content -replace '<title>.*?</title>', '') -replace '[\p{P}\p{Z}\s]', '') }
if ($manifest.parent_node -ne 'Vx2FwJzWNiBjJuk24Qoc0a2NnEy') { throw 'Unexpected parent node' }
$items = @(
    @('docs/second-design-pass.md','64 · 第二轮游戏设计与优化讨论基线',64),
    @('docs/research/r16-calendar-economy.md','65 · 日历物价与自由比赛设置研究',65),
    @('docs/research/r16-price-scope.md','66 · 物价影响的收支分类证据',66),
    @('docs/round-16-runtime-review.md','67 · 经济改动前旧存档与兼容审查',67)
)
# Fail before creating pages if a relative link would be silently dropped by import.
foreach ($item in $items) {
    $source = Get-Content -Raw -LiteralPath $item[0]
    foreach ($link in [regex]::Matches($source, '\]\(([^)]+)\)')) {
        if ($link.Groups[1].Value -notmatch '^https?://') { throw ('Resolve relative Markdown link before publication: '+$item[0]) }
    }
}
$published = @()
foreach ($item in $items) {
    $matches = @($manifest.pages | Where-Object { $_.file -eq $item[0] })
    if ($matches.Count -gt 1) { throw ('Duplicate manifest source: '+$item[0]) }
    $page = $matches | Select-Object -First 1
    if ($null -eq $page) {
        $created = Invoke-Lark @('wiki','+node-create','--space-id','7475393357754155027','--parent-node-token',$manifest.parent_node,'--title',$item[1])
        if (-not $created.data.obj_token -or -not $created.data.node_token -or -not $created.data.url) { throw 'Create response missing document identity' }
        $page = [PSCustomObject]@{file=$item[0];title=$item[1];node_token=$created.data.node_token;document_id=$created.data.obj_token;url=$created.data.url;verified=$false;readback_file=('docs/r11-feishu-readback-'+$item[2]+'.json')}
        $manifest.pages += $page
        $manifest.status = 'publishing_round16-prep'
        Save-Manifest
    }
    $read = Invoke-Lark @('docs','+fetch','--doc',$page.document_id,'--doc-format','markdown')
    # Resume a created but not yet populated page without creating duplicates.
    $isTitlePlaceholder = $read.data.document.revision_id -eq 1 -and $read.data.document.content.Trim() -ceq ('# '+$page.title)
    if ((Normalize-Content $read.data.document.content).Length -eq 0 -or $isTitlePlaceholder) {
        $null = Invoke-Lark @('docs','+update','--doc',$page.document_id,'--command','append','--doc-format','markdown','--content',('@'+$page.file))
        $read = Invoke-Lark @('docs','+fetch','--doc',$page.document_id,'--doc-format','markdown')
    }
    $remote = $read.data.document.content
    $original = Get-Content -Raw -LiteralPath $page.file
    $page.verified = (Normalize-Content $original) -ceq (Normalize-Content $remote)
    $page | Add-Member -Force NoteProperty revision_id $read.data.document.revision_id
    $page | Add-Member -Force NoteProperty remote_characters $remote.Length
    $normalizedBytes = [Text.Encoding]::UTF8.GetBytes((Normalize-Content $remote))
    $normalizedHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($normalizedBytes))
    $page | Add-Member -Force NoteProperty normalized_sha256 $normalizedHash
    $page | Add-Member -Force NoteProperty source_sha256 (Get-FileHash -LiteralPath $page.file -Algorithm SHA256).Hash
    $page | Add-Member -Force NoteProperty verification_method 'Full ordered content equality after removal of document title, whitespace and Markdown punctuation; source hash recorded.'
    $read | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $page.readback_file -Encoding UTF8
    Save-Manifest
    if (-not $page.verified) { throw ('Readback differs: '+$page.file) }
    $published += $page
    Write-Output ('VERIFIED '+$page.title+' '+$page.url)
}
$before = Invoke-Lark @('docs','+fetch','--doc',$manifest.parent_doc,'--doc-format','markdown')
$missing = @($published | Where-Object { -not $before.data.document.content.Contains($_.url) })
if ($missing.Count -gt 0) {
    $nav = @('## 第二轮设计与经济研究准备','','以下为下一阶段设计讨论、日历及物价研究、真实v6存档基线。尚未实施经济系统改动，不代表还原验收完成。','')
    foreach ($page in $missing) { $nav += '- ['+$page.title+']('+$page.url+')' }
    $navPath = Join-Path $env:TEMP 'r11-round16-prep-nav.tmp'
    $nav | Set-Content -LiteralPath $navPath -Encoding UTF8
    $null = Invoke-Lark @('docs','+update','--doc',$manifest.parent_doc,'--command','append','--doc-format','markdown','--content',('@'+$navPath))
}
$after = Invoke-Lark @('docs','+fetch','--doc',$manifest.parent_doc,'--doc-format','markdown')
if (-not $after.data.document.content.StartsWith($before.data.document.content.TrimEnd())) { throw 'Existing directory content changed' }
foreach ($page in $published) { if (-not $after.data.document.content.Contains($page.url)) { throw 'Missing navigation link' } }
$after | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath 'docs/r11-feishu-readback-index.json' -Encoding UTF8
$manifest.status = 'verified'
$manifest.navigation_verified = $true
$manifest.existing_index_preserved = $true
$manifest | Add-Member -Force NoteProperty round16-prep_updated_at '2026-11-08'
Save-Manifest
Write-Output 'ROUND16_PREP_PUBLICATION_VERIFIED'
