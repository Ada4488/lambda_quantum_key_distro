import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [activeTab, setActiveTab] = useState('simulator');
  const [apiUrl, setApiUrl] = useState('');
  const [isConnected, setIsConnected] = useState(false);

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
            <div className="coming-soon">
              <p>🚧 Component under development</p>
              <p>API URL: {apiUrl}</p>
            </div>
          </div>
        )}
        {activeTab === 'security' && (
          <div className="content-panel">
            <h2>🛡️ Security Dashboard</h2>
            <p>Monitor eavesdropping detection and security metrics</p>
            <div className="coming-soon">
              <p>🚧 Component under development</p>
            </div>
          </div>
        )}
        {activeTab === 'encryption' && (
          <div className="content-panel">
            <h2>🔐 File Encryption</h2>
            <p>Encrypt and decrypt files using quantum-derived keys</p>
            <div className="coming-soon">
              <p>🚧 Component under development</p>
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
