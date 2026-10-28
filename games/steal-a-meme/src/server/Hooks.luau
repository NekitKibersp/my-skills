-- Игровые события для квестов и статистики: другие сервисы сообщают «что произошло»,
-- а QuestService (и кто угодно ещё) подписывается. Так сервисы не зависят друг от друга.
--   Hooks.Fire(player, "Steal", 1)
--   Hooks.Connect(function(player, stat, amount) ... end)
-- Stat: Buy, Steal, Slap, MonsterHit, Merge, Lock, Earn, Play, Defend (см. Config.Quests).
local Hooks = {}

local listeners: { (Player, string, number) -> () } = {}

function Hooks.Connect(callback: (Player, string, number) -> ())
	table.insert(listeners, callback)
end

function Hooks.Fire(player: Player, stat: string, amount: number?)
	for _, callback in listeners do
		task.spawn(callback, player, stat, amount or 1)
	end
end

return Hooks
