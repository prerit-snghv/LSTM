#include <iostream>
#include <fstream>
#include <cmath>
#include <iomanip>

int main() {

    // Open the file to write
    std::ofstream mem_file("inv_sqrt.mem");
    
    // Define your epsilon
    float epsilon = 0.00001f;
    float scaling = 256.0f;     // 2^8
    float hw_to_real, inv_sqrt;
    int real_to_hw;

    // Loop through every possible 16-bit address
    for (int i = 0; i < 65536; i++) {

        // Convert 'i' to a real-world float (divide by 256.0f)
        hw_to_real = i/scaling;

        // Calculate the inverse square root
        inv_sqrt = 1.0f/std::sqrt(hw_to_real + epsilon);

        // back to a Q8.8 integer (multiply by 256.0f and round)
        real_to_hw = std::round(inv_sqrt * scaling);

        // clamping
        if(real_to_hw > 32767) real_to_hw = 32767;
        
        // Write to file (C++ hex formatting is weird, so here is the exact line you need)
        mem_file << std::hex << std::setw(4) << std::setfill('0') << real_to_hw << "\n";

    }

    mem_file.close();
    std::cout << "ROM file generated successfully!" << std::endl;
    return 0;

}