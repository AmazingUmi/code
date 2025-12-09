"""
BELLHOP文件写入工具

功能：
- 生成 .env 文件（主环境文件）
- 生成 .bty 文件（海底地形）
- 生成 .ssp 文件（声速剖面集合）
- 生成 .trc 文件（海面反射系数）
- 生成 .brc 文件（海底反射系数）

参考MATLAB函数：
- write_env.m
- write_bty.m
- write_ssp.m
- write_bell.m
- TopReCoe.m
- RefCoeBw.m
"""

from pathlib import Path
from typing import Dict, List, Optional
import numpy as np
import logging


logger = logging.getLogger(__name__)


# ==================== .env 文件写入 ====================

def write_env(envfil: str, model: str, title: str, freq: float,
              ssp: Dict, bdry: Dict, pos: Dict, beam: Dict, rmax: float) -> None:
    """
    生成BELLHOP环境文件 (.env)
    
    对应MATLAB: write_env.m
    
    Args:
        envfil: 文件名（不含.env后缀）
        model: 模型名称（'BELLHOP'）
        title: 标题
        freq: 频率 (Hz)
        ssp: 声速剖面字典
        bdry: 边界条件字典
        pos: 位置字典（声源/接收）
        beam: 波束参数字典
        rmax: 最大距离 (km)
    """
    if not envfil.endswith('.env'):
        envfil = envfil + '.env'
    
    with open(envfil, 'w') as f:
        # 第1行：标题
        f.write(f"'{title}' ! Title \n")
        
        # 第2行：频率
        f.write(f"{freq:8.2f}  \t \t \t ! Frequency (Hz) \n")
        
        # 第3行：媒质层数
        f.write(f"{ssp['NMedia']:5d}    \t \t \t ! NMedia \n")
        
        # 第4行：顶部边界选项
        f.write(f"'{bdry['Top']['Opt']}' \t \t \t ! Top Option \n")
        
        # 如果顶部是声学半空间
        if len(bdry['Top']['Opt']) > 1 and bdry['Top']['Opt'][1] == 'A':
            hs = bdry['Top']['HS']
            f.write(f"    {ssp['depth'][0]:6.2f} {hs['alphaR']:6.2f} {hs['betaR']:6.2f} "
                   f"{hs['rho']:6.2g} {hs['alphaI']:6.2f} {hs['betaI']:6.2f} /  \t ! upper halfspace \n")
        
        # 声速剖面（SSP）
        for medium in range(ssp['NMedia']):
            f.write(f"{ssp['N'][medium]:5d} {ssp['sigma'][medium]:4.2f} "
                   f"{ssp['depth'][medium+1]:6.2f} \t ! N sigma depth \n")
            
            raw = ssp['raw'][medium]
            for i in range(len(raw['z'])):
                f.write(f"\t {raw['z'][i]:6.2f} {raw['alphaR'][i]:6.2f} {raw['betaR'][i]:6.2f} "
                       f"{raw['rho'][i]:6.2g} {raw['alphaI'][i]:10.6f} {raw['betaI'][i]:6.2f} / "
                       f"\t ! z c cs rho \n")
        
        # 底部边界选项
        f.write(f"'{bdry['Bot']['Opt']}' {0.0:6.2f}  \t \t ! Bottom Option, sigma \n")
        
        # 如果底部是声学半空间
        if bdry['Bot']['Opt'][0] == 'A':
            hs = bdry['Bot']['HS']
            f.write(f"    {ssp['depth'][ssp['NMedia']]:6.2f} {hs['alphaR']:6.2f} {hs['betaR']:6.2f} "
                   f"{hs['rho']:6.2g} {hs['alphaI']:6.2f} {hs['betaI']:6.2f} /  \t ! lower halfspace \n")
        
        # 声源深度
        f.write(f"{len(pos['s']['z']):5d} \t \t \t \t ! NSz \n")
        _write_array(f, pos['s']['z'], "Sz(1)  ... (m)")
        
        # 接收深度
        f.write(f"{len(pos['r']['z']):5d} \t \t \t \t ! NRz \n")
        _write_array(f, pos['r']['z'], "Rz(1)  ... (m)")
        
        # 接收距离（BELLHOP特有）
        if model == 'BELLHOP':
            f.write(f"{len(pos['r']['range']):5d} \t \t \t \t ! NRr \n")
            _write_array(f, pos['r']['range'], "Rr(1)  ... (km)")
            
            # BELLHOP波束参数
            _write_bell(f, beam)
    
    logger.info(f"已生成 .env 文件: {envfil}")


