#include "gtest/gtest.h"

// Include the generated header directly — this works because generated
// headers are in hdrs (public) of the coco_cc_library.
#include "test/cpp_mixed_library/src/ISensor.h"

// Include the hand-written header — also public via hdrs of the library.
#include "test/cpp_mixed_library/handwritten/sensor_wrapper.h"

TEST(CppMixedLibraryTest, GeneratedEnumIsAccessible) {
    SensorState state = SensorState::IDLE;
    EXPECT_EQ(state, SensorState::IDLE);

    state = SensorState::ACTIVE;
    EXPECT_EQ(state, SensorState::ACTIVE);
}

TEST(CppMixedLibraryTest, HandwrittenWrapperWorks) {
    SensorWrapper wrapper;
    EXPECT_EQ(wrapper.getState(), SensorState::IDLE);

    wrapper.activate();
    EXPECT_EQ(wrapper.getState(), SensorState::ACTIVE);

    wrapper.reset();
    EXPECT_EQ(wrapper.getState(), SensorState::IDLE);
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
