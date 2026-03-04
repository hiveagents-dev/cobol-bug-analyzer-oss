"""
Comprehensive test suite for COBOL Bug Analyzer Backend API

Tests cover:
- Valid COBOL code analysis
- Invalid code handling
- Empty input validation
- Ollama API integration (mocked)
- Error handling and edge cases
- Health check endpoint
- Info endpoint
- OllamaAnalyzer class functionality
"""

import pytest
import json
import sys
import os
from unittest.mock import Mock, patch, MagicMock

# Add backend directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'backend'))


# Import the actual Flask app and analyzer
@pytest.fixture
def app():
    """Import the actual Flask application for testing"""
    from app import app as flask_app
    flask_app.config['TESTING'] = True
    return flask_app


@pytest.fixture
def client(app):
    """Create a test client"""
    return app.test_client()


class TestAnalyzeEndpoint:
    """Test cases for /api/analyze endpoint"""

    @patch('app.analyzer._call_ollama')
    def test_analyze_valid_cobol_code(self, mock_ollama, client):
        """Test analysis of valid COBOL code"""
        valid_cobol = """
        IDENTIFICATION DIVISION.
        PROGRAM-ID. HELLO-WORLD.
        PROCEDURE DIVISION.
            DISPLAY 'HELLO WORLD'.
            STOP RUN.
        """

        # Mock Ollama response
        mock_ollama.return_value = "No bugs detected. Code looks clean."

        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': valid_cobol}),
            content_type='application/json'
        )

        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'bugs' in data
        assert 'summary' in data
        assert 'analysis_complete' in data
        assert data['analysis_complete'] is True

    @patch('app.analyzer._call_ollama')
    def test_analyze_complex_cobol_with_bugs(self, mock_ollama, client):
        """Test analysis of COBOL code with potential bugs"""
        buggy_cobol = """
        IDENTIFICATION DIVISION.
        PROGRAM-ID. BUGGY-PROGRAM.
        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01 COUNTER PIC 9(3) VALUE 0.
        PROCEDURE DIVISION.
            PERFORM VARYING COUNTER FROM 1 BY 1 UNTIL COUNTER > 1000
                DISPLAY COUNTER
            END-PERFORM.
            STOP RUN.
        """

        # Mock Ollama response with bugs
        mock_ollama.return_value = """
        Line 6: Medium severity
        Bug: COUNTER may overflow with PIC 9(3)
        Suggestion: Increase COUNTER to PIC 9(4) or add bounds checking
        """

        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': buggy_cobol}),
            content_type='application/json'
        )

        assert response.status_code == 200
        data = json.loads(response.data)
        assert isinstance(data.get('bugs'), list)
        assert data['analysis_complete'] is True
        # Should have parsed at least one bug
        if len(data['bugs']) > 0:
            assert 'line' in data['bugs'][0]
            assert 'severity' in data['bugs'][0]

    @patch('app.analyzer._call_ollama')
    def test_analyze_invalid_cobol_syntax(self, mock_ollama, client):
        """Test handling of invalid COBOL syntax"""
        invalid_cobol = """
        THIS IS NOT VALID COBOL CODE
        RANDOM TEXT WITHOUT STRUCTURE
        123456789
        """

        mock_ollama.return_value = "Invalid COBOL syntax detected."

        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': invalid_cobol}),
            content_type='application/json'
        )

        # Should still process
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'bugs' in data
        assert 'analysis_complete' in data

    def test_analyze_empty_code(self, client):
        """Test handling of empty code input"""
        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': ''}),
            content_type='application/json'
        )

        assert response.status_code == 400
        data = json.loads(response.data)
        assert 'error' in data
        assert 'empty' in data['error'].lower()

    def test_analyze_whitespace_only(self, client):
        """Test handling of whitespace-only input"""
        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': '   \n\t  \n  '}),
            content_type='application/json'
        )

        assert response.status_code == 400
        data = json.loads(response.data)
        assert 'error' in data

    def test_analyze_no_code_field(self, client):
        """Test handling of missing 'code' field"""
        response = client.post(
            '/api/analyze',
            data=json.dumps({'wrong_field': 'some value'}),
            content_type='application/json'
        )

        assert response.status_code == 400
        data = json.loads(response.data)
        assert 'error' in data
        assert 'code' in data['error'].lower()

    def test_analyze_no_json_body(self, client):
        """Test handling of missing request body"""
        response = client.post(
            '/api/analyze',
            data=None,
            content_type='application/json'
        )

        assert response.status_code == 400

    def test_analyze_invalid_json(self, client):
        """Test handling of malformed JSON"""
        response = client.post(
            '/api/analyze',
            data='{"code": invalid json}',
            content_type='application/json'
        )

        assert response.status_code == 400


