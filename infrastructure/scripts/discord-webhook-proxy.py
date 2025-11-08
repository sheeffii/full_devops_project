#!/usr/bin/env python3
"""
Discord Webhook Proxy for Prometheus Alertmanager
Converts Alertmanager webhook format to Discord embeds
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime

DISCORD_WEBHOOK_URL = os.environ.get('DISCORD_WEBHOOK_URL')
if not DISCORD_WEBHOOK_URL:
    print("ERROR: DISCORD_WEBHOOK_URL environment variable not set", file=sys.stderr)
    sys.exit(1)

# Color mapping for severities
SEVERITY_COLORS = {
    'critical': 0xDC143C,  # Crimson
    'warning': 0xFF8C00,   # Dark Orange
    'info': 0x1E90FF       # Dodger Blue
}

class AlertmanagerHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        try:
            alertmanager_payload = json.loads(post_data.decode('utf-8'))
            discord_embeds = self.convert_to_discord(alertmanager_payload)
            
            # Send to Discord
            self.send_to_discord(discord_embeds)
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "ok"}')
            
        except Exception as e:
            print(f"Error processing alert: {e}", file=sys.stderr)
            self.send_response(500)
            self.end_headers()
    
    def convert_to_discord(self, payload):
        """Convert Alertmanager webhook to Discord embeds"""
        embeds = []
        
        for alert in payload.get('alerts', []):
            status = alert.get('status', 'unknown')
            labels = alert.get('labels', {})
            annotations = alert.get('annotations', {})
            
            alertname = labels.get('alertname', 'Unknown Alert')
            severity = labels.get('severity', 'info')
            instance = labels.get('instance', 'N/A')
            
            # Determine color based on status and severity
            if status == 'resolved':
                color = 0x00FF00  # Green
                title_prefix = "✅ RESOLVED"
            elif severity == 'critical':
                color = SEVERITY_COLORS['critical']
                title_prefix = "🔥 CRITICAL"
            elif severity == 'warning':
                color = SEVERITY_COLORS['warning']
                title_prefix = "⚠️ WARNING"
            else:
                color = SEVERITY_COLORS['info']
                title_prefix = "ℹ️ INFO"
            
            # Build embed
            embed = {
                "title": f"{title_prefix}: {alertname}",
                "color": color,
                "fields": [
                    {
                        "name": "Instance",
                        "value": instance,
                        "inline": True
                    },
                    {
                        "name": "Severity",
                        "value": severity.upper(),
                        "inline": True
                    },
                    {
                        "name": "Status",
                        "value": status.upper(),
                        "inline": True
                    }
                ],
                "timestamp": datetime.utcnow().isoformat()
            }
            
            # Add description if available
            if 'description' in annotations:
                embed['description'] = annotations['description']
            
            # Add summary if available
            if 'summary' in annotations:
                embed['fields'].insert(0, {
                    "name": "Summary",
                    "value": annotations['summary'],
                    "inline": False
                })
            
            # Add additional labels as fields
            for key, value in labels.items():
                if key not in ['alertname', 'severity', 'instance']:
                    embed['fields'].append({
                        "name": key.capitalize(),
                        "value": str(value),
                        "inline": True
                    })
            
            embeds.append(embed)
        
        return embeds
    
    def send_to_discord(self, embeds):
        """Send embeds to Discord webhook"""
        payload = {
            "username": "Prometheus Alert",
            "avatar_url": "https://prometheus.io/assets/prometheus_logo_grey.svg",
            "embeds": embeds
        }
        
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            DISCORD_WEBHOOK_URL,
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        
        try:
            with urllib.request.urlopen(req) as response:
                if response.status == 204:
                    print(f"✅ Discord notification sent successfully")
                else:
                    print(f"⚠️ Discord webhook returned status {response.status}", file=sys.stderr)
        except urllib.error.HTTPError as e:
            error_body = e.read().decode('utf-8') if e.fp else 'No error details'
            print(f"❌ Discord API error {e.code}: {e.reason}", file=sys.stderr)
            print(f"   Webhook URL (first 60 chars): {DISCORD_WEBHOOK_URL[:60]}...", file=sys.stderr)
            print(f"   Response: {error_body}", file=sys.stderr)
            raise
        except Exception as e:
            print(f"❌ Failed to send Discord notification: {e}", file=sys.stderr)
            raise
    
    def log_message(self, format, *args):
        """Override to reduce logging noise"""
        print(f"{self.address_string()} - {format % args}")

def run_server(port=9094):
    server_address = ('', port)
    httpd = HTTPServer(server_address, AlertmanagerHandler)
    print(f"Discord webhook proxy listening on port {port}...")
    print(f"Forwarding to: {DISCORD_WEBHOOK_URL[:50]}...")
    httpd.serve_forever()

if __name__ == '__main__':
    run_server()
