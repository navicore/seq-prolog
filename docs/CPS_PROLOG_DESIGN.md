# CPS-Based Prolog Solver Design

## Lessons Learned from Current Implementation

### What Works Well
1. **Tokenizer & Parser** - Clean, well-tested, handles Edinburgh syntax
2. **Term representation** - Atoms, variables, compounds, lists are solid
3. **Unification** - Correct algorithm with proper substitution handling
4. **Built-in predicates** - Arithmetic, comparison work correctly
5. **Single-solution queries** - `solve-first` works reliably

### What Broke Down
1. **Choice point stack management** - Error-prone `pick`/`roll` indices
2. **Multi-solution enumeration** - Counts proof paths, not unique answers
3. **Variable renaming** - Same name gets different IDs across head/body
4. **Recursive predicates** - Infinite loops due to choice point accumulation

### Root Cause Analysis
The fundamental issue: we built an **explicit state machine** for backtracking when we should have used **implicit control flow via continuations**.

---

## CPS Design for Prolog

### Core Insight
In CPS (Continuation-Passing Style), instead of returning values, functions take extra arguments representing "what to do next":

```
# Traditional:
solve(goal) -> Result

# CPS:
solve(goal, on_success, on_failure)
  # on_success: what to do with a solution
  # on_failure: what to do when this path fails
```

### Seq Closure Capabilities (Verified)

From patch-seq tests, Seq supports:
```seq
# Closures capture stack values
: make-adder ( Int -- Closure[Int -- Int] )
  [ add ]
;

# Deep recursion works (50,000+ levels)
: recurse-with-closure ( Int -- Int )
  dup 0 i.> if
    1 i.subtract
    dup [ drop recurse-with-closure ] call
  then
;

# Combinators with quotations
[ dup 0 > ] [ 1 subtract ] while
```

### Proposed Solver Architecture

```seq
# Success continuation: receives substitution, calls next on backtrack request
# Failure continuation: called when current path fails

# Type signatures (conceptual):
# SuccessCont = Closure[Subst, FailureCont -- ]
# FailureCont = Closure[ -- ]

: solve-goal ( Term Subst SuccessCont FailureCont ClauseDB -- )
  # Find matching clauses
  # For each clause:
  #   - Try to unify
  #   - On success: solve body with NEW failure cont that tries next clause
  #   - On failure: call failure continuation
;

: try-clauses ( Term ClauseList Subst SuccessCont FailureCont ClauseDB -- )
  over cnull? if
    # No more clauses - fail
    drop drop drop drop
    call  # call the failure continuation
  else
    # Try first clause
    over ccar  # get clause
    4 pick     # get goal
    unify-head
    dup unify-ok? if
      # Unification succeeded
      # Create new failure continuation: try remaining clauses
      3 pick ccdr  # remaining clauses
      5 pick       # goal
      5 pick       # subst (original, for retry)
      6 pick       # success cont
      6 pick       # original failure cont
      7 pick       # db
      [ try-clauses ]  # <-- THIS is the magic: closure captures all state

      # Now solve the clause body with this new failure cont
      # ... (body goals, new subst, success cont, new failure cont)
    else
      # Unification failed - try next clause immediately
      drop  # drop failed result
      ccdr  # remaining clauses
      try-clauses
    then
  then
;
```

### Key Differences from Current Design

| Aspect | Current (Choice Points) | CPS Design |
|--------|------------------------|------------|
| Backtrack state | Explicit data structure | Closure captures environment |
| Control flow | Manual stack management | Implicit via call |
| Recursion | Creates accumulating CPs | Natural recursion |
| State restoration | Manual field extraction | Automatic in closure |

### Answer Deduplication

To avoid the "infinite proof paths" problem:

```seq
: solve-with-dedup ( Goal Subst SuccessCont FailureCont DB AnswerSet -- )
  # When success cont is called:
  #   1. Extract query variable bindings
  #   2. Check if already in AnswerSet
  #   3. If new: add to set, call user's success cont
  #   4. If duplicate: call failure cont to find more
;
```

---

## Implementation Roadmap

### Phase 1: Minimal CPS Solver (1 week)
**Goal:** Prove the architecture works

1. Create `src/cps-solve.seq` with:
   - `solve-goal-cps` - single goal solver
   - `solve-goals-cps` - goal list solver
   - `try-clauses-cps` - clause iteration with closures

2. Test with simple facts:
   ```prolog
   parent(tom, mary).
   parent(tom, james).
   ?- parent(tom, X).  # Should find both
   ```

3. Test with simple rules:
   ```prolog
   grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
   ?- grandparent(tom, ann).
   ```

### Phase 2: Recursive Predicates (1 week)
**Goal:** Handle recursion without infinite loops

1. Add answer deduplication
2. Test with:
   ```prolog
   ancestor(X, Y) :- parent(X, Y).
   ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).
   ?- ancestor(tom, ann).
   ```

3. Verify finite enumeration of solutions

### Phase 3: Variable Handling (3-4 days)
**Goal:** Fix variable renaming and display

