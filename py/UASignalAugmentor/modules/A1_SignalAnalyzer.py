"""
频率分析模块

对应MATLAB: A1wavtrans.m, A2wavfilter.m

功能：
- 读取原始船舶音频文件
- 分段FFT分析（1秒窗口）
- 全局阈值筛选（合并A2逻辑，避免重复滤除）
- 保存频率、幅值、相位信息
"""
# 自带包
import logging
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass, field
import time
# 第三方包
import numpy as np
import soundfile as sf
from tqdm import tqdm
# 本地包
from utils.io_utils import save_pickle, ensure_dir


@dataclass
class SegmentAnalysis:
    """单个信号段的分析结果"""
    amp: np.ndarray              # 幅值数组
    freq: np.ndarray             # 频率数组 (Hz)
    phase: np.ndarray            # 相位数组 (弧度)


@dataclass
class AudioAnalysisResult:
    """单个音频文件的完整分析结果"""
    fs: int                                    # 采样率
    n_delay: np.ndarray                        # 各段时延 (秒)
    analyze_record: List[SegmentAnalysis]      # 各段分析结果
    analy_freq: np.ndarray                     # 该文件所有频率的并集
    source_file: str                           # 源文件路径
    ship_class: str                            # 船舶类别


class FrequencyAnalyzer:
    """
    音频频率分析器
    
    对应MATLAB: A1wavtrans.m
    
    主要功能：
    1. 遍历指定类别的音频文件
    2. 对每个音频进行分段FFT分析
    3. 提取主要频率成分（幅值、相位）
    4. 保存每个文件的分析结果
    5. 汇总全局频率列表
    
    Attributes:
        config: 配置字典
        logger: 日志记录器
    """
    
    def __init__(self, config: Dict[str, Any]):
        """
        初始化频率分析器
        
        Args:
            config: 配置字典，应包含：
                - input_path: 原始音频根目录
                - output_path: 输出结果目录
                - ship_classes: 船舶类别列表，如['Class A', 'Class B', ...]
                - segment_length: 分段长度（秒），默认1.0
                - threshold: 幅值阈值，默认0.05
                - freq_range: 频率范围 [min_hz, max_hz]，默认[10, 5000]
                - freq_precision: 频率精度（小数位数），默认1
        """
        self.config = config
        self.logger = logging.getLogger(self.__class__.__name__)
        
        # 提取配置参数
        self.input_path = Path(config['input_path'])
        self.output_path = Path(config['output_path'])
        self.ship_classes = config.get('ship_classes', 
                                       ['Class A', 'Class B', 'Class C', 'Class D', 'Class E'])
        self.segment_length = config.get('segment_length', 1.0)
        self.threshold = config.get('threshold', 0.05)
        self.freq_min, self.freq_max = config.get('freq_range', [10, 5000])
        self.freq_precision = config.get('freq_precision', 1)
        
        # 确保输出目录存在
        ensure_dir(self.output_path)
        
        self.logger.info(f"FrequencyAnalyzer initialized with config: {config}")
    
    def process(self, input_path: Optional[Path] = None) -> Dict[str, Any]:
        """
        执行完整的频率分析流程
        
        Args:
            input_path: 可选的输入路径，覆盖配置中的路径
            
        Returns:
            结果字典：
            {
                'num_files_processed': int,           # 处理的文件总数
                'global_frequencies': np.ndarray,     # 全局频率列表
                'results_by_class': dict,             # 按类别统计
                'output_files': list,                 # 输出文件列表
                'elapsed_time': float                 # 处理耗时（秒）
            }
        """
        start_time = time.time()
        input_path = input_path or self.input_path #这条语句只会在 “调用者传进来的 input_path 是 None” 时把 self.input_path 赋给它
        
        self.logger.info(f"Starting frequency analysis from: {input_path}")
        
        # 全局频率集合
        global_frequencies = set()
        results_by_class = {}
        output_files = []
        total_files = 0
        
        # 遍历每个船舶类别
        for ship_class in self.ship_classes:
            class_path = input_path / ship_class
            
            if not class_path.exists():
                self.logger.warning(f"Class directory not found: {class_path}")
                continue
            
            # 获取该类别下的所有WAV文件
            audio_files = list(class_path.glob('*.wav'))
            if not audio_files:
                self.logger.warning(f"No WAV files found in: {class_path}")
                continue
            
            self.logger.info(f"Processing {len(audio_files)} files in {ship_class}")
            results_by_class[ship_class] = {'count': len(audio_files), 'files': []}
            
            # 处理每个音频文件
            for audio_file in tqdm(audio_files, desc=f"{ship_class}"):
                try:
                    result = self._process_single_file(audio_file, ship_class)
                    
                    # 更新全局频率集合
                    global_frequencies.update(result.analy_freq)
                    
                    # 保存单个文件的结果
                    output_file = self._save_result(result, ship_class)
                    output_files.append(output_file)
                    results_by_class[ship_class]['files'].append(str(audio_file.name))
                    
                    total_files += 1
                    
                except Exception as e:
                    self.logger.error(f"Error processing {audio_file}: {e}", exc_info=True)
                    continue
        
        # 转换为排序的numpy数组
        global_frequencies_array = np.array(sorted(global_frequencies))
        
        # 保存全局频率列表
        global_freq_file = self.output_path / 'Analy_freq_all.pkl'
        save_pickle({'frequencies': global_frequencies_array}, global_freq_file)
        self.logger.info(f"Saved global frequencies ({len(global_frequencies_array)} unique) to: {global_freq_file}")
        
        elapsed_time = time.time() - start_time
        
        summary = {
            'num_files_processed': total_files,
            'global_frequencies': global_frequencies_array,
            'num_unique_frequencies': len(global_frequencies_array),
            'results_by_class': results_by_class,
            'output_files': output_files,
            'elapsed_time': elapsed_time
        }
        
        self.logger.info(f"Analysis completed in {elapsed_time:.2f}s. Processed {total_files} files.")
        return summary
    
    def _process_single_file(self, audio_path: Path, ship_class: str) -> AudioAnalysisResult:
        """
        处理单个音频文件
        
        Args:
            audio_path: 音频文件路径
            ship_class: 船舶类别
            
        Returns:
            AudioAnalysisResult对象
        """
        # 读取音频文件
        signal, fs = sf.read(audio_path)
        
        # 如果是多声道，取平均
        if signal.ndim > 1:
            signal = np.mean(signal, axis=1)
        
        # 计算信号参数
        L = len(signal)
        T = L / fs
        
        # 分段参数
        cut_length = int(self.segment_length * fs)
        N = int(np.floor(T / self.segment_length))
        
        if N == 0:
            self.logger.warning(f"Audio too short ({T:.2f}s): {audio_path}")
            N = 1
            cut_length = L
        
        # 计算各段的时延
        n_delay = np.array([(i - 1) * self.segment_length for i in range(1, N + 1)])
        
        # 存储所有段的分析结果
        analyze_record = []
        file_frequencies = set()
        
        # 对每一段进行FFT分析
        for i in range(N):
            start_idx = i * cut_length
            end_idx = min((i + 1) * cut_length, L)
            segment = signal[start_idx:end_idx]
            
            # 如果段长度不足，跳过
            if len(segment) < cut_length // 2:
                continue
            
            # 分析该段（不做分段阈值筛选）
            seg_result = self._analyze_segment(segment, fs, cut_length)
            analyze_record.append(seg_result)
        
        # 合并A2逻辑：基于文件内全局最大幅值做单次阈值筛选
        file_frequencies = set()
        max_amp_global = 0.0
        for seg in analyze_record:
            if seg.amp.size > 0:
                max_amp_global = max(max_amp_global, float(np.max(seg.amp)))
        
        #print(f"[DEBUG] 文件: {audio_path.name}, 全局最大幅值: {max_amp_global:.6f}")
        
        filtered_record: List[SegmentAnalysis] = []
        if max_amp_global > 0:
            for seg in analyze_record:
                if seg.amp.size == 0:
                    filtered_record.append(SegmentAnalysis(amp=np.asarray([]), freq=np.asarray([]), phase=np.asarray([])))
                    continue
                valid_idx = seg.amp >= (self.threshold * max_amp_global)
                amp_f = seg.amp[valid_idx]
                freq_f = seg.freq[valid_idx]
                phase_f = seg.phase[valid_idx]
                filtered_record.append(SegmentAnalysis(amp=amp_f, freq=freq_f, phase=phase_f))
                for f in np.unique(freq_f):
                    file_frequencies.add(float(f))
        else:
            # 无有效幅值，全部置空
            for _ in analyze_record:
                filtered_record.append(SegmentAnalysis(amp=np.asarray([]), freq=np.asarray([]), phase=np.asarray([])))
        
        # 转换为排序的数组
        analy_freq = np.array(sorted(file_frequencies))
        
        return AudioAnalysisResult(
            fs=fs,
            n_delay=n_delay,
            analyze_record=filtered_record,
            analy_freq=analy_freq,
            source_file=str(audio_path),
            ship_class=ship_class
        )
    
    def _analyze_segment(self, segment: np.ndarray, fs: int, cut_length: int) -> SegmentAnalysis:
        """
        对单个信号段进行FFT分析并提取主要频率成分
        
        对齐MATLAB实现 (A1wavtrans.m 第53-58行):
        - signal_f = fft(mid_signal)
        - signal_f_2 = signal_f(1:cut_length/2+1)
        - signal_f_3 = abs(signal_f_2)/cut_length
        - signal_f_3(2:end-1) = 2*signal_f_3(2:end-1)
        - f = (0:cut_length/2)/cut_length*fs
        
        Args:
            segment: 信号段
            fs: 采样率
            cut_length: 期望的段长度(用于频率计算和归一化)
            
        Returns:
            SegmentAnalysis对象
        """
        # FFT变换
        signal_f = np.fft.fft(segment)
        
        # 取单边谱：MATLAB用 signal_f(1:cut_length/2+1)
        # Python索引从0开始，对应 signal_f[0:cut_length//2+1]
        half_len = cut_length // 2 + 1
        signal_f_half = signal_f[:half_len]
        
        # 计算幅值谱：MATLAB用 abs(signal_f_2)/cut_length
        signal_amp = np.abs(signal_f_half) / cut_length
        
        # 单边谱需要乘2：MATLAB的 signal_f_3(2:end-1) = 2*signal_f_3(2:end-1)
        # Python索引：[1:-1] 对应 MATLAB的 (2:end-1)
        signal_amp[1:-1] *= 2
        
        # 计算相位谱
        signal_phase = np.angle(signal_f_half)
        
        # 频率轴：MATLAB用 f = (0:cut_length/2)/cut_length*fs
        freq_axis = np.arange(half_len) / cut_length * fs
        
        # 不在分段内做幅值阈值筛选，保留频率范围内的所有分量
        freq_mask = (freq_axis >= self.freq_min) & (freq_axis <= self.freq_max)
        sig_freq = freq_axis[freq_mask]
        sig_amp = signal_amp[freq_mask]
        sig_phase = signal_phase[freq_mask]
        
        # 频率四舍五入（防止重复）
        sig_freq = np.round(sig_freq, self.freq_precision)
        '''
        调试内容：
        import matplotlib.pyplot as plt
        plt.figure()
        plt.plot(freq_axis, signal_amp)
        plt.xlabel('频率 (Hz)')
        plt.ylabel('幅值')
        plt.title(f'频谱图')
        plt.grid(True)
        plt.show()
        '''
        return SegmentAnalysis(
            amp=sig_amp,
            freq=sig_freq,
            phase=sig_phase
        )
    
    def _save_result(self, result: AudioAnalysisResult, ship_class: str) -> Path:
        """
        保存单个文件的分析结果
        
        Args:
            result: 分析结果
            ship_class: 船舶类别
            
        Returns:
            输出文件路径
        """
        # 构造输出文件名
        source_name = Path(result.source_file).stem
        output_filename = f"{ship_class}_{source_name}.pkl"
        output_path = self.output_path / output_filename
        
        # 转换为可序列化的字典
        data = {
            'fs': result.fs,
            'n_delay': result.n_delay,
            'analyze_record': [
                {
                    'amp': seg.amp,
                    'freq': seg.freq,
                    'phase': seg.phase
                }
                for seg in result.analyze_record
            ],
            'analy_freq': result.analy_freq,
            'source_file': result.source_file,
            'ship_class': result.ship_class
        }
        
        save_pickle(data, output_path)
        return output_path


# 便捷函数
def analyze_audio_frequencies(
    input_path: str,
    output_path: str,
    ship_classes: Optional[List[str]] = None,
    **kwargs
) -> Dict[str, Any]:
    """
    便捷函数：执行音频频率分析
    
    Args:
        input_path: 输入音频根目录
        output_path: 输出目录
        ship_classes: 船舶类别列表
        **kwargs: 其他配置参数
        
    Returns:
        分析结果字典
    """
    config = {
        'input_path': input_path,
        'output_path': output_path,
        'ship_classes': ship_classes or ['Class A', 'Class B', 'Class C', 'Class D', 'Class E'],
        **kwargs
    }
    
    analyzer = FrequencyAnalyzer(config)
    return analyzer.process()
