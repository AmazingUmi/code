"""
检查WOA23数据结构
"""

import netCDF4 as nc
from pathlib import Path

woa23_dir = Path(r'D:\database\others\OceanDataBase\WOA23')
sal_file = woa23_dir / 'woa23_decav91C0_s00_04.nc'

print("="*80)
print("WOA23数据结构检查")
print("="*80)

ds = nc.Dataset(str(sal_file), 'r')

print(f"\n文件: {sal_file.name}")
print(f"\n变量列表:")
for var_name in ds.variables.keys():
    var = ds.variables[var_name]
    print(f"  {var_name}: shape={var.shape}, dims={var.dimensions}")

print(f"\n详细信息:")
lon = ds.variables['lon'][:]
lat = ds.variables['lat'][:]
depth = ds.variables['depth'][:]
sal = ds.variables['s_an'][:]

print(f"  lon: shape={lon.shape}, 范围=[{lon.min():.2f}, {lon.max():.2f}]")
print(f"  lat: shape={lat.shape}, 范围=[{lat.min():.2f}, {lat.max():.2f}]")
print(f"  depth: shape={depth.shape}, 层数={len(depth)}")
print(f"  s_an (盐度): shape={sal.shape}")

print(f"\n维度说明:")
print(f"  s_an的维度顺序: {ds.variables['s_an'].dimensions}")

ds.close()

print("\n" + "="*80)
