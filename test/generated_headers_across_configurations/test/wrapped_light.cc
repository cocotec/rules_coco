#include "test/generated_headers_across_configurations/Light.h"

#ifndef WRAPPED_CC_LIBRARY
#error "the library was not compiled through wrapped_cc_library"
#endif

int main() {
  Brightness brightness = Brightness::DIM;
  return brightness == Brightness::DIM ? 0 : 1;
}
