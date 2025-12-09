"""
B1 数据预处理模块

功能：
- 从原始ETOPO和WOA23 NetCDF文件中读取目标经纬度范围的数据
- 计算声速剖面
- 保存为Python友好的格式（.npz）

数据源：
- ETOPO: D:/database/others/海洋数据集/etopo2022/DATA
- WOA23: D:/database/others/海洋数据集/WOA23

输出：
- G:/code/py/UASignalAugmentor/data/etopo_processed.npz
- G:/code/py/UASignalAugmentor/data/woa23_processed.npz
"""

import sys
from pathlib import Path
from typing import Dict, Tuple, Optional, List
import numpy as np
import logging
from tqdm import tqdm

# 尝试导入netCDF4
try:
    import netCDF4 as nc
except ImportError:
    print("警告: netCDF4未安装，尝试使用xarray")
    try:
        import xarray as xr
        USE_XARRAY = True
    except ImportError:
        print("错误: 需要安装 netCDF4 或 xarray")
        print("请运行: pip install netCDF4 或 pip install xarray")
        sys.exit(1)
else:
    USE_XARRAY = False

# 添加项目路径以导入sound_speed函数
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))


logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


# ==================== 配置 ====================

# 硬编码路径
ETOPO_DIR = Path("D:/database/others/海洋数据集/etopo2022/DATA")
WOA23_DIR = Path("D:/database/others/海洋数据集/WOA23")
OUTPUT_DIR = Path("G:/code/py/UASignalAugmentor/data")

# 目标经纬度范围（覆盖所有坐标组的范围 + 余量）
TARGET_LAT_RANGE = [5.0, 25.0]   # 南海区域
TARGET_LON_RANGE = [105.0, 125.0]

# ETOPO分块参数
ETOPO_GRID_SIZE = 15  # ETOPO按15°×15°分块
ETOPO_POINTS_PER_DEGREE = 240  # 15s分辨率: 3600点/15° = 240点/°


# ==================== ETOPO处理 ====================

def get_etopo_grid_blocks(lat_range: List[float], lon_range: List[float]) -> Tuple[List[int], List[int]]:
    """
    计算需要读取的ETOPO网格块
    
    ETOPO数据按15°×15°分块存储，文件名如: ETOPO_2022_v1_15s_N15E105_surface.nc
    
    Args:
        lat_range: [min_lat, max_lat]
        lon_range: [min_lon, max_lon]
        
    Returns:
        (lat_blocks, lon_blocks): 需要读取的纬度和经度块列表
    """
    # 计算覆盖范围的网格块
    # LAT_N = (15*(floor(LAT(1)/15)+1)):15:(15*ceil(LAT(2)/15))
    lat_start_block = 15 * (int(np.floor(lat_range[0] / 15)) + 1)
    lat_end_block = 15 * int(np.ceil(lat_range[1] / 15))
    lat_blocks = list(range(lat_start_block, lat_end_block + 1, 15))
    
    # LON_N = (15*floor(LON(1)/15)):15:(15*(ceil(LON(2)/15)-1))
    lon_start_block = 15 * int(np.floor(lon_range[0] / 15))
    lon_end_block = 15 * (int(np.ceil(lon_range[1] / 15)) - 1)
    lon_blocks = list(range(lon_start_block, lon_end_block + 1, 15))
    
    logger.info(f"ETOPO网格块: 纬度 {lat_blocks}, 经度 {lon_blocks}")
    return lat_blocks, lon_blocks


def get_etopo_filename(lat_block: int, lon_block: int) -> str:
    """
    生成ETOPO文件名
    
    格式: ETOPO_2022_v1_15s_N15E105_surface.nc
    
    Args:
        lat_block: 纬度块 (0, 15, 30, ...)
        lon_block: 经度块 (0, 15, 30, ...)
        
    Returns:
        文件名
    """
    # 纬度标识
    if lat_block >= 0:
        lat_str = f"N{abs(lat_block):02d}"
    else:
        lat_str = f"S{abs(lat_block):02d}"
    
    # 经度标识
    if lon_block >= 0:
        lon_str = f"E{abs(lon_block):03d}"
    else:
        lon_str = f"W{abs(lon_block):03d}"
    
    return f"ETOPO_2022_v1_15s_{lat_str}{lon_str}_surface.nc"


