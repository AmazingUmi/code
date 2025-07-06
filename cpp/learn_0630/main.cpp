// 头文件包含部分 - 这些是C++标准库的重要组成部分
#include <iostream>     // 输入输出流，提供std::cout, std::cin等
#include <vector>       // 动态数组容器，可以自动扩展大小
#include <string>       // 字符串类，比C风格字符串更安全易用
#include <memory>       // 智能指针，自动管理内存，避免内存泄漏
#include <algorithm>    // 算法库，提供排序、查找等常用算法
#include <map>          // 关联容器，存储键值对，自动排序
#include <fstream>      // 文件流，用于文件读写操作
#include <exception>    // 异常处理相关类和函数

// 1. 命名空间 - 用于避免名称冲突，组织代码
// 相当于给变量和函数加上"姓氏"，避免重名问题
namespace MyNamespace {
    // 在命名空间内定义的常量，使用时需要加上命名空间前缀
    const int GLOBAL_CONSTANT = 100;
}

// 2. 抽象基类定义 - 展示面向对象编程的核心概念
class Animal {
protected:  // protected访问修饰符：只有本类和派生类可以访问
    std::string name;   // 动物名字，使用std::string而不是char*更安全
    int age;            // 动物年龄
    
public:     // public访问修饰符：外部代码可以访问
    // 构造函数 - 创建对象时自动调用，用于初始化对象
    // const std::string& 表示传入字符串的常量引用，避免不必要的复制
    // 使用初始化列表语法 : name(n), age(a) 直接初始化成员变量，比在函数体内赋值更高效
    Animal(const std::string& n, int a) : name(n), age(a) {}
    
    // 虚析构函数 - 当通过基类指针删除派生类对象时，确保正确调用派生类的析构函数
    // = default 表示使用编译器生成的默认实现
    virtual ~Animal() = default;
    
    // 纯虚函数 - 函数声明后加 = 0，表示这是一个抽象函数
    // 包含纯虚函数的类称为抽象类，不能直接实例化，只能被继承
    // const 表示这个函数不会修改对象的状态
    virtual void makeSound() const = 0;
    
    // 普通虚函数 - 可以被派生类重写(override)
    // virtual关键字使得通过基类指针调用时能调用到派生类的版本（多态）
    virtual void introduce() const {
        std::cout << "我是 " << name << "，今年 " << age << " 岁" << std::endl;
    }
    
    // getter方法 - 提供对私有/保护成员的只读访问
    // const成员函数表示不会修改对象状态，可以被const对象调用
    std::string getName() const { return name; }
    int getAge() const { return age; }
};

// 3. 派生类（继承）- 从Animal类继承，获得Animal的所有公有和保护成员
class Dog : public Animal {  // public继承：Animal的public成员在Dog中仍为public
private:    // private访问修饰符：只有本类可以访问
    std::string breed;  // 狗的品种，Dog类特有的属性
    
public:
    // 派生类构造函数 - 必须调用基类构造函数来初始化继承的成员
    // : Animal(n, a) 调用基类构造函数，breed(b) 初始化派生类特有成员
    Dog(const std::string& n, int a, const std::string& b) 
        : Animal(n, a), breed(b) {}
    
    // 重写(override)基类的纯虚函数 - 必须实现，否则Dog也会成为抽象类
    // override关键字（C++11）：明确表示这是重写基类虚函数，编译器会检查签名是否匹配
    void makeSound() const override {
        // 可以直接访问protected成员name，因为这是继承关系
        std::cout << name << " 汪汪叫！" << std::endl;
    }
    
    // 重写基类的虚函数，提供Dog特有的实现
    void introduce() const override {
        // 调用基类的方法，复用代码，然后添加额外信息
        Animal::introduce();  // 作用域解析运算符 :: 明确调用基类版本
        std::cout << "我是一只 " << breed << std::endl;
    }
    
    // 友元函数声明 - 允许外部函数访问私有成员
    // 友元打破了封装性，但在某些情况下很有用（如操作符重载）
    friend void playWithDog(const Dog& dog);
};

// 另一个派生类，展示多态性
class Cat : public Animal {
public:
    // 相比Dog，Cat的构造函数更简单，只需要名字和年龄
    Cat(const std::string& n, int a) : Animal(n, a) {}
    
    // 实现基类的纯虚函数，提供Cat特有的行为
    void makeSound() const override {
        std::cout << name << " 喵喵叫！" << std::endl;
    }
    // 注意：Cat没有重写introduce()函数，所以会使用基类的默认实现
};

