# SeqProlog - A compiled Prolog implementation
#
# Compiles .sprolog files to native executables via Seq.
# Requires: seqc (the Seq compiler) on PATH

default:
    @just --list

# Build the SeqProlog compiler
build:
    @echo "Building SeqProlog compiler..."
    @mkdir -p target
    seqc build src/compiler.seq -o target/seqprolog
    @echo "Built: target/seqprolog"

# Build the interpreter (legacy, for testing)
build-repl:
    @echo "Building SeqProlog REPL (interpreter mode)..."
    @mkdir -p target
    seqc build src/repl.seq -o target/seqprolog-repl
    @echo "Built: target/seqprolog-repl"

# Run the REPL (interpreter mode)
repl: build-repl
    ./target/seqprolog-repl

# Compile a Prolog file to Seq code (output to stdout)
codegen file: build
    ./target/seqprolog {{file}}

# Compile a Prolog file to executable
compile file output="target/prolog-out": build
    #!/usr/bin/env bash
    set -euo pipefail
    # Generate Seq code to temp file in src directory (for include paths)
    temp_seq="src/.seqprolog-temp.seq"
    trap "rm -f $temp_seq" EXIT
    ./target/seqprolog {{file}} > "$temp_seq"
    # Compile the generated Seq code
    seqc build "$temp_seq" -o {{output}}
    rm -f "$temp_seq"
    echo "Compiled: {{file}} -> {{output}}"

# Compile and run a Prolog file
run file: (compile file)
    ./target/prolog-out

# Run Seq-level unit tests
test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running Seq unit tests..."
    mkdir -p target/tests
    failed=0
    for test in tests/seq/test_*.seq; do
        if [ -f "$test" ]; then
            name=$(basename "$test" .seq)
            echo -n "  $name... "
            if seqc build "$test" -o "target/tests/$name" 2>&1; then
                if "./target/tests/$name" > /dev/null 2>&1; then
                    echo "ok"
                else
                    echo "FAILED (runtime)"
                    failed=1
                fi
            else
                echo "FAILED (compile)"
                failed=1
            fi
        fi
    done
    if [ $failed -eq 1 ]; then
        echo "Some tests failed!"
        exit 1
    fi
    echo "All Seq tests passed!"

# Run Seq tests with output
test-verbose:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p target/tests
    failed=0
    for test in tests/seq/test_*.seq; do
        if [ -f "$test" ]; then
            name=$(basename "$test" .seq)
            echo "=== $name ==="
            if seqc build "$test" -o "target/tests/$name"; then
                if "./target/tests/$name"; then
                    echo "PASSED"
                else
                    echo "FAILED (runtime)"
                    failed=1
                fi
            else
                echo "FAILED (compile)"
                failed=1
            fi
            echo ""
        fi
    done
    if [ $failed -eq 1 ]; then
        echo "Some tests failed!"
        exit 1
    fi
    echo "All tests passed!"

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

# Run Prolog integration tests (codegen only)
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

# Run full compiler integration test (compile + link + run)
compile-test: build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running compiler integration tests..."
    mkdir -p target/tests
    temp_seq="src/.seqprolog-temp.seq"
    trap "rm -f $temp_seq" EXIT
    failed=0
    for test in tests/prolog/*.sprolog; do
        if [ -f "$test" ]; then
            name=$(basename "$test" .sprolog)
            echo -n "  $name... "
            # Generate Seq code
            if ./target/seqprolog "$test" > "$temp_seq" 2>&1; then
                # Compile generated Seq code
                if seqc build "$temp_seq" -o "target/tests/$name" 2>&1; then
                    # Run the compiled executable
                    if "./target/tests/$name" > /dev/null 2>&1; then
                        echo "ok"
                    else
                        echo "FAILED (runtime)"
                        failed=1
                    fi
                else
                    echo "FAILED (seqc compile)"
                    failed=1
                fi
            else
                echo "FAILED (codegen)"
                failed=1
            fi
        fi
    done
    rm -f "$temp_seq"
    if [ $failed -eq 1 ]; then
        echo "Some integration tests failed!"
        exit 1
    fi
    echo "All compiler integration tests passed!"

# Run query execution integration tests
query-test: build
    @bash tests/prolog/test_queries.sh

# Full CI: test + build + prolog-test + compile-test + query-test
ci: test build prolog-test compile-test query-test
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