def process_etopo(lat_range: List[float], lon_range: List[float]) -> Dict:
    """
    处理ETOPO数据，提取目标范围
    
    参考MATLAB代码，按15°×15°网格块拼接数据
    
    Args:
        lat_range: [min_lat, max_lat]
        lon_range: [min_lon, max_lon]
        
    Returns:
        包含lat, lon, elevation的字典
    """
    logger.info("\n" + "="*80)
    logger.info("处理ETOPO数据")
    logger.info("="*80)
    logger.info(f"目标范围: lat [{lat_range[0]}, {lat_range[1]}], lon [{lon_range[0]}, {lon_range[1]}]")
    
    # 获取需要读取的网格块
    lat_blocks, lon_blocks = get_etopo_grid_blocks(lat_range, lon_range)
    
    # 每个15°块包含3600个点 (15s分辨率)
    points_per_block = 3600
    
    # 初始化数组
    total_lon_points = len(lon_blocks) * points_per_block
    total_lat_points = len(lat_blocks) * points_per_block
    
    Lat1 = np.zeros(total_lat_points)
    Lon1 = np.zeros(total_lon_points)
    Z = np.zeros((total_lon_points, total_lat_points))
    
    logger.info(f"初始化数组: {total_lon_points} x {total_lat_points}")
    
    # 读取并拼接所有网格块
    with tqdm(total=len(lat_blocks) * len(lon_blocks), desc="读取ETOPO块") as pbar:
        for i_lat, lat_block in enumerate(lat_blocks):
            for i_lon, lon_block in enumerate(lon_blocks):
                filename = get_etopo_filename(lat_block, lon_block)
                filepath = ETOPO_DIR / filename
                
                if not filepath.exists():
                    logger.warning(f"文件不存在: {filename}")
                    pbar.update(1)
                    continue
                
                try:
                    # 读取nc文件
                    if USE_XARRAY:
                        ds = xr.open_dataset(filepath)
                        lat = ds['lat'].values
                        lon = ds['lon'].values
                        z = ds['z'].values
                        ds.close()
                    else:
                        ds = nc.Dataset(filepath, 'r')
                        lat = ds.variables['lat'][:]
                        lon = ds.variables['lon'][:]
                        z = ds.variables['z'][:]
                        ds.close()
                    
                    # 填充数据 (MATLAB索引从1开始，Python从0开始)
                    lon_start = i_lon * points_per_block
                    lon_end = (i_lon + 1) * points_per_block
                    lat_start = i_lat * points_per_block
                    lat_end = (i_lat + 1) * points_per_block
                    
                    # 第一次读取经度时保存
                    if i_lat == 0:
                        Lon1[lon_start:lon_end] = lon
                    
                    # 填充高程数据 (注意：z是(lon, lat)维度)
                    Z[lon_start:lon_end, lat_start:lat_end] = z
                    
                except Exception as e:
                    logger.error(f"读取 {filename} 失败: {e}")
                
                pbar.update(1)
            
            # 每读完一行块，保存纬度
            lat_start = i_lat * points_per_block
            lat_end = (i_lat + 1) * points_per_block
            if filepath.exists():  # 使用最后读取的lat
                Lat1[lat_start:lat_end] = lat
    
    # 裁剪到目标范围
    logger.info("裁剪到目标范围...")
    idx_lon = (Lon1 >= lon_range[0]) & (Lon1 <= lon_range[1])
    idx_lat = (Lat1 >= lat_range[0]) & (Lat1 <= lat_range[1])
    
    Lon = Lon1[idx_lon]
    Lat = Lat1[idx_lat]
    Altitude = Z[np.ix_(idx_lon, idx_lat)]  # 二维索引
    
    logger.info(f"裁剪后范围: lat [{Lat.min():.4f}, {Lat.max():.4f}], lon [{Lon.min():.4f}, {Lon.max():.4f}]")
    logger.info(f"数据形状: {Altitude.shape}")
    logger.info(f"高程范围: [{Altitude.min():.1f}, {Altitude.max():.1f}]m")
    
    # 转换为海深（负的高程 = 正的海深）
    sea_depth = -Altitude
    sea_depth = np.maximum(sea_depth, 0)  # 陆地区域设为0
    
    return {
        'lat': Lat,
        'lon': Lon,
        'elevation': Altitude,
        'sea_depth': sea_depth,
        'metadata': {
            'source': str(ETOPO_DIR),
            'lat_range': lat_range,
            'lon_range': lon_range,
            'resolution': '15s',
            'dimension': 'Lon × Lat'
        }
    }


