#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

bool contains(const std::string &content, const std::string &pattern) {
  return content.find(pattern) != std::string::npos;
}

int main(int argc, char *argv[]) {
  if (argc != 2) {
    std::cerr << "Usage: " << argv[0] << " <csharp_file>" << std::endl;
    return 1;
  }

  std::ifstream file(argv[1]);
  if (!file.is_open()) {
    std::cerr << "Error: Could not open file " << argv[1] << std::endl;
    return 1;
  }

  std::stringstream buffer;
  buffer << file.rdbuf();
  const auto &content = buffer.str();

  // Simple checks for expected C# patterns
  if (!contains(content, "class Example")) {
    std::cerr << "Error: Generated C# file missing 'class Example' declaration"
              << std::endl;
    return 1;
  }
  if (!contains(content, "public static string greet()")) {
    std::cerr << "Error: Generated C# file missing 'public static string "
                 "greet()' method"
              << std::endl;
    return 1;
  }
  if (!contains(content, "return")) {
    std::cerr << "Error: Generated C# file missing 'return' statement"
              << std::endl;
    return 1;
  }
  if (content.find('{') == std::string::npos ||
      content.find('}') == std::string::npos) {
    std::cerr << "Error: Generated C# file missing braces" << std::endl;
    return 1;
  }

  std::cout << "✓ Generated C# file looks good" << std::endl;
  return 0;
}
