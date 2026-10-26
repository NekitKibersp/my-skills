# Мои скиллы для Claude Code

`install.sh` ставит в `~/.claude/skills`:
- **все скиллы Anthropic** — всегда свежие, скачиваются напрямую из [anthropics/skills](https://github.com/anthropics/skills);
- **сторонние скиллы из этого репозитория** (`.claude/skills/`):
  - [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill): `ui-ux-pro-max`, `ui-styling`, `design`, `design-system`, `brand`, `banner-design`, `slides`;
  - [aidea-team/claude-skill-scraper](https://github.com/aidea-team/claude-skill-scraper): `scrape`.
  - [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills): `database-designer`.

Чтобы добавить свой скилл, положите его папку в `.claude/skills/`.

## Как сделать, чтобы скиллы подключались сами

### 1. Облачные сессии (claude.ai/code), для любых проектов
В настройках облачного окружения (⚙ рядом со средой) в **Скрипт настройки** вставьте:
  ```bash
  git clone --depth 1 https://github.com/NekitKibersp/my-skills /tmp/my-skills && /tmp/my-skills/install.sh
  ```
Теперь в каждой новой сессии этого окружения скиллы установятся автоматически, какой бы проект вы ни открыли.

### 2. Свой компьютер, один раз для всех проектов
```bash
git clone https://github.com/NekitKibersp/my-skills
cd my-skills && ./install.sh
```
Скиллы попадут в `~/.claude/skills/` и будут доступны во всех проектах.
Обновить: `git pull && ./install.sh`.

### 3. Шаблон для новых проектов
В настройках репозитория на GitHub включите **Template repository**.
Новые проекты создавайте кнопкой **Use this template**: папка `.claude/skills` со сторонними скиллами
окажется внутри проекта (скиллы Anthropic при этом ставятся только через `install.sh`).

## Лицензии
Сторонние скиллы распространяются под MIT (файл `LICENSE` в папке скилла).
Скиллы Anthropic здесь не хранятся, их лицензии — в [anthropics/skills](https://github.com/anthropics/skills).

## Скилл `scrape`
Скиллу нужен Python с пакетами `playwright` и `requests`; при первом запуске он сам создаёт
окружение в `~/.claude/venvs/web-scraper`. В облаке сайты, которые нужно разобрать, должны быть
разрешены в настройках сетевого доступа окружения.
