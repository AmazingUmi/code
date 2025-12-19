#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <omp.h>
#include <cstdlib>
#include <direct.h>  // For _chdir function
#include <chrono>    // Include chrono library for timing
#include <windows.h> // For GetModuleFileNameA function

// Change current working directory
void changeDirectory(const std::string& path) {
    if (_chdir(path.c_str()) != 0) {
        std::cerr << "Cannot change directory to: " << path << std::endl;
        exit(1);  // Exit if directory change fails
    }
}

// Execute bellhop.exe command
void runBellhop(const std::string& envFile, const std::string& bellhopPath) {
    // Windows system() quirk: If the command starts with a quote, cmd.exe might strip the first and last quote.
    // To prevent this, we wrap the entire command in an outer pair of quotes.
    // The final command sent to cmd looks like: ""path\to\bellhop.exe" "file.env""
    std::string command = "\"\"" + bellhopPath + "\" \"" + envFile + "\"\"";
    system(command.c_str()); // Execute command
}

int main(int argc, char* argv[]) {
    // Check command line arguments
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <working_directory_path>" << std::endl;
        std::cerr << "Example: BellParallelWin.exe D:/ENV/folder" << std::endl;
        return 1;
    }

    // Start timing
    auto start_time = std::chrono::high_resolution_clock::now();  // Get current time

    // Get working directory from command line arguments
    std::string path = argv[1];
    
    // Get the directory of the current executable, use bellhop.exe in the CallBell directory
    char exePath[1024];
    GetModuleFileNameA(NULL, exePath, sizeof(exePath));
    std::string exeDir = exePath;
    size_t pos = exeDir.find_last_of("\\");
    if (pos != std::string::npos) {
        exeDir = exeDir.substr(0, pos);
    }
    std::string bellhopPath = exeDir + "\\bellhop.exe";
    
    std::cout << "Switching to working directory: " << path << std::endl;
    std::cout << "Bellhop path: " << bellhopPath << std::endl;
    changeDirectory(path);

    // Open environment files list
    std::ifstream inputFile("env_files_list.txt");
    if (!inputFile) {
        std::cerr << "Cannot open file env_files_list.txt" << std::endl;
        return 1;
    }

    std::vector<std::string> envFiles;
    std::string line;

    // Read all environment file paths
    while (std::getline(inputFile, line)) {
        // Remove possible Windows carriage return
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        if (!line.empty()) {
            envFiles.push_back(line);
        }
    }

    // Use OpenMP to call bellhop.exe in parallel
#pragma omp parallel for
    for (int i = 0; i < envFiles.size(); ++i) {
        runBellhop(envFiles[i], bellhopPath);
    }

    // End timing
    auto end_time = std::chrono::high_resolution_clock::now();  // Get current time
    std::chrono::duration<double> duration = end_time - start_time;  // Calculate duration

    // Print runtime
    std::cout << "Program runtime: " << duration.count() << " seconds" << std::endl;

    return 0;
}