# ==================== WOA23处理 ====================

def get_woa23_filename(time_idx: int, data_type: str) -> str:
    """
    生成WOA23文件名
    
    格式: woa23_decav91C0_s00_04.nc (盐度), woa23_decav91C0_t00_04.nc (温度)
    
    Args:
        time_idx: 时间索引 (0-16)
        data_type: 's' (盐度) 或 't' (温度)
        
    Returns:
        文件名
    """
    return f"woa23_decav91C0_{data_type}{time_idx:02d}_04.nc"


def process_woa23(lat_range: List[float], lon_range: List[float]) -> Dict:
    """
    处理WOA23数据，提取目标范围并计算声速剖面
    
    参考MATLAB代码，读取温度和盐度nc文件，直接计算声速剖面
    
    Args:
        lat_range: [min_lat, max_lat]
        lon_range: [min_lon, max_lon]
        
    Returns:
        包含所有时间索引的声速剖面数据
    """
    logger.info("\n" + "="*80)
    logger.info("处理WOA23数据")
    logger.info("="*80)
    logger.info(f"目标范围: lat [{lat_range[0]}, {lat_range[1]}], lon [{lon_range[0]}, {lon_range[1]}]")
    
    # 导入声速计算函数
    from utils.env_processor import sound_speed
    
    # 存储所有时间索引的数据
    woa23_data = {
        'time_indices': list(range(0, 17))  # 0-16 (对应MATLAB的0:16)
    }
    
    # 第一次读取，获取经纬度和深度信息
    sal_file = WOA23_DIR / get_woa23_filename(0, 's')
    
    if not sal_file.exists():
        logger.warning(f"WOA23文件不存在: {sal_file}")
        logger.warning("将创建示例数据")
        return create_dummy_woa23(lat_range, lon_range)
    
    logger.info(f"读取参考文件: {sal_file.name}")
    
    # 读取经纬度和深度
    if USE_XARRAY:
        ds = xr.open_dataset(sal_file)
        lon_woa = ds['lon'].values
        lat_woa = ds['lat'].values
        depth_woa = ds['depth'].values
        ds.close()
    else:
        ds = nc.Dataset(sal_file, 'r')
        lon_woa = ds.variables['lon'][:]
        lat_woa = ds.variables['lat'][:]
        depth_woa = ds.variables['depth'][:]
        ds.close()
    
    # 找到目标范围的索引
    lat_idx = (lat_woa >= lat_range[0]) & (lat_woa <= lat_range[1])
    lon_idx = (lon_woa >= lon_range[0]) & (lon_woa <= lon_range[1])
    
    Lat = lat_woa[lat_idx]
    Lon = lon_woa[lon_idx]
    Depth = depth_woa
    
    logger.info(f"裁剪后范围: lat [{Lat.min():.4f}, {Lat.max():.4f}], lon [{Lon.min():.4f}, {Lon.max():.4f}]")
    logger.info(f"网格大小: {len(Lon)} x {len(Lat)}")
    logger.info(f"深度层数: {len(Depth)}")
    logger.info(f"深度范围: [{Depth.min():.1f}, {Depth.max():.1f}]m")
    
    # 保存到字典
    woa23_data['lat'] = Lat
    woa23_data['lon'] = Lon
    woa23_data['depth'] = Depth
    
    # 读取所有时间索引的数据并计算声速 (0-16)
    logger.info("\n读取所有时间索引的温盐数据并计算声速剖面...")
    with tqdm(total=17, desc="处理WOA23") as pbar:
        for time_idx in range(0, 17):
            sal_file = WOA23_DIR / get_woa23_filename(time_idx, 's')
            temp_file = WOA23_DIR / get_woa23_filename(time_idx, 't')
            
            if not sal_file.exists() or not temp_file.exists():
                logger.warning(f"时间索引 {time_idx} 文件缺失，跳过")
                pbar.update(1)
                continue
            
            try:
                # 读取盐度数据
                if USE_XARRAY:
                    ds_sal = xr.open_dataset(sal_file)
                    Sal = ds_sal['s_an'].values  # s_an: salinity analyzed
                    ds_sal.close()
                    
                    ds_temp = xr.open_dataset(temp_file)
                    Temp = ds_temp['t_an'].values  # t_an: temperature analyzed
                    ds_temp.close()
                else:
                    ds_sal = nc.Dataset(sal_file, 'r')
                    Sal = ds_sal.variables['s_an'][:]
                    ds_sal.close()
                    
                    ds_temp = nc.Dataset(temp_file, 'r')
                    Temp = ds_temp.variables['t_an'][:]
                    ds_temp.close()
                
                # 裁剪到目标范围
                # MATLAB: Sal(lon_idx, lat_idx, :)
                # Python需要使用np.ix_进行高级索引
                Sal = Sal[np.ix_(lon_idx, lat_idx, np.arange(len(Depth)))]
                Temp = Temp[np.ix_(lon_idx, lat_idx, np.arange(len(Depth)))]
                
                # 计算声速剖面
                # 创建深度网格 (Nlon, Nlat, Ndepth)
                Nlon, Nlat, Ndepth = Temp.shape
                depth_grid = np.tile(Depth, (Nlon, Nlat, 1))
                
                # 使用声速公式计算
                # C = 1449.2 + 4.6*T - 0.055*T^2 + 0.00029*T^3 + (1.34-0.01*T)*(S-35) + 0.017*D
                SoundSpeed = sound_speed(Temp, Sal, depth_grid)
                
                # 保存 (MATLAB索引0-16 对应 Python存储键1-17)
                # 为了与后续使用保持一致，时间索引+1
                storage_idx = time_idx + 1
                woa23_data[f'sound_speed_{storage_idx}'] = SoundSpeed
                
            except Exception as e:
                logger.error(f"处理时间索引 {time_idx} 失败: {e}")
                import traceback
                traceback.print_exc()
            
            pbar.update(1)
    
    logger.info(f"\n✓ WOA23数据处理完成")
    logger.info(f"  经度点数: {len(Lon)}")
    logger.info(f"  纬度点数: {len(Lat)}")
    logger.info(f"  深度层数: {len(Depth)}")
    logger.info(f"  时间索引: 1-17 (对应MATLAB的0-16)")
    logger.info(f"  声速剖面形状: ({Nlon}, {Nlat}, {Ndepth})")
    
    return woa23_data


