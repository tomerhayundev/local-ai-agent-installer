# Installs a personal AI agent on this Windows computer: WSL2 and Docker Desktop if they are missing, then the agent's
# package, its keeper and the agent itself. Double-click install-agent.cmd, which starts this script with the
# execution policy bypassed for that one process. Windows asks for administrator rights only when something must be
# installed.
#
# The questions and the work are in the package: each step is `python install.py <step>` in one `docker run`. This
# script only does what can't happen inside a container: it installs and starts Docker, gathers this computer's facts,
# pulls the image, runs the steps one after another, starts what they ask for and opens their links (the front-end
# contract in the installers plan). It is plain ASCII, so Windows PowerShell 5.1 reads it the same in every language.
param(
    [string]$PackageOverride = '',
    [int]$Restarts = 0,
    [switch]$Resume
)

$ErrorActionPreference = 'Continue'
if ($PackageOverride) { $env:LOCAL_AI_AGENT_PACKAGE = $PackageOverride }
$Package = if ($env:LOCAL_AI_AGENT_PACKAGE) { $env:LOCAL_AI_AGENT_PACKAGE } else { 'ghcr.io/tomerhayundev/local-ai-agent' }
$Network = 'local-ai-agent-net'
$LicenseUrl = 'https://www.docker.com/legal/docker-subscription-service-agreement/'
$InstallerUrl = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'
$DockerExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
$DockerBin = Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin'
$AgentsHome = Join-Path $env:LOCALAPPDATA 'LocalAIAgent'
$RunOnceKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
$DockerWait = 300
$RestartCode = 10
$MaxRestarts = 2            # the first restart, and at most one more on a resume (then it says what is missing)
# Windows PowerShell by its full path, for the elevated child and RunOnce: never a name that a search could resolve.
$PowerShellExe = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path -LiteralPath $PowerShellExe)) {
    $PowerShellExe = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
}
# What the elevated child is given: these functions, as already loaded here, and nothing read from a file.
$ElevatedFunctions = @('Say', 'Wait-ForEnter', 'Invoke-Wsl', 'Test-Wsl', 'Test-DockerUser', 'New-AdminFolder',
    'Test-DockerSignature', 'Install-DockerParts')
$ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
$STD_OUTPUT_HANDLE = -11

# UTF-8 both ways (Review Focus 1): what the steps print, and what the owner types, such as a Hebrew name.
$Utf8 = New-Object System.Text.UTF8Encoding $false
try { [Console]::OutputEncoding = $Utf8 } catch { }
try { [Console]::InputEncoding = $Utf8 } catch { }
$OutputEncoding = $Utf8

function Say([string]$Text = '') {
    Write-Host $Text
}

function Wait-ForEnter {
    [void](Read-Host 'Press Enter to close this window')
}

# Stops before the installer changed anything itself (or after something outside the steps failed).
function Stop-Installer([string]$Why) {
    if ($Why) { Say $Why }
    Say 'The installer stopped.'
    Wait-ForEnter
    exit 2
}

# A step ended with exit 1 or 2: it has said why.
function Stop-AfterStep {
    Say 'The installer stopped. Nothing else was changed.'
    Wait-ForEnter
    exit 2
}

# ANSI colours on the console (Ruling 14), so the QR codes draw on Windows 10's old console too. When it fails the
# installer carries on: the link is printed under each code anyway.
function Enable-Colours {
    try {
        Add-Type -Namespace LocalAIAgent -Name VtConsole -ErrorAction Stop -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
        $handle = [LocalAIAgent.VtConsole]::GetStdHandle($STD_OUTPUT_HANDLE)
        [uint32]$mode = 0
        if ([LocalAIAgent.VtConsole]::GetConsoleMode($handle, [ref]$mode)) {
            $wanted = [uint32]($mode -bor $ENABLE_VIRTUAL_TERMINAL_PROCESSING)
            [void][LocalAIAgent.VtConsole]::SetConsoleMode($handle, $wanted)
        }
    } catch { }
}