def _write_array(f, arr: List[float], comment: str) -> None:
    """辅助函数：写入数组（检测是否等间隔）"""
    if len(arr) >= 2 and _is_equally_spaced(arr):
        f.write(f"    {arr[0]:6f} {arr[-1]:6f}")
    else:
        for val in arr:
            f.write(f"    {val:6f}  ")
    f.write(f"/ \t ! {comment} \n")


def _is_equally_spaced(arr: List[float], tol: float = 1e-6) -> bool:
    """检测数组是否等间隔"""
    if len(arr) < 2:
        return False
    diffs = np.diff(arr)
    return np.allclose(diffs, diffs[0], atol=tol)


def _write_bell(f, beam: Dict) -> None:
    """
    写入BELLHOP波束参数
    
    对应MATLAB: write_bell.m
    """
    # 运行类型
    f.write(f"'{beam['RunType']}' \t \t \t \t ! Run Type \n")
    
    # 波束数量
    f.write(f"{beam['Nbeams']:d} \t \t \t \t \t! Nbeams \n")
    
    # 角度范围
    f.write(f"{beam['alpha'][0]:f} {beam['alpha'][1]:f} / \t \t ! angles (degrees) \n")
    
    # 步长和计算区域
    f.write(f"{beam['deltas']:f} {beam['Box']['z']:f} {beam['Box']['r']:f} "
           f"\t ! deltas (m) Box.z (m) Box.r (km) \n")
    
    # Cerveny高斯波束参数
    if len(beam['RunType']) > 1 and beam['RunType'][1] not in ['G', 'B', 'S']:
        f.write(f"'{beam['Type'][:2]}' {beam['epmult']:f} {beam['rLoop']:f}  "
               f"\t \t ! 'Min/Fill/Cer, Sin/Doub/Zero' Epsmult RLoop (km) \n")
        f.write(f"{beam['Nimage']:d} {beam['Ibwin']:d}  \t \t \t \t ! Nimage Ibwin \n")


# ==================== .bty 文件写入 ====================

def write_bty(envfil: str, interp_type: str, bathm: Dict) -> None:
    """
    生成海底地形文件 (.bty)
    
    对应MATLAB: write_bty.m
    
    Args:
        envfil: 文件名（不含.bty后缀）
        interp_type: 插值类型（如 "'LS'"）
        bathm: 海底地形字典 {'r': 距离数组, 'd': 深度数组}
    """
    bty_file = envfil + '.bty' if not envfil.endswith('.bty') else envfil
    
    with open(bty_file, 'w') as f:
        f.write(f"{interp_type}\n")
        
        N = len(bathm['r'])
        f.write(f"{N}\n")
        
        for i in range(N):
            f.write(f"{bathm['r'][i]:f} {bathm['d'][i]:f}\n")
    
    logger.info(f"已生成 .bty 文件: {bty_file}")


# ==================== .ssp 文件写入 ====================

def write_ssp(filename: str, rkm: np.ndarray, ssp: np.ndarray) -> None:
    """
    生成声速剖面集合文件 (.ssp)
    
    对应MATLAB: write_ssp.m
    
    Args:
        filename: 文件名（不含.ssp后缀）
        rkm: 距离数组 (km)
        ssp: 声速矩阵 (Ndepth × Nrange)
    """
    ssp_file = filename + '.ssp' if not filename.endswith('.ssp') else filename
    
    Npts = len(rkm)
    
    with open(ssp_file, 'w') as f:
        # 第1行：距离点数
        f.write(f"{Npts}\n")
        
        # 第2行：距离数组
        for r in rkm:
            f.write(f"{r:6.3f} ")
        f.write("\n")
        
        # 后续行：每个深度的声速
        for i in range(ssp.shape[0]):
            for j in range(ssp.shape[1]):
                f.write(f"{ssp[i, j]:6.1f} ")
            f.write("\n")
    
    logger.info(f"已生成 .ssp 文件: {ssp_file}")


