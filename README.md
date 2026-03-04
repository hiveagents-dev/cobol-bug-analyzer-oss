# COBOL Bug Analyzer

A modern web application for analyzing COBOL code to detect bugs, suggest improvements, and identify best practice violations using AI-powered analysis.

## 🎯 Features

- **Comprehensive Bug Detection**: Syntax errors, logic bugs, performance issues, and best practice violations
- **AI-Powered Analysis**: Uses Ollama's xmainframe model specialized for COBOL/mainframe code
- **Modern UI**: Clean, VS Code-inspired interface with syntax highlighting
- **Severity Classification**: Color-coded bug reports (Critical, High, Medium, Low, Info)
- **Actionable Suggestions**: Each bug comes with specific fix recommendations
- **Dockerized**: Easy deployment with Docker Compose

## 🏗️ Architecture

```
┌─────────────┐      ┌─────────────┐      ┌─────────────────────┐
│   Frontend  │─────▶│   Backend   │─────▶│   LLM Provider      │
│  (Nginx)    │      │   (Flask)   │      │  Ollama / Vertex AI │
│  Port 8080  │      │  Port 5000  │      └─────────────────────┘
└─────────────┘      └─────────────┘
```

- **Frontend**: Vanilla HTML/CSS/JS served by Nginx
- **Backend**: Flask REST API with multi-provider LLM support
- **AI Model**: Ollama xmainframe (local) or Vertex AI Gemini (cloud)

## 🔄 LLM Provider Configuration

The analyzer supports two LLM providers that can be switched via environment variables:

### Available Providers

| Provider | Best For | Cost | Setup |
|----------|----------|------|-------|
| **Ollama** | Local dev, offline work, full control | Free (your hardware) | Install Ollama + xmainframe model |
| **Vertex AI** | Production, Cloud Run, no infra management | ~€0.006/analysis | GCP project + authentication |

### About the xmainframe Model

