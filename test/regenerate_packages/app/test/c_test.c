#include <stdio.h>
#include <assert.h>

// This should work because app_c regenerates base with .hh extension
// Regenerated files are placed in the app package's output directory
#include "test/regenerate_packages/app/sources/IBase.hh"
#include "test/regenerate_packages/app/sources/geometry/Dims.hh"
#include "test/regenerate_packages/app/sources/IApp.hh"

int main(void) {
  // Test that we can use types from the regenerated base package
  enum Color color = Color_RED;
  assert(color == Color_RED);

  struct Point point;
  point.x = 15;
  point.y = 25;
  point.color = Color_GREEN;

  assert(point.x == 15);
  assert(point.y == 25);
  assert(point.color == Color_GREEN);

  // Test nested subdirectory from regenerated base package
  struct Dims dim;
  dim.width = 80;
  dim.height = 60;
  assert(dim.width == 80);
  assert(dim.height == 60);

  // Test that app types work with regenerated base types including subdirectory
  struct Rectangle rect;
  rect.topLeft = point;
  rect.bottomRight.x = 50;
  rect.bottomRight.y = 60;
  rect.bottomRight.color = Color_BLUE;
  rect.size = dim;

  assert(rect.topLeft.x == 15);
  assert(rect.bottomRight.y == 60);
  assert(rect.size.width == 80);
  assert(rect.size.height == 60);

  printf("All regenerate_packages C tests passed!\n");
  return 0;
}
