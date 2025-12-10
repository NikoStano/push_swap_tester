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

# Verbose mode
VERBOSE=false
if [ "$1" = "-v" ] || [ "$1" = "--verbose" ]; then
    VERBOSE=true
    shift
fi

# Test function
test_case() {
    local test_name="$1"
    local expected="$2"
    shift 2
    local args="$@"
    
    echo -n "Testing: $test_name ... "
    
    local output=$(valgrind --leak-check=full --error-exitcode=1 --quiet ./push_swap $args 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        if [ "$VERBOSE" = true ]; then
            local result=$(./push_swap $args 2>&1)
            local op_count=$(echo "$result" | wc -l)
            echo -e "  ${BLUE}→ Arguments: $args${NC}"
            echo -e "  ${BLUE}→ Operations generated: $op_count${NC}"
            if [ -n "$result" ]; then
                echo -e "  ${BLUE}→ First 3 operations:${NC}"
                echo "$result" | head -3 | sed 's/^/    /'
            fi
        fi
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo "  Expected: $expected"
        echo "  Got exit code: $exit_code"
        ((TESTS_FAILED++))
        if [ "$VERBOSE" = true ]; then
            echo -e "  ${BLUE}→ Valgrind output:${NC}"
            echo "$output" | sed 's/^/    /'
        fi
    fi
}

# Test error cases (should print "Error\n" on stderr)
test_error() {
    local test_name="$1"
    shift
    local args="$@"

    echo -n "Testing ERROR: $test_name ... "

    local program_output=$(./push_swap $args 2>&1)

    if echo "$program_output" | grep -q "Error"; then
        local valgrind_output=$(valgrind --leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=all ./push_swap $args 2>&1)

        if echo "$valgrind_output" | grep -q "All heap blocks were freed"; then
            echo -e "${GREEN}✓ PASS (Error + No leaks)${NC}"
            ((TESTS_PASSED++))
            if [ "$VERBOSE" = true ]; then
                echo -e "  ${BLUE}→ Arguments: $args${NC}"
                echo -e "  ${BLUE}→ Program output:${NC}"
                echo "$program_output" | sed 's/^/    /'
            fi
        else
            echo -e "${YELLOW}⚠ PARTIAL (Error but leaks detected)${NC}"
            ((TESTS_FAILED++))
            if [ "$VERBOSE" = true ]; then
                echo -e "  ${BLUE}→ Arguments: $args${NC}"
                echo -e "  ${RED}→ Memory leak details:${NC}"
                echo "$valgrind_output" | grep -E "(lost|reachable|LEAK SUMMARY)" | sed 's/^/    /'
            fi
        fi
    else
        echo -e "${RED}✗ FAIL (No Error message)${NC}"
        ((TESTS_FAILED++))
        if [ "$VERBOSE" = true ]; then
            echo -e "  ${BLUE}→ Arguments: $args${NC}"
            echo -e "  ${RED}→ Program output (expected 'Error'):${NC}"
            echo "$program_output" | sed 's/^/    /'
        fi
    fi
}

test_error_checker() {
    local test_name="$1"
    shift
    local args="$@"

    echo -n "Testing ERROR: $test_name ... "

    local program_output=$(./checker $args 2>&1)

    if echo "$program_output" | grep -q "Error"; then
        local valgrind_output=$(valgrind --leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=all ./checker $args 2>&1)

        if echo "$valgrind_output" | grep -q "All heap blocks were freed"; then
            echo -e "${GREEN}✓ PASS (Error + No leaks)${NC}"
            ((TESTS_PASSED++))
            if [ "$VERBOSE" = true ]; then
                echo -e "  ${BLUE}→ Checker args: $args${NC}"
                echo -e "  ${BLUE}→ Output:${NC}"
                echo "$program_output" | sed 's/^/    /'
            fi
        else
            echo -e "${YELLOW}⚠ PARTIAL (Error but leaks detected)${NC}"
            ((TESTS_FAILED++))
            if [ "$VERBOSE" = true ]; then
                echo -e "  ${BLUE}→ Checker args: $args${NC}"
                echo -e "  ${RED}→ Leak details:${NC}"
                echo "$valgrind_output" | grep -E "(lost|reachable|LEAK SUMMARY)" | sed 's/^/    /'
            fi
        fi
    else
        echo -e "${RED}✗ FAIL (No Error message)${NC}"
        ((TESTS_FAILED++))
        if [ "$VERBOSE" = true ]; then
            echo -e "  ${BLUE}→ Checker args: $args${NC}"
            echo -e "  ${RED}→ Output (expected 'Error'):${NC}"
            echo "$program_output" | sed 's/^/    /'
        fi
    fi
}

# Test sorting correctness
test_sort() {
    local test_name="$1"
    local numbers="$2"
    
    echo -n "Testing SORT: $test_name ... "

    local ops=$(./push_swap $numbers 2>/dev/null)
    local op_count=$(echo "$ops" | wc -l)

    # Check with checker if available
    if [ -f "./checker" ]; then
        local checker_result=$(echo "$ops" | ./checker $numbers 2>/dev/null)
        if [ "$checker_result" = "OK" ]; then
            echo -e "${GREEN}✓ PASS (${op_count} ops)${NC}"
            ((TESTS_PASSED++))
            if [ "$VERBOSE" = true ]; then
                echo -e "  ${BLUE}→ Numbers: $numbers${NC}"
                echo -e "  ${BLUE}→ Total operations: $op_count${NC}"
                echo -e "  ${BLUE}→ First 5 operations:${NC}"
                echo "$ops" | head -5 | sed 's/^/    /'
                if [ $op_count -gt 5 ]; then
                    echo -e "    ${BLUE}... ($((op_count - 5)) more)${NC}"
                fi
            fi
        else
            echo -e "${RED}✗ FAIL (Checker: $checker_result)${NC}"
            ((TESTS_FAILED++))
            if [ "$VERBOSE" = true ]; then
                echo -e "  ${BLUE}→ Numbers: $numbers${NC}"
                echo -e "  ${RED}→ Operations generated:${NC}"
                echo "$ops" | sed 's/^/    /'
                echo -e "  ${RED}→ Checker result: $checker_result${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ SKIP (no checker)${NC} - ${op_count} ops generated"
        if [ "$VERBOSE" = true ]; then
            echo -e "  ${BLUE}→ Numbers: $numbers${NC}"
            echo -e "  ${BLUE}→ Operations:${NC}"
            echo "$ops" | head -10 | sed 's/^/    /'
            if [ $op_count -gt 10 ]; then
                echo -e "    ${BLUE}... ($((op_count - 10)) more)${NC}"
            fi
        fi
    fi
}

echo -e "${L_BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${L_BLUE}║            PUSH_SWAP TESTER            ║${NC}"
echo -e "${L_BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}[1/10] Compiling...${NC}"
make re > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Compilation push_swap failed!${NC}"
fi
echo -e "${GREEN}✓ Compilation push_swap successful${NC}"

CHECKER_BACKUP=false
if [ -f "./checker" ]; then
    mv ./checker ./checker_backup
    CHECKER_BACKUP=true
fi

make bonus > /dev/null 2>&1
if [ -f "./checker" ]; then
    echo -e "${GREEN}✓ Compilation checker successful${NC}"
    rm -f ./checker_backup
elif [ "$CHECKER_BACKUP" = true ]; then
    mv ./checker_backup ./checker
    echo -e "${YELLOW}⚠ Using existing checker${NC}"
else
    echo -e "${RED}✗ No checker available${NC}"
fi
echo ""

# ========================================
# SECTION 2: CHECKER-SPECIFIC ERROR HANDLING
# ========================================
echo -e "${L_BLUE}[2/10] Checker Error Handling Tests${NC}"
echo "─────────────────────────────────────────"

test_error_checker "Checker: Non-numeric" "1 two 3"
test_error_checker "Checker: Duplicate numbers" "1 2 3 2"
test_error_checker "Checker: Number too large" "2147483648"
test_error_checker "Checker: Number too small" "-2147483649"
test_error_checker "Checker: Invalid format" "1 2 3+"
test_error_checker "Checker: Just a sign" "+"
test_error_checker "Checker: Just a minus" "-"
test_error_checker "Checker: Multiple signs" "++5"
test_error_checker "Checker: Multiple signs 2" "--5"
test_error_checker "Checker: Mix valid/invalid" "1 2 abc 3"
echo ""

# ========================================
# SECTION 3: BASIC TESTS
# ========================================
echo -e "${L_BLUE}[3/10] Basic Tests${NC}"
echo "─────────────────────────────────────────"

test_case "No arguments" "success" 
test_case "Already sorted (2 3 4)" "success" 2 3 4
test_case "Reverse sorted (4 3 2)" "success" 4 3 2
test_case "Single number" "success" 42

echo ""

# ========================================
# SECTION 4: ERROR HANDLING
# ========================================
echo -e "${L_BLUE}[4/10] Error Handling Tests${NC}"
echo "─────────────────────────────────────────"

test_error "Non-numeric" "1 two 3"
test_error "Duplicate numbers" "1 2 3 2"
test_error "Number too large" "2147483648"
test_error "Number too small" "-2147483649"
test_error "Invalid format" "1 2 3+"
test_error "Just a sign" "+"
test_error "Just a minus" "-"
test_error "Multiple signs" "++5"
test_error "Multiple signs 2" "--5"
test_error "Mix valid/invalid" "1 2 abc 3"
echo ""

# ========================================
# SECTION 5: EDGE CASES
# ========================================
echo -e "${L_BLUE}[5/10] Edge Cases${NC}"
echo "─────────────────────────────────────────"

test_case "INT_MAX" "success" 2147483647
test_case "INT_MIN" "success" -2147483648
test_case "INT_MAX and INT_MIN" "success" 2147483647 -2147483648
test_case "Negative numbers" "success" -5 -2 -10 -1
test_case "Mixed pos/neg" "success" 5 -2 10 -1 0
test_case "With spaces (quoted)" "success" "1 2 3 4 5"
test_case "Negative with spaces" "success" "-1 -2 -3"
test_case "Multiple spaces" "success" "1  2   3    4"
test_case "Leading spaces" "success" "  1 2 3"
test_case "Trailing spaces" "success" "1 2 3  "
test_case "Tab characters" "success" "1	2	3"
test_case "Empty string" "success" ""
test_case "Only spaces" "success" "   "

echo ""

# ========================================
# SECTION 6: OPERATIONS EFFICIENCY
# ========================================
echo -e "${L_BLUE}[6/10] Operations Efficiency (3 & 5 numbers)${NC}"
echo "─────────────────────────────────────────"

echo -n "Testing 3 numbers (should use ≤3 ops) ... "
THREE_PASS=0
for combo in "2 1 3" "3 2 1" "1 3 2" "3 1 2" "2 3 1"; do
    OPS=$(./push_swap $combo 2>/dev/null | wc -l)
    if [ $OPS -le 3 ]; then
        ((THREE_PASS++))
    fi
done
if [ $THREE_PASS -eq 5 ]; then
    echo -e "${GREEN}✓ PASS (all ≤3 ops)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL ($THREE_PASS/5 within limit)${NC}"
    ((TESTS_FAILED++))
fi

echo -n "Testing 5 numbers (should use ≤12 ops) ... "
FIVE_PASS=0
for i in {1..10}; do
    NUMS=$(shuf -i 1-5 -n 5 | tr '\n' ' ')
    OPS=$(./push_swap $NUMS 2>/dev/null | wc -l)
    if [ $OPS -le 12 ]; then
        ((FIVE_PASS++))
    fi
done
if [ $FIVE_PASS -ge 8 ]; then
    echo -e "${GREEN}✓ PASS ($FIVE_PASS/10 within limit)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL ($FIVE_PASS/10 within limit)${NC}"
    ((TESTS_FAILED++))
fi

echo ""

# ========================================
# SECTION 7: SORTING CORRECTNESS
# ========================================
echo -e "${L_BLUE}[7/10] Sorting Correctness${NC}"
echo "─────────────────────────────────────────"

test_sort "Two numbers" "2 1"
test_sort "Three numbers (1)" "3 2 1"
test_sort "Three numbers (2)" "2 1 3"
test_sort "Three numbers (3)" "1 3 2"
test_sort "Five numbers" "5 4 3 2 1"
test_sort "Five numbers random" "3 5 1 4 2"

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
# SECTION 8: Mixed Arguments Tests
# ========================================
echo -e "${L_BLUE}[8/10] Mixed Arguments Tests${NC}"
echo "─────────────────────────────────────────"

test_case "String + separate args" "success" "1 2" 3 4
test_case "Multiple strings" "success" "1 2" "3 4" "5"
test_error "String with invalid + valid" "1 abc" 2 3
test_error "Valid string + invalid arg" "1 2" abc

echo ""

# # ========================================
# # SECTION 9: PERFORMANCE TESTS
# # ========================================
# echo -e "${L_BLUE}[9/10] Performance Tests${NC}"
# echo "─────────────────────────────────────────"
# echo -e "100 numbers (avg of 10 runs) :"
# TOTAL_OPS=0
# for i in {1..10}; do
#     NUMS=$(shuf -i 0-999 -n 100 | tr '\n' ' ')
#     OPS=$(./push_swap $NUMS 2>/dev/null | wc -l)
#     TOTAL_OPS=$((TOTAL_OPS + OPS))
# done
# AVG_OPS=$((TOTAL_OPS / 10))

# if [ $AVG_OPS -lt 700 ]; then
#     echo -e "${GREEN}✓ EXCELLENT (${AVG_OPS} ops) - Grade: 5/5${NC}"
#     ((TESTS_PASSED++))
# elif [ $AVG_OPS -lt 900 ]; then
#     echo -e "${GREEN}✓ GOOD (${AVG_OPS} ops) - Grade: 4/5${NC}"
#     ((TESTS_PASSED++))
# elif [ $AVG_OPS -lt 1100 ]; then
#     echo -e "${GREEN}⚠ ACCEPTABLE (${AVG_OPS} ops) - Grade: 3/5${NC}"
#     ((TESTS_PASSED++))
# elif [ $AVG_OPS -lt 1300 ]; then
#     echo -e "${YELLOW}⚠ MINIMUM (${AVG_OPS} ops) - Grade: 2/5${NC}"
#     ((TESTS_PASSED++))
# else
#     echo -e "${YELLOW}✗ TOO SLOW (${AVG_OPS} ops) - Grade: 1/5${NC}"
#     ((TESTS_PASSED++))
# fi

# # 500 numbers test
# echo -e "500 numbers (avg of 10 runs) :"
# TOTAL_OPS=0
# for i in {1..10}; do
#     NUMS=$(shuf -i 0-999 -n 500 | tr '\n' ' ')
#     OPS=$(./push_swap $NUMS 2>/dev/null | wc -l)
#     TOTAL_OPS=$((TOTAL_OPS + OPS))
# done
# AVG_OPS=$((TOTAL_OPS / 10))

# if [ $AVG_OPS -lt 5500 ]; then
#     echo -e "${GREEN}✓ EXCELLENT (${AVG_OPS} ops)${NC}"
#     ((TESTS_PASSED++))
# elif [ $AVG_OPS -lt 7000 ]; then
#     echo -e "${GREEN}✓ GOOD (${AVG_OPS} ops)${NC}"
#     ((TESTS_PASSED++))
# elif [ $AVG_OPS -lt 8500 ]; then
#     echo -e "${GREEN}⚠ ACCEPTABLE (${AVG_OPS} ops)${NC}"
#     ((TESTS_PASSED++))
# elif [ $AVG_OPS -lt 10000 ]; then
#     echo -e "${YELLOW}⚠ MINIMUM (${AVG_OPS} ops)${NC}"
#     ((TESTS_PASSED++))
# else
#     echo -e "${YELLOW}✗ TOO SLOW (${AVG_OPS} ops)${NC}"
#     ((TESTS_PASSED++))
# fi

# # Large test
# echo -e "500 numbers (avg of 100 runs) :"
# TOTAL_OPS=0
# for i in {1..100}; do
#     NUMS=$(shuf -i 0-9999 -n 500 | tr '\n' ' ')
#     OPS=$(./push_swap $NUMS 2>/dev/null | wc -l)
#     TOTAL_OPS=$((TOTAL_OPS + OPS))
# done
# AVG_OPS=$((TOTAL_OPS / 100))

# if [ $AVG_OPS -lt 5500 ]; then
#     echo -e "${GREEN}✓ EXCELLENT (${AVG_OPS} ops) - Grade: 5/5${NC}"
#     ((TESTS_PASSED++))
# elif [ $AVG_OPS -lt 7000 ]; then
#     echo -e "${GREEN}✓ GOOD (${AVG_OPS} ops) - Grade: 4/5${NC}"
#     ((TESTS_PASSED++))
# elif [ $AVG_OPS -lt 8500 ]; then
#     echo -e "${GREEN}⚠ ACCEPTABLE (${AVG_OPS} ops) - Grade: 3/5${NC}"
#     ((TESTS_PASSED++))
# elif [ $AVG_OPS -lt 10000 ]; then
#     echo -e "${YELLOW}⚠ MINIMUM (${AVG_OPS} ops) - Grade: 2/5${NC}"
#     ((TESTS_PASSED++))
# else
#     echo -e "${YELLOW}✗ TOO SLOW (${AVG_OPS} ops) - Grade: 1/5${NC}"
#     ((TESTS_PASSED++))
# fi

# echo ""

# ========================================
# SECTION 10: MEMORY LEAK TEST
# ========================================
echo -e "${L_BLUE}[10/10] Memory Leak Check${NC}"
echo "─────────────────────────────────────────"

echo -n "Checking for memory leaks (100 numbers) ... "
NUMS=$(shuf -i 0-999 -n 100 | tr '\n' ' ')
valgrind --leak-check=full --error-exitcode=1 --quiet ./push_swap $NUMS > /dev/null 2>&1
LEAK_STATUS=$?

if [ $LEAK_STATUS -eq 0 ]; then
    echo -e "${GREEN}✓ NO LEAKS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ LEAKS DETECTED${NC}"
    if [ "$VERBOSE" = true ]; then
        valgrind --leak-check=full ./push_swap $NUMS 2>&1 | grep -E "(lost|reachable|ERROR SUMMARY)" | sed 's/^/    /'
    fi
    ((TESTS_FAILED++))
fi

echo -n "Checking for memory leaks (500 numbers) ... "
NUMS=$(shuf -i 0-999 -n 500 | tr '\n' ' ')
valgrind --leak-check=full --error-exitcode=1 --quiet ./push_swap $NUMS > /dev/null 2>&1
LEAK_STATUS=$?

if [ $LEAK_STATUS -eq 0 ]; then
    echo -e "${GREEN}✓ NO LEAKS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ LEAKS DETECTED${NC}"
    if [ "$VERBOSE" = true ]; then
        valgrind --leak-check=full ./push_swap $NUMS 2>&1 | grep -E "(lost|reachable|ERROR SUMMARY)" | sed 's/^/    /'
    fi
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

TOTAL=$((TESTS_PASSED + TESTS_FAILED))
PERCENTAGE=$((TESTS_PASSED * 100 / TOTAL))

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${L_GREEN}Success rate: ${PERCENTAGE}%${NC}"
    echo -e "${L_GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${L_GREEN}║        🎉 ALL TESTS PASSED! 🎉         ║${NC}"
    echo -e "${L_GREEN}╚════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${L_RED}Success rate: ${PERCENTAGE}%${NC}"
    echo -e "${L_RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${L_RED}║        ⚠️  SOME TESTS FAILED  ⚠️         ║${NC}"
    echo -e "${L_RED}╚════════════════════════════════════════╝${NC}"
    exit 1
fi
