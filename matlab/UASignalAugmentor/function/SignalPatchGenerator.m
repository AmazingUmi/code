function SignalPatchGenerator(ARR, SigFilesList, SigFilesStruct, OutputSigDir, Analy_freq_all, Amp_source, fs)
% SIGNALPATCHGENERATOR 批量合成接收信号
%
% 输入:
%   ARR            : 到达结构数据
%   EnvSiteRrName  : 当前处理的环境距离配置名称 (用于日志)
%   SigFilesList   : 信号文件列表
%   SigFilesStruct : 原始信号数据结构体数组
%   OutputSigDir   : 输出目录
%   Analy_freq_all : 所有分析频率
%   Amp_source     : 源强度
%   fs             : 采样率

    ReceiveDepth = [ARR(1, :).rd];

    % GPU settings (avoid forcing GPU when unavailable; allow controlled memory release)
    useGPU = false;
    try
        useGPU = (gpuDeviceCount > 0);
    catch
        useGPU = false;
    end
    BatchSize = 64;
    resetEveryN = 0; % set to e.g. 50 to periodically reset GPU context if needed
    sigCounter = 0;
    % 遍历每个接收深度
    for m = 1:length(ReceiveDepth)
        % m = 1:length(ReceiveDepth)
        ARRSingleRD = ARR(:, m);
        
        % 遍历每个信号文件
        for n = 1:length(SigFilesList)
            % n = 1:length(SigFilesList)
            [~, SigBaseName] = fileparts(SigFilesList(n).name);
            AnalyFreq   = SigFilesStruct(n).Analy_freq;
            AnalyRecord = SigFilesStruct(n).Analyrecord;
            Ndelay      = SigFilesStruct(n).Ndelay;
            
            % 生成输出文件名
            NewSigName = fullfile(OutputSigDir, sprintf('%s_Rd_%d_new.mat', ...
                SigBaseName, ReceiveDepth(m)));
            
            % 提取信号段存在的频率
            [~, idx] = ismember(AnalyFreq, Analy_freq_all);
            % 此RD下该信号所包含频率的到达结构
            ArrRDSig = ARRSingleRD(idx, :);
            
            
            % 合成信号
            [TargSig, TargT] = TargSigGenerator(AnalyRecord, AnalyFreq, ...
                ArrRDSig, Amp_source, fs, Ndelay, [], useGPU, BatchSize);
            
            % 保存信号
            save(NewSigName, 'TargSig', 'TargT');
            fprintf('      保存信号: %s (深度 %d m)\n', ...
                SigBaseName, ReceiveDepth(m));

            % Help GPU memory return to the pool between iterations
            if useGPU
                sigCounter = sigCounter + 1;
                try
                    wait(gpuDevice);
                    if resetEveryN > 0 && mod(sigCounter, resetEveryN) == 0
                        reset(gpuDevice);
                    end
                catch
                    % ignore GPU reset issues; continue on CPU next calls if needed
                end
            end

            % Release large locals promptly (especially when looping many signals)
            TargSig = [];
            TargT = [];
        end
    end
end
