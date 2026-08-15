# UASignalAugmentor 行为基线（Behavior Baseline）

> **性质**：characterization 快照——冻结 2026-08-15 时点的当前行为，用于后续
> behavior-preserving 变更的前后比对。**不**判断科学正确性，**不**修任何已知问题。
> 全部已发现问题按 CURRENT BEHAVIOR 原样记录。

- 基线脚本：`baseline/run_baseline.m`（只调用 `function/` 生产函数，不改生产代码）
- 本次报告：`baseline/output/baseline_report_run1.md`（reference run）、`baseline_report_run2.md`（复现 run）
- 运行方式：`cd baseline && matlab -batch "run_baseline('run1')"`，再 `run_baseline('run2')` 做跨 run 比对

## 1. Pipeline map

```
ConfigMaker → A1WavTransformer → A2ENVmaker → A3ENVDuplicator
            → [CallBell/BellParallelMac 运行 bellhop.exe]
            → A4ArrProcessor → A5RecSigSynthesizer
```

| 阶段 | 脚本 | inputs | outputs | config/state | cwd 假设 | 随机行为 | 外部二进制 |
|---|---|---|---|---|---|---|---|
| 0 | `ConfigMaker.m` | 无（站点表硬编码于脚本） | `data/OriginEnvPack/Config{Zone}.mat`（`Site_loc`/`Source`/`Cal`） | `ZoneName` 需**手改源码**切换 | active-editor 定位自身目录 | 无 | 无 |
| A1 | `A1WavTransformer.m` | `data/raw/Class {A..E}/*.wav` | `data/processed/{Class}_*.mat`（fs/Ndelay/Analyrecord/Analy_freq）+ `Analy_freq_all.mat` | 脚本内联参数：threshold=0.05, cut_Tlength=1, FreqRange=[10,200] | 同上 | 无（纯 FFT） | 无 |
| A2 | `A2ENVmaker.m` | Config*.mat + `data/OceanData/{ETOPO2022,woa23_00..16}.mat` | `OriginEnvPack/{Zone}/ENVn/Rrn/EnvTemplate/ENV_*.env/.bty/.ssp/.trc/.brc` | `ConfigName` **手改源码**切换海域 | active-editor；**循环内 `cd` 进 EnvTemplate 且不还原**（A2ENVmaker.m:109） | 无 | 无 |
| A3 | `A3ENVDuplicator.m` | `Analy_freq_all.mat` + Config*.mat + A2 模板 | 每个 EnvTemplate 内 `test_{i}.{env,bty,ssp,trc,brc}` × N 频率 + `env_files_list.txt` + `ENVall_files_YYYYMMDD.tar.gz` | 同上（zone 从 Config 读） | active-editor；打包阶段 `cd` 到父目录后**还原** | 无 | 无（tar 为系统命令） |
| — | CallBell | `env_files_list.txt` + 同目录 env 五件套 | 每个频率一个 `.arr`（+`.prt`） | 二进制须与 `bellhop.exe` 同目录，经自身 cwd 定位 | 从 `CallBell/{mac,win,lin}/` 运行，参数为目标目录绝对路径 | bellhop 内部确定 | `BellParallelMac` + `bellhop.exe`（macOS 下仍名 .exe） |
| A4 | `A4ArrProcessor.m` | `env_files_list.txt` + `.arr` | `Rrn/ENV_ARR_less.mat`（ARR[m频率×n深度]: Amp/Delay/phase/freq/rd） | 脚本内联：MAX_FREQ_LIMIT=5000, AMP_THRESHOLD_RATIO=0.05 | active-editor | 无 | 无 |
| A5 | `A5RecSigSynthesizer.m` | `ENV_ARR_less.mat` + `data/processed/{Class}_*.mat` + `Analy_freq_all.mat` | `Rrn/NewSig/{signal}_Rd_{depth}_new.mat`（TargSig/TargT） | 脚本内联：Amp_source=1e5, **fs=52734 硬编码**（不读信号 fs） | active-editor | 见 §4 | 无 |

