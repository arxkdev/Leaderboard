[![CI](https://github.com/arxkdev/Leaderboard/actions/workflows/ci.yaml/badge.svg)](https://github.com/arxkdev/Leaderboard/actions/workflows/ci.yaml)
[![DocsBuild](https://github.com/arxkdev/Leaderboard/actions/workflows/docs.yaml/badge.svg)](https://github.com/arxkdev/Leaderboard/actions/workflows/docs.yaml)
[![DocsPublish](https://github.com/arxkdev/Leaderboard/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/arxkdev/Leaderboard/actions/workflows/pages/pages-build-deployment)
<!-- DocsPublish should be Release -->


<div align="center">
	<h1>Leaderboard</h1>
	<a href="https://arxk.io/Leaderboard/"><strong>View docs</strong></a>
</div>


## Why you should use Leaderboard

Roblox developers often face challenges when implementing global leaderboards, particularly when dealing with various time periods. This library provides a streamlined solution, enabling you to create global leaderboards with just a few lines of code.

- **Time Period Support**: Leaderboard supports different time periods, including All-Time, Monthly, Weekly, and Daily leaderboards. Additionally, it provides flexibility with a custom rolling time, allowing you to choose how long the leaderboard should display.

- **Simplified Setup**: Streamline the creation of global leaderboards, eliminating the need for complex and time-consuming implementations. The library's design prioritizes ease of use and efficiency.

- **Efficient Memory Management**: Leaderboard leverages MemoryStore to surpass the limitations of OrderedDataStores. It features flexible rate limits and automatic data expiration, eliminating the need to create new stores for each time period.