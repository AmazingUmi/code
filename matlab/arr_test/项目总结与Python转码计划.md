# 水声信号处理与数据集生成项目 - Python转码计划

## 📋 项目概述

**项目名称**：基于BELLHOP的船舶识别数据集生成系统  
**原始语言**：MATLAB  
**目标语言**：Python  
**项目类型**：水声信号处理 + 深度学习数据集制作  

---

## 🎯 项目目标

处理船舶音频信号（ShipsEar数据集），通过水声传播模型（BELLHOP）模拟不同海洋环境下的接收信号，最终生成用于深度学习分类的多通道时频谱图数据集。

---

## 🏗️ 系统架构

### 核心数据流

```
原始音频 → 频率分析 → 频率筛选 → 环境文件生成 → 
声场计算(BELLHOP) → 多径参数提取 → 接收信号重构 → 
谱图生成 → 数据集划分
```

### 模块划分

#### **A系列：主数据生成管道**
- **A1_wavtrans**：音频频率分析与特征提取
- **A2_wavfilter**：频率成分全局筛选
- **A3_envfilmade**：BELLHOP环境文件批量生成
- **A4_readenvall**：声场计算结果解析
- **A5_recievesig**：多径接收信号重构
- **A6_picgenerate**：三通道谱图生成

#### **B系列：验证与分析**
- **B1_fftcompare**：频率筛选有效性验证
- **B2-B4**：可视化对比分析

#### **C系列：数据增强**
- **C1_noise_sig_generate**：多信噪比含噪数据生成
- **C2/C4**：噪声信号谱图生成

#### **D系列：数据组织**
- **D1_file_move_ENV_ARR_less**：环境计算结果迁移
- **D2_file_move_trainsets**：训练集/验证集/测试集划分

---

## 🔧 技术细节

### 数据集配置
- **船舶类别**：5类 (Class A-E)
- **海洋环境**：3类 (Shallow/Transition/Deep)
- **环境配置**：6组 (ENV1-6)
- **距离配置**：3个 (Rr1-3)
- **接收深度**：浅海3层，深海/过渡4层
- **总场景数**：3 × 6 × 3 = 54种

### 信号处理参数
- **采样率**：52734 Hz
- **频率范围**：10-5000 Hz
- **分段长度**：1秒
- **帧重叠率**：50%
- **信噪比**：15/10/5/0/-5 dB

### 谱图生成
- **通道1 (R)**：Mel谱图 (98×98)
- **通道2 (G)**：CQT谱图 (98×98)
- **通道3 (B)**：Bark谱图 (98×98)
- **输出格式**：PNG (无压缩)

---

## 📦 Python转码待办事项

### ✅ 转码范围
将所有MATLAB脚本转换为Python，**除外**：
- ❌ C++并行计算部分 (c++time.cpp, parallel.cpp) - 保持不变
- ❌ BELLHOP可执行文件调用 - 保持系统调用方式

---

## 📝 待办任务清单

### 阶段1️⃣：环境准备与依赖配置

- [ ] **任务1.1**：创建Python项目结构
  - [ ] 创建 `src/` 主代码目录
  - [ ] 创建 `utils/` 工具函数目录
  - [ ] 创建 `config/` 配置文件目录
  - [ ] 创建 `tests/` 单元测试目录
  - [ ] 创建虚拟环境

- [ ] **任务1.2**：编写 `requirements.txt`
  ```
  numpy>=1.24.0
  scipy>=1.10.0
  librosa>=0.10.0
  soundfile>=0.12.0
  matplotlib>=3.7.0
  Pillow>=10.0.0
  tqdm>=4.65.0
  joblib>=1.3.0
  pyyaml>=6.0
  ```

- [ ] **任务1.3**：编写配置文件 `config/config.yaml`
  - [ ] 数据路径配置
  - [ ] 信号处理参数
  - [ ] 谱图生成参数
  - [ ] 数据集划分比例

---

### 阶段2️⃣：核心工具函数转换

