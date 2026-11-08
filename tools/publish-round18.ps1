param([switch]$ResumeVerified)
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
    @('docs/round-18-report.md','80 · 逐卡报价九槽库存与v9验收',80),
    @('docs/round-18-shop-rules.md','81 · 普通商店价格库存与兼容策划',81),
    @('docs/round-18-runtime-review.md','82 · 商店界面与真实v8存档验收',82),
    @('docs/research/r18-shop-prices.md','83 · 28种逐卡报价及九槽实机证据',83),
    @('docs/research/r18-shop-modifiers.md','84 · 糖糖物价与能源修正证据',84),
    @('docs/round-18-shop-review.md','85 · 报价与重复库存独立审查',85)
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
        $manifest.status = 'publishing_round18'
        Save-Manifest
    }
    if ($ResumeVerified -and $page.verified -and $page.source_sha256 -eq (Get-FileHash -LiteralPath $page.file -Algorithm SHA256).Hash -and (Test-Path -LiteralPath $page.readback_file)) {
        $priorRead = Get-Content -Raw -LiteralPath $page.readback_file | ConvertFrom-Json
        if ((Normalize-Content $priorRead.data.document.content) -ceq (Normalize-Content (Get-Content -Raw -LiteralPath $page.file))) {
            $published += $page
            Write-Output ('REUSED_VERIFIED '+$page.title)
            continue
        }
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
    $nav = @('## 第十八轮普通商店报价与库存','','以下为逐卡报价、糖糖例外样本、九槽重复商品、v9兼容与独立验收。未知规则仍明确列出。','')
    foreach ($page in $missing) { $nav += '- ['+$page.title+']('+$page.url+')' }
    $navPath = Join-Path $env:TEMP 'r11-round18-nav.tmp'
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
$manifest | Add-Member -Force NoteProperty round18_updated_at '2026-11-08'
Save-Manifest
Write-Output 'ROUND18_PUBLICATION_VERIFIED'
