# Leaderboard

Leaderboard is an intuitive, open-source module designed to effortlessly establish and manage robust Daily, Weekly, Monthly, and All-Time leaderboards for your Roblox experiences.

### Why not OrderedDataStore?
You should not be using ODS for non persistent data. It should be persistent data. For years there was a workaround to allow people to create Daily/Weekly/Monthly boards with ODS, a very hacky workaround, but now we have MemoryStoreService which is a much better solution for non persistent data. 

Features:
- Custom sharding/partitioning solution for MemoryStoreService to reduce the risk of hitting rate limits
- Abstract API for easy integration into your existing codebase
- Customizable leaderboard settings
- Leaderboard types: Hourly, Daily, Weekly, Monthly, All-Time (Yearly support not recommended for use yet)
- Full type support