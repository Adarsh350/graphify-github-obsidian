# update-graphify-obsidian.ps1
# Fetches latest graphify GRAPH_REPORT.md from all repos and updates Obsidian vault.
# Runs daily via Windows Task Scheduler.

$VAULT = "C:\Users\JobSearch\Documents\Obsidian Vault\Graphify"
$LOG   = "C:\Users\JobSearch\.claude\scripts\graphify-obsidian.log"

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$ts  $msg"
    Write-Host $line
    Add-Content -Path $LOG -Value $line
}

function WikiLink($label) { return "[[" + $label + "]]" }

Log "=== Graphify Obsidian sync started ==="
New-Item -ItemType Directory -Force -Path $VAULT | Out-Null

# Format: "org/repo|branch|display_name"
$REPOS = @(
    "Adarsh350/Jobfill-Extension|main|Jobfill-Extension",
    "Adarsh350/mailchimp-reports-worker|main|mailchimp-reports-worker",
    "Adarsh350/mailchimp-bounce-monitor-worker|main|mailchimp-bounce-monitor-worker",
    "Adarsh350/chess-app|main|chess-app",
    "Adarsh350/trussme-email-dashboard|master|trussme-email-dashboard",
    "Adarsh350/live-email-dashboard|master|live-email-dashboard",
    "Adarsh350/iyara-labs-dashboard|master|iyara-labs-dashboard",
    "Adarsh350/iyaralabs-website-v3|main|iyaralabs-website-v3",
    "Adarsh350/claude-config|main|claude-config",
    "Adarsh350/deepgamecoaching-site|main|deepgamecoaching-site",
    "Adarsh350/adarsh-portfolio|main|adarsh-portfolio",
    "iyara-labs/iyaralabs-website-next|main|iyaralabs-website-next",
    "iyara-labs/org-automation|main|org-automation",
    "iyara-labs/iyaralabs-website-v2|main|iyaralabs-website-v2",
    "iyara-labs/portfolio-boilerplate|main|portfolio-boilerplate",
    "iyara-labs/petronet-website|main|petronet-website",
    "iyara-labs/iyaralabs-website-v1|main|iyaralabs-website-v1"
)

$updated       = 0
$skipped       = 0
$failed        = 0
$today         = Get-Date -Format "yyyy-MM-dd"
$personalRows  = [System.Collections.ArrayList]::new()
$iyaraRows     = [System.Collections.ArrayList]::new()
$personalLinks = [System.Collections.ArrayList]::new()
$iyaraLinks    = [System.Collections.ArrayList]::new()
$repoIndex     = 0

foreach ($entry in $REPOS) {
    $parts   = $entry -split "\|"
    $repo    = $parts[0]
    $branch  = $parts[1]
    $name    = $parts[2]
    $ghUrl   = "https://github.com/" + $repo + "/blob/" + $branch + "/graphify-out/GRAPH_REPORT.md"
    $repoUrl = "https://github.com/" + $repo
    $wikiLink = WikiLink($name)
    $backLink = WikiLink("Graphify Index|Back to Index")

    $linkLine = "- [" + $name + " graph](" + $ghUrl + ")"
    if ($repoIndex -lt 11) { [void]$personalLinks.Add($linkLine) } else { [void]$iyaraLinks.Add($linkLine) }

    $reportJson = gh api "repos/$repo/contents/graphify-out/GRAPH_REPORT.md" 2>$null
    if (-not $reportJson) {
        Log "  SKIP  $repo  (no graphify-out yet)"
        $skipped++
        $row = "| " + $wikiLink + " | - | - | - | pending |"
        if ($repoIndex -lt 11) { [void]$personalRows.Add($row) } else { [void]$iyaraRows.Add($row) }
        $repoIndex++
        continue
    }

    try {
        $jsonObj = $reportJson | ConvertFrom-Json
        $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($jsonObj.content))

        # Strip _COMMUNITY_ wikilinks — they create phantom ghost nodes in Obsidian graph view
        $decoded = $decoded -replace '\[\[_COMMUNITY_[^\]]+\]\]', ''
        # Also remove the now-empty "Community Hubs (Navigation)" section entirely
        $decoded = $decoded -replace '(?ms)## Community Hubs \(Navigation\).*?(?=\n## |\Z)', ''

        $nodes = if ($decoded -match '(\d+) nodes')       { $Matches[1] } else { "?" }
        $edges = if ($decoded -match '(\d+) edges')       { $Matches[1] } else { "?" }
        $comms = if ($decoded -match '(\d+) communities') { $Matches[1] } else { "?" }
        $files = if ($decoded -match '(\d+) files')       { $Matches[1] } else { "?" }

        $noteLines = @(
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
            "<- " + $backLink
        )

        $outFile = Join-Path $VAULT ($name + ".md")
        Set-Content -Path $outFile -Value ($noteLines -join "`n") -Encoding UTF8

        Log ("  OK    " + $repo + "  (" + $nodes + " nodes, " + $edges + " edges)")
        $updated++
        $row = "| " + $wikiLink + " | " + $nodes + " | " + $edges + " | " + $comms + " | " + $files + " |"
        if ($repoIndex -lt 11) { [void]$personalRows.Add($row) } else { [void]$iyaraRows.Add($row) }
    } catch {
        Log ("  ERROR " + $repo + "  " + $_)
        $failed++
        $row = "| " + $wikiLink + " | error | - | - | - |"
        if ($repoIndex -lt 11) { [void]$personalRows.Add($row) } else { [void]$iyaraRows.Add($row) }
    }

    $repoIndex++
}

# Rebuild master index
$syncTime = Get-Date -Format "yyyy-MM-dd HH:mm"
$indexLines = @(
    "# Graphify - Knowledge Graph Index",
    "",
    "> Auto-synced from GitHub. Last updated: $syncTime",
    "> New repos detected automatically every 30 min by personal-automation.",
    "",
    "---",
    "",
    "## How It Works",
    "",
    "- Every push to ``main`` / ``master`` triggers the graphify GitHub Action",
    "- Extracts AST knowledge graph from all code files",
    "- Commits ``graphify-out/GRAPH_REPORT.md`` + ``graph.json`` back to repo",
    "- This index auto-updates daily at 8am via Windows Task Scheduler",
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
)

$indexFile = Join-Path $VAULT "Graphify Index.md"
Set-Content -Path $indexFile -Value ($indexLines -join "`n") -Encoding UTF8

Log "Index rebuilt."
Log ("=== Done: " + $updated + " updated, " + $skipped + " skipped, " + $failed + " failed ===")