function Test-Package {
    if (-not $Package -or $Package.Contains('@')) {
        Stop-Installer 'This installer has no package filled in. Set LOCAL_AI_AGENT_PACKAGE to the package''s address.'
    }
    if ($Package -notmatch '^[A-Za-z0-9._:/-]+$') {
        Stop-Installer 'The package''s address is not host/owner/name.'
    }
}

# ---- Docker ---------------------------------------------------------------------------------------------------------

function Find-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $DockerBin)) {
        $env:Path = "$env:Path;$DockerBin"
    }
    return [bool](Get-Command docker -ErrorAction SilentlyContinue)
}

function Test-Docker {
    if (-not (Find-Docker)) { return $false }
    & docker info *> $null
    return ($LASTEXITCODE -eq 0)
}

# Runs wsl.exe with its output shown. wsl.exe writes UTF-16LE, on stdout and stderr, so both come through PowerShell
# (2>&1) and are read as that encoding, for this call only. Sets $script:WslCode.
function Invoke-Wsl {
    $before = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
        & wsl.exe @args 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { "$_" }
        } | Out-Host
        $script:WslCode = $LASTEXITCODE
    } catch {
        $script:WslCode = 1
    } finally {
        [Console]::OutputEncoding = $before
    }
}

function Test-Wsl {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    & wsl.exe --status *> $null
    return ($LASTEXITCODE -eq 0)
}

