#define _USE_MATH_DEFINES
#include <cmath>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <filesystem>
#include <random>
#include <algorithm>
#include <unordered_map>
#include <stdexcept>
#include <nlohmann/json.hpp>
#include <omp.h>

namespace fs = std::filesystem;
using json = nlohmann::json;

// 环境响应结构体
struct EnvResponse {
    std::vector<double> Amp;
    std::vector<double> Delay;
    std::vector<double> phase;
    double freq;
};

// 信号记录结构体
struct AnalyRecord {
    std::vector<double> Amp;
    std::vector<double> freq;
    std::vector<double> phase;
};

struct SignalData {
    double fs;
    std::vector<double> Ndelay;
    std::vector<AnalyRecord> Analyrecord;
    std::vector<double> Analy_freq;
};

// JSON 辅助解析
static std::vector<double> parseDoubleVector(const json& j) {
    if (j.is_null()) return {};
    if (j.is_array()) return j.get<std::vector<double>>();
    if (j.is_number()) return { j.get<double>() };
    if (j.is_string()) return { std::stod(j.get<std::string>()) };
    throw std::runtime_error("Unsupported JSON field type");
}

// 加载环境响应 JSON
static std::vector<std::vector<EnvResponse>> loadEnvResponses(const std::string& path) {
    std::ifstream in(path);
    if (!in) throw std::runtime_error("Cannot open ENV JSON: " + path);
    json j; in >> j;
    std::vector<std::vector<EnvResponse>> data;
    for (auto& row : j) {
        std::vector<EnvResponse> vec;
        for (auto& elem : row) {
            EnvResponse e;
            e.Amp = parseDoubleVector(elem.at("Amp"));
            e.Delay = parseDoubleVector(elem.at("Delay"));
            e.phase = parseDoubleVector(elem.at("phase"));
            e.freq = elem.at("freq").get<double>();
            vec.push_back(std::move(e));
        }
        data.push_back(std::move(vec));
    }
    return data;
}

// 加载信号 JSON
static SignalData loadSignalData(const std::string& path) {
    std::ifstream in(path);
    if (!in) throw std::runtime_error("Cannot open Signal JSON: " + path);
    json j; in >> j;
    SignalData d;
    d.fs = j.at("fs").get<double>();
    d.Ndelay = parseDoubleVector(j.at("Ndelay"));
    d.Analy_freq = parseDoubleVector(j.at("Analy_freq"));
    for (auto& it : j.at("Analyrecord")) {
        AnalyRecord rec;
        rec.Amp = parseDoubleVector(it.at("Amp"));
        rec.freq = parseDoubleVector(it.at("freq"));
        rec.phase = parseDoubleVector(it.at("phase"));
        d.Analyrecord.push_back(std::move(rec));
    }
    return d;
}

// 生成多径信号：基于预计算时间 base_t，返回实部与长度
static std::pair<std::vector<double>, int>
tdsiggenerate(double freq,
    double fs,
    const std::vector<double>& base_t,
    double amp0,
    double phase0,
    const std::vector<double>& delay,
    const std::vector<double>& envAmp,
    const std::vector<double>& envPhase) {
    int N = static_cast<int>(base_t.size());
    std::vector<double> y(N, 0.0);
    double minD = delay.empty() ? 0.0 : *std::min_element(delay.begin(), delay.end());
    // 预计算偏移
    std::vector<int> offs(delay.size());
    for (size_t i = 0; i < delay.size(); ++i) {
        offs[i] = static_cast<int>(std::floor((delay[i] - minD) * fs));
    }
    // 多径叠加
#pragma omp parallel for
    for (size_t p = 0; p < envAmp.size(); ++p) {
        double a = amp0 * envAmp[p];
        double ph = phase0 + envPhase[p];
        for (int i = 0; i < N; ++i) {
            int idx = offs[p] + i;
            if (idx >= 0 && idx < N)
#pragma omp atomic
                y[idx] += a * std::cos(2 * M_PI * freq * base_t[i] + ph);
        }
    }
    return { y, N };
}

