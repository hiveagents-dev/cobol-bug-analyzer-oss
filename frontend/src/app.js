// DOM Elements
const cobolInput = document.getElementById('cobol-input');
const analyzeBtn = document.getElementById('analyze-btn');
const clearBtn = document.getElementById('clear-btn');
const loadingSpinner = document.getElementById('loading-spinner');
const resultsSection = document.getElementById('results-section');
const bugsList = document.getElementById('bugs-list');
const summary = document.getElementById('summary');
const errorMessage = document.getElementById('error-message');

// API Configuration - Use nginx proxy (relative URL) in production
const API_BASE_URL = '';
const ANALYZE_ENDPOINT = `${API_BASE_URL}/api/analyze`;
const ANALYZE_STREAM_ENDPOINT = `${API_BASE_URL}/api/analyze/stream`;
const SESSION_ENDPOINT = `${API_BASE_URL}/api/session`;

// Session token management (no hardcoded API keys!)
let sessionToken = null;
let sessionExpiresAt = 0;

// Feature detection
const SUPPORTS_SSE = typeof EventSource !== 'undefined';


/**
 * Get or refresh session token
 * @returns {Promise<string>} Valid session token
 */
async function getSessionToken() {
    const now = Date.now();

    // Return cached token if still valid (with 60s buffer)
    if (sessionToken && sessionExpiresAt > now + 60000) {
        return sessionToken;
    }

    try {
        const response = await fetch(SESSION_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
        });

        if (!response.ok) {
            throw new Error(`Failed to get session: ${response.status}`);
        }

        const data = await response.json();
        sessionToken = data.token;
        sessionExpiresAt = now + (data.expires_in * 1000);

        console.log('✅ Session token obtained');
        return sessionToken;

    } catch (error) {
        console.error('Failed to get session token:', error);
        throw new Error('Unable to authenticate. Please refresh the page.');
    }
}

// Event Listeners
analyzeBtn.addEventListener('click', handleAnalyze);
clearBtn.addEventListener('click', handleClear);

// Keyboard shortcut: Ctrl/Cmd + Enter to analyze
cobolInput.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
        e.preventDefault();
        handleAnalyze();
    }
});

/**
 * Main analyze handler with streaming support
 */
async function handleAnalyze() {
    const code = cobolInput.value.trim();

    if (!code) {
        showError('Please enter some COBOL code to analyze.');
        return;
    }


    // Use streaming if supported, otherwise fallback to regular
    if (SUPPORTS_SSE) {
        analyzeWithStreaming(code);
    } else {
        analyzeRegular(code);
    }
}

/**
 * Analyze with SSE streaming for progressive results
 */
async function analyzeWithStreaming(code) {
    try {
        showLoading();
        hideError();

        // Get session token first
        const token = await getSessionToken();

        // Prepare streaming display
        bugsList.innerHTML = '<div class="streaming-info">🔄 Analysis in progress...</div>';
        resultsSection.classList.remove('hidden');

        const bugs = [];
        let eventSource = null;

        // EventSource doesn't support POST, so we use fetch with streaming
        fetch(ANALYZE_STREAM_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Session-Token': token,
            },
            body: JSON.stringify({ code }),
        }).then(response => {
            if (!response.ok) {
                throw new Error(`Stream failed: ${response.status}`);
            }

            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let buffer = '';

            function processStream() {
                reader.read().then(({ done, value }) => {
                    if (done) {
                        hideLoading();
                        return;
                    }

                    buffer += decoder.decode(value, { stream: true });
                    const lines = buffer.split('\n\n');
                    buffer = lines.pop(); // Keep incomplete line in buffer

                    lines.forEach(line => {
                        if (line.startsWith('data: ')) {
                            try {
                                const data = JSON.parse(line.substring(6));

                                if (data.done) {
                                    // Analysis complete
                                    hideLoading();
                                    updateSummary(bugs, data.cached);
                                } else if (data.error) {
                                    showError(`Analysis failed: ${data.error}`);
                                    hideLoading();
                                } else {
                                    // New bug received
                                    bugs.push(data);
                                    displayStreamingBug(data, bugs.length);
                                }
                            } catch (e) {
                                console.error('Error parsing SSE data:', e);
                            }
                        }
                    });

                    processStream();
                });
            }

            processStream();

        }).catch(error => {
            console.error('Streaming error:', error);
            hideLoading();
            // Fallback to regular analysis
            analyzeRegular(code);
        });

    } catch (error) {
        console.error('Streaming setup error:', error);
        // Fallback to regular analysis
        analyzeRegular(code);
    }
}

