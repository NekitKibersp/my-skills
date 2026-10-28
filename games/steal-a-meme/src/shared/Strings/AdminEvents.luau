-- Тексты админ-ивентов (уведомления сервера). Ключи AdminEventStart_<Id> / AdminEventEnd_<Id>
-- собираются из Config.AdminEvents.Types, чтобы название ивента было на языке игрока.
local Config = require(script.Parent.Parent.Config)

local strings: { [string]: { string } } = {
	AdminEventUnknown = { "Unknown event: {Name}", "Нет такого ивента: {Name}" },
}

for _, event in Config.AdminEvents.Types do
	strings["AdminEventStart_" .. event.Id] = {
		event.Face .. " " .. event.Name .. "! " .. event.Desc,
		event.Face .. " " .. event.NameRu .. "! " .. event.DescRu,
	}
	strings["AdminEventEnd_" .. event.Id] = {
		event.Name .. " is over",
		event.NameRu .. " — ивент закончился",
	}
end

return strings
