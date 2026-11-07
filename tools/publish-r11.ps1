$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$npxPath = 'D:/Program Files/nodejs/npx.cmd'
$manifestPath = 'docs/feishu-r11-publication.json'
if (Test-Path -LiteralPath $manifestPath) { throw 'Publication manifest exists; inspect recorded node IDs before attempting any further creation.' }
function Invoke-Lark([string[]]$Arguments) {
    $raw = & $npxPath --yes '@larksuite/cli@1.0.96' @Arguments
    if ($LASTEXITCODE -ne 0) { throw "lark-cli failed: $($Arguments[0..1] -join ' ')" }
    $result = ($raw -join "`n") | ConvertFrom-Json
    if ($result.ok -eq $false) { throw ($raw -join "`n") }
    return $result
}
$manifest = [ordered]@{
    published_at = '2026-11-08'
    status = 'publishing'
    parent_node = 'Vx2FwJzWNiBjJuk24Qoc0a2NnEy'
    parent_doc = 'MPxNdiFT1oo9sKxIga7c2tz1nwd'
    parent_url = 'https://dcncd5jl63xs.feishu.cn/wiki/Vx2FwJzWNiBjJuk24Qoc0a2NnEy'
    pages = @()
}
function Save-Manifest { $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding UTF8 }
Save-Manifest
$items = @(
    @('docs/r11-target.md', '01 · 还原目标与完成门槛'),
    @('docs/round-02-plan.md', '02 · 第二轮功能与实施策划'),
    @('docs/research/r11-map-contract.md', '03 · 地图与建筑模型策划'),
    @('docs/research/r11-economy-specials.md', '04 · 建筑经济与特殊设施'),
    @('docs/research/r11-cards-characters.md', '05 · 卡牌角色神仙与状态'),
    @('docs/research/r11-current-gap-audit.md', '06 · 原作对照与验收差距')
)
foreach ($item in $items) {
    $created = Invoke-Lark @('wiki','+node-create','--space-id','7475393357754155027','--parent-node-token',$manifest.parent_node,'--title',$item[1])
    $entry = [ordered]@{ file=$item[0]; title=$item[1]; node_token=$created.data.node_token; document_id=$created.data.obj_token; url=$created.data.url; verified=$false }
    $manifest.pages += $entry
    Save-Manifest
    $updated = Invoke-Lark @('docs','+update','--doc',$entry.document_id,'--command','append','--doc-format','markdown','--content',('@'+$item[0]))
    $entry.update_result = $updated
    Save-Manifest
    $read = Invoke-Lark @('docs','+fetch','--doc',$entry.document_id,'--doc-format','markdown')
    $read | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath ('docs/r11-feishu-readback-'+$manifest.pages.Count+'.json') -Encoding UTF8
    $entry.readback_file = 'docs/r11-feishu-readback-'+$manifest.pages.Count+'.json'
    Save-Manifest
    Write-Output ('Published '+$entry.title+' '+$entry.url)
}
Write-Output 'PAGES_WRITTEN_PENDING_VERIFICATION'
