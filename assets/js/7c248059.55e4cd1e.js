"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[386],{53448:e=>{e.exports=JSON.parse('{"functions":[{"name":"new","desc":"Creates a new board within the Leaderboard.","params":[{"name":"serviceKey","desc":"","lua_type":"string"},{"name":"leaderboardType","desc":"","lua_type":"LeaderboardType"},{"name":"rollingExpiry","desc":"","lua_type":"number?"}],"returns":[],"function_type":"static","source":{"line":186,"path":"lib/Leaderboard/Board.luau"}},{"name":"Get","desc":"Gets the top data for a specific board.","params":[{"name":"amount","desc":"","lua_type":"number"},{"name":"sortDirection","desc":"","lua_type":"string?"}],"returns":[],"function_type":"method","source":{"line":226,"path":"lib/Leaderboard/Board.luau"}},{"name":"Update","desc":"Updates the data for a specific board (either MemoryStore (Shards), or OrderedDataStore).","params":[{"name":"userId","desc":"","lua_type":"number"},{"name":"value","desc":"","lua_type":"number | (number) -> (number)"}],"returns":[],"function_type":"method","source":{"line":263,"path":"lib/Leaderboard/Board.luau"}},{"name":"Destroy","desc":"Destroys the board.","params":[],"returns":[],"function_type":"method","source":{"line":304,"path":"lib/Leaderboard/Board.luau"}}],"properties":[],"types":[{"name":"LeaderboardType","desc":"","lua_type":"\\"Hourly\\" | \\"Daily\\" | \\"Weekly\\" | \\"Monthly\\" | \\"Yearly\\" | \\"AllTime\\" | \\"Rolling\\"","source":{"line":29,"path":"lib/Leaderboard/Board.luau"}},{"name":"Board","desc":"","lua_type":"() -> Board","source":{"line":35,"path":"lib/Leaderboard/Board.luau"}},{"name":"BoardArguments","desc":"","fields":[{"name":"__serviceKey","lua_type":"string","desc":""},{"name":"__type","lua_type":"LeaderboardType","desc":""},{"name":"__storeUsing","lua_type":"string","desc":""},{"name":"__store","lua_type":"MemoryStoreSortedMap | OrderedDataStore | MemoryShard","desc":""},{"name":"__threads","lua_type":"{thread}","desc":""}],"source":{"line":46,"path":"lib/Leaderboard/Board.luau"}},{"name":"TopData","desc":"","fields":[{"name":"Rank","lua_type":"number","desc":""},{"name":"UserId","lua_type":"number","desc":""},{"name":"Value","lua_type":"number","desc":""},{"name":"Username","lua_type":"string","desc":""},{"name":"DisplayName","lua_type":"string","desc":""}],"source":{"line":63,"path":"lib/Leaderboard/Board.luau"}},{"name":"Object","desc":"","fields":[{"name":"__index","lua_type":"Object","desc":""},{"name":"Update","lua_type":"(self: Board, userId: number, value: number | (number) -> (number)) -> boolean","desc":""},{"name":"Get","lua_type":"(self: Board, amount: number, sortDirection: string) -> Promise.TypedPromise<{TopData}>","desc":""},{"name":"Destroy","lua_type":"(self: Board) -> ()","desc":""},{"name":"new","lua_type":"(serviceKey: string, leaderboardType: LeaderboardType, rollingExpiry: number?) -> Board","desc":""}],"source":{"line":82,"path":"lib/Leaderboard/Board.luau"}}],"name":"Board","desc":"This class is used to create a new leaderboard board.","source":{"line":98,"path":"lib/Leaderboard/Board.luau"}}')}}]);