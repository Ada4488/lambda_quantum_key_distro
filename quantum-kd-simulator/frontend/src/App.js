import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [activeTab, setActiveTab] = useState('simulator');
  const [apiUrl, setApiUrl] = useState('');
  const [isConnected, setIsConnected] = useState(false);

  // QKD Simulation state
  const [qkdParams, setQkdParams] = useState({
    target_key_length: 128,
    channel_error_rate: 0.05
  });
  const [simulationResult, setSimulationResult] = useState(null);
  const [isSimulating, setIsSimulating] = useState(false);
  const [simulationHistory, setSimulationHistory] = useState([]);

  // File encryption states
  const [selectedKey, setSelectedKey] = useState(null);
  const [selectedFile, setSelectedFile] = useState(null);
  const [selectedEncryptedFile, setSelectedEncryptedFile] = useState(null);
  const [encryptionResult, setEncryptionResult] = useState(null);
  const [isProcessing, setIsProcessing] = useState(false);

  useEffect(() => {
    // Try to detect API URL from environment or use default
    const detectedApiUrl = process.env.REACT_APP_API_URL || 'http://localhost:3001';
    setApiUrl(detectedApiUrl);
    
    // Test connection
    testConnection(detectedApiUrl);
  }, []);

  const testConnection = async (url) => {
    try {
      await axios.get(`${url}/api/v1/health`);
      setIsConnected(true);
    } catch (error) {
      console.warn('API connection failed:', error.message);
      setIsConnected(false);
    }
  };

  const runQkdSimulation = async () => {
    if (!isConnected) {
      alert('API not connected. Please check the backend server.');
      return;
    }

    setIsSimulating(true);
    setSimulationResult(null);

    try {
      const response = await axios.post(`${apiUrl}/api/v1/simulate-qkd`, qkdParams);
      const result = response.data;

      setSimulationResult(result);

      // Add to history
      const historyEntry = {
        ...result,
        timestamp: new Date().toISOString(),
        params: { ...qkdParams }
      };
      setSimulationHistory(prev => [historyEntry, ...prev.slice(0, 9)]); // Keep last 10

    } catch (error) {
      console.error('QKD simulation failed:', error);

      let errorMessage = 'Unknown error occurred';
      let suggestion = 'Please try again with different parameters.';

      if (error.response?.status === 400) {
        const responseData = error.response.data;

        if (responseData.message && responseData.message.includes('QBER')) {
          // QBER too high - eavesdropping detected
          const qberMatch = responseData.message.match(/QBER \(([0-9.]+)\)/);
          const qberValue = qberMatch ? parseFloat(qberMatch[1]) : null;

          errorMessage = `🚨 Eavesdropping Detected! QBER: ${qberValue ? (qberValue * 100).toFixed(1) + '%' : 'High'}`;
          suggestion = `The quantum bit error rate is too high (>${15}%), indicating potential eavesdropping. Try reducing the Channel Error Rate to below 0.15 (15%) for secure key generation.`;
        } else if (responseData.error) {
          errorMessage = responseData.error;

          if (responseData.error.includes('target_key_length')) {
            suggestion = 'Please enter a key length between 1 and 256 bits.';
          } else if (responseData.error.includes('channel_error_rate')) {
            suggestion = 'Please enter an error rate between 0.0 and 0.5 (0% to 50%).';
          }
        } else {
          errorMessage = responseData.message || 'Bad request';
        }
      } else if (error.response?.status === 500) {
        errorMessage = 'Server error occurred';
        suggestion = 'The simulation server encountered an error. Please try again.';
      } else if (error.code === 'NETWORK_ERROR' || !error.response) {
        errorMessage = 'Cannot connect to simulation server';
        suggestion = 'Please check that the backend server is running on port 3001.';
      } else {
        errorMessage = error.response?.data?.message || error.message;
      }

      setSimulationResult({
        error: true,
        message: errorMessage,
        suggestion: suggestion,
        qber: error.response?.data?.estimatedQBER,
        sessionId: error.response?.data?.sessionId
      });
    } finally {
      setIsSimulating(false);
    }
  };

  const handleParamChange = (param, value) => {
    setQkdParams(prev => ({
      ...prev,
      [param]: value
    }));
  };

  // File encryption handlers
  const handleFileSelect = (event) => {
    const file = event.target.files[0];
    setSelectedFile(file);
    setEncryptionResult(null);
  };

  const handleEncryptedFileSelect = (event) => {
    const file = event.target.files[0];
    setSelectedEncryptedFile(file);
    setEncryptionResult(null);
  };

  const handleEncryptFile = async () => {
    if (!selectedFile || !selectedKey) return;

    setIsProcessing(true);
    setEncryptionResult(null);

    try {
      // Create FormData for file upload
      const formData = new FormData();
      formData.append('file', selectedFile);
      formData.append('sessionId', selectedKey.sessionId);

      const response = await axios.post(`${apiUrl}/api/v1/encrypt-file`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        responseType: 'blob'
      });

      // Create download URL for encrypted file
      const blob = new Blob([response.data], { type: 'application/octet-stream' });
      const downloadUrl = window.URL.createObjectURL(blob);
      const filename = `${selectedFile.name}.enc`;

      setEncryptionResult({
        success: true,
        message: `File "${selectedFile.name}" encrypted successfully using quantum-derived key.`,
        downloadUrl,
        filename,
        operation: 'encrypt'
      });

    } catch (error) {
      console.error('File encryption failed:', error);
      setEncryptionResult({
        success: false,
        message: error.response?.data?.message || 'File encryption failed. Please try again.',
        operation: 'encrypt'
      });
    } finally {
      setIsProcessing(false);
    }
  };

  const handleDecryptFile = async () => {
    if (!selectedEncryptedFile || !selectedKey) return;

    setIsProcessing(true);
    setEncryptionResult(null);

    try {
      // Create FormData for file upload
      const formData = new FormData();
      formData.append('file', selectedEncryptedFile);
      formData.append('sessionId', selectedKey.sessionId);

      const response = await axios.post(`${apiUrl}/api/v1/decrypt-file`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        responseType: 'blob'
      });

      // Create download URL for decrypted file
      const blob = new Blob([response.data]);
      const downloadUrl = window.URL.createObjectURL(blob);
      const filename = selectedEncryptedFile.name.replace('.enc', '');

      setEncryptionResult({
        success: true,
        message: `File "${selectedEncryptedFile.name}" decrypted successfully.`,
        downloadUrl,
        filename,
        operation: 'decrypt'
      });

    } catch (error) {
      console.error('File decryption failed:', error);
      setEncryptionResult({
        success: false,
        message: error.response?.data?.message || 'File decryption failed. Please check the file and key.',
        operation: 'decrypt'
      });
    } finally {
      setIsProcessing(false);
    }
  };

  const tabs = [
    { id: 'simulator', label: 'QKD Simulator', icon: '🔬' },
    { id: 'security', label: 'Security Dashboard', icon: '🛡️' },
    { id: 'encryption', label: 'File Encryption', icon: '🔐' }
  ];

  return (
    <div className="App">
      <header className="App-header">
        <div className="header-content">
          <h1>
            <span className="quantum-icon">⚛️</span>
            Quantum Key Distribution Simulator
          </h1>
          <div className="connection-status">
            <span className={`status-indicator ${isConnected ? 'connected' : 'disconnected'}`}>
              {isConnected ? '🟢' : '🔴'}
            </span>
            <span className="status-text">
              {isConnected ? 'Connected' : 'Disconnected'}
            </span>
          </div>
        </div>
      </header>

      <nav className="tab-navigation">
        {tabs.map(tab => (
          <button
            key={tab.id}
            className={`tab-button ${activeTab === tab.id ? 'active' : ''}`}
            onClick={() => setActiveTab(tab.id)}
          >
            <span className="tab-icon">{tab.icon}</span>
            {tab.label}
          </button>
        ))}
      </nav>

      <main className="main-content">
        {activeTab === 'simulator' && (
          <div className="content-panel">
            <h2>🔬 Quantum Key Distribution Simulator</h2>
            <p>Generate secure quantum keys using the BB84 protocol</p>

            <div className="qkd-simulator">
              <div className="simulation-controls">
                <h3>Simulation Parameters</h3>

                <div className="param-group">
                  <label htmlFor="keyLength">Target Key Length (bits):</label>
                  <input
                    id="keyLength"
                    type="number"
                    min="1"
                    max="256"
                    value={qkdParams.target_key_length}
                    onChange={(e) => handleParamChange('target_key_length', parseInt(e.target.value))}
                  />
                  <span className="param-info">1-256 bits</span>
                </div>

                <div className="param-group">
                  <label htmlFor="errorRate">Channel Error Rate:</label>
                  <input
                    id="errorRate"
                    type="number"
                    min="0"
                    max="0.5"
                    step="0.01"
                    value={qkdParams.channel_error_rate}
                    onChange={(e) => handleParamChange('channel_error_rate', parseFloat(e.target.value))}
                  />
                  <span className="param-info">0.0-0.5 (0% - 50%)</span>
                </div>

                <button
                  className="simulate-button"
                  onClick={runQkdSimulation}
                  disabled={isSimulating || !isConnected}
                >
                  {isSimulating ? '🔄 Simulating...' : '🚀 Run QKD Simulation'}
                </button>
              </div>

              {simulationResult && (
                <div className={`simulation-result ${simulationResult.error ? 'error' : 'success'}`}>
                  <h3>Simulation Result</h3>
                  {simulationResult.error ? (
                    <div className="error-message">
                      <p className="error-title">❌ {simulationResult.message}</p>
                      {simulationResult.suggestion && (
                        <div className="error-suggestion">
                          <p><strong>💡 What to do:</strong></p>
                          <p>{simulationResult.suggestion}</p>
                        </div>
                      )}
                      {simulationResult.qber && (
                        <div className="error-details">
                          <p><strong>📊 Technical Details:</strong></p>
                          <p>Estimated QBER: {(simulationResult.qber * 100).toFixed(2)}%</p>
                          {simulationResult.sessionId && (
                            <p>Session ID: <code style={{fontSize: '0.8rem', wordBreak: 'break-all'}}>{simulationResult.sessionId}</code></p>
                          )}
                        </div>
                      )}
                    </div>
                  ) : (
                    <div className="success-result">
                      <div className="result-grid">
                        <div className="result-item session-id">
                          <div className="result-item-content">
                            <span className="label">Session ID:</span>
                            <span className="value" style={{wordBreak: 'break-all', fontSize: '0.9rem'}}>{simulationResult.sessionId}</span>
                          </div>
                        </div>
                        <div className="result-item">
                          <div className="result-item-content">
                            <span className="label">Final Key Length:</span>
                            <span className="value">{simulationResult.finalKeyLength} bits</span>
                          </div>
                        </div>
                        <div className="result-item">
                          <div className="result-item-content">
                            <span className="label">Estimated QBER:</span>
                            <span className="value">{(simulationResult.estimatedQBER * 100).toFixed(2)}%</span>
                          </div>
                        </div>
                        <div className="result-item">
                          <div className="result-item-content">
                            <span className="label">Status:</span>
                            <span className="value success">✅ {simulationResult.message}</span>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {simulationHistory.length > 0 && (
                <div className="simulation-history">
                  <h3>Recent Simulations</h3>
                  <div className="history-list">
                    {simulationHistory.slice(0, 5).map((entry, index) => (
                      <div key={index} className="history-item">
                        <div className="history-summary">
                          <span className="timestamp">
                            {new Date(entry.timestamp).toLocaleTimeString()}
                          </span>
                          <span className="key-length">{entry.finalKeyLength} bits</span>
                          <span className="qber">{(entry.estimatedQBER * 100).toFixed(1)}% QBER</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        )}
        {activeTab === 'security' && (
          <div className="content-panel">
            <h2>🛡️ Security Dashboard</h2>
            <p>Monitor eavesdropping detection and security metrics</p>

            <div className="security-dashboard">
              {/* Security Status Overview */}
              <div className="security-overview">
                <div className="security-card">
                  <div className="security-metric">
                    <h3>🔒 Security Status</h3>
                    <div className="status-indicator">
                      {simulationHistory.length > 0 ? (
                        simulationHistory.slice(-5).every(sim => sim.estimatedQBER <= 0.15) ? (
                          <span className="status-secure">✅ SECURE</span>
                        ) : (
                          <span className="status-warning">⚠️ THREATS DETECTED</span>
                        )
                      ) : (
                        <span className="status-unknown">❓ NO DATA</span>
                      )}
                    </div>
                  </div>
                </div>

                <div className="security-card">
                  <div className="security-metric">
                    <h3>📊 Average QBER</h3>
                    <div className="metric-value">
                      {simulationHistory.length > 0 ? (
                        `${(simulationHistory.reduce((sum, sim) => sum + (sim.estimatedQBER || 0), 0) / simulationHistory.length * 100).toFixed(2)}%`
                      ) : (
                        'N/A'
                      )}
                    </div>
                  </div>
                </div>

                <div className="security-card">
                  <div className="security-metric">
                    <h3>🚨 Eavesdropping Detected</h3>
                    <div className="metric-value threat-count">
                      {simulationHistory.filter(sim => sim.estimatedQBER > 0.15).length}
                      <span className="threat-detail">
                        {simulationHistory.filter(sim => sim.estimatedQBER > 0.15).length > 0 ?
                          ' sessions with QBER > 15%' :
                          ' (QBER ≤ 15% = secure)'
                        }
                      </span>
                    </div>
                  </div>
                </div>

                <div className="security-card">
                  <div className="security-metric">
                    <h3>🔑 Keys Generated</h3>
                    <div className="metric-value">
                      {simulationHistory.filter(sim => sim.finalKeyLength > 0).length}
                    </div>
                  </div>
                </div>
              </div>

              {/* QBER Trend Chart */}
              {simulationHistory.length > 0 && (
                <div className="qber-chart">
                  <h3>📈 QBER Trend Analysis</h3>
                  <div className="chart-container">
                    <div className="chart-header">
                      <span className="chart-title">QBER (%)</span>
                      <span className="threshold-indicator">Security Threshold: 15%</span>
                    </div>
                    <div className="chart-area">
                      <div className="threshold-line"></div>
                      <div className="chart-bars">
                        {simulationHistory.slice(-10).map((sim, index) => (
                          <div key={index} className="chart-bar">
                            <div
                              className={`bar ${sim.estimatedQBER > 0.15 ? 'danger' : 'safe'}`}
                              style={{
                                height: `${Math.min((sim.estimatedQBER * 100 / 20) * 100, 100)}%`,
                                minHeight: '4px'
                              }}
                              title={`Session ${index + 1}: QBER ${(sim.estimatedQBER * 100).toFixed(2)}%`}
                            ></div>
                            <span className="bar-label">S{index + 1}</span>
                            <span className="bar-value">{(sim.estimatedQBER * 100).toFixed(1)}%</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Recent Security Events */}
              <div className="security-events">
                <h3>🔍 Recent Security Events</h3>
                {simulationHistory.length > 0 ? (
                  <div className="events-list">
                    {simulationHistory.slice(-5).reverse().map((sim, index) => (
                      <div key={index} className={`event-item ${sim.estimatedQBER > 0.15 ? 'threat' : 'normal'}`}>
                        <div className="event-icon">
                          {sim.estimatedQBER > 0.15 ? '🚨' : '✅'}
                        </div>
                        <div className="event-details">
                          <div className="event-title">
                            {sim.estimatedQBER > 0.15 ? 'Potential Eavesdropping Detected' : 'Secure Key Exchange'}
                          </div>
                          <div className="event-info">
                            QBER: {(sim.estimatedQBER * 100).toFixed(2)}% |
                            Key Length: {sim.finalKeyLength} bits |
                            {new Date(sim.timestamp).toLocaleString()}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="no-events">
                    <p>No security events recorded. Run some QKD simulations to see security metrics.</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
        {activeTab === 'encryption' && (
          <div className="content-panel">
            <h2>🔐 File Encryption</h2>
            <p>Encrypt and decrypt files using quantum-derived keys</p>

            <div className="file-encryption">
              {/* Available Keys Section */}
              <div className="available-keys">
                <h3>🔑 Available Quantum Keys</h3>
                {simulationHistory.filter(sim => sim.finalKeyLength > 0).length > 0 ? (
                  <div className="keys-list">
                    {simulationHistory
                      .filter(sim => sim.finalKeyLength > 0)
                      .slice(-3)
                      .reverse()
                      .map((sim, index) => (
                        <div key={index} className="key-item">
                          <div className="key-info">
                            <span className="key-id">Key #{simulationHistory.length - index}</span>
                            <span className="key-length">{sim.finalKeyLength} bits</span>
                            <span className="key-qber">QBER: {(sim.estimatedQBER * 100).toFixed(2)}%</span>
                            <span className="key-time">{new Date(sim.timestamp).toLocaleString()}</span>
                          </div>
                          <button
                            className="select-key-btn"
                            onClick={() => setSelectedKey(sim)}
                          >
                            {selectedKey === sim ? '✅ Selected' : 'Select'}
                          </button>
                        </div>
                      ))}
                  </div>
                ) : (
                  <div className="no-keys">
                    <p>No quantum keys available. Generate a successful QKD session first.</p>
                    <button
                      className="goto-simulator-btn"
                      onClick={() => setActiveTab('simulator')}
                    >
                      Go to QKD Simulator
                    </button>
                  </div>
                )}
              </div>

              {/* File Operations Section */}
              {selectedKey && (
                <div className="file-operations">
                  <div className="selected-key-info">
                    <h4>🔐 Using Key: {selectedKey.finalKeyLength} bits (QBER: {(selectedKey.estimatedQBER * 100).toFixed(2)}%)</h4>
                  </div>

                  {/* File Encryption */}
                  <div className="operation-section">
                    <h3>📤 Encrypt File</h3>
                    <div className="file-input-area">
                      <input
                        type="file"
                        id="file-to-encrypt"
                        onChange={handleFileSelect}
                        accept="*/*"
                      />
                      <label htmlFor="file-to-encrypt" className="file-input-label">
                        {selectedFile ? `📄 ${selectedFile.name}` : '📁 Choose file to encrypt'}
                      </label>
                    </div>
                    {selectedFile && (
                      <div className="file-details">
                        <p>File size: {(selectedFile.size / 1024).toFixed(2)} KB</p>
                        <button
                          className="encrypt-btn"
                          onClick={handleEncryptFile}
                          disabled={isProcessing}
                        >
                          {isProcessing ? '🔄 Encrypting...' : '🔒 Encrypt File'}
                        </button>
                      </div>
                    )}
                  </div>

                  {/* File Decryption */}
                  <div className="operation-section">
                    <h3>📥 Decrypt File</h3>
                    <div className="file-input-area">
                      <input
                        type="file"
                        id="file-to-decrypt"
                        onChange={handleEncryptedFileSelect}
                        accept=".enc"
                      />
                      <label htmlFor="file-to-decrypt" className="file-input-label">
                        {selectedEncryptedFile ? `🔐 ${selectedEncryptedFile.name}` : '📁 Choose .enc file to decrypt'}
                      </label>
                    </div>
                    {selectedEncryptedFile && (
                      <div className="file-details">
                        <p>Encrypted file size: {(selectedEncryptedFile.size / 1024).toFixed(2)} KB</p>
                        <button
                          className="decrypt-btn"
                          onClick={handleDecryptFile}
                          disabled={isProcessing}
                        >
                          {isProcessing ? '🔄 Decrypting...' : '🔓 Decrypt File'}
                        </button>
                      </div>
                    )}
                  </div>

                  {/* Operation Result */}
                  {encryptionResult && (
                    <div className={`operation-result ${encryptionResult.success ? 'success' : 'error'}`}>
                      <h4>{encryptionResult.success ? '✅ Operation Successful' : '❌ Operation Failed'}</h4>
                      <p>{encryptionResult.message}</p>
                      {encryptionResult.downloadUrl && (
                        <a
                          href={encryptionResult.downloadUrl}
                          download={encryptionResult.filename}
                          className="download-btn"
                        >
                          📥 Download {encryptionResult.operation === 'encrypt' ? 'Encrypted' : 'Decrypted'} File
                        </a>
                      )}
                    </div>
                  )}
                </div>
              )}

              {/* Security Notice */}
              <div className="security-notice">
                <h4>🛡️ Security Information</h4>
                <ul>
                  <li>Files are encrypted using AES-256 with quantum-derived keys</li>
                  <li>Keys are derived from successful QKD sessions with QBER ≤ 15%</li>
                  <li>Encrypted files have .enc extension and include metadata</li>
                  <li>This is a demonstration - do not use for actual sensitive data</li>
                </ul>
              </div>
            </div>
          </div>
        )}
      </main>

      <footer className="App-footer">
        <p>
          Quantum Key Distribution Simulator - Demonstrating BB84 Protocol
        </p>
        <p className="disclaimer">
          ⚠️ This is a simulation for educational purposes only
        </p>
      </footer>
    </div>
  );
}

export default App;
