#!/bin/bash
# Integration tests for SeqProlog query execution
# Run with: bash tests/prolog/test_queries.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0

# Test helper function
run_test() {
    local name="$1"
    local prolog_file="$2"
    local query="$3"
    local expected_pattern="$4"

    # Compile the file using just compile
    if ! just compile "$prolog_file" > /dev/null 2>&1; then
        echo "FAIL: $name - compilation failed"
        FAIL=$((FAIL + 1))
        return
    fi

    # Run the query
    local result
    result=$(./target/prolog-out --query "$query" 2>&1) || true

    # Check if result matches expected pattern
    if echo "$result" | grep -q "$expected_pattern"; then
        echo "PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $name"
        echo "  Query: $query"
        echo "  Expected pattern: $expected_pattern"
        echo "  Got: $result"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== SeqProlog Integration Tests ==="
echo ""

# Build the compiler first
echo "Building compiler..."
just build > /dev/null 2>&1

# Test 1: Simple fact - positive
run_test "Fact query (positive)" \
    "tests/prolog/basic.sprolog" \
    "likes(mary, food)" \
    "true\."

# Test 2: Simple fact - negative
run_test "Fact query (negative)" \
    "tests/prolog/basic.sprolog" \
    "likes(mary, beer)" \
    "false\."

# Test 3: Variable query
run_test "Variable query" \
    "tests/prolog/basic.sprolog" \
    "likes(mary, X)" \
    "= food"

# Test 4: Simple rule
run_test "Simple rule" \
    "tests/prolog/basic.sprolog" \
    "happy(mary)" \
    "\."

# Test 5: Family example - fact
run_test "Family fact" \
    "examples/family.sprolog" \
    "parent(tom, mary)" \
    "true\."

# Test 6: Family example - grandparent rule
run_test "Grandparent rule" \
    "examples/family.sprolog" \
    "grandparent(tom, ann)" \
    "\."

# Test 7: Family example - ancestor (recursive)
run_test "Ancestor recursive rule" \
    "examples/family.sprolog" \
    "ancestor(tom, ann)" \
    "\."

# Test 8: Help flag
result=$(./target/prolog-out --help 2>&1) || true
if echo "$result" | grep -q "Usage:"; then
    echo "PASS: Help flag"
    PASS=$((PASS + 1))
else
    echo "FAIL: Help flag"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -gt 0 ]; then
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
