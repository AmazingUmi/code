"""
FrequencyAnalyzer使用示例

演示如何通过JSON配置文件使用频率分析器模块
"""

import sys
from pathlib import Path
import logging

# 添加项目根目录到路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from modules.A1_SignalAnalyzer import FrequencyAnalyzer
from utils.io_utils import load_json


def load_config_from_json():
    """从JSON文件加载配置"""
    config_file = project_root / 'config' / 'input_config.json'
    
    print(f"正在加载配置文件: {config_file}")
    
    if not config_file.exists():
        raise FileNotFoundError(f"配置文件不存在: {config_file}")
    
    config = load_json(config_file)
    print(f"配置加载成功！")
    print(f"  - 输入路径: {config['input_path']}")
    print(f"  - 输出路径: {config['output_path']}")
    print(f"  - 船舶类别: {config['ship_classes']}")
    print(f"  - 分段长度: {config['segment_length']}秒")
    print(f"  - 阈值: {config['threshold']}")
    
    return config


def main():
    """主函数：从JSON配置文件加载并运行"""
    print("=" * 60)
    print("FrequencyAnalyzer 频率分析器")
    print("从JSON配置文件加载参数")
    print("=" * 60)
    print()
    
    # 从JSON文件加载配置
    config = load_config_from_json()
    
    print("\n" + "=" * 60)
    print("开始频率分析...")
    print("=" * 60)
    
    # 创建分析器
    analyzer = FrequencyAnalyzer(config)
    
    # 执行分析
    result = analyzer.process()
    
    # 打印结果
    print("\n" + "=" * 60)
    print("处理完成!")
    print("=" * 60)
    print(f"  - 处理文件数: {result['num_files_processed']}")
    print(f"  - 唯一频率数: {result['num_unique_frequencies']}")
    print(f"  - 耗时: {result['elapsed_time']:.2f} 秒")
    
    if result['num_files_processed'] > 0:
        print(f"\n各类别统计:")
        for ship_class, stats in result['results_by_class'].items():
            print(f"  - {ship_class}: {stats['count']} 文件")
        
        print(f"\n频率范围: {result['global_frequencies'].min():.1f} - {result['global_frequencies'].max():.1f} Hz")
        print(f"\n输出文件保存在: {config['output_path']}")
        print(f"  - 单个文件结果: Class_X_filename.pkl")
        print(f"  - 全局频率列表: Analy_freq_all.pkl")


if __name__ == '__main__':
    # 设置日志
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # 运行主函数
    try:
        main()
    except FileNotFoundError as e:
        print(f"\n错误: {e}")
        print("请确保配置文件 'config/input_config.json' 存在。")
    except Exception as e:
        print(f"\n运行出错: {e}")
        import traceback
        traceback.print_exc()
