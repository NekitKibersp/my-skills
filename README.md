# Мои скиллы для Claude Code

`install.sh` ставит в `~/.claude/skills`:
- **все скиллы Anthropic** — всегда свежие, скачиваются напрямую из [anthropics/skills](https://github.com/anthropics/skills);
- **HyperFrames от HeyGen** (видео из HTML: `hyperframes`, `hyperframes-cli`, `hyperframes-registry`, `media-use`,
  `remotion-to-hyperframes`, `slideshow`, `figma`) — тоже свежие, из [heygen-com/hyperframes](https://github.com/heygen-com/hyperframes).
  Для озвучки/аватаров нужны свои ключи (`HEYGEN_API_KEY`, `GEMINI_API_KEY`, `ELEVENLABS_API_KEY`);
  `media-use` шлёт анонимную статистику в PostHog — отключается `HYPERFRAMES_NO_TELEMETRY=1`;
- **скиллы Эмиля Ковальски** (анимации и UI-полировка: `emil-design-eng`, `animate`, `review-animations`,
  `improve-animations`, `apple-design`, `prototype`, `break-ui`, `pick-ui-library` и др.) — свежие, из
  [emilkowalski/skills](https://github.com/emilkowalski/skills);
- **сторонние скиллы из этого репозитория** (`.claude/skills/`):
  - [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill): `ui-ux-pro-max`, `ui-styling`, `design`, `design-system`, `brand`, `banner-design`, `slides`;
  - [aidea-team/claude-skill-scraper](https://github.com/aidea-team/claude-skill-scraper): `scrape`.
  - [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills): `database-designer`;
  - [haidrrrry/claude-remotion-skill](https://github.com/haidrrrry/claude-remotion-skill): `remotion-motion-graphics`;
  - [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill): `design-taste-frontend` (папка `taste-skill`).

Чтобы добавить свой скилл, положите его папку в `.claude/skills/`.

Ещё `install.sh` записывает в `~/.claude/CLAUDE.md` правила из `user-instructions.md`
(между маркерами `my-skills:begin/end`, остальное содержимое файла не трогает): по ним Claude
в любой сессии сразу добавляет новые скиллы в этот репозиторий.

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
Скиллы Anthropic, HyperFrames и Эмиля Ковальски здесь не хранятся, их лицензии — в исходных репозиториях.

## Скилл `scrape`
Скиллу нужен Python с пакетами `playwright` и `requests`; при первом запуске он сам создаёт
окружение в `~/.claude/venvs/web-scraper`. В облаке сайты, которые нужно разобрать, должны быть
разрешены в настройках сетевого доступа окружения.
