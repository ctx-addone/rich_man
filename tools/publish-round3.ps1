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
$before = Invoke-Lark @('docs','+fetch','--doc',$manifest.parent_doc,'--doc-format','markdown')
$items = @(
    @('docs/round-03-report.md','08 · 第三轮建筑经济与实现'),
    @('docs/round-03-cards.md','09 · 卡牌实现边界'),
    @('docs/research/r11-map-catalog.md','10 · 地图证据盘点')
)
$published = @()
foreach ($item in $items) {
    $page = $manifest.pages | Where-Object { $_.file -eq $item[0] } | Select-Object -First 1
    if ($null -eq $page) {
        $created = Invoke-Lark @('wiki','+node-create','--space-id','7475393357754155027','--parent-node-token',$manifest.parent_node,'--title',$item[1])
        $page = [PSCustomObject]@{file=$item[0];title=$item[1];node_token=$created.data.node_token;document_id=$created.data.obj_token;url=$created.data.url;verified=$false;readback_file=('docs/r11-feishu-readback-'+($manifest.pages.Count+1)+'.json')}
        $manifest.pages += $page
        $manifest.status = 'publishing_round3'
        Save-Manifest
        $null = Invoke-Lark @('docs','+update','--doc',$page.document_id,'--command','append','--doc-format','markdown','--content',('@'+$page.file))
    }
    $read = Invoke-Lark @('docs','+fetch','--doc',$page.document_id,'--doc-format','markdown')
    $remote = $read.data.document.content
    $original = Get-Content -Raw -LiteralPath $page.file
    $page.verified = (Normalize-Content $original) -ceq (Normalize-Content $remote)
    $page | Add-Member -Force NoteProperty revision_id $read.data.document.revision_id
    $page | Add-Member -Force NoteProperty remote_characters $remote.Length
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
    $nav = @('## 第三轮建筑经济与卡牌','','以下记录本轮已实现的机制、临时参数和原作地图证据；完整还原仍未完成。','')
    foreach ($page in $missing) { $nav += '- ['+$page.title+']('+$page.url+')' }
    $nav | Set-Content -LiteralPath 'tools/r11-round3-nav.tmp' -Encoding UTF8
    $null = Invoke-Lark @('docs','+update','--doc',$manifest.parent_doc,'--command','append','--doc-format','markdown','--content','@tools/r11-round3-nav.tmp')
}
$after = Invoke-Lark @('docs','+fetch','--doc',$manifest.parent_doc,'--doc-format','markdown')
if (-not $after.data.document.content.StartsWith($before.data.document.content.TrimEnd())) { throw 'Existing directory content changed' }
foreach ($page in $published) { if (-not $after.data.document.content.Contains($page.url)) { throw 'Missing navigation link' } }
$after | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath 'docs/r11-feishu-readback-index.json' -Encoding UTF8
$manifest.status = 'verified'
$manifest | Add-Member -Force NoteProperty round3_updated_at '2026-11-08'
Save-Manifest
Write-Output 'ROUND3_PUBLICATION_VERIFIED'
