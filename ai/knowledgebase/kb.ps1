#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$ScriptDir    = $PSScriptRoot
$EnvFile      = Join-Path $ScriptDir '.env'
$NeoDir       = Join-Path $ScriptDir 'neo4j'
$BuilderRoot  = Join-Path $ScriptDir 'graph-builder'
$RepoDir      = Join-Path $BuilderRoot 'llm-graph-builder'
$LogDir       = Join-Path $ScriptDir 'logs'
$RepoUrl      = 'https://github.com/neo4j-labs/llm-graph-builder.git'
$NetworkName  = 'knowledgebase'

# ---------------------------------------------------------------------------
# Output helpers (ASCII-only to avoid Windows-1252 mis-parse of UTF-8)
# ---------------------------------------------------------------------------
function Write-Step    { param([string]$Msg) Write-Host "[*] $Msg" -ForegroundColor Cyan }
function Write-Done    { param([string]$Msg) Write-Host "[+] $Msg" -ForegroundColor Green }
function Write-Caution { param([string]$Msg) Write-Host "[!] $Msg" -ForegroundColor Yellow }
function Write-Fail    { param([string]$Msg) Write-Host "[X] $Msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# .env loader
# ---------------------------------------------------------------------------
function Invoke-LoadEnv {
    if (-not (Test-Path $EnvFile)) {
        Write-Caution ".env not found at $EnvFile -- continuing without it"
        return
    }
    foreach ($line in (Get-Content $EnvFile)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim().Trim('"').Trim("'")
            [System.Environment]::SetEnvironmentVariable($key, $val, 'Process')
        }
    }
}

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------
function Assert-Dependencies {
    foreach ($cmd in @('docker', 'git', 'python')) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            Write-Fail "Required command not found: $cmd"
            exit 1
        }
    }
    Write-Done 'Dependencies OK (docker, git, python)'
}

# ---------------------------------------------------------------------------
# Docker network
# ---------------------------------------------------------------------------
function Ensure-Network {
    $networkNames = docker network ls --format '{{.Name}}' 2>$null
    if ($networkNames -notcontains $NetworkName) {
        Write-Step "Creating Docker network: $NetworkName"
        docker network create $NetworkName | Out-Null
        Write-Done "Network $NetworkName created"
    } else {
        Write-Done "Network $NetworkName already exists"
    }
}

# ---------------------------------------------------------------------------
# Git clone (idempotent)
# ---------------------------------------------------------------------------
function Ensure-Repo {
    if (-not (Test-Path (Join-Path $RepoDir '.git'))) {
        Write-Step "Cloning $RepoUrl"
        if (-not (Test-Path $BuilderRoot)) { New-Item -ItemType Directory -Path $BuilderRoot | Out-Null }
        git clone $RepoUrl $RepoDir
        Write-Done 'Repository cloned'
    } else {
        Write-Done 'Repository already present'
    }
}

# ---------------------------------------------------------------------------
# Generic patch runner
#   $Script   - Python source (as string) that takes one arg: path to file
#   $Label    - Human-readable name for logging
#   $Target   - Absolute path to the file being patched
# ---------------------------------------------------------------------------
function Invoke-RunPatch {
    param(
        [string]$Script,
        [string]$Label,
        [string]$Target
    )
    if (-not (Test-Path $Target)) {
        Write-Fail "$Label : target file not found: $Target"
        exit 1
    }
    $tmp = Join-Path $LogDir '_patch_tmp.py'
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
    try {
        [System.IO.File]::WriteAllText($tmp, $Script, [System.Text.Encoding]::UTF8)
        $out = & python $tmp $Target 2>&1
        $ec  = $LASTEXITCODE
        if ($ec -eq 0) {
            Write-Done "$Label : $out"
        } else {
            Write-Fail "$Label failed (exit $ec): $out"
            exit 1
        }
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force }
    }
}

# ---------------------------------------------------------------------------
# Patch B -- score.py : insert NEO4J_BROWSER_URI into /connect response
# ---------------------------------------------------------------------------
$PatchBScript = @'
import sys

file = sys.argv[1]
with open(file, 'r', encoding='utf-8', newline='') as f:
    c = f.read()

if 'NEO4J_BROWSER_URI' in c:
    print('already patched')
    sys.exit(0)