function Test-DockerUser([string]$User) {
    try {
        $null = Get-LocalGroupMember -Group 'docker-users' -Member $User -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Get-InstallUser {
    return "$env:USERDOMAIN\$env:USERNAME"
}

function Confirm-Install {
    Say 'This installer will:'
    if (-not (Test-Path -LiteralPath $DockerExe)) {
        Say "  - Install Docker Desktop (and WSL2 if it is missing) and accept Docker's license (free for personal use"
        Say "    and for small businesses under Docker's terms): $LicenseUrl"
        Say '    Windows asks for administrator rights for this, and may need a restart.'
    }
    Say "  - Download the agent's package ($Package)"
    Say "  - Create the agents home: $AgentsHome"
    Say '  - Start the keeper and the agent'
    Say '  - Open a Tailscale sign-in in your browser (unless you choose home Wi-Fi only)'
    $answer = Read-Host 'Type yes to go on'
    if ("$answer".Trim() -notmatch '^(y|yes)$') {
        Say 'Nothing was changed.'
        Wait-ForEnter
        exit 2
    }
}

# A new folder `%ProgramData%\LocalAIAgent-setup-<random>` that only SYSTEM and Administrators can reach, with
# nothing inherited from ProgramData (where every user may create files). It is made with its ACL in one call, so it
# never exists with a looser one, and it must be empty. Directly under ProgramData, whose own ACL no user controls.
# Returns its path, or '' when it could not be made.
function New-AdminFolder {
    $folder = Join-Path $env:ProgramData ('LocalAIAgent-setup-' + [guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $folder) { return '' }
    $security = New-Object System.Security.AccessControl.DirectorySecurity
    $security.SetAccessRuleProtection($true, $false)
    $inherit = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $propagate = [System.Security.AccessControl.PropagationFlags]::None
    foreach ($sid in @('S-1-5-18', 'S-1-5-32-544')) {
        $who = New-Object System.Security.Principal.SecurityIdentifier $sid
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($who, 'FullControl', $inherit,
            $propagate, 'Allow')
        $security.AddAccessRule($rule)
    }
    try {
        $null = [System.IO.Directory]::CreateDirectory($folder, $security)
    } catch {
        return ''
    }
    try {
        $inside = @(Get-ChildItem -LiteralPath $folder -Force -ErrorAction Stop).Count
    } catch {
        $inside = -1
    }
    if ($inside -ne 0) {
        Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
        return ''
    }
    return $folder
}

# Whether Windows says the file's Authenticode signature is valid, and Docker Inc signed it.
function Test-DockerSignature([string]$Path) {
    try {
        $signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
    } catch {
        return $false
    }
    if ($signature.Status -ne 'Valid' -or -not $signature.SignerCertificate) { return $false }
    $subject = [string]$signature.SignerCertificate.Subject
    return ($subject -cmatch '(^|,\s*)(CN|O)=("Docker,? Inc\.?"|Docker Inc\.?)\s*(,|$)')
}

# The elevated child (New-ElevatedCommand): WSL2, Docker Desktop and the docker-users group. Sets $script:PartCode: 0
# when done, $RestartCode when Windows needs a restart, 1 when something failed.
function Install-DockerParts([string]$User) {
    $script:PartCode = 1
    $restart = $false
    if (-not (Test-Wsl)) {
        Say 'Installing WSL2...'
        Invoke-Wsl --install --no-distribution
        if ($script:WslCode -ne 0) { Say 'WSL2 could not be installed.'; return }
        $restart = $true
    }
    if (-not (Test-Path -LiteralPath $DockerExe)) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            # winget checks the installer it downloads against the SHA-256 in its manifest.
            Say 'Installing Docker Desktop with winget...'
            & winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements |
                Out-Host
        } else {
            # This child runs elevated, so the installer it runs must be one the user could not have replaced: it is
            # downloaded into a fresh folder only SYSTEM and Administrators can write, and run only when Docker
            # signed it.
            $folder = New-AdminFolder
            if (-not $folder) { Say 'No folder for Docker''s installer could be made.'; return }
            try {
                Say 'Downloading Docker Desktop...'
                $setup = Join-Path $folder 'Docker Desktop Installer.exe'
                try {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    $ProgressPreference = 'SilentlyContinue'
                    Invoke-WebRequest -Uri $InstallerUrl -OutFile $setup -UseBasicParsing -ErrorAction Stop
                } catch {
                    Say 'Docker Desktop could not be downloaded.'
                    return
                }
                if (-not (Test-DockerSignature $setup)) {
                    Say 'The Docker Desktop download could not be verified; nothing was installed.'
                    return
                }
                Say 'Installing Docker Desktop...'
                $setupArgs = @('install', '--quiet', '--accept-license', '--backend=wsl-2')
                $null = Start-Process -FilePath $setup -ArgumentList $setupArgs -Wait -PassThru
            } finally {
                Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        if (-not (Test-Path -LiteralPath $DockerExe)) { Say 'Docker Desktop could not be installed.'; return }
    }
    if (-not (Test-DockerUser $User)) {
        try {
            Add-LocalGroupMember -Group 'docker-users' -Member $User -ErrorAction Stop
            $restart = $true
        } catch {
            if (-not (Test-DockerUser $User)) { Say "$User could not be added to the docker-users group."; return }
        }
    }
    if ($restart) { $script:PartCode = $RestartCode } else { $script:PartCode = 0 }
}

# Windows needs a restart: a copy of this script carries on after the next sign-in, through RunOnce.
function Request-Restart {
    New-AgentsHome
    $folder = Join-Path $AgentsHome 'installer'
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $copy = Join-Path $folder 'install-agent.ps1'
    if ($PSCommandPath -ne $copy) {
        Copy-Item -LiteralPath $PSCommandPath -Destination $copy -Force
        $agentYaml = Join-Path $PSScriptRoot 'agent.yaml'
        if (Test-Path -LiteralPath $agentYaml -PathType Leaf) {
            Copy-Item -LiteralPath $agentYaml -Destination (Join-Path $folder 'agent.yaml') -Force
        }
    }
    $command = '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" -Resume -Restarts {2}' -f $PowerShellExe, $copy,
        ($Restarts + 1)
    if ($env:LOCAL_AI_AGENT_PACKAGE) { $command += ' -PackageOverride "{0}"' -f $env:LOCAL_AI_AGENT_PACKAGE }
    if (-not (Test-Path -LiteralPath $RunOnceKey)) { New-Item -Path $RunOnceKey | Out-Null }
    Set-ItemProperty -LiteralPath $RunOnceKey -Name 'LocalAIAgent' -Value $command
    Say 'Windows needs a restart. After you sign in again, the installer carries on by itself.'
    Wait-ForEnter
    exit 0
}

# A PowerShell string expression that gives back $Value exactly: base64 inside single quotes, so no quote, dollar or
# backtick in the value (a user name, say) can end the string or be read as code.
function ConvertTo-Literal([string]$Value) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))
    return "([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encoded')))"
}

