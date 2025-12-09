"""
UASignalAugmentor - 水声信号处理与数据集生成系统

工具函数模块
"""

__version__ = '0.1.0'
__author__ = 'UASignalAugmentor Team'

# 只导入已存在的模块
from . import io_utils

# TODO: 待其他模块实现后取消注释
# from . import signal_processing
# from . import multipath_synthesis
# from . import spectrogram_generator
# from . import config_loader

__all__ = [
    'io_utils',
    # 'signal_processing',
    # 'multipath_synthesis',
    # 'spectrogram_generator',
    # 'config_loader',
]
