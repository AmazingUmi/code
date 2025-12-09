"""
A2_EnvGenerator - 环境文件生成器

功能：
- A22: 生成原始BELLHOP环境文件（.env/.bty/.trc/.brc/.ssp）
- A3: 基于频率批量复制环境文件

参考MATLAB脚本：
- A22origin_ENVmake.m
- A3envfilmade.m
"""

from pathlib import Path
from typing import Dict, List, Optional, Tuple
import numpy as np
import shutil
import logging
from tqdm import tqdm

from utils.env_processor import (
    load_env_data, coord_proc, get_env, sound_speed
)
from utils.bellhop_writer import (
    write_env, write_bty, write_ssp, write_trc, write_brc
)
from utils.io_utils import load_json, load_pickle, ensure_dir


logger = logging.getLogger(__name__)


class EnvGenerator:
    """
    环境文件生成器
    
    对应MATLAB: A22origin_ENVmake.m + A3envfilmade.m
    
    配置参数：
    - env_data_config: 环境数据配置（ETOPO/WOA23路径）
    - coordinate_groups: 经纬度组配置
    - acoustic_config: 声场计算配置
    """
    
    def __init__(self, env_data_config: Dict, coordinate_groups: List[Dict], 
                 acoustic_config: Dict):
        """
        初始化环境文件生成器
        
        Args:
            env_data_config: 环境数据配置字典
            coordinate_groups: 经纬度组列表
            acoustic_config: 声场计算配置字典
        """
        self.env_data_config = env_data_config
        self.coordinate_groups = coordinate_groups
        self.acoustic_config = acoustic_config
        
        # 加载环境数据
        logger.info("正在加载环境数据...")
        self.etopo, self.woa23 = load_env_data(env_data_config)
        logger.info("环境数据加载完成")
        
        # 解析配置
        self.output_path = Path(acoustic_config['output_path'])
        self.source_depth = acoustic_config['source']['depth']
        self.source_range = acoustic_config['source']['range']
        self.azimuth = acoustic_config['azimuth']
        self.bellhop_params = acoustic_config['bellhop_params']
        self.time_idx = env_data_config['woa23']['time_index']
    
    def generate_template_envs(self) -> Dict:
        """
        生成原始环境文件模板（A22功能）
        
        对应MATLAB: A22origin_ENVmake.m
        
        Returns:
            统计信息字典
        """
        logger.info("=" * 60)
        logger.info("开始生成环境文件模板（A22）")
        logger.info("=" * 60)
        
        stats = {
            'total_groups': len(self.coordinate_groups),
            'total_files': 0,
            'success': 0,
            'failed': 0
        }
        
        # 遍历每个坐标组
        for coord_group in tqdm(self.coordinate_groups, desc="处理坐标组"):
            group_id = coord_group['group_id']
            logger.info(f"\n处理坐标组: {group_id}")
            
            try:
                self._generate_group_env(coord_group)
                stats['success'] += len(coord_group['receive_ranges'])
                stats['total_files'] += len(coord_group['receive_ranges'])
            except Exception as e:
                logger.error(f"处理坐标组 {group_id} 失败: {e}")
                stats['failed'] += len(coord_group['receive_ranges'])
                stats['total_files'] += len(coord_group['receive_ranges'])
        
        logger.info("\n" + "=" * 60)
        logger.info("环境文件模板生成完成")
        logger.info(f"总坐标组: {stats['total_groups']}")
        logger.info(f"总文件数: {stats['total_files']}")
        logger.info(f"成功: {stats['success']}")
        logger.info(f"失败: {stats['failed']}")
        logger.info("=" * 60)
        
        return stats
    
    def _generate_group_env(self, coord_group: Dict) -> None:
        """
        为单个坐标组生成环境文件
        
        Args:
            coord_group: 坐标组配置
        """
        group_id = coord_group['group_id']
        coord_s = {'lat': coord_group['lat'], 'lon': coord_group['lon']}
        receive_ranges = coord_group['receive_ranges']
        receive_depths = coord_group['receive_depths']
        
        # 创建输出目录
        group_folder = self.output_path / coord_group['zone_type'] / group_id
        
        # 遍历每个接收距离
        for j, rr in enumerate(receive_ranges, start=1):
            logger.info(f"  生成 Rr{j} (距离={rr}km)")
            
            # 创建子目录
            rr_folder = group_folder / f"Rr{j}" / "envfilefolder"
            ensure_dir(rr_folder)
            
            # 坐标转换
            max_range = max(receive_ranges)
            coord_e_lat, coord_e_lon = coord_proc(coord_s, [max_range], self.azimuth)
            
            # 构造测线上的经纬度数组
            N = max(int(max_range) + 1, 2)
            lat_arr = np.linspace(coord_s['lat'], coord_e_lat[0], N)
            lon_arr = np.linspace(coord_s['lon'], coord_e_lon[0], N)
            
            # 提取环境数据
            sea_depth, ssp_raw, SSProf = get_env(
                self.etopo, self.woa23, lat_arr, lon_arr, self.time_idx
            )
            
            # 计算海深地形
            bathm = {
                'r': np.linspace(0, max_range, N) - self.source_range,
                'd': sea_depth
            }
            
            # 构造BELLHOP参数
            Zmax = int(np.ceil(np.max(sea_depth)))
            ssp_top = ssp_raw[0, 1]  # 表层声速
            ssp_bot = ssp_raw[-1, 1]  # 底层声速
            
            # 构造SSP结构
            ssp = self._build_ssp_struct(ssp_raw, Zmax)
            
            # 构造边界条件
            bdry = self._build_boundary(ssp_top, ssp_bot)
            
            # 构造位置参数
            pos = {
                's': {'z': [self.source_depth]},
                'r': {
                    'z': receive_depths,
                    'range': [rr]
                }
            }
            
            # 构造波束参数
            beam = self._build_beam(Zmax, max_range)
            
            # 生成文件名
            envfil = rr_folder / f"ENV_{group_id}_Rr{rr}Km"
            
            # 生成BELLHOP文件
            title = f'Acoustic Calculation {group_id}_Rr{rr}Km'
            freq = self.bellhop_params['freq']
            
            write_env(
                str(envfil), 'BELLHOP', title, freq,
                ssp, bdry, pos, beam, max_range
            )
            write_bty(str(envfil), "'LS'", bathm)
            write_ssp(str(envfil), bathm['r'], SSProf['c'])
            
            # 生成反射系数文件
            freqvec = [freq]  # 暂时用单频
            write_trc(freqvec, ssp_top, self.bellhop_params['sea_state_level'], str(envfil))
            write_brc(
                self.bellhop_params['base_type'], str(envfil), 
                freqvec, ssp_bot, self.bellhop_params['alpha_b']
            )
            
            logger.info(f"    已生成环境文件: {envfil.name}")
    
    def _build_ssp_struct(self, ssp_raw: np.ndarray, Zmax: int) -> Dict:
        """
        构造声速剖面结构
        
        Args:
            ssp_raw: 原始声速剖面 [[depth, sound_speed], ...]
            Zmax: 最大深度
            
        Returns:
            SSP结构字典
        """
        return {
            'NMedia': 1,
            'N': [0],
            'sigma': [0],
            'depth': [0, ssp_raw[-1, 0]],
            'raw': [{
                'z': ssp_raw[:, 0],
                'alphaR': ssp_raw[:, 1],
                'betaR': np.zeros(len(ssp_raw)),
                'rho': np.ones(len(ssp_raw)),
                'alphaI': np.zeros(len(ssp_raw)),
                'betaI': np.zeros(len(ssp_raw))
            }]
        }
    
    def _build_boundary(self, ssp_top: float, ssp_bot: float) -> Dict:
        """
        构造边界条件
        
        Args:
            ssp_top: 表层声速
            ssp_bot: 底层声速
            
        Returns:
            边界条件字典
        """
        return {
            'Top': {
                'Opt': self.bellhop_params['top_option']
            },
            'Bot': {
                'Opt': self.bellhop_params['bottom_option'],
                'HS': {
                    'alphaR': 1500,
                    'betaR': 0,
                    'rho': 1,
                    'alphaI': 0,
                    'betaI': 0
                }
            }
        }
    
    def _build_beam(self, Zmax: int, rmax: float) -> Dict:
        """
        构造波束参数
        
        Args:
            Zmax: 最大深度
            rmax: 最大距离
            
        Returns:
            波束参数字典
        """
        beam_opt = self.bellhop_params['beam_option']
        
        return {
            'RunType': self.bellhop_params['run_type'],
            'Nbeams': 0,
            'alpha': [-90, 90],
            'deltas': 0,
            'Box': {
                'z': Zmax + 500,
                'r': rmax + 1
            },
            'epmult': beam_opt['epmult'],
            'rLoop': beam_opt['rLoop'],
            'Nimage': beam_opt['Nimage'],
            'Ibwin': beam_opt['Ibwin'],
            'Type': beam_opt['type']
        }
    
    def replicate_by_frequencies(self, freq_list_path: str) -> Dict:
        """
        基于频率列表批量复制环境文件（A3功能）
        
        对应MATLAB: A3envfilmade.m
        
        Args:
            freq_list_path: A1输出的频率列表文件路径（Analy_freq_all.pkl）
            
        Returns:
            统计信息字典
        """
        logger.info("=" * 60)
        logger.info("开始批量复制环境文件（A3）")
        logger.info("=" * 60)
        
        # 读取频率列表
        freq_data = load_pickle(freq_list_path)
        freq_list = freq_data  # 假设直接是频率数组
        
        logger.info(f"频率列表: {len(freq_list)} 个频率")
        
        stats = {
            'total_folders': 0,
            'total_files': 0,
            'success': 0,
            'failed': 0
        }
        
        # 遍历所有zone类型
        for zone_type in ['Shallow', 'Transition', 'Deep']:
            zone_path = self.output_path / zone_type
            
            if not zone_path.exists():
                continue
            
            # 遍历每个ENV文件夹
            for env_folder in zone_path.glob('ENV*'):
                # 遍历每个Rr文件夹
                for rr_folder in env_folder.glob('Rr*'):
                    env_file_folder = rr_folder / 'envfilefolder'
                    
                    if not env_file_folder.exists():
                        continue
                    
                    logger.info(f"处理: {env_file_folder.relative_to(self.output_path)}")
                    stats['total_folders'] += 1
                    
                    try:
                        self._replicate_folder(env_file_folder, freq_list)
                        stats['success'] += len(freq_list)
                        stats['total_files'] += len(freq_list)
                    except Exception as e:
                        logger.error(f"复制失败: {e}")
                        stats['failed'] += len(freq_list)
                        stats['total_files'] += len(freq_list)
        
        logger.info("\n" + "=" * 60)
        logger.info("批量复制完成")
        logger.info(f"处理文件夹: {stats['total_folders']}")
        logger.info(f"生成文件: {stats['total_files']}")
        logger.info(f"成功: {stats['success']}")
        logger.info(f"失败: {stats['failed']}")
        logger.info("=" * 60)
        
        return stats
    
    def _replicate_folder(self, folder: Path, freq_list: List[float]) -> None:
        """
        为单个文件夹复制环境文件
        
        Args:
            folder: 环境文件文件夹
            freq_list: 频率列表
        """
        # 查找模板.env文件
        env_files = list(folder.glob('ENV_*.env'))
        
        if not env_files:
            logger.warning(f"未找到模板.env文件: {folder}")
            return
        
        template_env = env_files[0]
        template_base = template_env.stem  # 不含扩展名
        
        # 读取模板文件
        with open(template_env, 'r', encoding='utf-8') as f:
            baselines = f.readlines()
        
        # 为每个频率生成文件
        file_list = []
        
        for i, freq in enumerate(freq_list, start=1):
            new_name = f'test_{i}'
            file_list.append(new_name)
            
            # 修改第2行（频率行）
            lines = baselines.copy()
            lines[1] = f"  {freq}  \t\t\t ! Frequency (Hz) \n"
            
            # 写入新.env文件
            new_env = folder / f'{new_name}.env'
            with open(new_env, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            
            # 复制辅助文件
            for ext in ['.trc', '.bty', '.brc', '.ssp']:
                src = folder / f'{template_base}{ext}'
                if src.exists():
                    dst = folder / f'{new_name}{ext}'
                    shutil.copy2(src, dst)
        
        # 生成文件列表
        list_file = folder / 'env_files_list.txt'
        with open(list_file, 'w', encoding='utf-8') as f:
            for name in file_list:
                f.write(f'{name}\n')
        
        logger.info(f"  生成 {len(file_list)} 个环境文件")


# ==================== 便捷函数 ====================

def generate_env_files(env_config_path: str = 'config/env_data_config.json',
                       coord_config_path: str = 'config/coordinate_groups.json',
                       acoustic_config_path: str = 'config/acoustic_config.json') -> Dict:
    """
    便捷函数：生成环境文件
    
    Args:
        env_config_path: 环境数据配置文件路径
        coord_config_path: 坐标组配置文件路径
        acoustic_config_path: 声场配置文件路径
        
    Returns:
        统计信息
    """
    # 加载配置
    env_config = load_json(env_config_path)
    coord_groups = load_json(coord_config_path)['coordinate_groups']
    acoustic_config = load_json(acoustic_config_path)
    
    # 生成环境文件
    generator = EnvGenerator(env_config, coord_groups, acoustic_config)
    return generator.generate_template_envs()


def replicate_env_files(freq_list_path: str,
                        env_config_path: str = 'config/env_data_config.json',
                        coord_config_path: str = 'config/coordinate_groups.json',
                        acoustic_config_path: str = 'config/acoustic_config.json') -> Dict:
    """
    便捷函数：批量复制环境文件
    
    Args:
        freq_list_path: 频率列表文件路径
        env_config_path: 环境数据配置文件路径
        coord_config_path: 坐标组配置文件路径
        acoustic_config_path: 声场配置文件路径
        
    Returns:
        统计信息
    """
    # 加载配置
    env_config = load_json(env_config_path)
    coord_groups = load_json(coord_config_path)['coordinate_groups']
    acoustic_config = load_json(acoustic_config_path)
    
    # 复制环境文件
    generator = EnvGenerator(env_config, coord_groups, acoustic_config)
    return generator.replicate_by_frequencies(freq_list_path)
