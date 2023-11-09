---
sidebar_position: 2
---

### Intro
The foundation of this library is built upon the best practices recommended by Roblox, as listed here:

# Sharding
https://en.wikipedia.org/wiki/Shard_(database_architecture)
Leaderboard uses a custom sharding solution for MemoryStoreService to reduce the risk of hitting the size limits for a single Memory Map. This is done by splitting the data into multiple Memory Maps, and then using a custom hashing algorithm to determine which Memory Map to use for a given key.

# Exponential Backoff
https://en.wikipedia.org/wiki/Exponential_backoff

# Other

- Custom sharding/partitioning solution for MemoryStoreService to reduce the risk of hitting rate limits
- Abstract API for easy integration into your existing codebase
- Customizable leaderboard settings
- Leaderboard types: Hourly, Daily, Weekly, Monthly, All-Time and Yearly
- Full type support