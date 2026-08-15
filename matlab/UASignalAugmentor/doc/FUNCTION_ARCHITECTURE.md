# UASignalAugmentor 函数架构审计（FUNCTION_ARCHITECTURE）

> Phase 2B-5 产出。基于 2026-08 全仓调用关系实测（调用者=当前代码中真实存在的调用；
> baseline/ 计入）。**本阶段不重写任何函数**；dead code 仅登记。
> 分类：A=stable reusable · B=pipeline-specific · C=duplicated · D=legacy · E=unknown。

## 审计总表

| 函数 | 调用者 | 职责 | 主要 I/O | 副作用/文件IO | 全局/路径依赖 | 重复 | 候选模块 | 分类 |
|---|---|---|---|---|---|---|---|---|
| `wavfreq` | A1, Plot, baseline | wav/数组→分段 FFT 频率/幅值/相位 | in: wav/信号+fs; out: fs,Ndelay,Analyrecord,Analy_freq | audioread | 无 | — | signal | **A** |
| `wavfilter` | A1, Plot, baseline | 全局幅值阈值筛选 | in: Analyrecord; out: 过滤后记录+频率集 | 无 | 无 | — | signal | **A** |
| `SigGenerateTD` | TargSigGenerator | 单频时域复信号生成 | out: y_time, M_length | 无 | 无 | 与 SigGenerateFD 并存(变体) | synthesis | **B** |
| `SigGenerateFD` | **无**（主流程未用） | 频域变体 | — | — | — | — | synthesis | **D** dead-code 候选 |
| `load_data` | A2, baseline | 加载 ETOPO2022+WOA23(17 文件映射) | out: ETOPO, WOA | load(.mat) | 路径由调用者传入 | — | environment | **A** |
| `coord_proc` | A2, Eddy/*Config, baseline | 大圆航线坐标计算 | coordS+距离+方位→coordE | 无 | 无 | — | environment | **A** |
| `get_env` | FileMaker | 插值取环境场/SSP/地形 | in: ETOPO,WOA,lon/lat,timeIdx | 调 get_envInfo/get_bathm/sound_speed | 无 | — | environment | **B** |
| `get_envInfo` / `get_bathm` / `sound_speed` | get_env | 环境子工具 | — | — | — | — | environment | **A**(内部) |
| `add_mesoscale` | FileMaker, EddyComparison | SSP 叠加涡/内波 | SSProf+params | 无 | 无 | — | environment | **A** |
| `FileMaker` | A2, baseline | 真实环境五件套生成（主入口） | ETOPO+WOA+Config→5 文件 | **写 .env/.bty/.ssp/.trc/.brc（写入 cwd）** | ⚠ 依赖调用者已 cd 到目标目录（A2 先 cd；baseline 同） | 与 FileMakerIdeal 共享子结构 | environment | **B** |
| `FileMakerIdeal` | Eddy×2 | 理想(Munk)环境五件套 | 同上（无 ETOPO/WOA） | 同上（写 cwd） | 同上 | 与 FileMaker 部分重复（写入序列同构） | environment | **B/C** |
| `write_env` | FileMaker±Ideal | .env 写入 | SSP/Bdry/Pos/Beam | 写文件 | 无 | — | bellhop-io | **A** |
| `write_bty` / `write_ssp` | FileMaker±Ideal | .bty/.ssp 写入 | bathm / r×c | 写文件 | 无 | — | bellhop-io | **A** |
| `write_bell` / `equally_spaced` | write_env | env 头/网格子工具 | — | — | — | — | bellhop-io | **A**(内部) |
| `ReCoeTop` | FileMaker±Ideal, FreqDuplicator | 海面反射系数 .trc | freqvec+ssp_top+sea_state | 写 .trc（cwd） | cwd 写入约定同上 | — | bellhop-io | **B** |
| `RefCoeBw` | 同上 | 海底反射系数 .brc | bottom 参数+freqvec | 写 .brc（cwd） | 同上 | — | bellhop-io | **B** |
| `get_boundary_speed` | FreqDuplicator | 从 .env 文本提取表/底声速 | — | 读文件 | 无 | — | bellhop-io | **A** |
| `FreqDuplicator` | A3, Eddy, baseline | 按频率批量复制 env 套件（重算 .trc/.brc） | SourceDir+FreqVector→test_* + list | 读写文件；**cd(OutputDir) 后还原(160-175)** | cwd 依赖（内部管理） | — | arrivals/bellhop-io | **B** |
| `read_arrivals_asc` | ArrReader, baseline | .arr 文本解析 | in: .arr; out: Arr(Narr/A/delay/...),Pos | 读文件 | 无 | 与 _bin 变体并存 | arrivals | **A** |
| `read_arrivals_bin` | **无** | 二进制 .arr 变体 | — | — | — | — | arrivals | **D** dead-code 候选 |
| `ArrReader` | A4, Eddy, baseline | .arr 批处理→ENV_ARR_less.mat | 列表+目录+两阈值 | save(.mat) | 无（注释提及 parfor 优化，现为 for） | — | arrivals | **B** |
| `read_shd`（→asc/bin） | plotshd | .shd 读取 | — | 读文件 | global units（plotshd 侧） | — | arrivals | **A** |
| `read_shd_bin` | 仅 read_shd 内部分派 | — | — | — | — | — | arrivals | **A**(内部) |
| `SignalPatchGenerator` | A5, Eddy/EXTRA | 批量合成调度（深度×信号） | ARR+信号集→NewSig/*.mat | save(.mat)；GPU 探测 | 无 | — | synthesis | **B** |
| `TargSigGenerator` | SignalPatchGenerator, baseline | 单信号合成（CPU/GPU 双路径） | AnalyRecord+ArrRDSig→TargSig,TargT | GPU 设备操作 | ⚠ randi 无种子（生产路径确定，见基线）；GPU/CPU 数值路径并存 | 与 ref/TargSigGeneratorGPU 历史重复 | synthesis | **B** |
| `plotSSP`/`plotray`/`plotshd`/`caxisrev` | EddyComparison | 可视化 | — | figure/saveas（Eddy 调用侧） | **global units**（plotray/plotshd） | — | visualization | **A** |
| `uasa_project_root` | baseline, Eddy/EXTRA_EddyConfigMaker（试点） | 项目根解析（自定位） | out: root 路径 | 无（不 cd/addpath） | 依赖自身位于 <root>/function | — | utilities | **A**（2B-3 新增） |

## 关键发现

1. **cwd-写入约定**：`FileMaker`/`ReCoeTop`/`RefCoeBw`/`FileMakerIdeal` 以"调用者先 cd 到目标目录"为隐式契约（A2:109、baseline 同步采用）。这是有意协议，不是缺陷；任何 future 重构不得在未改调用方时改为绝对路径写入以外的语义。
2. **FreqDuplicator 内部自管理 cd**（进入 OutputDir、finally 还原）——function 层唯一的 cd 操作者，已登记。
3. **dead-code 候选**（仅登记不删）：`SigGenerateFD`、`read_arrivals_bin`；`ref/TargSigGeneratorGPU`（无调用者的历史参考实现）。`read_shd_bin` 经 `read_shd` 内部分派仍可达，非 dead。
4. **global 状态**：仅 `plotray`/`plotshd` 使用 `global units`（BELLHOP 官方读取惯例），visualization 局部，不影响主流程数值。
5. **重复度评估**：`FileMaker` vs `FileMakerIdeal` 写入序列同构（env/bty/ssp/trc/brc 调用次序一致），若未来合并需以行为基线逐字节对照（属 Phase 3+ 之外的独立决策）。
6. **名称遮蔽**：`sound_speed`、`write_env` 等名称在 `underwateracoustic/bellhop_fundation/function`（EddyComparison_Config 会 addpath 该外部目录）中存在同名函数——Eddy 场景下存在**跨目录遮蔽风险**（E-unknown 项，登记；主流程不受影响，因主流程不加载该外部路径）。

## 候选模块划分（对应 FUNCTION_MAP.md 六分类）

signal / environment / bellhop-io / arrivals / synthesis / visualization / utilities——物理细分暂缓（单一 addpath 不变量优先），本表为依据。
