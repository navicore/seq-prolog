# SeqProlog - A Prolog interpreter written in Seq
#
# Requires: seqc (the Seq compiler) on PATH

default:
    @just --list

# Build SeqProlog
build:
    @echo "Building SeqProlog..."
    @mkdir -p target
    seqc build src/repl.seq -o target/seqprolog
    @echo "Built: target/seqprolog"

# Run the interactive REPL
repl: build
    ./target/seqprolog

# Run a Prolog file
run file: build
    ./target/seqprolog {{file}}

# Run Seq-level unit tests
test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running Seq unit tests..."
    mkdir -p target/tests
    for test in tests/seq/test_*.seq; do
        if [ -f "$test" ]; then
            name=$(basename "$test" .seq)
            echo "  $name..."
            seqc build "$test" -o "target/tests/$name" && "./target/tests/$name" > /dev/null
        fi
    done
    echo "All Seq tests passed!"

# Run Seq tests with output
test-verbose:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p target/tests
    for test in tests/seq/test_*.seq; do
        if [ -f "$test" ]; then
            name=$(basename "$test" .seq)
            echo "=== $name ==="
            seqc build "$test" -o "target/tests/$name" && "./target/tests/$name"
            echo ""
        fi
    done

# Run all examples
examples: build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running Prolog examples..."
    for example in examples/*.sprolog; do
        if [ -f "$example" ]; then
            echo "=== $(basename $example) ==="
            ./target/seqprolog "$example"
            echo ""
        fi
    done

# Clean build artifacts
clean:
    rm -rf target

# Format check (placeholder)
fmt:
    @echo "No formatter yet - contributions welcome!"

# Run Prolog integration tests
prolog-test: build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running SeqProlog Prolog tests..."
    for test in tests/prolog/*.sprolog; do
        if [ -f "$test" ]; then
            echo "  $(basename $test)..."
            ./target/seqprolog "$test" > /dev/null
        fi
    done
    echo "All Prolog tests passed!"

# Full CI: test + build + prolog-test
ci: test build prolog-test
    @echo "CI passed!"

# Safe eval - for testing expressions with bounded output
safe-eval expr: build
    #!/usr/bin/env bash
    tmp_out=$(mktemp)
    trap "rm -f $tmp_out" EXIT
    timeout 3 ./target/seqprolog /dev/stdin <<< '{{expr}}' > "$tmp_out" 2>&1 || true
    head -20 "$tmp_out"
    lines=$(wc -l < "$tmp_out")
    if [ "$lines" -gt 20 ]; then
        echo "... (truncated, $lines total lines)"
    fi

# Installation directories
PREFIX := env_var_or_default("PREFIX", env_var("HOME") + "/.local")
BINDIR := PREFIX + "/bin"
DATADIR := PREFIX + "/share/seqprolog"

# Install seqprolog
install: build
    #!/usr/bin/env bash
    set -euo pipefail

    BINDIR="{{BINDIR}}"
    DATADIR="{{DATADIR}}"

    echo "Installing SeqProlog..."
    echo "  Binary:  $BINDIR/seqprolog"
    echo "  Data:    $DATADIR/"

    mkdir -p "$BINDIR"
    mkdir -p "$DATADIR/lib"

    cp ./target/seqprolog "$BINDIR/seqprolog"
    chmod +x "$BINDIR/seqprolog"

    if [ -d "./lib" ]; then
        cp -r ./lib/* "$DATADIR/lib/"
    fi

    echo ""
    echo "Installation complete!"
    echo "Make sure $BINDIR is in your PATH."

# Uninstall seqprolog
uninstall:
    #!/usr/bin/env bash
    set -euo pipefail

    BINDIR="{{BINDIR}}"
    DATADIR="{{DATADIR}}"

    echo "Uninstalling SeqProlog..."
    rm -f "$BINDIR/seqprolog"
    rm -rf "$DATADIR"
    echo "Done."
