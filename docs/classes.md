---
sidebar_position: 4
---

# Classes
Heres a list of all the classes in the library and how they are used within the library.

### <b>Class</b>: `Leaderboard`
The leaderboard class is used to create a leaderboard object. This object is used to interact with the individual boards which are children of the leaderboard.

### <b>Class</b>: `Board`
The board class is used to create a board. This board could etiher be (Hourly, Daily, Weekly, Monthly, Yearly, or All Time). This class interacts with the MemoryShard class to store the data using the `set` and `get` methods.

### <b>Class</b>: `MemoryShard`
The memory shard class is used to store individual MemoryMaps for each board. This is a recommended way as per the [MemoryStores](https://create.roblox.com/docs/cloud-services/memory-stores) page under the `Best practices` tab. If you want to understand how this process works, please refer to the [Sharding](/docs/features#sharding) section of the Features page.