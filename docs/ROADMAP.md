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

## Phase 1: Working Queries (Current Priority)

**Goal**: Compiled programs can execute queries and return results.

| Task | Description | Status |
|------|-------------|--------|
| Execute embedded queries | `?- foo(X).` in source runs at startup | TODO |
| CLI `--query` flag | `./prog --query "foo(X)."` | TODO |
| Print solutions | Human-readable output (`X = bar`) | TODO |
| Wire up runtime | Connect codegen to solve.seq/unify.seq | TODO |

**Acceptance**:
```bash
echo "parent(tom, mary). parent(tom, james)." > test.sprolog
echo "?- parent(tom, X)." >> test.sprolog
just compile test.sprolog
./target/prolog-out
# Output: X = mary
```

---

## Phase 2: Multiple Solutions

**Goal**: Backtracking to enumerate all solutions.

| Task | Description |
|------|-------------|
| Choice points | Save/restore state for backtracking |
| Solution enumeration | Return all matching substitutions |
| Exhaustion detection | Know when no more solutions exist |

**Acceptance**:
```bash
./locomotive-maint --query "component(engine_123, X)"
# X = turbocharger
# X = air_filter
# X = fuel_pump
# false.
```

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
| Arithmetic enhancements | More operators, floats |

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

Current focus: **Phase 1 - Working Queries**

```bash
# Build
just build

# Current state: compiles facts but queries don't execute
./target/seqprolog examples/family.sprolog > /tmp/out.seq
cat /tmp/out.seq  # Shows generated code with "TODO: execute query"
```
