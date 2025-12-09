# A2环境文件生成器 - 实现计划

## 🎯 核心目标

**完整实现BELLHOP环境文件生成**：
1. 环境数据读取和处理（ETOPO/WOA23）
2. **生成BELLHOP格式文件**（.env/.bty/.trc/.brc/.ssp）
3. 基于频率的批量复制

---

## 📚 需转换的MATLAB函数

### **阶段1：环境数据处理工具（utils/）**

#### **1. load_data_new.m → env_data_loader.py**
```python
def load_etopo(file_path: str) -> Dict
def load_woa23(folder_path: str, time_index: int) -> Dict
```
- 读取.mat格式的ETOPO地形数据
- 读取WOA23声速剖面数据（17个时间索引）
- 依赖：`scipy.io.loadmat`

#### **2. coord_proc_new.m → coordinate_utils.py**
```python
def coord_proc(coord_s: Dict, R: List[float], azi: float) -> Tuple[np.ndarray, np.ndarray]
```
- 坐标转换：起点+距离+方位角 → 终点经纬度数组
- 简单的地理坐标计算
- 公式：
  - `lon_end = lon_start + R * sin(azi) / (111 * cos(lat/180*π))`
  - `lat_end = lat_start + R * cos(azi) / 111`

#### **3. get_env_new.m → ssp_processor.py**
```python
def get_env(etopo, woa23, lat, lon, time_idx) -> Tuple[np.ndarray, np.ndarray, Dict]
```
- 调用`get_bathm()`从ETOPO提取海深地形
- 调用`get_profile_filled()`从WOA23提取温盐剖面
- 计算声速剖面（调用sound_speed）
- 处理NaN值和深度插值
- 返回：`(seaDepth, ssp_raw, SSProf)`

#### **4. sound_speed → acoustic_utils.py**
```python
def sound_speed(temp, sal, depth) -> np.ndarray
```
- 经典声速公式（COA 1.2节）：
  ```python
  C = 1449.2 + 4.6*T - 0.055*T^2 + 0.00029*T^3 + \
      (1.34-0.01*T)*(S-35) + 0.017*D
  ```

---

### **阶段2：BELLHOP文件写入工具（utils/bellhop_writer.py）**

#### **1. write_env.m → write_env()**
```python
def write_env(envfil: str, model: str, title: str, freq: float, 
               ssp: Dict, bdry: Dict, pos: Dict, beam: Dict, rmax: float)
```
**生成.env文件**（主环境文件，文本格式）：
- 第1行：标题
- 第2行：频率 (Hz)
- 第3-N行：声速剖面（SSP）
- 边界条件（顶部/底部）
- 声源/接收深度
- 接收距离
- BELLHOP波束参数

#### **2. write_bty.m → write_bty()**
```python
def write_bty(envfil: str, interp_type: str, bathm: Dict)
```
**生成.bty文件**（海底地形，文本格式）：
```
'LS'           # 插值类型
N              # 点数
r1 d1          # 距离 深度
r2 d2
...
```

#### **3. write_ssp.m → write_ssp()**
```python
def write_ssp(filename: str, rkm: np.ndarray, ssp: np.ndarray)
```
**生成.ssp文件**（声速剖面集合，文本格式）：
```
Npts           # 距离点数
r1 r2 r3 ...   # 距离数组
c11 c12 c13... # 每个深度的声速
c21 c22 c23...
```

#### **4. TopReCoe.m → write_trc()**
```python
def write_trc(freqvec: List[float], c_surface: float, 
               sea_state_level: int, out_filename: str)
```
**生成.trc文件**（海面反射系数，文本格式）：
- 根据海况等级计算波高
- 计算不同入射角的反射系数
- 输出：91行 × 3列（角度/幅值/相位）

#### **5. RefCoeBw.m → write_brc()**
```python
def write_brc(base_type: str, envfil: str, freqvec: List[float],
               ssp_end: float, alpha_b: float)
```
**生成.brc文件**（海底反射系数，文本格式）：
- 根据海底类型（IMG/D05/D40/SCS-4）计算多层介质反射
- 输出：91行 × 3列（掠射角/幅值/相位）

---

### **阶段3：环境文件生成模块（modules/A2_EnvGenerator.py）**

#### **A22功能：模板环境文件生成**
```python
class EnvGenerator:
    def generate_template_envs(self):
        """生成原始.env文件组"""
        for coord_group in coordinate_groups:
            coord_s = {'lat': coord_group['lat'], 'lon': coord_group['lon']}
            
            for j, rr in enumerate(coord_group['receive_ranges']):
                # 1. 坐标转换
                coord_e_lat, coord_e_lon, azi = coord_proc(
                    coord_s, max(coord_group['receive_ranges']), self.azimuth
                )
                
                # 2. 提取环境数据
                lat_arr = np.linspace(coord_s['lat'], coord_e_lat[-1], N)
                lon_arr = np.linspace(coord_s['lon'], coord_e_lon[-1], N)
                sea_depth, ssp_raw, SSProf = get_env(
                    self.etopo, self.woa23, lat_arr, lon_arr, self.time_idx
                )
                
                # 3. 生成BELLHOP文件
                output_dir = f"{coord_group['group_id']}/Rr{j+1}/envfilefolder"
                envfil = f"ENV_{coord_group['group_id']}_Rr{rr}Km"
                
                write_env(envfil, 'BELLHOP', title, freq, ...)
                write_bty(envfil, "'LS'", bathm)
                write_ssp(envfil, rkm, SSProf.c)
                write_trc(freqvec, ssp_top, sea_state_level, envfil)
                write_brc(base_type, envfil, freqvec, ssp_bot, alpha_b)
```

