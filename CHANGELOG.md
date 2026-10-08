# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/) 风格。

## [Unreleased]

### Added
- 基于 0x88 的棋盘表示与攻击检测。
- 完整合法走法生成：兵（升变、吃过路兵、双步）、马、象、车、后、王、王车易位。
- FEN 解析与生成。
- FEN 合法性校验（`validate_fen` / `is_valid_fen`）。
- SAN 记谱生成与解析（消歧、吃子、升变、易位、`+`/`#`）。
- 对局状态判定：将杀、逼和、和棋、重复局面、子力不足。
- 走子撤回（撤销栈）。
- α-β 搜索引擎：子力 + 棋子位置表 + 象对/叠兵评估、静止搜索、MVV-LVA 走法排序。
- 杀手着法与历史启发走法排序。
- Zobrist 哈希、置换表与迭代加深（`Searcher`）。
- 时间受限的迭代加深（`search_timed`）。
- 开局库（常见开局线路，测试校验每条线路均可合法走完）。
- PGN 导入导出（容忍注释、变例、NAG 与内联回合号）。
- 棋盘渲染：Unicode / ASCII（`display`）。
- 浏览器演示：MoonBit 驱动 DOM 的 JS 网页版（`web/`）。
- 命令行：`board` / `perft` / `divide` / `best` / `think` / `timed` / `selfplay` / `book` /
  `validate` / `fen`。
- 可运行示例：`examples/demo`。
- 覆盖标准 perft 用例（初始局面、Kiwipete、Position 3–6）的测试套件。
- GitHub Actions CI（`moon check` / `moon test` / `moon fmt` / `moon info`）。
