<div align="center">

<img src="DNS-speed-checker/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="160" alt="DNS Speed Checker icon">

# DNS Speed Checker

A native macOS app that benchmarks DNS resolvers by sending raw UDP queries
directly to each server and timing the round trip — like `dig @<server>`, but
with a live, sortable leaderboard.

</div>

## Features

- **Real per-resolver timing.** Builds raw DNS A-record packets and sends them
  over UDP/53 to each resolver's IP via `NWConnection`, so every provider is
  measured independently (not through the system resolver).
- **Round-robin testing.** Queries run one at a time (no uplink contention) but
  rotate across resolvers each round, so changing network conditions affect
  every provider equally instead of biasing whoever was tested last.
- **Cached vs. uncached.** Repeated lookups measure cached-response latency
  (your network RTT to the resolver); a cache-busting pass queries random
  subdomains to measure true upstream recursive resolution.
- **Live leaderboard.** Results and ranks update in real time as samples
  arrive, sorted fastest-first.
- **Detailed stats.** Tap any resolver for median, mean, mode, standard
  deviation, percentiles (90/95/99), jitter, cold-start, and response rate.
- **Unresponsive resolvers** are detected early and skipped so dead IPs don't
  drag out a run.
- 50+ built-in public resolvers, plus add your own and pick which domains to
  test against.

## Requirements

- macOS 14.4+
- Xcode 15+

## Build & run

```bash
git clone git@github.com:kyllan16693/dns-speed-checker.git
cd dns-speed-checker
open DNS-speed-checker.xcodeproj
```

Then build and run the `DNS-speed-checker` scheme (⌘R). To run the unit tests:

```bash
xcodebuild -scheme DNS-speed-checker -destination 'platform=macOS' test
```

## How testing works

Each resolver gets a discarded warm-up query, several repeated lookups of the
enabled domains (mostly cache hits — effectively network latency), then a
cache-busting pass against random subdomains no resolver can have cached
(measuring full recursive resolution). The reported figure is the median
round-trip time, which is robust to occasional jitter.