// 4. 友元函数定义 - 可以访问Dog类的私有成员
// 友元函数不属于任何类，但被类授权访问其私有成员
// const Dog& 表示传入Dog对象的常量引用，不会修改对象且避免复制开销
void playWithDog(const Dog& dog) {
    // 直接访问Dog的私有成员name，这在普通函数中是不被允许的
    std::cout << "正在和 " << dog.name << " 玩耍！" << std::endl;
}

// 5. 函数模板 - 泛型编程，一个函数可以处理多种数据类型
// template<typename T> 声明这是一个模板，T是类型参数
// typename 可以用 class 替代，但typename更清晰地表示这是一个类型
template<typename T>
T getMax(T a, T b) {
    // 条件运算符 ?: 是if-else的简写形式
    // 要求类型T必须支持 > 运算符
    return (a > b) ? a : b;
}

// 6. 类模板 - 创建可以存储任意类型数据的通用容器
template<typename T>
class Container {
private:
    // 使用标准库的vector作为底层存储
    std::vector<T> items;
    
public:
    // 添加元素到容器
    // const T& 避免不必要的复制，特别是当T是复杂对象时
    void add(const T& item) {
        items.push_back(item);  // vector的成员函数，在末尾添加元素
    }
    
    // 获取指定位置的元素
    // size_t 是无符号整数类型，通常用于表示大小和索引
    T get(size_t index) const {
        if (index < items.size()) {
            return items[index];
        }
        // 抛出标准异常，比返回错误码更现代的错误处理方式
        throw std::out_of_range("索引超出范围");
    }
    
    // 返回容器中元素的数量
    size_t size() const { return items.size(); }
    
    // 提供迭代器接口，使得容器可以使用范围for循环
    // typename 关键字告诉编译器这是一个类型名，而不是静态成员
    typename std::vector<T>::iterator begin() { return items.begin(); }
    typename std::vector<T>::iterator end() { return items.end(); }
};

// 7. 强类型枚举类 (C++11特性) - 比传统enum更安全
// enum class 创建一个作用域枚举，避免名称污染
// 传统enum的值会直接暴露到外层作用域，容易造成命名冲突
enum class Color {
    RED,    // 默认值为0
    GREEN,  // 值为1
    BLUE    // 值为2
    // 使用时必须加上作用域：Color::RED
};

// 8. 结构体 - 类似类，但成员默认为public
// 通常用于简单的数据聚合，不需要复杂的封装
struct Point {
    double x, y;    // 坐标值，默认为public
    
    // 构造函数，提供默认参数
    // = 0 表示参数的默认值，调用时可以省略
    Point(double x = 0, double y = 0) : x(x), y(y) {}
    
    // 运算符重载 - 让自定义类型支持内置运算符
    // operator+ 重载加法运算符，返回新的Point对象
    Point operator+(const Point& other) const {
        // 创建并返回新对象，不修改当前对象（const函数）
        return Point(x + other.x, y + other.y);
    }
    
    // 重载等于运算符，用于比较两个Point是否相等
    bool operator==(const Point& other) const {
        // 浮点数比较通常需要考虑精度问题，这里简化处理
        return x == other.x && y == other.y;
    }
};

// 9. 函数对象/仿函数 - 重载了调用运算符()的类
// 函数对象比普通函数更灵活，可以保存状态，支持内联优化
class Multiplier {
private:
    int factor;     // 乘数因子，保存在对象中的状态
    
public:
    // 构造函数初始化乘数因子
    Multiplier(int f) : factor(f) {}
    
    // 重载函数调用运算符()，使对象可以像函数一样被调用
    // 这就是为什么叫"函数对象"的原因
    int operator()(int value) const {
        return value * factor;
    }
};

// 10. 自定义异常类 - 继承自标准异常类
// 创建自己的异常类型，提供更具体的错误信息
class CustomException : public std::exception {
private:
    std::string message;    // 错误信息
    
public:
    // 构造函数接收错误信息
    CustomException(const std::string& msg) : message(msg) {}
    
    // 重写基类的what()函数，返回错误信息
    // noexcept 关键字表示这个函数不会抛出异常
    // override 确保正确重写了基类的虚函数
    const char* what() const noexcept override {
        return message.c_str(); // 返回C风格字符串
    }
};