import os
eol = '\r\n' if '\r\n' in c else '\n'

old = (
    "        result['gcs_file_cache'] = gcs_cache"
    + eol
    + "        return create_api_response('Success',data=result)"
)
new = (
    "        result['gcs_file_cache'] = gcs_cache"
    + eol
    + "        result['uri'] = os.environ.get('NEO4J_BROWSER_URI', credentials.uri)"
    + eol
    + "        return create_api_response('Success',data=result)"
)

if old not in c:
    print('ERROR: patch target not found in score.py', file=sys.stderr)
    sys.exit(2)

c = c.replace(old, new, 1)
with open(file, 'w', encoding='utf-8', newline='') as f:
    f.write(c)

print('patched')
'@

# ---------------------------------------------------------------------------
# Patch C -- user_credential.py : env-var fallback for VITE_SKIP_AUTH=true
#   When the frontend sends no form credentials, fall back to env vars so
#   every API call still reaches Neo4j.
# ---------------------------------------------------------------------------
$PatchCScript = @'
import sys

file = sys.argv[1]
with open(file, 'r', encoding='utf-8', newline='') as f:
    c = f.read()

if 'already patched' in c or 'NEO4J_URI' in c:
    print('already patched')
    sys.exit(0)

eol = '\r\n' if '\r\n' in c else '\n'

# 1. Add "import os" after the last existing import line
old_imports = 'from fastapi import Form, HTTPException'
new_imports  = 'import os' + eol + 'from fastapi import Form, HTTPException'
if old_imports not in c:
    print('ERROR: import line not found in user_credential.py', file=sys.stderr)
    sys.exit(2)
c = c.replace(old_imports, new_imports, 1)

# 2. Replace the return statement with env-var fallbacks
old_return = (
    "    return Neo4jCredentials(" + eol
    + "        uri=uri," + eol
    + "        userName=userName," + eol
    + "        password=password," + eol
    + "        database=database," + eol
    + "        email=email" + eol
    + "    )"
)
new_return = (
    "    return Neo4jCredentials(" + eol
    + "        uri=uri or os.environ.get('NEO4J_URI')," + eol
    + "        userName=userName or os.environ.get('NEO4J_USERNAME')," + eol
    + "        password=password or os.environ.get('NEO4J_PASSWORD')," + eol
    + "        database=database or os.environ.get('NEO4J_DATABASE', 'neo4j')," + eol
    + "        email=email," + eol
    + "    )"
)
if old_return not in c:
    print('ERROR: return statement not found in user_credential.py', file=sys.stderr)
    sys.exit(2)
c = c.replace(old_return, new_return, 1)

with open(file, 'w', encoding='utf-8', newline='') as f:
    f.write(c)

print('patched')
'@

