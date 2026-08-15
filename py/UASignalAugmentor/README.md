# UASignalAugmentor (Python)

**⚠️ Partial port — 部分移植，未完成**

本目录是 MATLAB 项目 `matlab/UASignalAugmentor/`（权威实现）的 Python 部分移植。行为冲突时以 MATLAB 实现为准。当前**没有** `main.py`、CLI、`tests/`；请以实际文件为准，不要按任何"计划结构"创建空壳模块。

## 当前实际结构

```
UASignalAugmentor/
├── modules/
│   ├── A1_SignalAnalyzer.py    # A1: 音频频率分析
│   ├── A2_EnvGenerator.py      # A2/A3: BELLHOP 环境文件生成（基于旧版 arr_test 实现）
│   └── B1_DataPreprocess.py    # B1: ETOPO/WOA23 预处理（netCDF → npz）
├── utils/
│   ├── io_utils.py             # JSON/pickle I/O
│   ├── env_processor.py        # ETOPO/WOA 加载、坐标/声速处理
│   └── bellhop_writer.py       # .env/.bty/.ssp/.trc/.brc 写入
├── examples/                   # ★ 当前唯一运行入口
│   ├── example_frequency_analyzer.py
│   ├── example_env_generator.py
│   └── example_data_preprocess.py
├── config/*.json               # 注意：含失效的 Windows G:/ 路径，使用前必须覆盖
├── docs/                       # 设计文档（部分为历史快照，已过时）
├── data/                       # 输出占位目录
└── requirements.txt            # numpy / soundfile / tqdm
```

## 运行方式

```bash
pip install -r requirements.txt
python examples/example_frequency_analyzer.py
```

示例脚本通过 `sys.path.insert(0, project_root)` 后以 `from modules... import` / `from utils... import` 扁平导入（无包安装步骤）。

## 与 MATLAB 权威实现的对齐状态

| 阶段 | 状态 |
|---|---|
| A1 频率分析 | 已移植（`A1_SignalAnalyzer.py`） |
| A2/A3 环境文件生成 | **基于旧版 `matlab/arr_test` 脚本（`A22origin_ENVmake.m` / `A3envfilmade.m`）移植，与当前 MATLAB `A2ENVmaker.m` / `A3ENVDuplicator.m` 尚未 behaviorally aligned**（缺少按频率重算 .trc/.brc 反射系数等） |
| B1 数据预处理 | 已移植（`B1_DataPreprocess.py`） |
| A4/A5 及后续 | 未移植 |

## 已知问题

- `config/*.json` 内含失效 Windows `G:/` 路径，运行前必须修改或覆盖。
- `docs/PROJECT_STATUS.md`、`docs/CONFIG_DESIGN.md`、`modules/COMPLETION_SUMMARY.md` 为阶段性历史快照，其中描述的部分文件（如 `tests/`、`frequency_analyzer.py`）并不存在。

## 历史

转换自 MATLAB 项目 `matlab/arr_test`（现已由 `matlab/UASignalAugmentor` 取代）；转码计划见 `matlab/arr_test/项目总结与Python转码计划.md`。
