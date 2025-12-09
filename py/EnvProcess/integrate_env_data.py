"""
环境数据整合脚本
整合ETOPO海深数据和WOA23声速剖面数据，将声速剖面插值到ETOPO网格上

功能:
1. 提取ETOPO2022海深数据（高分辨率网格）
2. 提取WOA23温盐数据并计算声速剖面
3. 将声速剖面从WOA23网格插值到ETOPO网格
4. 保存整合后的数据：经度、纬度、海深、声速剖面

用法:
    python integrate_env_data.py
    
或者在脚本中导入使用:
    from integrate_env_data import integrate_env_data
    
    integrate_env_data(
        LAT=[13.0, 15.0],
        LON=[114.0, 116.0],
        etopo_dir=r'D:\database\others\OceanDataBase\etopo2022\DATA',
        woa23_dir=r'D:\database\others\OceanDataBase\WOA23',
        output_file='integrated_env_data.npz',
        time_index=0
    )
"""

import numpy as np
from pathlib import Path
from typing import List, Dict
from scipy.interpolate import RegularGridInterpolator
from etopo_extract import extract_etopo
from woa23_extract import sound_speed  # 复用已有的声速计算函数
import netCDF4 as nc
from tqdm import tqdm


def extract_woa23_single(LAT: List[float], LON: List[float], 
                         woa23_dir: str, time_index: int = 0) -> Dict:
    """
    提取单个时间索引的WOA23数据并计算声速剖面
    
    Args:
        LAT: [lat_min, lat_max] 纬度范围
        LON: [lon_min, lon_max] 经度范围
        woa23_dir: WOA23 nc文件所在目录
        time_index: 时间索引 (0-16)，默认0表示年平均
        
    Returns:
        字典包含: {'Lon', 'Lat', 'Depth', 'Sal', 'Temp', 'SoundSpeed'}
        - Lon: 经度数组 (Nlon,)
        - Lat: 纬度数组 (Nlat,)
        - Depth: 深度数组 (Ndepth,)
        - Sal: 盐度 (Nlon, Nlat, Ndepth)
        - Temp: 温度 (Nlon, Nlat, Ndepth)
        - SoundSpeed: 声速 (Nlon, Nlat, Ndepth)
    """
    woa23_dir = Path(woa23_dir)
    
    sal_file = woa23_dir / f'woa23_decav91C0_s{time_index:02d}_04.nc'
    temp_file = woa23_dir / f'woa23_decav91C0_t{time_index:02d}_04.nc'
    
    if not sal_file.exists() or not temp_file.exists():
        raise FileNotFoundError(f"WOA23文件不存在: {sal_file} 或 {temp_file}")
    
    print(f"读取WOA23数据 (时间索引 {time_index})...")
    
    # 读取盐度数据
    ds_sal = nc.Dataset(str(sal_file), 'r')
    lon_woa = ds_sal.variables['lon'][:]
    lat_woa = ds_sal.variables['lat'][:]
    depth_woa = ds_sal.variables['depth'][:]
    Sal_nc = ds_sal.variables['s_an'][:]
    ds_sal.close()
    
    # 读取温度数据
    ds_temp = nc.Dataset(str(temp_file), 'r')
    Temp_nc = ds_temp.variables['t_an'][:]
    ds_temp.close()
    
    # 去掉time维度并转置: (1, depth, lat, lon) -> (lon, lat, depth)
    Sal_full = np.transpose(Sal_nc[0, :, :, :], (2, 1, 0))
    Temp_full = np.transpose(Temp_nc[0, :, :, :], (2, 1, 0))
    
    # 提取区域
    lat_idx = (lat_woa >= LAT[0]) & (lat_woa <= LAT[-1])
    lon_idx = (lon_woa >= LON[0]) & (lon_woa <= LON[-1])
    
    Sal = Sal_full[np.ix_(lon_idx, lat_idx, np.arange(len(depth_woa)))]
    Temp = Temp_full[np.ix_(lon_idx, lat_idx, np.arange(len(depth_woa)))]
    
    Lat = lat_woa[lat_idx]
    Lon = lon_woa[lon_idx]
    Depth = depth_woa
    
    # 计算声速剖面
    print("计算声速剖面...")
    Nlon, Nlat, Ndepth = Temp.shape
    depth_grid = np.tile(Depth, (Nlon, Nlat, 1))
    SoundSpeed = sound_speed(Temp, Sal, depth_grid)
    
    print(f"WOA23数据提取完成: Lon {len(Lon)}点 × Lat {len(Lat)}点 × Depth {len(Depth)}层")
    
    return {
        'Lon': Lon,
        'Lat': Lat,
        'Depth': Depth,
        'Sal': Sal,
        'Temp': Temp,
        'SoundSpeed': SoundSpeed
    }


