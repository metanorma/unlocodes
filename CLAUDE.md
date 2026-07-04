# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`unlocode` is a Ruby gem that exposes the UN/LOCODE dataset (United Nations Code for Trade and Transport Locations) as a queryable in-memory registry.

UN/LOCODE assigns 5-character codes (ISO 3166-1 alpha-2 country + 3 location characters, e.g. `CNSHA` for Shanghai) to ports, airports, rail terminals, road terminals, inland transport hubs, postal exchange offices, and other trade/transport locations worldwide.

The dataset is published by UNECE/UNCEFACT as a JSON-LD vocabulary, tagged `2025-1`:
https://opensource.unicc.org/un/unece/uncefact/vocab-locode/-/tags/2025-1

This gem **vendors** the dataset (offline by design — the 39 MB `lib/unlocode/data/locode.jsonld` ships in the gem) and exposes it through a model-driven Ruby API. The upstream URL is the **source of truth for data refresh**, not a runtime dependency.

## Commands

```bash
bundle install                                # Install dev dependencies
bundle exec rake spec                         # Run the full RSpec suite (~30s; loads 115k entries)
bundle exec rspec spec/unlocode/entry_spec.rb # Run a single spec file
bundle exec rspec spec/unlocode/entry_spec.rb:42  # Run one example by line
bundle exec rubocop                           # Lint
bundle exec rubocop -A                        # Auto-correct lint
bundle exec rake unlocode:fetch               # Refresh vendored data from upstream (default tag: 2025-1)
bundle exec rake build                        # Build .gem into pkg/
```

Spec note: `spec_helper.rb` calls `Unlocodes.reset_registry!` after each example, but loading the bundled 115,928-entry dataset once per affected example is what makes the suite slow. Specs that don't need the global registry (e.g. `entry_spec`, `status_spec`, `coordinates_spec`) load in milliseconds.

## Architecture

### Data flow

```
lib/unlocode/data/locode.jsonld  ──▶  Loader  ──▶  [Unlocodes::Entry, …]  ──▶  Registry  ──▶  Query API
```

- **Loader** (`lib/unlocode/loader.rb`) parses the vendored JSON-LD file once into `Unlocodes::Entry` instances. The vocabulary is a single document whose `@graph` array contains one `unlcdv:UNLOCODE` resource per LOCODE.
- **Entry** (`lib/unlocode/entry.rb`) is a `lutaml-model` class — every attribute is typed; never a hash bag.
- **Registry** (`lib/unlocode/registry.rb`) holds all loaded entries and lazily builds the indexes callers actually need (by code, country, function). One global load, reused across queries.

### Wire names (UNCEFACT 2025-1)

The vocabulary uses these JSON-LD predicates (see `lib/unlocode/loader.rb`):

| Wire name                  | Ruby attribute    | Notes |
|----------------------------|-------------------|-------|
| `@id` (`unlcd:CNSHA`)      | `code` (fallback) | `rdf:value` is the primary |
| `rdf:value`                | `code`            | 5-char LOCODE |
| `rdfs:label`               | `name`            | Hash `{@language, @value}` or array |
| `unlcdv:countryCode`       | `country`         | `{"@id":"unlcdc:CN"}` — strip prefix |
| `unlcdv:countrySubdivision`| `subdivision`     | `{"@id":"unlcds:CNSH"}` — strip prefix |
| `unlcdv:functions`         | `function_codes`  | `{"@id":"unlcdf:4"}` — strip prefix; `1..9 → B,R,T,A,P,I,F,V,O` |
| `geo:lat`, `geo:long`      | `latitude`, `longitude` (Float) | Decimals degrees, WGS-84 |

The 2025-1 vocabulary does NOT publish status, change date, IATA, remarks, or name-without-diacritics in the JSON-LD — those fields live in the per-country CSVs and the diff file under `locodes/` and `vocab/unlocode-diff.txt` upstream. They are intentionally absent from the model until/unless those sources are also bundled.

### Function classifier mapping

`unlcdf:1`..`unlcdf:9` map to the UN/LOCODE manual's letters via `Loader::FUNCTION_DIGIT_TO_LETTER`. The `Function` class (`lib/unlocode/function.rb`) holds the human-readable descriptions keyed by letter.

### Query API

`Unlocodes::Registry` is the public query surface:
- `find(code)` / `[code]` — exact lookup (case-insensitive)
- `where(country:, function:, subdivision:, name:, ...)` — filtered query (single value or any-of array; `name:` accepts String or Regexp)
- `by_country`, `by_function` — pre-indexed direct lookups
- `countries`, `counts_by_country`, `each`, `size`, `count`

Top-level shortcuts on `Unlocodes` (a SingleForwardable delegator to `Unlocodes.registry`): `find`, `where`, `each`, `size`, `count`, `countries`.

### Dataset size & loading

The 2025-1 vocabulary has 115,928 entries. Strategy:
- Load once per process; cache globally on `Unlocodes.registry`.
- Build secondary indexes lazily on first use of each query shape (`@by_code`, `@by_country_index`, `@by_function_index`, `@by_status_index`).
- Loading parses the full JSON once (~3–5 seconds wall clock) and holds the entries array in memory.

## Conventions

These rules are load-bearing for this project; broader rules live in the global `~/.claude/CLAUDE.md`.

- **`lutaml-model` for every model.** No hand-rolled `to_h` / `from_h` / `to_json` / `from_json` on model classes. Wire-name translation lives in the Loader, not on the model.
- **`autoload`, not `require_relative`.** All internal library code uses `autoload` declared in the immediate parent namespace file (`lib/unlocode.rb`).
- **No `double()` in specs.** Use real `Unlocodes::Entry` instances built from sample vocabulary fragments, or lightweight `Struct`s for plain data.
- **Vendor the dataset inside the gem.** The gem must work offline. `lib/unlocode/data/locode.jsonld` ships in the gem package via the gemspec's `Dir.glob('{lib}/**/*')`.
- **Data refresh is an upstream-sync task.** Run `bundle exec rake unlocode:fetch` → commit the new `lib/unlocode/data/locode.jsonld` as one clearly-described update. Gem version bumps follow SemVer independently.
- **Standalone by design — no shared base across reference-data gems.** This gem does not share infrastructure with sibling gems (`iata`, future `iso3166`). Registry / Entry / Loader patterns are intentionally duplicated. See `docs/adr/0001-reference-data-gems-are-standalone.md`.

### Workflow safety (do not violate)

- All changes go through PRs. Never commit to `main`, never push to `main`, never merge to `main`, never push git tags. Releases are the user's call.
- Never add `Co-authored-by` / `Generated with` / `Signed-off-by` AI trailers to commits or PR descriptions.
- Never delete files I did not create. If cleanup is needed, flag it — never `rm` source files.
