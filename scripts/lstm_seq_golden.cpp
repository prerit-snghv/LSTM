#include <cmath>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

constexpr int FRACT_WIDTH = 12;
constexpr int ACC_WIDTH = 48;
constexpr int32_t ONE = 1 << FRACT_WIDTH;
constexpr int32_t THREE = 3 << FRACT_WIDTH;
constexpr int32_t FIVE = 5 << FRACT_WIDTH;
constexpr int32_t INT16_MAX_Q = 0x7fff;
constexpr int32_t INT16_MIN_Q = -0x8000;
constexpr int64_t INT48_MAX_Q = (1LL << (ACC_WIDTH - 1)) - 1;
constexpr int64_t INT48_MIN_Q = -(1LL << (ACC_WIDTH - 1));

struct Weights {
    int16_t w_i;
    int16_t u_i;
    int16_t b_i;
    int16_t w_f;
    int16_t u_f;
    int16_t b_f;
    int16_t w_g;
    int16_t u_g;
    int16_t b_g;
    int16_t w_o;
    int16_t u_o;
    int16_t b_o;
};

struct Inputs {
    std::string name;
    std::vector<int16_t> x;
    int16_t h_init;
    int16_t c_init;
    Weights weights;
};

struct StepOutputs {
    int16_t pre_i;
    int16_t pre_f;
    int16_t pre_g;
    int16_t pre_o;
    int16_t i;
    int16_t f;
    int16_t g;
    int16_t o;
    int16_t c_t;
    int16_t tanh_c_t;
    int16_t h_t;
};

struct IdealStepOutputs {
    double pre_i;
    double pre_f;
    double pre_g;
    double pre_o;
    double i;
    double f;
    double g;
    double o;
    double c_t;
    double tanh_c_t;
    double h_t;
};

int16_t to_i16(int64_t value) {
    return static_cast<int16_t>(value);
}

int16_t sat_i16(int64_t value) {
    if (value > INT16_MAX_Q) {
        return static_cast<int16_t>(INT16_MAX_Q);
    }
    if (value < INT16_MIN_Q) {
        return static_cast<int16_t>(INT16_MIN_Q);
    }
    return to_i16(value);
}

int64_t sat_i48(int64_t value) {
    if (value > INT48_MAX_Q) {
        return INT48_MAX_Q;
    }
    if (value < INT48_MIN_Q) {
        return INT48_MIN_Q;
    }
    return value;
}

double to_real(int16_t value) {
    return static_cast<double>(value) / static_cast<double>(ONE);
}

int16_t real_to_q12(double value) {
    return sat_i16(static_cast<int64_t>(std::llround(value * static_cast<double>(ONE))));
}

int16_t parse_raw_q12(const std::string& text) {
    const long value = std::stol(text);
    if (value < INT16_MIN_Q || value > INT16_MAX_Q) {
        throw std::runtime_error("raw Q4.12 value out of signed 16-bit range: " + text);
    }
    return static_cast<int16_t>(value);
}

int16_t parse_real_q12(const std::string& text) {
    return real_to_q12(std::stod(text));
}

int16_t q12_mul_sat(int16_t a, int16_t b) {
    const int64_t shifted = (static_cast<int64_t>(a) * static_cast<int64_t>(b)) >> FRACT_WIDTH;
    return sat_i16(shifted);
}

int16_t q12_add_sat(int16_t a, int16_t b) {
    return sat_i16(static_cast<int64_t>(a) + static_cast<int64_t>(b));
}

int64_t mac_shifted_product(int16_t a, int16_t b) {
    return (static_cast<int64_t>(a) * static_cast<int64_t>(b)) >> FRACT_WIDTH;
}

int16_t mac_preact(int16_t w, int16_t u, int16_t b, int16_t x_t, int16_t h_prev) {
    int64_t acc = mac_shifted_product(w, x_t);
    acc = sat_i48(acc + mac_shifted_product(u, h_prev));
    acc = sat_i48(acc + mac_shifted_product(b, static_cast<int16_t>(ONE)));
    return sat_i16(acc);
}

int16_t actfn_mul_sat(uint16_t a, int16_t b) {
    const int64_t shifted = (static_cast<int64_t>(a) * static_cast<int64_t>(b)) >> FRACT_WIDTH;
    return sat_i16(shifted);
}

