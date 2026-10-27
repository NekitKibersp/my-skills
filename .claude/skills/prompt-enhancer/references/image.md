# Промпт для генерации картинок

Пиши на английском. Описывай сцену связными фразами, как описание фотографии/иллюстрации,
а не набором тегов через запятую (современные модели понимают предложения лучше).

## Порядок элементов
1. **Тип изображения и стиль** — photo, cinematic still, 3D render, anime illustration, watercolor,
   pixel art, flat vector logo, isometric, oil painting…
2. **Главный объект** — кто/что, внешность, одежда, материал, эмоция, поза, действие.
3. **Окружение** — где, что вокруг, время суток, погода.
4. **Композиция и камера** — close-up / medium shot / wide shot, ракурс (low angle, top-down),
   объектив для фото (35mm, 85mm portrait, macro), глубина резкости.
5. **Свет и цвет** — golden hour, soft studio light, neon rim light, volumetric fog; палитра.
6. **Настроение и детализация** — epic, cozy, eerie; highly detailed / minimal.
7. **Текст на картинке** — точная надпись в кавычках и где она: `the title "SAMURAI CAT" in bold brush lettering at the top`.

## Особенности сервисов
- **Midjourney:** параметры в конце строки: `--ar 16:9` (соотношение сторон), `--no text, watermark`
  (чего не должно быть), `--style raw` (меньше «украшательства»), `--stylize`/`--s` (сила стиля),
  `--chaos` (разнообразие вариантов). Версию модели (`--v`) не указывай, если пользователь не просил —
  по умолчанию стоит актуальная.
- **Nano Banana / Gemini, GPT Image (ChatGPT):** хорошо понимают длинные описания на естественном языке и
  точный текст на картинке; умеют **редактировать** присланное фото — тогда пиши, что изменить и что
  оставить как есть («keep the face and pose unchanged, change only the background to…»).
  Соотношение сторон — словами в промпте («vertical 9:16 image») или в настройках.
- **Flux, Stable Diffusion:** отдельное поле **negative prompt** — туда то, чего не должно быть
  (`blurry, extra fingers, deformed hands, watermark, text`).
- **Ideogram:** силён в надписях и логотипах — текст всегда в кавычках.

Если сервис не назван — пиши универсальный промпт на естественном языке и отдельно строку
с параметрами для Midjourney.

## Типовые задачи
- **Логотип:** flat vector logo, simple geometric shapes, 2–3 colors, white background, centered,
  no gradients, scalable, + что изображено и название в кавычках.
- **Аватарка / персонаж:** стиль, портрет по грудь, взгляд в камеру, однотонный или размытый фон.
- **Обложка / превью YouTube:** 16:9, крупный объект, яркий контраст, место под заголовок.
- **Иконки для игры/приложения:** единый стиль, одинаковый ракурс и свет, прозрачный/однотонный фон.

## Пример
Было: «кот-самурай»
Стало:
```
Cinematic digital painting of a battle-worn samurai cat standing on a misty bamboo-forest path at dawn.
The cat is a gray tabby with a scar over one eye, wearing weathered red lacquered armor and holding a
katana low at its side, calm and focused expression. Soft golden morning light breaks through the fog,
falling cherry petals drift in the air. Low-angle medium shot, shallow depth of field, rich muted
colors with red accents, highly detailed fur and armor textures, epic and quiet mood.
```
Midjourney: `... --ar 3:4 --no text, watermark`
