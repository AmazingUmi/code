# UASA 行为基线报告 — run2
- 运行时间: 2026-08-15 20:49:45
- 本脚本目录: /Users/luyiyang/Database/code/matlab/UASignalAugmentor/baseline
- 临时工作目录(仓库外): /private/var/folders/md/dbgxkf7n4dz7g1hkk2_pw9040000gn/T/opencode/uasa_baseline/run2

## S0 运行环境
- MATLAB version: 25.2.0.3312555 (R2025b) Update 6
- computer: MACA64, ismac=1
- gpuDeviceCount: 0  (Apple Silicon 上 MATLAB GPU 通常为 0 → TargSigGenerator 生产默认走 CPU 路径)
- rng 生产默认(未显式设置): Type=twister, Seed=0

## S1 A1 — wavfreq + wavfilter（生产参数，CURRENT BEHAVIOR）
- 测试样本: data/raw/Class A/46__23_07_13_H3_bateero1.wav (仓库已跟踪的最小 wav)
- 参数(照抄 A1WavTransformer.m): FreqRange=[10 200], cut_Tlength=1, threshold=0.05
- audioinfo: fs=52734 Hz, TotalSamples=599350, Duration=11.366 s, BitsPerSample=24, NumChannels=1
- wavfreq 输出: fs=52734, 分段数 N=11, Ndelay=[0 ... 10] 步长=1
- 滤波前 Analyrecord: 段数=11, 每段频率数 min/max/mean=191/191/191.0
- 滤波前 Analy_freq_raw: numel=191, min=10.0, max=200.0
- 滤波后 Analyrecord: 每段频率数 min/max/mean=105/122/111.2
- 滤波后 Analy_freq_filtered: numel=147, min=45, max=200, mean=126.558, std=43.3022
- 滤波后全局幅值: n=1223, NaN=0, Inf=0, min=0.0010518, max=0.0210096, mean=0.00419074, std=0.00322538
- 滤波后全局相位(rad): min=-3.13945, max=3.13947, mean=-0.0641335, std=1.7824
- 已提交产物 Class A_*.mat: fs=52734, Ndelay numel=11, Analy_freq numel=147, min=45, max=200
- 已提交产物 Analy_freq_all.mat: numel=182, min=19, max=200, mean=109.5, std=52.683
- 信息性对比: 本次 fs 与已提交 fs 一致: 1；本次 AfF 与已提交 Analy_freq 交集数=147

## S2 A2 — ConfigDeep + load_data + FileMaker（单站点单距离，CURRENT BEHAVIOR）
- ConfigDeep.mat 字段: Cal, Site_loc, Source
  Site_loc.zone=Deep, 站点数=6, ReceiveRange=[5 30 60], ReceiveDepth=[25 50 100 300]
  Source: SourceRange=0, SourceDepth=10, azi=0, freq=500, freqvec=500, timeIdx=1
  Cal: top_sea_state_level=0, mesoscale.type=none, bottom_base_type=IMG, bottom_alpha_b=0.05, Beam.RunType=AB, Beam.Type=CS
- load_data: ETOPO.Lon n=4804, ETOPO.Lat n=4804, WOA.Data cells=17 (索引1-12月,13-16季,17年)
- 站点1: coordS=(117.900,17.800) → coordE 末端=(117.9000,18.3405)
- FileMaker 生成文件（名称, 字节）:
    ENV_1_Rr5Km.brc, 2097
    ENV_1_Rr5Km.bty, 1340
    ENV_1_Rr5Km.env, 6488
    ENV_1_Rr5Km.ssp, 38284
    ENV_1_Rr5Km.trc, 2097