# The elevated child's whole code, for -EncodedCommand (UTF-16LE, base64): the constants it uses, the functions in
# $ElevatedFunctions as they are loaded in this process, then Install-DockerParts for $User. Nothing in it is read
# from a file, so nothing a user can write while the UAC prompt is open runs as administrator.
function New-ElevatedCommand([string]$User) {
    $lines = @(
        '$ErrorActionPreference = ''Continue''',
        ('$DockerExe = ' + (ConvertTo-Literal $DockerExe)),
        ('$InstallerUrl = ' + (ConvertTo-Literal $InstallerUrl)),
        ('$RestartCode = ' + [int]$RestartCode))
    foreach ($name in $ElevatedFunctions) {
        $lines += "function $name {`n" + (Get-Command $name -CommandType Function).Definition + "`n}"
    }
    $lines += ('Install-DockerParts -User ' + (ConvertTo-Literal $User))
    $lines += 'if ($script:PartCode -eq 1) { Wait-ForEnter }'
    $lines += 'exit $script:PartCode'
    return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($lines -join "`n"))
}

# A resume that would ask for a restart once too often: say what is still missing, and stop.
function Stop-StillMissing([string]$User) {
    $missing = @()
    if (-not (Test-Wsl)) { $missing += 'WSL2' }
    if (-not (Test-Path -LiteralPath $DockerExe)) { $missing += 'Docker Desktop' }
    if (-not (Test-DockerUser $User)) { $missing += 'the docker-users group' }
    if (-not $missing) { $missing = @('Docker Desktop') }
    Stop-Installer ("Windows was restarted, but $($missing -join ' and ') still isn't ready. Install Docker " +
        'Desktop yourself from https://docs.docker.com/desktop/, then run this installer again.')
}

