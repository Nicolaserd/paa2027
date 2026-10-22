<#
.SYNOPSIS
  Verificacion de requisitos (preflight) para proyectos Power BI con Claude Code.

.DESCRIPTION
  Solo LEE el equipo y el proyecto: no instala nada y no se conecta a ningun tenant
  (Power BI Service / Fabric / Entra ID). Las consultas en linea son publicas y sin
  credenciales: registry.npmjs.org, raw.githubusercontent.com, learn.microsoft.com,
  nodejs.org y winget. Se desactivan con -SinRed, con PBI_PREFLIGHT_OFFLINE=1 o con
  politica.verificacionEnLinea=false en .claude/pbi/herramientas.json.

  Estados: OK | AVISO | FALLA | INFO
  Resultado: BLOQUEADO (falla algo obligatorio/necesario/de seguridad) | AVISOS | OK

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-preflight.ps1 -Guardar
  powershell -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/pbi-preflight.ps1 -SinRed -Json
#>
[CmdletBinding()]
param(
    [string]$ProjectDir,
    [switch]$SinRed,
    [switch]$Json,
    [switch]$Guardar
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

if (-not $ProjectDir) {
    if ($env:CLAUDE_PROJECT_DIR) { $ProjectDir = $env:CLAUDE_PROJECT_DIR }
    else { $ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
}
$ProjectDir = (Get-Item -LiteralPath $ProjectDir).FullName.TrimEnd('\')
$PbiDir     = Join-Path $ProjectDir '.claude\pbi'
$EstadoDir  = Join-Path $PbiDir 'estado'
$Manifest   = Get-Content -Raw -Encoding UTF8 (Join-Path $PbiDir 'herramientas.json') | ConvertFrom-Json
$Politica   = $Manifest.politica
$PluginInfo = $Manifest.plugin
$Confiables = @($Manifest.confianza.npmMantenedores)
$Online     = (-not $SinRed) -and [bool]$Politica.verificacionEnLinea -and ($env:PBI_PREFLIGHT_OFFLINE -ne '1')
$ClaudeHome = Join-Path $env:USERPROFILE '.claude'

$Checks = New-Object System.Collections.ArrayList
$Plan   = New-Object System.Collections.ArrayList
$DocsCambiadas = New-Object System.Collections.ArrayList

# ---------------------------------------------------------------- utilidades

function Add-Check {
    param([string]$Id, [string]$Nombre, [string]$Prioridad, [string]$Estado, [string]$Detalle, [string]$Accion = '')
    [void]$Checks.Add([pscustomobject]@{
        id = $Id; nombre = $Nombre; prioridad = $Prioridad; estado = $Estado; detalle = $Detalle; accion = $Accion
    })
}

function Add-Plan {
    param([int]$Orden, [string]$Id, [string]$Comando, [string]$Motivo, [switch]$Manual)
    [void]$Plan.Add([pscustomobject]@{ orden = $Orden; id = $Id; comando = $Comando; motivo = $Motivo; manual = [bool]$Manual })
}

function Invoke-Check {
    param([string]$Id, [string]$Nombre, [string]$Prioridad, [scriptblock]$Body)
    try { & $Body }
    catch { Add-Check $Id $Nombre $Prioridad 'AVISO' ('No se pudo verificar: ' + $_.Exception.Message) }
}

function Invoke-Proc {
    # Ejecuta un ejecutable con limite de tiempo. Devuelve stdout, o $null si no termina a tiempo.
    param([string]$File, [string]$Arguments, [int]$TimeoutSec = 30)
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
    $null = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($TimeoutSec * 1000)) { try { $p.Kill() } catch { }; return $null }
    return $out.Result
}

function Get-Exe {
    param([string]$Name)
    $c = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Source }
    return $null
}

function Get-Json {
    param([string]$Url)
    Invoke-RestMethod -Uri $Url -TimeoutSec 15 -Headers @{ 'User-Agent' = 'pbi-preflight' }
}

function Get-NpmLatest {
    param([string]$Package)
    Get-Json ('https://registry.npmjs.org/' + ($Package -replace '/', '%2F') + '/latest')
}

function Get-VersionCore {
    param([string]$Text)
    $m = [regex]::Match([string]$Text, '\d+(\.\d+)+')
    if ($m.Success) { return $m.Value }
    return $null
}

function Compare-Version {
    # -1 si A < B, 0 si iguales, 1 si A > B. Ignora sufijos de prerelease.
    param([string]$A, [string]$B)
    $pa = @((Get-VersionCore $A) -split '\.' | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })
    $pb = @((Get-VersionCore $B) -split '\.' | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })
    for ($i = 0; $i -lt [Math]::Max($pa.Count, $pb.Count); $i++) {
        $x = 0; if ($i -lt $pa.Count) { $x = $pa[$i] }
        $y = 0; if ($i -lt $pb.Count) { $y = $pb[$i] }
        if ($x -lt $y) { return -1 }
        if ($x -gt $y) { return 1 }
    }
    return 0
}

function Test-MicrosoftSignature {
    param([string]$Path)
    $s = Get-AuthenticodeSignature -FilePath $Path
    return ($s.Status -eq 'Valid' -and $s.SignerCertificate.Subject -match [regex]::Escape($Manifest.confianza.firmanteAuthenticode))
}