// 主函数 - 程序的入口点
int main() {
    // std::cout 是标准输出流，<< 是流插入运算符
    // std::endl 输出换行符并刷新缓冲区
    std::cout << "=== C++ 综合语法示例程序 ===" << std::endl;
    
    // try-catch 异常处理块 - 现代C++推荐的错误处理方式
    try {
        // 1. 基本数据类型和变量声明
        std::cout << "\n1. 基本数据类型：" << std::endl;
        
        // 整数类型，32位有符号整数
        int intVar = 42;
        
        // 双精度浮点数，64位
        double doubleVar = 3.14159;
        
        // 字符类型，8位
        char charVar = 'A';
        
        // 布尔类型，只能是true或false
        bool boolVar = true;
        
        // 字符串类，C++标准库提供，比C风格字符串更安全
        std::string stringVar = "Hello C++";
        
        // 输出各种数据类型的值
        std::cout << "整数: " << intVar << std::endl;
        std::cout << "浮点数: " << doubleVar << std::endl;
        std::cout << "字符: " << charVar << std::endl;
        // 三元运算符演示：condition ? value_if_true : value_if_false
        std::cout << "布尔值: " << (boolVar ? "true" : "false") << std::endl;
        std::cout << "字符串: " << stringVar << std::endl;
        
        // 2. 数组和指针操作
        std::cout << "\n2. 数组和指针：" << std::endl;
        
        // C风格数组：在栈上分配，大小在编译时确定
        // {} 是列表初始化语法，C++11引入
        int arr[5] = {1, 2, 3, 4, 5};
        
        // 指针：存储变量地址的变量
        // 数组名本身就是指向第一个元素的指针
        int* ptr = arr;
        
        std::cout << "数组元素: ";
        // 使用指针算术遍历数组
        for (int i = 0; i < 5; i++) {
            // *(ptr + i) 等价于 ptr[i] 或 arr[i]
            // 指针算术：ptr + i 指向第i个元素
            std::cout << *(ptr + i) << " ";
        }
        std::cout << std::endl;
        
        // 3. 引用 - C++特有的特性，相当于变量的别名
        std::cout << "\n3. 引用：" << std::endl;
        
        // int& 声明一个整数引用，必须在声明时初始化
        // 引用一旦绑定就不能改变绑定的对象
        int& ref = intVar;
        
        // 通过引用修改原变量的值
        ref = 100;
        std::cout << "通过引用修改后的值: " << intVar << std::endl;
        
        // 4. 控制流语句 - 程序执行流程控制
        std::cout << "\n4. 控制流：" << std::endl;
        
        // if-else 条件语句：根据条件执行不同代码块
        if (intVar > 50) {
            std::cout << "intVar 大于 50" << std::endl;
        } else {
            std::cout << "intVar 小于等于 50" << std::endl;
        }
        
        // switch-case 多分支选择语句：根据值选择执行路径
        Color color = Color::RED;   // 使用枚举类，需要加作用域
        switch (color) {
            case Color::RED:        // 每个case后面要有break，否则会继续执行下一个case
                std::cout << "颜色是红色" << std::endl;
                break;
            case Color::GREEN:
                std::cout << "颜色是绿色" << std::endl;
                break;
            case Color::BLUE:
                std::cout << "颜色是蓝色" << std::endl;
                break;
            // 可以添加default分支处理其他情况
        }
        
        // for循环：适用于已知循环次数的情况
        std::cout << "for循环: ";
        for (int i = 1; i <= 5; i++) {  // 初始化; 条件; 递增
            std::cout << i << " ";
        }
        std::cout << std::endl;
        
        // while循环：适用于未知循环次数，基于条件的循环
        std::cout << "while循环: ";
        int count = 0;
        while (count < 3) {     // 先检查条件，再执行循环体
            std::cout << count << " ";
            count++;            // 递增，防止无限循环
        }
        std::cout << std::endl;
        
        // 5. STL容器和算法 - 标准模板库，C++的核心优势
        std::cout << "\n5. STL容器：" << std::endl;
        
        // vector：动态数组，可以自动扩展大小
        // {} 初始化列表，C++11特性
        std::vector<int> vec = {10, 20, 30, 40, 50};
        
        std::cout << "vector内容: ";
        // 范围for循环 (C++11)：自动遍历容器中的每个元素
        // const auto& 自动推导类型，const防止修改，&避免复制
        for (const auto& item : vec) {
            std::cout << item << " ";
        }
        std::cout << std::endl;
        
        // map：关联容器，存储键值对，按键自动排序
        std::map<std::string, int> scoreMap;
        
        // 使用[]操作符插入或访问元素
        scoreMap["Alice"] = 95;
        scoreMap["Bob"] = 87;
        scoreMap["Charlie"] = 92;
        
        std::cout << "map内容: " << std::endl;
        // 遍历map，每个元素是一个pair<key, value>
        for (const auto& pair : scoreMap) {
            // pair.first是键，pair.second是值
            std::cout << pair.first << ": " << pair.second << std::endl;
        }
        
        // 6. 面向对象编程 - C++的核心特性：封装、继承、多态
        std::cout << "\n6. 面向对象编程：" << std::endl;
        
        // 多态性演示：通过基类指针调用派生类的方法
        // std::unique_ptr：智能指针，自动管理内存，离开作用域时自动删除对象
        std::vector<std::unique_ptr<Animal>> animals;
        
        // std::make_unique：安全创建unique_ptr的推荐方法 (C++14)
        // 这里创建Dog对象，但存储为Animal指针
        animals.push_back(std::make_unique<Dog>("旺财", 3, "金毛"));
        animals.push_back(std::make_unique<Cat>("咪咪", 2));
        
        // 多态性的体现：同样的代码，调用不同派生类的方法
        for (const auto& animal : animals) {
            // -> 是指针访问成员的操作符，等价于 (*animal).introduce()
            animal->introduce();    // 可能调用Dog::introduce()或Animal::introduce()
            animal->makeSound();    // 调用Dog::makeSound()或Cat::makeSound()
            std::cout << std::endl;
        }
        
        // 友元函数演示：访问类的私有成员
        Dog myDog("小黑", 4, "拉布拉多");
        playWithDog(myDog);     // 友元函数可以访问Dog的私有成员
        
        // 7. 模板编程 - 泛型编程，代码重用的强大工具
        std::cout << "\n7. 模板：" << std::endl;
        
        // 函数模板的使用：同一个函数处理不同类型
        // 编译器会根据参数类型自动推导模板参数
        std::cout << "整数最大值: " << getMax(10, 20) << std::endl;        // T = int
        std::cout << "浮点数最大值: " << getMax(3.14, 2.71) << std::endl;  // T = double
        
        // 类模板的使用：创建特定类型的容器
        Container<std::string> stringContainer;  // 明确指定模板参数为std::string
        stringContainer.add("Hello");
        stringContainer.add("World");
        stringContainer.add("C++");
        
        std::cout << "字符串容器内容: ";
        // 使用我们自定义容器的迭代器接口
        for (const auto& str : stringContainer) {
            std::cout << str << " ";
        }
        std::cout << std::endl;
        
        // 8. 运算符重载 - 让自定义类型支持内置运算符
        std::cout << "\n8. 运算符重载：" << std::endl;
        
        // 创建Point对象，使用带参数的构造函数
        Point p1(3.0, 4.0);
        Point p2(1.0, 2.0);
        
        // 使用重载的+运算符，就像内置类型一样自然
        Point p3 = p1 + p2;    // 调用 Point::operator+
        
        std::cout << "点相加结果: (" << p3.x << ", " << p3.y << ")" << std::endl;
        
        // 9. 函数对象(仿函数) - 可以保存状态的"函数"
        std::cout << "\n9. 函数对象：" << std::endl;
        
        // 创建一个乘以3的函数对象
        Multiplier mult(3);
        
        // 像调用函数一样使用对象
        std::cout << "使用函数对象: " << mult(5) << std::endl;  // 调用operator()
        
        // 10. Lambda表达式 - C++11引入的匿名函数，非常便利
        std::cout << "\n10. Lambda表达式：" << std::endl;
        
        // Lambda语法：[捕获列表](参数列表) { 函数体 }
        // auto 让编译器自动推导lambda的复杂类型
        auto lambda = [](int x, int y) { return x + y; };
        std::cout << "Lambda结果: " << lambda(10, 20) << std::endl;
        
        // Lambda与STL算法结合使用的强大示例
        std::vector<int> numbers = {5, 2, 8, 1, 9};
        
        // std::sort + lambda：自定义排序规则
        // [](int a, int b) { return a > b; } 定义降序比较函数
        std::sort(numbers.begin(), numbers.end(), [](int a, int b) {
            return a > b;  // 返回true表示a应该排在b前面（降序）
        });
        
        std::cout << "排序后的数字: ";
        for (int num : numbers) {
            std::cout << num << " ";
        }
        std::cout << std::endl;
        
        // 11. 智能指针 - 现代C++内存管理的核心，避免内存泄漏
        std::cout << "\n11. 智能指针：" << std::endl;
        
        // unique_ptr：独占所有权的智能指针，不能复制，只能移动
        // std::make_unique 是创建unique_ptr的推荐方式，更安全
        std::unique_ptr<int> uniquePtr = std::make_unique<int>(42);
        
        // shared_ptr：共享所有权的智能指针，可以复制，引用计数管理
        std::shared_ptr<int> sharedPtr = std::make_shared<int>(100);
        
        // * 运算符解引用，获取指针指向的值
        std::cout << "unique_ptr值: " << *uniquePtr << std::endl;
        std::cout << "shared_ptr值: " << *sharedPtr << std::endl;
        
        // use_count() 返回当前有多少个shared_ptr指向同一对象
        std::cout << "shared_ptr引用计数: " << sharedPtr.use_count() << std::endl;
        
        // 智能指针在离开作用域时自动删除对象，无需手动delete
        
        // 12. 异常处理 - 现代错误处理机制，比返回错误码更优雅
        std::cout << "\n12. 异常处理：" << std::endl;
        
        try {
            // 条件检查，演示抛出自定义异常
            if (intVar < 0) {
                // throw 关键字抛出异常对象
                throw CustomException("值不能为负数");
            }
            
            // 使用我们的自定义容器，演示标准异常
            Container<int> intContainer;
            intContainer.add(1);
            intContainer.add(2);
            
            // 故意访问不存在的索引，触发异常
            std::cout << intContainer.get(10) << std::endl;  // 这行会抛出异常
            
        } catch (const CustomException& e) {
            // 捕获我们自定义的异常类型
            // const& 避免复制异常对象
            std::cout << "自定义异常: " << e.what() << std::endl;
        } catch (const std::out_of_range& e) {
            // 捕获标准库的out_of_range异常
            std::cout << "标准异常: " << e.what() << std::endl;
        }
        // 还可以有 catch(...) 捕获所有类型的异常
        
        // 13. 文件I/O操作 - 与外部世界交互的重要方式
        std::cout << "\n13. 文件操作：" << std::endl;
        
        // ofstream：输出文件流，用于写文件
        std::ofstream outFile("example.txt");
        
        // is_open() 检查文件是否成功打开
        if (outFile.is_open()) {
            // << 操作符向文件写入数据，就像向std::cout输出一样
            outFile << "这是一个C++示例文件\n";
            outFile << "展示文件写入操作\n";
            
            // close() 关闭文件，释放资源
            // 实际上析构函数会自动关闭，但显式关闭是好习惯
            outFile.close();
            std::cout << "文件写入成功" << std::endl;
        }
        
        // ifstream：输入文件流，用于读文件
        std::ifstream inFile("example.txt");
        if (inFile.is_open()) {
            std::string line;   // 存储读取的每一行
            std::cout << "文件内容:" << std::endl;
            
            // getline() 逐行读取文件内容
            while (std::getline(inFile, line)) {
                std::cout << line << std::endl;
            }
            inFile.close();
        }
        
        // 14. 常量和命名空间 - 代码组织和安全性
        std::cout << "\n14. 常量和命名空间：" << std::endl;
        
        // const 关键字声明常量，编译时检查，不能修改
        const int LOCAL_CONSTANT = 50;
        std::cout << "局部常量: " << LOCAL_CONSTANT << std::endl;
        
        // 使用命名空间中的常量，需要加上作用域解析运算符 ::
        std::cout << "命名空间常量: " << MyNamespace::GLOBAL_CONSTANT << std::endl;
        
    } catch (const std::exception& e) {
        // 捕获所有标准异常的基类，确保程序不会因未处理异常而崩溃
        // std::cerr 是标准错误输出流，通常用于输出错误信息
        std::cerr << "程序异常: " << e.what() << std::endl;
        return 1;   // 返回非零值表示程序执行失败
    }
    
    std::cout << "\n=== 程序执行完成 ===" << std::endl;
    return 0;   // 返回0表示程序正常结束
}

/*
 * 总结：这个程序展示了C++的主要特性
 * 
 * 1. 基础语法：变量、数据类型、数组、指针、引用
 * 2. 控制流：if-else、switch、for、while循环
 * 3. 面向对象：类、继承、多态、封装、友元
 * 4. 模板：函数模板、类模板，实现泛型编程
 * 5. STL：容器、算法、迭代器
 * 6. 现代C++：智能指针、Lambda、auto、范围for
 * 7. 异常处理：try-catch、自定义异常
 * 8. 文件I/O：读写文件操作
 * 9. 高级特性：运算符重载、函数对象、枚举类
 * 10. 代码组织：命名空间、常量
 * 
 * 编译建议：
 * g++ -std=c++14 -Wall -Wextra -o program main.cpp
 * 
 * -std=c++14: 使用C++14标准
 * -Wall -Wextra: 启用更多警告，帮助发现潜在问题
 * -o program: 指定输出文件名
 */