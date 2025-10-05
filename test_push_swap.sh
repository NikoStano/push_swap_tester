#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
L_RED='\033[1;31m'
L_GREEN='\033[1;32m'
L_YELLOW='\033[1;33m'
L_BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_case() {
    local test_name="$1"
    local expected="$2"
    shift 2
    local args="$@"
    
    echo -n "Testing: $test_name ... "
    
    # Run with valgrind to check for leaks
    local output=$(valgrind --leak-check=full --error-exitcode=1 --quiet ./push_swap $args 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo "  Expected: $expected"
        echo "  Got exit code: $exit_code"
        ((TESTS_FAILED++))
    fi
}

# Test error cases (should print "Error\n" on stderr)
test_error() {
    local test_name="$1"
    shift
    local args="$@"
    
    echo -n "Testing ERROR: $test_name ... "
    
    # Run with valgrind
    local output=$(valgrind --leak-check=full --error-exitcode=42 --quiet ./push_swap $args 2>&1 | grep -v "Error" | grep -v "valgrind")
    local program_output=$(./push_swap $args 2>&1)
    
    # Check if "Error" is in output
    if echo "$program_output" | grep -q "Error"; then
        # Check for leaks
        if [ -z "$output" ]; then
            echo -e "${GREEN}✓ PASS (Error + No leaks)${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠ PARTIAL (Error but leaks detected)${NC}"
            echo "$output"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${RED}✗ FAIL (No Error message)${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test sorting correctness
test_sort() {
    local test_name="$1"
    local numbers="$2"
    
    echo -n "Testing SORT: $test_name ... "
    
    # Generate operations
    local ops=$(./push_swap $numbers 2>/dev/null)
    
    # Count operations
    local op_count=$(echo "$ops" | wc -l)
    
    # Check with checker if available
    if [ -f "./checker" ]; then
        local checker_result=$(echo "$ops" | ./checker $numbers 2>/dev/null)
        if [ "$checker_result" = "OK" ]; then
            echo -e "${GREEN}✓ PASS (${op_count} ops)${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL (Checker: $checker_result)${NC}"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${YELLOW}⚠ SKIP (no checker)${NC} - ${op_count} ops generated"
    fi
}

echo -e "${L_BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${L_BLUE}║   PUSH_SWAP COMPREHENSIVE TEST SUITE   ║${NC}"
echo -e "${L_BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Compile
echo -e "${YELLOW}[1/6] Compiling...${NC}"
make > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Compilation push_swap failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Compilation push_swap successful${NC}"
make bonus > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Compilation checker failed!${NC}"
fi
echo -e "${GREEN}✓ Compilation checker successful${NC}"
echo ""

# ========================================
# SECTION 1: BASIC TESTS
# ========================================
echo -e "${L_BLUE}[2/6] Basic Tests${NC}"
echo "─────────────────────────────────────────"

test_case "No arguments" "success" 
test_case "Already sorted (2 3 4)" "success" 2 3 4
test_case "Reverse sorted (4 3 2)" "success" 4 3 2
test_case "Single number" "success" 42

echo ""

# ========================================
# SECTION 2: ERROR HANDLING
# ========================================
echo -e "${L_BLUE}[3/6] Error Handling Tests${NC}"
echo "─────────────────────────────────────────"

# test_error "Empty string" ""
test_error "Non-numeric" "1 two 3"
test_error "Duplicate numbers" "1 2 3 2"
test_error "Number too large" "2147483648"
test_error "Number too small" "-2147483649"
test_error "Invalid format" "1 2 3+"
test_error "Just a sign" "+"
test_error "Just a minus" "-"
# test_error "Spaces only" "   "
test_error "Multiple signs" "++5"
test_error "Multiple signs 2" "--5"
test_error "Mix valid/invalid" "1 2 abc 3"

echo ""

# ========================================
# SECTION 3: EDGE CASES
# ========================================
echo -e "${L_BLUE}[4/6] Edge Cases${NC}"
echo "─────────────────────────────────────────"

test_case "INT_MAX" "success" 2147483647
test_case "INT_MIN" "success" -2147483648
test_case "INT_MAX and INT_MIN" "success" 2147483647 -2147483648
test_case "Negative numbers" "success" -5 -2 -10 -1
test_case "Mixed pos/neg" "success" 5 -2 10 -1 0
test_case "With spaces (quoted)" "success" "1 2 3 4 5"
test_case "Negative with spaces" "success" "-1 -2 -3"

echo ""

# ========================================
# SECTION 4: SORTING CORRECTNESS
# ========================================
echo -e "${L_BLUE}[5/6] Sorting Correctness${NC}"
echo "─────────────────────────────────────────"

test_sort "Two numbers" "2 1"
test_sort "Three numbers (1)" "3 2 1"
test_sort "Three numbers (2)" "2 1 3"
test_sort "Three numbers (3)" "1 3 2"
test_sort "Five numbers" "5 4 3 2 1"
test_sort "Five numbers random" "3 5 1 4 2"

# Generate random tests
echo -n "Testing SORT: 10 random numbers (5 tests) ... "
RANDOM_PASS=0
for i in {1..5}; do
    NUMS=$(shuf -i 0-100 -n 10 | tr '\n' ' ')
    OPS=$(./push_swap $NUMS 2>/dev/null)
    if [ -f "./checker" ]; then
        RESULT=$(echo "$OPS" | ./checker $NUMS 2>/dev/null)
        if [ "$RESULT" = "OK" ]; then
            ((RANDOM_PASS++))
        fi
    fi
done
if [ $RANDOM_PASS -eq 5 ]; then
    echo -e "${GREEN}✓ PASS (5/5)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL ($RANDOM_PASS/5)${NC}"
    ((TESTS_FAILED++))
fi

echo ""

# ========================================
# SECTION 5: PERFORMANCE TESTS
# ========================================
echo -e "${L_BLUE}[6/6] Performance Tests${NC}"
echo "─────────────────────────────────────────"

# 100 numbers test
echo -e "100 numbers (avg of 10 runs) :"
TOTAL_OPS=0
for i in {1..10}; do
    NUMS=$(shuf -i 0-999 -n 100 | tr '\n' ' ')
    OPS=$(./push_swap $NUMS 2>/dev/null | wc -l)
    TOTAL_OPS=$((TOTAL_OPS + OPS))
done
AVG_OPS=$((TOTAL_OPS / 10))

if [ $AVG_OPS -lt 700 ]; then
    echo -e "${GREEN}✓ EXCELLENT (${AVG_OPS} ops < 700)${NC}"
    ((TESTS_PASSED++))
elif [ $AVG_OPS -lt 900 ]; then
    echo -e "${YELLOW}⚠ GOOD (${AVG_OPS} ops < 900)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ POOR (${AVG_OPS} ops ≥ 900)${NC}"
    ((TESTS_FAILED++))
fi

# 500 numbers test
echo -e "500 numbers (avg of 10 runs) :"
TOTAL_OPS=0
for i in {1..10}; do
    NUMS=$(shuf -i 0-9999 -n 500 | tr '\n' ' ')
    OPS=$(./push_swap $NUMS 2>/dev/null | wc -l)
    TOTAL_OPS=$((TOTAL_OPS + OPS))
done
AVG_OPS=$((TOTAL_OPS / 10))

if [ $AVG_OPS -lt 5500 ]; then
    echo -e "${GREEN}✓ EXCELLENT (${AVG_OPS} ops < 5500)${NC}"
    ((TESTS_PASSED++))
elif [ $AVG_OPS -lt 7000 ]; then
    echo -e "${YELLOW}⚠ GOOD (${AVG_OPS} ops < 7000)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ POOR (${AVG_OPS} ops ≥ 7000)${NC}"
    ((TESTS_FAILED++))
fi

# Large test
echo -e "500 numbers (avg of 100 runs) :"
TOTAL_OPS=0
for i in {1..100}; do
    NUMS=$(shuf -i 0-9999 -n 500 | tr '\n' ' ')
    OPS=$(./push_swap $NUMS 2>/dev/null | wc -l)
    TOTAL_OPS=$((TOTAL_OPS + OPS))
done
AVG_OPS=$((TOTAL_OPS / 100))

if [ $AVG_OPS -lt 5500 ]; then
    echo -e "${GREEN}✓ EXCELLENT (${AVG_OPS} ops <= 5500)${NC}"
    ((TESTS_PASSED++))
elif [ $AVG_OPS -lt 7000 ]; then
    echo -e "${YELLOW}⚠ GOOD (${AVG_OPS} ops < 7000)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ POOR (${AVG_OPS} ops ≥ 7000)${NC}"
    ((TESTS_FAILED++))
fi

echo ""

# ========================================
# MEMORY LEAK TEST
# ========================================
echo -e "${L_BLUE}[BONUS] Memory Leak Check${NC}"
echo "─────────────────────────────────────────"

echo -n "Checking for memory leaks (100 numbers) ... "
NUMS=$(shuf -i 0-999 -n 100 | tr '\n' ' ')
LEAK_CHECK=$(valgrind --leak-check=full --error-exitcode=1 ./push_swap $NUMS 2>&1 | grep "ERROR SUMMARY")

if echo "$LEAK_CHECK" | grep -q "0 errors"; then
    echo -e "${GREEN}✓ NO LEAKS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ LEAKS DETECTED${NC}"
    echo "$LEAK_CHECK"
    ((TESTS_FAILED++))
fi

echo -n "Checking for memory leaks (500 numbers) ... "
NUMS=$(shuf -i 0-999 -n 500 | tr '\n' ' ')
LEAK_CHECK=$(valgrind --leak-check=full --error-exitcode=1 ./push_swap $NUMS 2>&1 | grep "ERROR SUMMARY")

if echo "$LEAK_CHECK" | grep -q "0 errors"; then
    echo -e "${GREEN}✓ NO LEAKS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ LEAKS DETECTED${NC}"
    echo "$LEAK_CHECK"
    ((TESTS_FAILED++))
fi

echo ""

# ========================================
# SUMMARY
# ========================================
echo -e "${L_BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${L_BLUE}║            TEST SUMMARY                ║${NC}"
echo -e "${L_BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "Total tests: $((TESTS_PASSED + TESTS_FAILED))"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${L_GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${L_GREEN}║      🎉 ALL TESTS PASSED! 🎉           ║${NC}"
    echo -e "${L_GREEN}╚════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${L_RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${L_RED}║     ⚠️  SOME TESTS FAILED  ⚠️         ║${NC}"
    echo -e "${L_RED}╚════════════════════════════════════════╝${NC}"
    exit 1
fi
