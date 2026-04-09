#include "gtest/gtest.h"

// IPublicApi.h is public because it was selected via path suffix "src/IPublicApi.h"
#include "test/cpp_path_hdrs/src/IPublicApi.h"

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
