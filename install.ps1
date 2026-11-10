# Установка my-skills на Windows (PowerShell):
#   git clone https://github.com/NekitKibersp/my-skills $HOME\my-skills
#   powershell -ExecutionPolicy Bypass -File $HOME\my-skills\install.ps1
#
# Что делает:
#   1. скачивает (или обновляет) репозиторий в %USERPROFILE%\my-skills;
#   2. запускает install.sh через Git Bash: скиллы -> ~/.claude/skills, агенты -> ~/.claude/agents,
#      правила -> ~/.claude/CLAUDE.md, pip-зависимости;
#   3. прописывает в ~/.claude/settings.json хук SessionStart: при каждом запуске claude
#      выполняется update.ps1 (git pull + установка новых скиллов). Повторный запуск ничего не дублирует.
# Нужен Git for Windows (он же нужен самому Claude Code): https://git-scm.com/download/win

$ErrorActionPreference = 'Stop'
$repoUrl = 'https://github.com/NekitKibersp/my-skills'
$repo = Join-Path $HOME 'my-skills'
$claudeDir = Join-Path $HOME '.claude'

function Find-GitBash {
    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $git) { throw 'Не найден git. Установи Git for Windows: https://git-scm.com/download/win' }
    # git.exe лежит в ...\Git\cmd, ...\Git\bin или ...\Git\mingw64\bin -> ищем ...\Git\bin\bash.exe выше по дереву;
    # git --exec-path (...\Git\mingw64\libexec\git-core) выручает, если git на PATH — это шим (scoop и т.п.)
    $roots = @()
    $starts = @($git.Source)
    try { $starts += @(& $git.Source --exec-path 2>$null) -replace '/', '\' } catch { }
    foreach ($d in $starts) {
        for ($i = 0; $i -lt 4 -and $d; $i++) { $d = Split-Path $d -Parent; if ($d) { $roots += $d } }
    }
    $roots += @("$env:ProgramFiles\Git", 'C:\Program Files\Git', "$env:LOCALAPPDATA\Programs\Git")
    foreach ($r in $roots) {
        foreach ($c in @((Join-Path $r 'bin\bash.exe'), (Join-Path $r 'usr\bin\bash.exe'))) {
            if (Test-Path -LiteralPath $c) { return $c }
        }
    }
    throw 'Не найден bash.exe из Git for Windows.'
}

$bash = Find-GitBash
# Claude Code ищет ~/.claude в %USERPROFILE%; Git Bash взял бы $HOME из переменной HOME, если она задана иначе
$env:HOME = $HOME
$env:GIT_TERMINAL_PROMPT = '0'

# git, bash и pip пишут в stderr; при 'Stop' Windows PowerShell 5.1 (если вывод перенаправлен) счёл бы это ошибкой.
# Коды возврата проверяем сами через $LASTEXITCODE.
$ErrorActionPreference = 'Continue'

# 1. Репозиторий
if (Test-Path (Join-Path $repo '.git')) {
    Write-Host "Обновляю $repo"
    git -C $repo pull --quiet --ff-only
} else {
    Write-Host "Скачиваю $repoUrl -> $repo"
    git clone --quiet $repoUrl $repo
}
if ($LASTEXITCODE -ne 0) { throw 'git завершился с ошибкой' }

# 2. Установка скиллов, агентов, правил
# Абсолютный путь в одинарных кавычках bash (пробелы, кириллица); внутри не должно быть двойных кавычек,
# иначе PowerShell 5.1 испортит аргумент. bash -l может сменить каталог, поэтому путь абсолютный.
$installSh = ((Join-Path $repo 'install.sh') -replace '\\', '/') -replace "'", "'\''"
& $bash -lc "'$installSh'"
if ($LASTEXITCODE -ne 0) { Write-Warning 'install.sh завершился с ошибкой — смотри вывод выше' }

# python-docx и edge-tts (на Windows python обычно называется python, а не python3)
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py -and $py.Source -notlike '*WindowsApps*') {
    & $py.Source -m pip install --quiet python-docx edge-tts
} else {
    Write-Warning 'Python не найден: для титульников и рефератов поставь Python и выполни: pip install python-docx'
}

# 3. Хук автообновления в ~/.claude/settings.json
$ErrorActionPreference = 'Stop'
# PS 5.1: без этого массив, обёрнутый в PSObject, может записаться как {"value":[...],"Count":N}
if ($PSVersionTable.PSVersion.Major -lt 6) { Remove-TypeData System.Array -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
$settingsPath = Join-Path $claudeDir 'settings.json'
$updateScript = (Join-Path $repo 'update.ps1') -replace '\\', '/'
$hookCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$updateScript`""

$settings = [pscustomobject]@{}
if (Test-Path $settingsPath) {
    $raw = [IO.File]::ReadAllText($settingsPath)
    if ($raw.Trim()) {
        Copy-Item $settingsPath "$settingsPath.bak" -Force
        $settings = $raw | ConvertFrom-Json
    }
}
if (-not $settings.PSObject.Properties['hooks']) {
    $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
} elseif ($null -eq $settings.hooks) {
    $settings.hooks = [pscustomobject]@{}
}
$old = @()
if ($settings.hooks.PSObject.Properties['SessionStart']) { $old = @($settings.hooks.SessionStart) }
# убрать прежние записи my-skills (и null), чужие хуки оставить
$kept = @($old | Where-Object {
    $null -ne $_ -and -not (@($_.hooks) | Where-Object { $_ -and "$($_.command)" -like '*my-skills*' })
})
$entry = [pscustomobject]@{
    hooks = @([pscustomobject]@{ type = 'command'; command = $hookCmd; timeout = 60 })
}
$new = @($kept) + @($entry)
if ($settings.hooks.PSObject.Properties['SessionStart']) {
    $settings.hooks.SessionStart = $new
} else {
    $settings.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue $new
}
$json = ConvertTo-Json -InputObject $settings -Depth 32
[IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Хук автообновления прописан в $settingsPath"
Write-Host 'Готово. Перезапусти claude; дальше новые скиллы из GitHub будут подтягиваться сами.'
