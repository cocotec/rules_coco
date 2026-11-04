#include "gtest/gtest.h"

// IPublicApi.h is public because it was selected via the path suffix "api/IPublicApi.h"
#include "api/IPublicApi.h"

TEST(CppPathHdrsTest, PublicApiSelectedByPathSuffix) {
    PathApiStatus status = PathApiStatus::OK;
    EXPECT_EQ(status, PathApiStatus::OK);

    status = PathApiStatus::FAIL;
    EXPECT_EQ(status, PathApiStatus::FAIL);
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
