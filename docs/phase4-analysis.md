# SeqProlog Phase 4 Analysis: Performance Wall and Path Forward

## What We Built

Phase 4 added two-tier predicate indexing to SeqProlog:

1. **Functor/arity clustering** — groups clauses by predicate signature (e.g., `component/2`, `has_turbo/1`) using an association list (`PredicateIndex`)
2. **First-argument hash indexing** — within each predicate, a 256-bucket hash trie (`ArgIndex`) maps the first argument's value to matching clauses

The indexing algorithm is correct and complete:
- 41/41 tests pass (32 original + 9 new indexing tests)
- Indexed queries, variable-fallback queries, rule-based queries, and cross-predicate queries all work
- Clause ordering is preserved (important for Prolog semantics)

## Where We Hit the Wall

### 1. Seq Compiler Cannot Handle Large Fact Sets

Facts are embedded as source code. The SeqProlog compiler generates one `db-cons` call per fact, and the Seq compiler (`seqc`) processes the resulting file:

| Facts | Seq Compile Time |
|-------|-----------------|
| 1K (200 engines x 5 parts) | ~56 seconds |
| 10K (2000 engines x 5 parts) | ~3.5 hours |
| 50K+ | Not feasible |

The Seq compiler appears to have super-linear (likely O(n^2) or worse) compilation time on large source files. This makes it impossible to test or deploy at the 250K fact target.

### 2. Seq Runtime Startup Overhead

Every Seq binary pays a fixed startup cost:

| Program | Wall Clock | User Time |
|---------|-----------|-----------|
| Tiny (~10 facts) | ~375ms | ~10ms |
| 1K facts | ~480ms | ~450ms |

The ~375ms baseline exceeds the <100ms query target before any Prolog code executes. This is inherent to the Seq runtime and cannot be optimized at the application level.

### 3. No Native Data Structures

Seq lacks built-in hash maps and arrays. We implemented a 256-bucket hash trie from algebraic union types:

```
ArgIndex = AILeaf(FlatBucket) | AINode(ArgIndex, ArgIndex)
```

This works but each node operation involves:
- Pattern matching on union variants (heap-allocated)
- 8 levels of recursive descent for every lookup/insert
- Immutable rebuilding of the path on every insertion

By contrast, a native `HashMap` does the same work with a single hash computation and array index.

### 4. Stack-Based Architecture Friction

Seq's stack-based execution model made the index code extremely complex. The `ai-add-rec` function carries 5 values through 8 recursive levels with manual stack manipulation (`pick`, `roll`, `nip`). This is:
- Error-prone (multiple stack bugs during development)
- Hard to maintain
- Likely slower than register-based execution due to stack shuffling overhead

## What Carries Forward

The algorithmic work from Phase 4 translates directly to any implementation:

### Indexing Strategy
```
PredicateIndex: HashMap<"functor/arity", PredicateEntry>
PredicateEntry: {
    arg_index: HashMap<first_arg_key, Vec<Clause>>,
    var_clauses: Vec<Clause>,    // clauses with variable first arg
    all_clauses: Vec<Clause>,    // all clauses (fallback)
}
```

### Lookup Algorithm
1. Extract predicate key from goal (`parent/2`, `component/2`, etc.)
2. Find `PredicateEntry` — if not found, query fails
3. If goal has no arguments or first arg is a variable → use `all_clauses`
4. If `var_clauses` is non-empty → use `all_clauses` (preserves clause ordering)
5. Otherwise → hash first arg, look up in `arg_index`

### Test Cases
The 9 indexing test cases (`tests/prolog/test_queries.sh` tests 33-41) cover:
- Multi-predicate functor/arity clustering
- First-arg specific lookup, all solutions, no-match
- Variable first-arg fallback
- Mixed ground + variable clause handling

These test scenarios should be ported to any new implementation.

## Estimated Performance: Rust + LLVM

| Operation | Seq (measured) | Rust + LLVM (estimated) |
|-----------|---------------|------------------------|
| Program startup | ~375ms | <1ms |
| Build index (1K facts) | ~75-100ms | <1ms |
| Build index (250K facts) | untestable | ~10-25ms |
| Load 250K facts from file | N/A (compiled in) | ~20-50ms |
| Single indexed query | <5ms | <0.1ms |
| **Total: cold start + 250K query** | **not feasible** | **~50-75ms** |

The <100ms target on 250K facts is achievable in Rust because:
- Native `HashMap` provides O(1) indexing with negligible constant factor
- No runtime startup overhead
- Facts can be loaded from files at runtime (not compiled into the binary)
- LLVM-compiled unification and backtracking operate at native speed

## Conclusion

SeqProlog successfully validated the Prolog execution model — parsing, unification, backtracking, clause resolution, arithmetic, and predicate indexing all work correctly. The performance wall is entirely in the Seq toolchain (compiler scalability, runtime overhead, lack of native data structures), not in the Prolog algorithm. A Rust + LLVM implementation using the same indexing strategy should comfortably meet the 250K fact / <100ms query target.
