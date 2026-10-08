# moonchess

一个用 [MoonBit](https://moonbitlang.com/) 从零实现的国际象棋库与引擎，接口风格对齐
[chess.js](https://github.com/jhlywa/chess.js)：走法生成与合法性校验、FEN / SAN / PGN、
将杀 / 逼和 / 和棋判定，以及一个带 α-β 剪枝的 AI 引擎。

## 特性

- **完整走法生成**：兵（含升变、吃过路兵）、马、象、车、后、王的全部合法走法，以及王车易位。
- **合法性校验**：基于 0x88 棋盘表示与攻击检测，过滤掉会让己方王被将军的走法。
- **FEN 读写**：解析与生成标准 FEN，包含走子方、易位权、吃过路兵目标格、半回合计数与回合数。
- **SAN 记谱**：自动消歧、吃子、升变、王车易位，并附加 `+` / `#` 将军标记；支持用 SAN 走子。
- **对局状态判定**：`is_check`、`is_checkmate`、`is_stalemate`、`is_draw`、
  `is_threefold_repetition`、`is_insufficient_material`、`is_game_over`。
- **撤回走子**：完整撤销栈，支持 `undo`。
- **AI 引擎**：子力价值 + 棋子位置表评估，negamax + α-β 剪枝，静止搜索（quiescence），
  走法排序（MVV-LVA）。
- **perft 自检**：内置 perft，用于验证走法生成的正确性。

## 项目结构

```
moonchess/
├── moon.mod                 # 模块定义
├── lib/                     # 核心库
│   ├── types.mbt            # Color / PieceType / Piece / Move / 易位标志
│   ├── square.mbt           # 0x88 坐标工具
│   ├── board.mbt            # 棋盘存储与攻击检测
│   ├── game.mbt             # Chess 对象、FEN、走子/撤销、材料/重复判定
│   ├── movegen.mbt          # 走法生成、SAN、对局状态
│   ├── engine.mbt           # 评估函数与 α-β 搜索
│   └── moonchess_wbtest.mbt # 白盒测试（含 perft）
├── cmd/main/                # 命令行前端
└── .github/workflows/       # CI（check / test / fmt / info）
```

## 快速开始

### 构建与测试

```bash
moon check --target all
moon test  --target all
```

### 作为库使用

```moonbit
// 从初始局面开始
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

// 用引擎搜索最佳走法
match game.best_move(4) {
  Some(best) => println("best: \{best.san}")
  None => println("game over")
}
```

### 命令行

```bash
moon run cmd/main -- perft 4          # perft(4) = 197281
moon run cmd/main -- best 4           # 搜索 4 层并打印最佳走法
moon run cmd/main -- selfplay 3 20    # 自我对弈 20 步，输出 SAN
moon run cmd/main -- fen             # 打印当前 FEN
```

## 正确性

走法生成通过标准 perft 用例验证：

| 局面 | 深度 1 | 深度 2 | 深度 3 | 深度 4 |
|------|-------:|-------:|-------:|-------:|
| 初始局面 | 20 | 400 | 8902 | 197281 |
| Kiwipete | 48 | 2039 | 97862 | — |

`moon test` 覆盖 FEN 往返、perft、SAN、王车易位、吃过路兵、升变、撤回、和棋判定等核心路径。

## 第三方来源与许可

本项目为原创实现，接口设计与部分算法思路参考了
[chess.js](https://github.com/jhlywa/chess.js)（作者 Jeff Hlywa，BSD-2-Clause 许可证）。
未直接复制其源代码；本项目采用 BSD-2-Clause 许可证，详见 [LICENSE](./LICENSE)。

## 许可证

[BSD-2-Clause](./LICENSE)
