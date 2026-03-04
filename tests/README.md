# Test Suite - COBOL Bug Analyzer

## Overview

Comprehensive test suite for both backend API and frontend UI components.

## Backend Tests

### Setup

```bash
cd backend
pip install -r requirements.txt
```

### Running Tests

```bash
# Run all tests
pytest tests/test_backend.py -v

# Run with coverage
pytest tests/test_backend.py --cov=backend --cov-report=html

# Run specific test class
pytest tests/test_backend.py::TestAnalyzeEndpoint -v

# Run specific test
pytest tests/test_backend.py::TestAnalyzeEndpoint::test_analyze_valid_cobol_code -v
```

### Test Coverage

The backend test suite covers:

1. **Valid Input Tests**
   - Valid COBOL code analysis
   - Complex programs with potential bugs
   - Multiple COBOL divisions

2. **Invalid Input Tests**
   - Invalid syntax handling
   - Empty code validation
   - Whitespace-only input
   - Missing fields
   - Malformed JSON

3. **Ollama Integration Tests**
   - Successful API calls (mocked)
   - Timeout handling
   - Invalid response handling

4. **Edge Cases**
   - Very long code (10,000+ lines)
   - Special characters and Unicode
   - Concurrent requests

5. **Performance Tests**
   - Response time validation
   - Load testing

## Frontend Tests

### Setup

Simply open the test file in a browser:

```bash
# Open in default browser
open frontend/tests/test_frontend.html

# Or serve with a local server
cd frontend/tests
python -m http.server 8000
# Then visit http://localhost:8000/test_frontend.html
```

### Test Coverage

The frontend test suite covers:

1. **UI Component Tests**
   - Analyze button existence
   - Code textarea presence
   - Results container
   - Loading state display

2. **API Integration Tests**
   - Endpoint configuration
   - Request payload format
   - Response handling (success/error)
   - Empty code validation

3. **User Interaction Tests**
   - Button click handlers
   - Code input changes
   - Results display
   - Loading states
   - Error messages
   - Clear/reset functionality
   - Syntax highlighting
   - Results formatting
   - Concurrent analysis prevention

### Running Frontend Tests

1. Open `frontend/tests/test_frontend.html` in a browser
2. Click "Run All Tests" button
3. View results and pass/fail status
4. Tests are fully automated and provide immediate feedback

## Test Strategy

### Test-Driven Development (TDD)

This test suite is designed to guide development:

1. **Red**: Tests fail initially (no implementation)
2. **Green**: Implement minimal code to pass tests
3. **Refactor**: Improve code while keeping tests green

### Mocking Strategy

- **Ollama API**: Fully mocked to avoid external dependencies
- **Flask app**: Lightweight mock for endpoint testing
- **Frontend**: UI component mocks for interaction testing

### Continuous Integration

Add to CI/CD pipeline:

```yaml
# Example GitHub Actions
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v2
    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: 3.9
    - name: Install dependencies
      run: |
        pip install -r backend/requirements.txt
    - name: Run tests
      run: |
        pytest tests/test_backend.py --cov=backend --cov-report=xml
    - name: Upload coverage
      uses: codecov/codecov-action@v2
```

## Expected Results

### Backend Tests

- **Total Tests**: 20+
- **Expected Pass Rate**: 100% (with proper implementation)
- **Coverage Target**: >80%

### Frontend Tests

- **Total Tests**: 15+
- **Expected Pass Rate**: 100% (with proper implementation)
- **Categories**: UI, API, Interaction

## Next Steps

1. Implement backend Flask API (`backend/app.py`)
2. Implement frontend UI (`frontend/index.html`, `frontend/app.js`)
3. Run tests to validate implementation
4. Iterate until all tests pass
5. Add integration tests for end-to-end workflows

## Troubleshooting

### Backend Tests

```bash
# If pytest not found
pip install pytest pytest-flask pytest-mock

# If import errors
export PYTHONPATH="${PYTHONPATH}:$(pwd)/backend"

# If coverage not working
pip install pytest-cov
```

### Frontend Tests

- Ensure JavaScript is enabled in browser
- Use modern browser (Chrome, Firefox, Safari, Edge)
- Check browser console for errors
- Verify API endpoint configuration

## Contact

For questions or issues with the test suite, consult:
- Backend tests: `tests/test_backend.py`
- Frontend tests: `frontend/tests/test_frontend.html`
- Configuration: `tests/pytest.ini`