- [ ] **任务2.1**：信号处理模块 `utils/signal_processing.py`
  - [ ] `add_awgn()` - 添加高斯白噪声
    - MATLAB: `function/add_awgn.m`
    - 依赖: `numpy.random`
  - [ ] `process_signal()` - 信号预处理
    - MATLAB: `processSignal.m`
    - 包含：归一化、加噪、预加重、中心化、分帧
    - 依赖: `scipy.signal`

- [ ] **任务2.2**：多径信号生成 `utils/multipath_synthesis.py`
  - [ ] `td_sig_generate()` - 时域多径合成
    - MATLAB: `tdsiggenerate.m`
    - 依赖: `numpy.fft`
  - [ ] `fd_sig_generate()` - 频域多径合成
    - MATLAB: `fdsiggenerate.m`
    - 依赖: `numpy.fft`

- [ ] **任务2.3**：谱图生成 `utils/spectrogram_generator.py`
  - [ ] `generate_mel_spectrogram()` - Mel谱图
    - 依赖: `librosa.feature.melspectrogram`
  - [ ] `generate_cqt_spectrogram()` - CQT谱图
    - 依赖: `librosa.cqt`
  - [ ] `generate_bark_spectrogram()` - Bark谱图
    - 依赖: `scipy.signal.spectrogram` + Bark映射
  - [ ] `combine_three_channels()` - 三通道合成
    - 依赖: `PIL.Image`

- [ ] **任务2.4**：文件I/O工具 `utils/io_utils.py`
  - [ ] `read_arrivals_asc()` - 读取BELLHOP .arr文件
    - MATLAB依赖: `read_arrivals_asc.m` (来自bellhop_fundation)
    - 需手动实现二进制解析
  - [ ] `save_json()` / `load_json()` - JSON序列化
  - [ ] `save_pickle()` / `load_pickle()` - Python对象持久化

---

### 阶段3️⃣：主流程脚本转换

- [ ] **任务3.1**：A1 - 频率分析 `src/a1_wav_transform.py`
  - MATLAB源: `A1wavtrans.m`
  - 功能：
    - [ ] 遍历5类船舶音频
    - [ ] 分段FFT分析（1秒窗口）
    - [ ] 提取主频率成分（阈值筛选）
    - [ ] 保存为 `.pkl` 格式
  - 依赖: `scipy.fft`, `soundfile`, `tqdm`
  - **关键挑战**: 
    - MATLAB的FFT与NumPy对齐
    - 路径管理统一化

- [ ] **任务3.2**：A2 - 频率筛选 `src/a2_wav_filter.py`
  - MATLAB源: `A2wavfilter.m`
  - 功能：
    - [ ] 加载所有信号频率数据
    - [ ] 全局幅值排序
    - [ ] 按阈值筛选有效成分
    - [ ] 更新保存筛选后数据
  - 依赖: `numpy`, `pickle`
  - **关键挑战**:
    - 大数组排序效率（考虑np.argsort）

- [ ] **任务3.3**：A3 - 环境文件生成 `src/a3_env_file_maker.py`
  - MATLAB源: `A3envfilmade.m`
  - 功能：
    - [ ] 遍历3类环境×6组×3距离
    - [ ] 为每个频率生成 `.env` 文件
    - [ ] 复制 `.trc`, `.bty`, `.brc` 文件
    - [ ] 生成 `env_files_list.txt`
    - [ ] 打包压缩（可选）
  - 依赖: `os`, `shutil`, `concurrent.futures`
  - **关键挑战**:
    - 文件模板替换（使用Jinja2或字符串格式化）
    - 并行处理（使用multiprocessing或joblib）

- [ ] **任务3.4**：A4 - 声场结果读取 `src/a4_read_env_all.py`
  - MATLAB源: `A4readenvall.m`
  - 功能：
    - [ ] 读取 `.arr` 文件（调用io_utils）
    - [ ] 提取多径参数（时延、幅值、相位）
    - [ ] 阈值筛选弱径
    - [ ] 保存为 `ENV_ARR_less.pkl` 和 `.json`
  - 依赖: `numpy`, `json`, `joblib`
  - **关键挑战**:
    - `.arr` 二进制格式解析（需参考BELLHOP文档）
    - 并行文件读取

