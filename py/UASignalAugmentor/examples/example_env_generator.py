"""
A2环境文件生成器示例

演示如何使用EnvGenerator生成BELLHOP环境文件
"""

import sys
from pathlib import Path

# 添加项目路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from modules.A2_EnvGenerator import EnvGenerator, generate_env_files, replicate_env_files
from utils.io_utils import load_json
import logging


# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)


def example_generate_template():
    """示例1: 生成环境文件模板（A22功能）"""
    print("\n" + "=" * 60)
    print("示例1: 生成环境文件模板（A22）")
    print("=" * 60 + "\n")
    
    try:
        # 使用便捷函数
        stats = generate_env_files()
        
        print("\n✅ 环境文件模板生成完成")
        print(f"统计信息: {stats}")
        
    except Exception as e:
        print(f"❌ 生成失败: {e}")
        import traceback
        traceback.print_exc()


def example_replicate_by_frequencies():
    """示例2: 基于频率批量复制（A3功能）"""
    print("\n" + "=" * 60)
    print("示例2: 基于频率批量复制（A3）")
    print("=" * 60 + "\n")
    
    try:
        # 假设频率列表文件路径
        freq_list_path = 'data/processed/Analy_freq_all.pkl'
        
        # 检查文件是否存在
        if not Path(freq_list_path).exists():
            print(f"⚠️ 频率列表文件不存在: {freq_list_path}")
            print("请先运行A1模块生成频率列表")
            return
        
        # 使用便捷函数
        stats = replicate_env_files(freq_list_path)
        
        print("\n✅ 环境文件批量复制完成")
        print(f"统计信息: {stats}")
        
    except Exception as e:
        print(f"❌ 复制失败: {e}")
        import traceback
        traceback.print_exc()


def example_custom_usage():
    """示例3: 自定义使用EnvGenerator类"""
    print("\n" + "=" * 60)
    print("示例3: 自定义使用EnvGenerator")
    print("=" * 60 + "\n")
    
    try:
        # 加载配置
        env_config = load_json('G:/code/py/UASignalAugmentor/config/env_data_config.json')
        coord_groups = load_json('G:/code/py/UASignalAugmentor/config/coordinate_groups.json')['coordinate_groups']
        acoustic_config = load_json('G:/code/py/UASignalAugmentor/config/acoustic_config.json')
        
        # 只处理前3个坐标组（测试用）
        coord_groups_test = coord_groups[:3]
        
        print(f"将处理 {len(coord_groups_test)} 个坐标组")
        
        # 创建生成器
        generator = EnvGenerator(env_config, coord_groups_test, acoustic_config)
        
        # 生成模板
        stats = generator.generate_template_envs()
        
        print("\n✅ 自定义生成完成")
        print(f"统计信息: {stats}")
        
    except Exception as e:
        print(f"❌ 生成失败: {e}")
        import traceback
        traceback.print_exc()


def main():
    """主函数"""
    print("\n" + "🌊" * 30)
    print("A2 环境文件生成器示例")
    print("🌊" * 30)
    
    # 提示用户选择
    print("\n请选择要运行的示例:")
    print("1. 生成环境文件模板（A22功能）")
    print("2. 基于频率批量复制（A3功能）")
    print("3. 自定义使用（仅处理前3个坐标组）")
    print("4. 运行所有示例")
    
    choice = input("\n请输入选项 (1/2/3/4): ").strip()
    
    if choice == '1':
        example_generate_template()
    elif choice == '2':
        example_replicate_by_frequencies()
    elif choice == '3':
        example_custom_usage()
    elif choice == '4':
        example_generate_template()
        example_replicate_by_frequencies()
    else:
        print("❌ 无效选项")
    
    print("\n" + "=" * 60)
    print("示例运行结束")
    print("=" * 60)


if __name__ == '__main__':
    main()
