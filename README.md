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
- **Impeccable** (`impeccable`: 24 команды `/impeccable audit|critique|polish|animate|…` для дизайна интерфейсов) — свежий, из
  [pbakaus/impeccable](https://github.com/pbakaus/impeccable). При первом запуске скачивает свою программу из релизов
  этого репозитория на GitHub (с проверкой sha256);
- **ElevenLabs** (официальные: `text-to-speech`, `speech-to-text`, `music`, `sound-effects`, `dubbing`, `voice-changer`,
  `voice-isolator`, `agents`, `realtime`, `speech-engine`, `onboarding`, `setup-api-key`) — свежие, из
  [elevenlabs/skills](https://github.com/elevenlabs/skills). Нужен свой ключ `ELEVENLABS_API_KEY`;
- **Remotion** (официальные: `remotion-best-practices`, `remotion-create`, `remotion-render`, `remotion-captions`,
  `remotion-markup`, `remotion-maps` и др.) — свежие, из [remotion-dev/skills](https://github.com/remotion-dev/skills);
- **сторонние скиллы из этого репозитория** (`.claude/skills/`):
  - [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill): `ui-ux-pro-max`, `ui-styling`, `design`, `design-system`, `brand`, `banner-design`, `slides`;
  - [aidea-team/claude-skill-scraper](https://github.com/aidea-team/claude-skill-scraper): `scrape`.
  - [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills): `database-designer`;
  - [haidrrrry/claude-remotion-skill](https://github.com/haidrrrry/claude-remotion-skill): `remotion-motion-graphics`;
  - [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill): `design-taste-frontend` (папка `taste-skill`).
  - [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) (Apache-2.0):
    `game-ai` — ИИ для NPC и врагов (конечные автоматы, деревья поведения, steering, поиск пути A*/navmesh),
    `ai-behavior-trees-utility-ai` — свой движок деревьев поведения и Utility AI,
    Roblox (Luau): `roblox-luau`, `roblox-studio-workflow`, `roblox-characters`, `roblox-ui`, `roblox-physics`,
    `roblox-networking`, `roblox-datastores`;
  - [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) (Apache-2.0): `caveman` — короткие ответы без «воды»
    для экономии токенов, включается `/caveman`, выключается «stop caveman» (взят только сам скилл, без прокси, хуков и облака);
  - [blader/humanizer](https://github.com/blader/humanizer): `humanizer` — убирает признаки «ИИ-текста»;
  - [mvanhorn/last30days-skill](https://github.com/mvanhorn/last30days-skill): `last30days` — что обсуждают о теме за последние 30 дней
    (Reddit, X, YouTube, HN, Polymarket, GitHub и др.; нужен Python 3, часть источников требует своих API-ключей;
    на своём компьютере может брать cookies X из браузера для поиска по X; демо-картинки `assets/` не включены);
  - [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills): маркетинг, `ab-testing`, `ad-creative`, `ads`, `ai-seo`, `analytics`, `aso`, `attribution`, `churn-prevention`, `co-marketing`, `cold-email`, `community-marketing`, `competitor-profiling`, `competitors`, `content-strategy`, `conversion-tracking`, `copy-editing`, `copywriting`, `cro`, `customer-research`, `directory-submissions`, `emails`, `events`, `free-tools`, `image`, `influencer-marketing`, `launch`, `lead-magnets`, `link-building`, `marketing-council`, `marketing-ideas`, `marketing-loops`, `marketing-plan`, `marketing-psychology`, `offers`, `marketing-onboarding`, `paywalls`, `popups`, `pricing`, `product-marketing`, `programmatic-seo`, `prospecting`, `public-relations`, `referrals`, `revops`, `sales-enablement`, `schema`, `seo-audit`, `signup`, `site-architecture`, `sms`, `social`, `video`.
    Скилл `onboarding` переименован в `marketing-onboarding`, чтобы не конфликтовать с `onboarding` от ElevenLabs.

- **свои скиллы:** `ru-voiceover` — русская озвучка видео голосом `ru-RU-DmitryNeural` через edge-tts + ffmpeg
  (`install.sh` ставит `edge-tts` через pip; в облаке нужен доступ к `speech.platform.bing.com`).

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
Сторонние скиллы распространяются под MIT, а скиллы из awesome-gamedev-agent-skills (`game-ai`, `ai-behavior-trees-utility-ai`, `roblox-*`) и `caveman` — под Apache-2.0 (файлы `LICENSE` и `NOTICE` в папке скилла).
Скиллы Anthropic, HyperFrames, Эмиля Ковальски, Impeccable, ElevenLabs и Remotion здесь не хранятся, их лицензии — в исходных репозиториях.

## Скилл `scrape`
Скиллу нужен Python с пакетами `playwright` и `requests`; при первом запуске он сам создаёт
окружение в `~/.claude/venvs/web-scraper`. В облаке сайты, которые нужно разобрать, должны быть
разрешены в настройках сетевого доступа окружения.