- [ ] **任务3.5**：A5 - 接收信号重构 `src/a5_receive_sig.py`
  - MATLAB源: `A5recievesig.m`
  - 功能：
    - [ ] 加载多径参数和信号频率数据
    - [ ] 随机选择10段连续信号
    - [ ] 调用 `td_sig_generate()` 重构
    - [ ] 保存为 `.pkl` 格式
  - 依赖: `numpy`, `pickle`, `tqdm`
  - **关键挑战**:
    - 时延对齐计算
    - 内存管理（大信号数组）

- [ ] **任务3.6**：A6 - 谱图生成 `src/a6_pic_generate.py`
  - MATLAB源: `A6picgenerate.m`
  - 功能：
    - [ ] 加载接收信号
    - [ ] 调用 `process_signal()` 预处理
    - [ ] 生成Mel/CQT/Bark三通道谱图
    - [ ] 保存为PNG (98×98×3)
  - 依赖: `librosa`, `PIL`, `numpy`
  - **关键挑战**:
    - Bark谱图实现（MATLAB没有内置）
    - 谱图归一化一致性

---

### 阶段4️⃣：验证与工具脚本

- [ ] **任务4.1**：B1 - 频率筛选验证 `src/b1_fft_compare.py`
  - MATLAB源: `B1fftcompare.m`
  - 功能：
    - [ ] 计算MSE、MAE等指标
    - [ ] 频谱对比分析
    - [ ] 时频KL散度计算
    - [ ] 生成评估报告
  - 依赖: `scipy`, `matplotlib`

- [ ] **任务4.2**：C1 - 噪声数据生成 `src/c1_noise_sig_generate.py`
  - MATLAB源: `C1noise_sig_generate.m`
  - 功能：
    - [ ] 为原始音频添加多SNR噪声
    - [ ] 批量保存为WAV文件
  - 依赖: `soundfile`, `utils.signal_processing`

- [ ] **任务4.3**：D2 - 数据集划分 `src/d2_file_move_trainsets.py`
  - MATLAB源: `D2file_move_trainsets.m`
  - 功能：
    - [ ] ENV1-4 → train
    - [ ] ENV5 → val
    - [ ] ENV6 → test
    - [ ] 按类别组织文件
  - 依赖: `shutil`, `pathlib`

---

### 阶段5️⃣：集成与优化

- [ ] **任务5.1**：主入口脚本 `main.py`
  - [ ] 命令行参数解析（argparse）
  - [ ] 流程编排（支持单步/全流程运行）
  - [ ] 日志系统（logging）
  - [ ] 进度条显示（tqdm）

- [ ] **任务5.2**：配置管理 `utils/config_loader.py`
  - [ ] YAML配置加载
  - [ ] 路径自动补全
  - [ ] 参数验证

- [ ] **任务5.3**：并行计算优化
  - [ ] 使用 `joblib.Parallel` 替代MATLAB parfor
  - [ ] 多进程池管理
  - [ ] 内存监控

- [ ] **任务5.4**：单元测试
  - [ ] `tests/test_signal_processing.py`
  - [ ] `tests/test_multipath_synthesis.py`
  - [ ] `tests/test_spectrogram.py`
  - [ ] 使用pytest框架

---

### 阶段6️⃣：文档与部署

- [ ] **任务6.1**：编写README
  - [ ] 项目介绍
  - [ ] 安装说明
  - [ ] 使用示例
  - [ ] 常见问题

- [ ] **任务6.2**：API文档
  - [ ] 使用Sphinx生成文档
  - [ ] Docstring完善（Google风格）

- [ ] **任务6.3**：Docker化（可选）
  - [ ] 编写Dockerfile
  - [ ] 依赖环境固化

