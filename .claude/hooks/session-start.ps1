<#
  Hook SessionStart (matcher: startup).
  1. Revoca cualquier aprobacion de nube que haya quedado de una sesion anterior.
  2. Verificacion unica: reutiliza el ultimo preflight si fue OK, es del mismo
     manifiesto y tiene menos de politica.revalidarHoras; si no, lo ejecuta de nuevo.
  3. Muestra el resultado al usuario (systemMessage) y se lo pasa a Claude
     (additionalContext). Nunca instala nada y nunca bloquea el inicio.
#>
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

function Write-HookOutput {
    param([string]$Mensaje, [string]$Contexto)
    @{
        systemMessage      = $Mensaje
        hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $Contexto }
    } | ConvertTo-Json -Depth 5 -Compress
}

try {
    $null = [Console]::In.ReadToEnd()
    $proj = $env:CLAUDE_PROJECT_DIR
    if (-not $proj) { $proj = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $proj = (Get-Item -LiteralPath $proj).FullName.TrimEnd('\')
    $pbiDir    = Join-Path $proj '.claude\pbi'
    $estadoDir = Join-Path $pbiDir 'estado'
    $estadoFile = Join-Path $estadoDir 'preflight.json'
    $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $pbiDir 'herramientas.json') | ConvertFrom-Json

    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $estadoDir 'nube-aprobada.json')

    $estado = $null
    if (Test-Path $estadoFile) { $estado = Get-Content -Raw -Encoding UTF8 $estadoFile | ConvertFrom-Json }
    $vigente = $estado -and $estado.resultado -eq 'OK' -and $estado.versionManifiesto -eq $manifest.version -and
               ([string]$estado.proyecto -eq [string]$proj) -and
               (((Get-Date) - [datetime]$estado.fecha).TotalHours -lt [double]$manifest.politica.revalidarHoras)

    if ($vigente) {
        Write-HookOutput "Preflight Power BI: OK (verificado $($estado.fecha))." "Preflight Power BI: OK (verificado $($estado.fecha); estado en .claude/pbi/estado/preflight.json). Requisitos cumplidos: puedes trabajar en LOCAL siguiendo .claude/rules/pbi-02-matriz-responsabilidades.md. Cualquier operacion en la nube sigue requiriendo /pbi-nube."
        exit 0
    }

    $json = & (Join-Path $proj '.claude\scripts\pbi-preflight.ps1') -ProjectDir $proj -Json -Guardar | Out-String
    $r = $json | ConvertFrom-Json

    $pendientes = @($r.checks | Where-Object { $_.estado -eq 'FALLA' -or $_.estado -eq 'AVISO' } |
        ForEach-Object { "- [$($_.estado)] $($_.nombre) ($($_.prioridad)): $($_.detalle)" + $(if ($_.accion) { " -> $($_.accion)" } else { '' }) })

    if ($r.resultado -eq 'OK') {
        Write-HookOutput "Preflight Power BI: OK." 'Preflight Power BI: OK. Requisitos cumplidos: trabaja en LOCAL segun .claude/rules/pbi-02-matriz-responsabilidades.md; la nube requiere /pbi-nube.'
        exit 0
    }

    $instruccion = if ($r.resultado -eq 'BLOQUEADO') {
        'PUERTA DE ENTRADA CERRADA: antes de cualquier tarea de Power BI (modelo, DAX, reportes, publicacion) informa estos pendientes al usuario y ejecuta el skill /pbi-preflight para resolverlos. No improvises con otras herramientas (pbi-cli, edicion manual de TMDL/PBIR) para saltarte la puerta salvo autorizacion explicita del usuario.'
    } else {
        'Hay avisos: informalos al usuario al inicio y ofrece ejecutar /pbi-preflight. Se puede trabajar en LOCAL si el usuario lo acepta.'
    }
    $contexto = "Preflight Power BI: $($r.resultado) ($($r.resumen)), $($r.fecha). Detalle en .claude/pbi/estado/preflight.json.`n" +
                ($pendientes -join "`n") + "`n" + $instruccion
    Write-HookOutput "Preflight Power BI: $($r.resultado) - $($r.resumen). Ejecuta /pbi-preflight para ver y resolver." $contexto
    exit 0
}
catch {
    Write-HookOutput 'Preflight Power BI: no se pudo ejecutar la verificacion automatica.' ("El hook de preflight fallo: $($_.Exception.Message). Antes de trabajar en Power BI ejecuta /pbi-preflight.")
    exit 0
}
