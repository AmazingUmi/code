function root = uasa_project_root()
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% UASA_PROJECT_ROOT 解析 UASignalAugmentor 项目根目录
%
% 原理：本函数位于 <UASA根>/function/ 下，由自身文件位置上溯一级得到根目录。
%   不改变 cwd、不修改 MATLAB path、不依赖 active editor。
%
% 使用前提：本函数已经由调用脚本的 addpath(<root>/function) 加载到路径
%   （与全部现有脚本的初始化约定一致）。
%
% 输出:
%   root - UASignalAugmentor 根目录绝对路径
%
% 作者: [猫猫头]（Phase 2B-3 结构整理）
% 日期: [2026-08-15]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

here = fileparts(mfilename('fullpath'));   % <root>/function
root = fileparts(here);                    % <root>
end
