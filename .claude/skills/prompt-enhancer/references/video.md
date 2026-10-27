# Промпт для генерации видео (Sora, Veo, Kling, Runway и др.)

Пиши на английском. Видео-модели — «режиссёры»: описывай не картинку, а **что происходит во времени**
и **как движется камера**.

## Каркас одного клипа
1. **Стиль/формат** — cinematic live-action, 3D animation (Pixar-like), anime, documentary handheld,
   stop-motion; соотношение сторон (16:9 для YouTube, 9:16 для Shorts/Reels/TikTok).
2. **Сцена** — место, время, погода, атмосфера.
3. **Объект и действие** — кто и что ДЕЛАЕТ, по порядку: «turns around, then starts running toward…».
   Одно-два действия на клип 5–10 секунд; больше — модель путается.
4. **Камера** — static shot, slow dolly-in, tracking shot following the character, drone aerial pull-back,
   handheld, orbit around; крупность (close-up / wide).
5. **Свет и цвет** — как для картинок.
6. **Звук** (если модель генерирует звук, например Veo) — фоновые звуки, музыка, реплики в кавычках с указанием,
   кто говорит: `the old man says: "We are late."`
7. **Длительность** — если сервис позволяет задать.

## Несколько сцен
Если нужен ролик из нескольких кадров — разбей на **отдельные промпты по сценам** (Shot 1, Shot 2…),
повторяя в каждом описание персонажа одинаковыми словами, чтобы он выглядел одинаково.
Если сервис поддерживает референс-картинку персонажа — посоветуй сначала сделать её (см. image.md).

## Чего избегать
- длинных текстов на экране (модели плохо пишут буквы в видео) — надписи лучше добавить при монтаже;
- слишком быстрых сложных движений и толп;
- противоречий «ночь» + «яркое солнце».

## Пример
Было: «видео как кот-самурай сражается»
Стало:
```
Cinematic live-action style, 16:9, 8 seconds. A misty bamboo forest at dawn. A gray tabby samurai cat
in red lacquered armor stands still, then draws its katana in one swift motion as falling leaves swirl
around it. The camera starts with a slow dolly-in on the cat's eyes, then cuts to a low-angle wide shot
as it leaps forward. Soft golden backlight through fog, muted colors with red accents. Sound: wind through
bamboo, the sharp ring of the blade being drawn, distant taiko drum.
```