/**
 * Regular non-streaming analysis (fallback)
 */
async function analyzeRegular(code) {
    try {
        showLoading();

        // Get session token first
        const token = await getSessionToken();

        const response = await fetch(ANALYZE_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Session-Token': token,
            },
            body: JSON.stringify({ code }),
        });

        if (!response.ok) {
            throw new Error(`API request failed: ${response.status} ${response.statusText}`);
        }

        const data = await response.json();
        displayResults(data);

    } catch (error) {
        console.error('Analysis error:', error);
        showError(`Analysis failed: ${error.message}. Make sure the backend server is running.`);
    } finally {
        hideLoading();
    }
}

/**
 * Display analysis results
 */
function displayResults(data) {
    hideError();

    const bugs = data.bugs || [];
    const totalBugs = bugs.length;
    const cached = data.cached || false;

    // Count severity levels
    const severityCounts = bugs.reduce((acc, bug) => {
        const severity = bug.severity || 'info';
        acc[severity] = (acc[severity] || 0) + 1;
        return acc;
    }, {});

    // Update summary
    summary.innerHTML = `
        <div class="summary-item">
            <strong>Total Issues:</strong>
            <span class="summary-badge ${totalBugs === 0 ? 'badge-success' : 'badge-info'}">
                ${totalBugs}
            </span>
        </div>
        ${severityCounts.critical ? `
            <div class="summary-item">
                <strong>Critical:</strong>
                <span class="summary-badge badge-critical">${severityCounts.critical}</span>
            </div>
        ` : ''}
        ${severityCounts.warning ? `
            <div class="summary-item">
                <strong>Warnings:</strong>
                <span class="summary-badge badge-warning">${severityCounts.warning}</span>
            </div>
        ` : ''}
        ${severityCounts.info ? `
            <div class="summary-item">
                <strong>Info:</strong>
                <span class="summary-badge badge-info">${severityCounts.info}</span>
            </div>
        ` : ''}
        ${cached ? `
            <div class="summary-item">
                <span class="summary-badge" style="background: #10b981; color: white;">⚡ Cached</span>
            </div>
        ` : ''}
    `;

    // Render bugs list
    if (bugs.length === 0) {
        bugsList.innerHTML = `
            <div class="no-bugs">
                <div class="no-bugs-icon">✅</div>
                <h3>No Issues Found!</h3>
                <p>Your COBOL code looks good. No obvious bugs detected.</p>
            </div>
        `;
    } else {
        bugsList.innerHTML = bugs.map(bug => renderBugItem(bug)).join('');
    }

    // Show results section
    resultsSection.classList.remove('hidden');

    // Smooth scroll to results
    resultsSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

/**
 * Display streaming bug progressively
 */
function displayStreamingBug(bug, index) {
    if (index === 1) {
        // First bug - clear loading message
        bugsList.innerHTML = '';
    }

    // Append new bug
    const bugHtml = renderBugItem(bug);
    bugsList.insertAdjacentHTML('beforeend', bugHtml);

    // Scroll to show new bug
    const newBugElement = bugsList.lastElementChild;
    if (newBugElement) {
        newBugElement.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
}

/**
 * Update summary after streaming complete
 */
function updateSummary(bugs, cached) {
    const totalBugs = bugs.length;
    const severityCounts = bugs.reduce((acc, bug) => {
        const severity = bug.severity || 'info';
        acc[severity] = (acc[severity] || 0) + 1;
        return acc;
    }, {});

    summary.innerHTML = `
        <div class="summary-item">
            <strong>Total Issues:</strong>
            <span class="summary-badge ${totalBugs === 0 ? 'badge-success' : 'badge-info'}">
                ${totalBugs}
            </span>
        </div>
        ${severityCounts.critical ? `
            <div class="summary-item">
                <strong>Critical:</strong>
                <span class="summary-badge badge-critical">${severityCounts.critical}</span>
            </div>
        ` : ''}
        ${severityCounts.warning ? `
            <div class="summary-item">
                <strong>Warnings:</strong>
                <span class="summary-badge badge-warning">${severityCounts.warning}</span>
            </div>
        ` : ''}
        ${severityCounts.info ? `
            <div class="summary-item">
                <strong>Info:</strong>
                <span class="summary-badge badge-info">${severityCounts.info}</span>
            </div>
        ` : ''}
        ${cached ? `
            <div class="summary-item">
                <span class="summary-badge" style="background: #10b981; color: white;">⚡ Cached</span>
            </div>
        ` : ''}
    `;
}

/**
 * Get icon for bug type
 */
function getBugIcon(type) {
    const icons = {
        'SYNTAX_ERROR': '⚠️',
        'LOGIC_BUG': '🐛',
        'DATA_HANDLING': '📊',
        'FILE_OPERATION': '📁',
        'PERFORMANCE': '⚡',
        'BEST_PRACTICE': '✨',
        'SECURITY': '🔒',
        'GENERAL_ISSUE': '📋',
        'ANALYSIS': '🔍'
    };
    return icons[type] || '❓';
}

/**
 * Format bug type for display
 */
function formatBugType(type) {
    if (!type || type === 'GENERAL_ISSUE' || type === 'ANALYSIS') {
        return 'General Analysis';
    }
    // Convert SYNTAX_ERROR to "Syntax Error", LOGIC_BUG to "Logic Bug", etc.
    return type.split('_').map(word =>
        word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
    ).join(' ');
}

/**
 * Render individual bug item
 */
function renderBugItem(bug) {
    const severity = bug.severity || 'info';
    const lineNumber = bug.line || 0;
    const title = formatBugType(bug.type);
    const description = escapeHtml(bug.description || 'No description available.');
    const suggestion = escapeHtml(bug.suggestion || 'Review the code and consider best practices.');

    return `
        <div class="bug-item severity-${severity}">
            <div class="bug-header">
                <div class="bug-title">
                    <span class="bug-type-icon">${getBugIcon(bug.type)}</span>
                    ${title}
                </div>
                <div class="bug-meta">
                    ${lineNumber > 0 ? `<span class="line-number">Line ${lineNumber}</span>` : '<span class="line-number no-line">Multiple Lines</span>'}
                    <span class="severity-badge severity-${severity}">${severity.toUpperCase()}</span>
                </div>
            </div>
            <div class="bug-description">${description}</div>
            <div class="bug-suggestion">
                <span class="suggestion-label">💡 Suggestion:</span>
                <div class="suggestion-text">${suggestion}</div>
            </div>
        </div>
    `;
}

/**
 * Clear input handler
 */
function handleClear() {
    cobolInput.value = '';
    resultsSection.classList.add('hidden');
    hideError();
    cobolInput.focus();
}

/**
 * Show loading state
 */
function showLoading() {
    analyzeBtn.disabled = true;
    analyzeBtn.querySelector('.btn-text').textContent = 'Analyzing...';
    loadingSpinner.classList.remove('hidden');
    resultsSection.classList.add('hidden');
    hideError();
}

/**
 * Hide loading state
 */
function hideLoading() {
    analyzeBtn.disabled = false;
    analyzeBtn.querySelector('.btn-text').textContent = 'Analyze Code';
    loadingSpinner.classList.add('hidden');
}

/**
 * Show error message (supports HTML for upgrade links)
 */
function showError(message) {
    errorMessage.innerHTML = message;
    errorMessage.classList.remove('hidden');
    resultsSection.classList.add('hidden');
}

/**
 * Hide error message
 */
function hideError() {
    errorMessage.classList.add('hidden');
    errorMessage.innerHTML = '';
}

/**
 * Escape HTML to prevent XSS
 */
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

/**
 * Initialize app
 */
async function init() {
    console.log('COBOL Bug Analyzer initialized');
    cobolInput.focus();

    // Check if backend is available
    await checkBackendHealth();

    // Pre-fetch session token for faster first analysis
    try {
        await getSessionToken();
    } catch (error) {
        console.warn('Could not pre-fetch session token:', error);
    }
}

/**
 * Check backend health on load
 */
async function checkBackendHealth() {
    try {
        const response = await fetch(`${API_BASE_URL}/api/health`, {
            method: 'GET',
        });

        if (response.ok) {
            console.log('✅ Backend server is running');
        }
    } catch (error) {
        console.warn('⚠️  Backend server might not be running. Start it with: node backend/server.js');
    }
}

// Initialize on DOM ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
