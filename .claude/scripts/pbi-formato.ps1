<#
.SYNOPSIS
  Inventario, respaldo y verificacion del formato de los archivos Power BI del proyecto (regla pbi-05).

.DESCRIPTION
  Acciones:
    inventario  (por defecto) Lista .pbix/.pbit/.pbip y clasifica cada uno segun los casos de la regla pbi-05.
    respaldar   Copia un .pbix/.pbit a _respaldo_pbix\ con fecha (verificada con SHA256) y asegura las
                entradas de .gitignore. No borra ni modifica el original.
    verificar   Comprueba que un .pbip quedo bien: PBIR, TMDL, referencia byPath, validacion con
                powerbi-report-author y que los archivos con datos (.pbi\cache.abf) queden fuera de git.

  Este script NUNCA convierte: Microsoft solo admite PBIX <-> PBIP con Power BI Desktop
  (Archivo > Guardar como). Ver la regla .claude/rules/pbi-05-formato-pbip.md.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-formato.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-formato.ps1 -Accion respaldar -Ruta "Ventas.pbix"
  powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-formato.ps1 -Accion verificar -Ruta "Ventas.pbip"
#>
[CmdletBinding()]
param(
    [ValidateSet('inventario', 'respaldar', 'verificar')]
    [string]$Accion = 'inventario',
    [string]$Ruta,
    [string]$ProjectDir,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

if (-not $ProjectDir) {
    if ($env:CLAUDE_PROJECT_DIR) { $ProjectDir = $env:CLAUDE_PROJECT_DIR }
    else { $ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
}
$ProjectDir = (Get-Item -LiteralPath $ProjectDir).FullName.TrimEnd('\')
$Formato  = (Get-Content -Raw -Encoding UTF8 (Join-Path $ProjectDir '.claude\pbi\herramientas.json') | ConvertFrom-Json).formato
$Respaldo = Join-Path $ProjectDir $Formato.carpetaRespaldo
$Excluir  = '\\(\.claude|\.git|node_modules|' + [regex]::Escape($Formato.carpetaRespaldo) + ')(\\|$)'
$Items    = New-Object System.Collections.ArrayList

# ---------------------------------------------------------------- utilidades

function Add-Item {
    param([string]$Archivo, [string]$Tipo, [string]$Caso, [string]$Estado, [string]$Detalle, [string]$Accion = '')
    [void]$Items.Add([pscustomobject]@{ archivo = $Archivo; tipo = $Tipo; caso = $Caso; estado = $Estado; detalle = $Detalle; accion = $Accion })
}

function Get-Rel {
    param([string]$Path)
    if ($Path -and $Path.StartsWith($ProjectDir, [StringComparison]::OrdinalIgnoreCase)) { return $Path.Substring($ProjectDir.Length).TrimStart('\') }
    return $Path
}

function Invoke-Proc {
    param([string]$File, [string]$Arguments, [int]$TimeoutSec = 60)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    $psi.Arguments = $Arguments
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEndAsync()
    $err = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($TimeoutSec * 1000)) { try { $p.Kill() } catch { }; return [pscustomobject]@{ Code = -1; Out = ''; Err = 'timeout' } }
    return [pscustomobject]@{ Code = $p.ExitCode; Out = $out.Result; Err = $err.Result }
}

function Get-GitExe {
    $c = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Source }
    return $null
}

function Get-PbipInfo {
    param([System.IO.FileInfo]$File)
    $dir = $File.DirectoryName
    $base = [IO.Path]::GetFileNameWithoutExtension($File.Name)
    $rep = Join-Path $dir "$base.Report"
    try {
        $art = (Get-Content -Raw -Encoding UTF8 $File.FullName | ConvertFrom-Json).artifacts | Where-Object { $_.report } | Select-Object -First 1
        if ($art.report.path) { $rep = [IO.Path]::GetFullPath((Join-Path $dir ($art.report.path -replace '/', '\'))) }
    }
    catch { }
    $info = [pscustomobject]@{ base = $base; dir = $dir; report = $rep; formatoInforme = 'no encontrado'; paginas = 0; referencia = ''; modelo = ''; formatoModelo = '' }
    if (Test-Path (Join-Path $rep 'definition\report.json')) {
        $info.formatoInforme = 'PBIR'
        $info.paginas = @(Get-ChildItem -Path (Join-Path $rep 'definition\pages') -Directory -ErrorAction SilentlyContinue).Count
    }
    elseif (Test-Path (Join-Path $rep 'report.json')) { $info.formatoInforme = 'PBIR-Legacy' }
    $pbir = Join-Path $rep 'definition.pbir'
    if (Test-Path $pbir) {
        $ref = (Get-Content -Raw -Encoding UTF8 $pbir | ConvertFrom-Json).datasetReference
        if ($ref.byPath) {
            $info.referencia = 'byPath'
            $info.modelo = [IO.Path]::GetFullPath((Join-Path $rep ($ref.byPath.path -replace '/', '\')))
            if (Get-ChildItem -Path (Join-Path $info.modelo 'definition') -Filter '*.tmdl' -ErrorAction SilentlyContinue) { $info.formatoModelo = 'TMDL' }
            elseif (Test-Path (Join-Path $info.modelo 'model.bim')) { $info.formatoModelo = 'TMSL' }
            else { $info.formatoModelo = 'no encontrado' }
        }
        elseif ($ref.byConnection) { $info.referencia = 'byConnection'; $info.formatoModelo = 'en la nube' }
    }
    return $info
}

function Get-PbixProteccion {
    # Heuristica: un PBIX protegido no es un ZIP legible; uno etiquetado suele llevar MSIP_Label en sus metadatos.
    param([string]$Path)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = $null
    try { $zip = [IO.Compression.ZipFile]::OpenRead($Path) }
    catch { return 'no es un ZIP legible: probablemente esta cifrado por una etiqueta de confidencialidad con proteccion' }
    try {
        foreach ($e in $zip.Entries) {
            if ($e.Length -gt 2MB -or $e.FullName -match '(?i)^(DataModel|Report/StaticResources)') { continue }
            if ($e.FullName -notmatch '(?i)(docProps|custom|Metadata|Settings|Content_Types|SecurityBindings)') { continue }
            $sr = New-Object System.IO.StreamReader($e.Open(), $true)
            try { $t = $sr.ReadToEnd() } finally { $sr.Dispose() }
            if ($t -match '(?i)MSIP_Label|sensitivityLabel') { return "posible etiqueta de confidencialidad (en $($e.FullName))" }
        }
    }
    finally { $zip.Dispose() }
    return ''
}

function Test-DatosFueraDeGit {
    # Comprueba que .pbi\cache.abf y .pbi\localSettings.json de cada PBIP queden fuera de git.
    param([object[]]$Infos)
    $gitExe = Get-GitExe
    $enGit = $false
    if ($gitExe) { $enGit = ((Invoke-Proc $gitExe "-C `"$ProjectDir`" rev-parse --is-inside-work-tree").Out -match 'true') }
    if (-not $enGit) {
        $texto = (@(Get-ChildItem -Path $ProjectDir -Recurse -Depth 4 -Force -File -Filter '.gitignore' -ErrorAction SilentlyContinue) | ForEach-Object { Get-Content -Raw $_.FullName }) -join "`n"
        $faltan = @('cache.abf', 'localSettings.json' | Where-Object { $texto -notmatch [regex]::Escape($_) })
        if ($faltan) { Add-Item '.gitignore' 'proyecto' 'git' 'AVISO' ("El proyecto no esta en git y ningun .gitignore excluye: " + ($faltan -join ', ') + '. cache.abf contiene datos.') "powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-formato.ps1 -Accion respaldar -Ruta <archivo.pbix>  (o agregar las lineas de formato.gitignore)" }
        return
    }
    $versionados = @(((Invoke-Proc $gitExe "-C `"$ProjectDir`" ls-files").Out -split "`n") | Where-Object { $_ -match '(^|/)\.pbi/(cache\.abf|localSettings\.json)\s*$' } | ForEach-Object { $_.Trim() })
    if ($versionados) {
        Add-Item '.gitignore' 'proyecto' 'git' 'FALLA' ('Git ya versiona archivos locales con datos: ' + ($versionados -join ', ') + '. Siguen en el historial aunque se borren.') 'git rm --cached <archivo> y revisar el historial antes de compartir el repositorio'
    }
    foreach ($i in $Infos) {
        foreach ($carpeta in @($i.modelo, $i.report) | Where-Object { $_ }) {
            foreach ($nombre in @('cache.abf', 'localSettings.json')) {
                if ($nombre -eq 'cache.abf' -and $carpeta -eq $i.report) { continue }
                $prueba = Join-Path $carpeta ".pbi\$nombre"
                $r = Invoke-Proc $gitExe "-C `"$ProjectDir`" check-ignore --no-index -q `"$prueba`""
                if ($r.Code -ne 0) {
                    Add-Item (Get-Rel $prueba) 'proyecto' 'git' 'AVISO' "No esta excluido por .gitignore (contiene $(if ($nombre -eq 'cache.abf') { 'datos del modelo' } else { 'ajustes locales' }))." 'Agregar a .gitignore: **/.pbi/cache.abf y **/.pbi/localSettings.json'
                }
            }
        }
    }
    $crlf = (Invoke-Proc $gitExe "-C `"$ProjectDir`" config --get core.autocrlf").Out.Trim()
    if ($crlf -ne 'true') { Add-Item '.git' 'proyecto' 'git' 'INFO' "core.autocrlf = '$crlf'. Microsoft recomienda autocrlf porque Desktop usa CRLF." 'git config core.autocrlf true' }
}

# ---------------------------------------------------------------- acciones

function Invoke-Inventario {
    $files = @(Get-ChildItem -Path $ProjectDir -Recurse -Depth 4 -File -Include '*.pbix', '*.pbit', '*.pbip' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $Excluir })
    if ($files.Count -eq 0) {
        Add-Item '' 'proyecto' '0' 'INFO' 'No hay archivos Power BI (.pbix/.pbit/.pbip) en el proyecto.' 'Para empezar desde cero: Power BI Desktop > Archivo > Guardar como > Proyecto de Power BI (.pbip)'
        return
    }
    $pbips = @($files | Where-Object { $_.Extension -eq '.pbip' })
    $infos = @{}
    foreach ($p in $pbips) { $infos[$p.FullName] = Get-PbipInfo $p }

    foreach ($f in @($files | Where-Object { $_.Extension -ne '.pbip' })) {
        $rel = Get-Rel $f.FullName
        $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
        $par = $pbips | Where-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) -eq $base } | Select-Object -First 1
        if ($f.Extension -eq '.pbit') {
            if ($par) { Add-Item $rel 'pbit' '7' 'OK' "Plantilla; ya existe $(Get-Rel $par.FullName)." }
            else { Add-Item $rel 'pbit' '7' 'INFO' 'Plantilla (.pbit): solo se convierte si se va a desarrollar a partir de ella.' '/pbi-convertir-pbip (caso 7)' }
            continue
        }
        if ($par) {
            $i = $infos[$par.FullName]
            $carpetas = @($i.report, $i.modelo | Where-Object { $_ -and (Test-Path $_) })
            $ultimo = $null
            if ($carpetas.Count) {
                $ultimo = @(Get-ChildItem -Path $carpetas -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '\\\.pbi\\' } | Sort-Object LastWriteTime -Descending) | Select-Object -First 1
            }
            if ($ultimo -and $f.LastWriteTime -gt $ultimo.LastWriteTime) {
                Add-Item $rel 'pbix' '6' 'AVISO' "Existe $(Get-Rel $par.FullName), pero este .pbix es mas reciente ($($f.LastWriteTime.ToString('s')) frente a $($ultimo.LastWriteTime.ToString('s'))): puede tener cambios que no estan en el PBIP." 'Preguntar al usuario cual es la version valida; no sobrescribir ninguno'
            }
            else { Add-Item $rel 'pbix' '6' 'OK' "El PBIP $(Get-Rel $par.FullName) es la fuente de verdad; este .pbix es una copia." }
            continue
        }
        $det = @("Solo PBIX ($([Math]::Round($f.Length / 1MB, 1)) MB). Reportes: convertir obligatorio. Modelo: muy recomendado. Solo lectura: no hace falta.")
        $prot = Get-PbixProteccion $f.FullName
        if ($prot) { $det += "ATENCION: $prot. PBIP no soporta etiquetas de confidencialidad: confirmar con el responsable antes de convertir." }
        if ($f.FullName -match '(?i)\\(OneDrive|SharePoint)') { $det += 'Esta en una carpeta sincronizada de OneDrive/SharePoint: guardar el PBIP en una ruta local corta.' }
        if ($f.DirectoryName.Length -gt [int]$Formato.rutaMaxRecomendada) { $det += "Ruta larga ($($f.DirectoryName.Length) caracteres): riesgo de superar el limite de 260 en el PBIP." }
        Add-Item $rel 'pbix' '1-3' 'AVISO' ($det -join ' ') '/pbi-convertir-pbip'
    }

    foreach ($p in $pbips) {
        $i = $infos[$p.FullName]
        $prob = @(); $casos = @(); $estado = 'AVISO'
        switch ($i.formatoInforme) {
            'PBIR' { }
            'PBIR-Legacy' { $prob += "informe en PBIR-Legacy (report.json): abrir y guardar en Desktop $($Formato.pbirPorDefectoDesdeYYMM) o posterior lo convierte a PBIR"; $casos += '4' }
            default { $prob += "no se encontro la definicion del informe en $(Get-Rel $i.report)" }
        }
        switch ($i.formatoModelo) {
            'TMSL' { $prob += 'modelo en TMSL (model.bim): guardar en TMDL'; $casos += '5' }
            'no encontrado' { $prob += "no se encontro el modelo referenciado ($(Get-Rel $i.modelo))" }
            'en la nube' { $prob += 'informe con conexion en vivo a un modelo del servicio: los cambios del modelo son nube (/pbi-nube)'; $casos += '8'; if ($prob.Count -eq 1) { $estado = 'INFO' } }
        }
        $accionCaso = '/pbi-convertir-pbip'
        if (($casos -join ',') -eq '8') { $accionCaso = 'Trabajar el informe en local; para cambiar el modelo, /pbi-nube' }
        if ($prob) { Add-Item (Get-Rel $p.FullName) 'pbip' ($casos -join ',') $estado ($prob -join '; ') $accionCaso }
        else { Add-Item (Get-Rel $p.FullName) 'pbip' 'OK' 'OK' "PBIP con informe PBIR ($($i.paginas) paginas) y modelo TMDL (byPath)" }
    }
    if ($pbips.Count) { Test-DatosFueraDeGit @($infos.Values) }
}

function Invoke-Respaldar {
    if (-not $Ruta) { throw 'Indica -Ruta con el .pbix o .pbit a respaldar.' }
    $f = Get-Item -LiteralPath (Resolve-Path $Ruta).Path
    if ($f.Extension -notin '.pbix', '.pbit') { throw 'Solo se respaldan .pbix o .pbit.' }
    New-Item -ItemType Directory -Force -Path $Respaldo | Out-Null
    $dest = Join-Path $Respaldo ('{0}_{1}{2}' -f $f.BaseName, (Get-Date -Format 'yyyyMMdd-HHmmss'), $f.Extension)
    Copy-Item -LiteralPath $f.FullName -Destination $dest
    if ((Get-FileHash -LiteralPath $f.FullName).Hash -ne (Get-FileHash -LiteralPath $dest).Hash) { throw 'La copia de respaldo no coincide con el original (SHA256).' }
    Add-Item (Get-Rel $dest) 'respaldo' '' 'OK' "Copia verificada (SHA256) de $(Get-Rel $f.FullName). El original no se toco."

    $gi = Join-Path $ProjectDir '.gitignore'
    $actual = @()
    if (Test-Path $gi) { $actual = @(Get-Content $gi | ForEach-Object { $_.Trim() }) }
    $faltan = @($Formato.gitignore | Where-Object { $actual -notcontains $_ })
    if ($faltan) {
        $bloque = "# Power BI (regla pbi-05): ajustes locales, cache con datos y respaldos de PBIX`r`n" + ($faltan -join "`r`n") + "`r`n"
        if ($actual.Count) { $bloque = "`r`n" + $bloque }
        [IO.File]::AppendAllText($gi, $bloque, (New-Object System.Text.UTF8Encoding($false)))
        Add-Item '.gitignore' 'proyecto' '' 'OK' ('Agregado: ' + ($faltan -join ', '))
    }
    else { Add-Item '.gitignore' 'proyecto' '' 'OK' 'Ya contenia las entradas necesarias.' }
}

function Invoke-Verificar {
    $p = $null
    if ($Ruta) { if (Test-Path $Ruta) { $p = Get-Item -LiteralPath (Resolve-Path $Ruta).Path } }
    else { $p = Get-ChildItem -Path $ProjectDir -Recurse -Depth 4 -File -Filter '*.pbip' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $Excluir } | Select-Object -First 1 }
    if (-not $p -or $p.Extension -ne '.pbip') {
        Add-Item $Ruta 'pbip' '' 'FALLA' 'No se encontro el .pbip: la conversion no se completo (Desktop > Archivo > Guardar como > Proyecto de Power BI).'
        return
    }
    $rel = Get-Rel $p.FullName
    $i = Get-PbipInfo $p
    switch ($i.formatoInforme) {
        'PBIR' { Add-Item $rel 'informe' '' 'OK' "Informe en PBIR con $($i.paginas) pagina(s)" }
        'PBIR-Legacy' { Add-Item $rel 'informe' '4' 'FALLA' 'El informe quedo en PBIR-Legacy: guardar de nuevo con Desktop 26.09 o posterior.' }
        default { Add-Item $rel 'informe' '' 'FALLA' "Falta la definicion del informe en $(Get-Rel $i.report)" }
    }
    switch ($i.formatoModelo) {
        'TMDL' { Add-Item $rel 'modelo' '' 'OK' "Modelo en TMDL ($(Get-Rel $i.modelo)) con referencia byPath" }
        'TMSL' { Add-Item $rel 'modelo' '5' 'AVISO' 'El modelo quedo en TMSL (model.bim): activar TMDL y volver a guardar.' }
        'en la nube' { Add-Item $rel 'modelo' '8' 'INFO' 'Conexion en vivo a un modelo del servicio (byConnection): el modelo no esta en local.' }
        default { Add-Item $rel 'modelo' '' 'FALLA' "No se encontro el modelo referenciado ($(Get-Rel $i.modelo))." }
    }
    if ($i.formatoInforme -eq 'PBIR' -and (Get-Command powerbi-report-author -ErrorAction SilentlyContinue)) {
        $r = Invoke-Proc $env:ComSpec "/d /c powerbi-report-author validate `"$($i.report)`"" 180
        $resumen = (($r.Out + "`n" + $r.Err) -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 3) -join ' | '
        if ($r.Code -eq 0) { Add-Item $rel 'validacion' '' 'OK' "powerbi-report-author validate: sin errores. $resumen" }
        else { Add-Item $rel 'validacion' '' 'FALLA' "powerbi-report-author validate (codigo $($r.Code)): $resumen" 'Corregir con la skill powerbi-report-cli antes de editar' }
    }
    elseif ($i.formatoInforme -eq 'PBIR') { Add-Item $rel 'validacion' '' 'AVISO' 'powerbi-report-author no esta instalado: validacion estructural pendiente (/pbi-preflight).' }
    Test-DatosFueraDeGit @($i)
}

switch ($Accion) {
    'respaldar' { Invoke-Respaldar }
    'verificar' { Invoke-Verificar }
    default { Invoke-Inventario }
}

$resultado = 'OK'
if ($Items | Where-Object { $_.estado -eq 'FALLA' }) { $resultado = 'FALLA' }
elseif ($Items | Where-Object { $_.estado -eq 'AVISO' }) { $resultado = 'AVISOS' }
$reporte = [pscustomobject]@{ accion = $Accion; proyecto = $ProjectDir; resultado = $resultado; items = $Items }

if ($Json) { $reporte | ConvertTo-Json -Depth 5; return }
Write-Output ("== Formato Power BI | {0} | {1} ==" -f $Accion, $ProjectDir)
foreach ($it in $Items) {
    $caso = ''
    if ($it.caso -and $it.caso -ne 'OK') { $caso = " (caso $($it.caso))" }
    Write-Output ("[{0,-5}] {1}{2}: {3}" -f $it.estado, $it.archivo, $caso, $it.detalle)
    if ($it.accion -and $it.estado -ne 'OK') { Write-Output ("        -> {0}" -f $it.accion) }
}
Write-Output ("RESULTADO: {0}" -f $resultado)
