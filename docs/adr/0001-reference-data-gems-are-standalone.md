# ADR-0001: Reference-data gems are standalone

Date: 2026-07-04
Status: Accepted

## Context

This organisation publishes a family of Ruby gems that each bundle a
reference dataset and expose a typed query API over it:

- `unlocodes` — UN/LOCODE dataset from UNECE/UNCEFACT (~115k entries)
- `iata` — IATA airport codes from Wikidata (~9k entries)
- (future) `iso3166` — ISO 3166 country and subdivision codes

Each gem independently implements the same architectural pattern: a
`Registry` (lazy-indexed in-memory lookup), an `Entry` (typed record),
a `Fetcher` (HTTP download), and a `Coordinates` value type. Code
reviewed in isolation sees this as duplication that could be extracted
into a shared base gem.

## Decision

We will **not** extract a shared base. Each gem remains standalone —
no `reference-data` base gem, no `ReferenceData::Base` class, no
cross-gem runtime dependency between sibling reference-data gems.

## Rationale

Each gem bundles its own dataset and exposes its own typed API. The
independence is load-bearing:

- **Blast radius.** A regression in a shared base ripples across all
  consumers. A bug in `unlocodes`'s loader must never break `iata`.
- **Release independence.** Each gem ships on its own cadence
  determined by its upstream dataset. A shared base couples those
  cadences.
- **Licensing.** Each dataset has its own upstream license terms
  (UN/LOCODE, Wikidata CC0, ISO 3166 reimplementations). Coupling
  the gems risks coupling the license obligations.
- **Caller footprint.** A user who installs `iata` should not transitively
  install `unlocodes`'s 39 MB dataset. Standalone gems keep each
  install minimal.

The visible "duplication" of Registry / Entry / Loader / Coordinates
across gems is the intended design — not friction to remove.

## Consequences

- Architecture reviews of these gems must not propose cross-gem base
  extraction as a deepening candidate. The pattern is recorded as a
  rejection rule.
- New sibling gems (e.g. `iso3166`) should replicate the pattern from
  an existing gem (copy + adapt), not inherit from a shared base.
- Internal refactors within a single gem (deepening Registry, folding
  shallow modules, etc.) remain encouraged — this ADR only forbids
  extraction **across** gems.

## Cross-reference

Recorded after `metanorma/unlocodes` architecture review candidate 5
was rejected by the maintainer on 2026-07-04.
