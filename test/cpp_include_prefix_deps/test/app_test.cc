#include "gmock/gmock.h"
#include "gtest/gtest.h"

#include "IApp.h"
#include "core/IBase.h"
#include "core/IBaseMock.h"

using ::testing::Return;

TEST(CppIncludePrefixDepsTest, AppUsesBaseThroughItsPrefix) {
  Report report(Status::ERROR);
  EXPECT_EQ(report.status, Status::ERROR);
}

TEST(CppIncludePrefixDepsTest, MocksLieBelowThePrefixToo) {
  BaseStubMock mock;
  EXPECT_CALL(mock, api_getStatus()).WillOnce(Return(Status::ERROR));
  EXPECT_EQ(mock.api_getStatus(), Status::ERROR);
}
