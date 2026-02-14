# SeqProlog Roadmap

## Vision

SeqProlog compiles Prolog fact/rule systems into fast, standalone executables that serve as **deterministic knowledge bases** - a complement to LLMs for domains requiring verifiable, authoritative answers.

### Target Use Case

```bash
# Compile a maintenance knowledge base
seqprolog locomotive-maint.sprolog -o locomotive-maint

# Query from CLI (for MCP wrapper, scripts, humans)
./locomotive-maint --query "due_for_maintenance(engine_123, X)" --format json

# Output:
{"solutions": [{"X": "turbocharger"}, {"X": "air_filter"}], "exhausted": true}
```

### Design Principles

1. **Compiled, not interpreted** - Facts baked into executable, fast startup
2. **CLI-first API** - Query via args, output to stdout (MCP wraps this)
3. **JSON output** - Machine-readable for tooling, convertible to JSON-RPC
4. **Scale to 250K+ facts** - First-argument indexing for performance

---

## Phase 1: Working Queries ✅ COMPLETE

**Goal**: Compiled programs can execute queries and return results.

| Task | Description | Status |
|------|-------------|--------|
| Execute embedded queries | `?- foo(X).` in source runs at startup | Deferred |
| CLI `--query` flag | `./prog --query "foo(X)."` | ✅ Done |
| Print solutions | Human-readable output (`X = bar`) | ✅ Done |
| Wire up runtime | Connect codegen to solve.seq/unify.seq | ✅ Done |