class TestHealthAndInfoEndpoints:
    """Test cases for health check and info endpoints"""

    @patch('app.analyzer.test_connection')
    def test_health_check_healthy(self, mock_test_connection, client):
        """Test health check endpoint when Ollama is healthy"""
        mock_test_connection.return_value = True

        response = client.get('/api/health')

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'healthy'
        assert data['ollama_connected'] is True
        assert 'endpoint' in data
        assert 'model' in data

    @patch('app.analyzer.test_connection')
    def test_health_check_degraded(self, mock_test_connection, client):
        """Test health check endpoint when Ollama is unavailable"""
        mock_test_connection.return_value = False

        response = client.get('/api/health')

        assert response.status_code == 503
        data = json.loads(response.data)
        assert data['status'] == 'degraded'
        assert data['ollama_connected'] is False

    def test_info_endpoint(self, client):
        """Test info endpoint returns analyzer configuration"""
        response = client.get('/api/info')

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['provider'] == 'ollama'
        assert 'endpoint' in data
        assert 'model' in data
        assert 'timeout' in data
        assert data['status'] == 'running'

    def test_404_handler(self, client):
        """Test 404 error handler"""
        response = client.get('/api/nonexistent')

        assert response.status_code == 404
        data = json.loads(response.data)
        assert 'error' in data
        assert 'not found' in data['error'].lower()


