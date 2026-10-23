// Copyright 2026 Cocotec Limited
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <gtest/gtest.h>

#include <string>

// Public headers must be usable on their own.
#include "App.h"
#include "Relay.h"
#include "Switch.h"

TEST(HideImplementation, AppCompilesAndLinks) {
  App app;
  SwitchImpl sw;
  (void)app;
  (void)sw;
}

// Forwarder is a class template, so HideImplementation leaves it whole in the
// public header.
TEST(HideImplementation, GenericIsInstantiableFromPublicHeader) {
  Forwarder<std::string> forwarder;
  (void)forwarder;
}