#### **A3功能：频率批量复制**
```python
def replicate_by_frequencies(self, freq_list: List[float]):
    """基于A1频率列表批量复制环境文件"""
    for env_folder in all_env_folders:
        # 读取模板.env文件
        with open(f'{env_folder}/ENV_xxx.env', 'r') as f:
            baselines = f.readlines()
        
        # 并行复制
        for i, freq in enumerate(freq_list):
            lines = baselines.copy()
            lines[1] = f"  {freq}  \t\t\t ! Frequency (Hz) \n"  # 修改第2行
            
            # 写入新文件
            with open(f'{env_folder}/test_{i+1}.env', 'w') as f:
                f.writelines(lines)
            
            # 复制辅助文件
            shutil.copy(f'{env_folder}/ENV_xxx.trc', f'{env_folder}/test_{i+1}.trc')
            shutil.copy(f'{env_folder}/ENV_xxx.bty', f'{env_folder}/test_{i+1}.bty')
            shutil.copy(f'{env_folder}/ENV_xxx.brc', f'{env_folder}/test_{i+1}.brc')
        
        # 生成文件列表
        with open(f'{env_folder}/env_files_list.txt', 'w') as f:
            for i in range(len(freq_list)):
                f.write(f'test_{i+1}\n')
```

---

### **阶段2：环境文件生成（modules/A2_EnvGenerator.py）**

#### **A22功能：模板环境文件生成**
```python
class EnvGenerator:
    def generate_template_envs(self):
        """生成原始.env文件组"""
        for coord_group in coordinate_groups:
            for receive_range in coord_group['receive_ranges']:
                # 1. 坐标转换
                coord_end = coord_proc(coord_start, receive_range, azimuth)
                
                # 2. 提取环境数据
                sea_depth, ssp = get_env(etopo, woa23, lat, lon, time_idx)
                
                # 3. 生成文件结构（不调用BELLHOP）
                env_data = {
                    'coord_start': coord_start,
                    'coord_end': coord_end,
                    'sea_depth': sea_depth,
                    'ssp': ssp,
                    'params': bellhop_params
                }
                
                # 4. 保存为.pkl或JSON（替代.env二进制格式）
                save_env_template(env_data, output_path)
```

#### **A3功能：频率批量复制**
```python
def replicate_by_frequencies(self, freq_list: List[float]):
    """基于A1频率列表复制环境文件"""
    for env_template in env_templates:
        for freq in freq_list:
            # 复制模板，更新频率参数
            env_copy = copy.deepcopy(env_template)
            env_copy['freq'] = freq
            save_env_file(env_copy, f'test_{i}.pkl')
```

---

## 🔧 技术方案

### **不调用BELLHOP的替代方案**

| MATLAB行为 | Python实现 |
|-----------|----------|
| 调用`write_env()`生成.env | 保存为.pkl字典或JSON |
| 调用`write_bty()`生成.bty | 保存海深数组到.pkl |
| 调用`write_ssp()`生成.ssp | 保存声速剖面到.pkl |
| 调用BELLHOP计算 | **跳过**（暂不实现） |

### **数据格式**
```python
# 每个环境配置保存为.pkl
env_template = {
    'group_id': 'ENV1',
    'receive_range': 5,  # km
    'coord_start': {'lat': 19.50, 'lon': 107.00},
    'coord_end': {'lat': 19.55, 'lon': 107.05},
    'sea_depth': np.array([100, 120, ...]),  # 海深剖面
    'ssp': {
        'z': np.array([0, 10, 20, ...]),     # 深度
        'c': np.array([[1500, 1505, ...]])   # 声速
    },
    'freq': 500,  # 默认频率，后续被A1频率替换
    'source_depth': 10,
    'receive_depths': [10, 20, 30],
    'bellhop_params': {...}
}
```

---

## 📦 依赖库

```python
scipy          # 读取.mat文件
numpy          # 数组计算
gsw            # 声速计算（可选，或自己实现公式）
```

---

## ✅ 实现步骤

1. ✅ 设计配置文件结构
2. ⏳ 实现环境数据加载（load_etopo, load_woa23）
3. ⏳ 实现坐标转换（coord_proc）
4. ⏳ 实现声速剖面处理（get_env, sound_speed）
5. ⏳ 实现A22模板生成（遍历坐标组，保存.pkl）
6. ⏳ 实现A3频率复制（读取A1频率，批量复制）
7. ⏳ 测试和文档

---

## 💡 关键简化

- **不生成BELLHOP格式文件**（.env/.bty/.trc/.brc）
- **直接保存Python数据结构**（.pkl或JSON）
- **环境数据处理逻辑保持一致**
- **为后续BELLHOP集成预留接口**