Eddy 变体：`Eddy/EXTRA_EddyConfigMaker.m` → `EXTRA_EddyAnalyzer.m` / `EddyComparison.m`。输出写死到仓库外 `/Users/luyiyang/Database/testBin/...`；`EXTRA_EddyAnalyzer.m` 循环上界注释为调试态（`for nrc = 1%:NumOfrc`）。**本阶段未动态执行，仅静态记录。**

## 2. 已知 current-behavior 事项（原样冻结，禁止顺手修复）

1. **A4ArrProcessor.m:105-115**：目录/列表缺失时 `continue` 被注释——打印警告后继续执行，随后 `readlines` 对不存在文件会报错中断整个批次。
2. **A5RecSigSynthesizer.m:84**：`fs = 52734` 硬编码；本基线样本实测信号 fs 恰为 52734，与历史产物一致，但契约上未从数据读取。
3. **A5 Amp_source = 1e5** 硬编码。
4. **A5 头注释 "Nsel 默认10段" 已过时**：`SignalPatchGenerator` 实际传 `[]`（全段）。
5. **TargSigGenerator.m:81 `randi(StartMax)` 无种子**——但生产路径（全段）`StartMax=1 → randi(1)≡1`，实测确定（见 §4）。
6. **env_files_list.txt 末行无换行符**（实测 xxd）；用 shell `while read` 消费会漏最后一项。
7. **BellParallelMac/bellhop.exe 的 dylib 依赖漂移**：rpath 指向 `~/miniconda3/lib/{libomp,libgfortran.5}.dylib`，本机不存在；需注入 homebrew 路径（§3）。且 MATLAB `system()` 会剥离 `DYLD_*`（签名进程），`BellParallelMac` 内部再 spawn `bellhop.exe` 时注入无法穿透两层——本基线回退为等价调用约定的直接循环调用 bellhop.exe。
8. **Eddy 脚本仓库外绝对路径**（§1）。
9. **A2 循环内 cd 不还原**（§1）。
10. **A3 打包 tar.gz**：本基线未执行（体积原因），静态记录。

## 3. 基线运行环境（2026-08-15）

- MATLAB R2025b Update 2 (25.2.0.3055257)，MACA64（Apple Silicon），`gpuDeviceCount=0` → 生产 A5 走 CPU 路径
- `matlab -batch` 会话初始 rng = twister seed 0（S0 记录）
- OS：macOS；仓库根：`git` 工作树（repo-relative 描述为准）
- CallBell：`CallBell/mac/BellParallelMac` + `bellhop.exe`（Mach-O arm64）
- dylib 注入：`DYLD_LIBRARY_PATH=/opt/homebrew/Cellar/libomp/20.1.5/lib:/opt/homebrew/Cellar/gcc/14.2.0_1/lib/gcc/current`（仅测试 harness 内，未改仓库任何文件）
- Config 使用状态：已跟踪的 `data/OriginEnvPack/ConfigDeep.mat`（Deep，6 站点，ReceiveRange=[5,30,60] km，ReceiveDepth=[25,50,100,300] m，freq=500，timeIdx=1，sea state 0，bottom IMG/0.05，RunType AB，Beam CS）
- 测试样本：已跟踪 `data/raw/Class A/46__23_07_13_H3_bateero1.wav`（fs=52734，24-bit，单声道，11.366 s）
- A3 频率集：**缩减集**（`Analy_freq_all ∩ 该信号频率` 前 5 个：45/48/51/52/54 Hz；全集 182 个）——TEST-CONTROLLED，为控制 bellhop 成本，非生产全量

## 4. 数值基线摘要（run1，详见 baseline_report_run1.md）

**S1 A1**（生产参数）：N=11 段；滤波前每段 191 频率；滤波后每段 105–122（均值 111.2）；`Analy_freq_filtered` n=147，min=45，max=200，mean=126.558，std=43.3022；全局幅值 n=1223，min=0.0010518，max=0.0210096，mean=0.00419074，std=0.00322538，NaN/Inf=0；相位 ∈ [-3.13945, 3.13947] rad。与已提交历史产物：fs 一致、频率交集 147/147（本次结果 ⊆ 历史）。

