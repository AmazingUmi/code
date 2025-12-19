#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <omp.h>
#include <cstdlib>
#include <chrono>
#include <unistd.h>  // Linux 下用于 chdir 函数

// 改变当前工作目录
void changeDirectory(const std::string& path) {
    if (chdir(path.c_str()) != 0) {
        std::cerr << "无法切换到目录: " << path << std::endl;
        exit(1);  // 如果目录切换失败，程序退出
    }
}

// 执行 bellhop.exe 命令
void runBellhop(const std::string& envFile) {
    std::string command = "./bellhop " + envFile;  // 假设 bellhop 是当前目录下的可执行文件
    system(command.c_str()); // 执行命令
}

int main(int argc, char* argv[]) {
    // 检查命令行参数
    if (argc < 2) {
        std::cerr << "用法: " << argv[0] << " <工作目录路径>" << std::endl;
        std::cerr << "示例: ./parallel /path/to/env/directory" << std::endl;
        return 1;
    }

    // 开始计时
    auto start_time = std::chrono::high_resolution_clock::now();  // 获取当前时间

    // 从命令行参数获取工作目录
    std::string path = argv[1];
    std::cout << "切换到工作目录: " << path << std::endl;
    changeDirectory(path);

    // 打开环境文件列表
    std::ifstream inputFile("env_files_list.txt");
    if (!inputFile) {
        std::cerr << "无法打开文件 env_files_list.txt" << std::endl;
        return 1;
    }

    std::vector<std::string> envFiles;
    std::string line;

    // 读取所有环境文件路径，去除行尾可能的 \r（Windows 兼容）
    while (std::getline(inputFile, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        envFiles.push_back(line);
    }

    // 使用OpenMP并行调用bellhop
#pragma omp parallel for
    for (int i = 0; i < static_cast<int>(envFiles.size()); ++i) {
        runBellhop(envFiles[i]);
    }

    // 结束计时
    auto end_time = std::chrono::high_resolution_clock::now();  // 获取当前时间
    std::chrono::duration<double> duration = end_time - start_time;  // 计算时间差

    // 打印运行时间
    std::cout << "程序运行时间: " << duration.count() << "秒" << std::endl;

    return 0;
}
