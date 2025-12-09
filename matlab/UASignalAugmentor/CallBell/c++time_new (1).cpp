#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <omp.h>
#include <cstdlib>
#include <unistd.h>
#include <libgen.h>  // 用于 dirname
#include <limits.h>  // 用于 PATH_MAX
#include <chrono>    // 用于高分辨率计时

// 获取可执行文件所在目录
std::string getExecutablePath() {
    char result[PATH_MAX];
    ssize_t count = readlink("/proc/self/exe", result, PATH_MAX - 1);
    if (count == -1) {
        std::cerr << "无法获取可执行文件路径" << std::endl;
        exit(1);
    }
    result[count] = '\0'; // 添加字符串结束符
    return std::string(dirname(result));
}

// 改变当前工作目录
void changeDirectory(const std::string& path) {
    if (chdir(path.c_str()) != 0) {
        std::cerr << "无法切换到目录: " << path << std::endl;
        exit(1);
    }
}

// 执行 bellhop 命令
void runBellhop(const std::string& bellhopPath, const std::string& envFile) {
    std::string command = bellhopPath + ".exe " + envFile;  // 构建命令
    system(command.c_str());  // 执行命令
}

int main(int argc, char* argv[]) {
    // 检查命令行参数
    if (argc < 2) {
        std::cerr << "用法: " << argv[0] << " /path/to/env" << std::endl;
        return 1;
    }

    // 获取环境目录
    std::string envDir = argv[1];

    // 获取可执行文件所在目录
    std::string exeDir = getExecutablePath();

    // 拼接 bellhop 的路径
    std::string bellhopPath = exeDir + "/bellhop";

    // 切换到环境目录
    changeDirectory(envDir);

    // 打开环境文件列表
    std::ifstream inputFile("env_files_list.txt");
    if (!inputFile) {
        std::cerr << "无法打开文件 env_files_list.txt" << std::endl;
        return 1;
    }

    std::vector<std::string> envFiles;
    std::string line;
    // 读取所有环境文件路径，并去除每行末尾可能的 '\r'
    while (std::getline(inputFile, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        envFiles.push_back(line);
    }
    inputFile.close();

    // 开始计时
    auto start_time = std::chrono::high_resolution_clock::now();

    // 使用 OpenMP 并行调用 bellhop，每个线程运行一个 env 文件
#pragma omp parallel for
    for (int i = 0; i < static_cast<int>(envFiles.size()); ++i) {
        runBellhop(bellhopPath, envFiles[i]);
    }

    // 结束计时
    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration = end_time - start_time;
    std::cout << "程序运行时间: " << duration.count() << " 秒" << std::endl;

    return 0;
}