**S2 A2**（ConfigDeep 站点 1、5 km 模板）：FileMaker 产 5 文件（env 6488B / bty 1340B / ssp 38284B / trc 2097B / brc 2097B）；env 头：freq 500.00，NMedia 1，Top 'CFFT'，depth 0–3961 m；bty 'LS' 61 点（0–3902.25 m 起）；ssp 62 列。**跨 run 字节级一致。**

**S3 A3**：FreqDuplicator 5 频率 × 5 件套 = 25 个 `test_*`；`env_files_list.txt` = `test_1..test_5`（末行无换行）；`test_1.env` 与模板仅频率行不同（首差异在字符偏移 47）。注：当前 MATLAB A3 生产行为按频率重算 .trc/.brc（头注释声明）；本缩减运行走同一 `FreqDuplicator` 生产函数。

**S4 CallBell**：BellParallelMac 本机因 §2.7 注入无法穿透而未产 .arr（退出码 0 但 bellhop 全部 dyld 失败）；**回退**（等价调用约定：cwd=EnvTemplate，逐个 `bellhop.exe <name>`）产出 5/5 `.arr`。test_1.arr：freq=45，声源深 10 m，接收深 [25,50,100,300]，距离 [5000,30000,60000] m，每点声线 17–36（总 303）。

**S5 A4**（生产参数 5000/0.05）：`ENV_ARR_less.mat` ARR 5×4；合并统计：Delay n=191 ∈ [3.24916, 41.3141] s，mean=25.1579，std=14.4147；Amp n=191 ∈ [2.40319e-08, 7.25992e-05]，mean=5.17547e-06；phase ∈ [-π, 1.75e-07]；NaN=0。**跨 run `isequal` 完全一致。**

**S6 A5**（Amp_source=1e5，fs=52734，147 信号频率命中缩减集 5 个）：
- 生产默认（全段，无 rng）：len=580786，min=-0.0346117，max=0.0348129，mean=-1.85053e-14，std=0.0129381，NaN/Inf=0；TargT 末值 11.0135 s；两次调用 isequal=1（StartMax=1 → randi 无效）
- test-controlled rng(42)：跨 run isequal=1；前 5 样本高精度参考值见报告
- PROBE（TargSegNum=10，非生产路径）：rng 重置三次一致；**会话内不重置连续两次也一致**（len=528052）——该样本各段 Analyrecord 高度相似，输出对 StartSeg 不敏感（实测观察，未深究）
- **分类：A5 本样本/本环境下 deterministic；随机性为潜伏态（仅 TargSegNum<N 且段间差异显著时暴露）**

**跨 run（run1 vs run2）总判定**：S1 数值 / S2 字节 / S5 ARR / S6 seeded 信号——**全部一致** → 本基线可作回归锚点。

## 5. 覆盖度声明（如实）

| 阶段 | 覆盖 | 说明 |
|---|---|---|
| A1 | **动态**（完整生产参数，单样本） | 未跑 5 类全量（历史产物已提交可对照） |
| A2 | **动态**（单站点×单距离最小 case） | 未批量 6 站点×3 距离 |
| A3 | **动态**（缩减频率集 5 个） | 未跑 182 全集；tar 打包未执行 |
| CallBell | **动态（回退路径）** | BellParallelMac 本机受阻（§2.7），以等价调用约定直调 bellhop.exe；**未验证**原二进制并行行为本身 |
| A4 | **动态**（生产参数） | 未触发 §2.1 的缺目录分支 |
| A5 | **动态**（单深度、单信号、CPU 路径） | 未跑 GPU 分支、全深度×全信号批次 |
| Eddy | **仅静态** | 仓库外路径 + 调试态循环，未执行 |
| ConfigMaker | **仅静态**（已加载其产物 ConfigDeep.mat 验证结构） | 重新生成会覆盖现产物，不跑 |

**未声称全链路端到端验证**；以上为局部（per-stage）characterization。

## 6. 回归判定建议（供后续 Phase 2 使用）

- 必须逐项一致：S1 全部数值、S2 模板文件字节、S3 文件清单与 test_env 差异偏移、S5 ARR `isequal`、S6 seeded 信号 `isequal`
- 环境依赖（失败先查环境而非代码）：dylib 注入路径（§3）、MATLAB 版本、bellhop 二进制
- 本文档与两份 run 报告为基线锚点；重跑命令见文件头
