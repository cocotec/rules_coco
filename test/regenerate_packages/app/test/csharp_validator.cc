#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

bool contains(const std::string &content, const std::string &pattern) {
  return content.find(pattern) != std::string::npos;
}

int main(int argc, char *argv[]) {
  if (argc != 2) {
    std::cerr << "Usage: " << argv[0] << " <generated_dir>" << std::endl;
    return 1;
  }

  std::string base_dir = argv[1];

  // Validate IBase.cs (regenerated from base package)
  std::ifstream ibase_file(base_dir + "/IBase.cs");
  if (!ibase_file.is_open()) {
    std::cerr << "Error: Could not open IBase.cs" << std::endl;
    return 1;
  }
  std::stringstream ibase_buffer;
  ibase_buffer << ibase_file.rdbuf();
  const auto &ibase_content = ibase_buffer.str();

  if (!contains(ibase_content, "public enum Color")) {
    std::cerr << "Error: IBase.cs missing Color enum" << std::endl;
    return 1;
  }
  if (!contains(ibase_content, "public record struct Point")) {
    std::cerr << "Error: IBase.cs missing Point struct" << std::endl;
    return 1;
  }
  std::cout << "✓ IBase.cs (regenerated) looks good" << std::endl;

  // Validate geometry/Dims.cs (regenerated from base subdirectory)
  std::ifstream size_file(base_dir + "/geometry/Dims.cs");
  if (!size_file.is_open()) {
    std::cerr << "Error: Could not open geometry/Dims.cs" << std::endl;
    return 1;
  }
  std::stringstream size_buffer;
  size_buffer << size_file.rdbuf();
  const auto &size_content = size_buffer.str();

  if (!contains(size_content, "public record struct Dims")) {
    std::cerr << "Error: Dims.cs missing Dims struct" << std::endl;
    return 1;
  }
  if (!contains(size_content, "public int width")) {
    std::cerr << "Error: Dims.cs missing width field" << std::endl;
    return 1;
  }
  std::cout << "✓ geometry/Dims.cs (regenerated from subdirectory) looks good"
            << std::endl;

  // Validate IApp.cs (from app package)
  std::ifstream iapp_file(base_dir + "/IApp.cs");
  if (!iapp_file.is_open()) {
    std::cerr << "Error: Could not open IApp.cs" << std::endl;
    return 1;
  }
  std::stringstream iapp_buffer;
  iapp_buffer << iapp_file.rdbuf();
  const auto &iapp_content = iapp_buffer.str();

  if (!contains(iapp_content, "public record struct Rectangle")) {
    std::cerr << "Error: IApp.cs missing Rectangle struct" << std::endl;
    return 1;
  }
  if (!contains(iapp_content, "public Point topLeft")) {
    std::cerr << "Error: IApp.cs missing Point usage" << std::endl;
    return 1;
  }
  if (!contains(iapp_content, "public Dims size")) {
    std::cerr << "Error: IApp.cs missing Dims usage" << std::endl;
    return 1;
  }
  std::cout << "✓ IApp.cs looks good" << std::endl;

  std::cout << "✓ All C# regenerate_packages validation passed" << std::endl;
  return 0;
}
