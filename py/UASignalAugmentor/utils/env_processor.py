"""
环境数据处理工具

功能：
- 加载ETOPO地形数据和WOA23声速剖面数据
- 坐标转换（起点+距离+方位角 → 终点经纬度）
- 提取海深地形和声速剖面
- 声速计算

参考MATLAB函数：
- load_data_new.m
- coord_proc_new.m
- get_env_new.m
- sound_speed.m
- get_bathm.m
- get_profile_filled.m
"""

from pathlib import Path
from typing import Dict, Tuple, Optional, List
import numpy as np
from scipy.io import loadmat
from scipy.interpolate import interp1d
import logging


logger = logging.getLogger(__name__)


# ==================== 数据加载 ====================

def load_etopo(file_path: str) -> Dict:
    """
    加载ETOPO地形数据
    
    对应MATLAB: load_data_new.m (ETOPO部分)
    
    Args:
        file_path: ETOPO .mat文件路径
        
    Returns:
        包含地形数据的字典
    """
    try:
        etopo = loadmat(file_path)
        logger.info(f"成功加载ETOPO数据: {file_path}")
        return etopo
    except Exception as e:
        logger.error(f"加载ETOPO数据失败: {e}")
        raise


def load_woa23(folder_path: str, time_index: int = 1) -> Dict:
    """
    加载WOA23声速剖面数据
    
    对应MATLAB: load_data_new.m (WOA23部分)
    
    Args:
        folder_path: WOA23 .mat文件夹路径
        time_index: 时间索引 (1-12:月度, 13-16:季度, 00:年度)
        
    Returns:
        包含WOA23数据的字典:
        {
            'Lat': 纬度数组,
            'Lon': 经度数组,
            'Data': [17个时间索引的数据] (每个包含Depth/Sal/Temp)
        }
    """
    folder = Path(folder_path)
    
    # 读取经纬度信息（全年数据）
    woa23_00 = loadmat(folder / 'woa23_00.mat')
    woa23 = {
        'Lat': woa23_00['Lat'],
        'Lon': woa23_00['Lon'],
        'Data': []
    }
    
    # 文件名映射: 索引1-17 对应文件名 01-12, 13-16, 00
    file_ids = list(range(1, 13)) + [13, 14, 15, 16, 0]
    
    for file_id in file_ids:
        filename = f'woa23_{file_id:02d}.mat'
        data = loadmat(folder / filename)
        woa23['Data'].append({
            'Depth': data['Depth'],
            'Sal': data['Sal'],
            'Temp': data['Temp']
        })
    
    logger.info(f"成功加载WOA23数据: {folder_path}, 共{len(woa23['Data'])}个时间索引")
    return woa23


# ==================== 坐标转换 ====================

def coord_proc(coord_s: Dict[str, float], R: List[float], azi: float) -> Tuple[np.ndarray, np.ndarray]:
    """
    坐标转换：起点 + 距离 + 方位角 → 终点经纬度数组
    
    对应MATLAB: coord_proc_new.m
    
    公式:
    - lon_end = lon_start + R * sin(azi) / (111 * cos(lat_start/180*π))
    - lat_end = lat_start + R * cos(azi) / 111
    
    Args:
        coord_s: 起点坐标 {'lat': 纬度, 'lon': 经度}
        R: 距离数组 (km)
        azi: 方位角 (度, 正北为0°, 顺时针)
        
    Returns:
        (lat_end_array, lon_end_array): 终点纬度和经度数组
    """
    lat_s = coord_s['lat']
    lon_s = coord_s['lon']
    
    # 转换为弧度
    azi_rad = azi / 180 * np.pi
    lat_s_rad = lat_s / 180 * np.pi
    
    R_array = np.array(R)
    
    # 计算终点坐标
    lon_end = lon_s + R_array * np.sin(azi_rad) / (111 * np.cos(lat_s_rad))
    lat_end = lat_s + R_array * np.cos(azi_rad) / 111
    
    return lat_end, lon_end


# ==================== 声速计算 ====================

