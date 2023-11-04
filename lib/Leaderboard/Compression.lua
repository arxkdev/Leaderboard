local Compression = {};

local function CompressedNumber(hugeNumber: number): number
	return hugeNumber ~= 0 and math.floor(math.log(hugeNumber) / math.log(1.0000001)) or 0;
end

local function DecompressedNumber(stored: number): number
	return math.floor(stored ~= 0 and (1.0000001 ^ stored) or 0)
end

function Compression.Compress(num: number): number
	return CompressedNumber(num);
end

function Compression.Decompress(stored: number): number
	return DecompressedNumber(stored);
end

return Compression;