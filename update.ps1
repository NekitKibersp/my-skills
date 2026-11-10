# Запускается хуком SessionStart при каждом старте claude на Windows (прописывает install.ps1).
# 1) быстро: git pull + скиллы/агенты/правила из my-skills (install.sh --local);
# 2) раз в сутки в фоне: полная установка (свежие наборы Anthropic и др.).
# Ошибки не мешают запуску claude: скрипт всегда завершается с кодом 0 и ничего не печатает.
$ErrorActionPreference = 'SilentlyContinue'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = Join-Path $HOME '.claude\.my-skills-full-update'

$git = Get-Command git -CommandType Application | Select-Object -First 1
if (-not $git) { exit 0 }
# git.exe в ...\Git\cmd, ...\Git\bin или ...\Git\mingw64\bin -> ...\Git\bin\bash.exe (как в install.ps1)
$roots = @()
foreach ($d in @($git.Source)) {
    for ($i = 0; $i -lt 4 -and $d; $i++) { $d = Split-Path $d -Parent; if ($d) { $roots += $d } }
}
$roots += @("$env:ProgramFiles\Git", 'C:\Program Files\Git', "$env:LOCALAPPDATA\Programs\Git")
$bash = $roots | ForEach-Object { (Join-Path $_ 'bin\bash.exe'), (Join-Path $_ 'usr\bin\bash.exe') } |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $bash) { exit 0 }

$env:HOME = $HOME                 # тот же ~/.claude, что у Claude Code (%USERPROFILE%)
$env:GIT_TERMINAL_PROMPT = '0'    # git не должен ждать ввода и подвешивать запуск claude
$installSh = ((Join-Path $repo 'install.sh') -replace '\\', '/') -replace "'", "'\''"

git -C $repo pull --quiet --ff-only *> $null
& $bash -lc "'$installSh' --local" *> $null

$needFull = -not (Test-Path $stamp) -or ((Get-Item $stamp).LastWriteTime -lt (Get-Date).AddDays(-1))
if ($needFull) {
    New-Item -ItemType File -Force -Path $stamp | Out-Null
    # Start-Process склеивает аргументы пробелами без кавычек — передаём одну готовую строку
    Start-Process -FilePath $bash -ArgumentList "-lc `"'$installSh'`"" -WindowStyle Hidden
}
exit 0
