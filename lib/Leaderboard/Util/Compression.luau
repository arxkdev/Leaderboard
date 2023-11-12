local Compression = {};
local LOGARITHMIC_BASE = 1.0000001;

-- Not super precise, but it's good enough for our purposes.
function Compression.Compress(x: number): number
	return (x ~= 0 and math.floor(math.log10(x) / math.log10(LOGARITHMIC_BASE)) or 0);
end

function Compression.Decompress(x: number): number
	return (x ~= 0 and math.floor(math.pow(LOGARITHMIC_BASE, x)) or 0);
end

return table.freeze(Compression) :: {
	Compress: (number) -> number,
	Decompress: (number) -> number,
}