def interpolate_ssp_to_grid(woa_data: Dict, target_lon: np.ndarray, target_lat: np.ndarray) -> np.ndarray:
    """
    将声速剖面从WOA23网格插值到目标网格（ETOPO网格）
    
    Args:
        woa_data: WOA23数据字典，包含 Lon, Lat, Depth, SoundSpeed
        target_lon: 目标经度网格 (N,)
        target_lat: 目标纬度网格 (M,)
        
    Returns:
        插值后的声速剖面 (N, M, Ndepth)
    """
    print("将声速剖面插值到ETOPO网格...")
    
    woa_lon = woa_data['Lon']
    woa_lat = woa_data['Lat']
    woa_depth = woa_data['Depth']
    woa_ssp = woa_data['SoundSpeed']  # (Nlon_woa, Nlat_woa, Ndepth)
    
    Ndepth = len(woa_depth)
    Nlon_target = len(target_lon)
    Nlat_target = len(target_lat)
    
    # 初始化输出数组
    ssp_interpolated = np.zeros((Nlon_target, Nlat_target, Ndepth))
    
    # 对每个深度层进行2D插值
    with tqdm(total=Ndepth, desc="插值声速剖面") as pbar:
        for i_depth in range(Ndepth):
            # 提取当前深度层的声速数据
            ssp_layer = woa_ssp[:, :, i_depth]  # (Nlon_woa, Nlat_woa)
            
            # 创建2D插值器
            # 注意: RegularGridInterpolator要求输入点按升序排列
            interpolator = RegularGridInterpolator(
                (woa_lon, woa_lat), 
                ssp_layer,
                method='linear',
                bounds_error=False,
                fill_value=np.nan
            )
            
            # 创建目标网格点
            lon_grid, lat_grid = np.meshgrid(target_lon, target_lat, indexing='ij')
            points = np.column_stack([lon_grid.ravel(), lat_grid.ravel()])
            
            # 执行插值
            ssp_interp = interpolator(points)
            ssp_interpolated[:, :, i_depth] = ssp_interp.reshape(Nlon_target, Nlat_target)
            
            pbar.update(1)
    
    print(f"插值完成: {Nlon_target} × {Nlat_target} × {Ndepth}")
    
    return ssp_interpolated


