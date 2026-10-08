# moonchess

一个用 [MoonBit](https://moonbitlang.com/) 从零实现的国际象棋库与引擎，接口风格对齐
[chess.js](https://github.com/jhlywa/chess.js)：走法生成与合法性校验、FEN / SAN / PGN、
将杀 / 逼和 / 和棋判定，以及一个带 α-β 剪枝与置换表的 AI 引擎。

## 特性

- **完整走法生成**：兵（含升变、吃过路兵）、马、象、车、后、王的全部合法走法，以及王车易位。
- **合法性校验**：基于 0x88 棋盘表示与攻击检测，过滤掉会让己方王被将军的走法。
- **FEN 读写**：解析与生成标准 FEN，包含走子方、易位权、吃过路兵目标格、半回合计数与回合数。
- **SAN 记谱**：自动消歧、吃子、升变、王车易位，并附加 `+` / `#` 将军标记；支持用 SAN 走子。
- **PGN 读写**：导出七个标签对与走子文本，导入时忽略注释 `{}`、变例 `()`、NAG `$n` 与内联
  回合号，并容忍缺失的 `+` / `#`。
- **对局状态判定**：`is_check`、`is_checkmate`、`is_stalemate`、`is_draw`、
  `is_threefold_repetition`、`is_insufficient_material`、`is_game_over`。
- **撤回走子**：完整撤销栈，支持 `undo`。
- **AI 引擎**：子力价值 + 棋子位置表 + 象对/叠兵评估，negamax + α-β 剪枝，静止搜索
  （quiescence），置换表 / 杀手着法 / 历史启发 + MVV-LVA 走法排序。
- **置换表搜索**：64 位 Zobrist 哈希 + 2^16 项置换表，迭代加深（`Searcher`），支持时间限制。
- **开局库**：内置常见开局线路，按 SAN 历史匹配。
- **棋盘渲染**：`display()` 输出 Unicode / ASCII 棋盘。
- **浏览器演示**：`web/` 用 JS FFI 在浏览器里渲染棋盘、点击走子并调用引擎对战。
- **perft 自检**：内置 perft，对照公开标准用例验证走法生成。

## 项目结构

```
moonchess/
├── moon.mod                  # 模块定义
├── lib/                      # 核心库
│   ├── types.mbt             # Color / PieceType / Piece / Move / 易位标志
│   ├── square.mbt            # 0x88 坐标工具
│   ├── board.mbt             # 棋盘存储与攻击检测
│   ├── game.mbt              # Chess 对象、FEN、走子/撤销、材料/重复判定
│   ├── movegen.mbt           # 走法生成、SAN、对局状态
│   ├── engine.mbt            # 评估函数与 α-β 搜索
│   ├── search.mbt            # Zobrist 哈希、置换表、迭代加深
│   ├── book.mbt              # 开局库
│   ├── pgn.mbt               # PGN 导入导出
│   ├── display.mbt           # 棋盘渲染
│   └── moonchess_wbtest.mbt  # 测试（含 perft 套件）
├── cmd/main/                 # 命令行前端
├── examples/demo/            # 可运行示例
├── web/                      # 浏览器演示（MoonBit + JS FFI）
├── docs/design.md            # 设计说明
└── .github/workflows/        # CI（check / test / fmt / info）
```

## 快速开始

### 构建与测试

```bash
moon check --target native
moon test  --target native
```

### 作为库使用

```moonbit
let game = @lib.Chess::new()
ignore(game.move_by_san("e4"))
ignore(game.move_by_san("e5"))
let m = game.move_by_san("Nf3").unwrap()
println(m.san)          // Nf3
println(game.fen())     // rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2

// 列出全部合法走法
for move in game.moves() {
  println(move.san)
}

// 简单 α-β 搜索
match game.best_move(4) {
  Some(best) => println("best: \{best.san}")
  None => println("game over")
}

// 迭代加深 + 置换表
let searcher = @lib.Searcher::new()
let result = searcher.search(game, 6)
println("depth=\{result.depth} score=\{result.score} nodes=\{result.nodes}")
```

### 命令行

```bash
moon run cmd/main -- board            # 打印棋盘
moon run cmd/main -- perft 4          # perft(4) = 197281
moon run cmd/main -- divide 3         # perft 按首着拆分
moon run cmd/main -- best 4           # 搜索 4 层
moon run cmd/main -- think 6          # 迭代加深 + 置换表
moon run cmd/main -- timed 1500       # 限时 1500ms 搜索
moon run cmd/main -- selfplay 3 20    # 自我对弈（开局用开局库）
moon run cmd/main -- book e4 e5 Nf3   # 查询开局库续着
moon run cmd/main -- validate "<fen>" # FEN 合法性校验
moon run cmd/main -- fen              # 打印当前 FEN
```

### 示例

```bash
moon run examples/demo
```

### 浏览器演示

`web/` 是一个纯 MoonBit 驱动的网页版：棋盘渲染、点击走子、引擎应招都在 MoonBit 里完成，
通过 `extern "js"` 与 DOM 交互。

```bash
# 1. 构建 JS 产物并复制到 web/moonchess.js
powershell -ExecutionPolicy Bypass -File web/build.ps1
# 2. 起一个静态服务器
python -m http.server 8000 --directory web
```

浏览器打开 http://localhost:8000/ ，点击棋子选中，再点击目标格走子，引擎会按所选强度应招。

## 正确性

走法生成通过公开标准 perft 用例验证：

| 局面 | 深度 1 | 深度 2 | 深度 3 | 深度 4 |
|------|-------:|-------:|-------:|-------:|
| 初始局面 | 20 | 400 | 8902 | 197281 |
| Kiwipete | 48 | 2039 | 97862 | — |
| Position 3 | 14 | 191 | 2812 | 43238 |
| Position 4 | 6 | 264 | 9467 | — |
| Position 5 | 44 | 1486 | 62379 | — |
| Position 6 | 46 | 2079 | 89890 | — |

`moon test` 覆盖 FEN、perft、SAN、PGN、王车易位、吃过路兵、升变、撤回、将杀 / 逼和 / 和棋判定、
Zobrist 哈希、引擎与开局库等核心路径。

## 设计说明

数据结构、合法性判定、搜索与置换表的设计取舍见 [docs/design.md](./docs/design.md)。

## 第三方来源与许可

本项目为原创实现，接口设计与部分算法思路参考了
[chess.js](https://github.com/jhlywa/chess.js)（作者 Jeff Hlywa，BSD-2-Clause 许可证）。
未直接复制其源代码；本项目采用 BSD-2-Clause 许可证，详见 [LICENSE](./LICENSE)。

## 许可证

[BSD-2-Clause](./LICENSE)