function Test-NpmMeta {
    # Devuelve '' si el paquete publicado es de confianza; si no, la lista de problemas.
    param($Meta, [string]$RepoEsperado)
    $prob = @()
    $mant = @($Meta.maintainers | ForEach-Object { $_.name })
    if (-not ($mant | Where-Object { $Confiables -contains $_ })) { $prob += ('mantenedores no confiables: ' + ($mant -join ',')) }
    if ($Meta._npmUser -and ($Confiables -notcontains $Meta._npmUser.name)) { $prob += ('publicado por ' + $Meta._npmUser.name) }
    if ([string]$Meta.repository.url -notmatch [regex]::Escape($RepoEsperado)) { $prob += ('repositorio inesperado: ' + $Meta.repository.url) }
    if ($Meta.deprecated) { $prob += ('version deprecated: ' + $Meta.deprecated) }
    return ($prob -join '; ')
}

function Get-InstalledPlugins {
    $res = @()
    if ($script:ClaudeExe) {
        $txt = Invoke-Proc $script:ClaudeExe 'plugin list --json' 45
        if ($txt) {
            $start = $txt.IndexOfAny([char[]]'[{')
            if ($start -ge 0) {
                $j = $txt.Substring($start) | ConvertFrom-Json
                $items = @()
                if ($j -is [array]) { $items = $j } elseif ($null -ne $j.installed) { $items = @($j.installed) }
                foreach ($it in $items) {
                    $id = @($it.pluginId, $it.id, $it.name) | Where-Object { $_ } | Select-Object -First 1
                    $enabled = $true
                    if ($null -ne $it.enabled) { $enabled = [bool]$it.enabled }
                    $path = @($it.installPath, $it.path) | Where-Object { $_ } | Select-Object -First 1
                    $res += [pscustomobject]@{ Id = [string]$id; Version = [string]$it.version; Enabled = $enabled; Path = [string]$path }
                }
                return $res
            }
        }
    }
    $f = Join-Path $ClaudeHome 'plugins\installed_plugins.json'
    if (Test-Path $f) {
        $j = Get-Content -Raw -Encoding UTF8 $f | ConvertFrom-Json
        $plugins = $j
        if ($null -ne $j.plugins) { $plugins = $j.plugins }
        foreach ($prop in $plugins.PSObject.Properties) {
            foreach ($e in @($prop.Value)) {
                $res += [pscustomobject]@{ Id = $prop.Name; Version = [string]$e.version; Enabled = $true; Path = [string]$e.installPath }
            }
        }
    }
    return $res
}

function Get-McpRegistrations {
    # Registros manuales de MCP relacionados con Power BI (usuario, local y proyecto).
    $regs = @()
    $add = {
        param($Origen, $Servers)
        if (-not $Servers) { return }
        foreach ($s in $Servers.PSObject.Properties) {
            $txt = $s.Value | ConvertTo-Json -Compress -Depth 10
            $tipo = $null
            if ($txt -match 'api\.fabric\.microsoft\.com/v1/mcp/powerbi') { $tipo = 'hospedado' }
            elseif ($txt -match 'powerbi-modeling-mcp') { $tipo = 'local' }
            if ($tipo) { $script:McpRegs += [pscustomobject]@{ Origen = $Origen; Nombre = $s.Name; Tipo = $tipo } }
        }
    }
    $script:McpRegs = @()
    $cj = Join-Path $env:USERPROFILE '.claude.json'
    if (Test-Path $cj) {
        $j = Get-Content -Raw -Encoding UTF8 $cj | ConvertFrom-Json
        & $add 'usuario (~/.claude.json)' $j.mcpServers
        if ($j.projects) {
            $norm = ($ProjectDir -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
            foreach ($p in $j.projects.PSObject.Properties) {
                if ((($p.Name -replace '\\', '/').TrimEnd('/').ToLowerInvariant()) -eq $norm) { & $add 'local (proyecto en ~/.claude.json)' $p.Value.mcpServers }
            }
        }
    }
    $pj = Join-Path $ProjectDir '.mcp.json'
    if (Test-Path $pj) { & $add 'proyecto (.mcp.json)' ((Get-Content -Raw -Encoding UTF8 $pj | ConvertFrom-Json).mcpServers) }
    return $script:McpRegs
}

$script:ClaudeExe = Get-Exe 'claude'

# ---------------------------------------------------------------- 1. equipo

Invoke-Check 'windows' 'Windows' 'prerequisito' {
    if ($env:OS -eq 'Windows_NT') { Add-Check 'windows' 'Windows' 'prerequisito' 'OK' ([Environment]::OSVersion.VersionString) }
    else { Add-Check 'windows' 'Windows' 'prerequisito' 'FALLA' 'El MCP local, Power BI Desktop y el Desktop Bridge requieren Windows.' }
}

Invoke-Check 'claude-code' 'Claude Code' 'prerequisito' {
    if (-not $script:ClaudeExe) {
        Add-Check 'claude-code' 'Claude Code' 'prerequisito' 'FALLA' 'No se encontro el comando claude en el PATH.' 'Instalar Claude Code'
        return
    }
    $v = Get-VersionCore (Invoke-Proc $script:ClaudeExe '--version' 20)
    if (-not $Online) { Add-Check 'claude-code' 'Claude Code' 'prerequisito' 'OK' "instalada $v (vigencia no verificada: sin red)"; return }
    $canal = 'latest'
    $us = Join-Path $ClaudeHome 'settings.json'
    if (Test-Path $us) { $c = (Get-Content -Raw -Encoding UTF8 $us | ConvertFrom-Json).autoUpdatesChannel; if ($c) { $canal = [string]$c } }
    $tags = Get-Json 'https://registry.npmjs.org/-/package/@anthropic-ai/claude-code/dist-tags'
    $ultima = $tags.$canal
    if (-not $ultima) { $ultima = $tags.latest }
    if ((Compare-Version $v $ultima) -lt 0) {
        Add-Check 'claude-code' 'Claude Code' 'prerequisito' 'AVISO' "instalada $v, ultima del canal '$canal' $ultima (desactualizada)" 'claude update'
        Add-Plan 10 'claude-code' 'claude update' "Claude Code $v -> $ultima (plugins, hooks y reglas requieren version reciente)"
    }
    else { Add-Check 'claude-code' 'Claude Code' 'prerequisito' 'OK' "instalada $v (canal $canal)" }
}

Invoke-Check 'node' 'Node.js' 'prerequisito' {
    $nodeExe = Get-Exe 'node'
    $instalarNode = 'winget install --id OpenJS.NodeJS.LTS -e --source winget'
    if (-not $nodeExe) {
        Add-Check 'node' 'Node.js' 'prerequisito' 'FALLA' 'No instalado (lo necesitan el MCP y las CLIs).' $instalarNode
        Add-Plan 20 'node' $instalarNode 'Node.js LTS con soporte vigente'
        return
    }
    $nv = (Invoke-Proc $nodeExe '--version' 15).Trim()
    $major = [int](($nv.TrimStart('v')).Split('.')[0])
    if ($major -lt [int]$Politica.nodeMayorMinimo) {
        Add-Check 'node' 'Node.js' 'prerequisito' 'FALLA' "$nv es menor que el minimo $($Politica.nodeMayorMinimo) (Node 20 sin soporte desde 2026-04-30; las CLIs exigen >= 20)." $instalarNode
        Add-Plan 20 'node' $instalarNode "Actualizar Node.js $nv a una LTS con soporte"
        return
    }
    if ($Online) {
        $e = (Get-Json 'https://raw.githubusercontent.com/nodejs/Release/main/schedule.json').("v$major")
        if ($e -and $e.end -and ([datetime]$e.end -lt (Get-Date))) {
            Add-Check 'node' 'Node.js' 'prerequisito' 'FALLA' "$nv sin soporte de seguridad desde $($e.end)." $instalarNode
            Add-Plan 20 'node' $instalarNode "Node.js $nv fuera de soporte"
            return
        }
        $fin = ''; if ($e) { $fin = " (soporte hasta $($e.end))" }
        Add-Check 'node' 'Node.js' 'prerequisito' 'OK' "$nv$fin"
    }
    else { Add-Check 'node' 'Node.js' 'prerequisito' 'OK' "$nv (calendario de soporte no verificado: sin red)" }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Add-Check 'npm' 'npm' 'prerequisito' 'FALLA' 'npm no esta en el PATH.' $instalarNode
    }
}

