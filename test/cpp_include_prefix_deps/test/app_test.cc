#include "gtest/gtest.h"

#include "core/IBase.h"
#include "test/cpp_include_prefix_deps/app/IApp.h"

TEST(CppIncludePrefixDepsTest, AppUsesBaseThroughItsPrefix) {
  Report report(Status::ERROR);
  EXPECT_EQ(report.status, Status::ERROR);
}
