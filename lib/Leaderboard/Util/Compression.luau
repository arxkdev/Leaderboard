local Compression = {};
local LOGARITHMIC_BASE = 1.0000001;

-- Not super precise, but it's good enough for our purposes.
function Compression.Compress(num: number): number
	return (num ~= 0 and math.floor(math.log10(num) / math.log10(LOGARITHMIC_BASE)) or 0);
end

function Compression.Decompress(num: number): number
	return (num ~= 0 and math.floor(math.pow(LOGARITHMIC_BASE, num)) or 0);
end

return table.freeze(Compression);