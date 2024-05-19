import React, { useState } from 'react';
import { Tab, Tabs, AppBar, makeStyles } from '@material-ui/core';
import ReactJson from 'react-json-view';
import './App.css';

function App() {
  const [url, setUrl] = useState('');
  const [response, setResponse] = useState(null);
  const [exportResponse, setExportResponse] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isImporting, setIsImporting] = useState(false);
  const [isExporting, setIsExporting] = useState(false);

  const [tabValue, setTabValue] = useState(0);

  const handleTabChange = (event, newValue) => {
    setTabValue(newValue);
  };

  const useStyles = makeStyles({
    root: {
      backgroundColor: '#000000', // Replace 'yourColor' with the color you want
    },
  });

  const handleAnalyze = async () => {
    setIsLoading(true);
    setResponse(null); // Clear the previous response
    try {
      const res = await fetch(`/api/analyze?website_url=${encodeURIComponent(url)}`);
      const data = await res.json();
      if (!res.ok || data.error) {
        console.error(data);
        setResponse({ success: 0, message: data.error || 'Request failed with status: ' + res.status });
        setIsLoading(false); // Stop spinner on error
        return;
      }
      setResponse({ success: 1, message: 'Request successful', data: data });
    } catch (error) {
      console.error(error);
      setResponse({ success: 0, message: 'Request failed' });
      setIsLoading(false); // Stop spinner on error
    }
    setIsLoading(false); // Stop spinner on success
  };

  const handleImport = async () => {
    setIsImporting(true);
    try {
      const res = await fetch('/api/import', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(response.data),
      });
      const data = await res.json();
      if (!res.ok || data.error) {
        console.error(data);
        setResponse({ success: 0, message: data.error || 'Import failed with status: ' + res.status });
        setIsImporting(false); // Stop spinner on error
        return;
      }
      setResponse({ success: 1, message: 'Import successful' });
      setIsLoading(false); // Clear the previous response
    } catch (error) {
      console.error(error);
      setResponse({ success: 0, message: 'Import failed' });
      setIsImporting(false); // Stop spinner on error
    }
    setIsImporting(false); // Stop spinner on success
  };

  const handleExport = async () => {
    setIsExporting(true); // Start spinner
    setExportResponse(null); // Clear the previous export response
    try {
      const res = await fetch('/api/export');
      const data = await res.json();
      if (!res.ok || data.error) {
        console.error(data);
        setExportResponse({ success: 0, message: data.error || 'Export failed with status: ' + res.status });
        setIsExporting(false); // Stop spinner on error
        return;
      }
      setExportResponse({ success: 1, data: data });
    } catch (error) {
      console.error(error);
      setExportResponse({ success: 0, message: 'Export failed' });
      setIsExporting(false); // Stop spinner on error
    }
    setIsExporting(false); // Stop spinner on success
  };

  const classes = useStyles();

  return (
      <div className="App">
        <AppBar position="static" className={classes.root}>
          <Tabs value={tabValue} onChange={handleTabChange}>
            <Tab label="Analyze & Import" />
            <Tab label="Export" />
          </Tabs>
        </AppBar>
        {tabValue === 0 && (
            <header className="App-header">
              <div className="App-header-content">
                <h1>Airtable GPT - Competitor Analyzer & Importer</h1>
                <input
                    type="text"
                    value={url}
                    onChange={e => setUrl(e.target.value)}
                    placeholder="Enter website URL"
                />
                <button onClick={handleAnalyze} disabled={isLoading}>Analyze</button>
                {response && response.success && !isImporting ? (
                    <button onClick={handleImport}>Import</button>
                ) : null}
                {isLoading || isImporting ? (
                    <div className="loading-container">
                      <div className="spinner"></div>
                      <div>{isLoading ? 'Loading...' : 'Importing...'}</div>
                    </div>
                ) : null}
                {response ? (
                    <div className={`response ${response.success ? 'success' : 'failure'}`}>
                      {response.message}
                    </div>
                ) : null}
                {response && response.success ? (
                    <textarea className="jsonOutput" readOnly value={JSON.stringify(response.data, null, 2)}/>
                ) : null}
                {/*{response && response.success ? (*/}
                {/*    <ReactJson src={response.data} theme="monokai" collapsed={2} />*/}
                {/*) : null}*/}
              </div>
            </header>
          )}
        {tabValue === 1 && (
            <header className="App-header">
              <div className="App-header-content">
                <h1>Airtable GPT - Competitor Exporter</h1>
                <div>
                  <button onClick={handleExport}>Export</button>
                  {isExporting ? (
                      <div className="loading-container">
                        <div className="spinner"></div>
                        <div>Exporting...</div>
                      </div>
                  ) : null}
                  {exportResponse && exportResponse.success && (
                      <textarea className="jsonOutput" readOnly value={JSON.stringify(exportResponse.data, null, 2)}/>
                  )}
                </div>
              </div>
            </header>
          )}
      </div>
  );
}

export default App;