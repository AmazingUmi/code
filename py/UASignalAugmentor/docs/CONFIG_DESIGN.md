# A2环境文件生成器 - 配置文件说明

## 📋 配置文件分离设计（三文件结构）

### **1. env_data_config.json** - 环境数据库配置
**职责**：管理ETOPO和WOA23环境数据源

```json
{
  "etopo": {
    "file_path": "路径/targetETOPO.mat",
    "description": "全球海底地形数据"
  },
  "woa23": {
    "folder_path": "路径/target_WOA23_mat",
    "time_index": 1  // 1-12月度, 13-16季度, 17年度
  }
}
```

**使用场景**：
- 初始化时加载环境数据库
- 多个模块共享（A2、后续模块都可能用到）

---

### **2. coordinate_groups.json** - 经纬度组配置
**职责**：定义每个环境点的坐标和接收参数

```json
{
  "coordinate_groups": [
    {
      "group_id": "ENV1",
      "lat": 19.50,
      "lon": 107.00,
      "zone_type": "Shallow",       // 深浅海作为属性
      "receive_ranges": [1, 5, 10],
      "receive_depths": [10, 20, 30]
    },
    {
      "group_id": "ENV2",
      "lat": 7.10,
      "lon": 117.80,
      "zone_type": "Shallow",
      "receive_ranges": [1, 5, 10],
      "receive_depths": [10, 20, 30]
    }
    // ... 18个环境点
  ]
}
```

**特点**：
- 每个经纬度点独立配置
- `zone_type` 作为属性而非分组依据
- 易于增删改某个环境点
- `group_id` 对应输出文件夹名（ENV1, ENV2...）

---

### **3. acoustic_config.json** - 声场计算配置
**职责**：定义声场计算的物理参数（与坐标无关）

```json
{
  "output_path": "data/env_files",
  "source": {
    "depth": 10,   // 声源深度
    "range": 0     // 声源距离
  },
  "azimuth": 0,    // 方位角
  "bellhop_params": {
    "run_type": "AB",
    "top_option": "CFFT",
    "freq": 500,
    "beam_option": {...}
  }
}
```

**使用场景**：
- 定义BELLHOP计算的全局参数
- 与具体坐标解耦

---

## 🔄 数据流

```
env_data_config.json     →  加载ETOPO/WOA23  →  环境数据库
                                                    ↓
coordinate_groups.json   →  遍历每个坐标点   →  EnvGenerator
                                                    ↓
acoustic_config.json     →  BELLHOP参数      →  生成.env文件
```

---

## ✅ 优势

1. **职责清晰**：数据源 / 坐标 / 计算参数 三者分离
2. **灵活性**：
   - 修改某个坐标点：只改 `coordinate_groups.json`
   - 修改BELLHOP参数：只改 `acoustic_config.json`
   - 环境数据路径：只改 `env_data_config.json`
3. **可扩展**：添加新坐标点只需在数组中追加
4. **zone_type作为属性**：不强制按深浅海分组，更灵活
