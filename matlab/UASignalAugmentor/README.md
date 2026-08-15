# UASignalAugmentor（MATLAB，权威实现）

端到端水声信号合成与增强系统：真实舰船音频 → 频率提取 → 真实海洋环境（ETOPO2022 + WOA23）BELLHOP 声场计算 → 多径接收信号合成。

> Python 部分移植见 `py/UASignalAugmentor/`（未完成，行为以本目录为准）。

## 从哪里开始运行（执行顺序）

| 步骤 | 脚本（本目录顶层） | 作用 | 输出 |
|---|---|---|---|
| 0 | `ConfigMaker.m` | 站点/声源/计算参数 → 配置（**手改脚本内 `ZoneName` 切换海域**） | `data/OriginEnvPack/Config{Zone}.mat` |
| 1 | `A1WavTransformer.m` | wav 频率成分提取与阈值筛选 | `data/processed/{Class}_*.mat`、`Analy_freq_all.mat` |
| 2 | `A2ENVmaker.m` | 批量生成 BELLHOP 环境模板（**手改 `ConfigName`**） | `data/OriginEnvPack/{Zone}/ENVn/Rrn/EnvTemplate/ENV_*.{env,bty,ssp,trc,brc}` |
| 3 | `A3ENVDuplicator.m` | 按频率复制环境文件（重算 .trc/.brc） | `EnvTemplate/test_*.五件套` + `env_files_list.txt` + tar 包 |
| — | **CallBell**（外部二进制，见下） | 并行运行 BELLHOP | 每频率一个 `.arr` |
| 4 | `A4ArrProcessor.m` | 解析 .arr → 压缩到达结构 | `Rrn/ENV_ARR_less.mat` |
| 5 | `A5RecSigSynthesizer.m` | 合成接收信号 | `Rrn/NewSig/{signal}_Rd_{depth}_new.mat` |

## CallBell 运行方式（BELLHOP 并行计算）

```bash
cd matlab/UASignalAugmentor/CallBell/mac        # 或 win/ lin/
./BellParallelMac <含 env_files_list.txt 的目录绝对路径>
```

约定：`bellhop.exe` 与 `BellParallelMac` 同目录（经二进制自身 cwd 定位，macOS/Linux 下可执行文件仍名为 `bellhop.exe`）。详见 `CallBell/命令.txt`。**不要移动/改名 CallBell/。**

## ⚠️ 运行前提：MATLAB Desktop active-editor 依赖

`ConfigMaker.m`、`A1–A5`、Eddy 脚本均以如下方式自定位：

```matlab
tmp = matlab.desktop.editor.getActive;
pathstr = fileparts(tmp.Filename);
cd(pathstr);
```

因此**必须在 MATLAB 桌面编辑器中把该脚本作为活动文件运行**（F5/运行按钮），不能用 `matlab -batch` 从任意目录运行。该初始化块同时完成 `addpath(function/)`，不要移除。

## 目录地图

| 目录 | 内容 |
|---|---|
| `function/` | 共享函数库（39 个：信号/环境/Bellhop IO/到达结构/合成/绘图），单一 `addpath` 入口 |
| `Eddy/` | 涡旋变体（EXTRA_EddyAnalyzer / EddyComparison，及其参数配置与 convert_munk_ssp）。仅依赖 `function/` 与 `CallBell/`——不依赖 `underwateracoustic/`（其历史 addpath 已于 2026-08 移除，避免同名函数遮蔽，见 `doc/FUNCTION_ARCHITECTURE.md`） |
| `Plot/` | 频率筛选有效性验证（FilteredFreqVerif） |
| `ref/` | 参考变体（TargSigGeneratorGPU，未被主流程调用） |
| `baseline/` | 行为基线（Phase 2A，回归验证用，见 `doc/BEHAVIOR_BASELINE.md`） |
| `CallBell/` | BELLHOP 并行运行器（mac/win/lin 三平台二进制 + 源码） |
| `doc/` | 项目说明、接口文档、行为基线、函数/配置地图 |
| `data/` | 输入数据与产物（昂贵，勿批量删除/再生） |

## 文档索引

- `doc/项目说明文档.md` — 完整流程与数据布局（最完整参考）
- `doc/接口文档.md` — 函数接口
- `doc/BEHAVIOR_BASELINE.md` — 行为基线（重构回归锚点）
- `doc/FUNCTION_MAP.md` / `doc/FUNCTION_ARCHITECTURE.md` — 函数分类与依赖
- `doc/CONFIGURATION_MAP.md` — 配置参数地图
