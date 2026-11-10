# Запускается хуком SessionStart при каждом старте claude на Windows (прописывает install.ps1).
# 1) быстро: git pull + скиллы/агенты/правила из my-skills (install.sh --local);
# 2) раз в сутки в фоне: полная установка (свежие наборы Anthropic и др.).
# Ошибки не мешают запуску claude: скрипт всегда завершается с кодом 0 и ничего не печатает.
$ErrorActionPreference = 'SilentlyContinue'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = Join-Path $HOME '.claude\.my-skills-full-update'

$git = Get-Command git
if (-not $git) { exit 0 }
$gitRoot = Split-Path (Split-Path $git.Source -Parent) -Parent
$bash = @((Join-Path $gitRoot 'bin\bash.exe'), (Join-Path $gitRoot 'usr\bin\bash.exe'),
          'C:\Program Files\Git\bin\bash.exe') | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $bash) { exit 0 }

$installSh = (Join-Path $repo 'install.sh') -replace '\\', '/'

git -C $repo pull --quiet --ff-only *> $null
& $bash -lc "'$installSh' --local" *> $null

$needFull = -not (Test-Path $stamp) -or ((Get-Item $stamp).LastWriteTime -lt (Get-Date).AddDays(-1))
if ($needFull) {
    New-Item -ItemType File -Force -Path $stamp | Out-Null
    Start-Process -FilePath $bash -ArgumentList @('-lc', "'$installSh'") -WindowStyle Hidden
}
exit 0
