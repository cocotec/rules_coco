// Reaches boost_stub.h only through the runtime's deps; see BUILD.bazel.
#include "stub/boost_stub.h"

#include "gtest/gtest.h"

TEST(CcRuntimeExtraDepsTest, StubHeaderIsVisibleThroughRuntime) {
  EXPECT_EQ(coco::test::BoostStubMarker(), 42);
}

int main(int argc, char **argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
