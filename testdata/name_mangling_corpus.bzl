# Copyright 2025 Cocotec Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Name mangling conformance corpus, shared with popili.

THIS IS A CONTRACT BETWEEN rules_coco AND popili. Both repositories load this
same file and assert against it, which is what stops the two implementations of
the file name mangler drifting apart. Never change an expected value to make one
side's tests pass: if they disagree, one of them has a bug.

Edit this file by hand. See README.md for the mangling rules, the update
procedure, and what is deliberately excluded.

    MANGLE_CASES         (input, style) -> expected, for popili's name mangler
    PATH_CASES           a module path plus generator options -> the generated
                         file paths. A case lists only the fields that differ
                         from PATH_CASE_DEFAULTS.
"""

CORPUS_STYLES = [
    "CapsUpperUnderscore",
    "LowerCamelCase",
    "LowerCamelCasePrefixUnderscore",
    "LowerUnderscore",
    "Unaltered",
    "UnalteredButValid",
    "UpperCamelCase",
    "UpperUnderscore",
]

STYLES_RULES_COCO_UNSUPPORTED = [
    "LowerCamelCasePrefixUnderscore",
    "UnalteredButValid",
]

PATH_CASE_DEFAULTS = {
    "flat_hierarchy": False,
    "header_extension": ".h",
    "header_prefix": "",
    "impl_extension": ".cc",
    "impl_prefix": "",
    "mocks": False,
}

# Cases read inputs first, then the expectation. Sorting the keys
# alphabetically would put "expected" before "input", which reads backwards for
# a table of test data.
# buildifier: disable=unsorted-dict-items
MANGLE_CASES = [
    {
        "input": "2Fast",
        "style": "CapsUpperUnderscore",
        "expected": "i2FAST",
    },
    {
        "input": "2Fast",
        "style": "LowerCamelCase",
        "expected": "i2fast",
    },
    {
        "input": "2Fast",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_2fast",
    },
    {
        "input": "2Fast",
        "style": "LowerUnderscore",
        "expected": "i2fast",
    },
    {
        "input": "2Fast",
        "style": "Unaltered",
        "expected": "i2Fast",
    },
    {
        "input": "2Fast",
        "style": "UnalteredButValid",
        "expected": "i2Fast",
    },
    {
        "input": "2Fast",
        "style": "UpperCamelCase",
        "expected": "I2fast",
    },
    {
        "input": "2Fast",
        "style": "UpperUnderscore",
        "expected": "I2fast",
    },
    {
        "input": "A",
        "style": "CapsUpperUnderscore",
        "expected": "A",
    },
    {
        "input": "A",
        "style": "LowerCamelCase",
        "expected": "a",
    },
    {
        "input": "A",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_a",
    },
    {
        "input": "A",
        "style": "LowerUnderscore",
        "expected": "a",
    },
    {
        "input": "A",
        "style": "Unaltered",
        "expected": "A",
    },
    {
        "input": "A",
        "style": "UnalteredButValid",
        "expected": "A",
    },
    {
        "input": "A",
        "style": "UpperCamelCase",
        "expected": "A",
    },
    {
        "input": "A",
        "style": "UpperUnderscore",
        "expected": "A",
    },
    {
        "input": "ABC",
        "style": "CapsUpperUnderscore",
        "expected": "ABC",
    },
    {
        "input": "ABC",
        "style": "LowerCamelCase",
        "expected": "abc",
    },
    {
        "input": "ABC",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_abc",
    },
    {
        "input": "ABC",
        "style": "LowerUnderscore",
        "expected": "abc",
    },
    {
        "input": "ABC",
        "style": "Unaltered",
        "expected": "ABC",
    },
    {
        "input": "ABC",
        "style": "UnalteredButValid",
        "expected": "ABC",
    },
    {
        "input": "ABC",
        "style": "UpperCamelCase",
        "expected": "Abc",
    },
    {
        "input": "ABC",
        "style": "UpperUnderscore",
        "expected": "Abc",
    },
    {
        "input": "ABCDef",
        "style": "CapsUpperUnderscore",
        "expected": "ABCDEF",
    },
    {
        "input": "ABCDef",
        "style": "LowerCamelCase",
        "expected": "abcdef",
    },
    {
        "input": "ABCDef",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_abcdef",
    },
    {
        "input": "ABCDef",
        "style": "LowerUnderscore",
        "expected": "abcdef",
    },
    {
        "input": "ABCDef",
        "style": "Unaltered",
        "expected": "ABCDef",
    },
    {
        "input": "ABCDef",
        "style": "UnalteredButValid",
        "expected": "ABCDef",
    },
    {
        "input": "ABCDef",
        "style": "UpperCamelCase",
        "expected": "Abcdef",
    },
    {
        "input": "ABCDef",
        "style": "UpperUnderscore",
        "expected": "Abcdef",
    },
    {
        "input": "Dims",
        "style": "CapsUpperUnderscore",
        "expected": "DIMS",
    },
    {
        "input": "Dims",
        "style": "LowerCamelCase",
        "expected": "dims",
    },
    {
        "input": "Dims",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_dims",
    },
    {
        "input": "Dims",
        "style": "LowerUnderscore",
        "expected": "dims",
    },
    {
        "input": "Dims",
        "style": "Unaltered",
        "expected": "Dims",
    },
    {
        "input": "Dims",
        "style": "UnalteredButValid",
        "expected": "Dims",
    },
    {
        "input": "Dims",
        "style": "UpperCamelCase",
        "expected": "Dims",
    },
    {
        "input": "Dims",
        "style": "UpperUnderscore",
        "expected": "Dims",
    },
    {
        "input": "Example",
        "style": "CapsUpperUnderscore",
        "expected": "EXAMPLE",
    },
    {
        "input": "Example",
        "style": "LowerCamelCase",
        "expected": "example",
    },
    {
        "input": "Example",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_example",
    },
    {
        "input": "Example",
        "style": "LowerUnderscore",
        "expected": "example",
    },
    {
        "input": "Example",
        "style": "Unaltered",
        "expected": "Example",
    },
    {
        "input": "Example",
        "style": "UnalteredButValid",
        "expected": "Example",
    },
    {
        "input": "Example",
        "style": "UpperCamelCase",
        "expected": "Example",
    },
    {
        "input": "Example",
        "style": "UpperUnderscore",
        "expected": "Example",
    },
    {
        "input": "Example123Name",
        "style": "CapsUpperUnderscore",
        "expected": "EXAMPLE123NAME",
    },
    {
        "input": "Example123Name",
        "style": "LowerCamelCase",
        "expected": "example123name",
    },
    {
        "input": "Example123Name",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_example123name",
    },
    {
        "input": "Example123Name",
        "style": "LowerUnderscore",
        "expected": "example123name",
    },
    {
        "input": "Example123Name",
        "style": "Unaltered",
        "expected": "Example123Name",
    },
    {
        "input": "Example123Name",
        "style": "UnalteredButValid",
        "expected": "Example123Name",
    },
    {
        "input": "Example123Name",
        "style": "UpperCamelCase",
        "expected": "Example123name",
    },
    {
        "input": "Example123Name",
        "style": "UpperUnderscore",
        "expected": "Example123name",
    },
    {
        "input": "ExampleName",
        "style": "CapsUpperUnderscore",
        "expected": "EXAMPLE_NAME",
    },
    {
        "input": "ExampleName",
        "style": "LowerCamelCase",
        "expected": "exampleName",
    },
    {
        "input": "ExampleName",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_exampleName",
    },
    {
        "input": "ExampleName",
        "style": "LowerUnderscore",
        "expected": "example_name",
    },
    {
        "input": "ExampleName",
        "style": "Unaltered",
        "expected": "ExampleName",
    },
    {
        "input": "ExampleName",
        "style": "UnalteredButValid",
        "expected": "ExampleName",
    },
    {
        "input": "ExampleName",
        "style": "UpperCamelCase",
        "expected": "ExampleName",
    },
    {
        "input": "ExampleName",
        "style": "UpperUnderscore",
        "expected": "Example_Name",
    },
    {
        "input": "Geometry",
        "style": "CapsUpperUnderscore",
        "expected": "GEOMETRY",
    },
    {
        "input": "Geometry",
        "style": "LowerCamelCase",
        "expected": "geometry",
    },
    {
        "input": "Geometry",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_geometry",
    },
    {
        "input": "Geometry",
        "style": "LowerUnderscore",
        "expected": "geometry",
    },
    {
        "input": "Geometry",
        "style": "Unaltered",
        "expected": "Geometry",
    },
    {
        "input": "Geometry",
        "style": "UnalteredButValid",
        "expected": "Geometry",
    },
    {
        "input": "Geometry",
        "style": "UpperCamelCase",
        "expected": "Geometry",
    },
    {
        "input": "Geometry",
        "style": "UpperUnderscore",
        "expected": "Geometry",
    },
    {
        "input": "Get Something",
        "style": "CapsUpperUnderscore",
        "expected": "GET_SOMETHING",
    },
    {
        "input": "Get Something",
        "style": "LowerCamelCase",
        "expected": "getSomething",
    },
    {
        "input": "Get Something",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_getSomething",
    },
    {
        "input": "Get Something",
        "style": "LowerUnderscore",
        "expected": "get_something",
    },
    {
        "input": "Get Something",
        "style": "Unaltered",
        "expected": "Get Something",
    },
    {
        "input": "Get Something",
        "style": "UnalteredButValid",
        "expected": "GetSomething",
    },
    {
        "input": "Get Something",
        "style": "UpperCamelCase",
        "expected": "GetSomething",
    },
    {
        "input": "Get Something",
        "style": "UpperUnderscore",
        "expected": "Get_Something",
    },
    {
        "input": "Get __()X So%'/`m\\]ething4",
        "style": "CapsUpperUnderscore",
        "expected": "GET__X_SO_M_ETHING4",
    },
    {
        "input": "Get __()X So%'/`m\\]ething4",
        "style": "LowerCamelCase",
        "expected": "getXSoMEthing4",
    },
    {
        "input": "Get __()X So%'/`m\\]ething4",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_getXSoMEthing4",
    },
    {
        "input": "Get __()X So%'/`m\\]ething4",
        "style": "LowerUnderscore",
        "expected": "get__x_so_m_ething4",
    },
    {
        "input": "Get __()X So%'/`m\\]ething4",
        "style": "Unaltered",
        "expected": "Get __()X So%'/`m\\]ething4",
    },
    {
        "input": "Get __()X So%'/`m\\]ething4",
        "style": "UnalteredButValid",
        "expected": "Get__XSomething4",
    },
    {
        "input": "Get __()X So%'/`m\\]ething4",
        "style": "UpperCamelCase",
        "expected": "GetXSoMEthing4",
    },
    {
        "input": "Get __()X So%'/`m\\]ething4",
        "style": "UpperUnderscore",
        "expected": "Get__X_So_M_Ething4",
    },
    {
        "input": "Get __()X Something",
        "style": "CapsUpperUnderscore",
        "expected": "GET__X_SOMETHING",
    },
    {
        "input": "Get __()X Something",
        "style": "LowerCamelCase",
        "expected": "getXSomething",
    },
    {
        "input": "Get __()X Something",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_getXSomething",
    },
    {
        "input": "Get __()X Something",
        "style": "LowerUnderscore",
        "expected": "get__x_something",
    },
    {
        "input": "Get __()X Something",
        "style": "Unaltered",
        "expected": "Get __()X Something",
    },
    {
        "input": "Get __()X Something",
        "style": "UnalteredButValid",
        "expected": "Get__XSomething",
    },
    {
        "input": "Get __()X Something",
        "style": "UpperCamelCase",
        "expected": "GetXSomething",
    },
    {
        "input": "Get __()X Something",
        "style": "UpperUnderscore",
        "expected": "Get__X_Something",
    },
    {
        "input": "GetSomething",
        "style": "CapsUpperUnderscore",
        "expected": "GET_SOMETHING",
    },
    {
        "input": "GetSomething",
        "style": "LowerCamelCase",
        "expected": "getSomething",
    },
    {
        "input": "GetSomething",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_getSomething",
    },
    {
        "input": "GetSomething",
        "style": "LowerUnderscore",
        "expected": "get_something",
    },
    {
        "input": "GetSomething",
        "style": "Unaltered",
        "expected": "GetSomething",
    },
    {
        "input": "GetSomething",
        "style": "UnalteredButValid",
        "expected": "GetSomething",
    },
    {
        "input": "GetSomething",
        "style": "UpperCamelCase",
        "expected": "GetSomething",
    },
    {
        "input": "GetSomething",
        "style": "UpperUnderscore",
        "expected": "Get_Something",
    },
    {
        "input": "HANDLE__DIAGNOSTIC",
        "style": "CapsUpperUnderscore",
        "expected": "HANDLE__DIAGNOSTIC",
    },
    {
        "input": "HANDLE__DIAGNOSTIC",
        "style": "LowerCamelCase",
        "expected": "handleDiagnostic",
    },
    {
        "input": "HANDLE__DIAGNOSTIC",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_handleDiagnostic",
    },
    {
        "input": "HANDLE__DIAGNOSTIC",
        "style": "LowerUnderscore",
        "expected": "handle__diagnostic",
    },
    {
        "input": "HANDLE__DIAGNOSTIC",
        "style": "Unaltered",
        "expected": "HANDLE__DIAGNOSTIC",
    },
    {
        "input": "HANDLE__DIAGNOSTIC",
        "style": "UnalteredButValid",
        "expected": "HANDLE__DIAGNOSTIC",
    },
    {
        "input": "HANDLE__DIAGNOSTIC",
        "style": "UpperCamelCase",
        "expected": "HandleDiagnostic",
    },
    {
        "input": "HANDLE__DIAGNOSTIC",
        "style": "UpperUnderscore",
        "expected": "Handle__diagnostic",
    },
    {
        "input": "HTTPServer",
        "style": "CapsUpperUnderscore",
        "expected": "HTTPSERVER",
    },
    {
        "input": "HTTPServer",
        "style": "LowerCamelCase",
        "expected": "httpserver",
    },
    {
        "input": "HTTPServer",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_httpserver",
    },
    {
        "input": "HTTPServer",
        "style": "LowerUnderscore",
        "expected": "httpserver",
    },
    {
        "input": "HTTPServer",
        "style": "Unaltered",
        "expected": "HTTPServer",
    },
    {
        "input": "HTTPServer",
        "style": "UnalteredButValid",
        "expected": "HTTPServer",
    },
    {
        "input": "HTTPServer",
        "style": "UpperCamelCase",
        "expected": "Httpserver",
    },
    {
        "input": "HTTPServer",
        "style": "UpperUnderscore",
        "expected": "Httpserver",
    },
    {
        "input": "IOHandler",
        "style": "CapsUpperUnderscore",
        "expected": "IOHANDLER",
    },
    {
        "input": "IOHandler",
        "style": "LowerCamelCase",
        "expected": "iohandler",
    },
    {
        "input": "IOHandler",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_iohandler",
    },
    {
        "input": "IOHandler",
        "style": "LowerUnderscore",
        "expected": "iohandler",
    },
    {
        "input": "IOHandler",
        "style": "Unaltered",
        "expected": "IOHandler",
    },
    {
        "input": "IOHandler",
        "style": "UnalteredButValid",
        "expected": "IOHandler",
    },
    {
        "input": "IOHandler",
        "style": "UpperCamelCase",
        "expected": "Iohandler",
    },
    {
        "input": "IOHandler",
        "style": "UpperUnderscore",
        "expected": "Iohandler",
    },
    {
        "input": "IoHandler",
        "style": "CapsUpperUnderscore",
        "expected": "IO_HANDLER",
    },
    {
        "input": "IoHandler",
        "style": "LowerCamelCase",
        "expected": "ioHandler",
    },
    {
        "input": "IoHandler",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_ioHandler",
    },
    {
        "input": "IoHandler",
        "style": "LowerUnderscore",
        "expected": "io_handler",
    },
    {
        "input": "IoHandler",
        "style": "Unaltered",
        "expected": "IoHandler",
    },
    {
        "input": "IoHandler",
        "style": "UnalteredButValid",
        "expected": "IoHandler",
    },
    {
        "input": "IoHandler",
        "style": "UpperCamelCase",
        "expected": "IoHandler",
    },
    {
        "input": "IoHandler",
        "style": "UpperUnderscore",
        "expected": "Io_Handler",
    },
    {
        "input": "Level2Sensor",
        "style": "CapsUpperUnderscore",
        "expected": "LEVEL2SENSOR",
    },
    {
        "input": "Level2Sensor",
        "style": "LowerCamelCase",
        "expected": "level2sensor",
    },
    {
        "input": "Level2Sensor",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_level2sensor",
    },
    {
        "input": "Level2Sensor",
        "style": "LowerUnderscore",
        "expected": "level2sensor",
    },
    {
        "input": "Level2Sensor",
        "style": "Unaltered",
        "expected": "Level2Sensor",
    },
    {
        "input": "Level2Sensor",
        "style": "UnalteredButValid",
        "expected": "Level2Sensor",
    },
    {
        "input": "Level2Sensor",
        "style": "UpperCamelCase",
        "expected": "Level2sensor",
    },
    {
        "input": "Level2Sensor",
        "style": "UpperUnderscore",
        "expected": "Level2sensor",
    },
    {
        "input": "My-Module",
        "style": "CapsUpperUnderscore",
        "expected": "MY_MODULE",
    },
    {
        "input": "My-Module",
        "style": "LowerCamelCase",
        "expected": "myModule",
    },
    {
        "input": "My-Module",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_myModule",
    },
    {
        "input": "My-Module",
        "style": "LowerUnderscore",
        "expected": "my_module",
    },
    {
        "input": "My-Module",
        "style": "Unaltered",
        "expected": "My-Module",
    },
    {
        "input": "My-Module",
        "style": "UnalteredButValid",
        "expected": "MyModule",
    },
    {
        "input": "My-Module",
        "style": "UpperCamelCase",
        "expected": "MyModule",
    },
    {
        "input": "My-Module",
        "style": "UpperUnderscore",
        "expected": "My_Module",
    },
    {
        "input": "MyExampleName",
        "style": "CapsUpperUnderscore",
        "expected": "MY_EXAMPLE_NAME",
    },
    {
        "input": "MyExampleName",
        "style": "LowerCamelCase",
        "expected": "myExampleName",
    },
    {
        "input": "MyExampleName",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_myExampleName",
    },
    {
        "input": "MyExampleName",
        "style": "LowerUnderscore",
        "expected": "my_example_name",
    },
    {
        "input": "MyExampleName",
        "style": "Unaltered",
        "expected": "MyExampleName",
    },
    {
        "input": "MyExampleName",
        "style": "UnalteredButValid",
        "expected": "MyExampleName",
    },
    {
        "input": "MyExampleName",
        "style": "UpperCamelCase",
        "expected": "MyExampleName",
    },
    {
        "input": "MyExampleName",
        "style": "UpperUnderscore",
        "expected": "My_Example_Name",
    },
    {
        "input": "MyIOHandler",
        "style": "CapsUpperUnderscore",
        "expected": "MY_IOHANDLER",
    },
    {
        "input": "MyIOHandler",
        "style": "LowerCamelCase",
        "expected": "myIohandler",
    },
    {
        "input": "MyIOHandler",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_myIohandler",
    },
    {
        "input": "MyIOHandler",
        "style": "LowerUnderscore",
        "expected": "my_iohandler",
    },
    {
        "input": "MyIOHandler",
        "style": "Unaltered",
        "expected": "MyIOHandler",
    },
    {
        "input": "MyIOHandler",
        "style": "UnalteredButValid",
        "expected": "MyIOHandler",
    },
    {
        "input": "MyIOHandler",
        "style": "UpperCamelCase",
        "expected": "MyIohandler",
    },
    {
        "input": "MyIOHandler",
        "style": "UpperUnderscore",
        "expected": "My_Iohandler",
    },
    {
        "input": "My_Module",
        "style": "CapsUpperUnderscore",
        "expected": "MY_MODULE",
    },
    {
        "input": "My_Module",
        "style": "LowerCamelCase",
        "expected": "myModule",
    },
    {
        "input": "My_Module",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_myModule",
    },
    {
        "input": "My_Module",
        "style": "LowerUnderscore",
        "expected": "my_module",
    },
    {
        "input": "My_Module",
        "style": "Unaltered",
        "expected": "My_Module",
    },
    {
        "input": "My_Module",
        "style": "UnalteredButValid",
        "expected": "My_Module",
    },
    {
        "input": "My_Module",
        "style": "UpperCamelCase",
        "expected": "MyModule",
    },
    {
        "input": "My_Module",
        "style": "UpperUnderscore",
        "expected": "My_module",
    },
    {
        "input": "ServerHTTP",
        "style": "CapsUpperUnderscore",
        "expected": "SERVER_HTTP",
    },
    {
        "input": "ServerHTTP",
        "style": "LowerCamelCase",
        "expected": "serverHttp",
    },
    {
        "input": "ServerHTTP",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_serverHttp",
    },
    {
        "input": "ServerHTTP",
        "style": "LowerUnderscore",
        "expected": "server_http",
    },
    {
        "input": "ServerHTTP",
        "style": "Unaltered",
        "expected": "ServerHTTP",
    },
    {
        "input": "ServerHTTP",
        "style": "UnalteredButValid",
        "expected": "ServerHTTP",
    },
    {
        "input": "ServerHTTP",
        "style": "UpperCamelCase",
        "expected": "ServerHttp",
    },
    {
        "input": "ServerHTTP",
        "style": "UpperUnderscore",
        "expected": "Server_Http",
    },
    {
        "input": "_Leading",
        "style": "CapsUpperUnderscore",
        "expected": "i_LEADING",
    },
    {
        "input": "_Leading",
        "style": "LowerCamelCase",
        "expected": "leading",
    },
    {
        "input": "_Leading",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_leading",
    },
    {
        "input": "_Leading",
        "style": "LowerUnderscore",
        "expected": "i_leading",
    },
    {
        "input": "_Leading",
        "style": "Unaltered",
        "expected": "i_Leading",
    },
    {
        "input": "_Leading",
        "style": "UnalteredButValid",
        "expected": "i_Leading",
    },
    {
        "input": "_Leading",
        "style": "UpperCamelCase",
        "expected": "Leading",
    },
    {
        "input": "_Leading",
        "style": "UpperUnderscore",
        "expected": "I_leading",
    },
    {
        "input": "a",
        "style": "CapsUpperUnderscore",
        "expected": "A",
    },
    {
        "input": "a",
        "style": "LowerCamelCase",
        "expected": "a",
    },
    {
        "input": "a",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_a",
    },
    {
        "input": "a",
        "style": "LowerUnderscore",
        "expected": "a",
    },
    {
        "input": "a",
        "style": "Unaltered",
        "expected": "a",
    },
    {
        "input": "a",
        "style": "UnalteredButValid",
        "expected": "a",
    },
    {
        "input": "a",
        "style": "UpperCamelCase",
        "expected": "A",
    },
    {
        "input": "a",
        "style": "UpperUnderscore",
        "expected": "A",
    },
    {
        "input": "example",
        "style": "CapsUpperUnderscore",
        "expected": "EXAMPLE",
    },
    {
        "input": "example",
        "style": "LowerCamelCase",
        "expected": "example",
    },
    {
        "input": "example",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_example",
    },
    {
        "input": "example",
        "style": "LowerUnderscore",
        "expected": "example",
    },
    {
        "input": "example",
        "style": "Unaltered",
        "expected": "example",
    },
    {
        "input": "example",
        "style": "UnalteredButValid",
        "expected": "example",
    },
    {
        "input": "example",
        "style": "UpperCamelCase",
        "expected": "Example",
    },
    {
        "input": "example",
        "style": "UpperUnderscore",
        "expected": "Example",
    },
    {
        "input": "exampleName",
        "style": "CapsUpperUnderscore",
        "expected": "EXAMPLE_NAME",
    },
    {
        "input": "exampleName",
        "style": "LowerCamelCase",
        "expected": "exampleName",
    },
    {
        "input": "exampleName",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_exampleName",
    },
    {
        "input": "exampleName",
        "style": "LowerUnderscore",
        "expected": "example_name",
    },
    {
        "input": "exampleName",
        "style": "Unaltered",
        "expected": "exampleName",
    },
    {
        "input": "exampleName",
        "style": "UnalteredButValid",
        "expected": "exampleName",
    },
    {
        "input": "exampleName",
        "style": "UpperCamelCase",
        "expected": "ExampleName",
    },
    {
        "input": "exampleName",
        "style": "UpperUnderscore",
        "expected": "Example_Name",
    },
    {
        "input": "getSomething",
        "style": "CapsUpperUnderscore",
        "expected": "GET_SOMETHING",
    },
    {
        "input": "getSomething",
        "style": "LowerCamelCase",
        "expected": "getSomething",
    },
    {
        "input": "getSomething",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_getSomething",
    },
    {
        "input": "getSomething",
        "style": "LowerUnderscore",
        "expected": "get_something",
    },
    {
        "input": "getSomething",
        "style": "Unaltered",
        "expected": "getSomething",
    },
    {
        "input": "getSomething",
        "style": "UnalteredButValid",
        "expected": "getSomething",
    },
    {
        "input": "getSomething",
        "style": "UpperCamelCase",
        "expected": "GetSomething",
    },
    {
        "input": "getSomething",
        "style": "UpperUnderscore",
        "expected": "Get_Something",
    },
    {
        "input": "my_module",
        "style": "CapsUpperUnderscore",
        "expected": "MY_MODULE",
    },
    {
        "input": "my_module",
        "style": "LowerCamelCase",
        "expected": "myModule",
    },
    {
        "input": "my_module",
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": "_myModule",
    },
    {
        "input": "my_module",
        "style": "LowerUnderscore",
        "expected": "my_module",
    },
    {
        "input": "my_module",
        "style": "Unaltered",
        "expected": "my_module",
    },
    {
        "input": "my_module",
        "style": "UnalteredButValid",
        "expected": "my_module",
    },
    {
        "input": "my_module",
        "style": "UpperCamelCase",
        "expected": "MyModule",
    },
    {
        "input": "my_module",
        "style": "UpperUnderscore",
        "expected": "My_module",
    },
]

# Cases read inputs first, then the expectation. Sorting the keys
# alphabetically would put "expected" before "input", which reads backwards for
# a table of test data.
# buildifier: disable=unsorted-dict-items
PATH_CASES = [
    {
        "module_path": [
            "Dims",
        ],
        "style": "CapsUpperUnderscore",
        "expected": {
            "header": "DIMS.h",
            "impl": "DIMS.cc",
        },
    },
    {
        "module_path": [
            "Dims",
        ],
        "style": "LowerCamelCase",
        "expected": {
            "header": "dims.h",
            "impl": "dims.cc",
        },
    },
    {
        "module_path": [
            "Dims",
        ],
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": {
            "header": "_dims.h",
            "impl": "_dims.cc",
        },
    },
    {
        "module_path": [
            "Dims",
        ],
        "style": "LowerUnderscore",
        "expected": {
            "header": "dims.h",
            "impl": "dims.cc",
        },
    },
    {
        "module_path": [
            "Dims",
        ],
        "style": "Unaltered",
        "expected": {
            "header": "Dims.h",
            "impl": "Dims.cc",
        },
    },
    {
        "module_path": [
            "Dims",
        ],
        "style": "UnalteredButValid",
        "expected": {
            "header": "Dims.h",
            "impl": "Dims.cc",
        },
    },
    {
        "module_path": [
            "Dims",
        ],
        "style": "UpperCamelCase",
        "expected": {
            "header": "Dims.h",
            "impl": "Dims.cc",
        },
    },
    {
        "module_path": [
            "Dims",
        ],
        "style": "UpperUnderscore",
        "expected": {
            "header": "Dims.h",
            "impl": "Dims.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "Dims",
        ],
        "style": "CapsUpperUnderscore",
        "expected": {
            "header": "GEOMETRY/DIMS.h",
            "impl": "GEOMETRY/DIMS.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "Dims",
        ],
        "style": "LowerCamelCase",
        "expected": {
            "header": "geometry/dims.h",
            "impl": "geometry/dims.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "Dims",
        ],
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": {
            "header": "_geometry/_dims.h",
            "impl": "_geometry/_dims.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "Dims",
        ],
        "style": "LowerUnderscore",
        "flat_hierarchy": True,
        "expected": {
            "header": "dims.h",
            "impl": "dims.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "Dims",
        ],
        "style": "LowerUnderscore",
        "expected": {
            "header": "geometry/dims.h",
            "impl": "geometry/dims.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "Dims",
        ],
        "style": "Unaltered",
        "mocks": True,
        "expected": {
            "header": "Geometry/Dims.h",
            "impl": "Geometry/Dims.cc",
            "mock_header": "Geometry/DimsMock.h",
            "mock_impl": "Geometry/DimsMock.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "Dims",
        ],
        "style": "Unaltered",
        "expected": {
            "header": "Geometry/Dims.h",
            "impl": "Geometry/Dims.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "Dims",
        ],
        "style": "UnalteredButValid",
        "expected": {
            "header": "Geometry/Dims.h",
            "impl": "Geometry/Dims.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "Dims",
        ],
        "style": "UpperCamelCase",
        "expected": {
            "header": "Geometry/Dims.h",
            "impl": "Geometry/Dims.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "Dims",
        ],
        "style": "UpperUnderscore",
        "expected": {
            "header": "Geometry/Dims.h",
            "impl": "Geometry/Dims.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "IOHandler",
        ],
        "style": "CapsUpperUnderscore",
        "mocks": True,
        "expected": {
            "header": "GEOMETRY/IOHANDLER.h",
            "impl": "GEOMETRY/IOHANDLER.cc",
            "mock_header": "GEOMETRY/IOHANDLERMock.h",
            "mock_impl": "GEOMETRY/IOHANDLERMock.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "IOHandler",
        ],
        "style": "CapsUpperUnderscore",
        "expected": {
            "header": "GEOMETRY/IOHANDLER.h",
            "impl": "GEOMETRY/IOHANDLER.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "IOHandler",
        ],
        "style": "LowerCamelCase",
        "expected": {
            "header": "geometry/iohandler.h",
            "impl": "geometry/iohandler.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "IOHandler",
        ],
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": {
            "header": "_geometry/_iohandler.h",
            "impl": "_geometry/_iohandler.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "IOHandler",
        ],
        "style": "LowerUnderscore",
        "mocks": True,
        "expected": {
            "header": "geometry/iohandler.h",
            "impl": "geometry/iohandler.cc",
            "mock_header": "geometry/iohandlerMock.h",
            "mock_impl": "geometry/iohandlerMock.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "IOHandler",
        ],
        "style": "LowerUnderscore",
        "expected": {
            "header": "geometry/iohandler.h",
            "impl": "geometry/iohandler.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "IOHandler",
        ],
        "style": "Unaltered",
        "expected": {
            "header": "Geometry/IOHandler.h",
            "impl": "Geometry/IOHandler.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "IOHandler",
        ],
        "style": "UnalteredButValid",
        "expected": {
            "header": "Geometry/IOHandler.h",
            "impl": "Geometry/IOHandler.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "IOHandler",
        ],
        "style": "UpperCamelCase",
        "expected": {
            "header": "Geometry/Iohandler.h",
            "impl": "Geometry/Iohandler.cc",
        },
    },
    {
        "module_path": [
            "Geometry",
            "IOHandler",
        ],
        "style": "UpperUnderscore",
        "expected": {
            "header": "Geometry/Iohandler.h",
            "impl": "Geometry/Iohandler.cc",
        },
    },
    {
        "module_path": [
            "Level2Sensor",
        ],
        "style": "CapsUpperUnderscore",
        "expected": {
            "header": "LEVEL2SENSOR.h",
            "impl": "LEVEL2SENSOR.cc",
        },
    },
    {
        "module_path": [
            "Level2Sensor",
        ],
        "style": "LowerCamelCase",
        "expected": {
            "header": "level2sensor.h",
            "impl": "level2sensor.cc",
        },
    },
    {
        "module_path": [
            "Level2Sensor",
        ],
        "style": "LowerCamelCasePrefixUnderscore",
        "expected": {
            "header": "_level2sensor.h",
            "impl": "_level2sensor.cc",
        },
    },
    {
        "module_path": [
            "Level2Sensor",
        ],
        "style": "LowerUnderscore",
        "header_prefix": "api_",
        "impl_prefix": "impl_",
        "header_extension": ".hpp",
        "impl_extension": ".cpp",
        "expected": {
            "header": "api_level2sensor.hpp",
            "impl": "impl_level2sensor.cpp",
        },
    },
    {
        "module_path": [
            "Level2Sensor",
        ],
        "style": "LowerUnderscore",
        "expected": {
            "header": "level2sensor.h",
            "impl": "level2sensor.cc",
        },
    },
    {
        "module_path": [
            "Level2Sensor",
        ],
        "style": "Unaltered",
        "expected": {
            "header": "Level2Sensor.h",
            "impl": "Level2Sensor.cc",
        },
    },
    {
        "module_path": [
            "Level2Sensor",
        ],
        "style": "UnalteredButValid",
        "expected": {
            "header": "Level2Sensor.h",
            "impl": "Level2Sensor.cc",
        },
    },
    {
        "module_path": [
            "Level2Sensor",
        ],
        "style": "UpperCamelCase",
        "expected": {
            "header": "Level2sensor.h",
            "impl": "Level2sensor.cc",
        },
    },
    {
        "module_path": [
            "Level2Sensor",
        ],
        "style": "UpperUnderscore",
        "expected": {
            "header": "Level2sensor.h",
            "impl": "Level2sensor.cc",
        },
    },
]