# ==================== .trc 文件写入（海面反射系数）====================

def write_trc(freqvec: List[float], c_surface: float, 
              sea_state_level: int, out_filename: str) -> np.ndarray:
    """
    生成海面反射系数文件 (.trc)
    
    对应MATLAB: TopReCoe.m
    
    Args:
        freqvec: 频率数组 (Hz)
        c_surface: 海面声速 (m/s)
        sea_state_level: 海况等级 (0-8)
        out_filename: 输出文件名（不含.trc后缀）
        
    Returns:
        result_R: 反射系数矩阵 (91 × 3: 角度/幅值/相位)
    """
    # 海况等级对应的波高
    wave_height = [0, 0.1, 0.5, 1.25, 2.5, 4, 6, 9, 14]
    sigma = wave_height[sea_state_level] * 0.707
    
    theta = np.arange(0, 91)  # 0°到90°
    Re_mean = np.zeros_like(theta, dtype=float)
    
    for freq in freqvec:
        k = 2 * np.pi * freq / c_surface
        tau = 2 * k * sigma * np.sin(np.deg2rad(theta))
        Re_top = -np.exp(-0.5 * tau**2)
        Re_mean += np.abs(Re_top)
    
    Re_mean /= len(freqvec)
    
    # 构造输出矩阵 (角度, 幅值, 相位)
    result_R = np.zeros((len(theta), 3))
    result_R[:, 0] = theta
    result_R[:, 1] = Re_mean
    result_R[:, 2] = 180  # 相位固定为180°
    
    # 写入文件
    trc_file = out_filename + '.trc' if not out_filename.endswith('.trc') else out_filename
    
    with open(trc_file, 'w') as f:
        f.write(f"{len(result_R)} \n")
        for row in result_R:
            f.write(f"{row[0]:6.2f}  {row[1]:6.2f}  {row[2]:6.2f}\n")
    
    logger.info(f"已生成 .trc 文件: {trc_file}")
    return result_R


# ==================== .brc 文件写入（海底反射系数）====================

