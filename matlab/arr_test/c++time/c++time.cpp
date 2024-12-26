#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <omp.h>
#include <cstdlib>
#include <windows.h>  // For SetCurrentDirectory and GetModuleFileName
#include <chrono>     // For high resolution timing

// Get executable file path
std::string getExecutablePath() {
    char result[MAX_PATH];
    if (GetModuleFileNameA(NULL, result, MAX_PATH) == 0) {
        std::cerr << "无法获取可执行文件路径" << std::endl;
        exit(1);
    }
    std::string path(result);
    return path.substr(0, path.find_last_of("\\"));
}

// Change working directory
void changeDirectory(const std::string& path) {
    if (SetCurrentDirectoryA(path.c_str()) == 0) {
        std::cerr << "无法切换到目录: " << path << std::endl;
        exit(1);
    }
}

// Execute bellhop command
void runBellhop(const std::string& bellhopPath, const std::string& envFile) {
    std::string command = bellhopPath + ".exe " + envFile; // Windows-specific command
    int result = system(command.c_str());
    if (result != 0) {
        std::cerr << "Error executing command: " << command << std::endl;
    }
}

int main(int argc, char* argv[]) {
        // 设置控制台输出为UTF-8
    SetConsoleOutputCP(CP_UTF8);
    
    if (argc < 2) {
        std::cerr << "用法: " << argv[0] << " /path/to/env" << std::endl;
        return 1;
    }

    std::string envDir = argv[1];
    std::string exeDir = getExecutablePath(); // Get executable path
    std::string bellhopPath = exeDir + "\\bellhop"; // Bellhop executable path for Windows

    changeDirectory(envDir); // Change working directory to envDir

    // Read environment file list
    std::ifstream inputFile("env_files_list.txt");
    if (!inputFile) {
        std::cerr << "无法打开文件 env_files_list.txt" << std::endl;
        return 1;
    }

    std::vector<std::string> envFiles;
    std::string line;
    while (std::getline(inputFile, line)) {
        envFiles.push_back(line);
    }

    // Start timing
    auto start_time = std::chrono::high_resolution_clock::now();

    // Parallel execution using OpenMP
    #pragma omp parallel for
    for (int i = 0; i < envFiles.size(); ++i) {
        runBellhop(bellhopPath, envFiles[i]);
    }

    // End timing
    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration = end_time - start_time;
    std::cout << "程序运行时间: " << duration.count() << " 秒" << std::endl;

    return 0;
}
