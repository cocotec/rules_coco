#include "gtest/gtest.h"

#include "test/workspace_cross/app/src/IApp.h"
#include "test/workspace_cross/lib/src/ILib.h"

TEST(WorkspaceCrossTest, ConfigFromLibWorkspace) {
  Config config(100, Status::OK);

  EXPECT_EQ(config.timeout, 100);
  EXPECT_EQ(config.status, Status::OK);
}

TEST(WorkspaceCrossTest, AppDataReferencesLibType) {
  Config config(50, Status::ERROR);
  AppData data(config, 7);

  EXPECT_EQ(data.config.timeout, 50);
  EXPECT_EQ(data.config.status, Status::ERROR);
  EXPECT_EQ(data.count, 7);
}

int main(int argc, char **argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
