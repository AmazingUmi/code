% % FigureBest start
% @ 图通道
% 支持 macos,windows,matlab after or 2016a
% ---------------------------
% % 如何安装启动fb?
% 第一步：解压代码包
% 第二步：将所有文件放置在合适的不常动的位置；确保拥有读和写权限；否则会启动不了/存在功能隐患
% 第三步：运行fb.m函数（第一次启动时）
% 第四步：之后启动，满足第二步的情况下，输入fb即可快速启动
% 上方内容主要用于自动设置路径
%
% % 提升速度与排查问题?
% 第一次运行之后，可以注释除了最后一行外的所有内容来提升启动速度/不自动切换路径；
% 为了避免运行有卡顿或者java类报错，请合理增大java堆内存,在：预设-常规-java堆内存
% 如果无法写入，切换current folder到桌面
% 每次替换许可证后将上方注释打开一次
% 遇到问题通常打开set path注释都可以解决
% ---------------------------

%% show msg
disp('FB is starting...')

%% encoding check
% ---------------------------
% PASS: UTF8 OR GBK
% WARNING: 'OTHERS'
DefaultCharacterSet = feature('DefaultCharacterSet');
locale = feature('locale');
encoding = locale.encoding;
if ~strcmp(DefaultCharacterSet,'GBK') | ~strcmp(encoding,'GBK')
    disp(['[DefaultCharacterSet]' DefaultCharacterSet '; ' '[encoding]' encoding])
    disp('Chaos character MAY occur if were NOT GBK, while main functions wonnot be affected!')
    disp('Please change the encoding IF possible')
end

%% set path
% ---------------------------
folderOfThis = fileparts(mfilename('fullpath')); % get the folder of current .m
addpath(genpath(folderOfThis)); % add path and subpath (temporary)
savepath % add path and subpath (permanent)
cd(folderOfThis) % change current folder
clear folderOfThis

%% set window size
% ---------------------------
% change the value in ~\settings\window.txt
% 更改~\settings\window.txt中的默认值

%% open
FigureBest_v4


