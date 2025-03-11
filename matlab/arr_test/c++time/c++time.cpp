#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <omp.h>
#include <cstdlib>
#include <direct.h>  // 用于 _chdir 函数
#include <chrono>    // 引入chrono库来计时

// 改变当前工作目录
void changeDirectory(const std::string& path) {
    if (_chdir(path.c_str()) != 0) {
        std::cerr << "无法切换到目录: " << path << std::endl;
        exit(1);  // 如果目录切换失败，程序退出
    }
}

// 执行 bellhop.exe 命令
void runBellhop(const std::string& envFile) {
    std::string command = "D:/database/at_2023_5_18/at/bin/bellhop.exe " + envFile;
    system(command.c_str()); // 执行命令
}

int main() {
    // 开始计时
    auto start_time = std::chrono::high_resolution_clock::now();  // 获取当前时间

    // 设置路径，可以根据需要修改
    std::string path = "D:/database/Enhanced_shipsEar/ENV1/envfilefolder";  // 设置你希望进入的路径
    changeDirectory(path);

    // 打开环境文件列表
    std::ifstream inputFile("env_files_list.txt");
    if (!inputFile) {
        std::cerr << "无法打开文件 env_files_list.txt" << std::endl;
        return 1;
    }

    std::vector<std::string> envFiles;
    std::string line;

    // 读取所有环境文件路径
    while (std::getline(inputFile, line)) {
        envFiles.push_back(line);
    }

    // 使用OpenMP并行调用bellhop.exe
#pragma omp parallel for
    for (int i = 0; i < envFiles.size(); ++i) {
        runBellhop(envFiles[i]);
    }

    // 结束计时
    auto end_time = std::chrono::high_resolution_clock::now();  // 获取当前时间
    std::chrono::duration<double> duration = end_time - start_time;  // 计算时间差

    // 打印运行时间
    std::cout << "程序运行时间: " << duration.count() << "秒" << std::endl;

    return 0;
}