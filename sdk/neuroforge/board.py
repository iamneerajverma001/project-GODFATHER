import http.server
import socketserver
import json
import os
import webbrowser

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>NeuroBoard - Project GODFATHER</title>
    <style>
        body { background-color: #0d1117; color: #c9d1d9; font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif; margin: 0; padding: 20px; }
        h1 { color: #58a6ff; text-align: center; font-weight: 300; letter-spacing: 2px;}
        .container { max-width: 1200px; margin: 0 auto; display: flex; gap: 20px; }
        .card { background-color: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 20px; flex: 1; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
        .card h2 { color: #8b949e; margin-top: 0; font-size: 1.2em; border-bottom: 1px solid #30363d; padding-bottom: 10px;}
        pre { background-color: #0d1117; padding: 15px; border-radius: 5px; overflow-x: auto; color: #79c0ff; border: 1px solid #30363d;}
        .highlight { color: #ff7b72; font-weight: bold; }
        .routing-node { display: inline-block; background: #238636; color: white; padding: 5px 10px; border-radius: 15px; margin: 5px; font-size: 0.9em; }
    </style>
</head>
<body>
    <h1>NEUROBOARD : SILICON TELEMETRY</h1>
    <div class="container">
        <div class="card">
            <h2>Power, Performance, Area (PPA)</h2>
            <pre id="ppa-content">Loading PPA Report...</pre>
        </div>
        <div class="card">
            <h2>3D NoC Routing Topology</h2>
            <div id="routing-content">Loading Routing Table...</div>
        </div>
    </div>

    <script>
        // Fetch PPA
        fetch('/ppa')
            .then(response => response.text())
            .then(text => document.getElementById('ppa-content').textContent = text)
            .catch(err => document.getElementById('ppa-content').textContent = 'PPA Report not found. Run `neuroforge profile` first.');

        // Fetch Routing
        fetch('/routing')
            .then(response => response.json())
            .then(data => {
                const container = document.getElementById('routing-content');
                container.innerHTML = '';
                for (const [layer, info] of Object.entries(data)) {
                    const node = document.createElement('div');
                    node.className = 'routing-node';
                    node.textContent = `${layer} -> [${info.physical_core}]`;
                    container.appendChild(node);
                }
            })
            .catch(err => document.getElementById('routing-content').textContent = 'Routing table not found. Run `neuroforge compile` first.');
    </script>
</body>
</html>
"""

class NeuroBoardHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode('utf-8'))
        elif self.path == '/ppa':
            try:
                with open('sdk/build/ppa_report.txt', 'r') as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-type", "text/plain")
                self.end_headers()
                self.wfile.write(content.encode('utf-8'))
            except FileNotFoundError:
                self.send_response(404)
                self.end_headers()
        elif self.path == '/routing':
            try:
                with open('sdk/build/noc_routing.json', 'r') as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(content.encode('utf-8'))
            except FileNotFoundError:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

def launch_dashboard(port=8080):
    print(f"NeuroForge: Launching NeuroBoard on http://localhost:{port}")
    webbrowser.open(f"http://localhost:{port}")
    with socketserver.TCPServer(("", port), NeuroBoardHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nNeuroForge: Shutting down NeuroBoard.")
