# Trading App — Flutter Assignment: Implementation Plan & Interview Playbook

**Deadline:** Monday, 3 Aug 2026. **Today:** Friday, 31 Jul 2026 → **you have ~3 working days.**
This plan is written to be *executed in that window*, not to be an idealized 3-week plan. Every "if time permits" note is there because it's genuinely optional, not because I'm hedging.

---

## 0. What "getting selected" actually depends on here

Re-reading the brief, the evaluators aren't grading "did you build 4 screens." They wrote *expected scenarios* for a reason — those are their test cases. Whoever built this brief has almost certainly wired up a mental (or literal) checklist against those bullet points. So the single highest-leverage thing you can do is: **treat every "Expected scenario" line in the original brief as a literal acceptance test**, and make sure your app visibly handles it — ideally in the walkthrough video, where you narrate "and here's what happens when I reorder while a tick is mid-flight" etc. That's what separates a submission that "has 4 features" from one that clearly understood *why* those features are hard.

The four things they're silently testing for, underneath the feature list:
1. **Single source of truth for prices** — do all screens showing RELIANCE agree, always?
2. **Correct realtime behavior under reordering/removal/navigation** — no stale bindings.
3. **Decimal correctness** — no floating-point drift in money.
4. **Rebuild discipline** — only the row that changed repaints, even at 50+ ticks/sec.

Everything below is structured around nailing those four, because they're the ones a reviewer can catch you failing just by watching your video closely.

**Calibrating this to ~4.5–5 years of experience, not "assignment completed."** A junior submission gets all four features technically working. What a reviewer expects from someone at your level is *evidence of judgment* — visible in three places, all baked into this plan rather than bolted on:
- **Dependency inversion on the price feed** (§3) — the four features depend on a `MarketDataService` *interface*, never on `MockMarketDataService` directly. That's not architecture-for-its-own-sake; it's the concrete answer to "how would you point this at a real backend tomorrow" without touching a single feature.
- **Named, defended trade-offs instead of hidden gaps** (§4, §5, §14) — Hive over Drift, int-paise over `decimal`, throttled sort over always-fresh sort. A senior engineer states the trade-off and the conditions under which they'd reverse it; a junior either doesn't notice the trade-off exists or hides it.
- **Explicit "what I'd do with more time" scoping** (§11, §14) — knowing what to *cut* under a 3-day deadline, and saying so out loud, is itself the signal. Don't apologize for the cuts in the video; state them as decisions.

---

## 1. Tech stack & package choices

You've shipped a similar assignment app before (SpendWise) with clean architecture + `flutter_bloc` + `GetIt` — staying consistent with that is the right call for a 3-day timeline; don't relearn a stack under deadline pressure. Recommended set:

| Concern | Package | Why |
|---|---|---|
| State management | `flutter_bloc` (Cubit for most, Bloc where events matter) | Consistent with what you've shipped before; testable; interviewers can ask you to defend it and you have real mileage |
| DI | `get_it`, registered manually in `injection.dart` | No codegen — see the "no extra setup" note in §13. `injectable` is fine if you're fast with it, but only if you remember to commit its generated file (§13) |
| Local persistence | `hive` + `hive_flutter`, with **hand-written `TypeAdapter<T>` classes** (not `hive_generator`) | Only ~4 model classes here — writing `read()`/`write()` by hand is a 20-minute job per model and removes the build_runner dependency entirely, which matters given the "runs with just `pub get && run`" requirement (§13) |
| Reactive local state (per-symbol prices) | `ValueNotifier` (built-in, no package) | See §3 — this is the actual answer to "correct realtime behavior" |
| Money | Plain `int` (paise/minor units) — no package needed | See §4 |
| Animations (flash) | `flutter_animate` or raw `AnimatedContainer`/`TweenAnimationBuilder` | You've used `flutter_animate` before |
| Charts (optional, Holdings polish) | `fl_chart` | Only if time permits — a tiny sparkline is a nice-to-have, not required |
| Testing | `flutter_test`, `bloc_test`, `mocktail` | Needed for §12 |

Don't reach for `rxdart`, `riverpod`, `drift`, `isar`, or anything you haven't used under time pressure before — none of them are *required* to satisfy the brief, and a working Hive-based app beats a half-finished Drift migration on Monday morning.

---

## 2. Architecture & folder structure

Feature-first Clean Architecture, same shape as SpendWise:

```
lib/
  core/
    di/                     # get_it setup
    constants/               # the 10 stock symbols, starting prices, tick config
    money/                   # Money value type, formatting extensions
    error/                   # Failure/Exception types
    theme/
  market_feed/                # SHARED — not a "feature", the engine everything depends on
    models/
      price_tick.dart
      stock.dart
    market_data_service.dart          # abstract interface
    mock_market_data_service.dart     # impl — single Timer-driven engine
  features/
    watchlist/
      data/        # hive models + adapters, local data source, repo impl
      domain/       # entities, repository interface, use cases
      presentation/ # cubit/bloc, pages, widgets (row, empty state, picker)
    live_prices/
      presentation/ # cubit, page, row widget with flash
    trade_ticket/
      domain/       # Order entity, PlaceOrder use case (the validation core)
      data/         # wallet repo, order history repo
      presentation/ # bloc, page, form widgets
    holdings/
      domain/       # Holding entity, sort/aggregate use cases
      data/         # holdings derived from order history (see §5)
      presentation/ # cubit, page, sortable list, summary header
  main.dart
```

**Why `market_feed` sits outside `features/`:** it's infrastructure shared by all four features, not owned by one of them. Putting it inside e.g. `live_prices/` and having the other three features reach into it is a dependency-direction smell an interviewer will spot instantly if they ask you to walk the folder tree.

### Clean, readable code — concrete practices, not just "write nice code"

