# SeqProlog Compiler Design

## Overview

SeqProlog is a **compiled Prolog** implementation. It compiles `.sprolog` source files to native executables via Seq.

**Key principle:** Facts and rules are compiled into the executable as static data structures, not loaded at runtime.

## Compilation Pipeline

```
.sprolog source
      │
      ▼
┌─────────────┐
│  seqprolog  │  (Prolog → Seq compiler)
│  compiler   │
└─────────────┘
      │
      ▼
  .seq source
      │
      ▼
┌─────────────┐
│    seqc     │  (Seq → native compiler, invoked via shell)
└─────────────┘
      │
      ▼
  executable
```

## Usage

```bash
# Compile Prolog to executable
seqprolog family.sprolog -o family

# Run the compiled program
./family
```

## What Gets Compiled

### Facts → Static Data

```prolog
% Input: family.sprolog
parent(tom, mary).
parent(tom, james).
parent(mary, ann).
```

```seq
# Output: family.seq (generated)
# Facts compiled as static clause database
: parent-clauses ( -- ClauseList )
  # Each fact is a pre-built term structure
  "tom" "mary" make-parent-fact
  "tom" "james" make-parent-fact cons
  "mary" "ann" make-parent-fact cons
;
```

### Rules → Compiled Goal Sequences

```prolog
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
```

Compiles to Seq code that:
1. Builds the rule's head pattern
2. References the body goals
3. Integrates with the runtime unification/backtracking system

### Queries → Entry Point

```prolog
?- grandparent(tom, Who).
```

Compiles to a `main` function that:
1. Initializes the clause database (static)
2. Executes the query using runtime resolution
3. Prints results

## Runtime vs Compile-Time

| Component | Compile-Time | Runtime |
|-----------|--------------|---------|
| Clause database | Built into executable | Static lookup |
| Term structures | Generated as Seq code | Exists in binary |
| Unification | Algorithm compiled in | Executes at runtime |
| Backtracking | Choice point logic compiled | State managed at runtime |
| Variable bindings | - | Created during execution |

## Architecture Components

### Compiler (seqprolog)
- `src/compiler.seq` - Main compiler driver
- `src/codegen.seq` - Seq code generation
- `src/parser.seq` - Prolog parser (existing)
- `src/tokenizer.seq` - Lexer (existing)

### Runtime Library
- `src/runtime/unify.seq` - Unification algorithm
- `src/runtime/solve.seq` - Resolution/backtracking engine
- `src/runtime/term.seq` - Term representation
- `src/runtime/subst.seq` - Substitution management

The compiler generates code that links against the runtime library.

## Invoking seqc

The seqprolog compiler shells out to seqc:

```seq
: compile-to-executable ( input-path output-path -- Bool )
  # 1. Parse .sprolog
  # 2. Generate .seq to temp file
  # 3. Shell out: seqc build temp.seq -o output-path
  # 4. Clean up temp file
  # 5. Return success/failure
;
```

No FFI linking to seqc is needed - simple process spawning is sufficient.

## Benefits of Compilation

1. **Startup time** - No parsing at runtime
2. **Optimization** - Facts can be indexed, inlined
3. **Distribution** - Single executable, no runtime interpreter needed
4. **Static analysis** - Catch undefined predicates at compile time

## Open Questions

1. Should queries be specified in the source file or as command-line args to the executable?
2. Interactive REPL mode - compile a base program, then interpret queries against it?
3. Incremental compilation for large clause databases?

## Current State

The existing code (parser, unify, solve) was built as an interpreter. To pivot to compiler:

1. Keep: tokenizer, parser, term ADTs, unification algorithm
2. Add: codegen.seq, compiler.seq
3. Restructure: solve.seq becomes runtime library
4. Remove/repurpose: repl.seq (or keep for interactive mode)