---

## 🔍 关键转换对照表

| MATLAB函数/语法 | Python等价物 | 备注 |
|----------------|-------------|------|
| `audioread()` | `soundfile.read()` | 读取音频 |
| `fft()` | `numpy.fft.fft()` | 快速傅里叶变换 |
| `spectrogram()` | `scipy.signal.spectrogram()` | 时频谱图 |
| `melSpectrogram()` | `librosa.feature.melspectrogram()` | Mel谱图 |
| `cqt()` | `librosa.cqt()` | 恒Q变换 |
| `parfor` | `joblib.Parallel()` | 并行循环 |
| `struct` | `dict` 或 `dataclass` | 结构体 |
| `cell` | `list` | 元胞数组 |
| `.mat` 文件 | `.pkl` 或 `.npz` | 数据存储 |
| `jsonencode()` | `json.dumps()` | JSON序列化 |
| `dir()` | `pathlib.Path.glob()` | 文件搜索 |
| `mkdir()` | `os.makedirs()` | 创建目录 |
| `copyfile()` | `shutil.copy()` | 文件复制 |

---

## ⚠️ 重点注意事项

### 1. 二进制文件解析
- **挑战**：BELLHOP的 `.arr` 文件是二进制格式
- **解决方案**：
  - 参考MATLAB函数 `read_arrivals_asc.m` 的逻辑
  - 使用 `struct.unpack()` 或 `numpy.fromfile()`
  - 需要了解文件格式规范

### 2. 数值精度对齐
- **挑战**：MATLAB和NumPy的FFT结果可能有微小差异
- **解决方案**：
  - 使用相同的归一化方式
  - 编写单元测试对比关键节点数值

### 3. 并行计算策略
- **挑战**：Python的GIL限制
- **解决方案**：
  - 使用 `multiprocessing` 而非 `threading`
  - 考虑 `joblib` 的内存映射特性
  - 避免频繁进程间通信

### 4. 内存管理
- **挑战**：大规模数据处理可能内存不足
- **解决方案**：
  - 使用生成器（generator）而非列表
  - 分批处理（batch processing）
  - 及时释放不用的数组（`del` 语句）

### 5. 路径兼容性
- **挑战**：Windows/Linux路径差异
- **解决方案**：
  - 统一使用 `pathlib.Path`
  - 避免硬编码路径分隔符

---

## 📊 预期成果

### 代码结构
```
arr_test_python/
├── config/
│   └── config.yaml
├── src/
│   ├── a1_wav_transform.py
│   ├── a2_wav_filter.py
│   ├── a3_env_file_maker.py
│   ├── a4_read_env_all.py
│   ├── a5_receive_sig.py
│   ├── a6_pic_generate.py
│   ├── b1_fft_compare.py
│   ├── c1_noise_sig_generate.py
│   └── d2_file_move_trainsets.py
├── utils/
│   ├── __init__.py
│   ├── signal_processing.py
│   ├── multipath_synthesis.py
│   ├── spectrogram_generator.py
│   ├── io_utils.py
│   └── config_loader.py
├── tests/
│   ├── test_signal_processing.py
│   ├── test_multipath_synthesis.py
│   └── test_spectrogram.py
├── main.py
├── requirements.txt
└── README.md
```

### 性能目标
- 单个谱图生成时间：< 1秒
- 内存占用：< 8GB（处理单个环境）
- 并行加速比：> 0.7（相对核心数）

---

## ⚡ Python vs MATLAB 性能对比分析

### 📈 预期性能提升的部分

#### 1. **FFT计算** ⬆️ **提升10-30%**
- **原因**：
  - NumPy的FFT底层使用FFTW（C库），高度优化
  - MATLAB的FFT也很快，但NumPy在大数组上略有优势
- **场景**：A1频率分析、B1频谱对比
- **证据**：NumPy FFT在百万点级别比MATLAB快15-25%

