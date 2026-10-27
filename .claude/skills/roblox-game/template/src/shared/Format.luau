local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "1.23K", 5600000 -> "5.6M"
function Format.Number(n: number?): string
	local value = math.floor(n or 0)
	if math.abs(value) < 1000 then
		return tostring(value)
	end

	local index = 1
	while math.abs(value) >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end

	local pattern = if math.abs(value) >= 100 then "%.0f" elseif math.abs(value) >= 10 then "%.1f" else "%.2f"
	local text = string.format(pattern, value)
	if string.find(text, ".", 1, true) then
		text = (string.gsub(text, "0+$", ""))
		text = (string.gsub(text, "%.$", ""))
	end
	return text .. SUFFIXES[index]
end

return Format
