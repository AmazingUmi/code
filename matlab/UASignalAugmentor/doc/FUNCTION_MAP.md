# UASignalAugmentor 函数分类地图（FUNCTION_MAP）

> Phase 2B-2 产出。`function/` 保持扁平单 addpath 入口；本表为职责分类，
> 物理细分仅在确认无名称冲突与动态路径依赖后另行评估。
> 详细依赖/副作用审计见 `FUNCTION_ARCHITECTURE.md`。

## signal processing（信号处理）

| 函数 | 调用者 | 说明 |
|---|---|---|
| `wavfreq.m` | A1, Plot/FilteredFreqVerif, baseline | wav 分段 FFT 频率/幅值/相位提取 |
| `wavfilter.m` | A1, Plot/FilteredFreqVerif, baseline | 全局幅值阈值筛选 |
| `SigGenerateTD.m` | TargSigGenerator | 单频时域信号合成 |
| `SigGenerateFD.m` | （无调用者） | 频域变体，**dead-code 候选（登记不删）** |

## environment generation（环境生成）

| 函数 | 调用者 | 说明 |
|---|---|---|
| `load_data.m` | A2, baseline | 加载 ETOPO2022 + woa23_00..16 |
| `coord_proc.m` | A2, Eddy/…Config, baseline | 大圆航线起点→终点坐标 |
| `get_env.m` | FileMaker | 环境场/SSP/海底地形提取（→ get_envInfo, get_bathm, sound_speed） |
| `get_envInfo.m` / `get_bathm.m` / `sound_speed.m` | get_env | 子工具 |
| `add_mesoscale.m` | FileMaker, EddyComparison | SSP 叠加涡旋/内波 |
| `FileMaker.m` | A2, baseline | 真实环境五件套生成主入口 |
| `FileMakerIdeal.m` | Eddy/EXTRA_EddyAnalyzer, EddyComparison | 理想（Munk）环境五件套 |

## Bellhop IO（文件写入）

| 函数 | 调用者 | 说明 |
|---|---|---|
| `write_env.m` / `write_bty.m` / `write_ssp.m` | FileMaker(±Ideal), FreqDuplicator | .env/.bty/.ssp 写入（write_env→write_bell, equally_spaced） |
| `write_bell.m` / `equally_spaced.m` | write_env | 子工具 |
| `ReCoeTop.m` | FileMaker(±Ideal), FreqDuplicator | 海面反射系数 .trc |
| `RefCoeBw.m` | 同上 | 海底反射系数 .brc |
| `get_boundary_speed.m` | FreqDuplicator | 从 .env 文本提取表/底声速 |
| `FreqDuplicator.m` | A3, Eddy, baseline | 频率扩展复制（A3 核心） |

## arrivals（到达结构）

| 函数 | 调用者 | 说明 |
|---|---|---|
| `read_arrivals_asc.m` | ArrReader, A3(注释), baseline | .arr 文本解析 |
| `read_arrivals_bin.m` | （无调用者） | 二进制变体，**dead-code 候选（登记不删）** |
| `ArrReader.m` | A4, Eddy, baseline | .arr 批处理→ENV_ARR_less.mat |

## synthesis（合成）

| 函数 | 调用者 | 说明 |
|---|---|---|
| `SignalPatchGenerator.m` | A5, Eddy/EXTRA_EddyAnalyzer | 批量信号合成调度 |
| `TargSigGenerator.m` | SignalPatchGenerator, baseline | 单信号合成（GPU 可选；randi 无种子，见基线 §4） |

## visualization（可视化）

| 函数 | 调用者 | 说明 |
|---|---|---|
| `plotSSP.m` / `plotray.m` / `plotshd.m` / `caxisrev.m` | EddyComparison | SSP/声线/传播损失绘图（plotshd→read_shd） |
| `read_shd.m`（→asc/bin） | plotshd | .shd 读取；bin 变体无调用者 |

## utilities / 路径

| 函数 | 调用者 | 说明 |
|---|---|---|
| `uasa_project_root.m` | （Phase 2B-3 新增） | 项目根解析，见 2B-3 |

## 命名冲突检查（2026-08 实测）

`function/` 内 39 个函数名与 MATLAB R2025b 内建无冲突（除 `sound_speed` 为自定义覆盖，仅本 addpath 作用域内生效）。