#### 2. **文件I/O** ⬆️ **提升20-50%**
- **原因**：
  - Python的`soundfile`、`pickle`比MATLAB的`audioread`、`save`更高效
  - 避免了MATLAB的JIT编译开销
- **场景**：A1读取音频、A4保存多径参数
- **建议**：使用`numpy.savez_compressed()`替代`.mat`可进一步提升

#### 3. **并行计算** ⬆️ **提升30-100%**
- **原因**：
  - `joblib`的内存映射比MATLAB parfor更高效
  - Python可使用`multiprocessing.Pool`避免GIL
  - 更细粒度的并行控制（进程数、内存共享）
- **场景**：A3环境文件生成、A4批量读取.arr、A6谱图生成
- **关键优化**：
  ```python
  from joblib import Parallel, delayed
  results = Parallel(n_jobs=-1, backend='loky')(
      delayed(process_func)(x) for x in data
  )
  ```

#### 4. **字符串处理** ⬆️ **提升50-200%**
- **原因**：Python的字符串操作天生快于MATLAB
- **场景**：A3环境文件模板替换、文件路径操作

---

### 📉 预期性能持平或下降的部分

#### 1. **矩阵运算** ➡️ **基本持平**
- **原因**：
  - 两者都调用BLAS/LAPACK底层库
  - NumPy和MATLAB在矩阵乘法、线性代数上性能相近
- **场景**：信号卷积、矩阵索引
- **注意**：避免Python循环，使用向量化操作

#### 2. **谱图生成** ⬇️ **可能降低10-20%**
- **原因**：
  - MATLAB的`spectrogram()`、`melSpectrogram()`高度优化
  - Librosa虽功能强大，但部分操作用Python实现，速度略慢
- **场景**：A6的Mel/CQT/Bark谱图
- **缓解方案**：
  - 使用`librosa`的`n_jobs`参数并行
  - 考虑`torchaudio`（GPU加速）

#### 3. **Bark谱图** ⬇️ **可能降低30-50%**
- **原因**：
  - MATLAB有内置优化
  - Python需手动实现Bark映射（纯Python循环）
- **场景**：A6的Bark通道
- **优化方案**：
  ```python
  # 使用NumPy向量化替代循环
  bark_spec = np.array([S[bark_idx[i]].sum(axis=0) for i in range(num_bands)])
  # 改为
  bark_spec = np.add.reduceat(S, bark_boundaries, axis=0)
  ```

#### 4. **启动时间** ⬇️ **增加2-5秒**
- **原因**：Python导入大型库（NumPy/SciPy）有开销
- **影响**：单次运行可忽略，频繁调用需注意

---

### 🔥 关键性能优化策略

#### 策略1：使用Numba JIT编译
```python
from numba import jit

@jit(nopython=True)
def td_sig_generate(freq, T, fs, amp0, phase0, delay, amp, phase):
    # 时域多径合成 - 加速50-100倍
    ...
```
- **适用**：嵌套循环密集的函数（tdsiggenerate、Bark映射）
- **提升**：50-100倍加速

#### 策略2：使用Cython重写瓶颈
```python
# cython_utils.pyx
cdef double[:] fast_bark_mapping(double[:,:] S, int[:] edges):
    # C级别性能
    ...
```
- **适用**：`.arr`文件解析、Bark谱图
- **提升**：10-50倍加速

#### 策略3：GPU加速（可选）
```python
import cupy as cp  # CUDA加速的NumPy

# FFT
X_gpu = cp.fft.fft(cp.asarray(signal))
# 谱图
import torchaudio
mel_spec = torchaudio.transforms.MelSpectrogram().cuda()
```
- **适用**：大批量谱图生成、FFT
- **提升**：5-20倍加速
- **成本**：需要NVIDIA GPU

#### 策略4：内存映射大文件
```python
import numpy as np

# 避免一次性加载大数组
data = np.load('large_file.npy', mmap_mode='r')
```
- **适用**：A4读取大量.arr、A5信号重构
- **提升**：减少70%内存占用

