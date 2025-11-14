// Simple C test to verify C runtime works without C++ runtime
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include "src/add.h"

int main(void) {
    int32_t result = add(2, 3);
    assert(result == 5);
    printf("Test passed: 2 + 3 = %d\n", result);
    return 0;
}
