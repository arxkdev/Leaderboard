"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[738],{53448:e=>{e.exports=JSON.parse('{"functions":[{"name":"new","desc":"Creates a new board within the Leaderboard.","params":[{"name":"serviceKey","desc":"","lua_type":"string"},{"name":"leaderboardType","desc":"","lua_type":"LeaderboardType"},{"name":"rollingExpiry","desc":"","lua_type":"number?"}],"returns":[{"desc":"","lua_type":"Board"}],"function_type":"static","source":{"line":181,"path":"lib/Leaderboard/Board/init.luau"}},{"name":"Get","desc":"Gets the top data for a specific board.","params":[{"name":"amount","desc":"","lua_type":"number"},{"name":"sortDirection","desc":"","lua_type":"string?"}],"returns":[{"desc":"","lua_type":"Promise.TypedPromise<{TopData}>"}],"function_type":"method","yields":true,"source":{"line":223,"path":"lib/Leaderboard/Board/init.luau"}},{"name":"Update","desc":"Updates the data for a specific board (either MemoryStore (Shards), or OrderedDataStore).","params":[{"name":"userId","desc":"","lua_type":"number"},{"name":"value","desc":"","lua_type":"number | (number) -> (number)"}],"returns":[{"desc":"","lua_type":"boolean"}],"function_type":"method","yields":true,"source":{"line":263,"path":"lib/Leaderboard/Board/init.luau"}},{"name":"Destroy","desc":"Destroys the board.","params":[],"returns":[],"function_type":"method","source":{"line":297,"path":"lib/Leaderboard/Board/init.luau"}}],"properties":[],"types":[{"name":"LeaderboardType","desc":"","lua_type":"\\"Hourly\\" | \\"Daily\\" | \\"Weekly\\" | \\"Monthly\\" | \\"Yearly\\" | \\"AllTime\\" | \\"Rolling\\"","source":{"line":35,"path":"lib/Leaderboard/Board/init.luau"}},{"name":"Board","desc":"","lua_type":"() -> Board","source":{"line":41,"path":"lib/Leaderboard/Board/init.luau"}},{"name":"BoardArguments","desc":"","fields":[{"name":"__serviceKey","lua_type":"string","desc":""},{"name":"__type","lua_type":"LeaderboardType","desc":""},{"name":"__storeUsing","lua_type":"string","desc":""},{"name":"__store","lua_type":"MemoryStoreSortedMap | OrderedDataStore | MemoryShard","desc":""},{"name":"__threads","lua_type":"{thread}","desc":""}],"source":{"line":52,"path":"lib/Leaderboard/Board/init.luau"}},{"name":"TopData","desc":"","fields":[{"name":"Rank","lua_type":"number","desc":""},{"name":"UserId","lua_type":"number","desc":""},{"name":"Value","lua_type":"number","desc":""},{"name":"Username","lua_type":"string","desc":""},{"name":"DisplayName","lua_type":"string","desc":""}],"source":{"line":69,"path":"lib/Leaderboard/Board/init.luau"}},{"name":"Object","desc":"","fields":[{"name":"__index","lua_type":"Object","desc":""},{"name":"Update","lua_type":"(self: Board, userId: number, value: number | (number) -> (number)) -> Promise.TypedPromise<boolean>","desc":""},{"name":"Get","lua_type":"(self: Board, amount: number, sortDirection: string) -> Promise.TypedPromise<{TopData}>","desc":""},{"name":"Destroy","lua_type":"(self: Board) -> ()","desc":""},{"name":"new","lua_type":"(serviceKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?) -> Board","desc":""}],"source":{"line":88,"path":"lib/Leaderboard/Board/init.luau"}}],"name":"Board","desc":"This class is used to create a new leaderboard board.","source":{"line":104,"path":"lib/Leaderboard/Board/init.luau"}}')}}]);