Invoke-Check 'git' 'Git' 'prerequisito' {
    $gitExe = Get-Exe 'git'
    if ($gitExe) { Add-Check 'git' 'Git' 'prerequisito' 'OK' ((Invoke-Proc $gitExe '--version' 15).Trim()) }
    else {
        Add-Check 'git' 'Git' 'prerequisito' 'FALLA' 'No instalado: es la linea base para revisar y revertir cambios del agente.' 'winget install --id Git.Git -e --source winget'
        Add-Plan 25 'git' 'winget install --id Git.Git -e --source winget' 'Git para linea base y reversion'
    }
}

# ---------------------------------------------------------------- 2. Power BI Desktop y Desktop Bridge

Invoke-Check 'pbi-desktop' 'Power BI Desktop' 'prerequisito' {
    $cands = @()
    foreach ($p in @("$env:ProgramFiles\Microsoft Power BI Desktop\bin\PBIDesktop.exe", "${env:ProgramFiles(x86)}\Microsoft Power BI Desktop\bin\PBIDesktop.exe")) {
        if ($p -and (Test-Path $p)) { $cands += [pscustomobject]@{ Ruta = $p; Origen = 'MSI' } }
    }
    $store = $null
    try { $store = Get-AppxPackage -Name 'Microsoft.MicrosoftPowerBIDesktop' -ErrorAction SilentlyContinue | Select-Object -First 1 } catch { }
    if ($store) { $cands += [pscustomobject]@{ Ruta = (Join-Path $store.InstallLocation 'bin\PBIDesktop.exe'); Origen = 'Microsoft Store' } }
    $instalar = 'winget install --id Microsoft.PowerBI -e --source winget  (o Microsoft Store)'
    if (-not $cands) {
        Add-Check 'pbi-desktop' 'Power BI Desktop' 'prerequisito' 'FALLA' 'No instalado (necesario para trabajar en local, recargar y capturar).' $instalar
        Add-Plan 28 'pbi-desktop' $instalar 'Instalar Power BI Desktop (requiere elevacion)' -Manual
        return
    }
    $d = $cands[0]
    $info = (Get-Item $d.Ruta).VersionInfo
    $ver = Get-VersionCore $info.ProductVersion
    $yymm = [regex]::Match([string]$info.ProductVersion, '\((\d{2}\.\d{2})\)').Groups[1].Value
    $firma = Test-MicrosoftSignature $d.Ruta
    if (-not $firma) {
        Add-Check 'pbi-desktop' 'Power BI Desktop' 'seguridad' 'FALLA' "$($d.Ruta) no tiene firma Authenticode valida de Microsoft." 'Reinstalar desde Microsoft Store o winget'
        return
    }
    $detalle = "$ver ($yymm, $($d.Origen), firma Microsoft valida)"
    if ($yymm -and ((Compare-Version $yymm $Politica.pbiDesktopMinimoYYMM) -lt 0)) {
        Add-Check 'pbi-desktop' 'Power BI Desktop' 'prerequisito' 'FALLA' "$detalle es anterior a $($Politica.pbiDesktopMinimoYYMM): no tiene Desktop Bridge." 'Actualizar Power BI Desktop'
        Add-Plan 28 'pbi-desktop' 'winget upgrade --id Microsoft.PowerBI -e --source winget  (o Microsoft Store)' 'Desktop sin Desktop Bridge' -Manual
        return
    }
    $wg = Get-Exe 'winget'
    if ($Online -and $wg -and $d.Origen -eq 'MSI') {
        $out = Invoke-Proc $wg 'show --id Microsoft.PowerBI -e --source winget --accept-source-agreements --disable-interactivity' 40
        $ultima = [regex]::Match([string]$out, '(?m)^\s*Versi.{1,2}n:\s*(\S+)').Groups[1].Value
        if ($ultima -and ((Compare-Version $ver $ultima) -lt 0)) {
            Add-Check 'pbi-desktop' 'Power BI Desktop' 'prerequisito' 'AVISO' "$detalle; disponible $ultima" 'winget upgrade --id Microsoft.PowerBI -e --source winget'
            Add-Plan 28 'pbi-desktop' 'winget upgrade --id Microsoft.PowerBI -e --source winget' "Power BI Desktop $ver -> $ultima (cerrar Desktop antes; requiere elevacion)" -Manual
            return
        }
    }
    $pbirDefecto = $Manifest.formato.pbirPorDefectoDesdeYYMM
    if ($yymm -and ((Compare-Version $yymm $pbirDefecto) -lt 0)) {
        Add-Check 'pbi-desktop' 'Power BI Desktop' 'prerequisito' 'AVISO' "$detalle es anterior a $pbirDefecto`: no convierte automaticamente los informes PBIR-Legacy a PBIR." 'Actualizar Power BI Desktop'
        return
    }
    Add-Check 'pbi-desktop' 'Power BI Desktop' 'prerequisito' 'OK' $detalle
}