def integrate_env_data(LAT: List[float], LON: List[float],
                       etopo_dir: str, woa23_dir: str,
                       output_file: str = 'integrated_env_data.npz',
                       time_index: int = 0):
    """
    整合ETOPO和WOA23数据，生成包含经纬度、海深、声速剖面的数据文件
    
    Args:
        LAT: [lat_min, lat_max] 纬度范围
        LON: [lon_min, lon_max] 经度范围
        etopo_dir: ETOPO2022 nc文件所在目录
        woa23_dir: WOA23 nc文件所在目录
        output_file: 输出文件名
        time_index: WOA23时间索引 (0-16)，0表示年平均
        
    输出文件包含:
        - Lon: 经度数组 (N,)
        - Lat: 纬度数组 (M,)
        - Depth: 深度数组 (K,) - 来自WOA23
        - Bathymetry: 海深矩阵 (N, M) - 来自ETOPO
        - SoundSpeed: 声速剖面 (N, M, K) - 插值到ETOPO网格
        - Metadata: 元数据字符串
    """
    print("="*60)
    print("环境数据整合脚本")
    print("="*60)
    print(f"区域范围: 纬度 {LAT}, 经度 {LON}")
    print(f"WOA23时间索引: {time_index} (0=年平均, 1-12=月份, 13-16=季节)")
    print()
    
    # 步骤1: 提取ETOPO海深数据
    print("[1/4] 提取ETOPO海深数据...")
    etopo_data = extract_etopo(LAT=LAT, LON=LON, dirname=etopo_dir)
    
    # 步骤2: 提取WOA23声速剖面
    print("\n[2/4] 提取WOA23数据并计算声速剖面...")
    woa_data = extract_woa23_single(LAT=LAT, LON=LON, woa23_dir=woa23_dir, time_index=time_index)
    
    # 步骤3: 插值声速剖面到ETOPO网格
    print("\n[3/4] 插值声速剖面到ETOPO网格...")
    ssp_interpolated = interpolate_ssp_to_grid(
        woa_data,
        target_lon=etopo_data['Lon'],
        target_lat=etopo_data['Lat']
    )
    
    # 步骤4: 保存整合数据
    print("\n[4/4] 保存整合数据...")
    
    # 准备元数据
    metadata = {
        'description': '整合的海洋环境数据',
        'lat_range': LAT,
        'lon_range': LON,
        'woa23_time_index': time_index,
        'dimensions': f'Lon({len(etopo_data["Lon"])}) × Lat({len(etopo_data["Lat"])}) × Depth({len(woa_data["Depth"])})',
        'bathymetry_source': 'ETOPO2022',
        'ssp_source': 'WOA23 (插值)',
        'bathymetry_range': f'[{etopo_data["Altitude"].min():.1f}, {etopo_data["Altitude"].max():.1f}] m',
    }
    
    # 保存为npz文件
    np.savez_compressed(
        output_file,
        Lon=etopo_data['Lon'],
        Lat=etopo_data['Lat'],
        Depth=woa_data['Depth'],
        Bathymetry=etopo_data['Altitude'],  # 海深数据 (负值表示水深)
        SoundSpeed=ssp_interpolated,  # 声速剖面 (N, M, K)
        metadata=str(metadata)
    )
    
    print(f"\n整合完成！数据已保存到: {output_file}")
    print("\n数据摘要:")
    print(f"  经度: {len(etopo_data['Lon'])} 点, 范围 [{etopo_data['Lon'].min():.4f}, {etopo_data['Lon'].max():.4f}]")
    print(f"  纬度: {len(etopo_data['Lat'])} 点, 范围 [{etopo_data['Lat'].min():.4f}, {etopo_data['Lat'].max():.4f}]")
    print(f"  深度: {len(woa_data['Depth'])} 层, 范围 [{woa_data['Depth'].min():.1f}, {woa_data['Depth'].max():.1f}] m")
    print(f"  海深: 范围 [{etopo_data['Altitude'].min():.1f}, {etopo_data['Altitude'].max():.1f}] m")
    print(f"  声速: 范围 [{np.nanmin(ssp_interpolated):.2f}, {np.nanmax(ssp_interpolated):.2f}] m/s")
    print()
    print("数据格式说明:")
    print("  - Lon: 经度数组 (N,)")
    print("  - Lat: 纬度数组 (M,)")
    print("  - Depth: 深度数组 (K,)")
    print("  - Bathymetry: 海深矩阵 (N, M), 负值表示水深")
    print("  - SoundSpeed: 声速剖面 (N, M, K)")
    print()
    print("读取示例:")
    print("  data = np.load('integrated_env_data.npz')")
    print("  lon = data['Lon']")
    print("  lat = data['Lat']")
    print("  depth = data['Depth']")
    print("  bathymetry = data['Bathymetry']")
    print("  sound_speed = data['SoundSpeed']")
    print("="*60)


if __name__ == '__main__':
    # 示例使用
    integrate_env_data(
        LAT=[5, 25],  # 纬度范围
        LON=[105, 125],  # 经度范围
        etopo_dir=r'D:\database\others\OceanDataBase\etopo2022\DATA',
        woa23_dir=r'D:\database\others\OceanDataBase\WOA23',
        output_file=r'D:\database\others\OceanDataBase\pytest_dir\integrated_env_data.npz',
        time_index=0  # 0=年平均, 1-12=月份, 13-16=季节
    )
