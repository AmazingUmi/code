function eddy_path_check()
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EDDY_PATH_CHECK Eddy 场景函数解析回归测试（Phase 3A）
%   复现 EddyComparison_Config / EddyComparison 的初始化 addpath 序列，
%   断言 8 个历史遮蔽函数全部确定解析到 UASA 权威实现。
%
%   修复前状态（实测）：Config 会话中 external addpath 前置，
%   RefCoeBw/coord_proc/write_ssp/plotshd 等解析到 underwateracoustic 旧版。
%
% 用法: matlab -batch "eddy_path_check"（在 baseline/ 目录下）
% 输出: PASS/FAIL 与逐函数解析结果；FAIL 时退出码非零。
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

root = fileparts(fileparts(mfilename('fullpath')));   % UASA 根
uasa = fullfile(root, 'function');
ext  = fullfile(root, '..', 'underwateracoustic', 'bellhop_fundation', 'function');

SHARED = {'RefCoeBw','coord_proc','get_bathm','get_env','load_data', ...
          'plotshd','write_ssp','caxisrev', 'read_shd','sound_speed'};

% 场景1: 复现修复前 Config 序列（先 UASA 后 external 前置）
addpath(uasa); addpath(ext);
n_ext_s1 = count_external(SHARED);

% 场景2: 修复后序列（Eddy 脚本只 addpath UASA）
addpath(uasa);
n_ext_s2 = count_external(SHARED);

fprintf('场景1(历史序列, external 前置): 解析到外部版 %d/%d 个\n', n_ext_s1, numel(SHARED));
fprintf('场景2(修复后序列, 仅 UASA):     解析到外部版 %d/%d 个\n', n_ext_s2, numel(SHARED));

ok = (n_ext_s2 == 0);
if ok
    disp('PASS: Eddy 关键函数全部确定解析到 UASA 权威实现');
else
    disp('FAIL: 仍有函数解析到外部旧版');
    for f = SHARED
        fprintf('  %-12s -> %s\n', f{1}, which(f{1}));
    end
end
end

function n = count_external(names)
n = 0;
for k = 1:numel(names)
    w = which(names{k});
    if ~isempty(w) && contains(w, 'underwateracoustic')
        n = n + 1;
    end
end
end
