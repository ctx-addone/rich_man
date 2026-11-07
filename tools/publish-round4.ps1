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
    @('docs/round-04-report.md','11 · 第四轮股票与攻防验收'),
    @('docs/round-04-stocks.md','12 · 股票模型与边界'),
    @('docs/round-04-combat.md','13 · 攻击与防御模型'),
    @('docs/research/r11-reactions-stocks.md','14 · 股票与反应卡补证')
)
$published = @()
$repairPage = $manifest.pages | Where-Object { $_.file -eq 'docs/round-04-stocks.md' } | Select-Object -First 1
if ($null -ne $repairPage -and -not $repairPage.verified) {
    if ($repairPage.document_id -ne 'BtgndMh9po7bz3xWnpOcHv1jnFc') { throw 'Unexpected repair document' }
    $priorRead = Get-Content -Raw -LiteralPath $repairPage.readback_file | ConvertFrom-Json
    $repairRead = Invoke-Lark @('docs','+fetch','--doc',$repairPage.document_id,'--doc-format','markdown')
    if ($repairRead.data.document.revision_id -ne 2 -or $repairRead.data.document.content -cne $priorRead.data.document.content) { throw 'Repair target changed; refusing overwrite' }
    $null = Invoke-Lark @('docs','+update','--doc',$repairPage.document_id,'--command','overwrite','--revision-id','2','--doc-format','markdown','--content',('@'+$repairPage.file))
}
foreach ($item in $items) {
    $page = $manifest.pages | Where-Object { $_.file -eq $item[0] } | Select-Object -First 1
    if ($null -eq $page) {
        $created = Invoke-Lark @('wiki','+node-create','--space-id','7475393357754155027','--parent-node-token',$manifest.parent_node,'--title',$item[1])
        $page = [PSCustomObject]@{file=$item[0];title=$item[1];node_token=$created.data.node_token;document_id=$created.data.obj_token;url=$created.data.url;verified=$false;readback_file=('docs/r11-feishu-readback-'+($manifest.pages.Count+1)+'.json')}
        $manifest.pages += $page
        $manifest.status = 'publishing_round4'
        Save-Manifest
        $null = Invoke-Lark @('docs','+update','--doc',$page.document_id,'--command','append','--doc-format','markdown','--content',('@'+$page.file))
    }
    $read = Invoke-Lark @('docs','+fetch','--doc',$page.document_id,'--doc-format','markdown')
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
    $nav = @('## 第四轮股票与攻防','','以下记录股票、攻击与防御反应的实现、验证与规则补证；完整还原仍未完成。','')
    foreach ($page in $missing) { $nav += '- ['+$page.title+']('+$page.url+')' }
    $navPath = Join-Path $env:TEMP 'r11-round4-nav.tmp'
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
$manifest | Add-Member -Force NoteProperty round4_updated_at '2026-11-08'
Save-Manifest
Write-Output 'ROUND4_PUBLICATION_VERIFIED'
