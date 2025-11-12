#include "gmock/gmock.h"
#include "gtest/gtest.h"

#include "src/Example.h"
#include "src/ExampleMock.h"

using ::testing::_;
using ::testing::Exactly;

TEST(SmokeTest, BasicMockTest) {
  ExampleComponentMock mock;
  EXPECT_CALL(mock, client_process()).Times(Exactly(1));

  mock.client_process();
}

int main(int argc, char **argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
