# UASignalAugmentor 配置参数地图（CONFIGURATION_MAP）

> Phase 2B-4 产出。**只登记，不移动任何参数**；本表为未来配置重构的依据。
> 分类：`[PATH]` 路径/运行时 · `[EXP]` 实验设计 · `[SCI]` 科学/数值参数。
> 已知硬编码问题（fs、Amp_source、rng 等）见文末 Deferred，均登记为后续 correctness phase 处理。

## 1. 主流程 Config*.mat（ConfigMaker.m 产出）

| 参数 | 定义位置 | 使用阶段 | 默认值（Deep） | 类别 | 适合集中管理 |
|---|---|---|---|---|---|
| `ZoneName` | ConfigMaker.m:40 | 0 | `'Deep'`（手改源码切换） | [EXP] | ★★★（当前手改源码） |
| `Site_loc.lat/lon` | ConfigMaker（分区硬编码） | A2 | 6 站点/海域 | [EXP] | ★★ |
| `Site_loc.ReceiveRange` | 同上 | A2/A4/A5 | `[5 30 60]` km | [SCI] | ★★ |
| `Site_loc.ReceiveDepth` | 同上 | A2/A4/A5 | `[25 50 100 300]` m | [SCI] | ★★ |
| `Site_loc.outputPath` | 同上 | A2 | `<root>/data/OriginEnvPack/{Zone}` | [PATH] | —（派生） |
| `Source.SourceRange/SourceDepth/azi` | ConfigMaker | A2 | 0 km / 10 m / 0° | [SCI] | ★★ |
| `Source.freq` / `freqvec` | ConfigMaker | A2（写 env）/A3（反射系数） | 500 Hz | [SCI] | ★★ |
| `Source.timeIdx` | ConfigMaker | A2 | 1（WOA 月索引；13-16 季，17 年） | [SCI] | ★★ |
| `Cal.top_sea_state_level` | ConfigMaker | A3(.trc) | 0 | [SCI] | ★★ |
| `Cal.mesoscale.type/params` | ConfigMaker | A2 | `'none'` / `[]` | [SCI] | ★★ |
| `Cal.Bdry.Top.Opt` | ConfigMaker | A2 | `'CFFT'` | [SCI] | ★ |
| `Cal.Bdry.Bot.Opt` + HS 五参数 | ConfigMaker | A2 | `'F*'`, 1500/0/1/0/0 | [SCI] | ★ |
| `Cal.bottom_base_type` / `bottom_alpha_b` | ConfigMaker | A3(.brc) | `'IMG'` / 0.05 | [SCI] | ★★ |
| `Cal.Beam.*`（RunType/Nbeams/alpha/deltas/epmult/rLoop/Nimage/Ibwin/Type） | ConfigMaker | A2（写 env） | `'AB'`/0/[-90,90]/0/0.3/1/1/1/`'CS'` | [SCI] | ★ |
| **`ConfigName`** | A2ENVmaker.m:53 / A3ENVDuplicator.m:62 | A2/A3 | `'ConfigDeep.mat'`（各自手改源码） | [PATH] | ★★★ |

## 2. 各脚本内联参数

| 参数 | 定义位置 | 使用阶段 | 默认值 | 类别 | 适合集中管理 |
|---|---|---|---|---|---|
| `threshold` | A1WavTransformer.m:51 | A1 | 0.05 | [SCI] | ★★ |
| `cut_Tlength` | A1:52 | A1 | 1 s | [SCI] | ★★ |
| `FreqRange` | A1:53 | A1 | `[10, 200]` Hz | [SCI] | ★★ |
| `subfolders`（类别表） | A1:46 | A1 | `Class A..E` | [PATH] | ★ |
| `MAX_FREQ_LIMIT` | A4ArrProcessor.m:49 | A4 | 5000 Hz | [SCI] | ★★ |
| `AMP_THRESHOLD_RATIO` | A4:50 | A4 | 0.05 | [SCI] | ★★ |
| `EnvClasses` | A4:57 / A5:57 | A4/A5 | `{'Shallow','Transition','Deep'}` | [PATH] | ★ |
| **`Amp_source`** | A5RecSigSynthesizer.m:83 | A5 | 1e5 | [SCI] | ★★（deferred） |
| **`fs`** | A5:84 | A5 | 52734 Hz（不读信号 fs） | [SCI] | ★★★（deferred correctness） |
| `useGPU`/`BatchSize`/`resetEveryN` | SignalPatchGenerator.m:27-29 | A5 | false / 64 / 0 | [PATH] | ★ |
| `TargSegNum`（缺省） | TargSigGenerator.m:24（SignalPatchGenerator 传 `[]`） | A5 | 全段（A5 头注释"10段"已过时） | [SCI] | 登记差异 |
| rng（无种子） | TargSigGenerator.m:81 | A5 | 生产路径实际确定（StartMax=1） | [SCI] | deferred |

## 3. Eddy 变体

| 参数 | 定义位置 | 使用阶段 | 值 | 类别 |
|---|---|---|---|---|
| `Receiver 63 km/150 m`、`freq=300`、`timeIdx=13`、`rcVector 10:10:50`、`zc/DR/DZ=150/60/500`、`DCVector`、`Bdry QVWT/A`、HS 1610/1.7/α(f)、Beam AB… | Eddy/EXTRA_EddyConfigMaker.m → `data/Eddy/EddyFileConfig.mat` | EXTRA_EddyAnalyzer | 见脚本 | [SCI] |
| `freq=100`、`rmax=100`、`dr=1`、深度 0:10:3000、站点(115,13)、eddy rc/zc/DR/DZ/DC=50/600/70/500/-50、RunTypes {CB,RB}、Bdry QVW/A*、HS 1600/1.5/0.5 | Eddy/EddyComparison_Config.m → `EddyComparison_Params.mat` | EddyComparison | 见脚本 | [SCI] |
| `OutputDir = /Users/.../testBin/...` | EXTRA_EddyAnalyzer.m:12,49; EddyComparison.m:63 | Eddy 两脚本 | 仓库外绝对路径 | [PATH] ★★★（deferred） |
| `bellhop_path = CallBell/mac/bellhop.exe` | EddyComparison.m:36 | EddyComparison | 平台硬编码 | [PATH] |
| `n=4`（SSP 插值倍率） | Eddy/convert_munk_ssp.m:44 | Eddy 数据准备 | 4 | [SCI] |
| 循环上界调试态 `for nrc = 1%:NumOfrc` | EXTRA_EddyAnalyzer.m:88 | Eddy | 1（非全向量） | [EXP] deferred |

## 4. 分类汇总与未来建议（不实施）

- **[PATH] 类**（ZoneName、ConfigName、EnvClasses、OutputDir、bellhop_path）：最优先集中——建议未来统一为脚本顶部单一"运行配置块"或外部 run-manifest；**不改变 .mat 配置结构**。
- **[SCI] 类**：保持 Config*.mat 为主体；A1/A4 内联参数建议未来并入同一 manifest（行为变更需单独 correctness commit + baseline 对照）。
- **[EXP] 类**：站点表/海域切换建议未来参数化为循环批处理入口（属功能增强，另立 phase）。

## 5. Deferred（本阶段明确不动的 correctness 项）

`A5 fs` 硬编码、`Amp_source` 硬编码、`TargSigGenerator rng` 无种子、A4 缺输入 continue 被注释、Eddy 仓库外输出路径、Eddy 调试态循环、BellParallelMac dylib 依赖与假成功、A5 头注释 Nsel 过时（已在新头注释中修正表述）。
