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

  - [obra/superpowers](https://github.com/obra/superpowers) (MIT): процесс разработки — `brainstorming`, `writing-plans`,
    `executing-plans`, `subagent-driven-development`, `dispatching-parallel-agents`, `test-driven-development`,
    `systematic-debugging`, `verification-before-completion`, `using-git-worktrees`, `requesting-code-review`,
    `receiving-code-review`, `finishing-a-development-branch`, `writing-skills`, `using-superpowers`
    (ссылки `superpowers:<имя>` внутри заменены на просто `<имя>`; визуальный режим `brainstorming` грузит логотип
    с primeradiant.com — отключается `SUPERPOWERS_DISABLE_TELEMETRY=1`);
  - [google/skills](https://github.com/google/skills) (Apache-2.0), официальные скиллы Google: `finding-google-skills`,
    `retrieving-developer-knowledge`, `gemini-api`, `firebase-basics`, `cloud-run-basics`, `google-cloud-recipe-onboarding`,
    `google-cloud-recipe-auth`, `google-cloud-storage-basics`, `cloud-sql-basics`, `sign-in-with-google-web`,
    `google-analytics-data-api-basics`, `google-analytics-admin-api-basics` (остальные ~160 — GKE, BigQuery, Ads — не взяты);
  - [google-gemini/gemini-skills](https://github.com/google-gemini/gemini-skills) (Apache-2.0): `gemini-api-dev`,
    `gemini-live-api-dev`, `gemini-omni-flash-api` (нужен `GEMINI_API_KEY`);
  - [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) (MIT): `vercel-react-best-practices`,
    `vercel-composition-patterns`, `web-design-guidelines`;
  - [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) (MIT): `karpathy-guidelines` —
    правила против типичных ошибок LLM в коде;

  - [vercel-labs/skills](https://github.com/vercel-labs/skills) (MIT): `find-skills` — сам ищет подходящий скилл в каталоге skills.sh;
  - [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT): `frontend-ui-engineering`, `api-and-interface-design`,
    `web-performance-optimization` (в оригинале `performance-optimization`, переименован из-за игрового скилла с тем же именем),
    `security-and-hardening`, `observability-and-instrumentation`, `git-workflow-and-versioning`, `documentation-and-adrs`,
    `ci-cd-and-automation`, `shipping-and-launch`, `deprecation-and-migration`, `browser-testing-with-devtools`.
    Не взяты дубли Superpowers: TDD, планирование, отладка, ревью, упрощение кода, проработка идей;
  - [mattpocock/skills](https://github.com/mattpocock/skills) (MIT): `grill-me`, `grilling`, `grill-with-docs`, `handoff`, `teach`,
    `wait-what`, `to-questionnaire`, `writing-for-agents`, `wizard`, `ask-matt`, `retro`, `research`,
    `improve-codebase-architecture`, `wayfinder`, `throwaway-prototype` (в оригинале `prototype`, переименован: `prototype` уже есть
    у Эмиля Ковальски), `pr`, `domain-modeling`, `setup-matt-pocock-skills`, `codebase-design`, `to-tickets`, `implement`,
    `implement-spec`, `to-spec`, `triage`. Не взяты: `tdd` и `diagnosing-bugs` (есть в Superpowers), `code-review` (встроен в Claude Code);
  - [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) (MIT): `diagram-design` — схемы и диаграммы;
  - [zarazhangrui/frontend-slides](https://github.com/zarazhangrui/frontend-slides) (MIT): `frontend-slides` — HTML-презентации с анимациями;
  - [supabase/agent-skills](https://github.com/supabase/agent-skills) (MIT): `supabase`, `supabase-postgres-best-practices`;
  - [prisma/skills](https://github.com/prisma/skills) (MIT): `prisma-orm-setup`, `prisma-client-api`, `prisma-cli`, `prisma-database-setup`,
    `prisma-postgres`, `prisma-postgres-setup`, `prisma-upgrade-v7`;
  - [greensock/gsap-skills](https://github.com/greensock/gsap-skills) (MIT): `gsap-core`, `gsap-timeline`, `gsap-scrolltrigger`,
    `gsap-plugins`, `gsap-utils`, `gsap-react`, `gsap-frameworks`, `gsap-performance`;
  - [huggingface/skills](https://github.com/huggingface/skills) (Apache-2.0): `huggingface-best`, `hf-cli`, `hf-mem`,
    `huggingface-local-models`, `huggingface-spaces`, `huggingface-gradio`, `huggingface-zerogpu`, `huggingface-datasets`,
    `huggingface-llm-trainer`, `trl-training`, `huggingface-vision-trainer`, `transformers-js`, `huggingface-papers`,
    `huggingface-tool-builder`, `huggingface-lora-space-builder` (без AWS SageMaker). Многим нужен свой токен `HF_TOKEN`;
  - [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) (Apache-2.0), остальные
    скиллы набора: `gamedev-router` (в оригинале `router`, сам выбирает нужный скилл по движку), Godot (`godot-*`), Unity (`unity-*`),
    Unreal (`unreal-*`), браузерные движки (`phaser-*`, `pixijs-rendering`, `threejs-*`), `bevy-ecs`, `defold-core`, `love2d-core`,
    `pygame-core`, `ebitengine-game`, общие темы (`game-feel`, `level-design`, `procedural-gen`, `save-systems`, `shader-programming`,
    `camera-systems`, `audio-design`, `dialogue-systems`, `game-ui-ux`, `input-systems`, `physics-tuning`, `performance-optimization`,
    `create-game-assets`), жанры (`platformer`, `roguelike`, `rpg`, `fps-shooter`, `tower-defense`, `card-game`, `visual-novel`,
    `survival-crafting`, `puzzle`) и выпуск игры (`game-jam`, `prototype-fast`, `steam-publish`, `itch-publish`);

- **свои скиллы:**
  - `ru-voiceover` — русская озвучка видео голосом `ru-RU-DmitryNeural` через edge-tts + ffmpeg
    (`install.sh` ставит `edge-tts` через pip; в облаке нужен доступ к `speech.platform.bing.com`);
  - `roblox-game` — целый режим для Roblox (симулятор, обби, тайкун, PvP-арена, tower defense, хоррор) как Rojo-проект
    + готовый `.rbxlx`: шаблон (сохранение, Remotes, UI-набор), рецепты жанров, пример «Симулятор кристаллов»,
    скрипты `setup.sh` (rojo + selene), `new-project.sh`, `check.sh`;
  - `roblox-monetization` — геймпассы и Developer Products с правильным `ProcessReceipt`;
  - `agent-team` — как раздавать задачи субагентам и запускать их параллельно.
  - `prompt-enhancer` — превращает короткую идею в подробный промпт: для Claude, картинок (Midjourney, Nano Banana,
    GPT Image, Flux), видео (Sora, Veo, Kling), музыки и голоса (Suno, ElevenLabs) и других чат-ботов (ChatGPT, Gemini).
- **субагенты** (`.claude/agents/` → `~/.claude/agents/`): 53 из
  [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) (MIT, `LICENSE-VoltAgent`),
  `unity-developer` из [wshobson/agents](https://github.com/wshobson/agents) (MIT, `LICENSE-wshobson`) и свои:
  `roblox-developer`, `telegram-bot-developer` (боты на aiogram 3, платежи Stars), `academic-writer` (курсовые и рефераты
  по методичке и ГОСТ), `presentation-designer` (презентация целиком). Кому что поручать — в скилле `agent-team`.

Чтобы добавить свой скилл, положите его папку в `.claude/skills/`.

Ещё `install.sh` записывает в `~/.claude/CLAUDE.md` правила из `user-instructions.md`
(между маркерами `my-skills:begin/end`, остальное содержимое файла не трогает). По ним Claude
в любой сессии сам кладёт в этот репозиторий (сразу в `main`) новые скиллы, субагентов и правила,
которым его научили («запомни…», «всегда делай…»); правила копятся в разделе «Правила пользователя».

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
Сторонние скиллы распространяются под MIT, а скиллы из awesome-gamedev-agent-skills (`game-ai`, `ai-behavior-trees-utility-ai`, `roblox-*` кроме `roblox-game` и `roblox-monetization`), `caveman`, скиллы Google, Gemini и Hugging Face — под Apache-2.0. Агенты VoltAgent — MIT (`.claude/agents/LICENSE-VoltAgent`) (файлы `LICENSE` и `NOTICE` в папке скилла).
Скиллы Anthropic, HyperFrames, Эмиля Ковальски, Impeccable, ElevenLabs и Remotion здесь не хранятся, их лицензии — в исходных репозиториях.

## Скилл `scrape`
Скиллу нужен Python с пакетами `playwright` и `requests`; при первом запуске он сам создаёт
окружение в `~/.claude/venvs/web-scraper`. В облаке сайты, которые нужно разобрать, должны быть
разрешены в настройках сетевого доступа окружения.
