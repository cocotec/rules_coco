#include "gtest/gtest.h"

#include "test/workspace_basic/app/src/IApp.h"
#include "test/workspace_basic/middle/src/IMiddle.h"
#include "test/workspace_basic/base/src/IBase.h"

TEST(WorkspaceBasicTest, TestEnumFromBasePackage) {
  Status status = Status::OK;
  EXPECT_EQ(status, Status::OK);

  status = Status::ERROR;
  EXPECT_EQ(status, Status::ERROR);
}

TEST(WorkspaceBasicTest, TestConfigStructFromBasePackage) {
  Config config(100, Status::OK);

  EXPECT_EQ(config.timeout, 100);
  EXPECT_EQ(config.status, Status::OK);
}

TEST(WorkspaceBasicTest, TestPriorityEnumFromMiddlePackage) {
  Priority priority = Priority::MEDIUM;
  EXPECT_EQ(priority, Priority::MEDIUM);
}

TEST(WorkspaceBasicTest, TestTaskStructFromMiddlePackage) {
  Config config(200, Status::ERROR);
  Task task(config, Priority::HIGH);

  EXPECT_EQ(task.config.timeout, 200);
  EXPECT_EQ(task.config.status, Status::ERROR);
  EXPECT_EQ(task.priority, Priority::HIGH);
}

TEST(WorkspaceBasicTest, TestThreeLevelDependencyChain) {
  Config baseConfig(150, Status::OK);
  Task middleTask(baseConfig, Priority::MEDIUM);

  EXPECT_EQ(middleTask.config.timeout, 150);
  EXPECT_EQ(middleTask.config.status, Status::OK);
  EXPECT_EQ(middleTask.priority, Priority::MEDIUM);
}

int main(int argc, char **argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
