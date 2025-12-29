# SeqProlog

A **compiled Prolog** implementation in [Seq](https://github.com/navicore/patch-seq), a concatenative stack-based programming language.

## Status: Foundation Complete, Compiler Pending

The tokenizer and parser are complete. The compilation backend is pending the addition of generator support to Seq.

**Tracking issue:** [patch-seq#131 - Generator support with yield_value and resume](https://github.com/navicore/patch-seq/issues/131)

### What Works Now

- **Tokenizer**: Full Edinburgh Prolog syntax lexing
- **Parser**: Recursive descent parser for facts, rules, queries, lists
- **AST**: Complete term representation with source spans
- **REPL**: Parse mode - enter Prolog and see parsed AST

### What's Coming

- **Compiler**: Prolog → Seq code generation (pending generators)
- **Runtime**: Unification and backtracking via generators
- **Execution**: Native compiled queries against fact databases

## Design Goals

1. **Compiled, not interpreted** - Prolog compiles to Seq, then to native code via LLVM
2. **Generators for backtracking** - Clean abstraction using Seq's (upcoming) generator support
3. **Static knowledge bases** - Facts compiled in for maximum performance
4. **Use case: Fact checking** - Post-LLM validation against ground truth

## Installation

### Prerequisites

- [Seq compiler](https://github.com/navicore/patch-seq) (`seqc`) on PATH
- [just](https://github.com/casey/just) command runner

### Build

```bash
just build
```

## Usage (Parse Mode)

```bash
# Interactive REPL
./target/seqprolog

# Parse a file
./target/seqprolog examples/family.sprolog
```

```
SeqProlog 0.1.0
Parse mode (compilation pending generator support)
Enter Prolog clauses or queries. Type 'halt.' to exit.

| parent(tom, mary).
Parsed clause: parent(tom, mary).
| grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
Parsed clause: grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
| ?- grandparent(tom, A).
Parsed query: ?- grandparent(tom, A)
(Execution pending compiler implementation)
```

## Prolog Syntax Supported

### Facts
```prolog
likes(mary, food).
parent(tom, mary).
```

### Rules
```prolog
mortal(X) :- human(X).
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
```

### Queries
```prolog
?- mortal(socrates).
?- parent(X, mary).
```

### Lists
```prolog
member(X, [X|_]).
member(X, [_|T]) :- member(X, T).
append([], L, L).
append([H|T], L, [H|R]) :- append(T, L, R).
```

### Arithmetic
```prolog
factorial(0, 1).
factorial(N, F) :-
    N > 0,
    N1 is N - 1,
    factorial(N1, F1),
    F is N * F1.
```

## Project Structure

```
seq-prolog/
├── src/
│   ├── term.seq         # Prolog terms and data types
│   ├── tokenizer.seq    # Lexer for Prolog syntax
│   ├── parser.seq       # Recursive descent parser
│   ├── repl.seq         # CLI/REPL (parse mode)
│   └── version.seq      # Version info
├── examples/            # Example Prolog programs
├── tests/               # Test files
├── justfile             # Build system
└── README.md
```

## Future: Compiled Architecture

Once Seq has generator support, the compilation pipeline will be:

```
Prolog source (.sprolog)
    ↓
[Parser] → AST (terms, clauses)
    ↓
[Compiler] → Seq source code
    ↓
[seqc] → Native binary via LLVM
```

Backtracking will use generators:
```seq
# Compiled query becomes a generator
: query-parent-X-mary ( -- Generator )
  [
    "tom" yield   # first solution
    "bob" yield   # second solution
    # generator ends = no more solutions
  ] make-generator
;
```

## Related Projects

- [patch-seq](https://github.com/navicore/patch-seq) - The Seq language
- [seq-lisp](https://github.com/navicore/seq-lisp) - A Lisp interpreter in Seq

## License

MIT
