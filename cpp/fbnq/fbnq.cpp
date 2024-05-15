#include <iostream>
#include <vector>
#include <chrono>
#include <omp.h>

// 计算斐波那契数列
void fibonacci_parallel(int n, std::vector<unsigned long long>& fib) {
    fib.resize(n);
#pragma omp parallel
    {
        int tid = omp_get_thread_num();
        int num_threads = omp_get_num_threads();

#pragma omp for
        for (int i = 0; i < n; ++i) {
            if (i == 0)
                fib[i] = 0;
            else if (i == 1)
                fib[i] = 1;
            else
                fib[i] = fib[i - 1] + fib[i - 2];
        }
    }
}

int main() {
    const int n = 500; // 要计算的斐波那契数列的个数
    std::vector<unsigned long long> fib_serial(n);
    std::vector<unsigned long long> fib_parallel(n);

    // 测量串行版本的执行时间
    auto start_serial = std::chrono::steady_clock::now();
    for (int i = 0; i < n; ++i) {
        if (i == 0)
            fib_serial[i] = 0;
        else if (i == 1)
            fib_serial[i] = 1;
        else
            fib_serial[i] = fib_serial[i - 1] + fib_serial[i - 2];
    }
    auto end_serial = std::chrono::steady_clock::now();
    std::chrono::duration<double> elapsed_serial = end_serial - start_serial;
    std::cout << "Serial execution time: " << elapsed_serial.count() << " seconds\n";

    // 测量并行版本的执行时间
    auto start_parallel = std::chrono::steady_clock::now();
    fibonacci_parallel(n, fib_parallel);
    auto end_parallel = std::chrono::steady_clock::now();
    std::chrono::duration<double> elapsed_parallel = end_parallel - start_parallel;
    std::cout << "Parallel execution time: " << elapsed_parallel.count() << " seconds\n";

    // 计算加速比
    double speedup = elapsed_serial.count() / elapsed_parallel.count();
    std::cout << "Speedup: " << speedup << "\n";

    // 输出前几个斐波那契数列
    /*
    for (int i = 0; i < n; ++i) {
        std::cout << "Fibonacci[" << i << "] = " << fib_parallel[i] << "\n";
    }
    */

    return 0;
}