int16_t actfn(bool tanh_mode, int16_t data_in) {
    const bool flag_neg = data_in < 0;
    const uint32_t abs_wide = flag_neg
        ? static_cast<uint32_t>(-static_cast<int32_t>(data_in))
        : static_cast<uint32_t>(data_in);

    uint32_t scaled_abs_wide = tanh_mode ? (abs_wide << 1) : abs_wide;
    if (scaled_abs_wide > 0xffffU) {
        scaled_abs_wide = 0xffffU;
    }

    const uint16_t x_abs = static_cast<uint16_t>(scaled_abs_wide);
    int16_t c0 = 0;
    int16_t c1 = 0;
    int16_t c2 = 0;
    int16_t c3 = 0;
    bool saturated_segment = false;

    if (x_abs < ONE) {
        c0 = 2048;
        c1 = 1024;
        c2 = -4;
        c3 = -76;
    } else if (x_abs < THREE) {
        c0 = 1967;
        c1 = 1261;
        c2 = -247;
        c3 = 14;
    } else if (x_abs < FIVE) {
        c0 = 2188;
        c1 = 1102;
        c2 = -225;
        c3 = 16;
    } else {
        saturated_segment = true;
    }

    int16_t poly_data = static_cast<int16_t>(ONE);
    if (!saturated_segment) {
        const int16_t stage1 = sat_i16(static_cast<int32_t>(actfn_mul_sat(x_abs, c3)) + c2);
        const int16_t stage2 = sat_i16(static_cast<int32_t>(actfn_mul_sat(x_abs, stage1)) + c1);
        poly_data = sat_i16(static_cast<int32_t>(actfn_mul_sat(x_abs, stage2)) + c0);

        if (poly_data > ONE) {
            poly_data = static_cast<int16_t>(ONE);
        } else if (poly_data < 0) {
            poly_data = 0;
        }
    }

    if (!flag_neg) {
        return tanh_mode
            ? to_i16((static_cast<int32_t>(poly_data) << 1) - ONE)
            : poly_data;
    }

    return tanh_mode
        ? to_i16(((ONE - static_cast<int32_t>(poly_data)) << 1) - ONE)
        : to_i16(ONE - static_cast<int32_t>(poly_data));
}

StepOutputs run_step(const Weights& w, int16_t x_t, int16_t h_prev, int16_t c_prev) {
    StepOutputs out{};
    out.pre_i = mac_preact(w.w_i, w.u_i, w.b_i, x_t, h_prev);
    out.pre_f = mac_preact(w.w_f, w.u_f, w.b_f, x_t, h_prev);
    out.pre_g = mac_preact(w.w_g, w.u_g, w.b_g, x_t, h_prev);
    out.pre_o = mac_preact(w.w_o, w.u_o, w.b_o, x_t, h_prev);

    out.i = actfn(false, out.pre_i);
    out.f = actfn(false, out.pre_f);
    out.g = actfn(true, out.pre_g);
    out.o = actfn(false, out.pre_o);

    out.c_t = q12_add_sat(q12_mul_sat(out.f, c_prev), q12_mul_sat(out.i, out.g));
    out.tanh_c_t = actfn(true, out.c_t);
    out.h_t = q12_mul_sat(out.o, out.tanh_c_t);
    return out;
}

double sigmoid(double value) {
    return 1.0 / (1.0 + std::exp(-value));
}

IdealStepOutputs run_ideal_step(const Weights& w, int16_t x_t, double h_prev, double c_prev) {
    const double x_real = to_real(x_t);

    IdealStepOutputs out{};
    out.pre_i = to_real(w.w_i) * x_real + to_real(w.u_i) * h_prev + to_real(w.b_i);
    out.pre_f = to_real(w.w_f) * x_real + to_real(w.u_f) * h_prev + to_real(w.b_f);
    out.pre_g = to_real(w.w_g) * x_real + to_real(w.u_g) * h_prev + to_real(w.b_g);
    out.pre_o = to_real(w.w_o) * x_real + to_real(w.u_o) * h_prev + to_real(w.b_o);

    out.i = sigmoid(out.pre_i);
    out.f = sigmoid(out.pre_f);
    out.g = std::tanh(out.pre_g);
    out.o = sigmoid(out.pre_o);

    out.c_t = out.f * c_prev + out.i * out.g;
    out.tanh_c_t = std::tanh(out.c_t);
    out.h_t = out.o * out.tanh_c_t;
    return out;
}

