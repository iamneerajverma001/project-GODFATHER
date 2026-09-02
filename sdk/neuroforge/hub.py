import http.server
import socketserver
import json
import threading

class SwarmHubHandler(http.server.SimpleHTTPRequestHandler):
    """
    The Global Registry for Project GODFATHER Swarm Intelligence.
    Accepts AES-encrypted STDP telemetry from edge chips and broadcasts
    it to all connected agents in the mesh.
    """
    
    # In-memory ledger of encrypted STDP weights
    global_ledger = []

    def do_POST(self):
        if self.path == '/push':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            payload = json.loads(post_data.decode('utf-8'))
            
            puf_id = payload.get("puf_id")
            encrypted_weights = payload.get("encrypted_payload")
            
            print(f"\n[SwarmHub] Received Encrypted STDP Blob from Agent {puf_id[:8]}...")
            SwarmHubHandler.global_ledger.append({
                "source": puf_id,
                "payload": encrypted_weights
            })
            
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"SwarmHub: Payload accepted and added to global ledger.")
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        if self.path == '/sync':
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(SwarmHubHandler.global_ledger).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

def launch_swarm_hub(port=9999):
    print(f"SwarmHub: Initializing Global Zero-Trust P2P Registry on port {port}...")
    with socketserver.TCPServer(("", port), SwarmHubHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nSwarmHub: Shutting down.")
