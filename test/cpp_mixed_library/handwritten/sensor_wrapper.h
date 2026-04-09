#ifndef SENSOR_WRAPPER_H
#define SENSOR_WRAPPER_H

#include "test/cpp_mixed_library/src/ISensor.h"

// Hand-written wrapper around the Coco-generated ISensor types.
// Demonstrates that hand-written code can include generated headers
// when they are in the same cc_library.

class SensorWrapper {
public:
    SensorWrapper() : state_(SensorState::IDLE) {}

    SensorState getState() const { return state_; }
    void activate() { state_ = SensorState::ACTIVE; }
    void reset() { state_ = SensorState::IDLE; }

private:
    SensorState state_;
};

#endif  // SENSOR_WRAPPER_H