This is graded explicitly, so treat it as a checklist, not a vibe:
- **Enforced formatting/lints**: extend `flutter_lints` (or `very_good_analysis` if you want a stricter bar) in `analysis_options.yaml`, run `dart format .` and `flutter analyze` clean before every commit — not just once at the end on Day 3.
- **Single-responsibility everywhere**: one Cubit per feature-concern, never a shared "AppCubit" managing watchlist state and wallet state together. If a class needs a comment explaining "this also handles X," it's two classes.
- **Names carry the meaning, comments carry the *why***: `calculateWeightedAverageCost()` not `calc()` with a comment above it. Reserve `///` doc comments for the handful of genuinely non-obvious decisions — *why* the average-cost division truncates, *why* the mutex exists in the wallet repo — not boilerplate restating what the code already says.
- **No primitive obsession**: `Money` and `PriceTick` value types (§4, §3) aren't just correctness tools, they make every signature self-documenting — `Money balance` reads its intent, `int balance` doesn't.
- **No magic numbers**: tick rate, clamp percentages, flash-animation duration, mutex timeout — all named constants in `core/constants/`, never inlined literals scattered across files where a reviewer has to hunt for "why 0.003."

---

## 3. The core engine: mock market data feed (build this first — everything depends on it)

This is the piece that determines whether Features 1, 2, 3, 4 all "agree" with each other. Design it before writing a single screen.

**Interface:**
```dart
abstract class MarketDataService {
  ValueListenable<PriceTick> priceOf(String symbol);   // one notifier per symbol
  PriceTick currentPrice(String symbol);                // sync read, no waiting for a tick
  void start();
  void dispose();
}
```

**Why `ValueListenable<PriceTick>` per symbol, not one big `Stream<Map<String,PriceTick>>`:**
This is the single most important architectural decision in the whole assignment, and it's the direct answer to "only affected cells rebuild" and "no stale ticks on the wrong row." If you model this as one stream of the whole price map, *every* listener rebuilds on *every* tick, and you'd have to hand-roll diffing to avoid it. If instead you give every stock symbol its own `ValueNotifier<PriceTick>` held in a `Map<String, ValueNotifier<PriceTick>>` inside the service (registered once at startup, for the fixed set of 10 symbols — never created/destroyed at runtime), then:
- A row widget wraps itself in `ValueListenableBuilder(valueListenable: service.priceOf(symbol), builder: ...)`.
- Only the notifier for the symbol that ticked fires; only that row rebuilds.
- Reordering a `ReorderableListView` never touches the binding — the row is keyed by *symbol* (`ValueKey(symbol)`), not by index, so as it moves position the same widget subtree (and thus the same `ValueListenableBuilder` subscription) moves with it. **This is exactly the "no stale ticks for the wrong row" edge case in the brief**, and index-based keys are the bug that fails it.
- Two watchlists containing the same stock both listen to the *same* notifier instance → guaranteed identical live prices, satisfying that expected scenario for free, by construction, not by careful syncing.

**Seed data** — the fixed universe, defined once in `core/constants/stocks.dart`, never hardcoded again anywhere else:

| Symbol | Example starting price (₹) |
|---|---|
| RELIANCE | 2,950.00 |
| TCS | 3,850.00 |
| INFY | 1,780.00 |
| HDFCBANK | 1,650.00 |
| ICICIBANK | 1,220.00 |
| SBIN | 830.00 |
| ITC | 465.00 |
| LT | 3,600.00 |
| BHARTIARTL | 1,590.00 |
| AXISBANK | 1,140.00 |

These don't need to match real market prices exactly (the brief says "any reasonable starting prices") — they just need to look plausible for large-cap Indian equities, which round numbers in these ranges do. Store them as `Money` (paise, §4) from the moment they're defined, not as `double`, so the seed data itself never introduces the floating-point drift you're avoiding everywhere else.

**Tick generation:**
- A single `Timer.periodic` heartbeat (interval derived from the configured tick rate) fires; on each fire, pick symbol(s) to update and mutate their notifier.
- Random-walk price model per symbol: `delta = currentPrice * randomInRange(-maxPctPerTick, maxPctPerTick)`, applied additively. Clamp cumulative move to roughly ±15–20% of the day's opening price so numbers stay plausible over a long-running session, and floor at some minimum (e.g. never below ₹1) so a pathological run of down-ticks can't produce a negative or zero price.
- `PriceTick` carries `{price, previousPrice, changeSinceOpen, changePctSinceOpen, direction}` so the UI layer never has to diff itself — direction (`up`/`down`/`flat`) is computed once, at the source, and used directly to pick the flash color. Computing it independently in every widget that displays a price is how you get subtle inconsistencies between screens.
- **Tick rate is configurable** via a constant/debug setting (`ticksPerSecondPerStock`), read by `MockMarketDataService` at construction. For the stress-test scenario (5+/sec/stock, 50+/sec overall), just turn this constant up — don't hardcode a rate.

