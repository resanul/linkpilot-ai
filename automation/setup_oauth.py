"""LinkPilot AI - LinkedIn OAuth 2.0 Token Helper
Run this script locally on your computer to authenticate with LinkedIn
and obtain your 60-day Access Token for GitHub Secrets.
"""

import http.server
import os
import socketserver
import urllib.parse
import webbrowser
import requests

PORT = 8080
REDIRECT_URI = f"http://localhost:{PORT}/callback"
AUTH_URL = "https://www.linkedin.com/oauth/v2/authorization"
TOKEN_URL = "https://www.linkedin.com/oauth/v2/accessToken"
SCOPES = "openid profile w_member_social"

auth_code = None


class OAuthCallbackHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        global auth_code
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/callback":
            params = urllib.parse.parse_qs(parsed.query)
            if "code" in params:
                auth_code = params["code"][0]
                self.send_response(200)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(b"""
                <html>
                <body style="font-family:sans-serif; text-align:center; padding:50px;">
                    <h2 style="color:#2563EB;">&#10004; LinkedIn Authorization Successful!</h2>
                    <p>You can close this browser tab and return to your terminal.</p>
                </body>
                </html>
                """)
            else:
                error = params.get("error_description", ["Unknown error"])[0]
                self.send_response(400)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(f"<h3>Authorization failed: {error}</h3>".encode())

    def log_message(self, format, *args):
        # Suppress standard logging
        return


def main():
    print("=" * 60)
    print("🔑 LinkPilot AI - LinkedIn OAuth 2.0 Token Generator")
    print("=" * 60)
    print("\nPrerequisites:")
    print("1. Go to https://www.linkedin.com/developers/apps and select your App.")
    print("2. In the 'Auth' tab, ensure this Redirect URL is added:")
    print(f"   👉 {REDIRECT_URI}")
    print("3. In the 'Products' tab, ensure 'Share on LinkedIn' and 'Sign In with LinkedIn using OpenID Connect' are enabled.\n")

    client_id = input("Enter your LinkedIn Client ID: ").strip()
    client_secret = input("Enter your LinkedIn Client Secret: ").strip()

    if not client_id or not client_secret:
        print("[!] Client ID and Client Secret are required.")
        return

    state = os.urandom(16).hex()
    auth_params = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": REDIRECT_URI,
        "state": state,
        "scope": SCOPES,
    }

    url = f"{AUTH_URL}?{urllib.parse.urlencode(auth_params)}"

    print(f"\n[+] Opening browser for authorization...")
    print(f"[+] If it doesn't open automatically, visit this URL:\n{url}\n")
    webbrowser.open(url)

    # Start local server to catch redirect
    with socketserver.TCPServer(("", PORT), OAuthCallbackHandler) as httpd:
        print(f"[+] Waiting for callback on {REDIRECT_URI}...")
        while not auth_code:
            httpd.handle_request()

    print("[+] Authorization code received! Exchanging for Access Token...")

    token_data = {
        "grant_type": "authorization_code",
        "code": auth_code,
        "redirect_uri": REDIRECT_URI,
        "client_id": client_id,
        "client_secret": client_secret,
    }

    resp = requests.post(TOKEN_URL, data=token_data)
    if resp.status_code == 200:
        token_json = resp.json()
        access_token = token_json.get("access_token")
        expires_in = token_json.get("expires_in", 5184000)
        days = expires_in // 86400

        print("\n" + "=" * 60)
        print("🎉 SUCCESS! Your LinkedIn Access Token has been generated:")
        print("=" * 60)
        print(f"\n{access_token}\n")
        print("=" * 60)
        print(f"Valid for: ~{days} days")
        print("\nNext Step:")
        print("1. Go to your GitHub repository: https://github.com/resanul/linkpilot-ai/settings/secrets/actions")
        print("2. Click 'New repository secret'")
        print("3. Name: LINKEDIN_ACCESS_TOKEN")
        print(f"4. Value: (paste the token above)")
        print("=" * 60)
    else:
        print(f"\n[!] Token exchange failed ({resp.status_code}): {resp.text}")


if __name__ == "__main__":
    main()
