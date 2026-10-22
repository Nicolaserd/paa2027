<#
.SYNOPSIS
  Aprobacion temporal de operaciones en la nube para el proyecto Power BI.

.DESCRIPTION
  Solo se usa desde el skill /pbi-nube, DESPUES de que el usuario eligio "hazlo tu".
  "aprobar" esta en permissions.ask de .claude/settings.json: Claude Code siempre pide
  confirmacion al usuario antes de ejecutarlo (incluso en modo bypass).
  Mientras la aprobacion este vigente, el hook guard-nube no vuelve a preguntar.
  Cada nueva sesion (SessionStart) la revoca.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-nube.ps1 -Accion aprobar -Horas 2 -Alcance "Publicar Ventas.Report en workspace Finanzas"
  powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-nube.ps1 -Accion revocar
#>
[CmdletBinding()]
param(
    [ValidateSet('estado', 'aprobar', 'revocar')]
    [string]$Accion = 'estado',
    [double]$Horas,
    [string]$Alcance = ''
)

$ErrorActionPreference = 'Stop'
$proj = $env:CLAUDE_PROJECT_DIR
if (-not $proj) { $proj = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$pol = (Get-Content -Raw -Encoding UTF8 (Join-Path $proj '.claude\pbi\herramientas.json') | ConvertFrom-Json).politica
$estadoDir = Join-Path $proj '.claude\pbi\estado'
$marca = Join-Path $estadoDir 'nube-aprobada.json'

switch ($Accion) {
    'aprobar' {
        if (-not $Alcance) { throw 'Indica -Alcance: que operacion, que workspace o modelo, y para que.' }
        if (-not $Horas) { $Horas = [double]$pol.nubeAprobacionHorasPorDefecto }
        $Horas = [Math]::Min($Horas, [double]$pol.nubeAprobacionHorasMax)
        New-Item -ItemType Directory -Force -Path $estadoDir | Out-Null
        $ahora = Get-Date
        [pscustomobject]@{
            aprobadoEl = $ahora.ToString('s')
            expira     = $ahora.AddHours($Horas).ToString('s')
            alcance    = $Alcance
        } | ConvertTo-Json | Set-Content -Encoding UTF8 -Path $marca
        Write-Output "Nube APROBADA hasta $($ahora.AddHours($Horas).ToString('s')) para: $Alcance"
    }
    'revocar' {
        Remove-Item -Force -ErrorAction SilentlyContinue $marca
        Write-Output 'Aprobacion de nube revocada. El proyecto vuelve a modo solo local.'
    }
    default {
        if (Test-Path $marca) {
            $m = Get-Content -Raw -Encoding UTF8 $marca | ConvertFrom-Json
            if ([datetime]$m.expira -gt (Get-Date)) { Write-Output "Nube aprobada hasta $($m.expira) para: $($m.alcance)"; return }
            Write-Output "Aprobacion vencida el $($m.expira). Modo solo local."
            return
        }
        Write-Output 'Sin aprobacion de nube. Modo solo local.'
    }
}
