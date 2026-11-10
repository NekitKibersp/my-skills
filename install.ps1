# Установка my-skills на Windows одной командой (PowerShell):
#   irm https://raw.githubusercontent.com/NekitKibersp/my-skills/main/install.ps1 | iex
# или из скачанного репозитория:  powershell -ExecutionPolicy Bypass -File .\install.ps1
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
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { throw 'Не найден git. Установи Git for Windows: https://git-scm.com/download/win' }
    # ...\Git\cmd\git.exe или ...\Git\bin\git.exe -> ...\Git\bin\bash.exe
    $gitRoot = Split-Path (Split-Path $git.Source -Parent) -Parent
    foreach ($c in @((Join-Path $gitRoot 'bin\bash.exe'), (Join-Path $gitRoot 'usr\bin\bash.exe'),
                     'C:\Program Files\Git\bin\bash.exe')) {
        if (Test-Path $c) { return $c }
    }
    throw 'Не найден bash.exe из Git for Windows.'
}

$bash = Find-GitBash

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
& $bash -lc "~/my-skills/install.sh"
if ($LASTEXITCODE -ne 0) { Write-Warning 'install.sh завершился с ошибкой — смотри вывод выше' }

# python-docx и edge-tts (на Windows python обычно называется python, а не python3)
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py -and $py.Source -notlike '*WindowsApps*') {
    & $py.Source -m pip install --quiet python-docx edge-tts
} else {
    Write-Warning 'Python не найден: для титульников и рефератов поставь Python и выполни: pip install python-docx'
}

# 3. Хук автообновления в ~/.claude/settings.json
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
}
$old = @()
if ($settings.hooks.PSObject.Properties['SessionStart']) { $old = @($settings.hooks.SessionStart) }
# убрать прежние записи my-skills, чужие хуки оставить
$kept = @($old | Where-Object {
    -not (@($_.hooks) | Where-Object { $_.command -like '*my-skills*' })
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