def sound_speed(temp: np.ndarray, sal: np.ndarray, depth: np.ndarray) -> np.ndarray:
    """
    使用经典声速经验公式计算声速
    
    对应MATLAB: sound_speed.m
    参考: COA 1.2节
    
    公式:
    C = 1449.2 + 4.6*T - 0.055*T^2 + 0.00029*T^3 + 
        (1.34-0.01*T)*(S-35) + 0.017*D
    
    Args:
        temp: 温度 (°C)
        sal: 盐度 (psu)
        depth: 深度 (m)
        
    Returns:
        声速 (m/s)
    """
    T = temp
    S = sal
    D = depth
    
    C = (1449.2 + 4.6 * T - 0.055 * T**2 + 0.00029 * T**3 +
         (1.34 - 0.01 * T) * (S - 35) + 0.017 * D)
    
    return C


# ==================== 海深地形提取 ====================

def get_bathm(etopo: Dict, lat: np.ndarray, lon: np.ndarray) -> np.ndarray:
    """
    从ETOPO数据集中提取指定经纬度的海深数据
    
    对应MATLAB: get_bathm.m
    
    Args:
        etopo: ETOPO数据字典，包含 'Lat', 'Lon', 'Altitude' 字段
        lat: 纬度数组
        lon: 经度数组
        
    Returns:
        海深数组 (m, 正值表示深度)
    """
    from scipy.interpolate import interp2d, RectBivariateSpline
    
    # 提取ETOPO数据
    etopo_lat = etopo['Lat'].flatten()  # 纬度数组
    etopo_lon = etopo['Lon'].flatten()  # 经度数组
    etopo_alt = etopo['Altitude']        # 高程矩阵 (负值表示海下)
    
    # 确保经纬度是一维数组
    if etopo_lat.ndim > 1:
        etopo_lat = etopo_lat.flatten()
    if etopo_lon.ndim > 1:
        etopo_lon = etopo_lon.flatten()
    
    # 使用RectBivariateSpline进行2D插值 (更快且更稳定)
    # MATLAB的interp2 对应 scipy的 RectBivariateSpline
    # 注意: ETOPO.Altitude 在MATLAB中需要转置
    
    # 如果etopo_alt的shape不匹配，需要转置
    if etopo_alt.shape[0] == len(etopo_lon) and etopo_alt.shape[1] == len(etopo_lat):
        etopo_alt = etopo_alt.T
    
    # 创建插值函数
    interp_func = RectBivariateSpline(etopo_lat, etopo_lon, etopo_alt, kx=1, ky=1)
    
    # 对输入的经纬度进行插值
    # 注意: RectBivariateSpline 的输入顺序是 (lat, lon)
    altitude = interp_func(lat, lon, grid=False)
    
    # 转换为海深 (负的高程 = 正的海深)
    sea_depth = -altitude
    
    # 确保海深为正值 (有些陆地点可能为负)
    sea_depth = np.maximum(sea_depth, 0)
    
    logger.info(f"ETOPO插值: 经纬度点数={len(lat)}, 海深范围=[{sea_depth.min():.1f}, {sea_depth.max():.1f}]m")
    
    return sea_depth


# ==================== 温盐剖面提取 ====================

