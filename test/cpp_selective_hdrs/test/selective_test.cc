#include "gtest/gtest.h"

// IPublicApi.h is in hdrs (public) because it was listed in public_hdrs.
#include "test/cpp_selective_hdrs/src/IPublicApi.h"

// InternalComp.h is NOT included here — it's in srcs (private) because it
// was not listed in public_hdrs. Attempting to include it from a downstream
// target would cause a compilation error.

TEST(CppSelectiveHdrsTest, PublicApiEnumIsAccessible) {
    ApiStatus status = ApiStatus::OK;
    EXPECT_EQ(status, ApiStatus::OK);

    status = ApiStatus::FAIL;
    EXPECT_EQ(status, ApiStatus::FAIL);
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
