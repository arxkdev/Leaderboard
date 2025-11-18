return function (s: string): number
    local h = 0x811C9DC5 -- offset basis
    local FNV_PRIME = 0x01000193

    for i = 1, #s do
        h = bit32.bxor(h, string.byte(s, i))
        -- multiply by 0x01000193, mod 2^32
        h = bit32.band(h * FNV_PRIME, 0xFFFFFFFF)
    end

    -- force to unsigned range
    if h < 0 then
        h = h + 0x100000000
    end

    return h
end