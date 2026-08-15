# Umi的代码库 — 水声信号仿真研究仓库

个人研究代码库，围绕水声信号仿真与数据集生成。文档与注释以中文为主。自动化工具（OpenCode 等）修改本仓库前必须先读 [AGENTS.md](AGENTS.md)。

原始历史修改记录见 [`readme.txt`](readme.txt)（保留不再维护），关键节点：2025-12 UASignalAugmentor 主程序整理完毕、带涡程序（测试版）构建。

## 目录导航

| 目录 | 状态 | 说明 |
|---|---|---|
| `matlab/UASignalAugmentor/` | **权威实现（authoritative）** | A1–A5 端到端水声信号合成与增强主流程，含 Eddy 涡旋变体与 CallBell（BELLHOP 并行运行器） |
| `py/UASignalAugmentor/` | 部分移植（partial port） | 仅 A1 / A2 / B1 三个模块与 `utils/`；当前入口为 `examples/*.py`；A2 基于旧版 `arr_test` 实现，与最新 MATLAB A2/A3 尚未对齐 |
| `py/EnvProcess/` | 独立工具 | ETOPO2022 / WOA23 netCDF → `.mat`/`.npz` 提取脚本 |
| `matlab/arr_test/` | 历史前身 | UASignalAugmentor 的旧版 A1–D2 脚本；含 Python 转码计划原始文档，已被 UASA 取代 |
| `py/old/` | 遗留 | 早期 PyTorch 分类器训练实验（DenseNet/ResNet/ConvNext）与训练日志，与主流程无关 |
| `cpp/` | 历史实验 | 旧 Windows Visual Studio 工程；其中已提交的 `.exe`/`.obj`/`.vs/` 构建产物为有意保留 |
| `matlab/` 其他子目录 | 辅助分析 | `underwateracoustic`（含 WOA18/ETOPO 大型数据）、`特性分析`、`NoiseGenerate`、`不同海洋环境聚类`、`env_data_read`（ADCP/OBS/台风数据读取）、`CyxReverberation`、`basic_module` 等独立脚本，与主流程无代码耦合 |
| `doc/` | 参考资料 | 论文/文档，非代码 |

## 主要文档

- [AGENTS.md](AGENTS.md) — 仓库约定、运行陷阱与现代化规则
- `matlab/UASignalAugmentor/doc/项目说明文档.md` — 主流程与数据布局的最完整参考
- `matlab/UASignalAugmentor/doc/接口文档.md` — 函数接口
- `py/UASignalAugmentor/README.md` — Python 移植现状（partial port）

## 数据与二进制说明

- 各 `data/` 目录下的 `.mat`/`.wav`（ETOPO2022、WOA23、原始/处理音频等）为昂贵数据，**不要删除或批量重新生成**。
- 被跟踪的 `bellhop.exe`、`BellParallelMac*` 等二进制是**有意的运行时依赖**；`cpp/` 下的 VS 构建产物为有意保留的历史内容，不要清理。
- 根 `.gitignore` 仅忽略 OS/缓存临时文件（`.DS_Store`、`__pycache__/`、`*.py[cod]`、`*.asv`），不忽略任何数据或二进制。
