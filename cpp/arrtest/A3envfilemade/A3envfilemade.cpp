#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <filesystem>
#include <chrono>
#include <iomanip>
#include <stdexcept>
#include <omp.h>

namespace fs = std::filesystem;

// 按换行符分割字符串
std::vector<std::string> splitLines(const std::string& str) {
    std::vector<std::string> lines;
    std::istringstream stream(str);
    std::string line;
    while (std::getline(stream, line))
        lines.push_back(line);
    return lines;
}

// 将多行内容合并成一个字符串，每行末尾添加换行符
std::string joinLines(const std::vector<std::string>& lines) {
    std::ostringstream oss;
    for (const auto& line : lines)
        oss << line << "\n";
    return oss.str();
}

// 获取当前日期，格式化为 yyyymmdd
std::string getCurrentDate() {
    auto now = std::chrono::system_clock::now();
    std::time_t tnow = std::chrono::system_clock::to_time_t(now);
    std::tm tm_now;
#if defined(_MSC_VER)
    localtime_s(&tm_now, &tnow);
#else
    localtime_r(&tnow, &tm_now);
#endif
    std::ostringstream oss;
    oss << std::put_time(&tm_now, "%Y%m%d");
    return oss.str();
}

// 从文本文件读取频率数据，每行一个浮点数
std::vector<double> loadAnalyFreqAll(const std::string& filename) {
    std::vector<double> freqs;
    std::ifstream infile(filename);
    if (!infile)
        throw std::runtime_error("无法打开频率数据文件: " + filename);
    double freq;
    while (infile >> freq) {
        freqs.push_back(freq);
    }
    infile.close();
    return freqs;
}


