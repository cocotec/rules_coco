#include "gtest/gtest.h"

// Both headers come from a single coco_cc_library that merges two packages.
#include "test/cpp_merged_library/sensors/src/ISensor.h"
#include "test/cpp_merged_library/actuators/src/IActuator.h"

TEST(CppMergedLibraryTest, SensorTypeFromSensorsPackage) {
    SensorType type = SensorType::TEMPERATURE;
    EXPECT_EQ(type, SensorType::TEMPERATURE);

    type = SensorType::PRESSURE;
    EXPECT_EQ(type, SensorType::PRESSURE);
}

TEST(CppMergedLibraryTest, ActuatorStateFromActuatorsPackage) {
    ActuatorState state = ActuatorState::OFF;
    EXPECT_EQ(state, ActuatorState::OFF);

    state = ActuatorState::ON;
    EXPECT_EQ(state, ActuatorState::ON);
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
