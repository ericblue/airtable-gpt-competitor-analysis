import React, { useState } from 'react';
import { Tab, Tabs, AppBar, makeStyles } from '@material-ui/core';
import ReactJson from 'react-json-view';
import './App.css';

function App() {
  const [url, setUrl] = useState('');
  const [bulkUrls, setBulkUrls] = useState('');
  const [analyzeResponse, setAnalyzeResponse] = useState(null);
  const [bulkResponses, setBulkResponses] = useState({});
  const [bulkImportResponses, setBulkImportResponses] = useState({});
  const [exportResponse, setExportResponse] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isImporting, setIsImporting] = useState(false);
  const [importResponse, setImportResponse] = useState(null);
  const [isExporting, setIsExporting] = useState(false);
  const [currentUrlIndex, setCurrentUrlIndex] = useState(0);
  const [currentUrl, setCurrentUrl] = useState('');
  const [bulkImportDone, setBulkImportDone] = useState(false);
  const [tabValue, setTabValue] = useState(0);
  const [dryrun, setDryrun] = useState(false);
  const [useExistingFeatures, setUseExistingFeatures] = useState(true);



  React.useEffect(() => {
    console.log('Analyze response:', analyzeResponse);
  }, [analyzeResponse]);

  const handleTabChange = (event, newValue) => {
    setTabValue(newValue);
  };

  const useStyles = makeStyles({
    root: {
      backgroundColor: '#000000', // Replace 'yourColor' with the color you want
    },
  });

  const handleAnalyze = async (analyzeUrl) => {
    setIsLoading(true);
    setAnalyzeResponse(null);
    setImportResponse(null);

    try {
      console.log('Analyzing URL ' + analyzeUrl);
      const res = await fetch(`/api/analyze?website_url=${encodeURIComponent(analyzeUrl)}`);
      const data = await res.json();
      if (!res.ok || data.error) {
        console.error(data);
        console.log('!res.ok || data.error - Analyze failed for URL ' + analyzeUrl);
        setAnalyzeResponse({ success: 0, message: data.error || 'Analyze request failed with status: ' + res.status });
        setIsLoading(false); // Stop spinner on error
        return;
      }
      console.log('Analyze successful for URL ' + analyzeUrl);
      setAnalyzeResponse({ success: 1, message: 'Analyze request successful', data: data });
    } catch (error) {
      console.log('error - Analyze failed for URL ' + analyzeUrl)
      console.error(error);
      setAnalyzeResponse({ success: 0, message: 'Analyze request failed' });
      setIsLoading(false); // Stop spinner on error
    }
    setIsLoading(false); // Stop spinner on success
  };

  const handleImport = async (dryrun = false, importData) => {
    console.log('Import data:', importData); // Log the import data
    setIsImporting(true);
    setAnalyzeResponse(null);
    try {
      const res = await fetch(`/api/import?dryrun=${dryrun}&leverage_existing_features=${useExistingFeatures}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(importData),
      });
      const data = await res.json();
      if (!res.ok || data.error) {
        console.error(data);
        setImportResponse({ success: 0, message: data.error || 'Import failed with status: ' + res.status });
        setIsImporting(false);
        console.log('!res.ok || data.error - Import failed for URL ' + currentUrl);
        return;
      }
      console.log('Import successful for URL ' + currentUrl);
      setImportResponse({ success: 1, message: 'Import successful', data: data }); // Set the response data to the importResponse state
      setIsLoading(false);
    } catch (error) {
      console.log('error - Import failed for URL ' + currentUrl);
      console.error(error);
      setImportResponse({ success: 0, message: 'Import failed' });
      setIsImporting(false);
    }
    setIsImporting(false);
  };

  const handleBulkImport = async () => {

    let responses = {};

    // if bulkUrls is empty, return
    if (!bulkUrls) {
      responses['default'] = { success: 0, message: 'No URLs were provided' };
      setBulkImportResponses({...responses});
      return;
    }
    const urls = bulkUrls.split('\n');
    setAnalyzeResponse(null);
    setBulkImportResponses({});


    for (const url of urls) {
      setCurrentUrlIndex(urls.indexOf(url) + 1);
      setCurrentUrl(url);
      setIsLoading(true);

      try {
        const res = await fetch(`/api/analyze-and-import?website_url=${encodeURIComponent(url)}`);
        const data = await res.json();
        if (!res.ok || data.error) {
          console.error(data);
          responses[url] = { success: 0, message: data.error || 'Analyze and import request failed with status: ' + res.status };
          setIsLoading(false); // Stop spinner on error
          continue;
        }
        console.log('Analyze and import successful for URL ' + url);
        responses[url] = { success: 1, message: 'Analyze and import request successful', data: data };
        setBulkImportResponses({...responses});
      } catch (error) {
        console.log('error - Analyze and import failed for URL ' + url)
        console.error(error);
        responses[url] = { success: 0, message: 'Analyze and import request failed' };
        setBulkImportResponses({...responses});
        setIsLoading(false); // Stop spinner on error
      }
      setIsLoading(false); // Stop spinner on success
    }
    console.log('Responses object:', JSON.stringify(responses)); // Log the responses object
    setBulkImportDone(true); // Set bulkImportDone to true after the bulk import process is completed
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
            <Tab label="Bulk Analyze & Import" />
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
                <button onClick={() => handleAnalyze(url)} disabled={isLoading}>Analyze</button>
                {analyzeResponse && analyzeResponse.success && !isImporting ? (
                    <button onClick={() => handleImport(dryrun, analyzeResponse.data)}>Import</button>) : null}
                {isLoading || isImporting ? (
                    <div className="loading-container">
                      <div className="spinner"></div>
                      <div>{isLoading ? 'Loading...' : 'Importing...'}</div>
                    </div>
                ) : null}
                {analyzeResponse ? (
                    <div className={`response ${analyzeResponse.success ? 'success' : 'failure'}`}>
                      {analyzeResponse.message}
                    </div>
                ) : null}

                {importResponse ? (
                    <div className={`response ${importResponse.success ? 'success' : 'failure'}`}>
                      {importResponse.message}
                    </div>
                ) : null}

                {(analyzeResponse && analyzeResponse.success) || importResponse ? (
                    <textarea className="jsonOutput" readOnly value={JSON.stringify(importResponse || analyzeResponse.data, null, 2)}/>
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
        {tabValue === 2 && (
            <header className="App-header">
              <div className="App-header-content">
                <h1>Airtable GPT - Bulk Competitor Analyzer & Importer</h1>
                <textarea
                    value={bulkUrls}
                    onChange={e => setBulkUrls(e.target.value)}
                    placeholder="Enter website URLs, one per line"
                    style={{height: '200px', width: '500px'}} // Adjust the size as needed
                />
                <p></p>
                <input
                    type="checkbox"
                    checked={dryrun}
                    onChange={e => setDryrun(e.target.checked)}
                />
                <label className="label-spacing">Dry Run</label>
                <input
                    type="checkbox"
                    checked={useExistingFeatures}
                    onChange={e => setUseExistingFeatures(e.target.checked)}
                />
                <label className="label-spacing">Use Existing Features</label>
                <button onClick={handleBulkImport}>Bulk Import</button>
                {isLoading ? (
                    <div className="loading-container">
                      <div className="spinner"></div>
                      <div>Processing URL {currentUrlIndex} of {bulkUrls.split('\n').length}: {currentUrl}</div>
                    </div>
                ) : null}
                {bulkImportDone ? (
                    <div className="response success">
                      Bulk import completed successfully
                    </div>
                ) : null}
                {bulkImportDone ? (
                    <textarea className="jsonOutput" readOnly value={JSON.stringify(bulkImportResponses, null, 2)}/>
                ) : null}

              </div>
            </header>
        )}
      </div>
  );
}

export default App;