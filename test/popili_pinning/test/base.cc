#include "gmock/gmock.h"
#include "gtest/gtest.h"

#include "coco/stream_logger.h"
#include "test/popili_pinning/Runnable.h"
#include "test/popili_pinning/RunnableMock.h"

using ::testing::_;
using ::testing::AtLeast;
using ::testing::DoAll;
using ::testing::Exactly;
using ::testing::Return;
using ::testing::WithArg;

TEST(MockTest, Main) {
  RunnableBaseMock mock;
  EXPECT_CALL(mock, client_begin()).Times(Exactly(1));
  EXPECT_CALL(mock, client_stop()).Times(Exactly(1));

  mock.client_begin();
  mock.client_stop();
}

int main(int argc, char **argv) { return RUN_ALL_TESTS(); }
