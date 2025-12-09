"""
B1数据预处理示例

运行此脚本来预处理ETOPO和WOA23数据
"""

import sys
from pathlib import Path

# 添加项目路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from modules.B1_DataPreprocess import preprocess_all

if __name__ == '__main__':
    print("\n开始数据预处理...")
    print("这可能需要几分钟时间，请耐心等待...\n")
    
    preprocess_all()
    
    print("\n预处理完成！")
    print("现在可以使用预处理的数据来快速生成环境文件了。")
