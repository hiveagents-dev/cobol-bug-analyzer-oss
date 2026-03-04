#!/bin/bash
# ==============================================================================
# COBOL Bug Analyzer - Local Test Script
# ==============================================================================
# Usage: ./scripts/test-local.sh [ollama|vertex]
#
# Runs the backend locally with the specified LLM provider.
# If no provider specified, auto-detects available providers.
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_ROOT/backend"

# Default values
PROVIDER="${1:-auto}"
FLASK_PORT="${FLASK_PORT:-5001}"  # 5001 to avoid macOS AirPlay Receiver on 5000

# ==============================================================================
# Helper Functions
# ==============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  COBOL Bug Analyzer - Local Test${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ==============================================================================
# Provider Detection
# ==============================================================================

check_ollama() {
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        # Check if xmainframe model is available
        if curl -s http://localhost:11434/api/tags | grep -q "xmainframe"; then
            return 0
        else
            print_warning "Ollama running but xmainframe model not found"
            print_info "Run: ollama pull xmainframe:latest"
            return 1
        fi
    fi
    return 1
}

check_vertex() {
    # Check if gcloud is installed and authenticated
    if command -v gcloud &> /dev/null; then
        if gcloud auth application-default print-access-token > /dev/null 2>&1; then
            return 0
        else
            print_warning "GCP not authenticated for Vertex AI"
            print_info "Run: gcloud auth application-default login"
            return 1
        fi
    fi
    return 1
}

detect_provider() {
    print_info "Auto-detecting available providers..."
    echo ""

    OLLAMA_OK=false
    VERTEX_OK=false

    if check_ollama; then
        print_success "Ollama: Available (xmainframe model ready)"
        OLLAMA_OK=true
    else
        print_warning "Ollama: Not available"
    fi

    if check_vertex; then
        print_success "Vertex AI: Available (GCP authenticated)"
        VERTEX_OK=true
    else
        print_warning "Vertex AI: Not available"
    fi

    echo ""

    # Return first available provider
    if [ "$OLLAMA_OK" = true ]; then
        echo "ollama"
    elif [ "$VERTEX_OK" = true ]; then
        echo "vertex"
    else
        echo "none"
    fi
}

# ==============================================================================
# Setup Functions
# ==============================================================================

check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check Python
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        print_error "Python not found. Please install Python 3.8+"
        exit 1
    fi
    print_success "Python found"

    # Check pip
    if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
        print_error "pip not found. Please install pip"
        exit 1
    fi
    print_success "pip found"

    # Check curl (for health checks)
    if ! command -v curl &> /dev/null; then
        print_warning "curl not found - health checks will be skipped"
    else
        print_success "curl found"
    fi

    echo ""
}

install_dependencies() {
    print_info "Checking Python dependencies..."

    cd "$BACKEND_DIR"

    # Check if requirements are installed
    if python3 -c "import flask, flask_cors, requests, dotenv, cachetools" 2>/dev/null; then
        print_success "Core dependencies already installed"
    else
        print_info "Installing dependencies..."
        pip3 install -q -r requirements.txt
        print_success "Dependencies installed"
    fi

    # For Vertex AI, check google-cloud-aiplatform
    if [ "$PROVIDER" = "vertex" ]; then
        if python3 -c "import vertexai" 2>/dev/null; then
            print_success "Vertex AI SDK already installed"
        else
            print_info "Installing Vertex AI SDK..."
            pip3 install -q google-cloud-aiplatform
            print_success "Vertex AI SDK installed"
        fi
    fi

    echo ""
}

# ==============================================================================
# Main Execution
# ==============================================================================

cleanup() {
    echo ""
    print_info "Shutting down..."
    exit 0
}

trap cleanup SIGINT SIGTERM

print_header
check_prerequisites

# Determine provider
if [ "$PROVIDER" = "auto" ]; then
    PROVIDER=$(detect_provider)

    if [ "$PROVIDER" = "none" ]; then
        print_error "No LLM provider available!"
        echo ""
        echo "To use Ollama:"
        echo "  1. Install: brew install ollama"
        echo "  2. Pull model: ollama pull xmainframe:latest"
        echo "  3. Start: ollama serve"
        echo ""
        echo "To use Vertex AI:"
        echo "  1. Install gcloud: https://cloud.google.com/sdk/docs/install"
        echo "  2. Authenticate: gcloud auth application-default login"
        echo "  3. Set project: export GCP_PROJECT_ID=your-project"
        exit 1
    fi

    print_info "Selected provider: $PROVIDER"
elif [ "$PROVIDER" = "ollama" ]; then
    if ! check_ollama; then
        print_error "Ollama not available. Start Ollama first: ollama serve"
        exit 1
    fi
elif [ "$PROVIDER" = "vertex" ]; then
    if ! check_vertex; then
        print_error "Vertex AI not available. Authenticate first: gcloud auth application-default login"
        exit 1
    fi
else
    print_error "Unknown provider: $PROVIDER"
    echo "Usage: $0 [ollama|vertex]"
    exit 1
fi

install_dependencies

# Set environment variables based on provider
cd "$BACKEND_DIR"

echo ""
echo -e "${BLUE}────────────────────────────────────────${NC}"
if [ "$PROVIDER" = "ollama" ]; then
    print_info "Starting backend with Ollama provider"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    echo "  Provider:  Ollama"
    echo "  Model:     xmainframe:latest"
    echo "  Endpoint:  http://localhost:11434"
    echo "  Backend:   http://localhost:$FLASK_PORT"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    echo ""
    print_info "Press Ctrl+C to stop"
    echo ""

    export LLM_PROVIDER=ollama
    export OLLAMA_ENDPOINT=http://localhost:11434
    export OLLAMA_MODEL=xmainframe:latest

else
    print_info "Starting backend with Vertex AI provider"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    echo "  Provider:  Vertex AI (Gemini)"
    echo "  Project:   ${GCP_PROJECT_ID:-cobol-analyzer}"
    echo "  Location:  ${GCP_LOCATION:-us-central1}"
    echo "  Model:     ${VERTEX_MODEL:-gemini-2.0-flash-001}"
    echo "  Backend:   http://localhost:$FLASK_PORT"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    echo ""
    print_info "Press Ctrl+C to stop"
    echo ""

    export LLM_PROVIDER=vertex_ai
    export GCP_PROJECT_ID="${GCP_PROJECT_ID:-cobol-analyzer}"
    export GCP_LOCATION="${GCP_LOCATION:-us-central1}"
    export VERTEX_MODEL="${VERTEX_MODEL:-gemini-2.0-flash-001}"
fi

# Run Flask on specified port (debug=False to avoid reload issues with inline script)
export FLASK_RUN_PORT="$FLASK_PORT"
export FLASK_DEBUG=0

# Set provider-specific env vars
if [ "$LLM_PROVIDER" = "ollama" ]; then
    export OLLAMA_ENDPOINT="${OLLAMA_ENDPOINT:-http://localhost:11434}"
    export OLLAMA_MODEL="${OLLAMA_MODEL:-xmainframe:latest}"
fi

python3 -m flask run --host=0.0.0.0 --port="$FLASK_PORT"
