# Contributing to COBOL Bug Analyzer

Thanks for your interest in contributing! This guide will get you up and running.

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Python 3.11+
- [Ollama](https://ollama.com) (for local LLM, no cloud account needed)

### Local Setup

```bash
git clone https://github.com/your-org/cobol-bug-analyzer.git
cd cobol-bug-analyzer

# Pull the COBOL-specialized model
ollama pull xmainframe:latest

# Start the stack
docker compose up -d

# App is live at http://localhost:8080
```

### Running Without Docker

```bash
# Backend
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
LLM_PROVIDER=ollama python app.py

# Frontend (separate terminal)
cd frontend/src
python -m http.server 8080
```

## Running Tests

```bash
# Install test deps
pip install -r backend/requirements.txt

# Run backend tests
pytest tests/test_backend.py -v

# With coverage
pytest tests/test_backend.py -v --cov=backend --cov-report=term-missing

# Frontend tests — open in browser
open frontend/tests/test_frontend.html
```

Tests must pass before submitting a PR.

## LLM Providers

The app supports two providers via the `LLM_PROVIDER` env var:

| Provider | Use case | Setup |
|----------|----------|-------|
| `ollama` | Local dev, no cloud needed | `ollama pull xmainframe:latest` |
| `vertex_ai` | Google Cloud / Gemini | GCP project + `gcloud auth application-default login` |

Default for local dev is `ollama`.

## Project Structure

```
backend/          Flask REST API + LLM adapters
frontend/src/     Vanilla HTML/CSS/JS UI
tests/            pytest backend test suite
scripts/          Helper scripts for local testing
docs/             Documentation
```

## How to Contribute

1. **Fork** the repo and create a branch from `main`
2. **Write tests** for any new behaviour
3. **Make your changes** — keep files under 500 lines
4. **Run the tests** and make sure they pass
5. **Open a Pull Request** with a clear description of what and why

## Pull Request Guidelines

- Keep PRs focused — one feature or fix per PR
- Reference any related issues in the PR description
- Add or update tests for your changes
- Don't commit `.env` files, credentials, or secrets

## Reporting Bugs

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md). Include:
- Steps to reproduce
- Expected vs actual behaviour
- Your environment (OS, Docker version, LLM provider)

## Suggesting Features

Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md).

## Code Style

- Python: follow PEP 8, keep functions focused
- JavaScript: vanilla JS, no frameworks
- No hardcoded secrets or credentials

## License

By contributing you agree your code will be licensed under the [MIT License](../LICENSE).

---

Built with ❤️ by [Hive Agents](https://www.hiveagents.dev)
