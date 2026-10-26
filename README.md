# Мои скиллы для Claude Code

Собрано из:
- [anthropics/skills](https://github.com/anthropics/skills)
- [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)
- [aidea-team/claude-skill-scraper](https://github.com/aidea-team/claude-skill-scraper) (скилл `scrape`)

Все скиллы лежат в `.claude/skills/`.

## Как сделать, чтобы скиллы подключались сами

### 1. Облачные сессии (claude.ai/code), для любых проектов
В настройках облачного окружения (меню окружения в заголовке сессии → Edit):
- в **Repositories** добавьте этот репозиторий (если он приватный);
- в **Setup script** вставьте:
  ```bash
  git clone --depth 1 https://github.com/<ваш-логин>/claude-skills /tmp/claude-skills && /tmp/claude-skills/install.sh
  ```
Теперь в каждой новой сессии этого окружения скиллы установятся автоматически, какой бы проект вы ни открыли.

### 2. Свой компьютер, один раз для всех проектов
```bash
git clone https://github.com/<ваш-логин>/claude-skills
cd claude-skills && ./install.sh
```
Скиллы попадут в `~/.claude/skills/` и будут доступны во всех проектах.
Обновить: `git pull && ./install.sh`.

### 3. Шаблон для новых проектов
В настройках репозитория на GitHub включите **Template repository**.
Новые проекты создавайте кнопкой **Use this template**: папка `.claude/skills` окажется внутри проекта.

## Лицензии
Скиллы в этом репозитории распространяются под Apache 2.0 или MIT (файл `LICENSE` в папке скилла).
Скиллы `docx`, `pdf`, `pptx`, `xlsx` от Anthropic проприетарные, поэтому в репозитории их нет:
`install.sh` скачивает их напрямую из [anthropics/skills](https://github.com/anthropics/skills).

## Скилл `scrape`
Скиллу нужен Python с пакетами `playwright` и `requests`; при первом запуске он сам создаёт
окружение в `~/.claude/venvs/web-scraper`. В облаке сайты, которые нужно разобрать, должны быть
разрешены в настройках сетевого доступа окружения.