**Known Limitations**:
- Returns first solution only (multiple solutions in Phase 2)
- Variable renaming uses counter-based approach - see [issue #5](https://github.com/navicore/seq-prolog/issues/5)

**Example**:
```bash
echo "parent(tom, mary). parent(tom, james)." > test.sprolog
just compile test.sprolog
./target/prolog-out --query "parent(tom, X)"
# Output: 0 = mary
#         .
```

---

## Phase 2: Multiple Solutions ✅ COMPLETE

**Goal**: Backtracking to enumerate all solutions.

| Task | Description | Status |
|------|-------------|--------|
| Choice points | Save/restore state for backtracking | ✅ Done |
| Solution enumeration | Return all matching substitutions | ✅ Done |
| Exhaustion detection | Know when no more solutions exist | ✅ Done |
| `--query-all` flag | Enumerate all solutions from CLI | ✅ Done |
| `--query` flag | First-solution only (safe for recursive rules) | ✅ Done |

**Implementation**: ChoiceStack-threaded solver replaces CPS. Choice points
are pushed when multiple clauses match a goal, enabling backtracking via
`solve-next`. The REPL also iterates all solutions automatically.

**Example**:
```bash
./target/prolog-out --query-all "parent(tom, X)"
# X = mary
# .
# X = james
# .
# X = ann
# .
# false.
```

---

## Phase 2.5: Operator Parsing (Current Priority)

**Goal**: Parse infix operators in `.sprolog` files and `--query` strings so
the existing arithmetic/comparison builtins are usable from compiled programs.

**Context**: The runtime already supports `is/2`, `</2`, `>/2`, `=</2`,
`>=/2`, `=:=/2`, `=\=/2`, `=/2`, and `\=/2` as builtins. However, the parser
only handles standard functor syntax (`f(x, y)`), not infix operator syntax
(`X is Y + Z`). This means compiled `.sprolog` files cannot contain rules
involving arithmetic or comparisons - a prerequisite for any real knowledge
base with numeric thresholds or computed values.

| Task | Description |
|------|-------------|
| Operator precedence table | Standard Prolog precedences (1200 down to 200) |
| Infix parsing in clauses | `X is Y + Z` parses as `is(X, +(Y, Z))` in `.sprolog` files |
| Infix parsing in queries | Same support in `--query` / `--query-all` strings |
| Comparison operators | `<`, `>`, `=<`, `>=`, `=:=`, `=\=` in clause bodies |
| Unification operators | `=`, `\=` in clause bodies |
| Arithmetic operators | `+`, `-`, `*`, `/`, `mod` as term constructors |

**Acceptance**:
```bash
# This .sprolog file should compile and work:
# threshold(engine_123, 5000).
# needs_service(E) :- threshold(E, T), T > 4000.
./target/prolog-out --query "needs_service(engine_123)"
# true.

# Arithmetic in queries:
./target/prolog-out --query "X is 2 + 3"
# X = 5
# .
```

**Scope note**: This is a parser-only change. No runtime modifications needed -
all operator builtins are already implemented and tested via the REPL.

---

## Phase 3: JSON Output

**Goal**: `--format json` for MCP/tooling integration.

| Task | Description |
|------|-------------|
| Term → JSON serialization | Atoms→strings, ints→numbers, compounds→objects |
| Solution list format | `{"solutions": [...], "exhausted": bool}` |
| `--format` flag | `json`, `prolog` (default), extensible |
| Error format | `{"error": "message", "line": N}` |

**JSON Schema**:
```json
{
  "solutions": [
    {"X": "turbocharger", "Hours": 5000},
    {"X": "air_filter", "Hours": 1000}
  ],
  "exhausted": true
}
```

---

## Phase 4: Performance (250K Facts)

**Goal**: Sub-second queries on 250K+ fact databases.

| Task | Description |
|------|-------------|
| First-argument indexing | Hash lookup on first arg of each predicate |
| Clause clustering | Group clauses by functor/arity |
| Benchmark suite | Measure query time vs fact count |
| Memory optimization | Efficient term representation |

**Target**: <100ms for indexed lookups on 250K facts.

---

## Phase 5: Negation & Advanced Features

| Task | Description |
|------|-------------|
| Negation-as-failure | `\+ goal` succeeds if goal fails |
| Cut (`!`) | Prune choice points |
| List predicates | `member`, `append`, `length`, `findall` |
| Arithmetic enhancements | Additional operators, floats (parsing done in Phase 2.5) |

---

## Phase 6: Developer Experience

| Task | Description |
|------|-------------|
| Better error messages | Line numbers, context |
| `--explain` mode | Show resolution steps |
| `--stats` mode | Query time, choice points explored |
| REPL improvements | History, tab completion |

---

## Non-Goals (For Now)

- **Built-in MCP server** - External wrapper is simpler, more flexible
- **Dynamic assert/retract** - Compiled = static facts
- **Modules** - Single-file compilation for now
- **Constraint solving** - Pure Prolog first

---

## Architecture Notes

### Query Flow (Phase 1-3)
```
CLI args
    │
    ▼
┌─────────────┐
│ Parse query │
└─────────────┘
    │
    ▼
┌─────────────┐     ┌─────────────┐
│   Solve     │◀───▶│   Unify     │
└─────────────┘     └─────────────┘
    │
    ▼
┌─────────────┐
│  Format     │──▶ JSON / Prolog / etc.
└─────────────┘
```

### Indexing Strategy (Phase 4)
```
component(engine_123, turbocharger).
component(engine_123, air_filter).
component(engine_456, turbocharger).

Compiled index:
  component/2:
    engine_123 → [clause_0, clause_1]
    engine_456 → [clause_2]
```

---

## Success Metrics

1. **Correctness** - All queries return sound results
2. **Performance** - 250K facts, <100ms indexed query
3. **Usability** - MCP wrapper can invoke and parse output
4. **Reliability** - CI passes, release binaries work

---

## Getting Started

Current focus: **Phase 2.5 - Operator Parsing**

```bash
# Build compiler
just build

# Compile a Prolog file to executable
just compile examples/family.sprolog

# Run queries (first solution)
./target/prolog-out --query "parent(tom, mary)"     # true.
./target/prolog-out --query "parent(tom, X)"        # X = mary

# Run queries (all solutions)
./target/prolog-out --query-all "parent(tom, X)"    # X = mary, X = james, X = ann, false.

# Recursive rules
./target/prolog-out --query "grandparent(tom, ann)" # succeeds with bindings
./target/prolog-out --query "ancestor(tom, ann)"    # recursive rules work

# Run tests
just ci
```
