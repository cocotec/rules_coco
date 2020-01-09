#include "gtest/gtest.h"

#include "coco/stream_logger.h"
#include "test/simple/src/PBase.h"
#include "test/simple/src/PBaseMock.h"

using ::testing::_;
using ::testing::AtLeast;
using ::testing::DoAll;
using ::testing::Exactly;
using ::testing::Return;
using ::testing::WithArg;

TEST(MockTest, Main) {
  PBaseProvidedMock mock;
  EXPECT_CALL(mock, start()).Times(Exactly(1));
  EXPECT_CALL(mock, stop()).Times(Exactly(1));

  mock.start();
  mock.stop();
}

int main(int argc, char **argv) { return RUN_ALL_TESTS(); }
