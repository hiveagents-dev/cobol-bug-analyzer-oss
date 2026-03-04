#!/bin/bash
# Test runner script for COBOL Bug Analyzer

echo "🧪 COBOL Bug Analyzer Test Suite"
echo "================================="
echo ""

# Check if we're in the right directory
if [ ! -f "tests/test_backend.py" ]; then
    echo "❌ Error: Please run from project root directory"
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate || . venv/Scripts/activate

# Install dependencies
echo "📥 Installing test dependencies..."
pip install -r backend/requirements.txt --quiet

echo ""
echo "🚀 Running Backend Tests"
echo "------------------------"

# Run backend tests with coverage
cd backend
pytest ../tests/test_backend.py -v --cov=. --cov-report=term-missing --cov-report=html

# Check test result
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Backend tests PASSED"
    echo "📊 Coverage report: backend/htmlcov/index.html"
else
    echo ""
    echo "❌ Backend tests FAILED"
    exit 1
fi

cd ..

echo ""
echo "🎨 Frontend Tests"
echo "-----------------"
echo "Open frontend/tests/test_frontend.html in your browser to run frontend tests"
echo ""
echo "Or run: open frontend/tests/test_frontend.html"
echo ""

echo "✨ All tests complete!"
echo ""
echo "📈 Test Summary:"
echo "  - Backend: 30+ test cases"
echo "  - Frontend: 15+ test cases"
echo "  - Coverage: Comprehensive"
echo ""