def create_dummy_woa23(lat_range: List[float], lon_range: List[float]) -> Dict:
    """创建示例WOA23数据（用于测试）"""
    logger.info("创建示例WOA23数据...")
    
    # 创建网格
    lat = np.linspace(lat_range[0], lat_range[1], 80)
    lon = np.linspace(lon_range[0], lon_range[1], 80)
    depth = np.array([0, 10, 20, 30, 50, 75, 100, 125, 150, 200, 250, 300, 400, 500,
                      600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500])
    
    # 创建温度和盐度数据（简单模型）
    nlat, nlon, ndepth = len(lat), len(lon), len(depth)
    
    data = {
        'lat': lat,
        'lon': lon,
        'depth': depth,
        'time_indices': list(range(1, 18))
    }
    
    # 为每个时间索引创建数据
    for time_idx in range(1, 18):
        # 温度: 表层高，深层低
        temp = 28 - depth / 100  # 简单线性递减
        temp = np.clip(temp, 2, 30)
        
        # 盐度: 相对恒定
        sal = 34.5 + 0.5 * (depth / 5500)
        
        # 扩展为3D (lat, lon, depth)
        temp_3d = np.tile(temp, (nlat, nlon, 1))
        sal_3d = np.tile(sal, (nlat, nlon, 1))
        
        data[f'temp_{time_idx}'] = temp_3d
        data[f'sal_{time_idx}'] = sal_3d
    
    logger.info(f"示例数据: lat {nlat}x lon {nlon}x depth {ndepth}")
    
    return data


