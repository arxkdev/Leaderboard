local byte   = string.byte;
local band   = bit32.band;
local bxor   = bit32.bxor;
local lshift = bit32.lshift;

local BASIS = 0x811c9dc5;

return function (s: string): number
    local h = BASIS;
    local len = #s;

    for i = 1, len do
        h = bxor(h, byte(s, i));

        -- 32-bit unsigned multiply by 0x01000193
        local a = lshift(h, 24);
        local b = lshift(h, 8);
        local c = h * 0x93;
        h = band(a + b + c, 0xFFFFFFFF);
    end;

    return h;
end