// Stand-in for a real Boost target; exists only to prove cc_runtime_deps plumbing.
#ifndef COCO_E2E_BOOST_STUB_H_
#define COCO_E2E_BOOST_STUB_H_

namespace coco {
namespace test {

inline int BoostStubMarker() {
  return 42;
}

}  // namespace test
}  // namespace coco

#endif  // COCO_E2E_BOOST_STUB_H_
