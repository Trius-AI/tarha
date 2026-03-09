// Session Viewer Application
class SessionViewer {
    constructor() {
        this.apiUrl = document.getElementById('api-url').value || 'http://localhost:8080';
        this.autoRefresh = false;
        this.autoRefreshInterval = null;
        this.sessions = [];
        this.selectedSession = null;

        this.init();
    }

    init() {
        // Bind event listeners
        document.getElementById('refresh-btn').addEventListener('click', () => this.refresh());
        document.getElementById('auto-refresh-toggle').addEventListener('click', () => this.toggleAutoRefresh());
        document.getElementById('api-url').addEventListener('change', (e) => {
            this.apiUrl = e.target.value;
            this.refresh();
        });
        document.getElementById('close-detail').addEventListener('click', () => this.closeDetail());

        // Initial load
        this.refresh();
    }

    async fetchJson(endpoint) {
        const url = `${this.apiUrl}${endpoint}`;
        try {
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json'
                }
            });
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Fetch error:', error);
            throw error;
        }
    }

    async postJson(endpoint, data = {}) {
        const url = `${this.apiUrl}${endpoint}`;
        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                },
                body: JSON.stringify(data)
            });
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            return await response.json();
        } catch (error) {
            console.error('Post error:', error);
            throw error;
        }
    }

    async refresh() {
        const container = document.getElementById('sessions-container');
        container.innerHTML = '<div class="loading">Loading sessions...</div>';

        try {
            // Fetch active sessions
            const sessionsData = await this.fetchJson('/sessions/active');
            this.sessions = sessionsData.sessions || [];

            // Fetch status for stats
            const statusData = await this.fetchJson('/status');

            this.updateStats(this.sessions, statusData);
            this.renderSessions(this.sessions);

            // Update last refreshed time
            document.getElementById('last-updated').textContent = new Date().toLocaleTimeString();
        } catch (error) {
            container.innerHTML = `
                <div class="error">
                    <p>❌ Error connecting to API: ${error.message}</p>
                    <p>Make sure the coding agent HTTP server is running at ${this.apiUrl}</p>
                </div>
            `;
        }
    }

    updateStats(sessions, status) {
        document.getElementById('total-sessions').textContent = sessions.length;
        document.getElementById('active-sessions').textContent = status.active_sessions || sessions.length;
    }

    renderSessions(sessions) {
        const container = document.getElementById('sessions-container');

        if (sessions.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <div class="icon">📭</div>
                    <p>No active sessions</p>
                    <p style="margin-top: 10px; font-size: 0.9rem;">Sessions will appear here when created</p>
                </div>
            `;
            return;
        }

        container.innerHTML = sessions.map(session => this.renderSessionCard(session)).join('');

        // Bind click events to session cards
        container.querySelectorAll('.session-card').forEach(card => {
            card.addEventListener('click', (e) => {
                if (!e.target.closest('button')) {
                    this.showSessionDetail(card.dataset.sessionId);
                }
            });
        });

        // Bind action buttons
        container.querySelectorAll('.btn-halt').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                this.haltSession(btn.dataset.sessionId);
            });
        });

        container.querySelectorAll('.btn-stats').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                this.showSessionDetail(btn.dataset.sessionId);
            });
        });
    }

    renderSessionCard(session) {
        const sessionId = session.id || session;
        const isBusy = session.busy || false;
        const model = session.model || 'unknown';
        const tokens = session.prompt_tokens || session.estimated_tokens || 0;
        const toolCalls = session.tool_calls || 0;
        const messageCount = session.messages ? session.messages.length : 0;

        return `
            <div class="session-card" data-session-id="${sessionId}">
                <div class="session-header">
                    <span class="session-id">${sessionId.substring(0, 8)}...</span>
                    <div class="session-status">
                        <span class="status-dot ${isBusy ? 'busy' : 'idle'}"></span>
                        <span>${isBusy ? 'Busy' : 'Idle'}</span>
                    </div>
                </div>
                <div class="session-info">
                    <div class="info-row">
                        <span class="info-label">Model:</span>
                        <span class="info-value model">${model}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Messages:</span>
                        <span class="info-value">${messageCount}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Tokens:</span>
                        <span class="info-value tokens">${tokens.toLocaleString()}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Tool Calls:</span>
                        <span class="info-value">${toolCalls}</span>
                    </div>
                </div>
                <div class="session-actions">
                    <button class="btn-secondary btn-stats" data-session-id="${sessionId}">📊 Stats</button>
                    <button class="btn-danger btn-halt" data-session-id="${sessionId}">⏹ Halt</button>
                </div>
            </div>
        `;
    }

    async showSessionDetail(sessionId) {
        const detailPanel = document.getElementById('session-detail');
        const detailContent = document.getElementById('detail-content');

        detailPanel.style.display = 'block';
        detailContent.innerHTML = '<div class="loading">Loading session details...</div>';

        try {
            const sessionData = await this.fetchJson(`/session/${sessionId}`);
            this.selectedSession = sessionData;

            detailContent.innerHTML = this.renderSessionDetail(sessionData);
        } catch (error) {
            detailContent.innerHTML = `
                <div class="error">
                    <p>❌ Error loading session: ${error.message}</p>
                </div>
            `;
        }
    }

    renderSessionDetail(session) {
        const id = session.id || 'unknown';
        const model = session.model || 'unknown';
        const messages = session.messages || [];
        const workingDir = session.working_dir || 'unknown';
        const promptTokens = session.prompt_tokens || 0;
        const completionTokens = session.completion_tokens || 0;
        const estimatedTokens = session.estimated_tokens || 0;
        const toolCalls = session.tool_calls || 0;
        const contextLength = session.context_length || 'unknown';
        const openFiles = session.open_files || {};
        const busy = session.busy || false;

        let messagesHtml = '';
        if (messages.length > 0) {
            messagesHtml = messages.map(msg => `
                <li class="message-item">
                    <div class="message-role ${msg.role}">${msg.role}</div>
                    <div class="message-content">${this.escapeHtml(msg.content || JSON.stringify(msg, null, 2))}</div>
                </li>
            `).join('');
        } else {
            messagesHtml = '<li class="message-item"><div class="message-content">No messages yet</div></li>';
        }

        return `
            <div class="detail-section">
                <h3>📋 Session ID</h3>
                <pre>${id}</pre>
            </div>

            <div class="detail-section">
                <h3>🤖 Model</h3>
                <pre>${model}</pre>
            </div>

            <div class="detail-section">
                <h3>📊 Statistics</h3>
                <pre>
Status:         ${busy ? 'Busy' : 'Idle'}
Context Length: ${contextLength}
Prompt Tokens:  ${promptTokens}
Completion:     ${completionTokens}
Estimated:      ${estimatedTokens}
Tool Calls:     ${toolCalls}
Messages:       ${messages.length}
                </pre>
            </div>

            <div class="detail-section">
                <h3>📁 Working Directory</h3>
                <pre>${workingDir}</pre>
            </div>

            <div class="detail-section">
                <h3>📂 Open Files (${Object.keys(openFiles).length})</h3>
                <pre>${Object.keys(openFiles).length > 0 ? Object.keys(openFiles).join('\n') : 'No open files'}</pre>
            </div>

            <div class="detail-section">
                <h3>💬 Messages (${messages.length})</h3>
                <ul class="message-list">${messagesHtml}</ul>
            </div>
        `;
    }

    async haltSession(sessionId) {
        if (!confirm(`Are you sure you want to halt session ${sessionId.substring(0, 8)}...?`)) {
            return;
        }

        try {
            await this.postJson(`/session/${sessionId}/halt`, {});
            await this.refresh();
        } catch (error) {
            alert(`Error halting session: ${error.message}`);
        }
    }

    closeDetail() {
        document.getElementById('session-detail').style.display = 'none';
        this.selectedSession = null;
    }

    toggleAutoRefresh() {
        const btn = document.getElementById('auto-refresh-toggle');
        this.autoRefresh = !this.autoRefresh;

        if (this.autoRefresh) {
            btn.textContent = 'Auto: ON';
            btn.classList.add('btn-primary');
            btn.classList.remove('btn-secondary');
            this.autoRefreshInterval = setInterval(() => this.refresh(), 5000);
        } else {
            btn.textContent = 'Auto: OFF';
            btn.classList.remove('btn-primary');
            btn.classList.add('btn-secondary');
            if (this.autoRefreshInterval) {
                clearInterval(this.autoRefreshInterval);
                this.autoRefreshInterval = null;
            }
        }
    }

    escapeHtml(text) {
        if (typeof text !== 'string') {
            text = String(text);
        }
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.sessionViewer = new SessionViewer();
});