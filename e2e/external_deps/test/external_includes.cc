#include "IApp.h"
#include "IBase.h"
#include "IMotor.h"

int main() {
  Status status = Status::OK;
  Direction direction = Direction::FORWARD;
  return status == Status::OK && direction == Direction::FORWARD ? 0 : 1;
}