1. Implement VarMap for clause renaming (same name = same ID within clause)
2. Filter output to show only query variables
3. Display original variable names (X, Y) not IDs (0, 1)

### Phase 4: Integration (3-4 days)
**Goal:** Replace current solver

1. Update REPL to use CPS solver
2. Update compiler codegen
3. Run full test suite
4. Fix any edge cases

### Phase 5: Polish (ongoing)
- Fix REPL conjunction parsing (#9)
- Add more built-ins
- Performance optimization
- Documentation

---

## Risk Assessment

### Low Risk
- Seq closures are well-tested
- The tokenizer/parser/unification can be reused unchanged
- Architecture is proven (many Prologs use CPS internally)

### Medium Risk
- Closure allocation overhead (may need optimization for large searches)
- Debugging CPS code is harder than explicit state

### Mitigations
- Start with minimal implementation to validate approach
- Keep explicit state version as fallback
- Add tracing/debugging hooks early

---

## Decision Point

This design addresses all the fundamental issues:
1. ✓ No manual stack index management
2. ✓ Natural handling of recursion
3. ✓ State captured automatically in closures
4. ✓ Answer deduplication prevents infinite enumeration

**Recommendation:** Build Phase 1 as a proof-of-concept (2-3 days). If it handles the basic cases cleanly, proceed with full implementation.

---

## Alternative: Fix Current Implementation

If CPS feels too risky, the current implementation could be fixed by:
1. Adding answer deduplication to solve-all
2. Fixing variable renaming with VarMap
3. More careful stack index auditing

Estimated effort: Similar (2-3 weeks), but higher risk of more subtle bugs.

---

## Detailed Implementation Notes (For Context Recovery)

### Files to Create/Modify

**New files:**
- `src/cps-solve.seq` - The new CPS-based solver

**Files to keep unchanged:**
- `src/tokenizer.seq` - Working tokenizer
- `src/term.seq` - Term/Clause/Subst definitions (may add AnswerSet)
- `src/parser.seq` - Working parser
- `src/runtime/unify.seq` - Working unification

**Files to modify later (Phase 4):**
- `src/repl.seq` - Switch to CPS solver
- `src/runtime/query.seq` - Switch to CPS solver
- `src/compiler.seq` - Update codegen if needed

### Phase 1 Success Criteria

Create `src/cps-solve.seq` that passes these tests:

```prolog
% Test 1: Simple fact enumeration
parent(tom, mary).
parent(tom, james).
?- parent(tom, X).
% Expected: X = mary; X = james; false.

% Test 2: Negative query
?- parent(tom, ann).
% Expected: false.

% Test 3: Simple rule
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
parent(tom, mary).
parent(mary, ann).
?- grandparent(tom, ann).
% Expected: true (or Z = ann if queried with variable)
```

### Phase 2 Success Criteria

The recursive predicate that currently infinite-loops must terminate:

```prolog
ancestor(X, Y) :- parent(X, Y).
ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).
parent(tom, mary).
parent(mary, ann).
?- ancestor(tom, ann).
% Expected: true (finite, terminates)
% Current behavior: INFINITE LOOP
```

### Key Data Structures

```seq
# Success continuation type (conceptual)
# Takes: Subst (the solution), FailCont (to get more solutions)
# Returns: nothing (side-effects output or collects results)
type SuccessCont = Closure[Subst FailCont --]

# Failure continuation type
# Takes: nothing
# Returns: nothing (either finds another path or terminates)
type FailCont = Closure[--]

# For answer deduplication (Phase 2)
union AnswerSet {
  AnswerEmpty
  AnswerCons { bindings: Subst, rest: AnswerSet }
}
```

### Core CPS Pattern

```seq
: solve-cps ( GoalList Subst SuccessCont FailCont DB -- )
  # Base case: no goals = success
  over gnull? if
    drop drop drop  # drop goals, db, fail-cont
    # Stack: subst success-cont
    swap call       # call success-cont with subst
  else
    # Recursive case: solve first goal, then rest
    over gcar   # first goal
    2 pick gcdr # remaining goals
    # ... try matching clauses with nested continuations
  then
;
```

### Current Open GitHub Issues

- #5: Variable renaming (same name different IDs) - Fix in Phase 3
- #7: solve-all crashes - Superseded by CPS rewrite
- #8: Variable display shows IDs - Fix in Phase 3
- #9: REPL conjunction parsing - Fix in Phase 5
- #10: Recursive infinite loops - Fix in Phase 2

### Reference: Seq Closure Syntax

```seq
# Create closure capturing value from stack
42 [ dup i.* ]  # captures 42, when called: multiplies TOS by 42

# Call a closure
some-closure call

# Closure in function
: make-adder ( Int -- Closure[Int -- Int] )
  [ add ]  # captures the Int, returns closure that adds it
;

# Using closures for control flow
[ condition ] [ body ] while
[ action ] 5 times
```

### Why CPS Solves Our Problems

1. **No stack index bugs**: Closures capture state automatically
2. **Natural backtracking**: Failure = call the failure continuation
3. **Recursion works**: Each recursive call has its own captured state
4. **Answer dedup is easy**: Check before calling success continuation
