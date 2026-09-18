# Name mangling conformance corpus

`name_mangling_corpus.bzl` is a contract between `rules_coco` and `popili`: both load this file and
assert against it, which keeps their two implementations of the file name mangler aligned.

## Symbols

| Symbol                          | Meaning                                                                      |
| ------------------------------- | ---------------------------------------------------------------------------- |
| `CORPUS_STYLES`                 | Every style popili supports, including ones `rules_coco` does not implement. |
| `STYLES_RULES_COCO_UNSUPPORTED` | The styles `rules_coco` does not implement.                                  |
| `MANGLE_CASES`                  | `{"input", "style", "expected"}` — one mangled name.                         |
| `PATH_CASES`                    | `{"module_path", "style", ..., "expected"}` — one set of output paths.       |
| `PATH_CASE_DEFAULTS`            | Default values used for `PATH_CASES`                                         |

A path case lists only the fields that differ from `PATH_CASE_DEFAULTS`, which both consumers merge
in before comparing.

## Not in the corpus

- The empty string, and any input that mangles to nothing: undefined in popili, and unreachable
  from real module names, which must be valid identifiers.
- Non-ASCII input: neither implementation specifies it.
- `include_prefix`, and the `Simulator` and `HiddenImplementation` output kinds: popili has them,
  rules_coco has no concept of them.
