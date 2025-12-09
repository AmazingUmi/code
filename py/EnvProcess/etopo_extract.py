"""
ETOPO2022数据提取函数
直接从MATLAB脚本转换: ref/ETOPO2022_Extract.m

用法:
    from etopo_extract import extract_etopo
    
    result = extract_etopo(
        LAT=[13.2-0.001, 14.53+0.001],
        LON=[114.46-0.001, 115.84+0.001],
        dirname=r'D:\database\others\海洋数据集\etopo2022\DATA'
    )
    
    # 保存为mat文件
    from scipy.io import savemat
    savemat('output.mat', result)
"""

import numpy as np
from pathlib import Path
from typing import Dict, List
import netCDF4 as nc
from tqdm import tqdm


def extract_etopo(LAT: List[float], LON: List[float], dirname: str) -> Dict:
    """
    从ETOPO2022 nc文件中提取区域数据
    
    直接对应MATLAB代码: ETOPO2022_Extract.m
    
    Args:
        LAT: [lat_min, lat_max] 纬度范围
        LON: [lon_min, lon_max] 经度范围
        dirname: ETOPO nc文件所在目录
        
    Returns:
        字典包含: {'Lon', 'Lat', 'Altitude', 'Dimension'}
        - Lon: 经度数组 (N,)
        - Lat: 纬度数组 (M,)
        - Altitude: 高程矩阵 (N, M) - Lon × Lat
        - Dimension: "Lon × Lat"
    """
    dirname = Path(dirname)
    
    # MATLAB: LAT_N = (15*(floor(LAT(1)/15)+1)):15:(15*ceil(LAT(2)/15));
    LAT_N_start = 15 * (int(np.floor(LAT[0] / 15)) + 1)
    LAT_N_end = 15 * int(np.ceil(LAT[1] / 15))
    LAT_N = list(range(LAT_N_start, LAT_N_end + 1, 15))
    
    # MATLAB: LON_N = (15*floor(LON(1)/15)):15:(15*(ceil(LON(2)/15)-1));
    LON_N_start = 15 * int(np.floor(LON[0] / 15))
    LON_N_end = 15 * (int(np.ceil(LON[1] / 15)) - 1)
    LON_N = list(range(LON_N_start, LON_N_end + 1, 15))
    
    # MATLAB: Lat1 = zeros(length(LAT_N)*3600, 1);
    Lat1 = np.zeros(len(LAT_N) * 3600)
    Lon1 = np.zeros(len(LON_N) * 3600)
    Z = np.zeros((len(LON_N) * 3600, len(LAT_N) * 3600))
    
    # MATLAB: for i_lat = 1:length(LAT_N)
    total_blocks = len(LAT_N) * len(LON_N)
    with tqdm(total=total_blocks, desc="提取ETOPO") as pbar:
        for i_lat in range(len(LAT_N)):
            for i_lon in range(len(LON_N)):
                # 生成文件名
                # MATLAB: if LAT_N(i_lat) >= 0
                if LAT_N[i_lat] >= 0:
                    lat_str = f'N{LAT_N[i_lat]:02d}'
                else:
                    lat_str = f'S{abs(LAT_N[i_lat]):02d}'
                
                if LON_N[i_lon] >= 0:
                    lon_str = f'E{LON_N[i_lon]:03d}'
                else:
                    lon_str = f'W{abs(LON_N[i_lon]):03d}'
                
                # MATLAB: filename = sprintf('ETOPO_2022_v1_15s_%s%s_surface.nc', lat_str, lon_str);
                filename = f'ETOPO_2022_v1_15s_{lat_str}{lon_str}_surface.nc'
                filepath = dirname / filename
                
                # MATLAB: lat = ncread([dirname, filename], 'lat');
                ds = nc.Dataset(str(filepath), 'r')
                lat = ds.variables['lat'][:]
                lon = ds.variables['lon'][:]
                z = ds.variables['z'][:]
                ds.close()
                
                # MATLAB索引从1开始，Python从0开始
                # MATLAB: if i_lat == 1
                if i_lat == 0:
                    # MATLAB: Lon1((i_lon-1)*3600+1:i_lon*3600) = lon;
                    Lon1[i_lon*3600:(i_lon+1)*3600] = lon
                
                # MATLAB: Z((i_lon-1)*3600+1:i_lon*3600, (i_lat-1)*3600+1:i_lat*3600) = z;
                Z[i_lon*3600:(i_lon+1)*3600, i_lat*3600:(i_lat+1)*3600] = z
                
                pbar.update(1)
            
            # MATLAB: Lat1((i_lat-1)*3600+1:i_lat*3600) = lat;
            Lat1[i_lat*3600:(i_lat+1)*3600] = lat
    
    # MATLAB: idx_x = Lon1>=LON(1) & Lon1<=LON(end);
    idx_x = (Lon1 >= LON[0]) & (Lon1 <= LON[-1])
    idx_y = (Lat1 >= LAT[0]) & (Lat1 <= LAT[-1])
    
    # MATLAB: Lon = Lon1(idx_x);
    Lon = Lon1[idx_x]
    Lat = Lat1[idx_y]
    # MATLAB: Altitude = Z(idx_x, idx_y);
    Altitude = Z[np.ix_(idx_x, idx_y)]
    
    print(f"\n提取完成: Lon {len(Lon)}点 × Lat {len(Lat)}点, 高程范围 [{Altitude.min():.1f}, {Altitude.max():.1f}] m")
    
    return {
        'Lon': Lon,
        'Lat': Lat,
        'Altitude': Altitude,
        'Dimension': 'Lon × Lat'
    }


if __name__ == '__main__':
    # 测试示例
    result = extract_etopo(
        LAT=[13.2-0.001, 14.53+0.001],
        LON=[114.46-0.001, 115.84+0.001],
        dirname=r'D:\database\others\OceanDataBase\etopo2022\DATA'
    )
    
    # 保存为npz
    np.savez_compressed('etopo_output.npz', **result)
    print("\n已保存到: etopo_output.npz")
