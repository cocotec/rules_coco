#include "gtest/gtest.h"

#include "test/workspace_nested/inner/pkg/src/IPkg.h"

TEST(WorkspaceNestedTest, PixelStructFromNestedWorkspacePackage) {
  Pixel pixel(Colour::GREEN, 200);

  EXPECT_EQ(pixel.colour, Colour::GREEN);
  EXPECT_EQ(pixel.brightness, 200);
}

TEST(WorkspaceNestedTest, DefaultPixelValues) {
  Pixel pixel(Colour::RED, 128);

  EXPECT_EQ(pixel.colour, Colour::RED);
  EXPECT_EQ(pixel.brightness, 128);
}

int main(int argc, char **argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