# ==================== 保存 ====================

def save_processed_data(etopo_data: Dict, woa23_data: Dict):
    """保存处理好的数据"""
    logger.info("\n" + "="*80)
    logger.info("保存处理后的数据")
    logger.info("="*80)
    
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # 保存ETOPO
    etopo_file = OUTPUT_DIR / "etopo_processed.npz"
    np.savez_compressed(
        etopo_file,
        lat=etopo_data['lat'],
        lon=etopo_data['lon'],
        elevation=etopo_data['elevation'],
        sea_depth=etopo_data['sea_depth'],
        metadata=str(etopo_data['metadata'])
    )
    logger.info(f"✓ ETOPO保存到: {etopo_file}")
    logger.info(f"  文件大小: {etopo_file.stat().st_size / 1024 / 1024:.2f} MB")
    
    # 保存WOA23
    woa23_file = OUTPUT_DIR / "woa23_processed.npz"
    
    # 构建保存字典
    save_dict = {
        'lat': woa23_data['lat'],
        'lon': woa23_data['lon'],
        'depth': woa23_data['depth']
    }
    
    # 添加所有时间索引的声速剖面数据 (1-17)
    for time_idx in range(1, 18):
        if f'sound_speed_{time_idx}' in woa23_data:
            save_dict[f'sound_speed_{time_idx}'] = woa23_data[f'sound_speed_{time_idx}']
    
    np.savez_compressed(woa23_file, **save_dict)
    logger.info(f"✓ WOA23保存到: {woa23_file}")
    logger.info(f"  文件大小: {woa23_file.stat().st_size / 1024 / 1024:.2f} MB")


# ==================== 主函数 ====================

def preprocess_all():
    """执行完整的预处理流程"""
    logger.info("\n" + "🚀"*40)
    logger.info("B1 数据预处理模块")
    logger.info("🚀"*40)
    
    try:
        # 1. 处理ETOPO
        etopo_data = process_etopo(TARGET_LAT_RANGE, TARGET_LON_RANGE)
        
        # 2. 处理WOA23
        woa23_data = process_woa23(TARGET_LAT_RANGE, TARGET_LON_RANGE)
        
        # 3. 保存
        save_processed_data(etopo_data, woa23_data)
        
        logger.info("\n" + "="*80)
        logger.info("✓ 预处理完成！")
        logger.info("="*80)
        logger.info(f"输出目录: {OUTPUT_DIR}")
        logger.info(f"  - etopo_processed.npz")
        logger.info(f"  - woa23_processed.npz")
        
    except Exception as e:
        logger.error(f"预处理失败: {e}")
        import traceback
        traceback.print_exc()
        raise


if __name__ == '__main__':
    preprocess_all()
