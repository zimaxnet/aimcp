import { useState } from 'react'
import reactLogo from './assets/react.svg'
import viteLogo from '/vite.svg'
import './App.css'
import { useMsal, useIsAuthenticated } from '@azure/msal-react';

function AuthButtons() {
  const { instance, accounts } = useMsal();
  const isAuthenticated = useIsAuthenticated();
  const account = accounts[0];

  const handleLogin = () => {
    instance.loginRedirect();
  };
  const handleLogout = () => {
    instance.logoutRedirect();
  };

  if (!isAuthenticated) {
    return <button onClick={handleLogin}>Sign in with Microsoft Entra CIAM</button>;
  }
  return (
    <div style={{ marginBottom: 16 }}>
      <span>Signed in as <b>{account?.username}</b></span>
      <button style={{ marginLeft: 12 }} onClick={handleLogout}>Sign out</button>
    </div>
  );
}

function CallBackend() {
  const { instance, accounts } = useMsal();
  const isAuthenticated = useIsAuthenticated();
  const [response, setResponse] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const callApi = async () => {
    setLoading(true);
    setError(null);
    setResponse(null);
    try {
      const account = accounts[0];
      const result = await instance.acquireTokenSilent({
        scopes: ["api://cf6cfea3-fca3-4e29-94fa-bd7287c144b7/.default"],
        account,
      });
      const res = await fetch("https://aimcs-backend.azurewebsites.net/api/api", {
        headers: {
          Authorization: `Bearer ${result.accessToken}`,
        },
      });
      const text = await res.text();
      setResponse(text);
    } catch (err: any) {
      setError(err.message || "Unknown error");
    } finally {
      setLoading(false);
    }
  };

  if (!isAuthenticated) return null;

  return (
    <div style={{ marginBottom: 16 }}>
      <button onClick={callApi} disabled={loading}>
        {loading ? "Calling backend..." : "Call Backend"}
      </button>
      {response && (
        <div style={{ marginTop: 8, color: 'green' }}>Backend response: {response}</div>
      )}
      {error && (
        <div style={{ marginTop: 8, color: 'red' }}>Error: {error}</div>
      )}
    </div>
  );
}

function App() {
  const [count, setCount] = useState(0)

  return (
    <>
      <AuthButtons />
      <CallBackend />
      <div>
        <a href="https://vite.dev" target="_blank">
          <img src={viteLogo} className="logo" alt="Vite logo" />
        </a>
        <a href="https://react.dev" target="_blank">
          <img src={reactLogo} className="logo react" alt="React logo" />
        </a>
      </div>
      <h1>Vite + React</h1>
      <div className="card">
        <button onClick={() => setCount((count) => count + 1)}>
          count is {count}
        </button>
        <p>
          Edit <code>src/App.tsx</code> and save to test HMR
        </p>
      </div>
      <p className="read-the-docs">
        Click on the Vite and React logos to learn more
      </p>
    </>
  )
}

export default App