**Lifecycle correctness (edge cases the brief doesn't spell out but a reviewer will notice):**
- The service is registered as a **singleton** in `GetIt`, constructed once, `start()`ed once in `main()` — never re-instantiated per screen. Otherwise you'd get multiple independent random walks and the "single source of truth" requirement silently breaks the moment two screens are open.
- On navigating away and back (e.g., leaving Live Prices and returning), the screen doesn't re-subscribe to a *new* engine — it's the same singleton, so prices are current, not stale, satisfying that expected scenario trivially.
- Widgets `dispose()` their own `ValueListenableBuilder` subscriptions automatically (framework does this) — but make sure you're **not** manually adding listeners in `initState` without removing them in `dispose`, which is the classic Flutter memory-leak-under-load bug that would surface exactly under the stress-test scenario.
- Consider pausing the timer when the app is backgrounded (`AppLifecycleState.paused`) and resuming on foreground — not required by the brief, but a nice "I thought about battery/perf" detail to mention in the video if you have time.

### If this were wired to a real backend instead of a mock

The brief only asks for a mock feed, but naming this boundary out loud is a stronger signal than pretending the mock *is* the final architecture. Because every feature depends on the `MarketDataService` interface and never on `MockMarketDataService` directly, swapping in a real feed is a single new implementation class, not a rewrite. What that real implementation would need to handle, that the mock currently doesn't:
- **Reconnection with backoff** — a WebSocket ticker drops; the service needs to detect the drop, retry with exponential backoff, and resubscribe to the same 10 symbols without the UI layer knowing anything happened.
- **Out-of-order / duplicate ticks** — over a real network, ticks can arrive out of send-order. Each tick would need a sequence number or server timestamp, and the service should discard a tick that's older than the one it already applied for that symbol — otherwise a stale tick can visually "rewind" a price after a newer one already rendered.
- **Staleness detection** — if no tick arrives for a symbol within some expected window, the UI should be able to show "stale"/greyed-out rather than silently displaying a last-known price as if it were live.
- **Backpressure** — a burst of ticks after a reconnect shouldn't be applied one-by-one at full speed if that means dropping frames; coalescing to "latest tick per symbol since last frame" is the natural extension of the throttled-resort idea already in §9, generalized to price updates themselves.

You don't need to build any of this — saying it clearly in the video or README, unprompted, does the work.

---

## 4. Money & decimal handling

**Decision: store every money value as an `int` in minor units (paise), never as `double`.** ₹1,234.56 is stored as `123456`. All arithmetic (order value = qty × LTP, balance deductions, weighted-average cost) happens on integers. Only at the final UI-formatting step do you divide by 100 and format with a `NumberFormat` for display.

Wrap this in a tiny value type instead of passing raw `int` around everywhere:
```dart
extension type Money(int paise) {
  Money operator +(Money other) => Money(paise + other.paise);
  Money operator -(Money other) => Money(paise - other.paise);
  String get formatted => '₹${(paise / 100).toStringAsFixed(2)}';
}
```
This isn't just style — it stops you from ever accidentally adding a "rupees" int to a "paise" int, which is a real bug class in fintech code (and directly relevant given your Atoa background — this is worth saying in the interview almost verbatim).

**Where it bites, specifically:**
- Order value = `quantity * ltp.paise` — integer × integer, exact, no rounding at all.
- Weighted average cost on a second buy of an already-held stock: `newAvgPaise = ((oldQty * oldAvgPaise) + (buyQty * buyPricePaise)) ~/ (oldQty + buyQty)`. Integer division truncates — for a portfolio-tracking app (not a clearing house) truncating to the nearest paise is an acceptable, defensible simplification; state that trade-off explicitly rather than hiding it. If you want to be fancier, carry an extra 2 digits of internal precision (basis points instead of paise) and round only at display time — mention this as the "how would you improve it" answer.
- P&L = `(qty * ltp.paise) - (qty * avgCostPaise)` — again all-integer.

---

## 5. Persistence strategy

**Decision: Hive for everything**, given the 3-day window — schema-less, no code-gen migration pain, fast to iterate on. Four boxes:
- `watchlists` — `List<WatchlistModel>` where each has `id, name, orderedSymbols: List<String>`.
- `wallet` — single value, current balance in paise.
- `orders` — append-only list of executed orders (`id, symbol, side, qty, priceAtExecution, timestamp`).
- **Holdings are *not* stored as their own box.** They're derived, at app startup and on every new order, from the `orders` box. This is the more defensible design and worth stating outright to an interviewer:

> "I treat order history as the single source of truth and *compute* holdings from it, rather than persisting a separate holdings snapshot that has to be kept in sync with orders on every write. That removes an entire class of dual-write bugs — the risk of holdings and order history disagreeing after a crash mid-write."

It still satisfies "persist holdings across app restarts," because holdings persist *by construction* — the orders they're derived from persist, and the derivation is deterministic and cheap (10 stocks, a handful of orders — this is not expensive to recompute at boot).

**Concurrency guard on writes:** order submission needs to (a) deduct/credit wallet and (b) append to order history as one logical unit. Hive doesn't give you cross-box transactions, so wrap the two writes in a simple `Completer`-based mutex inside the order repository (serialize calls to `placeOrder`) rather than relying on the UI to prevent double-submission alone. This is your answer to "how do you prevent a double-tap on Submit from double-charging the wallet."

*If time genuinely permits after all four features work end-to-end and are tested* — swapping the wallet+orders repository for `drift`/SQLite with a real `transaction()` block is the natural "next step" to mention in the video ("this is the boundary where I'd reach for a real transactional store"). Don't attempt the migration under deadline pressure; saying it out loud is worth more than a half-done implementation.

---

## 6. Feature 1 — Watchlist

### Tasks & subtasks
1. **Domain layer**
   - `Watchlist` entity (`id`, `name`, `symbols: List<String>`), `WatchlistRepository` interface (CRUD + reorder).
2. **Data layer**
   - Hive model/adapter, local data source, repository impl backed by the `watchlists` box.
3. **Presentation**
   - Watchlist list screen (all watchlists) → create / rename / delete.
   - Watchlist detail screen: `ReorderableListView.builder`, each row **keyed by symbol** (`ValueKey`). Row content is exactly the four fields the brief specifies — **symbol** (static text), **last price / LTP**, **change (₹)**, **change (%)** — the latter three driven by `ValueListenableBuilder` on `marketDataService.priceOf(symbol)` (never by re-fetching or passing a static price down). This is the same row widget Feature 2 reuses (§7).
   - **Remove-stock affordance**: wrap each row in `Dismissible` (swipe-to-remove) or give it a trailing delete `IconButton` — the brief lists this as its own requirement, separate from reordering, so it needs its own explicit tap/swipe target, not just a reaction to some other action. A brief "Removed RELIANCE — Undo" snackbar is a nice touch if time permits, not required.
   - Stock picker (bottom sheet) listing the fixed 10 symbols, disabling ones already in the current watchlist.
   - Empty state widget (per-watchlist, and a separate one for "no watchlists exist yet").
   - Tap row → `Navigator.push` to Buy/Sell ticket, passing the symbol to pre-fill.
   - Destructive actions (delete watchlist) get a confirm dialog — cheap to add, avoids an accidental data-loss story in the video.
4. **Persistence wiring**
   - **Every mutation persists**, not just reorder: create, rename, delete, add stock, remove stock all write to the `watchlists` box immediately on the action (they're infrequent, discrete user actions — no reason to debounce them). Reorder is the one exception: debounce that specifically (write once on drag end, not on every drag frame) so dragging stays smooth and you're not hammering disk I/O 60 times a second.
   - This is what directly satisfies both "persist across restarts" as a requirement *and* "removed stock is gone after restart" as an expected scenario — the removal write and the restart-read are hitting the same box, so there's nothing to reconcile between them.

### Edge cases to explicitly handle
- **Reorder mid-tick** — covered structurally by symbol-based keys (§3); verify it in the video by reordering while prices are visibly updating.
- **Remove a stock** → its row (and `ValueListenableBuilder` subscription) is disposed; it should visibly stop updating and not appear after restart. Note: the underlying `ValueNotifier` in the market feed *keeps ticking* (other screens/watchlists may still reference that symbol) — removal only detaches *this* watchlist's reference to it, it doesn't touch the shared engine.
- **Same stock in two watchlists** → both bound to the same notifier instance ⇒ identical prices by construction (§3); don't build any manual sync logic here, if you find yourself writing one, the architecture is wrong.
- **Duplicate add** — decide explicitly: disallow adding a symbol already present in that watchlist (grey it out in the picker). State this as a deliberate product decision, not an oversight.
- **Empty watchlist** vs **zero watchlists** — two distinct empty states, don't conflate them.
- **Rename to empty string / whitespace-only** — validate, block, show inline error.
- **Delete the watchlist currently open** — pop back to the list screen automatically rather than leaving a dangling detail view.
- **All 10 stocks in one watchlist** — picker should show "no more stocks available" rather than an empty sheet.
- **App killed mid-drag** — since you save on drag-end (not per-frame), worst case on a hard kill is losing the very last in-flight reorder, not corrupting the stored list; acceptable and worth stating as a trade-off.

---

## 7. Feature 2 — Live Prices Mimic

### Tasks & subtasks
1. Screen with `ListView.builder` (or grid) over the fixed 10 symbols, bound to the shared `MarketDataService` singleton from §3 — never a locally-constructed instance. That engine is what makes "continuously, at a realistic rate" true: the `Timer.periodic` runs indefinitely with no stop condition, and "realistic" is the clamped-random-walk price model doing its job (small, plausible per-tick moves, not jumps) — this screen's only responsibility is rendering whatever the engine currently holds, not generating or pacing anything itself.
2. Row/cell widget: symbol, LTP, change, change%, all via `ValueListenableBuilder` on that symbol's notifier — this screen is really just "watchlist row logic minus the watchlist," reuse the row widget between Feature 1 and Feature 2 rather than duplicating it.
3. **Flash animation**: on each tick, briefly overlay/tint the row green or red based on `PriceTick.direction` (computed at the source, §3), then fade back to neutral over ~200–400ms. Implement with `TweenAnimationBuilder` keyed to the tick's timestamp so a new tick mid-fade restarts the flash rather than layering animations.
4. Debug/settings surface (even a simple constant + a slider in a debug drawer) to change tick rate live, so you can demo the stress-test scenario in your video by cranking it up on camera.
5. **Verify — don't just assume — single source of truth**: this is a standalone requirement in the brief, not just a side-effect of the architecture. Cheapest way to prove it on camera: open Live Prices and a Watchlist that contains the same symbol at the same time (split-screen, or cut between the two within a couple of seconds in the recording) and show the numbers moving in lockstep. If they ever diverge even briefly, something's constructing a second engine instance somewhere — that's the bug this check exists to catch.

### Edge cases
- **First frame before any tick has arrived** — `currentPrice(symbol)` should return a sensible seeded starting price synchronously (don't null-check-crash on first build); the mock service should be pre-seeded with the "reasonable starting prices" at construction, before `start()` even fires the first tick.
- **Stress test (50+ ticks/sec aggregate)** — because rebuilds are scoped per-row via `ValueListenableBuilder`, this should already hold up; the thing to verify (and show in the video, ideally with the Flutter DevTools performance overlay on) is that *other* rows visibly do **not** repaint when one symbol ticks. Use `RepaintBoundary` around each row so Flutter doesn't even have to consider repainting siblings.
- **Scrolling while ticks arrive** — off-screen rows built by `ListView.builder` simply aren't in the tree, so they don't rebuild at all; only re-verify that scrolling itself doesn't stutter, which it won't if row rebuilds stay cheap (a few `Text` widgets, no rebuilding of the whole `ListView`).
- **Navigate away and back** — same singleton engine (§3) means prices are current on return, not resumed-from-stale; explicitly do **not** cache a snapshot of prices in the page's own state that could go stale.
- **Direction on the very first tick** (no previous price to compare against) — default to "flat"/no flash rather than a false green/red.

---

## 8. Feature 3 — Buy/Sell Ticket

### Tasks & subtasks
1. **Domain**: `Order` entity, `PlaceOrder` use case — this is where validation logic should live (not scattered in widget code), so it's independently unit-testable. Return type: `Either<Failure, Order>` (or a hand-rolled `Result<T>` sealed class if you'd rather not pull in `dartz`) instead of throwing — each validation failure (`InsufficientBalance`, `InsufficientHoldings`, `InvalidQuantity`) is a distinct `Failure` subtype the Bloc can pattern-match on to pick the right inline error copy, rather than a generic try/catch around a thrown exception. This is a small thing to implement but it's the kind of detail that separates "validation happens to work" from "errors are a modeled part of the domain."
2. **Data**: wallet repository (balance in paise), order repository (append + read history), both Hive-backed, writes serialized via the mutex from §5. Every successful submit writes to both immediately — not batched, not debounced (unlike Watchlist's reorder-debouncing, §6) — so a hard kill one frame after the confirmation screen appears still leaves the correct balance and order recorded on next launch.
3. **Presentation**: the screen takes a **required `symbol` argument** (route parameter or constructor field) — it's a single-stock ticket, not a stock picker, so the symbol is displayed but locked/non-editable once opened; both §6 (Watchlist row tap) and §9 (Holdings row tap) navigate here passing that argument. Rest of the form: side toggle (Buy/Sell), quantity field, live LTP (via `ValueListenableBuilder` — same pattern, again), computed order value, inline validation errors, submit → confirmation screen.
4. **The Buy/Sell → Holdings bridge**: submit doesn't write a "holding" anywhere — it writes an `Order` to history (task 2) and debits/nothing-touches the wallet accordingly. The "holding is created or its average price is updated" outcome the brief describes is Holdings (§9) recomputing itself from that same order history — worth stating explicitly here rather than only in §9, since it's this feature's requirement too: the order write *is* the mechanism, there's no second write to "create a holding."

### Edge cases
- **LTP moves while the form is open** — displayed price and projected order value (`qty × LTP`) recompute live off the same notifier; don't snapshot the price once at form-open.
- **Price used for execution is the price *at the moment of submit tap*, not whatever was last rendered a frame earlier** — read `marketDataService.currentPrice(symbol)` synchronously *inside* the submit handler, not from a variable captured earlier in `build()`. This is a subtle but real race: if you capture LTP into a local at build time and a tick lands between that build and the tap, you'd execute at a stale price. Reading it fresh at submit time is the correct behavior and a good thing to explicitly narrate in the video.
- **Boundary: order value exactly equals available balance** → should succeed (`<=`, not `<`). Off-by-one here is an easy accidental fail.
- **Boundary: sell quantity exactly equals held quantity** → should succeed and zero out (→ removed in Holdings, see §9).
- **Double-tap on submit** → guarded by the repository-level mutex (§5); additionally disable the submit button for the duration of the (synchronous, in this mock-backend case, but code it as if async) submission to avoid a visibly duplicate-looking UI even before the guard kicks in.
- **Fractional / negative / zero quantity** → validate as a positive integer only (Indian equity markets don't trade fractional shares — state this as a deliberate domain assumption). Show the *first* relevant error, don't stack three inline errors for one bad input.
- **Sell more than held** → blocked with a clear message, distinct from "insufficient balance" (different failure, different copy).
- **Rounding/decimal precision** → covered by §4; specifically verify in the video that a sequence of small buys/sells never accumulates a visible ₹0.01 drift.
- **Buying a stock again after selling it down to zero** → average cost resets to the new buy price, it must not silently blend with the old (closed) position's average.
- **Same stock's ticket opened from two places at once** (Watchlist row and a Holdings row, in quick succession) → both forms read/write through the same singleton wallet/order repositories, so there's no risk of one "seeing" a stale balance the other already spent — this is the same single-source-of-truth principle as §3, just applied to money instead of prices.

---

## 9. Feature 4 — Holdings

### Tasks & subtasks
1. **Domain**: `Holding` (derived, not stored — §5), computed from order history: for each symbol, running qty and weighted-average cost across all orders for that symbol.
2. **Presentation**: list where each row shows the six fields the brief specifies — **symbol, quantity, avg cost, LTP, current value, P&L (₹ and %)** — sortable (P&L / symbol / current value, default P&L descending), aggregate header (total invested, current value, total P&L ₹ and %), tap row → Buy/Sell ticket pre-filled (passing `symbol`, per §8's required argument), empty state.
3. **Live updates, two separate triggers, don't conflate them**:
   - *Price-driven*: each row's LTP/P&L updates unthrottled via `ValueListenableBuilder`, same pattern as everywhere else — this is what makes the numbers live.
   - *Order-driven*: the **set of holdings itself** (which symbols exist, their qty, their avg cost) only changes when a new order is written — a Buy on a new symbol, a Buy adding to an existing position, or a Sell. This needs its own reactive trigger, separate from the price-tick re-sort timer in the edge cases below: wrap the order repository's Hive box with `box.listenable()` (built into Hive) and have the Holdings Cubit rebuild its derived `List<Holding>` from scratch whenever that fires. Without this, placing an order while Holdings is already open wouldn't show up until the screen is closed and reopened — which is exactly what the "Buy appears in Holdings" and "Sell-to-zero removes it" expected scenarios are testing for.

### Edge cases
- **Sort stability under live reordering** — re-sorting the whole list on *every single tick* (up to 50/sec) is wasteful and can visibly jitter rows around under someone's finger while they're trying to tap one. Decouple this explicitly: individual row values (LTP, P&L) update unthrottled via their own notifiers (cheap, per-row), but the **list order** is recomputed on a throttled cadence (e.g., every 400–500ms via a separate `Timer.periodic`) that re-reads current values and re-sorts. This is a genuinely good interview talking point: *"the data is always current; the re-sort is throttled because re-ordering the visual list 50 times a second is not something a human eye or finger benefits from, and it's the expensive O(n log n) part."* Still correctly satisfies "when sorted by P&L, order updates as prices move," just not on every single tick.
- **A row crossing from loss to gain** — verify explicitly in the video: hold a stock near its avg cost, watch it cross zero P&L and physically reorder in the list.
- **Sell reduces qty to zero** → holding disappears from the list on the next recompute, fired immediately by the order-repository listenable from task 3 above — not the throttled price-resort timer in the bullet above this one, which only reorders an already-derived list and wouldn't remove anything on its own. Since holdings are derived, disappearance is automatic once the recompute runs — no explicit "delete holding" code path needed, which is itself worth mentioning as a benefit of the derived-state design.
- **Aggregate summary always equals the sum of rows** — because it's computed from the *same* underlying holdings list on every recompute (not maintained as a separately incremented running total), it cannot drift out of sync with the rows. State explicitly: no separate "totalPnl" field being incremented/decremented anywhere — it's `holdings.fold(...)`, always freshly derived.
- **All 10 stocks held, scrolling + ticking simultaneously** — same `RepaintBoundary`-per-row + throttled-resort combination as above should hold up; this is the scenario to run with DevTools' performance overlay visible in the video.
- **Restart with existing holdings** — recompute from persisted order history at boot, then immediately bind to *live* current prices (not whatever P&L was last computed before the app closed) — don't persist and restore a stale P&L snapshot.
- **Empty state** — no orders ever placed, vs. all positions sold to zero, both land on the same empty state; no need to distinguish them in the UI.

---

## 10. Thoughtful UI for dense data

This screen family (Watchlist, Live Prices, Holdings) is fundamentally a table of numbers that never stops moving — the brief's "thoughtful UI for dense data" criterion is really asking whether you designed for that specifically, not whether the screens look nice generically.

- **Tabular figures for every numeric column.** Use `FontFeature.tabularFigures()` (or a monospace/tabular-numeral font) on price, quantity, and P&L text styles. Without it, digits have variable width in most fonts, so a price ticking from ₹1,499.95 to ₹1,500.05 visibly shifts the whole column left/right on every update — distracting and unprofessional at the tick rates this app runs. This one line is easy to miss and very noticeable when it's missing.
- **One color source of truth.** Define `AppColors.gain` / `AppColors.loss` once in the theme, use them everywhere — flash animation, change%, P&L text — never a hardcoded `Colors.green` inline in a widget. Consistency here is both a code-quality signal and a UX one.
- **Don't rely on color alone.** Pair the color with a `+`/`−` sign or a small up/down arrow glyph on change% and P&L, so the direction is legible without color vision — a real accessibility gap in a lot of trading-app clones.
- **Right-align every numeric column, left-align symbol/name.** Standard financial-table convention — it's what lets a human's eye compare magnitudes down a column at a glance. Don't center-align numbers.
- **Row information hierarchy**: symbol bold/prominent, LTP secondary, change/change% tertiary but still legible at a glance — not all four fields fighting for the same visual weight.
- **Density over decoration**: compact row height, minimal padding, thin/no dividers. This is meant to read like a trading terminal, not a card-based social feed — resist the instinct to add whitespace and shadows to "make it feel nicer," it works against the actual data density here.
- **Subtle flash, not a strobe.** At 5+ ticks/sec across 10 rows, a full-saturation flash on every tick reads as visual noise. Keep the flash a short (~200ms), low-opacity tint rather than a jarring color flood — calm at high tick rates is itself a design decision worth calling out.
- **First-class loading/empty/error states**, not afterthoughts — a shimmer skeleton on first load (matching the row layout, not a generic spinner) reads far more intentional than a blank screen for the ~1 second before the first tick lands.
- **Dark theme as the default, not an extra.** Zerodha Kite, Groww, and Upstox all default to dark for exactly this reason — reduced eye strain scanning dense, high-contrast numeric data over a trading session. Defaulting to dark (or at minimum being properly dark-mode-aware) is a small, cheap signal that you understood the domain, not just the ticket list.
- **Accessibility on dense rows**: wrap each row in a `Semantics` widget with a composed label ("RELIANCE, 1,499 rupees 95 paise, up 2.1 percent") so a screen reader gets the same information a sighted user gets from three separate text widgets and a color.

---

## 11. Day-by-day execution plan (3 days)

**Day 1 (Fri 31 Jul) — Foundation.** This is the highest-risk day; everything else depends on it being right.
- Project scaffold, folder structure, DI setup.
- `market_feed`: models, `MockMarketDataService`, per-symbol `ValueNotifier`s, configurable tick rate, seeded starting prices, clamped random walk. Write it, then genuinely stress-test it standalone (a debug screen printing tick counts/sec) before building any UI on top of it.
- Feature 2 (Live Prices) — build this first among the four *screens*, because it's the thinnest possible consumer of the engine and will immediately surface any design flaw in §3 before you've built three other screens on the same flawed foundation.
- `Money` type + formatting.

**Day 2 (Sat 1 Aug) — Watchlist + Trade Ticket.**
- Feature 1 end-to-end including persistence and reorder.
- Feature 3 end-to-end including the wallet mutex, validation use case, and unit tests for the validation logic specifically (cheap to test, high value to demonstrate).

**Day 3 (Sun 2 Aug) — Holdings + hardening.**
- Feature 4 end-to-end including throttled sort.
- Full pass over every "Expected scenario" bullet in the original brief, feature by feature — literally check them off.
- `flutter analyze` clean, remove dead code, tidy commit history if it's messy (see §13).
- Widget/bloc tests for at least the critical paths (§12).

**Monday morning (3 Aug) — buffer, not a build day.**
- Record the Loom walkthrough (script it against the "Expected scenarios," see §13).
- Write the README.
- Fresh-clone the repo into a clean folder and run `flutter pub get && flutter run` exactly as a reviewer would, before submitting — catching a missing-file or platform-specific bug yourself beats a reviewer catching it.

---

## 12. Testing checklist (don't skip — "clean code" is graded partly by whether tests exist)

- **Unit**: `PlaceOrder` use case — balance check, holdings-qty check, boundary equalities, weighted-average-cost math, quantity validation (zero/negative/fractional).
- **Unit**: money formatting / arithmetic on the `Money` type.
- **Unit**: mock price engine — clamping never produces ≤0, direction computed correctly, seeded start prices present before first tick.
- **Bloc/Cubit tests** (`bloc_test`): watchlist reorder emits correct new order; ticket submit emits validation-error vs success states correctly for each edge case above.
- **Widget test**: at least one — e.g., empty state renders when watchlist is empty; row flashes the right color for an up-tick.
- You don't need exhaustive coverage in 3 days — a focused set of tests around the *money* and *validation* logic (the parts a reviewer can't fully verify just by watching a video) is the highest-value use of testing time.

---

## 13. README & submission checklist

### Submission logistics — don't lose points to something this avoidable
- **Repo visibility**: the brief asks for a *public* GitHub repo — this is a one-click toggle in repo settings that's trivial to forget if you've been developing in a private repo all along. Check it explicitly before submitting, don't assume.
- **Flutter stable channel**: run `flutter channel stable && flutter upgrade` before you start, and state the exact version you built against in the README (`flutter --version` output, one line) — if a reviewer's local Flutter is meaningfully older, this tells them what to install rather than leaving them guessing why a build fails.
- **The "no extra setup" requirement is a real constraint, not a formality**: it means literally `flutter pub get && flutter run` on a machine that has never seen this repo before. The specific way this breaks: any generated code (Hive type adapters via `build_runner`, `injectable`'s DI registration) that isn't committed to the repo won't exist on a fresh clone, and the app fails to compile. Either avoid codegen entirely (recommended — see the hand-written `TypeAdapter` note in §1), or if you do use it, run `dart run build_runner build --delete-conflicting-outputs` one final time before your last commit and make sure the generated `.g.dart` files are *not* in `.gitignore`. Test this by actually cloning your own repo into a throwaway folder and running the two commands cold — don't trust that it "should" work.
- **Video hosting**: don't commit a large `.mp4` directly into the git repo — it bloats clone time and git history for no benefit. Host it on Loom (or an unlisted YouTube link) and put the link at the top of the README, or attach it as a GitHub Release asset if you'd rather keep everything on GitHub. Either satisfies "attached to the submission" — just don't make the repo itself heavy.

### README content

- Run instructions: literally just `flutter pub get && flutter run` — verify this on a clean clone.
- One paragraph explaining the architecture (feature-first clean architecture + the single-source-of-truth price engine) — a reviewer skimming 30 submissions will read your README before your code.
- One short section: "Design decisions & trade-offs" — money as int-paise, Hive over Drift given the timeline, holdings derived from orders rather than stored separately, throttled re-sort. Naming your trade-offs *before* someone asks is stronger than being asked and then justifying them.
- One short section: "Known limitations & what I'd do next" — the weighted-average-cost rounding truncation, the lack of true cross-box transactions, no reconnection/staleness handling (because there's no real network here) — the same list as §14's "one more day" answer. Listing your own gaps unprompted reads as a senior habit; a reviewer finding an unstated gap themselves reads very differently.
- Video: walk through each feature, but specifically **narrate the edge cases as you trigger them** — reorder mid-tick, sell down to zero and watch the holding disappear, submit at the exact balance boundary, crank the tick-rate slider and show DevTools' performance overlay staying green. This is what turns "I built 4 features" into "I understood why this is hard."
- **Commit history**: commit incrementally, one logical unit of work per commit, using conventional-commit style messages so the history itself reads as a timeline of the plan in §11 — e.g.:
  ```
  feat(market-feed): mock price engine with per-symbol ValueNotifier
  feat(live-prices): row widget with flash animation
  feat(watchlist): CRUD, drag reorder, Hive persistence
  feat(trade-ticket): PlaceOrder use case with Either-based validation
  test(trade-ticket): balance/holdings boundary and rounding tests
  feat(holdings): derived holdings, throttled sort, aggregate summary
  fix(holdings): correct P&L sign on sell-side average cost reset
  docs: README with architecture, trade-offs, and known limitations
  ```
  Not one giant "final app" commit, and not commits like "wip" or "fix bug" with no scope — a reviewer reading your commit log should be able to reconstruct your build order without opening the diff. This directly maps to a stated grading criterion.

---

## 14. Interview cross-question bank

Organized by theme. These are written to be *your* answers about *this* codebase — say them with specifics (symbol names, the actual data structures you used), not in the abstract.

### Architecture & state management

**Q: Why clean architecture / feature-first folders for something this small?**
A: The assignment brief itself is explicit about "sensible architecture and folder structure" being graded, and the app isn't actually that small once you count four features each with their own persistence and validation logic. Feature-first folders keep the four verticals independent — I could delete the Holdings feature folder entirely and nothing else breaks, because it only depends on the shared `market_feed` and the `orders` data, never reaches sideways into another feature's internals. The one deliberate exception is `market_feed` living outside `features/`, because it's infrastructure genuinely shared by all four, not owned by one.

**Q: Why `flutter_bloc` over `Riverpod` here?**
A: Practical reason: I've shipped a comparable assignment with `flutter_bloc` + `GetIt` before, and a deadline is not the time to gamble on a stack I'm less battle-tested with. Technical reason: this app's state is naturally event/intent-driven in three of the four features (create watchlist, reorder, submit order — each is a discrete user action with a discrete outcome), which maps cleanly onto Bloc's event→state model. The one place I *didn't* reach for Bloc is the raw per-symbol price stream — I used `ValueNotifier` there instead, because Bloc/Cubit state is meant to represent meaningful UI states, and re-emitting a whole new Bloc state 50 times a second per symbol would be both semantically wrong and wasteful to rebuild against.

**Q: Why not just Provider/setState everywhere, given it's "just an assignment"?**
A: Because "correct realtime behavior under load" and "sensible architecture" are explicitly graded, and `setState` at the screen level would force whole-screen rebuilds on every tick — directly failing the "only affected cells rebuild" requirement. The architecture isn't decoration here, it's load-bearing for the actual functional requirements.

### Realtime data & performance

**Q: Walk me through what happens, end to end, when one price ticks.**
A: The engine's `Timer` fires, mutates the `PriceTick` value inside that symbol's `ValueNotifier`, which calls `notifyListeners()`. Every `ValueListenableBuilder` currently subscribed to *that specific* notifier — which is however many rows across whichever screens/watchlists currently display that symbol — rebuilds. Nothing else in the tree rebuilds, because nothing else is listening to that notifier. Each of those row rebuilds is wrapped in a `RepaintBoundary`, so Flutter doesn't propagate the repaint to sibling rows either.

**Q: Why not a single `Stream<Map<String, Price>>` for the whole feed?**
A: I could — it's a valid design — but it pushes the "who needs to rebuild" decision onto every consumer, who'd then have to diff the map themselves to avoid rebuilding on unrelated symbols. Splitting into one `ValueNotifier` per symbol moves that decision to the *source*, so every consumer gets correct, minimal rebuild behavior "for free" just by using `ValueListenableBuilder` on the right key. It also directly solves the "stale ticks on the wrong row after reorder" scenario, because the notifier is bound to the symbol, and the row widget is keyed by symbol — the two move together regardless of list position.

**Q: How would you actually verify "no dropped frames" rather than just asserting it?**
A: DevTools' Performance view / the in-app performance overlay, watching the raster and UI thread bars stay under 16ms at 60fps (or under ~8ms at 120fps on higher-refresh devices) while cranking the tick-rate constant up to the stress-test level. I'd also watch specifically for the *widget rebuild* count via `debugPrintRebuildDirtyWidgets` or an equivalent to confirm only the ticked rows' subtree is dirty, not the whole `ListView`.

**Q: At 50+ ticks/sec, why doesn't the Holdings list visibly jitter?**
A: Because I deliberately decoupled *data currency* from *visual re-sort frequency*. Every row's numbers are always current (unthrottled, per-row `ValueListenableBuilder`). The act of re-sorting the whole list, though, is throttled to roughly twice a second via a separate timer that re-reads current values and re-sorts — re-sorting a 10-item list 50 times a second buys nothing a human can perceive and is pure wasted work (and would visually jitter under someone's finger). That's a conscious trade-off between "technically most current possible" and "usable," and I'd defend the throttled version as the better product decision, not just the cheaper one.

**Q: What would break this design if the requirement changed to 500 stocks instead of 10?**
A: A `Map` of 500 `ValueNotifier`s is still fine memory-wise. What would start to hurt is the Holdings full re-sort — O(n log n) on 500 items, even throttled, is more work per tick-batch than on 10. At that scale I'd move the sort off the UI isolate (an `Isolate.run` or a `compute()` call) so the sort itself can't ever contend with frame rendering, and I'd only render the visible window (which `ListView.builder` already gives me) rather than sort-then-slice on the full list if I could instead maintain a lazily-sorted structure.

**Q: Isolates — did you need one here, and would you use one for the price engine itself?**
A: Not for the price engine itself — a `Timer` firing lightweight arithmetic 50 times a second is trivial CPU work that the main isolate's event loop handles without contention; spinning up a separate isolate would add message-passing overhead for no real benefit at this scale. Where I *would* consider an isolate is exactly the "500 stocks" scenario above — genuinely CPU-heavier work (a big sort, or if the mock feed did something more elaborate like simulating order-book depth) is where offloading from the UI isolate starts to pay for itself.

### Money & correctness

**Q: Why integers instead of `double` for money?**
A: `double` is binary floating point — it cannot represent most decimal fractions exactly (the classic `0.1 + 0.2 != 0.3` problem), and the brief explicitly calls out "math is precise, no floating-point drift visible to the user" as a graded requirement. Storing money as an integer count of paise makes every operation — addition, multiplication by an integer quantity — exact, with zero rounding error anywhere except the one deliberate, explicit integer division in the weighted-average-cost calculation, which I called out rather than hid.

**Q: Why not the `decimal` package instead of hand-rolled integer paise?**
A: `decimal` is a perfectly valid alternative and I'd be comfortable defending either. I went with plain `int` because the domain here genuinely never needs sub-paise precision or arbitrary decimal places — Indian equity prices are quoted to the paise — so a purpose-built value type over `int` gives the same correctness guarantee with zero extra dependency and (marginally) better performance, at the cost of writing a few operator overloads myself instead of importing them.

**Q: Where specifically could rounding still bite you, and how would you tighten it?**
A: The weighted-average-cost recompute on a second buy — `(oldQty*oldAvg + buyQty*buyPrice) ~/ (oldQty+buyQty)` — truncates. Over many small buys that could drift the stored average cost by a paise or two from the "true" mathematical average. The fix is to carry extra internal precision (e.g., store avg cost in ten-thousandths of a paise internally, only rounding to the nearest paise at display time), which I'd implement if this were headed to production; for the assignment I judged it out of scope for the 3-day window and said so explicitly in the README rather than leaving it as an unstated gap.

### Persistence & data integrity

**Q: Why Hive instead of SQLite/Drift, given you're dealing with money?**
A: Time-to-ship, mainly — Hive needs no schema migrations and almost no boilerplate, which matters on a 3-day deadline. The integrity risk with NoSQL key-value storage is usually multi-entity transactions; I addressed that specifically for order placement (which touches both the wallet and order-history "tables") by serializing writes through a mutex in the repository rather than relying on the datastore for atomicity. It's not as strong a guarantee as a real SQL transaction, but it's correct for this app's actual concurrency profile — a single user, one order submission at a time. If this were a multi-writer or crash-heavy environment, Drift with real transactions is where I'd go next.

**Q: Why derive Holdings from Orders instead of storing Holdings directly?**
A: Storing both means every order-placement has to keep two persisted structures in sync, and any bug or crash mid-write leaves you with holdings and order-history that disagree — with the order history usually being "more true," making the separately-stored holdings redundant and a source of drift. Deriving holdings from order history on read (cheap at this scale — a handful of orders, 10 possible symbols) means there's only one thing to persist and get right, and holdings are correct by construction, always.

**Q: What happens if the app is killed mid-order-submission?**
A: The mutex serializes the wallet-deduct and order-append as one logical step, but Hive itself doesn't give a cross-box atomic commit, so in the worst case a hard kill between those two writes could leave the wallet debited without the order recorded (or vice versa). I flagged this explicitly rather than papering over it — it's the concrete argument for a transactional store like Drift/SQLite being the correct next step if this moved beyond a take-home assignment.

### Edge cases & product judgment

**Q: How did you decide what counts as an "edge case" versus over-engineering for an assignment?**
A: I went through every line under the brief's "Expected scenarios" for each feature and treated those as a literal spec — those are the reviewer's actual test cases, not decoration. Beyond that, I added a small number of edge cases that follow directly from the architecture I chose (e.g., "what happens on the very first tick before any previous price exists to compare direction against") rather than inventing an open-ended list — the goal was covering what's actually reachable in this app, not padding a list.

**Q: If you had one more day, what would you add?**
A: In priority order: (1) the extra-precision fix for weighted-average-cost rounding, (2) a Drift-backed transactional rewrite of the wallet/order repository, (3) golden tests for the flash animation and row layouts, (4) app-lifecycle-aware pausing of the tick engine when backgrounded, for battery. I'd say this unprompted in the video too — it shows the gaps were seen and prioritized, not missed.

### Seniority & judgment

**Q: How would you swap the mock feed for a real backend without touching Watchlist, Live Prices, Trade Ticket, or Holdings?**
A: Every feature is written against the `MarketDataService` interface, injected via `GetIt`, never against `MockMarketDataService` directly — that's the whole point of the abstraction. A real implementation just needs to satisfy the same contract (`priceOf(symbol)`, `currentPrice(symbol)`, `start()`, `dispose()`) internally driven by a WebSocket instead of a `Timer`, plus the reconnection/staleness/backpressure handling I called out in §3. Swap the binding in `injection.dart` and nothing above that layer changes — that's the actual test of whether the dependency inversion was real or just decorative.

**Q: How did you decide what *not* to build in three days?**
A: Anything that wasn't in the brief's "Expected scenarios" and wasn't a direct consequence of an architecture decision I'd already made got cut and written down explicitly rather than silently dropped — real cross-box transactions, golden tests, reconnection logic, extra-precision rounding. The test I used: would skipping this cause a scenario in the brief to visibly fail? If yes, it's in scope; if it's a "nice to have" that only matters at a scale or backend this assignment doesn't have, it goes in the README's known-limitations list instead of into code I wouldn't have time to test properly.

**Q: If you reviewed this code as someone else's PR, what would you comment on?**
A: Two honest ones: the mutex-based write serialization in the wallet repository is correct for this app's single-writer profile but I'd flag it in review as "this is a stopgap, not a transaction — don't copy this pattern into something with concurrent writers without revisiting it." And the weighted-average-cost integer division — I'd want a comment right on that line explaining the truncation is intentional and where the precision loss is bounded, so a future reader doesn't "fix" it into something inconsistent with how the rest of the money math works.

---

*Good luck — build the engine first, verify it standalone, then everything downstream of it gets much easier.*
