#!/bin/bash
# Run SeqProlog benchmarks - measures query time for indexed lookups
# Usage: bash benchmarks/run.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== SeqProlog Performance Benchmarks ==="
echo ""

# Build compiler if needed
echo "Building compiler..."
just build > /dev/null 2>&1

# Generate benchmark files if not present
if [ ! -f "$SCRIPT_DIR/bench_1k.sprolog" ]; then
    echo "Generating benchmark data..."
    bash "$SCRIPT_DIR/generate.sh"
    echo ""
fi

# Time a query, returning milliseconds
time_query() {
    local label="$1"
    local file="$2"
    local query="$3"
    local flag="${4:---query}"

    # Compile
    if ! just compile "$file" > /dev/null 2>&1; then
        echo "  $label: COMPILE FAILED"
        return
    fi

    # Run and time (3 trials, report best)
    local best=""
    for trial in 1 2 3; do
        local start
        start=$(python3 -c 'import time; print(int(time.time()*1000))')
        ./target/prolog-out "$flag" "$query" > /dev/null 2>&1 || true
        local end
        end=$(python3 -c 'import time; print(int(time.time()*1000))')
        local elapsed=$((end - start))
        if [ -z "$best" ] || [ "$elapsed" -lt "$best" ]; then
            best=$elapsed
        fi
    done
    printf "  %-45s %6d ms\n" "$label" "$best"
}

# Run benchmarks at each scale
for size in 1k 10k 50k 100k 250k; do
    file="$SCRIPT_DIR/bench_${size}.sprolog"
    if [ ! -f "$file" ]; then
        echo "Skipping $size (file not found)"
        continue
    fi

    echo "--- $size facts ---"

    # Compilation time
    start=$(python3 -c 'import time; print(int(time.time()*1000))')
    just compile "$file" > /dev/null 2>&1
    end=$(python3 -c 'import time; print(int(time.time()*1000))')
    printf "  %-45s %6d ms\n" "Compile" $((end - start))

    # Indexed query: specific engine (first-arg index hit)
    time_query "Query: component(engine_1, X) [indexed]" "$file" "component(engine_1, X)"

    # Indexed query-all: all parts for one engine
    time_query "Query-all: component(engine_1, X) [indexed]" "$file" "component(engine_1, X)" "--query-all"

    # Rule-based query with indexed lookup
    time_query "Query: has_turbo(engine_1) [rule+index]" "$file" "has_turbo(engine_1)"

    # Variable first-arg (falls back to all_clauses for that predicate)
    time_query "Query: component(X, turbocharger) [scan]" "$file" "component(X, turbocharger)"

    echo ""
done

echo "=== Benchmark Complete ==="
