# graphify-github-obsidian

Auto-generate knowledge graphs from all your GitHub repos and sync them to Obsidian — fully automated. Zero ongoing input required.

## What This Does

Every time you push code to any of your repos, a GitHub Action extracts an AST knowledge graph (nodes = functions/classes/modules, edges = calls/imports/dependencies) and commits `graphify-out/GRAPH_REPORT.md` and `graphify-out/graph.json` back to that repo.

A bootstrap workflow scans for new repos every 30 minutes and installs the graphify action automatically.

A Windows scheduled script syncs all graph reports into your Obsidian vault daily.

```
Push code → graphify Action runs → graph committed to repo
                                          ↓
New repo created → bootstrap detects it → installs Action (within 30 min)
                                          ↓
Daily 8am → PowerShell script → fetches all reports → updates Obsidian vault
```

---

## Repo Structure

```
graphify-github-obsidian/
├── workflows/
│   ├── graphify.yml            # Action for repos on 'main' branch
│   └── graphify_master.yml     # Action for repos on 'master' branch
├── bootstrap/
│   └── bootstrap.yml           # Auto-installs graphify on new repos
└── obsidian-sync/
    ├── update-graphify-obsidian.ps1   # Daily sync script (Windows)
    └── SETUP.md                       # Task Scheduler setup guide
```

---

## Quick Start

### Step 1 — Create a Personal Access Token

Create a PAT at GitHub → Settings → Developer Settings → Personal Access Tokens → Fine-grained tokens.

Required permissions:
- **Contents**: Read and write (for all target repos)
- **Workflows**: Read and write (to install workflow files)
- **Metadata**: Read

Add it as a secret named `GRAPHIFY_PAT` in your `personal-automation` repo.

---

### Step 2 — Install graphify on existing repos

For each repo, copy the appropriate workflow file to `.github/workflows/graphify.yml`:
- `workflows/graphify.yml` → repos on `main` branch
- `workflows/graphify_master.yml` → repos on `master` branch

Or push it in bulk via the GitHub API (see `bootstrap/bootstrap.yml` for the pattern).

**Common failure — `cache: 'pip'` bug:**

If your repos don't have `requirements.txt` or `pyproject.toml`, `actions/setup-python` with `cache: 'pip'` will crash immediately:
```
No file matched to [**/requirements.txt or **/pyproject.toml]
```
The workflow files in this repo already have this removed.

---

### Step 3 — Install the bootstrap in personal-automation

Copy `bootstrap/bootstrap.yml` to `.github/workflows/bootstrap.yml` in your `personal-automation` repo.

Update the two variables in the script:
```bash
YOUR_USERNAME="YourGitHubUsername"
YOUR_ORG="your-org-name"
```

The bootstrap runs every 30 minutes. Any new repo gets graphify installed within 30 minutes of creation.

---

### Step 4 — Set up Obsidian sync (Windows)

See `obsidian-sync/SETUP.md` for the full guide. Short version:

1. Copy `update-graphify-obsidian.ps1` to your machine
2. Edit `$VAULT`, `$LOG`, and `$REPOS` at the top of the script
3. Register as a Windows Scheduled Task (runs daily at 8am)

---

### Step 5 — Test

```powershell
powershell.exe -ExecutionPolicy Bypass -File "path\to\update-graphify-obsidian.ps1"
```

Expected output:
```
2026-04-16 08:00:01  === Graphify Obsidian sync started ===
2026-04-16 08:00:02    OK    yourname/repo-name  (242 nodes, 412 edges)
...
2026-04-16 08:00:20  === Done: 16 updated, 0 skipped, 0 failed ===
```

Open Obsidian → `Graphify/Graphify Index` to see the full graph index.

---

## Obsidian Notes Structure

```
Graphify/
├── Graphify Index.md      ← master table: all repos, node/edge counts, GitHub links
├── repo-name.md           ← one note per repo with stats + full report
└── ...
```

**Phantom node fix:** Graphify reports contain `[[_COMMUNITY_Community X]]` wikilinks for internal navigation. Embedded raw in Obsidian, these create hundreds of ghost nodes that congest the graph view. The sync script strips them automatically:

```powershell
$decoded = $decoded -replace '\[\[_COMMUNITY_[^\]]+\]\]', ''
$decoded = $decoded -replace '(?ms)## Community Hubs \(Navigation\).*?(?=\n## |\Z)', ''
```

---

## What the Graph Tells You

- **God nodes** — highest-degree functions. Everything depends on these. Highest risk to touch.
- **Surprising connections** — cross-file relationships not obvious from reading code linearly.
- **Communities** — clusters of tightly related code. Changes in one community rarely ripple to others.

The GitHub Action runs AST-only extraction (free, no LLM tokens). For deeper semantic extraction, run graphify locally with `--mode deep`.

---

## Credits

Knowledge graph extraction powered by [graphify](https://github.com/safishamsi/graphify) — `pip install graphifyy`.
