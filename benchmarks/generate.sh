#!/bin/bash
# Generate benchmark .sprolog files at various sizes
# Pattern: component(engine_N, part_M). with ~5 parts per engine

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PARTS=("piston" "crankshaft" "valve" "camshaft" "turbocharger")

generate_file() {
    local num_engines="$1"
    local outfile="$2"
    local total=$((num_engines * ${#PARTS[@]}))

    echo "Generating $outfile ($total facts, $num_engines engines x ${#PARTS[@]} parts)..."

    {
        echo "% Benchmark: $total facts ($num_engines engines x ${#PARTS[@]} parts)"
        echo ""
        for ((i = 1; i <= num_engines; i++)); do
            for part in "${PARTS[@]}"; do
                echo "component(engine_$i, $part)."
            done
        done
        echo ""
        echo "% Rules for rule-based benchmarks"
        echo "has_turbo(X) :- component(X, turbocharger)."
        echo "engine_part(E, P) :- component(E, P)."
    } > "$outfile"
}

# Generate at various scales
generate_file 200      "bench_1k.sprolog"       # 1,000 facts
generate_file 2000     "bench_10k.sprolog"      # 10,000 facts
generate_file 10000    "bench_50k.sprolog"      # 50,000 facts
generate_file 20000    "bench_100k.sprolog"     # 100,000 facts
generate_file 50000    "bench_250k.sprolog"     # 250,000 facts

echo "Done. Generated benchmark files in $SCRIPT_DIR/"
ls -lh "$SCRIPT_DIR"/bench_*.sprolog
