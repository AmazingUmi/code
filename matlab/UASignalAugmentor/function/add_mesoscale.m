function SSP = add_mesoscale(SSP, rmax, phenomenon_type, params)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ADD_MESOSCALE 向声速剖面添加中尺度现象
%   在二维声速剖面数据中叠加高斯涡或内波等中尺度海洋现象
%
% 输入参数:
%   SSP              - 声速剖面结构体，包含字段：
%                      .z: 深度向量 (m)
%                      .c: 声速矩阵 (m×n, m为深度点数, n为距离点数)
%   rmax             - 最大距离范围 (km)，用于生成距离向量
%   phenomenon_type  - 中尺度现象类型：
%                      'none' (无中尺度现象，直接返回原始声速)
%                      'eddy' (高斯涡)
%                      'internal_wave' (内波)
%   params           - 现象参数结构体，根据类型包含不同字段：
%                      当 phenomenon_type 为 'none' 时，可省略此参数
%
%                      【高斯涡参数】
%                      .rc: 涡心水平位置 (km)
%                      .zc: 涡心竖直位置 (m)
%                      .DR: 涡水平尺度 (km)
%                      .DZ: 涡竖直尺度 (m)
%                      .DC: 涡的强度 (m/s, 负值为冷涡, 正值为暖涡)
%
%                      【内波参数】
%                      .z0: 内波基准深度 (m)
%                      .L:  特征长度 (km)
%                      .rc: 波峰中心所在距离 (km)
%                      .DC: 内波强度 (m)
%                      .k1: 上层插值点数 (默认20)
%                      .k2: 下层插值点数 (默认50)
%
% 输出参数:
%   SSP - 更新后的声速剖面结构体，其中 SSP.c 被替换为添加中尺度现象后的声速矩阵
%
% 示例:
%   % 不添加中尺度现象
%   ssp_new = add_mesoscale(SSP, 200, 'none');
%
%   % 添加高斯涡
%   eddy_params.rc = 100;  % 涡心在100km处
%   eddy_params.zc = 600;  % 涡心深度600m
%   eddy_params.DR = 70;   % 水平尺度70km
%   eddy_params.DZ = 400;  % 竖直尺度400m
%   eddy_params.DC = -40;  % 冷涡，强度-40 m/s
%   ssp_new = add_mesoscale(SSP, 200, 'eddy', eddy_params);
%
%   % 添加内波
%   iw_params.z0 = 1000;   % 基准深度1000m
%   iw_params.L  = 40;     % 特征长度40km
%   iw_params.rc = 100;    % 波峰中心100km
%   iw_params.DC = 500;    % 内波强度500m
%   ssp_new = add_mesoscale(SSP, 200, 'internal_wave', iw_params);
%
% 作者: [猫猫头]
% 日期: [2025-12-03]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 提取声速剖面数据
z = SSP.z;
c = SSP.c;
[m, n] = size(c);
zm = max(z);

% 生成距离向量
r = linspace(0, rmax, n);

% 根据现象类型处理
switch lower(phenomenon_type)
    case 'none'
        %% 不添加中尺度现象，直接返回原始声速
        SSP.c = c;
        
    case 'eddy'
        %% 添加高斯涡
        % 提取参数
        rc = params.rc;  % 涡心水平位置
        zc = params.zc;  % 涡心竖直位置
        DR = params.DR;  % 涡水平尺度
        DZ = params.DZ;  % 涡竖直尺度
        DC = params.DC;  % 涡的强度
        
        % 计算声速扰动
        dc = zeros(size(c));
        for i = 1:n
            for j = 1:m
                dc(j, i) = DC * exp(-((r(i) - rc) / DR)^2 - ((z(j) - zc) / DZ)^2);
            end
        end
        
        % 叠加扰动
        SSP.c = c + dc;
        
    case 'internal_wave'
        %% 添加内波
        % 提取参数
        z0 = params.z0;  % 内波基准深度
        L = params.L;    % 特征长度
        rc = params.rc;  % 波峰中心所在距离
        DC = params.DC;  % 内波强度
        
        % 设置插值点数（可选参数）
        if isfield(params, 'k1')
            k1 = params.k1;
        else
            k1 = 20;  % 默认值
        end
        
        if isfield(params, 'k2')
            k2 = params.k2;
        else
            k2 = 50;  % 默认值
        end
        
        k3 = k1 + k2 - 1;
        
        % 计算内波导致的等深线起伏
        h = z0 + DC * (sech((r - rc) / L)).^2;
        
        % 初始化新声速矩阵
        ssp_new = zeros(m, n);
        zn = zeros(1, k3);
        sspn = zeros(1, k3);
        
        % 对每个距离点进行垂直拉伸/压缩
        for i = 1:n
            % 下层（从基准深度到最大深度）
            zd0 = linspace(z0, zm, k2);
            zd = linspace(h(i), zm, k2);
            sspd = interp1(z, c(:, i), zd0);
            
            % 上层（从海面到基准深度）
            zu0 = linspace(0, z0, k1);
            zu = linspace(0, h(i), k1);
            sspu = interp1(z, c(:, i), zu0);
            
            % 合并上下层
            zn(1:k1) = zu;
            zn(k1+1:k3) = zd(2:k2);
            
            sspn(1:k1) = sspu;
            sspn(k1+1:k3) = sspd(2:k2);
            
            % 插值到原始深度网格
            ssp_new(:, i) = interp1(zn, sspn, z);
        end
        
        % 更新 SSP 结构体
        SSP.c = ssp_new;
        
    otherwise
        error('不支持的中尺度现象类型: %s\n支持的类型: ''none'' (无), ''eddy'' (高斯涡), ''internal_wave'' (内波)', ...
            phenomenon_type);
end

end
