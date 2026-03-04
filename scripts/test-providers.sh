#!/bin/bash
# ==============================================================================
# COBOL Bug Analyzer - Quick Provider Test
# ==============================================================================
# Tests that a provider is working by sending a sample COBOL analysis request.
# Assumes the backend is already running.
#
# Usage: ./scripts/test-providers.sh [ollama|vertex]
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BACKEND_URL="${BACKEND_URL:-http://localhost:5001}"

# Sample COBOL code with intentional bugs for testing
SAMPLE_COBOL='IDENTIFICATION DIVISION.
PROGRAM-ID. TEST-BUGS.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-NUM PIC 9(5).
01 WS-RESULT PIC 9(5).
01 WS-UNINIT PIC X(10).
PROCEDURE DIVISION.
    MOVE WS-UNINIT TO WS-RESULT.
    DIVIDE 10 BY 0 GIVING WS-RESULT.
    DISPLAY WS-RESULT.'

print_header() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  COBOL Bug Analyzer - Provider Test${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header

# Step 1: Health check
print_info "Testing backend health..."
HEALTH=$(curl -s "$BACKEND_URL/api/health" 2>/dev/null || echo "FAILED")

if echo "$HEALTH" | grep -q "healthy\|degraded"; then
    print_success "Backend is running"

    # Show provider info
    PROVIDER=$(echo "$HEALTH" | grep -o '"ollama_connected":\s*[^,}]*' | head -1 || echo "")
    if echo "$HEALTH" | grep -q '"ollama_connected": true'; then
        echo "  └─ Provider: Ollama"
    else
        echo "  └─ Provider: Vertex AI (or Ollama disconnected)"
    fi
else
    print_error "Backend not responding at $BACKEND_URL"
    echo ""
    echo "Start the backend first:"
    echo "  ./scripts/test-local.sh ollama"
    echo "  # or"
    echo "  ./scripts/test-local.sh vertex"
    exit 1
fi

# Step 2: Get session token
print_info "Getting session token..."
TOKEN_RESPONSE=$(curl -s -X POST "$BACKEND_URL/api/session" \
    -H "Content-Type: application/json" 2>/dev/null || echo "FAILED")

if echo "$TOKEN_RESPONSE" | grep -q '"token"'; then
    TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n 's/.*"token":\s*"\([^"]*\)".*/\1/p')
    print_success "Session token obtained"
else
    print_error "Failed to get session token"
    echo "$TOKEN_RESPONSE"
    exit 1
fi

# Step 3: Run analysis
print_info "Running COBOL analysis (this may take 1-3 minutes)..."
echo ""
echo -e "${YELLOW}Sample COBOL code being analyzed:${NC}"
echo "────────────────────────────────────────"
echo "$SAMPLE_COBOL"
echo "────────────────────────────────────────"
echo ""

ANALYSIS=$(curl -s -X POST "$BACKEND_URL/api/analyze" \
    -H "Content-Type: application/json" \
    -H "X-Session-Token: $TOKEN" \
    -d "{\"code\": $(echo "$SAMPLE_COBOL" | jq -Rs .)}" 2>/dev/null || echo "FAILED")

# Step 4: Display results
if echo "$ANALYSIS" | grep -q '"analysis_complete":\s*true'; then
    print_success "Analysis completed!"
    echo ""

    # Extract and display summary
    SUMMARY=$(echo "$ANALYSIS" | sed -n 's/.*"summary":\s*"\([^"]*\)".*/\1/p')
    echo -e "${GREEN}Summary: $SUMMARY${NC}"
    echo ""

    # Count bugs
    BUG_COUNT=$(echo "$ANALYSIS" | grep -o '"line":' | wc -l | tr -d ' ')
    echo "Bugs found: $BUG_COUNT"
    echo ""

    # Show pretty-printed results if jq is available
    if command -v jq &> /dev/null; then
        echo -e "${BLUE}Full Analysis Results:${NC}"
        echo "────────────────────────────────────────"
        echo "$ANALYSIS" | jq '.bugs[] | {line, type, severity, description}' 2>/dev/null || echo "$ANALYSIS" | jq '.'
    else
        echo "Install jq for prettier output: brew install jq"
        echo ""
        echo "$ANALYSIS"
    fi

    echo ""
    print_success "Provider test PASSED!"

elif echo "$ANALYSIS" | grep -q '"error"'; then
    print_error "Analysis failed"
    echo "$ANALYSIS" | jq '.' 2>/dev/null || echo "$ANALYSIS"
    exit 1
else
    print_error "Unexpected response"
    echo "$ANALYSIS"
    exit 1
fi
