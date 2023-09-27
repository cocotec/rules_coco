#include "gmock/gmock.h"
#include "gtest/gtest.h"

#include "coco/stream_logger.h"
#include "test/package_directory/Runnable.h"
#include "test/package_directory/RunnableMock.h"

using ::testing::_;
using ::testing::AtLeast;
using ::testing::DoAll;
using ::testing::Exactly;
using ::testing::Return;
using ::testing::WithArg;

TEST(MockTest, Main) {
  RunnableBaseMock mock;
  EXPECT_CALL(mock, client_start()).Times(Exactly(1));
  EXPECT_CALL(mock, client_stop()).Times(Exactly(1));

  mock.client_start();
  mock.client_stop();
}

int main(int argc, char **argv) { return RUN_ALL_TESTS(); }