def write_brc(base_type: str, envfil: str, freqvec: List[float],
              ssp_end: float, alpha_b: float = 0.05) -> np.ndarray:
    """
    生成海底反射系数文件 (.brc)
    
    对应MATLAB: RefCoeBw.m
    
    Args:
        base_type: 海底类型 ('IMG', 'D05', 'D40', 'SCS-4')
        envfil: 输出文件名（不含.brc后缀）
        freqvec: 频率数组 (Hz)
        ssp_end: 海水最底层声速 (m/s)
        alpha_b: 海底衰减系数 (dB/lambda), 默认0.05
        
    Returns:
        result_R: 反射系数矩阵 (91 × 3: 掠射角/幅值/相位)
    """
    # 根据海底类型定义分层参数
    if base_type == 'IMG':
        # 镜面反射（理想海底）
        speed = [ssp_end, 1500]
        layer_depth = [0, 1]
        rho_D = [1, 1]
        alpha_p = [0, 0]
    elif base_type == 'D05':
        speed = [ssp_end, 1542.05, 1502.70, 1500.39, 1499.09, 1492.67, 
                1489.81, 1495.51, 1569.88, 1580.84, 1583.34]
        layer_depth = [0, 0.462, 0.954, 1.453, 1.945, 2.443, 2.91, 3.406, 3.898, 4.395, 4.895]
        rho_D = [1, 1.51, 1.36, 1.37, 1.35, 1.38, 1.37, 1.38, 1.50, 1.45, 1.40]
        alpha_p = [0] + [alpha_b] * (len(rho_D) - 1)
    elif base_type == 'D40':
        speed = [ssp_end, 1568.69, 1664.50, 1591.08, 1569.42, 1587, 1562.01]
        layer_depth = [0, 0.467, 0.967, 1.462, 1.958, 2.463, 3.268]
        rho_D = [1, 1.52, 1.72, 1.63, 1.58, 1.60, 1.57]
        alpha_p = [0] + [alpha_b] * (len(rho_D) - 1)
    elif base_type == 'SCS-4':
        speed = [ssp_end, 1609.87, 1591.64, 1589.51, 1552.50]
        layer_depth = [0, 0.468, 0.962, 1.465, 2.158]
        rho_D = [1, 1.69, 1.64, 1.61, 1.51]
        alpha_p = [0] + [alpha_b] * (len(rho_D) - 1)
    else:
        raise ValueError(f"未知的海底类型: {base_type}")
    
    angle_graze = np.arange(0, 91)  # 0°到90°掠射角
    result_R1 = np.zeros_like(angle_graze, dtype=float)
    
    # 对每个频率计算反射系数
    for freq in freqvec:
        R_multilayer = _compute_multilayer_reflection(
            freq, speed, layer_depth, rho_D, alpha_p, angle_graze
        )
        R_multilayer[np.isnan(R_multilayer)] = 1
        result_R1 += np.abs(R_multilayer)
    
    # 构造输出矩阵
    result_R = np.zeros((len(angle_graze), 3))
    result_R[:, 0] = angle_graze
    result_R[:, 1] = result_R1 / len(freqvec)
    result_R[:, 2] = 0  # 相位
    
    # 写入文件
    brc_file = envfil + '.brc' if not envfil.endswith('.brc') else envfil
    
    with open(brc_file, 'w') as f:
        f.write(f"{len(angle_graze)} \n")
        for row in result_R:
            f.write(f"{row[0]:6.2f}  {row[1]:6.2f}  {row[2]:6.2f}\n")
    
    logger.info(f"已生成 .brc 文件: {brc_file}")
    return result_R


def _compute_multilayer_reflection(freq: float, speed: List[float], 
                                   layer_depth: List[float], rho_D: List[float],
                                   alpha_p: List[float], angle_graze: np.ndarray) -> np.ndarray:
    """
    计算多层介质的反射系数
    
    使用递归算法从最底层向上计算
    """
    n_layers = len(speed)
    
    # 最底层和倒数第二层的掠射角
    angle_end = np.arccos(speed[-1] / speed[0] * np.cos(np.deg2rad(angle_graze)))
    angle_end_1 = np.arccos(speed[-2] / speed[0] * np.cos(np.deg2rad(angle_graze)))
    
    # 阻抗
    Z_end = speed[-1] * rho_D[-1] / np.sin(angle_end)
    Z_end_1 = speed[-2] * rho_D[-2] / np.sin(angle_end_1)
    
    # 初始反射系数
    R_temp = (Z_end - Z_end_1) / (Z_end + Z_end_1)
    Z_temp = Z_end_1
    angle_temp = angle_end_1
    
    # 递归计算各层反射
    for i in range(2, n_layers):
        angle_up = np.arccos(speed[-i-1] / speed[0] * np.cos(np.deg2rad(angle_graze)))
        Z_up = speed[-i-1] * rho_D[-i-1] / np.sin(angle_up)
        R_up = (Z_temp - Z_up) / (Z_temp + Z_up)
        
        # 相位延迟
        phi = (2 * np.pi * freq / speed[-i+1] * 
               (layer_depth[-i+1] - layer_depth[-i]) * np.sin(angle_temp))
        
        # 多层反射系数递推
        R_temp = (R_up + R_temp * np.exp(2j * phi)) / (1 + R_up * R_temp * np.exp(2j * phi))
        Z_temp = Z_up
        angle_temp = angle_up
    
    return R_temp