# ---------------------------------------------------------------------------
# Ensure embedding model is cached locally (downloads once, then offline forever)
# ---------------------------------------------------------------------------
function Ensure-EmbeddingModel {
    $localModelDir = Join-Path $RepoDir 'backend' 'local_model'
    # Check for a key file that indicates the model is fully downloaded
    if (Test-Path (Join-Path $localModelDir 'tokenizer_config.json')) {
        Write-Done 'Embedding model already cached'
        return
    }
    Write-Step 'Downloading all-MiniLM-L6-v2 embedding model (first-run, requires internet)...'
    New-Item -ItemType Directory -Force -Path $localModelDir | Out-Null
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

    # Write the download script to a temp file so we avoid shell quoting hell
    $pyScript = Join-Path $LogDir '_download_model.py'
    [System.IO.File]::WriteAllText($pyScript, @'
from sentence_transformers import SentenceTransformer
import sys
try:
    model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
    model.save('/local_model')
    print('Model saved to /local_model')
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
'@, [System.Text.Encoding]::UTF8)

    docker run --rm `
        -v "${localModelDir}:/local_model" `
        -v "${LogDir}:/scripts" `
        python:3.11-slim `
        sh -c 'pip install -q sentence-transformers && python /scripts/_download_model.py'

    $ec = $LASTEXITCODE
    Remove-Item $pyScript -Force -ErrorAction SilentlyContinue
    if ($ec -ne 0) {
        Write-Fail 'Embedding model download failed. Ensure internet access on first run.'
        exit 1
    }
    Write-Done 'Embedding model downloaded and cached at local_model/'
}

# ---------------------------------------------------------------------------
# Apply both patches
# ---------------------------------------------------------------------------
function Invoke-ApplyPatches {
    Write-Step 'Applying patch B (score.py: NEO4J_BROWSER_URI in /connect)'
    $scoreFile = Join-Path $RepoDir 'backend' 'score.py'
    Invoke-RunPatch -Script $PatchBScript -Label 'Patch B' -Target $scoreFile

    Write-Step 'Applying patch C (user_credential.py: normalize localhost -> neo4j)'
    $credFile = Join-Path $RepoDir 'backend' 'src' 'entities' 'user_credential.py'
    Invoke-RunPatch -Script $PatchCScript -Label 'Patch C' -Target $credFile
}

# ---------------------------------------------------------------------------
# Write backend .env
# ---------------------------------------------------------------------------
function Write-BackendEnv {
    $dest = Join-Path $RepoDir 'backend' '.env'
    Write-Step "Writing backend .env -> $dest"

    # Load values from the project .env (already in process env by now)
    $get = { param($k, $d) $v = [System.Environment]::GetEnvironmentVariable($k); if ($v) { $v } else { $d } }

    $content = @"
NEO4J_URI=$( & $get 'NEO4J_URI' 'bolt://neo4j:7687' )
NEO4J_USERNAME=$( & $get 'NEO4J_USERNAME' 'neo4j' )
NEO4J_PASSWORD=$( & $get 'NEO4J_PASSWORD' 'password' )
NEO4J_DATABASE=$( & $get 'NEO4J_DATABASE' 'neo4j' )
NEO4J_BROWSER_URI=$( & $get 'NEO4J_BROWSER_URI' 'bolt://localhost:7687' )
OPENAI_API_KEY=$( & $get 'OPENAI_API_KEY' 'lm-studio' )
LLM_MODEL_CONFIG_lmstudio_gemma4=google/gemma-4-e2b,http://host.docker.internal:1234/v1,lm-studio
EMBEDDING_MODEL=$( & $get 'EMBEDDING_MODEL' 'all-MiniLM-L6-v2' )
EMBEDDING_PROVIDER=$( & $get 'EMBEDDING_PROVIDER' 'sentence-transformer' )
IS_EMBEDDING=$( & $get 'IS_EMBEDDING' 'false' )
GCS_FILE_CACHE=$( & $get 'GCS_FILE_CACHE' 'False' )
MAX_TOKEN_CHUNK_SIZE=$( & $get 'MAX_TOKEN_CHUNK_SIZE' '5000' )
UPDATE_GRAPH_CHUNKS_PROCESSED=$( & $get 'UPDATE_GRAPH_CHUNKS_PROCESSED' '20' )
ALLOWED_NODES=
ALLOWED_RELATIONSHIPS=
"@
    [System.IO.File]::WriteAllText($dest, $content, [System.Text.Encoding]::UTF8)
    Write-Done 'Backend .env written'
}

# ---------------------------------------------------------------------------
# --start
# ---------------------------------------------------------------------------
function Invoke-Start {
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
    $logFile = Join-Path $LogDir "start-$stamp.log"

    Write-Step "=== Start (log: $logFile) ==="

    Invoke-LoadEnv
    Assert-Dependencies
    Ensure-Network
    Ensure-Repo
    Ensure-EmbeddingModel
    Invoke-ApplyPatches
    Write-BackendEnv

    # Neo4j stack (always-on)
    Write-Step 'Starting Neo4j stack'
    Push-Location $NeoDir
    try {
        docker compose up -d 2>&1 | Tee-Object -FilePath $logFile -Append
    } finally { Pop-Location }

    # Graph-builder stack (on-demand)
    Write-Step 'Starting graph-builder stack'
    Push-Location $BuilderRoot
    try {
        docker compose up -d --build 2>&1 | Tee-Object -FilePath $logFile -Append
    } finally { Pop-Location }

    Write-Done '=== All services started ==='
}

# ---------------------------------------------------------------------------
# --stop
# ---------------------------------------------------------------------------
function Invoke-Stop {
    param([switch]$All)
    Invoke-LoadEnv

    Write-Step 'Stopping graph-builder stack'
    Push-Location $BuilderRoot
    try { docker compose down 2>&1 } finally { Pop-Location }

    if ($All) {
        Write-Step 'Stopping Neo4j stack'
        Push-Location $NeoDir
        try { docker compose down 2>&1 } finally { Pop-Location }
        Write-Done 'All stacks stopped'
    } else {
        Write-Done 'Graph-builder stopped (Neo4j still running; use --stop --all to stop everything)'
    }
}

# ---------------------------------------------------------------------------
# --reset-db
# ---------------------------------------------------------------------------
function Invoke-ResetDb {
    Write-Caution 'This will DESTROY all Neo4j data and logs volumes.'
    $answer = Read-Host 'Type YES to confirm'
    if ($answer -ne 'YES') {
        Write-Caution 'Aborted.'
        return
    }

    Invoke-LoadEnv
    Write-Step 'Stopping Neo4j stack'
    Push-Location $NeoDir
    try { docker compose down 2>&1 } finally { Pop-Location }

    foreach ($vol in @('neo4j_neo4j_data', 'neo4j_neo4j_logs')) {
        $exists = docker volume ls --format '{{.Name}}' | Where-Object { $_ -eq $vol }
        if ($exists) {
            Write-Step "Removing volume $vol"
            docker volume rm $vol | Out-Null
            Write-Done "Volume $vol removed"
        } else {
            Write-Caution "Volume $vol not found -- skipping"
        }
    }
    Write-Done 'Database reset complete. Run --start to reinitialise.'
}

# ---------------------------------------------------------------------------
# --update
# ---------------------------------------------------------------------------
function Invoke-Update {
    Invoke-LoadEnv
    Write-Step 'Pulling latest upstream changes'
    Push-Location $RepoDir
    try { git pull --ff-only 2>&1 } finally { Pop-Location }

    Invoke-ApplyPatches
    Write-BackendEnv

    Write-Step 'Rebuilding graph-builder stack'
    Push-Location $BuilderRoot
    try { docker compose build 2>&1 } finally { Pop-Location }

    Write-Done 'Update complete. Run --start to (re)start services.'
}

# ---------------------------------------------------------------------------
# --help
# ---------------------------------------------------------------------------
function Show-Help {
    Write-Host @"

  run.ps1 -- local Neo4j AI knowledgebase manager

  USAGE
    .\run.ps1 --start          Clone repo, apply patches, start both stacks
    .\run.ps1 --stop           Stop graph-builder stack (keep Neo4j running)
    .\run.ps1 --stop --all     Stop ALL stacks including Neo4j
    .\run.ps1 --reset-db       Wipe Neo4j data volumes (prompts for confirmation)
    .\run.ps1 --update         git pull, re-patch, rebuild graph-builder
    .\run.ps1 --help           Show this message

  DIRECTORY LAYOUT
    knowledgebase\
      run.ps1                  <- this script
      .env                     <- project secrets (OPENAI_API_KEY, NEO4J_PASSWORD, ...)
      neo4j\
        compose.yml            <- always-on Neo4j service
      graph-builder\
        llm-graph-builder\     <- cloned from GitHub (managed by this script)
      logs\                    <- start logs + temporary patch files

  PATCHES APPLIED
    Patch B  score.py          /connect endpoint returns NEO4J_BROWSER_URI to frontend
    Patch C  user_credential.py  normalize localhost -> neo4j before bolt:// connection

  ENVIRONMENT (.env keys used)
    NEO4J_URI                  bolt://neo4j:7687  (internal Docker name)
    NEO4J_BROWSER_URI          bolt://localhost:7687  (returned to browser)
    NEO4J_USERNAME / NEO4J_PASSWORD
    OPENAI_API_KEY
    EMBEDDING_MODEL            default: openai

"@
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
$cmd     = if ($args.Count -gt 0) { $args[0] } else { '--help' }
$allFlag = $args -contains '--all'

switch ($cmd) {
    '--start'    { Invoke-Start }
    '--stop'     { Invoke-Stop -All:$allFlag }
    '--reset-db' { Invoke-ResetDb }
    '--update'   { Invoke-Update }
    '--help'     { Show-Help }
    default      { Write-Fail "Unknown command: $cmd"; Show-Help; exit 1 }
}
