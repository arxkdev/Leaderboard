# Leaderboard
@arxkdev

### What?
Leaderboard is an intuitive, open-source module designed to effortlessly establish and manage robust non-persistent & persistent leaderboards for your Roblox experiences.

### What can I do with this?
- Create leaderboards for your Roblox experiences
- Pick from a variety of leaderboard types such as <b><i>Hourly, Daily, Weekly, Monthly, All-Time and Yearly</i></b>
- Customize your leaderboard settings to your liking
- Use automation to automatically update your leaderboards
- Easily integrate into your existing codebase with the abstract API

### Why not OrderedDataStore?
You should not be using ODS for non persistent data. It should be persistent data. For years there was a workaround to allow people to create Daily/Weekly/Monthly boards with ODS, a very hacky workaround, but now we have MemoryStoreService which is a much better solution for non persistent data. 

### Features:
- Custom sharding/partitioning solution for MemoryStoreService to reduce the risk of hitting rate limits
- Abstract API for easy integration into your existing codebase
- Customizable leaderboard settings
- Leaderboard types: Hourly, Daily, Weekly, Monthly, All-Time and Yearly
- Full type support