--- /private/var/folders/md/dbgxkf7n4dz7g1hkk2_pw9040000gn/T/opencode/uasa_baseline/run2/Deep/ENV1/Rr1/EnvTemplate/ENV_1_Rr5Km.env (前30行, 共104行) ---
   1| 'Acoustic Calculation ENV_1_Rr5Km' ! Title 
   2|   500.00  	 	 	 ! Frequency (Hz) 
   3|     1    	 	 	 ! NMedia 
   4| 'CFFT' 	 	 	 ! Top Option 
   5|     0 0.00 3961.00 	 ! N sigma depth 
   6| 	   0.00 1532.42   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
   7| 	   5.00 1532.53   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
   8| 	  10.00 1532.55   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
   9| 	  15.00 1532.54   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  10| 	  20.00 1532.51   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  11| 	  25.00 1532.38   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  12| 	  30.00 1532.15   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  13| 	  35.00 1531.57   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  14| 	  40.00 1530.61   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  15| 	  45.00 1529.50   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  16| 	  50.00 1528.37   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  17| 	  55.00 1527.50   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  18| 	  60.00 1526.44   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  19| 	  65.00 1525.18   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  20| 	  70.00 1524.21   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  21| 	  75.00 1523.30   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  22| 	  80.00 1522.16   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  23| 	  85.00 1521.10   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  24| 	  90.00 1519.98   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  25| 	  95.00 1519.08   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  26| 	 100.00 1518.16   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  27| 	 125.00 1513.57   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  28| 	 150.00 1509.69   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  29| 	 175.00 1506.33   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
  30| 	 200.00 1503.73   0.00      1   0.000000   0.00 / 	 ! z c cs rho 
--- /private/var/folders/md/dbgxkf7n4dz7g1hkk2_pw9040000gn/T/opencode/uasa_baseline/run2/Deep/ENV1/Rr1/EnvTemplate/ENV_1_Rr5Km.bty (前4行, 共64行) ---
   1| 'LS'
   2| 61
   3| 0.000000 3902.250000
   4| 1.000000 3913.972973
--- /private/var/folders/md/dbgxkf7n4dz7g1hkk2_pw9040000gn/T/opencode/uasa_baseline/run2/Deep/ENV1/Rr1/EnvTemplate/ENV_1_Rr5Km.ssp (前4行, 共90行) ---
   1| 62
   2| -60.000  0.000  1.000  2.000  3.000  4.000  5.000  6.000  7.000  8.000  9.000 10.000 11.000 12.000 13.000 14.000 15.000 16.000 17.000 18.000 19.000 20.000 21.000 22.000 23.000 24.000 25.000 26.000 27.000 28.000 29.000 30.000 31.000 32.000 33.000 34.000 35.000 36.000 37.000 38.000 39.000 40.000 41.000 42.000 43.000 44.000 45.000 46.000 47.000 48.000 49.000 50.000 51.000 52.000 53.000 54.000 55.000 56.000 57.000 58.000 59.000 63.000 
   3| 1532.7 1532.7 1532.7 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.3 1532.2 1532.2 1532.2 1532.2 
   4| 1532.8 1532.8 1532.8 1532.8 1532.7 1532.7 1532.7 1532.7 1532.7 1532.7 1532.7 1532.7 1532.7 1532.7 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.6 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.5 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.4 1532.3 
--- /private/var/folders/md/dbgxkf7n4dz7g1hkk2_pw9040000gn/T/opencode/uasa_baseline/run2/Deep/ENV1/Rr1/EnvTemplate/ENV_1_Rr5Km.trc (前3行, 共93行) ---
   1| 91 
   2|   0.00    1.00  180.00
   3|   1.00    1.00  180.00
--- /private/var/folders/md/dbgxkf7n4dz7g1hkk2_pw9040000gn/T/opencode/uasa_baseline/run2/Deep/ENV1/Rr1/EnvTemplate/ENV_1_Rr5Km.brc (前3行, 共93行) ---
   1| 91 
   2|   0.00    1.00    0.00
   3|   1.00    0.83    0.00

## S3 A3 — FreqDuplicator（TEST-CONTROLLED 缩减频率集）
- 完整 Analy_freq_all 长度=182；本基线缩减集长度=5: [45, 48, 51, 52, 54]
- FreqDuplicator 生成 test_* 文件数=25（每频率5件套 env/bty/ssp/trc/brc）
- env_files_list.txt 内容（CallBell 协议输入）:
    test_1 | test_2 | test_3 | test_4 | test_5
