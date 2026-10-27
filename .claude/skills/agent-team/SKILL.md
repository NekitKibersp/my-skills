---
name: agent-team
description: "Split a big task across specialized subagents and run independent parts in parallel instead of doing everything alone. Use when the user asks to use agents, work as a team or in parallel (\"используй агентов\", \"работай командой\", \"распараллель\"), or names one of the installed agents (backend-developer, code-reviewer, debugger, roblox-developer, research-analyst...). Explains which agent fits which job, how to brief them and how to merge their results."
user-invocable: true
argument-hint: "[задача]"
---

# Команда агентов

Субагенты запускаются через инструмент **Agent** (`subagent_type` = имя агента). Каждый стартует
с нуля и видит только твой промпт, поэтому дорог: запускай их, когда пользователь просит или
когда задача действительно делится на независимые куски. Мелочь делай сам.

## Кто есть в команде

Агенты лежат в `~/.claude/agents/` (ставит `install.sh`). Если нужного нет — `general-purpose`.

| Задача | Агент |
|---|---|
| Серверная часть, API, БД | `backend-developer` |
| Интерфейс, React/Vue | `frontend-developer`, `ui-designer` |
| Фича целиком (фронт+бэк) | `fullstack-developer` |
| Мобильное приложение | `mobile-developer` |
| Python / TypeScript глубоко | `python-pro`, `typescript-pro` |
| Roblox (Luau, Rojo) | `roblox-developer` |
| Другие игры (Unity, Godot, механики) | `game-developer` |
| CI/CD, Docker, деплой | `devops-engineer` |
| Ревью кода | `code-reviewer`, `architect-reviewer` |
| Баг, падение, странное поведение | `debugger` |
| Тесты | `test-automator` |
| Безопасность | `security-auditor` |
| Тормоза | `performance-engineer` |
| Рефакторинг | `refactoring-specialist` |
| Документация, README | `documentation-engineer` |
| Промпты для LLM | `prompt-engineer` |
| Поиск информации, сравнение вариантов | `research-analyst`, `search-specialist` |
| Требования, приоритеты, план продукта | `product-manager` |
| Разбить огромную задачу и раздать | `multi-agent-coordinator`, `task-distributor` |

## Как работать

1. **Разбей задачу** на части с понятным результатом. Независимые части (разные файлы/модули,
   разные вопросы исследования) — параллельно: несколько вызовов Agent в одном сообщении.
   Зависимые — по очереди, результат первого вставь в промпт второго.
2. **Не давай двум агентам править одни и те же файлы одновременно.** Если надо —
   `isolation: "worktree"` у каждого, потом сведи изменения сам.
3. **Бриф для агента** (он не видит переписку):
   - цель и зачем она нужна;
   - путь к проекту и конкретные файлы;
   - решения, уже принятые с пользователем, и ограничения (стиль, язык, что не трогать);
   - что считать готовым и как проверить (команда тестов/сборки);
   - что вернуть: список изменённых файлов, результат проверки, открытые вопросы.
4. **Проверь результат сам.** Отчёт агента — это заявление, а не факт: посмотри diff, запусти
   проверки. Ошибки агента исправь или отправь ему же через SendMessage с конкретикой.
5. **Финальное ревью:** после крупной реализации запусти `code-reviewer` (или `security-auditor`
   для кода с деньгами/доступом) на итоговый diff.
6. **Пользователю** — сводка: кто что сделал, что проверено, что осталось. Отчёты агентов
   пользователь не видит, пересказывай важное.

## Типовые составы

- **Новая фича:** `product-manager` (если требования размыты) → `backend-developer` ∥ `frontend-developer` → `test-automator` → `code-reviewer`.
- **Баг:** `debugger` находит причину → исправляешь сам или тот же агент → `test-automator` добавляет регрессионный тест.
- **Исследование:** 2–4 `research-analyst` по разным вопросам параллельно → сводишь в один ответ.
- **Roblox-игра:** план и Config — сам (скилл roblox-game) → `roblox-developer` на каждую систему (магазин, раунды, карта) параллельно, каждый в своих файлах → сборка `check.sh` → `code-reviewer` на защиту remotes.

Для дисциплинированного процесса с планом и TDD смотри также скиллы Superpowers:
`writing-plans`, `subagent-driven-development`, `dispatching-parallel-agents`.