---

### 📊 综合性能评估

| 模块 | MATLAB基线 | Python(基础) | Python(优化) | 提升幅度 |
|------|-----------|-------------|-------------|--------|
| A1 频率分析 | 100% | 95% | **110%** | ⬆️ +10% |
| A2 频率筛选 | 100% | 105% | **120%** | ⬆️ +20% |
| A3 环境文件生成 | 100% | 110% | **150%** | ⬆️ +50% |
| A4 .arr读取 | 100% | 80% | **120%** (Cython) | ⬆️ +20% |
| A5 信号重构 | 100% | 90% | **140%** (Numba) | ⬆️ +40% |
| A6 谱图生成 | 100% | 85% | **95%** (GPU) | ⬇️ -5% |
| **整体流程** | **100%** | **~92%** | **~118%** | **⬆️ +18%** |

**注**：
- 基线100% = MATLAB运行时间
- 数值越大 = 速度越快
- 优化版本需额外工作量

---

### 💡 最终建议

#### ✅ **推荐转Python的理由**（非性能因素）

1. **生态系统更丰富**
   - 深度学习框架集成（PyTorch/TensorFlow）
   - 更多音频处理库（librosa/pydub/pedalboard）
   - Web API部署容易（Flask/FastAPI）

2. **开发效率更高**
   - 免费开源，无许可证限制
   - 更好的IDE支持（VSCode/PyCharm）
   - 包管理更方便（pip/conda）

3. **可移植性更强**
   - 跨平台一致性好
   - Docker部署简单
   - 云端计算友好（AWS Lambda/Google Cloud）

4. **协作更容易**
   - Git版本控制更自然
   - 代码审查工具丰富
   - 社区支持更活跃

#### ⚠️ **保留MATLAB的场景**

1. **快速原型验证**：MATLAB的交互式环境更友好
2. **复杂信号处理**：需要Simulink等专业工具
3. **团队已有MATLAB经验**：学习成本考量

---

### 🎯 性能优化路线图

**第一阶段**：基础转换（性能-8%）
- 直接翻译，保证功能正确
- 预计耗时：10天

**第二阶段**：向量化优化（性能+5%）
- 消除Python循环
- 使用NumPy广播
- 预计耗时：2天

**第三阶段**：并行优化（性能+15%）
- joblib并行化
- 多进程池管理
- 预计耗时：2天

**第四阶段**：高级优化（性能+25%）
- Numba/Cython重写瓶颈
- GPU加速（可选）
- 预计耗时：3-5天

**总计**：**17-19天达到18%性能提升**

---

## 🚀 开发建议

1. **渐进式开发**：先转换核心工具函数，再转换主流程
2. **持续测试**：每完成一个模块立即编写单元测试
3. **数值验证**：关键步骤与MATLAB结果对比（误差<1e-6）
4. **代码审查**：使用pylint/black进行代码质量检查
5. **版本控制**：每个阶段完成后打tag
6. **性能分析**：使用`cProfile`和`line_profiler`找出瓶颈

---

## 📅 预估工时

| 阶段 | 预估时间 | 优先级 |
|-----|---------|-------|
| 阶段1：环境准备 | 0.5天 | 🔴 高 |
| 阶段2：工具函数 | 2天 | 🔴 高 |
| 阶段3：主流程 | 5天 | 🔴 高 |
| 阶段4：验证工具 | 2天 | 🟡 中 |
| 阶段5：集成优化 | 2天 | 🟡 中 |
| 阶段6：文档部署 | 1天 | 🟢 低 |
| **总计** | **12.5天** | - |

---

## 📞 支持资源

- **MATLAB文档**：当前 `arr_test/` 目录
- **BELLHOP文档**：http://oalib.hlsresearch.com/Rays/
- **Librosa文档**：https://librosa.org/doc/latest/
- **Scipy文档**：https://docs.scipy.org/

---

**生成时间**：2025-12-01  
**版本**：v1.0  
**维护者**：待定
