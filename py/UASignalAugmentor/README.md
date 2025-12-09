# UASignalAugmentor

**水声信号处理与数据集生成系统 (Underwater Acoustic Signal Augmentation)**

基于物理建模的船舶识别数据集生成工具，从MATLAB项目转换而来。

---

## 📁 项目结构

```
UASignalAugmentor/
├── modules/                      # 核心处理模块（业务逻辑）
│   ├── __init__.py
│   ├── frequency_analyzer.py     # A1: 音频频率分析模块
│   ├── frequency_filter.py       # A2: 频率成分筛选模块
│   ├── env_generator.py          # A3: BELLHOP环境文件生成模块
│   ├── arrival_reader.py         # A4: 声场计算结果读取模块
│   ├── signal_reconstructor.py   # A5: 接收信号重构模块
│   ├── spectrogram_builder.py    # A6: 三通道谱图生成模块
│   ├── validation.py             # B系列: 验证与对比分析
│   ├── augmentation.py           # C系列: 数据增强（噪声等）
│   └── dataset_organizer.py      # D系列: 数据集划分与组织
│
├── utils/                        # 底层工具函数（技术实现）
│   ├── __init__.py
│   ├── signal_processing.py      # 信号处理基础函数
│   ├── multipath_synthesis.py    # 多径信号合成算法
│   ├── spectrogram_generator.py  # 谱图生成算法
│   ├── io_utils.py               # 文件I/O工具
│   └── config_loader.py          # 配置加载器
│
├── cli/                          # 命令行接口
│   ├── __init__.py
│   └── commands.py               # CLI命令定义
│
├── config/                       # 配置文件
│   ├── config.yaml               # 主配置文件
│   └── paths.yaml                # 路径配置
│
├── tests/                        # 单元测试
│   ├── test_signal_processing.py
│   ├── test_multipath_synthesis.py
│   └── test_spectrogram.py
│
├── data/                         # 数据目录
│   ├── raw/                      # 原始音频
│   ├── processed/                # 处理后的频率数据
│   ├── signals/                  # 重构信号
│   └── spectrograms/             # 生成的谱图
│
├── docs/                         # 文档
│   └── API.md                    # API文档
│
├── logs/                         # 日志输出
│
├── output/                       # 最终输出
│   ├── train/                    # 训练集
│   ├── val/                      # 验证集
│   └── test/                     # 测试集
│
├── main.py                       # 主入口程序
├── README.md                     # 项目说明
├── requirements.txt              # 依赖包列表
└── .gitignore                    # Git忽略文件

```

---

## 🚀 快速开始

### 安装依赖
```bash
pip install -r requirements.txt
```

### 运行流程
```bash
# 方式1: 运行完整流程
python main.py pipeline --all

# 方式2: 运行单个模块
python main.py run frequency-analyzer --input data/raw/ --output data/processed/
python main.py run frequency-filter --input data/processed/ --output data/processed/
python main.py run env-generator --input data/processed/ --output envfiles/
# ...

# 方式3: Python API调用
from modules import FrequencyAnalyzer, FrequencyFilter
from pipeline import Pipeline

# 创建流水线
pipeline = Pipeline(config='config/config.yaml')
pipeline.run_all()  # 执行全部流程

# 或者单独调用模块
analyzer = FrequencyAnalyzer(config)
result = analyzer.process(input_path='data/raw/')
```

---

## 📊 数据流程

```
原始音频 (data/raw/)
    ↓ [A1: 频率分析]
频率数据 (data/processed/)
    ↓ [A2: 频率筛选]
筛选后频率 (data/processed/)
    ↓ [A3: 环境文件生成]
BELLHOP .env文件
    ↓ [C++并行计算]
声场结果 .arr文件
    ↓ [A4: 多径参数提取]
多径参数 (data/processed/)
    ↓ [A5: 信号重构]
接收信号 (data/signals/)
    ↓ [A6: 谱图生成]
三通道谱图 (data/spectrograms/)
    ↓ [D2: 数据集划分]
训练集/验证集/测试集 (output/)
```

---

## 🛠️ 技术栈

- **Python 3.9+**
- **NumPy**: 数值计算
- **SciPy**: 信号处理
- **Librosa**: 音频分析
- **Pillow**: 图像处理
- **Joblib**: 并行计算

---

## 📝 待完成

- [ ] 工具函数实现
- [ ] 主流程脚本转换
- [ ] 单元测试编写
- [ ] 配置文件创建
- [ ] 性能优化

---

## 📄 许可证

MIT License

---

## 👥 贡献者

转换自MATLAB项目: `G:\code\matlab\arr_test`