- test_1.env 与模板 .env 文本完全一致: 0（一致说明本旧版实现未逐频率改写env体, 差异定位见下）
  → 首个差异出现在字符偏移 47 附近（预期为频率行）

## S4 CallBell — BellParallelMac 协议运行（真实 bellhop 计算）
- DYLD_LIBRARY_PATH 注入(子shell内联): /opt/homebrew/Cellar/libomp/20.1.5/lib ; /opt/homebrew/Cellar/gcc/14.2.0_1/lib/gcc/current
  (二进制 rpath 指向的 ~/miniconda3/lib/{libomp,libgfortran.5}.dylib 在本机不存在 → 环境漂移，属环境依赖非仓库缺陷)
- BellParallelMac 退出码=0
    切换到工作目录: /private/var/folders/md/dbgxkf7n4dz7g1hkk2_pw9040000gn/T/opencode/uasa_baseline/run2/Deep/ENV1/Rr1/EnvTemplate
    dyld[30090]: Library not loaded: @rpath/libgfortran.5.dylib
      Referenced from: <1348126F-DF1D-33CE-ADBA-B4EB09D120A1> /Users/luyiyang/Database/code/matlab/UASignalAugmentor/CallBell/mac/bellhop.exe
      Reason: tried: '/Users/luyiyang/Database/code/matlab/UASignalAugmentor/CallBell/mac/libgfortran.5.dylib' (no such file), '/Users/luyiyang/miniconda3/lib/gcc/arm64-apple-darwin20.0.0/15.1.0/libgfortran.5.dylib' (no such file), '/System/Volumes/Preboot/Cryptexes/OS/Users/luyiyang/miniconda3/lib/gcc/arm64-apple-darwin20.0.0/15.1.0/libgfortran.5.dylib' (no such file), '/Users/luyiyang/miniconda3/lib/libgfortran.5.dylib' (no such file), '/System/Volumes/Preboot/Cryptexes/OS/Users/luyiyang/miniconda3/lib/libgfortran.5.dylib' (no such file), '/Users/luyiyang/Database/code/matlab/UASignalAugmentor/CallBell/mac/libgfortran.5.dylib' (no such file), '/Users/luyiyang/miniconda3/lib/gcc/arm64-apple-darwin20.0.0/15.1.0/libgfortran.5.dylib' (no such file), '/System/Volumes/Preboot/Cryptexes/OS/Users/luyiyang/miniconda3/lib/gcc/arm64-apple-darwin20.0.0/15.1.0/libgfortran.5.dylib' (no such file), '/Users/luyiyang/miniconda3/lib/libgfortran.5.dylib' (no such file), '/System/Volumes/Preboot/Cryptexes/OS/Users/luyiyang/miniconda3/lib/libgfortran.5.dylib' (no such file), '/usr/local/lib/libgfortran.5.dylib' (no such file), '/usr/lib/libgfortran.5.dylib' (no such file, not in dyld cache)
    dyld[30091]: Library not loaded: @rpath/libgfortran.5.dylib
      Referenced from: <1348126F-DF1D-33CE-ADBA-B4EB09D120A1> /Users/luyiyang/Database/code/matlab/UASignalAugmentor/CallBell/mac/bellhop.exe
- 生成 .arr 文件数=0
- 回退: 直接调用 bellhop.exe（等价调用约定）
- bellhop.exe 循环退出码=0
    