function Install-Docker {
    if (Test-Docker) { return }
    $user = Get-InstallUser
    if ((Test-Path -LiteralPath $DockerExe) -and (Test-Wsl) -and (Test-DockerUser $user)) { return }
    Say 'Windows asks for administrator rights to install what Docker needs.'
    $childArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', (New-ElevatedCommand $user))
    try {
        $child = Start-Process -FilePath $PowerShellExe -Verb RunAs -Wait -PassThru -ArgumentList $childArgs `
            -ErrorAction Stop
    } catch {
        Stop-Installer 'Docker needs administrator rights to install. Run the installer again and choose Yes.'
    }
    if ($child.ExitCode -eq $RestartCode) {
        if ($Restarts -ge $MaxRestarts) { Stop-StillMissing $user }
        Request-Restart
    }
    if ($child.ExitCode -ne 0) { Stop-Installer 'Docker could not be installed.' }
}

function Start-Docker {
    if (Test-Docker) { return }
    if (-not (Test-Path -LiteralPath $DockerExe)) { Stop-Installer 'Docker Desktop is not installed.' }
    Start-Process -FilePath $DockerExe
    Say 'Waiting for Docker to start (up to 5 minutes)...'
    $deadline = (Get-Date).AddSeconds($DockerWait)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        if (Test-Docker) { return }
    }
    Stop-Installer "Docker didn't start within 5 minutes. Start Docker Desktop, then run this installer again."
}

function Test-Compose {
    $version = "$(& docker compose version --short 2>$null)".Trim()
    if ($version -match '^v?(\d+)\.(\d+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        if ($major -gt 2 -or ($major -eq 2 -and $minor -ge 30)) { return }
    }
    if (-not $version) { $version = 'none' }
    Stop-Installer ("Docker Compose 2.30 or newer is needed (this computer has $version). Update Docker Desktop, " +
        'then run this installer again.')
}

# ---- This computer's facts (the thirteen names of the front-end contract) ------------------------------------------

function Get-HomeAddress {
    try {
        $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop |
            Sort-Object { $_.RouteMetric + $_.InterfaceMetric } | Select-Object -First 1
        $address = Get-NetIPAddress -InterfaceIndex $route.ifIndex -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1
        return [string]$address.IPAddress
    } catch {
        return ''
    }
}

function Get-Facts {
    $env:HOST_HOME = $AgentsHome
    $env:HOST_PLATFORM = 'windows'
    $env:HOST_NAME = $env:COMPUTERNAME
    $env:HOST_TZ = (Get-TimeZone).Id
    $env:HOST_LANG = (Get-Culture).TwoLetterISOLanguageName
    $env:HOST_LAN = Get-HomeAddress
    # This computer's DNS servers are not passed on Docker Desktop: its own DNS stands between the containers and this
    # computer, and a router's address may not answer from there. The installer says what that leaves out.
    $env:HOST_DNS = ''
    # Not on Docker Desktop: an empty value unsets the name, and `docker run -e NAME` then passes nothing.
    $env:HOST_UID = ''
    $env:HOST_GID = ''
    $env:DOCKER_GID = ''
    $env:PACKAGE = $Package
    $env:KEEPER_USER = ''
    $env:AGENT_USER = ''
}

# ---- The package ----------------------------------------------------------------------------------------------------

function New-AgentsHome {
    if (Test-Path -LiteralPath $AgentsHome) { return }
    try {
        New-Item -ItemType Directory -Path $AgentsHome -ErrorAction Stop | Out-Null
    } catch {
        Stop-Installer "The agents home could not be made: $AgentsHome"
    }
}

function Get-Image {
    Say "Downloading the agent's package..."
    & docker pull "$($Package):latest" | Out-Host
    if ($LASTEXITCODE -ne 0) { Stop-Installer "The package could not be downloaded: $($Package):latest" }
    $json = (& docker image inspect --format '{{json .Config.Labels}}' "$($Package):latest" 2>$null) -join ''
    $version = ''
    try {
        $labels = $json | ConvertFrom-Json
        if ($labels) { $version = [string]$labels.'org.opencontainers.image.version' }
    } catch { }
    if (-not $version) { Stop-Installer 'this package has no version' }
    if ($version -notmatch '^[A-Za-z0-9._-]+$') { Stop-Installer 'this package''s version is not a plain version' }
    $script:Image = "$($Package):$version"
    & docker pull $script:Image | Out-Null
    if ($LASTEXITCODE -ne 0) { Stop-Installer "The package could not be downloaded: $script:Image" }
}

function Clear-OldInstaller {
    $state = "$(& docker container inspect --format '{{.State.Running}}' agent-installer 2>$null)".Trim()
    if ($state -eq 'true') {
        Stop-Installer 'Another installer is running on this computer. Let it finish, then run this one again.'
    }
    if ($state -eq 'false') { & docker rm -f agent-installer *> $null }
}

function Test-Network {
    & docker network inspect $Network *> $null
    return ($LASTEXITCODE -eq 0)
}

# ---- The steps ------------------------------------------------------------------------------------------------------

# Only a web link goes to the browser: Start-Process would also run a program or open a file.
function Open-Link([string]$Url) {
    if ($Url -notmatch '^https?://[^\s"]+$') { return }
    try {
        Start-Process $Url
    } catch {
        Say '(The browser could not be opened: open that link yourself.)'
    }
}

# Shows the step's lines as they come, opens OPEN links at once, and keeps UP, NEXT and PROBE for after the step.
function Use-StepLine([string]$Line) {
    # A blank line on docker's stderr comes through 2>&1 as an empty record, which "$_" names by its type.
    if ($Line -ceq 'System.Management.Automation.RemoteException') { $Line = '' }
    if ($Line -cmatch '^OPEN (\S+)$') { Open-Link $Matches[1]; return }
    if ($Line -cmatch '^UP (.+)$') { $script:Ups.Add($Matches[1]); return }
    if ($Line -cmatch '^NEXT (.+)$') { $script:Next = $Matches[1]; return }
    if ($Line -cmatch '^PROBE (.+)$') { $script:Probe = $Matches[1]; return }
    Write-Host $Line
}

# One step, as the user given. Sets $script:StepCode, and the step's UP, NEXT and PROBE lines.
function Invoke-Step {
    param([string]$User, [string[]]$StepArgs)
    Clear-OldInstaller
    $dockerArgs = @('run', '--rm', '-i', '--name', 'agent-installer',
        '-v', "$($AgentsHome):/agents-home", '-v', '/var/run/docker.sock:/var/run/docker.sock')
    if (Test-Network) { $dockerArgs += @('--network', $Network) }
    $dockerArgs += @('--user', $User,
        '-e', 'HOST_HOME', '-e', 'HOST_PLATFORM', '-e', 'HOST_NAME', '-e', 'HOST_TZ', '-e', 'HOST_LANG',
        '-e', 'HOST_LAN', '-e', 'HOST_UID', '-e', 'HOST_GID', '-e', 'DOCKER_GID', '-e', 'PACKAGE',
        '-e', 'KEEPER_USER', '-e', 'AGENT_USER', '-e', 'HOST_DNS',
        $script:Image, 'python', '-u', 'install.py')
    $dockerArgs += $StepArgs
    $script:Ups = New-Object System.Collections.Generic.List[string]
    $script:Next = ''
    $script:Probe = ''
    & docker @dockerArgs 2>&1 | ForEach-Object { "$_" } | ForEach-Object { Use-StepLine $_ }
    $script:StepCode = $LASTEXITCODE
}

# Docker Desktop: who the keeper and the agent run as, from what the image's user can do (Ruling 16).
function Invoke-Probe {
    Invoke-Step -User '1000:1000' -StepArgs @('probe')
    if ($script:StepCode -ne 0) { Stop-AfterStep }
    $socket = $false
    $files = $false
    try {
        $result = $script:Probe | ConvertFrom-Json
        $socket = ($result.socket -eq $true)
        $files = ($result.files -eq $true)
    } catch { }
    if ($socket -and $files) { $env:KEEPER_USER = '1000:1000' } else { $env:KEEPER_USER = '0:0' }
    if ($files) { $env:AGENT_USER = '' } else { $env:AGENT_USER = '0:0' }
}

function Copy-AgentProfile {
    $source = Join-Path $PSScriptRoot 'agent.yaml'
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { return }
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $AgentsHome 'import') -ErrorAction Stop | Out-Null
        Copy-Item -LiteralPath $source -Destination (Join-Path $AgentsHome 'import\agent.yaml') -Force -ErrorAction Stop
    } catch {
        Stop-Installer 'agent.yaml could not be copied.'
    }
}

function Start-Compose([string]$Path) {
    if ($Path -cnotmatch '^[A-Za-z0-9._/-]+$' -or $Path.StartsWith('/') -or $Path.Contains('..')) {
        Stop-Installer "A step asked to start an unexpected file: $Path"
    }
    $file = Join-Path $AgentsHome ($Path -replace '/', '\')
    & docker compose -f $file up -d | Out-Host
    if ($LASTEXITCODE -ne 0) { Stop-Installer "Docker could not start $Path." }
}

function Invoke-Steps {
    $next = 'start'
    while ($next) {
        if ($next -cnotmatch '^[a-z0-9 -]+$') { Stop-Installer 'A step asked for an unexpected next step.' }
        Invoke-Step -User $env:KEEPER_USER -StepArgs ($next.Trim() -split '\s+')
        if ($script:StepCode -ne 0) { Stop-AfterStep }
        foreach ($up in $script:Ups) { Start-Compose $up }
        $next = $script:Next
    }
}

function Main {
    Enable-Colours
    try { Unblock-File -LiteralPath $PSCommandPath -ErrorAction Stop } catch { }
    Test-Package
    if (-not $Resume) { Confirm-Install }
    Install-Docker
    Start-Docker
    Test-Compose
    Get-Facts
    New-AgentsHome
    Get-Image
    Invoke-Probe
    Copy-AgentProfile
    Invoke-Steps
    Say 'The installer is done.'
    Wait-ForEnter
}

Main
