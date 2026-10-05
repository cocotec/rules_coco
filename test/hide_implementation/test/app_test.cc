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

// The public header of a HideImplementation module must be usable on its own.
#include "test/hide_implementation/src/App.h"
#include "test/hide_implementation/src/Switch.h"

// The generic component lives only in the _impl header, so instantiating it
// here proves that file was generated, declared and made available.
#include "test/hide_implementation/src/Relay_impl.h"

TEST(HideImplementation, AppCompilesAndLinks) {
  App app;
  SwitchImpl sw;
  (void)app;
  (void)sw;
}

TEST(HideImplementation, GenericIsInstantiableFromImplHeader) {
  Forwarder<std::string> forwarder;
  (void)forwarder;
}