[xmainframe](https://ollama.com/xmainframe) is an open source LLM available on Ollama, fine-tuned specifically for COBOL and mainframe code. It understands COBOL divisions, data types, file handling patterns, and common legacy anti-patterns out of the box — making it significantly more accurate for this use case than a general-purpose model.

```bash
ollama pull xmainframe:latest
```

No account or API key required. The model runs entirely on your local machine.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_PROVIDER` | `vertex_ai` | Provider to use: `ollama` or `vertex_ai` |
| `OLLAMA_ENDPOINT` | `http://localhost:11434` | Ollama API endpoint |
| `OLLAMA_MODEL` | `xmainframe:latest` | Ollama model name |
| `GCP_PROJECT_ID` | `your-gcp-project` | Google Cloud project ID |
| `GCP_LOCATION` | `us-central1` | Vertex AI region |
| `VERTEX_MODEL` | `gemini-2.0-flash-001` | Gemini model version |

### Quick Provider Switch

```bash
# Use Ollama (local)
LLM_PROVIDER=ollama python backend/app.py

# Use Vertex AI (cloud)
LLM_PROVIDER=vertex_ai GCP_PROJECT_ID=your-project python backend/app.py
```

### Test Scripts

```bash
# Interactive test with auto-detection
./scripts/test-local.sh

# Specify provider explicitly
./scripts/test-local.sh ollama
./scripts/test-local.sh vertex

# Quick provider test (backend must be running)
./scripts/test-providers.sh
```

## 📋 Prerequisites

1. **Ollama** installed and running natively (recommended for Apple Silicon):
   ```bash
   brew install ollama
   ollama pull xmainframe:latest
   ollama serve
   ```

2. **Docker** and **Docker Compose**:
   ```bash
   brew install docker
   ```

## 🚀 Quick Start

### 1. Clone and Navigate
```bash
git clone https://github.com/your-org/cobol-bug-analyzer.git
cd cobol-bug-analyzer
```

### 2. Start Ollama (if not already running)
```bash
ollama serve
```

Verify xmainframe model is available:
```bash
ollama list | grep xmainframe
```

### 3. Launch with Docker Compose
```bash
docker compose up -d
```

### 4. Access the Application
- **Frontend**: http://localhost:8080
- **Backend API**: http://localhost:5000
- **Health Check**: http://localhost:5000/api/health

## 🧪 Testing

### Backend Tests
```bash
# Install test dependencies
cd backend
pip install -r requirements.txt

# Run tests
pytest ../tests/test_backend.py -v --cov=backend

# Or use the test runner
chmod +x ../tests/run_tests.sh
../tests/run_tests.sh
```

### Frontend Tests
```bash
# Open in browser
open frontend/tests/test_frontend.html
```

## 📚 API Documentation

### `POST /api/analyze`
Analyze COBOL code for bugs and improvements.

**Request:**
```json
{
  "code": "IDENTIFICATION DIVISION.\n       PROGRAM-ID. SAMPLE.\n       ..."
}
```

**Response:**
```json
{
  "bugs": [
    {
      "line": 42,
      "severity": "high",
      "type": "LOGIC_BUG",
      "description": "Division by zero possible",
      "suggestion": "Add zero check before division operation"
    }
  ],
  "summary": "Found 3 issue(s): 1 high, 2 medium",
  "analysis_complete": true
}
```

### `GET /api/health`
Check backend and Ollama connectivity.

### `GET /api/info`
Get analyzer configuration details.

## 🐳 Docker Commands

```bash
# Start services
docker compose up -d

# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f backend

# Stop services
docker compose down

# Rebuild after code changes
docker compose up -d --build

# View running containers
docker compose ps
```

## 🔧 Configuration

Backend configuration via environment variables in `compose.yaml`:

```yaml
environment:
  - LLM_PROVIDER=xmainframe
  - LLM_ENDPOINT=http://host.docker.internal:11434
  - LLM_MODEL=xmainframe:latest
  - FLASK_ENV=production
```

## 🛠️ Development

### Local Development (without Docker)

**Option 1: Using Ollama (recommended for local dev)**
```bash
# 1. Start Ollama with xmainframe model
ollama serve &
ollama pull xmainframe:latest

# 2. Run the test script
./scripts/test-local.sh ollama
```

**Option 2: Using Vertex AI**
```bash
# 1. Authenticate with GCP
gcloud auth application-default login --project=cobol-analyzer

# 2. Run the test script
GCP_PROJECT_ID=cobol-analyzer ./scripts/test-local.sh vertex
```

**Manual Backend Setup:**
```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Choose provider
LLM_PROVIDER=ollama python app.py      # For Ollama
# or
LLM_PROVIDER=vertex_ai python app.py   # For Vertex AI
```

**Frontend:**
```bash
cd frontend/src
python -m http.server 8080
# Or use any static file server
```

### Vertex AI Setup (for Cloud Deployment)

```bash
# Enable required APIs
gcloud services enable aiplatform.googleapis.com --project=cobol-analyzer
gcloud services enable run.googleapis.com --project=cobol-analyzer

# Create service account
gcloud iam service-accounts create cobol-analyzer-sa \
  --display-name="COBOL Analyzer SA" \
  --project=cobol-analyzer

# Grant Vertex AI permissions
gcloud projects add-iam-policy-binding cobol-analyzer \
  --member="serviceAccount:cobol-analyzer-sa@cobol-analyzer.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"
```

## 📂 Project Structure

```
cobol_bug_analyzer/
├── backend/
│   ├── app.py              # Flask REST API
│   ├── vertex_adapter.py   # Vertex AI Gemini adapter
│   ├── requirements.txt    # Python dependencies
│   ├── Dockerfile          # Backend container config
│   └── .env.example        # Environment template
├── frontend/
│   ├── src/
│   │   ├── index.html      # Main UI
│   │   ├── app.js          # Frontend logic
│   │   └── styles.css      # Styling
│   ├── tests/
│   │   └── test_frontend.html
│   ├── Dockerfile          # Frontend container (VM deployment)
│   ├── Dockerfile.cloudrun # Frontend container (Cloud Run)
│   └── nginx.conf          # Nginx configuration
├── scripts/
│   ├── test-local.sh       # Interactive local test script
│   └── test-providers.sh   # Quick provider test
├── tests/
│   ├── test_backend.py     # Backend test suite
│   ├── pytest.ini          # Pytest configuration
│   └── run_tests.sh        # Test runner script
├── compose.yaml            # Docker Compose
├── .github/
│   ├── workflows/ci.yml    # GitHub Actions CI
│   └── ISSUE_TEMPLATE/     # Bug report & feature request templates
└── README.md               # This file
```

## 🐛 Bug Categories Detected

1. **SYNTAX_ERROR**: Missing periods, invalid identifiers, PIC clause errors
2. **LOGIC_BUG**: Infinite loops, division by zero, uninitialized variables
3. **DATA_HANDLING**: Truncation, type mismatches, decimal alignment
4. **FILE_OPERATION**: Missing status checks, EOF handling
5. **PERFORMANCE**: Inefficient searches, redundant operations
6. **BEST_PRACTICE**: Magic numbers, poor naming conventions
7. **DEPRECATED_FEATURE**: ALTER statements, excessive GO TO usage
8. **SECURITY**: Data exposure risks, SQL injection vulnerabilities

## 🎨 UI Features

- **Large Code Editor**: Textarea with COBOL example placeholder
- **Analysis Button**: Triggers bug detection with loading spinner
- **Color-Coded Results**: Critical (red), Warning (orange), Info (blue)
- **Expandable Bug Cards**: Line numbers, descriptions, suggestions
- **Summary Statistics**: Total bugs and severity breakdown
- **Clear/Reset**: Easy code clearing for new analysis

## 🔍 Troubleshooting

### Backend can't connect to Ollama
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Verify xmainframe model
ollama list | grep xmainframe

# If model is missing
ollama pull xmainframe:latest
```

### Frontend can't reach backend
```bash
# Check backend is running
curl http://localhost:5000/api/health

# Check Docker services
docker compose ps

# Check logs
docker compose logs backend
```

### Tests failing
```bash
# Ensure test dependencies are installed
pip install -r backend/requirements.txt

# Run with verbose output
pytest tests/test_backend.py -vv
```

## 📝 Example COBOL Code

Paste this into the analyzer to see it in action:

```cobol
IDENTIFICATION DIVISION.
PROGRAM-ID. SAMPLE-PROGRAM.
DATA DIVISION.
WORKING-STORAGE SECTION.
01 WS-COUNTER PIC 9(3) VALUE 0.
01 WS-TOTAL PIC 9(5) VALUE 0.
PROCEDURE DIVISION.
    PERFORM VARYING WS-COUNTER FROM 1 BY 1 UNTIL WS-COUNTER > 100
        COMPUTE WS-TOTAL = WS-TOTAL + WS-COUNTER
    END-PERFORM.
    DISPLAY "Total: " WS-TOTAL.
    STOP RUN.
```

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines on how to get started, run tests, and submit pull requests.

## 📄 License

MIT License - feel free to use and modify as needed.

## 🙏 Acknowledgments

- **Ollama**: For providing the xmainframe COBOL-specialized model
- **Flask**: Lightweight Python web framework
- **Nginx**: High-performance web server
- **Docker**: Containerization platform

---

Built and open sourced by [Hive Agents](https://www.hiveagents.dev) — AI-powered tools for legacy code modernization.