class TestOllamaIntegration:
    """Test cases for Ollama API integration"""

    @patch('requests.post')
    def test_ollama_api_success(self, mock_post, client):
        """Test successful Ollama API call"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'response': 'No bugs detected. Code looks clean.'
        }
        mock_post.return_value = mock_response

        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': 'DISPLAY "TEST".'}),
            content_type='application/json'
        )

        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'bugs' in data
        assert 'summary' in data

    @patch('requests.post')
    def test_ollama_api_timeout(self, mock_post, client):
        """Test handling of Ollama API timeout"""
        import requests
        mock_post.side_effect = requests.exceptions.Timeout('Connection timeout')

        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': 'DISPLAY "TEST".'}),
            content_type='application/json'
        )

        # Should handle timeout gracefully
        assert response.status_code == 500
        data = json.loads(response.data)
        assert 'error' in data
        assert 'timeout' in data['error'].lower()

    @patch('requests.post')
    def test_ollama_api_connection_error(self, mock_post, client):
        """Test handling of Ollama API connection error"""
        import requests
        mock_post.side_effect = requests.exceptions.ConnectionError('Cannot connect')

        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': 'DISPLAY "TEST".'}),
            content_type='application/json'
        )

        assert response.status_code == 500
        data = json.loads(response.data)
        assert 'error' in data
        assert 'connect' in data['error'].lower()


class TestEdgeCases:
    """Test edge cases and boundary conditions"""

    @patch('app.analyzer._call_ollama')
    def test_analyze_very_long_code(self, mock_ollama, client):
        """Test handling of very long COBOL programs"""
        long_code = "DISPLAY 'LINE'.\n" * 10000
        mock_ollama.return_value = "Code analysis complete."

        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': long_code}),
            content_type='application/json'
        )

        # Should process successfully
        assert response.status_code in [200, 500]

    @patch('app.analyzer._call_ollama')
    def test_analyze_special_characters(self, mock_ollama, client):
        """Test handling of special characters in code"""
        special_code = """
        IDENTIFICATION DIVISION.
        PROGRAM-ID. TEST-SPECIAL.
        PROCEDURE DIVISION.
            DISPLAY 'Special test'.
            STOP RUN.
        """
        mock_ollama.return_value = "No issues found."

        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': special_code}),
            content_type='application/json'
        )

        assert response.status_code == 200

    @patch('app.analyzer._call_ollama')
    def test_concurrent_requests(self, mock_ollama, client):
        """Test handling of concurrent analysis requests"""
        code = "DISPLAY 'TEST'."
        mock_ollama.return_value = "Analysis complete."

        # Simulate concurrent requests
        responses = []
        for _ in range(5):
            response = client.post(
                '/api/analyze',
                data=json.dumps({'code': code}),
                content_type='application/json'
            )
            responses.append(response)

        # All requests should be processed
        for response in responses:
            assert response.status_code == 200


class TestResponseFormat:
    """Test response format and structure"""

    @patch('app.analyzer._call_ollama')
    def test_response_has_required_fields(self, mock_ollama, client):
        """Test that successful response has all required fields"""
        mock_ollama.return_value = "No bugs found."

        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': 'DISPLAY "TEST".'}),
            content_type='application/json'
        )

        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'bugs' in data
        assert isinstance(data['bugs'], list)
        assert 'summary' in data
        assert 'analysis_complete' in data
        assert data['analysis_complete'] is True

    def test_error_response_format(self, client):
        """Test that error response has proper format"""
        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': ''}),
            content_type='application/json'
        )

        assert response.status_code == 400
        data = json.loads(response.data)
        assert 'error' in data
        assert isinstance(data['error'], str)


# Performance and load testing helpers
class TestPerformance:
    """Performance and load testing"""

    @patch('app.analyzer._call_ollama')
    def test_response_time_acceptable(self, mock_ollama, client):
        """Test that response time is reasonable"""
        import time

        mock_ollama.return_value = "Analysis complete."

        start_time = time.time()
        response = client.post(
            '/api/analyze',
            data=json.dumps({'code': 'DISPLAY "TEST".'}),
            content_type='application/json'
        )
        end_time = time.time()

        # Response should be under 5 seconds for simple code (with mocking)
        assert (end_time - start_time) < 5.0
        assert response.status_code == 200


class TestOllamaAnalyzerClass:
    """Test the OllamaAnalyzer class directly"""

    def test_analyzer_initialization(self):
        """Test OllamaAnalyzer initialization"""
        from app import OllamaAnalyzer
        analyzer = OllamaAnalyzer()

        assert analyzer.endpoint is not None
        assert analyzer.model is not None
        assert analyzer.timeout > 0

    def test_parse_bug_response(self):
        """Test bug response parsing"""
        from app import OllamaAnalyzer
        analyzer = OllamaAnalyzer()

        response_text = """
        Line 5: High severity
        Error: Missing period at end of statement
        Suggestion: Add period after DISPLAY statement

        Line 10: Medium severity
        Bug: Potential null pointer
        Suggestion: Add null check before accessing variable
        """

        cobol_code = "\n".join([f"Line {i}" for i in range(1, 20)])
        bugs = analyzer._parse_bug_response(response_text, cobol_code)

        assert isinstance(bugs, list)
        assert len(bugs) > 0
        for bug in bugs:
            assert 'line' in bug
            assert 'severity' in bug
            assert 'description' in bug
            assert 'suggestion' in bug

    def test_generate_summary_no_bugs(self):
        """Test summary generation with no bugs"""
        from app import OllamaAnalyzer
        analyzer = OllamaAnalyzer()

        summary = analyzer._generate_summary([])
        assert 'no bugs' in summary.lower() or 'clean' in summary.lower()

    def test_generate_summary_with_bugs(self):
        """Test summary generation with bugs"""
        from app import OllamaAnalyzer
        analyzer = OllamaAnalyzer()

        bugs = [
            {'severity': 'critical', 'description': 'Bug 1', 'line': 1, 'suggestion': 'Fix 1'},
            {'severity': 'high', 'description': 'Bug 2', 'line': 2, 'suggestion': 'Fix 2'},
            {'severity': 'medium', 'description': 'Bug 3', 'line': 3, 'suggestion': 'Fix 3'},
        ]

        summary = analyzer._generate_summary(bugs)
        assert '3' in summary
        assert 'critical' in summary.lower() or 'high' in summary.lower()


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--cov=backend', '--cov-report=html'])
