#include "gmock/gmock.h"
#include "gtest/gtest.h"

#include "coco/gmock_helpers.h"
#include "Example.h"
#include "ExampleMock.h"

using ::testing::_;
using ::testing::Exactly;

TEST(SmokeTest, BasicMockTest) {
  ExampleComponentMock mock;
  EXPECT_CALL(mock, client_process()).Times(Exactly(1));

  mock.client_process();
}

// coco/gmock_helpers.h comes with the C++ runtime, built against the test library's gmock.
TEST(SmokeTest, GMockHelper) {
  coco::SingleThreadedGMockHelper helper;
  bool fired = false;
  helper.execute_async([&fired] { fired = true; });
  helper.coco_drain_queue();
  EXPECT_TRUE(fired);
}

int main(int argc, char **argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