void print_signal_compare(const std::string& name, int16_t rtl, double ideal) {
    const int16_t ideal_q12 = real_to_q12(ideal);
    const int diff = static_cast<int>(rtl) - static_cast<int>(ideal_q12);

    std::cout << "    " << std::left << std::setw(8) << name
              << " rtl_raw=" << std::right << std::setw(7) << rtl
              << " rtl_real=" << std::setw(11) << std::fixed << std::setprecision(6)
              << to_real(rtl)
              << " ideal=" << std::setw(12) << std::setprecision(6) << ideal
              << " ideal_q12=" << std::setw(7) << ideal_q12
              << " diff=" << std::setw(5) << diff << "\n";
}

void print_case(const Inputs& in) {
    if (in.x.empty()) {
        throw std::runtime_error("sequence must contain at least one x value");
    }

    int16_t h_state = in.h_init;
    int16_t c_state = in.c_init;
    double ideal_h_state = to_real(in.h_init);
    double ideal_c_state = to_real(in.c_init);

    std::cout << "case " << in.name << "\n";
    std::cout << "  steps=" << in.x.size()
              << " h_init_raw=" << in.h_init
              << " c_init_raw=" << in.c_init << "\n";
    std::cout << "  h_init_real=" << std::fixed << std::setprecision(6) << to_real(in.h_init)
              << " c_init_real=" << to_real(in.c_init) << "\n";

    for (std::size_t step = 0; step < in.x.size(); ++step) {
        const StepOutputs out = run_step(in.weights, in.x[step], h_state, c_state);
        const IdealStepOutputs ideal = run_ideal_step(
            in.weights,
            in.x[step],
            ideal_h_state,
            ideal_c_state
        );

        std::cout << "  step " << step
                  << " x_raw=" << in.x[step]
                  << " x_real=" << std::fixed << std::setprecision(6) << to_real(in.x[step])
                  << " h_prev_raw=" << h_state
                  << " c_prev_raw=" << c_state
                  << " ideal_h_prev=" << ideal_h_state
                  << " ideal_c_prev=" << ideal_c_state << "\n";

        print_signal_compare("pre_i", out.pre_i, ideal.pre_i);
        print_signal_compare("pre_f", out.pre_f, ideal.pre_f);
        print_signal_compare("pre_g", out.pre_g, ideal.pre_g);
        print_signal_compare("pre_o", out.pre_o, ideal.pre_o);
        print_signal_compare("i", out.i, ideal.i);
        print_signal_compare("f", out.f, ideal.f);
        print_signal_compare("g", out.g, ideal.g);
        print_signal_compare("o", out.o, ideal.o);
        print_signal_compare("c_t", out.c_t, ideal.c_t);
        print_signal_compare("tanh_c", out.tanh_c_t, ideal.tanh_c_t);
        print_signal_compare("h_t", out.h_t, ideal.h_t);

        h_state = out.h_t;
        c_state = out.c_t;
        ideal_h_state = ideal.h_t;
        ideal_c_state = ideal.c_t;
    }

    std::cout << "  final raw: h_final=" << h_state
              << " c_final=" << c_state << "\n";
    std::cout << "  final real: h_final=" << std::fixed << std::setprecision(6) << to_real(h_state)
              << " c_final=" << to_real(c_state) << "\n";
    std::cout << "  final ideal: h_final=" << std::fixed << std::setprecision(6) << ideal_h_state
              << " c_final=" << ideal_c_state << "\n";
    print_signal_compare("h_final", h_state, ideal_h_state);
    print_signal_compare("c_final", c_state, ideal_c_state);
    std::cout << "\n";
}

Weights nominal_weights() {
    return {
        4096, 0, 0,
        4096, 0, 0,
        2048, 0, 0,
        4096, 0, 0,
    };
}

std::vector<Inputs> default_cases() {
    return {
        {"two_step_nominal_same_x", {4096, 4096}, 2048, 1024, nominal_weights()},
        {"two_step_nominal_diff_x", {4096, 2048}, 2048, 1024, nominal_weights()},
    };
}

void print_help(const char* argv0) {
    std::cout
        << "Usage:\n"
        << "  " << argv0 << "\n"
        << "  " << argv0 << " [--real-inputs] --case NAME --x X0 --x X1 [--x XN ...] \\\n"
        << "      --h H_INIT --c C_INIT \\\n"
        << "      --wi WI --ui UI --bi BI --wf WF --uf UF --bf BF \\\n"
        << "      --wg WG --ug UG --bg BG --wo WO --uo UO --bo BO\n\n"
        << "By default custom values are raw signed Q4.12 integers.\n"
        << "Use --real-inputs to enter real values, for example 1.0 or -0.5.\n\n"
        << "Examples:\n"
        << "  " << argv0 << "\n"
        << "  " << argv0 << " --real-inputs --case two_step --x 1.0 --x 1.0 --h 0.5 --c 0.25 \\\n"
        << "      --wi 1.0 --ui 0 --bi 0 --wf 1.0 --uf 0 --bf 0 \\\n"
        << "      --wg 0.5 --ug 0 --bg 0 --wo 1.0 --uo 0 --bo 0\n";
}

