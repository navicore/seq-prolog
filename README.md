# SeqProlog

A **Prolog interpreter** written in [Seq](https://github.com/navicore/patch-seq), a concatenative stack-based programming language.

## Status: Working Interpreter

The interpreter is functional with:
- Full Edinburgh Prolog syntax parsing
- Unification with occurs check
- Fact and rule resolution
- Built-in predicates for unification and arithmetic

### What Works

- **Tokenizer**: Full Edinburgh Prolog syntax lexing
- **Parser**: Recursive descent parser for facts, rules, queries, lists
- **Unification**: Robinson's algorithm with occurs check
- **Solver**: First-solution resolution engine
- **Built-ins**: `true`, `fail`, `=`, `\=`, `is`, `<`, `>`, `=<`, `>=`, `=:=`, `=\=`
- **REPL**: Interactive query execution

### Coming Soon

- **Multiple solutions**: Weave-based backtracking using Seq's generator support
- **List predicates**: `append`, `member`, `length`, `reverse`

## Installation

### Prerequisites

- [Seq compiler](https://github.com/navicore/patch-seq) (`seqc`) on PATH
- [just](https://github.com/casey/just) command runner

### Build

```bash
just build
```

## Usage

```bash
# Interactive REPL
./target/seqprolog

# Load a file and start REPL
./target/seqprolog examples/family.sprolog

# Parse-only mode (show AST)
./target/seqprolog --parse examples/family.sprolog
```

### Example Session

```
SeqProlog 0.1.0
Enter Prolog clauses or queries. Type 'halt.' to exit.

?- parent(tom, mary).
Clause added.
?- parent(tom, james).
Clause added.
?- parent(mary, ann).
Clause added.
?- grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
Clause added.
?- parent(tom, mary).
true.
?- parent(tom, ann).
false.
?- grandparent(tom, ann).
true.
?- 3 < 5.
true.
?- X is 2 + 3.
0 = 5
?- halt.
Goodbye!
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
?- X is 3 + 4 * 2.
?- 5 > 3.
?- X is 10 mod 3.
```

## Project Structure

```
seq-prolog/
├── src/
│   ├── term.seq         # Prolog terms and ADTs
│   ├── tokenizer.seq    # Lexer for Prolog syntax
│   ├── parser.seq       # Recursive descent parser
│   ├── unify.seq        # Unification algorithm
│   ├── solve.seq        # Resolution engine
│   ├── builtins.seq     # Built-in predicates
│   ├── repl.seq         # CLI/REPL
│   └── version.seq      # Version info
├── examples/            # Example Prolog programs
├── tests/               # Test files
├── justfile             # Build system
└── README.md
```

## Architecture

SeqProlog uses a traditional Prolog architecture:

1. **Parsing**: Edinburgh syntax → AST (terms, clauses)
2. **Unification**: Robinson's algorithm with substitution threading
3. **Resolution**: Depth-first search through clause database
4. **Backtracking**: Currently first-solution only; weave-based multiple solutions planned

### Future: Weave-based Backtracking

Seq's generator support (weaves) will enable elegant backtracking:

```seq
# Each predicate with multiple solutions becomes a weave
: parent-query ( Ctx Args -- | Yield Subst )
  # Try each matching clause
  # Yield solutions on success
  # Return naturally when exhausted
;
```

## Built-in Predicates

| Predicate | Description |
|-----------|-------------|
| `true` | Always succeeds |
| `fail` | Always fails |
| `X = Y` | Unify X and Y |
| `X \= Y` | Succeed if X and Y don't unify |
| `X is Expr` | Evaluate Expr, unify with X |
| `X < Y` | Arithmetic less than |
| `X > Y` | Arithmetic greater than |
| `X =< Y` | Arithmetic less or equal |
| `X >= Y` | Arithmetic greater or equal |
| `X =:= Y` | Arithmetic equality |
| `X =\= Y` | Arithmetic inequality |

## Related Projects

- [patch-seq](https://github.com/navicore/patch-seq) - The Seq language
- [seq-lisp](https://github.com/navicore/seq-lisp) - A Lisp interpreter in Seq

## License

MIT