int main() {
    try {
        // 1. 初始化与路径设置（与 MATLAB 代码保持一致）
        std::string ENVall_folder = "G:\\database\\Enhanced_shipsEar0410";
        std::vector<std::string> ENV_classes = { "Shallow", "Transition", "Deep" };
        std::string Signal_folder_path = "G:\\database\\shipsEar\\Shipsear_signal_folder";
        // 请先将 Analy_freq_all.mat 转为文本文件，文件内每行一个频率数据
        std::string freqFile = Signal_folder_path + "\\Analy_freq_all.txt";
        std::vector<double> Analy_freq_all = loadAnalyFreqAll(freqFile);

        if (Analy_freq_all.empty())
            throw std::runtime_error("频率数据为空，请检查 " + freqFile);
        std::cout << "读取到频率数据个数: " << Analy_freq_all.size() << std::endl;

        // 2. 遍历各环境类别目录
        for (const auto& envClass : ENV_classes) {
            fs::path ENV_class_path = fs::path(ENVall_folder) / envClass;
            if (!fs::exists(ENV_class_path) || !fs::is_directory(ENV_class_path)) {
                std::cerr << "目录不存在: " << ENV_class_path.string() << "\n";
                continue;
            }
            // 遍历当前环境类别下的所有单一环境文件夹
            for (const auto& singleEntry : fs::directory_iterator(ENV_class_path)) {
                if (!singleEntry.is_directory())
                    continue;
                fs::path ENV_single_folder = singleEntry.path();
                // 遍历单一环境文件夹内的子文件夹（环境子类文件夹）
                for (const auto& rrEntry : fs::directory_iterator(ENV_single_folder)) {
                    if (!rrEntry.is_directory())
                        continue;
                    // 构造目标环境文件夹：在子文件夹下创建 "envfilefolder"
                    fs::path ENV_Rr_folder = rrEntry.path() / "envfilefolder";
                    if (!fs::exists(ENV_Rr_folder)) {
                        fs::create_directories(ENV_Rr_folder);
                        std::cout << "文件夹 \"" << ENV_Rr_folder.string() << "\" 已创建。\n";
                    }
                    else {
                        std::cout << "文件夹 \"" << ENV_Rr_folder.string() << "\" 已存在。\n";
                    }

                    // 在 envfilefolder 内查找以 "ENV" 开头的基础环境文件（例如 ENVxxx.env）
                    fs::path baseEnvFile;
                    for (const auto& fileEntry : fs::directory_iterator(ENV_Rr_folder)) {
                        if (fileEntry.is_regular_file()) {
                            std::string fname = fileEntry.path().filename().string();
                            // 判断文件名以 "ENV" 开头，并且扩展名为 ".env"
                            if (fname.find("ENV") == 0 && fileEntry.path().extension() == ".env") {
                                baseEnvFile = fileEntry.path();
                                break;
                            }
                        }
                    }
                    if (baseEnvFile.empty()) {
                        std::cerr << "在 " << ENV_Rr_folder.string() << " 中未找到以 'ENV' 开头且扩展名为 .env 的文件。\n";
                        continue;
                    }

                    // 得到基础文件名（不含扩展名），例如 "ENVxxx"
                    std::string envallname = baseEnvFile.stem().string();

                    // 读取基础 .env 文件内容
                    std::ifstream infile(baseEnvFile.string());

                    if (!infile) {
                        std::cerr << "无法打开文件: " << baseEnvFile.string() << "\n";
                        continue;
                    }
                    std::stringstream buffer;
                    buffer << infile.rdbuf();
                    std::string fileContents = buffer.str();
                    infile.close();

                    // 分割文件内容按行存入 vector
                    std::vector<std::string> baselines = splitLines(fileContents);
                    if (baselines.size() < 2) {
                        std::cerr << "文件 " << baseEnvFile.string() << " 行数不足。\n";
                        continue;
                    }

                    // 预分配新文件名存储容器
                    std::vector<std::string> newFilenames(Analy_freq_all.size());

                    // 3. 使用 OpenMP 并行生成新环境文件，每个频率生成一个文件
#pragma omp parallel for schedule(dynamic)
                    for (int m = 0; m < static_cast<int>(Analy_freq_all.size()); m++) {
                        try {
                            // 生成新文件名：例如 "test_1", "test_2", ...
                            std::string newName = "test_" + std::to_string(m + 1);
                            newFilenames[m] = newName;

                            // 拷贝基础内容到局部变量，并修改第二行为新的频率
                            std::vector<std::string> lines = baselines;
                            std::ostringstream freqLine;
                            freqLine << "  " << Analy_freq_all[m] << "  	 	 	 ! Frequency (Hz) ";
                            if (lines.size() >= 2)
                                lines[1] = freqLine.str();
                            std::string newFileContent = joinLines(lines);

                            // 定义新 .env 文件的输出完整路径
                            fs::path newEnvPath = ENV_Rr_folder / (newName + ".env");
                            std::ofstream outfile(newEnvPath);
                            if (!outfile) {
#pragma omp critical
                                std::cerr << "无法创建文件: " << newEnvPath.string() << "\n";
                                continue;
                            }
                            outfile << newFileContent;
                            outfile.close();

                            // 复制其他相关文件：.trc, .bty, .brc
                            fs::path source_trc = ENV_Rr_folder / (envallname + ".trc");
                            fs::path source_bty = ENV_Rr_folder / (envallname + ".bty");
                            fs::path source_brc = ENV_Rr_folder / (envallname + ".brc");

                            fs::path target_trc = ENV_Rr_folder / (newName + ".trc");
                            fs::path target_bty = ENV_Rr_folder / (newName + ".bty");
                            fs::path target_brc = ENV_Rr_folder / (newName + ".brc");

                            fs::copy_file(source_trc, target_trc, fs::copy_options::overwrite_existing);
                            fs::copy_file(source_bty, target_bty, fs::copy_options::overwrite_existing);
                            fs::copy_file(source_brc, target_brc, fs::copy_options::overwrite_existing);
                        }
                        catch (const std::exception& e) {
#pragma omp critical
                            std::cerr << "Error in iteration " << m << ": " << e.what() << "\n";
                        }
                    } // end parallel for

                    // 4. 将所有新生成的文件名写入文件列表：env_files_list.txt
                    fs::path listFilePath = ENV_Rr_folder / "env_files_list.txt";
                    std::ofstream listFile(listFilePath);
                    if (!listFile)
                        std::cerr << "无法创建文件列表: " << listFilePath.string() << "\n";
                    else {
                        for (const auto& name : newFilenames)
                            listFile << name << "\n";
                        listFile.close();
                    }
                } // end for 遍历 ENV_Rr_folder 内各子文件夹
            } // end for 遍历单一环境文件夹
        } // end for 遍历 ENV_classes

        // 5. 压缩打包整个环境文件夹
        fs::path parentDir = fs::path(ENVall_folder).parent_path();
        fs::current_path(parentDir);
        std::string zipname = "ENVall_files_" + getCurrentDate();
        std::ostringstream systemline;
        systemline << "tar -czf " << zipname << ".tar.gz " << fs::path(ENVall_folder).filename().string();
        std::cout << "执行压缩命令：" << systemline.str() << "\n";
        int ret = system(systemline.str().c_str());
        if (ret != 0)
            std::cerr << "压缩命令执行失败，返回值: " << ret << "\n";

        std::cout << "全部处理完成！\n";
    }
    catch (const std::exception& ex) {
        std::cerr << "程序异常: " << ex.what() << "\n";
        return -1;
    }

    return 0;
}
