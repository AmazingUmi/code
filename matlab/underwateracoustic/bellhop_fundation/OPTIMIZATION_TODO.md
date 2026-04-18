# bellhop_fundation 剩余优化待办

本文整理当前工程中**尚未完成**或**高风险**的优化项，按优先级从高到低排列，便于逐项落地。

> 说明：以下条目基于现有调用链 `envmake.m -> call_Bellhop_surface_more.m -> get_env.m/get_bathm.m` 以及相关写文件/反射系数函数的代码现状整理。

---

## P0（优先修复：可能报错/结果不可信）

### 1) `coord_proc.m` 角度单位与象限问题
- **文件**：`bellhop_fundation/function/coord_proc.m`
- **问题**：
  - 当输入 `coordE` 时输出 `azi` 为弧度（`atan`），但当输入 `(R,azi)` 时又把 `azi` 当角度转弧度（`azi/180*pi`），单位不一致。
  - `atan(x/y)` 存在象限歧义，建议用 `atan2d`.
- **建议改法**：
  - 统一 `azi` 全程为“度”，使用 `atan2d(x,y)`、`sind/cosd`。
- **验收标准**：
  - “正算 + 反算”一致：用同一组 `(coordS, coordE)` 算回 `(R,azi)`，再用 `(coordS,R,azi)` 还原的 `coordE` 偏差在可接受范围内（例如 < 1e-6° 或对应距离误差 < 米级）。

### 2) `write_altimetry.m` 对 `ri==0` 不兼容
- **文件**：`bellhop_fundation/function/write_altimetry.m`
- **问题**：`x = 0:ri:rmax;` 当 `ri==0` 会直接报错；而 `envmake.m` 默认 `ri = 0`。
- **建议改法**：
  - 在 `write_altimetry` 内部对 `ri==0` 设置默认采样步长（如 0.1 km 或 1 km），或改为固定点数 `linspace(0,rmax,N)`.
- **验收标准**：
  - `ri=0` 且 `top_option` 含 `*` 时，能正常生成 `.ati` 文件。

### 3) `SourceBeam.m` 存在除零风险（启用后会炸）
- **文件**：`bellhop_fundation/function/SourceBeam.m`
- **问题**：`bw0=0` 导致后续 `bw/bw0` 除零；只要 `runtype` 含 `*` 启用 `.sbp` 输出就会触发。
- **建议改法**：
  - 给 `bw0` 一个合理的非零基准值，或重写缩放逻辑以避免除零与分支重复。
- **验收标准**：
  - `runtype` 含 `*` 时可生成 `.sbp`，且 `DI_int` 不包含 `Inf/NaN`（除非明确允许）。

### 4) `RefCoeBw.m` 明显 bug 与数值稳定性
- **文件**：`bellhop_fundation/function/RefCoeBw.m`
- **问题**：
  - `zeors` 拼写错误（`SCS-4` 分支），会直接运行失败。
  - `angle_graze = 0:90` 导致 `sind(0)` 分母为 0，靠 `isnan(...)=1` “补丁式修复”，物理意义与数值稳定性都存疑。
- **建议改法**：
  - 修正拼写，避免 0° 入射角（从一个很小角开始，如 `0.1:90`）或显式处理 0°。
- **验收标准**：
  - 任意支持的 `base_type` 下可生成 `.brc`；输出不依赖 NaN 强行置 1 的旁路逻辑。

---

## P1（性能：批量/多测线时收益大）

### 5) `get_bathm.m` 反复 `meshgrid` 开销过大
- **文件**：`bellhop_fundation/function/get_bathm.m`
- **现状**：每次调用都构造 `[LON,LAT]=meshgrid(...)`，而 `envmake/get_env/call_Bellhop_surface_more` 会多次调用。
- **建议改法（择一）**：
  - 用 `persistent` 缓存 `griddedInterpolant` 或缓存 `LON/LAT`；
  - 或直接用向量网格形式的 `interp2(ETOPO.Lon,ETOPO.Lat,ETOPO.Altitude',lon,lat)`，避免 `meshgrid`。
- **验收标准**：
  - 在同一 `ETOPO` 上多次插值时，运行时间明显下降（例如 > 2x），结果数值一致或差异在插值误差允许范围。

### 6) `get_env.m` 温盐均值计算可向量化
- **文件**：`bellhop_fundation/function/get_env.m`
- **现状**：逐深度 for 循环计算 mean（且手动剔除 NaN）。
- **建议改法**：
  - 使用 `mean(Temp,2,'omitnan')` 和 `mean(Sal,2,'omitnan')`（或 `nanmean`）。
- **验收标准**：
  - 输出 `ssp_raw` 与旧版一致（或差异仅在浮点误差范围），运行更快且代码更短。

---

## P2（可维护性/可复现性：让脚本更工程化）

### 7) `envmake.m` 脚本参数建议集中与可复现
- **文件**：`bellhop_fundation/envmake.m`（或你新建的 `envmake_new.m`）
- **建议**：
  - 把参数（频率、点位、rmax、选项等）集中为一个 `cfg` 结构体；
  - 输出目录保存 `cfg.mat`，便于复现实验。
- **验收标准**：
  - 同一份 `cfg` 在不同机器/目录下运行，输出一致且路径不依赖硬编码盘符。

### 8) `plotgeomap.m` 默认数据源路径可配置
- **文件**：`bellhop_fundation/function/plotgeomap.m`
- **现状**：不传 `ETOPO` 时默认 `load('etopo1.mat')`，依赖当前工作目录/路径。
- **建议**：
  - 默认文件改为相对 `baseDir` 或传入 `etop_dir`；或在 `envmake` 中始终显式传 `ETOPO`（推荐）。
- **验收标准**：
  - 在任意工作目录下调用 `plotgeomap(...)` 都能找到正确数据源，不依赖 `cd`。

---

## 建议的落地顺序（最小改动优先）
1. 修 `write_altimetry(ri==0)`、`coord_proc`（P0）
2. 修 `RefCoeBw` 与 `SourceBeam`（P0，避免启用时炸）
3. 加速 `get_bathm`、向量化 `get_env`（P1）
4. `envmake` 工程化改造（P2）

