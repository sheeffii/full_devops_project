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
import requests

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
    def do_GET(self):
        # Simple health endpoint
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'ok')
        else:
            self.send_response(404)
            self.end_headers()

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
                "timestamp": datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
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
            "embeds": embeds
        }

        headers = {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
            # Use a non-suspicious UA to avoid Cloudflare 403 (error 1010)
            'User-Agent': 'DiscordBot (https://github.com/team7/full_devops_project, 1.0)'
        }

        try:
            resp = requests.post(DISCORD_WEBHOOK_URL, json=payload, headers=headers, timeout=10)
            if 200 <= resp.status_code < 300:
                # Discord typically returns 204 No Content on success
                print("✅ Discord notification sent successfully")
                return
            # If embeds failed (e.g., Cloudflare 1010), try a minimal content-only fallback
            print(f"⚠️ Discord webhook returned status {resp.status_code} on embeds: {resp.text}", file=sys.stderr)
            fallback = {
                "content": self._fallback_text_from_embeds(embeds) or "Prometheus alert"
            }
            resp2 = requests.post(DISCORD_WEBHOOK_URL, json=fallback, headers=headers, timeout=10)
            if 200 <= resp2.status_code < 300:
                print("✅ Discord notification sent via content fallback")
                return
            print(f"❌ Discord webhook fallback failed: {resp2.status_code} {resp2.text}", file=sys.stderr)
        except requests.RequestException as e:
            print(f"❌ Failed to send Discord notification: {e}", file=sys.stderr)
            raise

    def _fallback_text_from_embeds(self, embeds):
        try:
            if not embeds:
                return None
            e = embeds[0]
            title = e.get('title') or ''
            desc = e.get('description') or ''
            summary_field = next((f for f in e.get('fields', []) if f.get('name') == 'Summary'), None)
            summary = summary_field.get('value') if summary_field else ''
            parts = [p for p in [title, summary, desc] if p]
            return ' | '.join(parts)[:1900]  # stay under Discord limits
        except Exception:
            return None
    
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
