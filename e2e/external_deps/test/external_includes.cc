#include "IApp.h"
#include "IBase.h"
#include "motor/IMotor.h"
// Through the `includes` of @coco_dep//motor:motor_cc.
#include "IMotor.h"

int main() {
  Status status = Status::OK;
  Direction direction = Direction::FORWARD;
  return status == Status::OK && direction == Direction::FORWARD ? 0 : 1;
}
