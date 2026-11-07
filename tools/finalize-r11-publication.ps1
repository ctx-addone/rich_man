$ErrorActionPreference = 'Stop'
$npxPath = 'D:/Program Files/nodejs/npx.cmd'
$manifestPath = 'docs/feishu-r11-publication.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.status -ne 'pages_verified_navigation_pending') { throw 'Page verification must pass before navigation publish.' }
function Invoke-Lark([string[]]$Arguments) {
    $raw = & $npxPath --yes '@larksuite/cli@1.0.96' @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'lark-cli failed' }
    $result = ($raw -join "`n") | ConvertFrom-Json
    if ($result.ok -eq $false) { throw ($raw -join "`n") }
    return $result
}
$lines = @('# R11玩法重建 · 分类策划', '', '2026-11-08 研究基线。当前为研究与重建阶段，未完成还原。原v0.1页保留为历史资料；还原目标及范围以本目录为准。以下页面明确区分已有证据、待核验参数和待实现功能。', '')
foreach ($page in $manifest.pages) { $lines += '- [' + $page.title + '](' + $page.url + ')' }
$lines | Set-Content -LiteralPath 'tools/r11-nav.tmp' -Encoding UTF8
$null = Invoke-Lark @('docs','+update','--doc',$manifest.parent_doc,'--command','append','--doc-format','markdown','--content','@tools/r11-nav.tmp')
$parent = Invoke-Lark @('docs','+fetch','--doc',$manifest.parent_doc,'--doc-format','markdown')
foreach ($page in $manifest.pages) { if (-not $parent.data.document.content.Contains($page.url)) { throw 'Parent navigation link missing' } }
$parent | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath 'docs/r11-feishu-readback-index.json' -Encoding UTF8
$oldIndex = Invoke-Lark @('docs','+fetch','--doc','XWrSdTN7YoLHD5x95srcx0DmnJd','--doc-format','markdown')
@('## R11重建目标与第二轮策划（2026-11-08）','','原v0.1页面保留为历史基线，不能作为本轮缩减目标的依据。新一轮的完整还原目标、分类研究和验收差距请见：','',('- [R11玩法重建 · 分类目录]('+$manifest.parent_url+')')) | Set-Content -LiteralPath 'tools/r11-root-nav.tmp' -Encoding UTF8
if (-not $oldIndex.data.document.content.Contains($manifest.parent_url)) {
    $null = Invoke-Lark @('docs','+update','--doc','XWrSdTN7YoLHD5x95srcx0DmnJd','--command','append','--doc-format','markdown','--content','@tools/r11-root-nav.tmp')
}
$newIndex = Invoke-Lark @('docs','+fetch','--doc','XWrSdTN7YoLHD5x95srcx0DmnJd','--doc-format','markdown')
if (-not $newIndex.data.document.content.Contains($manifest.parent_url) -or -not $newIndex.data.document.content.StartsWith($oldIndex.data.document.content.TrimEnd())) { throw 'Existing index not preserved or new link missing' }
$newIndex | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath 'docs/r11-feishu-readback-root.json' -Encoding UTF8
$manifest.status = 'verified'
$manifest | Add-Member -Force NoteProperty navigation_verified $true
$manifest | Add-Member -Force NoteProperty existing_index_preserved $true
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Output ('PUBLICATION_VERIFIED ' + $manifest.parent_url)
