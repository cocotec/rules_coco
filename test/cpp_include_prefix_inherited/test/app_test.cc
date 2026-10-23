#include "gtest/gtest.h"

#include "exported/IExporter.h"
#include "exported/IReceiver.h"
#include "IApp.h"
#include "ws/IInherits.h"

TEST(CppIncludePrefixInheritedTest, AppUsesInheritedAndExportedPrefixes) {
  Status status{Level::HIGH, Signal::ON};
  EXPECT_EQ(status.level, Level::HIGH);
  EXPECT_EQ(status.reading, Signal::ON);
}