bool is_option(const std::string& arg, const std::string& option) {
    return arg == option;
}

bool is_help_option(const std::string& arg) {
    return is_option(arg, "-h") || is_option(arg, "-help") || is_option(arg, "--help");
}

Inputs parse_custom_case(int argc, char** argv) {
    Inputs in{};
    in.name = "custom_sequence";
    bool real_inputs = false;
    bool seen_h = false;
    bool seen_c = false;
    bool seen_wi = false;
    bool seen_ui = false;
    bool seen_bi = false;
    bool seen_wf = false;
    bool seen_uf = false;
    bool seen_bf = false;
    bool seen_wg = false;
    bool seen_ug = false;
    bool seen_bg = false;
    bool seen_wo = false;
    bool seen_uo = false;
    bool seen_bo = false;

    auto parse_value = [&](const std::string& text) {
        return real_inputs ? parse_real_q12(text) : parse_raw_q12(text);
    };

    for (int index = 1; index < argc; ++index) {
        const std::string arg = argv[index];

        if (is_help_option(arg)) {
            print_help(argv[0]);
            std::exit(0);
        }

        if (is_option(arg, "--real-inputs")) {
            real_inputs = true;
            continue;
        }

        if (index + 1 >= argc) {
            throw std::runtime_error("missing value after option: " + arg);
        }

        const std::string value = argv[++index];
        if (is_option(arg, "--case")) {
            in.name = value;
        } else if (is_option(arg, "--x")) {
            in.x.push_back(parse_value(value));
        } else if (is_option(arg, "--h")) {
            in.h_init = parse_value(value);
            seen_h = true;
        } else if (is_option(arg, "--c")) {
            in.c_init = parse_value(value);
            seen_c = true;
        } else if (is_option(arg, "--wi")) {
            in.weights.w_i = parse_value(value);
            seen_wi = true;
        } else if (is_option(arg, "--ui")) {
            in.weights.u_i = parse_value(value);
            seen_ui = true;
        } else if (is_option(arg, "--bi")) {
            in.weights.b_i = parse_value(value);
            seen_bi = true;
        } else if (is_option(arg, "--wf")) {
            in.weights.w_f = parse_value(value);
            seen_wf = true;
        } else if (is_option(arg, "--uf")) {
            in.weights.u_f = parse_value(value);
            seen_uf = true;
        } else if (is_option(arg, "--bf")) {
            in.weights.b_f = parse_value(value);
            seen_bf = true;
        } else if (is_option(arg, "--wg")) {
            in.weights.w_g = parse_value(value);
            seen_wg = true;
        } else if (is_option(arg, "--ug")) {
            in.weights.u_g = parse_value(value);
            seen_ug = true;
        } else if (is_option(arg, "--bg")) {
            in.weights.b_g = parse_value(value);
            seen_bg = true;
        } else if (is_option(arg, "--wo")) {
            in.weights.w_o = parse_value(value);
            seen_wo = true;
        } else if (is_option(arg, "--uo")) {
            in.weights.u_o = parse_value(value);
            seen_uo = true;
        } else if (is_option(arg, "--bo")) {
            in.weights.b_o = parse_value(value);
            seen_bo = true;
        } else {
            throw std::runtime_error("unknown option: " + arg);
        }
    }

    if (in.x.empty()) {
        throw std::runtime_error("custom sequence needs at least one --x value");
    }

    if (!(seen_h && seen_c &&
          seen_wi && seen_ui && seen_bi &&
          seen_wf && seen_uf && seen_bf &&
          seen_wg && seen_ug && seen_bg &&
          seen_wo && seen_uo && seen_bo)) {
        throw std::runtime_error("custom sequence is missing one or more required inputs; run with --help");
    }

    return in;
}

}  // namespace

int main(int argc, char** argv) {
    try {
        if (argc == 1) {
            for (const Inputs& test_case : default_cases()) {
                print_case(test_case);
            }
            return 0;
        }

        print_case(parse_custom_case(argc, argv));
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "error: " << error.what() << "\n\n";
        print_help(argv[0]);
        return 1;
    }
}