- 生成 .arr 文件数=5（回退后）
--- /private/var/folders/md/dbgxkf7n4dz7g1hkk2_pw9040000gn/T/opencode/uasa_baseline/run2/Deep/ENV1/Rr1/EnvTemplate/test_1.arr (前14行, 共322行) ---
   1|  '2D'
   2|    45.000000000000000     
   3|            1   10.0000000    
   4|            4   25.0000000       50.0000000       100.000000       300.000000    
   5|            3   5000.0000000000000        30000.000000000000        60000.000000000000     
   6|           36
   7|           20
   8|    5.35606359E-09   360.000000       6.22682190      -1.34906159E-05  -58.6085358       58.2437973               2           1
   9|    4.96443988E-08   360.000000       6.22811604      -1.34923848E-05  -58.2745819       57.7906342               2           1
  10|    2.10870226E-07   360.000000       6.22934961      -1.34935854E-05  -57.9406319       57.2084694               2           1
  11|    3.97235539E-07   360.000000       6.23013306      -1.34937318E-05  -57.6066780       56.4234123               2           1
  12|    3.99653572E-07   180.000000       6.20303822      -1.34327229E-05  -57.2727280      -56.0986176               1           1
  13|    2.08736978E-07   180.000000       6.20351458      -1.34322154E-05  -56.9387741      -56.2192001               1           1
  14|    4.69155950E-08   180.000000       6.20403862      -1.34318598E-05  -56.5805588      -56.1412163               1           1

## S5 A4 — read_arrivals_asc + ArrReader（生产参数）
- test_1.arr: Pos.freq=45, 接收深度 Pos.r.z=[25;50;100;300], 接收距离=[5000;30000;60000]
- 每接收点声线数 Narr: min=17, max=36, 总和=303
- ENV_ARR_less.mat: ARR 尺寸=5x4 (频率×深度), 字段=Amp,Delay,phase,freq,rd
- ARR.Delay(s): n=191, NaN=0, min=3.24916, max=41.3141, mean=25.1579, std=14.4147
- ARR.Amp: n=191, NaN=0, min=2.40319e-08, max=7.25992e-05, mean=5.17547e-06, std=1.1311e-05
- ARR.phase(rad): n=191, min=-3.14159, max=1.74846e-07
- ARR(1,1): freq=45, rd=25, 声线数=3; ARR(end,end): freq=54, rd=300, 声线数=4

## S6 A5 — TargSigGenerator（Amp_source=1e5, fs=52734 硬编码，CURRENT BEHAVIOR）
- 信号频率与缩减集耦合: 信号频率数=147, 命中=5
- 生产默认(无rng,全段) 两次调用输出完全一致: 1
  → randi 无种子但 StartMax=1 → randi(1)≡1（CURRENT BEHAVIOR：A5 生产路径确定；随机性仅在 TargSegNum<N 时暴露，见 PROBE）
  第1次: len=580786, min=-0.0346117, max=0.0348129, mean=-1.85053e-14, std=0.0129381, NaN=0, Inf=0
  第2次: len=580786, min=-0.0346117, max=0.0348129, mean=-1.85053e-14, std=0.0129381
  TargT 末值: 11.0135 s
  两次长度一致: 1 (StartSeg 随机 → 若一致属巧合)
- test-controlled rng(42) 两次调用输出完全一致: 1
  seeded: len=580786, min=-0.0346117, max=0.0348129, mean=-1.85053e-14, std=0.0129381, NaN=0, Inf=0
  seeded 前5样本(高精度参考值): -0.00028415693668648601 -0.00027987477369606495 -0.00027558344299905002 -0.00027128311921842396 -0.0002669739187695086
- PROBE TargSegNum=10: 三次调用(len=528052/528052/528052) 两两一致: 1/1/1
  PROBE rng(42)+TargSegNum=10 两次一致: 1, len=528052
  PROBE sigC4 统计: min=-0.0346117, max=0.0348129, mean=2.33723e-13, std=0.0125546
  PROBE2 会话内不重置连续两次(TargSegNum=10) 一致: 1（len=528052/528052）

## S7 跨运行确定性比对
- S1 一致性: fs=1, N=1, AfF numel=1, AfF 向量一致=1, maxAmp=1
- S2: FileMaker 模板文件跨运行字节级一致=1
- S5: ARR 跨运行 isequal=1
- S6: seeded TargSig 跨运行 isequal=1

--- 报告结束 ---
