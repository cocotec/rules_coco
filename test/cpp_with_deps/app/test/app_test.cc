#include "gtest/gtest.h"

#include "test/cpp_with_deps/app/src/IApp.h"
#include "test/cpp_with_deps/middle/src/IMiddle.h"
#include "test/cpp_with_deps/base/src/IBase.h"

TEST(CppWithDepsTest, TestEnumFromBasePackage) {
  // Level 1: Test that we can use the Status enum from the base package
  Status status = Status::OK;
  EXPECT_EQ(status, Status::OK);

  status = Status::ERROR;
  EXPECT_EQ(status, Status::ERROR);

  status = Status::PENDING;
  EXPECT_EQ(status, Status::PENDING);
}

TEST(CppWithDepsTest, TestConfigStructFromBasePackage) {
  // Level 1: Test that we can use the Config struct from the base package
  Config config(100, Status::OK);

  EXPECT_EQ(config.timeout, 100);
  EXPECT_EQ(config.status, Status::OK);
}

TEST(CppWithDepsTest, TestPriorityEnumFromMiddlePackage) {
  // Level 2: Test that we can use the Priority enum from the middle package
  Priority priority = Priority::LOW;
  EXPECT_EQ(priority, Priority::LOW);

  priority = Priority::MEDIUM;
  EXPECT_EQ(priority, Priority::MEDIUM);

  priority = Priority::HIGH;
  EXPECT_EQ(priority, Priority::HIGH);
}

TEST(CppWithDepsTest, TestTaskStructFromMiddlePackage) {
  // Level 2: Test that middle package can use types from base package
  Config config(200, Status::ERROR);
  Task task(config, Priority::HIGH);

  EXPECT_EQ(task.config.timeout, 200);
  EXPECT_EQ(task.config.status, Status::ERROR);
  EXPECT_EQ(task.priority, Priority::HIGH);
}

TEST(CppWithDepsTest, TestThreeLevelDependencyChain) {
  // Level 3: Test that app can access types from middle AND base (transitively)
  // This demonstrates three-level package dependency: app → middle → base

  // Create a Config from base package
  Config baseConfig(150, Status::OK);

  // Create a Task from middle package that uses Config from base
  Task middleTask(baseConfig, Priority::MEDIUM);

  // Verify all types work together across three package levels
  EXPECT_EQ(middleTask.config.timeout, 150);
  EXPECT_EQ(middleTask.config.status, Status::OK);
  EXPECT_EQ(middleTask.priority, Priority::MEDIUM);

  // This test passing demonstrates that C++ codegen works correctly with
  // multi-level Coco package dependencies - types from base package flow
  // through middle package to app package
}

int main(int argc, char **argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