def get_profile_filled(woa23: Dict, lat: np.ndarray, lon: np.ndarray, 
                       time_idx: int, max_depth: Optional[float] = None) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    从WOA23数据集中提取并填充温盐剖面
    
    对应MATLAB: get_profile_filled.m
    
    注意：
    - 1-12月份的剖面深度为1500m
    - 季度/全年平均的剖面深度为5500m
    - 提取1-12月份时，1500m以下用全年数据填充
    - WOA数据结构: Temp/Sal 为 (Nlat, Nlon, Ndepth)
    - Lat/Lon/Depth 为列向量 (N, 1)
    - 如果指定max_depth，只提取不超过该深度的数据层
    
    Args:
        woa23: WOA23数据字典
        lat: 纬度数组 (Npoints,)
        lon: 经度数组 (Npoints,)
        time_idx: 时间索引 (1-17)
        max_depth: 最大深度 (m)，如果指定则截断到该深度
        
    Returns:
        (Temp, Sal, Depth): 温度矩阵, 盐度矩阵, 深度数组
        Temp/Sal shape: (Ndepth, Nlon)
    """
    from scipy.interpolate import RectBivariateSpline
    
    # 数据集经纬度 - 展平为1D数组
    Lat = woa23['Lat'].flatten()  # (Nlat,)
    Lon = woa23['Lon'].flatten()  # (Nlon,)
    
    # 调试：打印数据范围
    logger.info(f"WOA数据范围: Lat=[{Lat.min():.2f}, {Lat.max():.2f}], Lon=[{Lon.min():.2f}, {Lon.max():.2f}]")
    logger.info(f"查询点范围: lat=[{lat.min():.2f}, {lat.max():.2f}], lon=[{lon.min():.2f}, {lon.max():.2f}]")
    
    # 根据时间索引选择数据
    if time_idx <= 12:
        # 月度数据：用全年数据填充深层
        # Python索引: MATLAB的1-17 对应 Python的0-16
        annual_data = woa23['Data'][16]  # MATLAB索引17 -> Python索引16
        month_data = woa23['Data'][time_idx - 1]  # MATLAB索引1-12 -> Python索引0-11
        
        # 使用全年数据作为基础
        TEMP = annual_data['Temp'].copy()  # (Nlat, Nlon, Ndepth_annual)
        SAL = annual_data['Sal'].copy()
        Depth = annual_data['Depth'].flatten()  # 使用全年的深度数组
        
        # 获取月度数据
        month_temp = month_data['Temp']  # (Nlat, Nlon, Ndepth_month)
        month_sal = month_data['Sal']
        Nd_month = month_data['Depth'].size
        
        # MATLAB: TEMP(:,:,1:Nd) = WOA18.Data{timeIdx}.Temp(:,:,:)
        # 用月度数据的所有层替换浅层部分（前Nd_month层）
        TEMP[:, :, :Nd_month] = month_temp
        SAL[:, :, :Nd_month] = month_sal
        
        logger.info(f"月度数据填充: 月度层数={Nd_month}, 全年层数={len(Depth)}")
    else:
        # 季度或全年数据
        data = woa23['Data'][time_idx - 1]
        TEMP = data['Temp']  # (Nlat, Nlon, Ndepth)
        SAL = data['Sal']
        Depth = data['Depth'].flatten()
    
    # 对每个深度层进行插值
    Nd = len(Depth)
    
    # 如果指定了max_depth，只处理不超过该深度的层
    if max_depth is not None:
        # 找到不超过max_depth的最大索引
        valid_depth_mask = Depth <= max_depth
        if not valid_depth_mask.any():
            logger.warning(f"所有深度层都超过max_depth={max_depth}m，使用第一层")
            Nd_use = 1
        else:
            Nd_use = np.where(valid_depth_mask)[0][-1] + 1  # +1因为是索引转长度
        
        # 截断数据
        TEMP = TEMP[:, :, :Nd_use]
        SAL = SAL[:, :, :Nd_use]
        Depth = Depth[:Nd_use]
        Nd = Nd_use
        
        logger.info(f"根据max_depth={max_depth:.1f}m截断: 使用{Nd}层 (最大深度{Depth[-1]:.1f}m)")
    
    Nlon = len(lon)
    
    Temp = np.zeros((Nd, Nlon))
    Sal = np.zeros((Nd, Nlon))
    
    # MATLAB代码分析:
    # [LON,LAT] = meshgrid(Lon,Lat)  % LON shape=(Nlat,Nlon), LAT shape=(Nlat,Nlon)
    # Temp(id,:,:) = interp2(LON,LAT,TEMP(:,:,id)',lon,lat)
    # 
    # interp2(X,Y,V,Xq,Yq):
    #   X,Y: 网格坐标
    #   V: 在网格上的值（转置后是(Nlon,Nlat)）
    #   Xq,Yq: 查询点坐标
    #
    # 关键：TEMP(:,:,id)' 将(Nlat,Nlon)转置为(Nlon,Nlat)
    # meshgrid(Lon,Lat)生成的网格中，LON的每一行都是Lon，LAT的每一列都是Lat
    
    # 对每个深度层进行2D插值
    for id in range(Nd):
        # 提取该深度层的数据 (Nlat, Nlon)
        temp_slice = TEMP[:, :, id]
        sal_slice = SAL[:, :, id]
        
        # RectBivariateSpline(x, y, z) 要求 z.shape = (len(x), len(y))
        # 我们有: temp_slice.shape = (Nlat, Nlon)
        # 所以: x=Lat (Nlat,), y=Lon (Nlon,)
        
        try:
            # 检查NaN比例
            nan_ratio = np.isnan(temp_slice).sum() / temp_slice.size
            if nan_ratio > 0.9:
                logger.warning(f"深度 {Depth[id]:.1f}m 数据大部分为NaN ({nan_ratio*100:.1f}%)，跳过")
                Temp[id, :] = np.nan
                Sal[id, :] = np.nan
                continue
            
            # 创建插值函数
            # 注意：RectBivariateSpline不能处理NaN，需要用griddata或者填充NaN
            # 简化方案：如果有NaN，暂时用最近邻填充
            if np.any(np.isnan(temp_slice)):
                # 使用最近邻填充NaN（简单方案）
                from scipy.ndimage import generic_filter
                temp_filled = temp_slice.copy()
                sal_filled = sal_slice.copy()
                
                # 用均值填充NaN
                temp_filled[np.isnan(temp_filled)] = np.nanmean(temp_filled)
                sal_filled[np.isnan(sal_filled)] = np.nanmean(sal_filled)
            else:
                temp_filled = temp_slice
                sal_filled = sal_slice
            
            temp_interp = RectBivariateSpline(Lat, Lon, temp_filled, kx=1, ky=1)
            sal_interp = RectBivariateSpline(Lat, Lon, sal_filled, kx=1, ky=1)
            
            # 插值到指定经纬度点
            # MATLAB: interp2(LON, LAT, TEMP', lon, lat)
            # 输入的lon, lat是向量，输出也是向量
            Temp[id, :] = temp_interp(lat, lon, grid=False)
            Sal[id, :] = sal_interp(lat, lon, grid=False)
            
        except Exception as e:
            logger.warning(f"深度 {Depth[id]:.1f}m 插值失败: {e}")
            import traceback
            traceback.print_exc()
            # 使用NaN填充
            Temp[id, :] = np.nan
            Sal[id, :] = np.nan
    
    logger.info(f"WOA23插值完成: 时间索引={time_idx}, 深度层数={Nd}, 经纬度点数={Nlon}")
    if not np.all(np.isnan(Temp)):
        logger.info(f"  温度范围: [{np.nanmin(Temp):.2f}, {np.nanmax(Temp):.2f}]°C")
        logger.info(f"  盐度范围: [{np.nanmin(Sal):.2f}, {np.nanmax(Sal):.2f}] psu")
    
    return Temp, Sal, Depth


# ==================== 环境数据提取 ====================

def get_env(etopo: Dict, woa23: Dict, lat: np.ndarray, lon: np.ndarray, 
            time_idx: int = 1) -> Tuple[np.ndarray, np.ndarray, Dict]:
    """
    从数据集中获得指定直线区间上的海深和声速剖面
    
    对应MATLAB: get_env_new.m
    
    Args:
        etopo: ETOPO地形数据
        woa23: WOA23声速剖面数据
        lat: 纬度数组 (区间上的多个点)
        lon: 经度数组 (区间上的多个点)
        time_idx: 声速剖面月份选择 (1-17)
        
    Returns:
        (seaDepth, ssp_raw, SSProf):
        - seaDepth: 海深数组 (m)
        - ssp_raw: 区间平均声速剖面 [[depth, sound_speed], ...]
        - SSProf: 区间多点声速剖面 {'z': depth_array, 'c': sound_speed_matrix}
    """
    # 1. 获取海深数据
    sea_depth = get_bathm(etopo, lat, lon)
    
    # 计算最大海深，用于截断WOA数据
    max_sea_depth = np.max(sea_depth)
    logger.info(f"区间最大海深: {max_sea_depth:.1f}m")
    
    # 2. 获取温盐剖面数据（只提取到最大海深）
    # 留一些余量，取整百米
    max_depth_query = np.ceil(max_sea_depth / 100) * 100 + 100  # 向上取整+100m余量
    Temp, Sal, TSDepth = get_profile_filled(woa23, lat, lon, time_idx, max_depth=max_depth_query)
    
    Nd = len(TSDepth)
    N_lon = len(lat)
    
    # 3. 计算每个深度的平均温盐（处理NaN）
    TempMean = np.zeros(Nd)
    SalMean = np.zeros(Nd)
    
    for iz in range(Nd):
        temp_row = Temp[iz, :]
        sal_row = Sal[iz, :]
        TempMean[iz] = np.nanmean(temp_row)
        SalMean[iz] = np.nanmean(sal_row)
    
    # 4. 找到有效数据的最大深度索引
    valid_mask = ~(np.isnan(TempMean) | np.isnan(SalMean))
    if not valid_mask.any():
        raise ValueError("温盐剖面数据完全缺失")
    
    idxD = np.where(valid_mask)[0][-1]  # 最后一个有效索引
    
    # 5. 扩展温盐剖面至最大海深
    seaDepth_max = int(np.ceil(np.max(sea_depth)))
    
    if TSDepth[idxD] < seaDepth_max:
        # 将最大有效深度的数据延伸到海深
        ssp_z = np.append(TSDepth[:idxD+1], seaDepth_max)
        TempMean_ext = np.append(TempMean[:idxD+1], TempMean[idxD])
        SalMean_ext = np.append(SalMean[:idxD+1], SalMean[idxD])
    elif TSDepth[idxD] == seaDepth_max:
        ssp_z = TSDepth[:idxD+1]
        TempMean_ext = TempMean[:idxD+1]
        SalMean_ext = SalMean[:idxD+1]
    else:
        # 插值到最大海深
        ssp_z = TSDepth[TSDepth < seaDepth_max]
        ssp_z = np.append(ssp_z, seaDepth_max)
        TempMean_ext = np.interp(ssp_z, TSDepth[:idxD+1], TempMean[:idxD+1])
        SalMean_ext = np.interp(ssp_z, TSDepth[:idxD+1], SalMean[:idxD+1])
    
    # 6. 计算平均声速剖面
    ssp_c = sound_speed(TempMean_ext, SalMean_ext, ssp_z)
    ssp_raw = np.column_stack([ssp_z, ssp_c])
    
    # 7. 计算区间多点声速剖面（填充NaN）
    Nz = len(ssp_z)
    c_matrix = np.zeros((Nz, N_lon))
    
    # 计算所有位置的声速（扩展温盐数据到ssp_z深度）
    C_all = np.zeros((Nz, N_lon))
    
    for iz in range(Nz):
        # 对每个深度，使用插值或直接使用对应深度的值
        if iz < len(TSDepth) - 1:
            # 在原始深度范围内，可以使用原始数据或插值
            if ssp_z[iz] in TSDepth:
                # 精确匹配
                idx = np.where(TSDepth == ssp_z[iz])[0][0]
                C_all[iz, :] = sound_speed(Temp[idx, :], Sal[idx, :], ssp_z[iz])
            else:
                # 需要插值温盐
                temp_interp = np.zeros(N_lon)
                sal_interp = np.zeros(N_lon)
                for j in range(N_lon):
                    temp_interp[j] = np.interp(ssp_z[iz], TSDepth[:idxD+1], Temp[:idxD+1, j])
                    sal_interp[j] = np.interp(ssp_z[iz], TSDepth[:idxD+1], Sal[:idxD+1, j])
                C_all[iz, :] = sound_speed(temp_interp, sal_interp, ssp_z[iz])
        else:
            # 超出原始深度范围，使用延伸值
            C_all[iz, :] = sound_speed(TempMean_ext[iz] * np.ones(N_lon), 
                                       SalMean_ext[iz] * np.ones(N_lon), 
                                       ssp_z[iz])
    
    # 填充NaN值
    for iz in range(Nz):
        c_matrix[iz, :] = C_all[iz, :]
        # 用均值替换NaN
        nan_mask = np.isnan(c_matrix[iz, :])
        c_matrix[iz, nan_mask] = ssp_c[iz]
    
    SSProf = {
        'z': ssp_z,
        'c': c_matrix
    }
    
    return sea_depth, ssp_raw, SSProf


# ==================== 便捷函数 ====================

def load_env_data(env_config: Dict) -> Tuple[Dict, Dict]:
    """
    根据配置加载环境数据
    
    Args:
        env_config: 环境数据配置字典 (来自env_data_config.json)
        
    Returns:
        (etopo, woa23): ETOPO和WOA23数据
    """
    etopo = load_etopo(env_config['etopo']['file_path'])
    woa23 = load_woa23(
        env_config['woa23']['folder_path'],
        env_config['woa23']['time_index']
    )
    
    return etopo, woa23
