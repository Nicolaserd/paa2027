<#
  Hook PreToolUse (Bash, PowerShell y herramientas MCP de Power BI / Fabric).
  Si la llamada se conecta a la nube (Power BI Service, Fabric, Entra ID, MCP hospedado)
  y no existe una aprobacion vigente creada con pbi-nube.ps1, obliga a pedir
  confirmacion al usuario (permissionDecision = ask) explicando el motivo.
  Los patrones viven en .claude/pbi/herramientas.json (politica.patronesNube*).
#>
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$raw = ''
try { $raw = [Console]::In.ReadToEnd() } catch { }

function Write-Ask {
    param([string]$Motivo)
    @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'ask'
            permissionDecisionReason = "POLITICA POWER BI - NUBE: $Motivo. Este proyecto trabaja en LOCAL por defecto. Claude debe haber preguntado antes con el skill /pbi-nube (hacerlo Claude / dar los pasos al usuario / seguir en local). Aprueba solo si ya lo acordaste."
        }
    } | ConvertTo-Json -Depth 5 -Compress
}

try {
    $in = $raw | ConvertFrom-Json
    $tool = [string]$in.tool_name
    $proj = $env:CLAUDE_PROJECT_DIR
    if (-not $proj) { $proj = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $pol = (Get-Content -Raw -Encoding UTF8 (Join-Path $proj '.claude\pbi\herramientas.json') | ConvertFrom-Json).politica

    $motivo = $null
    if ($tool -like 'mcp__*') {
        $entrada = $in.tool_input | ConvertTo-Json -Compress -Depth 20
        if ($tool -match $pol.patronesNubeServidorMcp) { $motivo = "servidor MCP en la nube ($tool)" }
        elseif ($entrada -match $pol.patronesNubeEntradaMcp) { $motivo = "el MCP recibe una conexion u operacion de nube ($($tool), '$($Matches[0])')" }
    }
    else {
        $cmd = [string]$in.tool_input.command
        foreach ($p in @($pol.patronesNube)) {
            if ($cmd -match $p) { $motivo = "comando de nube detectado ('$($Matches[0].Trim())')"; break }
        }
    }
    if (-not $motivo) { exit 0 }

    $marca = Join-Path $proj '.claude\pbi\estado\nube-aprobada.json'
    if (Test-Path $marca) {
        $m = Get-Content -Raw -Encoding UTF8 $marca | ConvertFrom-Json
        if ([datetime]$m.expira -gt (Get-Date)) { exit 0 }
    }
    Write-Ask $motivo
    exit 0
}
catch {
    # Si el hook falla, solo se pide confirmacion ante senales claras de nube.
    if ($raw -match '(?i)api\.powerbi\.com|fabric\.microsoft\.com|powerbi://|\baz\s+(login|rest)|Connect-PowerBIServiceAccount') {
        Write-Ask 'senal de nube detectada (verificacion detallada no disponible)'
    }
    exit 0
}
