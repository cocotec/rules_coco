#include "gtest/gtest.h"

// This should work because app_cpp regenerates base with .hpp extension
// Regenerated files are placed in the app package's output directory
#include "test/regenerate_packages/app/sources/IBase.hpp"
#include "test/regenerate_packages/app/sources/geometry/Dims.hpp"
#include "test/regenerate_packages/app/sources/IApp.hpp"

TEST(RegeneratePackagesTest, CppWithCustomHeaderExtension) {
  // Test that we can use types from the regenerated base package
  Color color = Color::RED;
  EXPECT_EQ(color, Color::RED);

  Point point(10, 20, Color::BLUE);
  EXPECT_EQ(point.x, 10);
  EXPECT_EQ(point.y, 20);
  EXPECT_EQ(point.color, Color::BLUE);

  // Test nested subdirectory from regenerated base package
  Dims dim(100, 50);
  EXPECT_EQ(dim.width, 100);
  EXPECT_EQ(dim.height, 50);

  // Test that app types work with regenerated base types including subdirectory
  Rectangle rect(point, Point(30, 40, Color::GREEN), dim);
  EXPECT_EQ(rect.topLeft.x, 10);
  EXPECT_EQ(rect.bottomRight.y, 40);
  EXPECT_EQ(rect.size.width, 100);
  EXPECT_EQ(rect.size.height, 50);
}
