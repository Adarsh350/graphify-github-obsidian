# update-graphify-obsidian.ps1
# Fetches latest graphify GRAPH_REPORT.md from all repos and updates Obsidian vault.
# Runs daily via Windows Task Scheduler.
# Repos are discovered dynamically - no hardcoded list needed.

$VAULT      = "C:\Users\JobSearch\Documents\Obsidian Vault\Graphify"
$LOG        = "C:\Users\JobSearch\.claude\scripts\graphify-obsidian.log"
$SKIP_REPOS = @("graphify-github-obsidian", "personal-automation")

function Log($msg) {
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$ts  $msg"
    Write-Host $line
    Add-Content -Path $LOG -Value $line
}

function WikiLink($label) { return "[[" + $label + "]]" }

Log "=== Graphify Obsidian sync started ==="
New-Item -ItemType Directory -Force -Path $VAULT | Out-Null

# Discover all repos from both orgs
Log "Discovering repos from Adarsh350 and iyara-labs..."
$personalJson = gh repo list Adarsh350  --limit 100 --json name,defaultBranchRef 2>$null | ConvertFrom-Json
$iyaraJson    = gh repo list iyara-labs --limit 100 --json name,defaultBranchRef 2>$null | ConvertFrom-Json

# Build unified list: @{ repo; branch; name; org }
$allRepos = [System.Collections.ArrayList]::new()
foreach ($r in $personalJson) {
    if ($SKIP_REPOS -notcontains $r.name) {
        $branch = if ($r.defaultBranchRef -and $r.defaultBranchRef.name) { $r.defaultBranchRef.name } else { "main" }
        [void]$allRepos.Add([PSCustomObject]@{ repo = "Adarsh350/$($r.name)"; branch = $branch; name = $r.name; org = "personal" })
    }
}
foreach ($r in $iyaraJson) {
    if ($SKIP_REPOS -notcontains $r.name) {
        $branch = if ($r.defaultBranchRef -and $r.defaultBranchRef.name) { $r.defaultBranchRef.name } else { "main" }
        [void]$allRepos.Add([PSCustomObject]@{ repo = "iyara-labs/$($r.name)"; branch = $branch; name = $r.name; org = "iyara" })
    }
}

Log ("Found " + $allRepos.Count + " repos to check (" + $personalJson.Count + " personal, " + $iyaraJson.Count + " iyara-labs)")

$updated       = 0
$skipped       = 0
$failed        = 0
$today         = Get-Date -Format "yyyy-MM-dd"
$personalRows  = [System.Collections.ArrayList]::new()
$iyaraRows     = [System.Collections.ArrayList]::new()
$personalLinks = [System.Collections.ArrayList]::new()
$iyaraLinks    = [System.Collections.ArrayList]::new()
$backLink      = WikiLink("Graphify Index|Back to Index")

foreach ($entry in $allRepos) {
    $repo    = $entry.repo
    $branch  = $entry.branch
    $name    = $entry.name
    $org     = $entry.org
    $ghUrl   = "https://github.com/$repo/blob/$branch/graphify-out/GRAPH_REPORT.md"
    $repoUrl = "https://github.com/$repo"
    $wikiLink = WikiLink($name)
    $linkLine = "- [$name graph]($ghUrl)"

    if ($org -eq "personal") { [void]$personalLinks.Add($linkLine) } else { [void]$iyaraLinks.Add($linkLine) }

    $reportJson = gh api "repos/$repo/contents/graphify-out/GRAPH_REPORT.md" 2>$null
    if (-not $reportJson) {
        Log "  SKIP  $repo  (no graphify-out yet - bootstrap will add it on next cycle)"
        $skipped++
        $row = "| $wikiLink | - | - | - | pending |"
        if ($org -eq "personal") { [void]$personalRows.Add($row) } else { [void]$iyaraRows.Add($row) }
        continue
    }

    try {
        $jsonObj = $reportJson | ConvertFrom-Json
        $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($jsonObj.content))

        # Strip _COMMUNITY_ wikilinks - they create phantom ghost nodes in Obsidian graph view
        $decoded = $decoded -replace '\[\[_COMMUNITY_[^\]]+\]\]', ''
        # Remove now-empty Community Hubs section
        $decoded = $decoded -replace '(?ms)## Community Hubs \(Navigation\).*?(?=\n## |\Z)', ''

        $nodes = if ($decoded -match '(\d+) nodes')       { $Matches[1] } else { "?" }
        $edges = if ($decoded -match '(\d+) edges')       { $Matches[1] } else { "?" }
        $comms = if ($decoded -match '(\d+) communities') { $Matches[1] } else { "?" }
        $files = if ($decoded -match '(\d+) files')       { $Matches[1] } else { "?" }

        $noteContent = @(
            "# $name - Knowledge Graph",
            "",
            "**Repo:** [$repo]($repoUrl)",
            "**Graph:** [GRAPH_REPORT.md]($ghUrl)",
            "**Updated:** $today",
            "**Branch:** $branch",
            "",
            "## Stats",
            "- **$nodes nodes x $edges edges x $comms communities**",
            "- $files files",
            "",
            "## Full Report",
            "",
            $decoded,
            "",
            "<- $backLink"
        ) -join "`n"

        $outFile = Join-Path $VAULT ($name + ".md")
        [System.IO.File]::WriteAllText($outFile, $noteContent, [System.Text.Encoding]::UTF8)

        Log ("  OK    $repo  ($nodes nodes, $edges edges)")
        $updated++
        $row = "| $wikiLink | $nodes | $edges | $comms | $files |"
        if ($org -eq "personal") { [void]$personalRows.Add($row) } else { [void]$iyaraRows.Add($row) }
    } catch {
        Log ("  ERROR $repo  $_")
        $failed++
        $row = "| $wikiLink | error | - | - | - |"
        if ($org -eq "personal") { [void]$personalRows.Add($row) } else { [void]$iyaraRows.Add($row) }
    }
}

# Rebuild master index
$syncTime   = Get-Date -Format "yyyy-MM-dd HH:mm"
$indexContent = @(
    "# Graphify - Knowledge Graph Index",
    "",
    "> Auto-synced from GitHub. Last updated: $syncTime",
    "> Repos are discovered automatically - new repos appear here once graphify bootstrap runs.",
    "",
    "---",
    "",
    "## How It Works",
    "",
    "- bootstrap.yml runs every 30 min and installs the graphify workflow on any new repo",
    "- Every push to ``main`` / ``master`` re-extracts the knowledge graph",
    "- This index auto-updates daily at 8am via Windows Task Scheduler",
    "- **No manual config needed** - new repos appear automatically",
    "",
    "---",
    "",
    "## Adarsh350 - Personal Repos",
    "",
    "| Repo | Nodes | Edges | Communities | Files |",
    "|------|-------|-------|-------------|-------|",
    ($personalRows -join "`n"),
    "",
    "## iyara-labs - Org Repos",
    "",
    "| Repo | Nodes | Edges | Communities | Files |",
    "|------|-------|-------|-------------|-------|",
    ($iyaraRows -join "`n"),
    "",
    "---",
    "",
    "## GitHub Links",
    "",
    "### Adarsh350",
    ($personalLinks -join "`n"),
    "",
    "### iyara-labs",
    ($iyaraLinks -join "`n")
) -join "`n"

$indexFile = Join-Path $VAULT "Graphify Index.md"
[System.IO.File]::WriteAllText($indexFile, $indexContent, [System.Text.Encoding]::UTF8)

Log "Index rebuilt."
Log ("=== Done: $updated updated, $skipped skipped (no graphify yet), $failed failed ===")
