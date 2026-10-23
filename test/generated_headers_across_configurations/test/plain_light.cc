#include "test/generated_headers_across_configurations/Light.h"

int main() {
  Brightness brightness = Brightness::DIM;
  return brightness == Brightness::DIM ? 0 : 1;
}