Invoke-Check 'desktop-bridge' 'Desktop Bridge' 'necesaria' {
    $pol = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Power BI Desktop' -Name 'DesktopNamedPipeBridge' -ErrorAction SilentlyContinue
    if ($pol -and $pol.DesktopNamedPipeBridge -eq 0) {
        Add-Check 'desktop-bridge' 'Desktop Bridge' 'necesaria' 'FALLA' 'Deshabilitado por politica de la organizacion (HKLM ...\Power BI Desktop\DesktopNamedPipeBridge = 0).' 'Solicitar a TI que lo habilite'
        return
    }
    $procs = @(Get-Process -Name 'PBIDesktop' -ErrorAction SilentlyContinue)
    if (-not $procs) {
        Add-Check 'desktop-bridge' 'Desktop Bridge' 'necesaria' 'INFO' 'Power BI Desktop cerrado: no se puede confirmar (activado por defecto). Se confirma con Desktop abierto.'
        return
    }
    $pipes = @()
    try { $pipes = @([System.IO.Directory]::GetFiles('\\.\pipe\') | Where-Object { $_ -match 'pbi-desktop-bridge-' }) }
    catch {
        Add-Check 'desktop-bridge' 'Desktop Bridge' 'necesaria' 'INFO' 'No se pudieron enumerar los named pipes; confirmar con: powerbi-desktop status'
        return
    }
    if ($pipes.Count -gt 0) { Add-Check 'desktop-bridge' 'Desktop Bridge' 'necesaria' 'OK' "$($pipes.Count) instancia(s) de Desktop con el Bridge activo" }
    else {
        $ruta = 'Archivo > Opciones y configuracion > Opciones > Seguridad > Desktop Bridge > "Enable external tool access to Power BI Desktop through secure local APIs"'
        Add-Check 'desktop-bridge' 'Desktop Bridge' 'necesaria' 'FALLA' 'Desktop abierto pero sin pipe del Bridge.' $ruta
        Add-Plan 60 'desktop-bridge' $ruta 'Habilitar el Desktop Bridge y reiniciar Desktop' -Manual
    }
}

# ---------------------------------------------------------------- 3. marketplace, plugin y skills

$Installed = @()
try { $Installed = @(Get-InstalledPlugins) } catch { }
$PluginId = "$($PluginInfo.id)@$($PluginInfo.marketplace)"
$Plugin = $Installed | Where-Object { $_.Id -eq $PluginId -or $_.Id -eq $PluginInfo.id } | Select-Object -First 1
$RemotePlugin = $null
if ($Online) {
    try { $RemotePlugin = Get-Json (($Manifest.fuentes | Where-Object { $_.id -eq 'github-plugin-json' }).url) } catch { }
}

Invoke-Check 'marketplace' 'Marketplace fabric-collection' 'obligatorio' {
    $km = Join-Path $ClaudeHome 'plugins\known_marketplaces.json'
    $m = $null
    if (Test-Path $km) { $m = (Get-Content -Raw -Encoding UTF8 $km | ConvertFrom-Json).($PluginInfo.marketplace) }
    $cmd = "claude plugin marketplace add $($PluginInfo.marketplaceRepo)"
    if (-not $m) {
        Add-Check 'marketplace' 'Marketplace fabric-collection' 'obligatorio' 'FALLA' 'No agregado.' $cmd
        Add-Plan 30 'marketplace' $cmd 'Marketplace oficial de Microsoft (Skills for Fabric)'
        return
    }
    $origen = "$($m.source.repo)$($m.source.url)"
    if ($origen -match [regex]::Escape($PluginInfo.marketplaceRepo)) { Add-Check 'marketplace' 'Marketplace fabric-collection' 'obligatorio' 'OK' "origen $origen" }
    else {
        Add-Check 'marketplace' 'Marketplace fabric-collection' 'seguridad' 'FALLA' "El nombre fabric-collection apunta a '$origen', no a $($PluginInfo.marketplaceRepo). Posible suplantacion: NO instalar desde ahi." "claude plugin marketplace remove $($PluginInfo.marketplace)"
    }
}

Invoke-Check 'plugin' 'Plugin powerbi-authoring' 'obligatorio' {
    $instalar = "claude plugin install $PluginId --scope user"
    if (-not $Plugin) {
        Add-Check 'plugin' 'Plugin powerbi-authoring' 'obligatorio' 'FALLA' 'No instalado (trae las skills y registra el Modeling MCP).' $instalar
        Add-Plan 40 'plugin' $instalar 'Plugin oficial powerbi-authoring (reiniciar Claude Code despues)'
        return
    }
    if (-not $Plugin.Enabled) {
        Add-Check 'plugin' 'Plugin powerbi-authoring' 'obligatorio' 'FALLA' "Instalado ($($Plugin.Version)) pero deshabilitado." "claude plugin enable $PluginId"
        Add-Plan 40 'plugin' "claude plugin enable $PluginId" 'Habilitar el plugin'
        return
    }
    if ($RemotePlugin -and $Plugin.Version -and ((Compare-Version $Plugin.Version $RemotePlugin.version) -lt 0)) {
        Add-Check 'plugin' 'Plugin powerbi-authoring' 'obligatorio' 'AVISO' "instalado $($Plugin.Version), ultima $($RemotePlugin.version)" "claude plugin update $PluginId"
        Add-Plan 40 'plugin' "claude plugin update $PluginId" "Actualizar plugin $($Plugin.Version) -> $($RemotePlugin.version) (reiniciar Claude Code)"
        return
    }
    Add-Check 'plugin' 'Plugin powerbi-authoring' 'obligatorio' 'OK' "version $($Plugin.Version)"
}

foreach ($skill in @($PluginInfo.skillsEsperadas)) {
    $sk = $skill
    Invoke-Check "skill-$sk" "Skill $sk" 'incluida' {
        if (-not $Plugin) { Add-Check "skill-$sk" "Skill $sk" 'incluida' 'FALLA' 'Llega con el plugin powerbi-authoring (no instalado).' 'Instalar el plugin'; return }
        $rutas = @()
        if ($Plugin.Path) { $rutas += (Join-Path $Plugin.Path "skills\$sk\SKILL.md") }
        $cache = Join-Path $ClaudeHome "plugins\cache\$($PluginInfo.marketplace)\$($PluginInfo.id)"
        if (Test-Path $cache) { $rutas += @(Get-ChildItem -Path "$cache\*\skills\$sk\SKILL.md" -ErrorAction SilentlyContinue | ForEach-Object FullName) }
        if ($rutas | Where-Object { Test-Path $_ }) { Add-Check "skill-$sk" "Skill $sk" 'incluida' 'OK' 'presente en el plugin' }
        else { Add-Check "skill-$sk" "Skill $sk" 'incluida' 'FALLA' 'No se encontro SKILL.md en el plugin instalado.' "claude plugin update $PluginId" }
    }
}

Invoke-Check 'manifiesto-oficial' 'Manifiesto oficial del plugin' 'documentacion' {
    if (-not $Online) { Add-Check 'manifiesto-oficial' 'Manifiesto oficial del plugin' 'documentacion' 'INFO' 'No verificado (sin red).'; return }
    if (-not $RemotePlugin) { Add-Check 'manifiesto-oficial' 'Manifiesto oficial del plugin' 'documentacion' 'AVISO' 'No se pudo leer plugin.json oficial (posible cambio de ruta en GitHub).' '/pbi-verificar-docs'; return }
    $remotas = @($RemotePlugin.skills | ForEach-Object { Split-Path $_ -Leaf }) | Sort-Object
    $esperadas = @($PluginInfo.skillsEsperadas) | Sort-Object
    $mcp = $RemotePlugin.mcpServers.($PluginInfo.mcpServidor) | ConvertTo-Json -Compress -Depth 5
    $difs = @()
    if (($remotas -join ',') -ne ($esperadas -join ',')) { $difs += "skills oficiales: $($remotas -join ', ')" }
    if (-not $mcp -or $mcp -notmatch [regex]::Escape($PluginInfo.mcpPaquete)) { $difs += "MCP del plugin cambio: $mcp" }
    if ($difs) {
        Add-Check 'manifiesto-oficial' 'Manifiesto oficial del plugin' 'documentacion' 'AVISO' ('Cambio respecto a lo verificado: ' + ($difs -join ' | ')) '/pbi-verificar-docs'
        Add-Plan 90 'docs' '/pbi-verificar-docs' 'El manifiesto oficial del plugin cambio' -Manual
    }
    else { Add-Check 'manifiesto-oficial' 'Manifiesto oficial del plugin' 'documentacion' 'OK' "plugin $($RemotePlugin.version): skills y MCP coinciden con lo verificado" }
}

# ---------------------------------------------------------------- 4. Power BI Modeling MCP

Invoke-Check 'modeling-mcp' 'Power BI Modeling MCP' 'obligatorio' {
    $regs = @(Get-McpRegistrations)
    $nubePlugins = @($Installed | Where-Object { $id = ($_.Id -split '@')[0]; $PluginInfo.pluginsNube -contains $id })
    $locales = @($regs | Where-Object { $_.Tipo -eq 'local' })
    if ($Plugin -and $Plugin.Enabled) { $locales += [pscustomobject]@{ Origen = "plugin $PluginId"; Nombre = $PluginInfo.mcpServidor; Tipo = 'local' } }
    $hospedados = @($regs | Where-Object { $_.Tipo -eq 'hospedado' })
    foreach ($np in $nubePlugins) { $hospedados += [pscustomobject]@{ Origen = "plugin $($np.Id)"; Nombre = 'MCP hospedado + FabricIQ + SQL endpoint'; Tipo = 'hospedado' } }

    if ($locales.Count -eq 0) {
        Add-Check 'modeling-mcp' 'Power BI Modeling MCP' 'obligatorio' 'FALLA' 'No registrado. Se registra automaticamente al instalar el plugin powerbi-authoring.' 'Instalar el plugin'
    }
    elseif ($locales.Count -gt 1) {
        Add-Check 'modeling-mcp' 'Power BI Modeling MCP' 'obligatorio' 'AVISO' ('Registrado mas de una vez: ' + (($locales | ForEach-Object { "$($_.Nombre) [$($_.Origen)]" }) -join '; ')) 'Quitar el registro manual (claude mcp remove <nombre>) y dejar el del plugin'
    }
    else { Add-Check 'modeling-mcp' 'Power BI Modeling MCP' 'obligatorio' 'OK' "registrado via $($locales[0].Origen)" }

    if ($hospedados.Count -gt 0) {
        $lista = ($hospedados | ForEach-Object { "$($_.Nombre) [$($_.Origen)]" }) -join '; '
        Add-Check 'mcp-hospedado' 'MCP hospedado (nube)' 'obligatorio' 'FALLA' "Registrado: $lista. Es NUBE y Microsoft desaconseja tener local y hospedado a la vez." 'Deshabilitar en proyectos locales: claude plugin disable fabric-skills@fabric-collection / claude mcp remove <nombre>'
    }

    if ($Online) {
        $meta = Get-NpmLatest $PluginInfo.mcpPaquete
        $prob = Test-NpmMeta $meta 'github.com/microsoft/powerbi-modeling-mcp'
        if ($prob) { Add-Check 'mcp-paquete' 'Paquete npm del MCP' 'seguridad' 'FALLA' "$($meta.version): $prob. NO usar hasta revisar." '/pbi-verificar-docs' }
        else { Add-Check 'mcp-paquete' 'Paquete npm del MCP' 'seguridad' 'OK' "ultima $($meta.version) publicada por Microsoft (el plugin usa @latest)" }
    }

    $npx = Join-Path $env:LOCALAPPDATA 'npm-cache\_npx'
    $exes = @()
    if (Test-Path $npx) { $exes = @(Get-ChildItem -Path "$npx\*\node_modules\@microsoft\powerbi-modeling-mcp-win32-*" -Recurse -Filter 'powerbi-modeling-mcp.exe' -ErrorAction SilentlyContinue) }
    if ($exes.Count -eq 0) { Add-Check 'mcp-binario' 'Binario del MCP' 'seguridad' 'INFO' 'Aun no descargado: npx lo descarga al primer arranque del servidor.' }
    else {
        $malos = @($exes | Where-Object { -not (Test-MicrosoftSignature $_.FullName) })
        if ($malos) { Add-Check 'mcp-binario' 'Binario del MCP' 'seguridad' 'FALLA' ('Sin firma valida de Microsoft: ' + ($malos.FullName -join '; ')) "Remove-Item -Recurse -Force `"$npx`"" }
        else { Add-Check 'mcp-binario' 'Binario del MCP' 'seguridad' 'OK' "$($exes.Count) binario(s) en cache npx con firma Microsoft valida" }
    }
}

# ---------------------------------------------------------------- 5. CLIs de reportes y Desktop Bridge

$NpmRoot = Join-Path $env:APPDATA 'npm\node_modules'
if (-not (Test-Path $NpmRoot)) { try { $NpmRoot = (& npm root -g 2>$null | Select-Object -First 1) } catch { } }

foreach ($t in @($Manifest.herramientas | Where-Object { $_.bin })) {
    $tool = $t
    Invoke-Check $tool.id $tool.nombre $tool.prioridad {
        $falta = 'FALLA'
        if ($tool.prioridad -eq 'recomendada') { $falta = 'AVISO' }
        $pkgJson = Join-Path $NpmRoot (($tool.npm -replace '/', '\') + '\package.json')
        $instalada = $null
        if ($NpmRoot -and (Test-Path $pkgJson)) { $instalada = (Get-Content -Raw -Encoding UTF8 $pkgJson | ConvertFrom-Json).version }
        $objetivo = $tool.versionVerificada
        if ($Online) {
            $meta = Get-NpmLatest $tool.npm
            $prob = Test-NpmMeta $meta $tool.repo
            if ($prob) {
                Add-Check $tool.id $tool.nombre 'seguridad' 'FALLA' "$($meta.version): $prob. NO instalar ni actualizar." '/pbi-verificar-docs'
                return
            }
            $objetivo = $meta.version
        }
        $cmd = "npm install -g $($tool.npm)@$objetivo"
        if (-not $instalada) {
            Add-Check $tool.id $tool.nombre $tool.prioridad $falta "No instalada (comando $($tool.bin))." $cmd
            Add-Plan 50 $tool.id $cmd "$($tool.nombre) $objetivo (version exacta verificada)"
            return
        }
        if (-not (Get-Command $tool.bin -ErrorAction SilentlyContinue)) {
            Add-Check $tool.id $tool.nombre $tool.prioridad 'AVISO' "Instalada $instalada pero el comando $($tool.bin) no esta en el PATH." 'Agregar la carpeta global de npm al PATH y reiniciar la terminal'
            return
        }
        if ((Compare-Version $instalada $objetivo) -lt 0) {
            Add-Check $tool.id $tool.nombre $tool.prioridad 'AVISO' "instalada $instalada, ultima $objetivo" $cmd
            Add-Plan 50 $tool.id $cmd "Actualizar $($tool.nombre) $instalada -> $objetivo"
            return
        }
        $nota = ''
        if (-not $Online) { $nota = ' (vigencia no verificada: sin red)' }
        Add-Check $tool.id $tool.nombre $tool.prioridad 'OK' "instalada $instalada$nota"
    }
}

# ---------------------------------------------------------------- 6. herramientas de terceros y de nube

Invoke-Check 'pbi-cli' 'pbi-cli (terceros)' 'info' {
    if (Get-Command pbi -ErrorAction SilentlyContinue) {
        $global = Join-Path $ClaudeHome 'CLAUDE.md'
        $nota = ''
        if ((Test-Path $global) -and (Select-String -Path $global -Pattern 'pbi-cli' -Quiet)) { $nota = ' Tu ~/.claude/CLAUDE.md ordena usar sus skills: en estos proyectos manda la regla pbi-02 (oficiales primero).' }
        Add-Check 'pbi-cli' 'pbi-cli (terceros)' 'info' 'INFO' ("Detectado (PyPI pbi-cli-tool, no es de Microsoft). Solo como respaldo con autorizacion del usuario." + $nota)
    }
}

Invoke-Check 'azure-cli' 'Azure CLI (solo nube)' 'info' {
    if (Get-Exe 'az') { Add-Check 'azure-cli' 'Azure CLI (solo nube)' 'info' 'INFO' 'Instalada. Cualquier uso pasa por /pbi-nube (requiere aprobacion).' }
    else { Add-Check 'azure-cli' 'Azure CLI (solo nube)' 'info' 'INFO' 'No instalada: solo hace falta para publicar o desplegar en Fabric (ver /pbi-nube). No se instala en el preflight.' }
}

# ---------------------------------------------------------------- 7. proyecto

Invoke-Check 'proyecto-git' 'Repositorio git del proyecto' 'proyecto' {
    $gitExe = Get-Exe 'git'
    if (-not $gitExe) { return }
    $dentro = (Invoke-Proc $gitExe "-C `"$ProjectDir`" rev-parse --is-inside-work-tree" 15)
    if ([string]$dentro -notmatch 'true') {
        Add-Check 'proyecto-git' 'Repositorio git del proyecto' 'proyecto' 'AVISO' 'El proyecto no esta bajo git: no hay forma de revisar o revertir cambios del agente.' 'git init ; git add -A ; git commit -m "Linea base antes de cambios del agente"'
        Add-Plan 70 'proyecto-git' 'git init ; git add -A ; git commit -m "Linea base antes de cambios del agente"' 'Linea base del proyecto (recomendacion oficial de Microsoft)'
        return
    }
    $head = Invoke-Proc $gitExe "-C `"$ProjectDir`" rev-parse --verify HEAD" 15
    if (-not ([string]$head).Trim()) {
        Add-Check 'proyecto-git' 'Repositorio git del proyecto' 'proyecto' 'AVISO' 'Repositorio sin ningun commit de linea base.' 'git add -A ; git commit -m "Linea base antes de cambios del agente"'
        return
    }
    $pend = @((Invoke-Proc $gitExe "-C `"$ProjectDir`" status --porcelain" 15) -split "`n" | Where-Object { $_.Trim() })
    $det = 'con linea base'
    if ($pend.Count) { $det = "con linea base; $($pend.Count) cambio(s) sin commit" }
    Add-Check 'proyecto-git' 'Repositorio git del proyecto' 'proyecto' 'OK' $det
}

Invoke-Check 'proyecto-formato' 'Formato del proyecto (PBIP)' 'proyecto' {
    # La logica de formato vive en pbi-formato.ps1 (regla pbi-05); aqui solo se resume.
    $inv = & (Join-Path $PSScriptRoot 'pbi-formato.ps1') -Accion inventario -ProjectDir $ProjectDir -Json | Out-String | ConvertFrom-Json
    foreach ($it in @($inv.items)) {
        $prio = 'proyecto'
        if ($it.estado -eq 'FALLA') { $prio = 'seguridad' }
        $nombre = 'Formato del proyecto'
        if ($it.archivo) { $nombre = "Formato $($it.archivo)" }
        $caso = ''
        if ($it.caso -and $it.caso -ne 'OK' -and $it.caso -ne 'git') { $caso = " [pbi-05, caso $($it.caso)]" }
        Add-Check 'proyecto-formato' $nombre $prio $it.estado ($it.detalle + $caso) $it.accion
    }
}

# ---------------------------------------------------------------- 8. vigencia de la documentacion oficial

Invoke-Check 'documentacion' 'Documentacion oficial' 'documentacion' {
    $dias = ((Get-Date) - [datetime]$Manifest.verificadoEl).Days
    if (-not $Online) { Add-Check 'documentacion' 'Documentacion oficial' 'documentacion' 'INFO' "Verificada el $($Manifest.verificadoEl) (hace $dias dias). Cambios no comprobados: sin red."; return }
    $rotas = @()
    foreach ($f in @($Manifest.fuentes | Where-Object { $_.tipo -eq 'learn' })) {
        try {
            $h = (Invoke-WebRequest -Uri $f.url -UseBasicParsing -TimeoutSec 15).Content
            $m = [regex]::Match($h, '<meta\s+name="updated_at"\s+content="([^"]+)"')
            if ($m.Success -and ([datetime]$m.Groups[1].Value -gt [datetime]$f.updatedAtVerificado)) {
                [void]$DocsCambiadas.Add([pscustomobject]@{ id = $f.id; url = $f.url; verificado = $f.updatedAtVerificado; actual = $m.Groups[1].Value })
            }
        }
        catch { $rotas += $f.url }
    }
    if ($rotas) {
        Add-Check 'documentacion' 'Documentacion oficial' 'documentacion' 'AVISO' ('Paginas oficiales no disponibles (posible cambio de URL): ' + ($rotas -join ', ')) '/pbi-verificar-docs'
        Add-Plan 90 'docs' '/pbi-verificar-docs' 'Paginas oficiales movidas o caidas' -Manual
    }
    if ($DocsCambiadas.Count) {
        Add-Check 'documentacion' 'Documentacion oficial' 'documentacion' 'AVISO' ("$($DocsCambiadas.Count) pagina(s) oficial(es) cambiaron desde la verificacion del $($Manifest.verificadoEl): " + (($DocsCambiadas | ForEach-Object { $_.id }) -join ', ')) '/pbi-verificar-docs'
        Add-Plan 90 'docs' '/pbi-verificar-docs' 'Revisar cambios en la documentacion oficial y actualizar reglas' -Manual
    }
    elseif ($dias -gt [int]$Politica.reverificarDocsDias) {
        Add-Check 'documentacion' 'Documentacion oficial' 'documentacion' 'AVISO' "Ultima verificacion documental hace $dias dias." '/pbi-verificar-docs'
    }
    elseif (-not $rotas) { Add-Check 'documentacion' 'Documentacion oficial' 'documentacion' 'OK' "Sin cambios desde la verificacion del $($Manifest.verificadoEl)" }
}

# ---------------------------------------------------------------- resultado

$bloqueantes = @($Checks | Where-Object { $_.estado -eq 'FALLA' -and @('obligatorio', 'necesaria', 'prerequisito', 'seguridad', 'incluida') -contains $_.prioridad })
$avisos = @($Checks | Where-Object { $_.estado -eq 'AVISO' -or ($_.estado -eq 'FALLA' -and $bloqueantes -notcontains $_) })
$resultado = 'OK'
if ($bloqueantes.Count) { $resultado = 'BLOQUEADO' } elseif ($avisos.Count) { $resultado = 'AVISOS' }

$planUnico = @($Plan | Sort-Object orden, comando -Unique | Sort-Object orden)
$reporte = [pscustomobject]@{
    fecha             = (Get-Date).ToString('s')
    versionManifiesto = $Manifest.version
    enLinea           = $Online
    proyecto          = $ProjectDir
    resultado         = $resultado
    resumen           = "$($bloqueantes.Count) bloqueante(s), $($avisos.Count) aviso(s)"
    checks            = $Checks
    plan              = $planUnico
    docsCambiadas     = $DocsCambiadas
}

if ($Guardar) {
    New-Item -ItemType Directory -Force -Path $EstadoDir | Out-Null
    $reporte | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -Path (Join-Path $EstadoDir 'preflight.json')
}

if ($Json) { $reporte | ConvertTo-Json -Depth 6; return }

$modo = 'en linea'
if (-not $Online) { $modo = 'sin red' }
Write-Output ("== Preflight Power BI | {0} | {1} ==" -f $reporte.fecha, $modo)
foreach ($c in $Checks) {
    Write-Output ("[{0,-5}] {1,-13} {2}: {3}" -f $c.estado, $c.prioridad, $c.nombre, $c.detalle)
    if ($c.accion -and $c.estado -ne 'OK' -and $c.estado -ne 'INFO') { Write-Output ("        -> {0}" -f $c.accion) }
}
Write-Output ''
Write-Output ("RESULTADO: {0} ({1})" -f $resultado, $reporte.resumen)
if ($planUnico.Count) {
    Write-Output 'Plan sugerido (requiere confirmacion del usuario antes de ejecutar):'
    $i = 1
    foreach ($p in $planUnico) {
        $tag = ''
        if ($p.manual) { $tag = ' [manual]' }
        Write-Output ("  {0}. {1}{2}  # {3}" -f $i, $p.comando, $tag, $p.motivo)
        $i++
    }
}
