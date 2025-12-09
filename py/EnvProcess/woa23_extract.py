r"""
WOA23数据提取函数
直接从MATLAB脚本转换: ref/WOA23_Extract.m

用法:
    from woa23_extract import extract_woa23
    
    extract_woa23(
        LAT=[10.875-0.001, 32.125+0.001],
        LON=[116.875-0.001, 149.125+0.001],
        woa23_dir=r'D:\database\others\OceanDataBase\WOA23',
        output_dir='./output'
    )
"""

import numpy as np
from pathlib import Path
from typing import List
import netCDF4 as nc
from tqdm import tqdm


def sound_speed(Temp: np.ndarray, Sal: np.ndarray, depth: np.ndarray) -> np.ndarray:
    """
    计算声速
    
    MATLAB代码中的公式:
    C = 1449.2 + 4.6*T - 0.055*T^2 + 0.00029*T^3 + (1.34-0.01*T)*(S-35) + 0.017*D
    
    Args:
        Temp: 温度 (°C)
        Sal: 盐度 (psu)
        depth: 深度 (m)
        
    Returns:
        声速 (m/s)
    """
    # 处理NaN值，避免计算溢出
    T = np.where(np.isnan(Temp), 0, Temp)
    S = np.where(np.isnan(Sal), 35, Sal)
    D = depth
    
    # 使用np.float64确保精度，避免溢出
    T = T.astype(np.float64)
    S = S.astype(np.float64)
    D = D.astype(np.float64)
    
    C = (1449.2 + 4.6*T - 0.055*T**2 + 0.00029*T**3 + 
         (1.34 - 0.01*T)*(S - 35) + 0.017*D)
    
    # 将无效数据恢复为NaN
    C = np.where(np.isnan(Temp) | np.isnan(Sal), np.nan, C)
    
    return C


def extract_woa23(LAT: List[float], LON: List[float], 
                  woa23_dir: str, output_dir: str = './WOA23_mat',
                  time_indices: List[int] = None):
    """
    从WOA23 nc文件中提取区域数据并保存
    
    直接对应MATLAB代码: WOA23_Extract.m
    
    Args:
        LAT: [lat_min, lat_max] 纬度范围
        LON: [lon_min, lon_max] 经度范围
        woa23_dir: WOA23 nc文件所在目录
        output_dir: 输出目录（保存npz文件）
        time_indices: 要提取的时间索引列表，默认为0-16（全部）
        
    说明:
        为每个时间索引生成独立的npz文件
        文件名: woa23_00.npz, woa23_01.npz, ..., woa23_16.npz
        每个文件包含: Sal, Temp, Lat, Lon, Depth, SoundSpeed
        
        数据维度:
        - Sal, Temp, SoundSpeed: (Nlon, Nlat, Ndepth) - 经度×纬度×深度
        - Lat: (Nlat,) - 纬度数组
        - Lon: (Nlon,) - 经度数组
        - Depth: (Ndepth,) - 深度数组
    """
    woa23_dir = Path(woa23_dir)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 默认提取所有时间索引
    if time_indices is None:
        time_indices = list(range(0, 17))
    
    # MATLAB: for timeIdx = 0:16
    success_count = 0
    with tqdm(time_indices, desc="提取WOA23") as pbar:
        for timeIdx in pbar:
            # MATLAB: sal_file = sprintf('woa23_decav91C0_s%02d_04.nc', timeIdx);
            sal_file = woa23_dir / f'woa23_decav91C0_s{timeIdx:02d}_04.nc'
            temp_file = woa23_dir / f'woa23_decav91C0_t{timeIdx:02d}_04.nc'
            
            if not sal_file.exists() or not temp_file.exists():
                continue
        
            # MATLAB: lon_woa = ncread(sal_file, 'lon');
            ds_sal = nc.Dataset(str(sal_file), 'r')
            lon_woa = ds_sal.variables['lon'][:]
            lat_woa = ds_sal.variables['lat'][:]
            depth_woa = ds_sal.variables['depth'][:]
            
            # MATLAB: Sal = ncread(sal_file, 's_an');
            # 注意: nc文件维度是 (time, depth, lat, lon)，需要去掉time维度并转置
            Sal_nc = ds_sal.variables['s_an'][:]  # shape: (1, 102, 720, 1440)
            ds_sal.close()
            
            # MATLAB: Temp = ncread(temp_file, 't_an');
            ds_temp = nc.Dataset(str(temp_file), 'r')
            Temp_nc = ds_temp.variables['t_an'][:]  # shape: (1, 102, 720, 1440)
            ds_temp.close()
            
            # 去掉time维度: (1, depth, lat, lon) -> (depth, lat, lon)
            Sal_nc = Sal_nc[0, :, :, :]
            Temp_nc = Temp_nc[0, :, :, :]
            
            # MATLAB中ncread自动转置，这里需要手动转置为 (lon, lat, depth)
            # (depth, lat, lon) -> (lon, lat, depth)
            Sal_full = np.transpose(Sal_nc, (2, 1, 0))
            Temp_full = np.transpose(Temp_nc, (2, 1, 0))
            
            # MATLAB: lat_idx = (lat_woa >= LAT(1)) & (lat_woa <= LAT(end));
            lat_idx = (lat_woa >= LAT[0]) & (lat_woa <= LAT[-1])
            lon_idx = (lon_woa >= LON[0]) & (lon_woa <= LON[-1])
            
            # MATLAB: Sal = Sal(lon_idx, lat_idx, :);
            # 现在Sal_full是 (lon, lat, depth)，与MATLAB一致
            Sal = Sal_full[np.ix_(lon_idx, lat_idx, np.arange(len(depth_woa)))]
            Temp = Temp_full[np.ix_(lon_idx, lat_idx, np.arange(len(depth_woa)))]
            
            # MATLAB: Lat = lat_woa(lat_idx);
            Lat = lat_woa[lat_idx]
            Lon = lon_woa[lon_idx]
            Depth = depth_woa
            
            # 计算声速剖面
            # 创建深度网格 (lon, lat, depth)
            Nlon, Nlat, Ndepth = Temp.shape
            depth_grid = np.tile(Depth, (Nlon, Nlat, 1))
            
            # 使用声速公式计算 SSP
            SoundSpeed = sound_speed(Temp, Sal, depth_grid)
            
            # 保存为npz文件
            # MATLAB: save(sprintf('./WOA23_mat/woa23_%02d.mat',timeIdx),'Sal','Temp','Lat','Lon','Depth');
            output_file = output_dir / f'woa23_{timeIdx:02d}.npz'
            np.savez_compressed(
                output_file,
                Sal=Sal,
                Temp=Temp,
                Lat=Lat,
                Lon=Lon,
                Depth=Depth,
                SoundSpeed=SoundSpeed  # 添加声速剖面
            )
            success_count += 1
    
    print(f"\n提取完成: 成功处理 {success_count}/{len(time_indices)} 个时间索引")
    print(f"输出目录: {output_dir}")


if __name__ == '__main__':
    # 测试示例
    extract_woa23(
        LAT=[10.875-0.001, 32.125+0.001],
        LON=[116.875-0.001, 149.125+0.001],
        woa23_dir=r'D:\database\others\OceanDataBase\WOA23',
        output_dir=r'D:\database\others\OceanDataBase\pytest_dir\WOA23_mat',
        time_indices=list(range(0, 17))  # 可指定特定索引，如 [0, 1, 16]
    )