// 新信号生成，结合多个分段
static std::pair<std::vector<double>, std::vector<double>>
generateNewSignal(const SignalData& sd,
    const std::vector<EnvResponse>& envResp,
    double Amp_source) {
    // 1. 时延范围
    double maxD = -1e300, minD = 1e300;
    for (auto& e : envResp) {
        if (!e.Delay.empty()) {
            maxD = std::max(maxD, *std::max_element(e.Delay.begin(), e.Delay.end()));
            minD = std::min(minD, *std::min_element(e.Delay.begin(), e.Delay.end()));
        }
    }
    // 2. 随机选取连续段
    int R = static_cast<int>(sd.Analyrecord.size());
    int Nsel = std::min(16, R);
    std::mt19937 gen{ std::random_device{}() };
    std::uniform_int_distribution<> dist(0, R - Nsel);
    int start = dist(gen);
    std::vector<int> segs(Nsel);
    for (int i = 0; i < Nsel; ++i) segs[i] = start + i;
    // 3. 输出时序
    int L = static_cast<int>(std::ceil((maxD - minD + Nsel + 0.01) * sd.fs));
    std::vector<double> tgsig(L, 0.0), tgt(L);
    for (int i = 0; i < L; ++i) tgt[i] = i / sd.fs;
    // 4. 预计算 base_t
    double segDur = (sd.Ndelay.size() >= 2 ? (sd.Ndelay[1] - sd.Ndelay[0]) : 0.0);
    int M = static_cast<int>(std::round(segDur * sd.fs));
    std::vector<double> base_t(M);
    for (int i = 0; i < M; ++i) base_t[i] = i / sd.fs;
    // 5. 并行叠加
#pragma omp parallel for
    for (int si = 0; si < Nsel; ++si) {
        int p = segs[si];
        auto& rec = sd.Analyrecord[p];
        std::vector<double> local(L, 0.0);
        for (size_t c = 0; c < rec.freq.size(); ++c) {
            double freq = rec.freq[c];
            double amp0 = Amp_source * rec.Amp[c];
            double ph0 = rec.phase[c];
            for (auto& e : envResp) {
                if (std::abs(e.freq - freq) > 1e-6) continue;
                auto [y, len] = tdsiggenerate(freq, sd.fs, base_t, amp0, ph0, e.Delay, e.Amp, e.phase);
                double d0 = *std::min_element(e.Delay.begin(), e.Delay.end());
                int be = static_cast<int>(std::floor((d0 - minD + sd.Ndelay[p]) * sd.fs));
                if (be < 0 || be + len > L) continue;
                for (int i = 0; i < len; ++i) local[be + i] += y[i];
                break;
            }
        }
#pragma omp critical
        for (int i = 0; i < L; ++i) tgsig[i] += local[i];
    }
    return { tgsig, tgt };
}

// WAV 写入
static bool writeWav(const std::string& file, const std::vector<double>& s, int fs) {
    if (s.empty()) return false;
    double mx = 0;
    for (double v : s) mx = std::max(mx, std::abs(v));
    double scale = 32767.0 / (mx < 1e-6 ? 1e-6 : mx);
    std::vector<int16_t> pcm(s.size());
    for (size_t i = 0; i < s.size(); ++i)
        pcm[i] = static_cast<int16_t>(std::clamp(int(std::round(s[i] * scale)), -32768, 32767));
    int byteRate = fs * 1 * 16 / 8;
    int blockAlign = 1 * 16 / 8;
    int dataSize = static_cast<int>(pcm.size() * sizeof(int16_t));
    int chunkSize = 36 + dataSize;
    std::ofstream out(file, std::ios::binary);
    if (!out) return false;
    out.write("RIFF", 4);
    out.write(reinterpret_cast<const char*>(&chunkSize), 4);
    out.write("WAVE", 4);
    out.write("fmt ", 4);
    int sub1 = 16; out.write(reinterpret_cast<const char*>(&sub1), 4);
    short audioF = 1; out.write(reinterpret_cast<const char*>(&audioF), 2);
    short ch = 1; out.write(reinterpret_cast<const char*>(&ch), 2);
    out.write(reinterpret_cast<const char*>(&fs), 4);
    out.write(reinterpret_cast<const char*>(&byteRate), 4);
    out.write(reinterpret_cast<const char*>(&blockAlign), 2);
    short bits = 16; out.write(reinterpret_cast<const char*>(&bits), 2);
    out.write("data", 4);
    out.write(reinterpret_cast<const char*>(&dataSize), 4);
    out.write(reinterpret_cast<const char*>(pcm.data()), static_cast<std::streamsize>(dataSize));
    return true;
}

int main() {
    std::string ENVall = "G:/database/Enhanced_shipsEar0405";
    std::vector<std::string> ENVcls = { "Shallow", "Transition", "Deep" };
    std::string SigFld = "G:/database/shipsEar/Shipsear_signal_folder0416";
    double Amp_source = 1e5;
    for (auto& cls : ENVcls) {
        fs::path clsPath = fs::path(ENVall) / cls;
        if (!fs::exists(clsPath)) continue;
        for (auto& sf : fs::directory_iterator(clsPath)) if (fs::is_directory(sf)) {
            for (auto& rr : fs::directory_iterator(sf)) if (fs::is_directory(rr)) {
                fs::path outDir = rr.path() / "NewSig";
                fs::create_directories(outDir);
                fs::path envJson = rr.path() / "ENV_ARR_less.json";
                if (!fs::exists(envJson)) continue;
                auto env2D = loadEnvResponses(envJson.string());
                int depths = static_cast<int>(env2D[0].size());
                std::vector<double> Rd = (depths == 3)
                    ? std::vector<double>{10, 20, 30}
                : std::vector<double>{ 25,50,100,300 };
                for (int m = 0; m < depths; ++m) {
                    std::vector<EnvResponse> col;
                    col.reserve(env2D.size());
                    for (auto& r : env2D) col.push_back(r[m]);
                    for (auto& f : fs::directory_iterator(SigFld)) {
                        if (f.path().extension() == ".json" && f.path().stem() != "Analy_freq_all") {
                            auto sd = loadSignalData(f.path().string());
                            auto [sig, tgt] = generateNewSignal(sd, col, Amp_source);
                            std::string outName = f.path().stem().string() + "_Rd_" + std::to_string((int)Rd[m]) + ".wav";
                            writeWav((outDir / outName).string(), sig, static_cast<int>(sd.fs));
                        }
                    }
                }
            }
        }
    }
    return 0;
}
