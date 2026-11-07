$ErrorActionPreference = 'Stop'
$manifestPath = 'docs/feishu-r11-publication.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
function Invoke-Lark([string[]]$Arguments) {
    $raw = & 'D:/Program Files/nodejs/npx.cmd' --yes '@larksuite/cli@1.0.96' @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'lark-cli failed' }
    $result = ($raw -join "`n") | ConvertFrom-Json
    if ($result.ok -eq $false) { throw ($raw -join "`n") }
    return $result
}
function Save-Manifest { $manifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $manifestPath -Encoding UTF8 }
function Normalize-Content([string]$content) { return (($content -replace '<title>.*?</title>', '') -replace '[\p{P}\p{Z}\s]', '') }
function Publication-Content([string]$file) { return (Get-Content -Raw -LiteralPath $file).Replace('](round-02-report.md)', '](https://dcncd5jl63xs.feishu.cn/wiki/I73vwc6Y4iluPjkW8NMc7yxMnCg)') }
function Verify-Page($page, $read) {
    $remote = $read.data.document.content
    $page.verified = (Normalize-Content (Publication-Content $page.file)) -ceq (Normalize-Content $remote)
    $page | Add-Member -Force NoteProperty revision_id $read.data.document.revision_id
    $page | Add-Member -Force NoteProperty remote_characters $remote.Length
    $page | Add-Member -Force NoteProperty source_sha256 (Get-FileHash -LiteralPath $page.file -Algorithm SHA256).Hash
    $page | Add-Member -Force NoteProperty verification_method 'Full ordered content equality after removal of document title, whitespace and Markdown punctuation; source hash recorded.'
    $read | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $page.readback_file -Encoding UTF8
    Save-Manifest
    if (-not $page.verified) { throw ('Readback differs: '+$page.file) }
    Write-Output ('VERIFIED '+$page.title)
}
foreach ($index in @(1,2,6)) {
    $page = $manifest.pages[$index]
    $before = Invoke-Lark @('docs','+fetch','--doc',$page.document_id,'--doc-format','markdown')
    if (Test-Path -LiteralPath $page.readback_file) {
        $saved = Get-Content -Raw -LiteralPath $page.readback_file | ConvertFrom-Json
        if ($before.data.document.content -cne $saved.data.document.content) { throw 'Remote changed since readback; preserve and inspect instead of overwrite.' }
    } elseif ($index -ne 6) { throw 'Missing existing-page snapshot' }
    Publication-Content $page.file | Set-Content -LiteralPath 'tools/r11-sync-content.tmp' -Encoding UTF8
    $updated = Invoke-Lark @('docs','+update','--doc',$page.document_id,'--revision-id',([string]$before.data.document.revision_id),'--command','overwrite','--doc-format','markdown','--content','@tools/r11-sync-content.tmp')
    $page.update_result = $updated
    $read = Invoke-Lark @('docs','+fetch','--doc',$page.document_id,'--doc-format','markdown')
    Verify-Page $page $read
}
$page = $manifest.pages | Where-Object { $_.file -eq 'docs/round-02-report.md' } | Select-Object -First 1
if ($null -eq $page) {
    $created = Invoke-Lark @('wiki','+node-create','--space-id','7475393357754155027','--parent-node-token',$manifest.parent_node,'--title','07 · 第二轮实现与原作差距')
    $page = [PSCustomObject]@{file='docs/round-02-report.md';title='07 · 第二轮实现与原作差距';node_token=$created.data.node_token;document_id=$created.data.obj_token;url=$created.data.url;verified=$false;readback_file='docs/r11-feishu-readback-7.json'}
    $manifest.pages += $page
    Save-Manifest
    $updated = Invoke-Lark @('docs','+update','--doc',$page.document_id,'--command','append','--doc-format','markdown','--content','@docs/round-02-report.md')
    $page | Add-Member NoteProperty update_result $updated
}
$read = Invoke-Lark @('docs','+fetch','--doc',$page.document_id,'--doc-format','markdown')
Verify-Page $page $read
$before = Invoke-Lark @('docs','+fetch','--doc',$manifest.parent_doc,'--doc-format','markdown')
if (-not $before.data.document.content.Contains($page.url)) {
    @('## 第二轮实现结果','','道路与建筑模型已接入，银行及医院/监狱基础流程可玩。完整还原目标尚未完成，实际测试结果与剩余差距见：','',('- ['+$page.title+']('+$page.url+')')) | Set-Content -LiteralPath 'tools/r11-report-nav.tmp' -Encoding UTF8
    $null = Invoke-Lark @('docs','+update','--doc',$manifest.parent_doc,'--command','append','--doc-format','markdown','--content','@tools/r11-report-nav.tmp')
}
$after = Invoke-Lark @('docs','+fetch','--doc',$manifest.parent_doc,'--doc-format','markdown')
if (-not $after.data.document.content.StartsWith($before.data.document.content.TrimEnd()) -or -not $after.data.document.content.Contains($page.url)) { throw 'Navigation verification failed' }
$after | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath 'docs/r11-feishu-readback-index.json' -Encoding UTF8
$manifest.status = 'verified'
$manifest | Add-Member -Force NoteProperty report_updated_at '2026-11-08'
Save-Manifest
Write-Output ('REPORT_VERIFIED '+$page.url)
