#!/usr/bin/env python3
"""stdio <-> HTTP Bruecke fuer MCP-Server.

Claude Desktop laedt in claude_desktop_config.json nur stdio-Server (command/args/env);
HTTP-Eintraege mit "type": "http" verwirft es ("Skipped invalid MCP server config entries").
Dieses Skript spricht stdio nach aussen und leitet jede JSON-RPC-Nachricht per HTTP POST
an den echten Server weiter -- inklusive Authorization-Header, den die Connector-UI nicht
setzen kann.

Konfiguration ueber Umgebungsvariablen:
  MCP_URL            Pflicht. Volle URL des MCP-Endpoints.
  MCP_TOKEN          Optional. Wird als "Authorization: Bearer <MCP_TOKEN>" gesendet.
  MCP_TIMEOUT        Sekunden pro HTTP-Request (Default 120).
  MCP_STARTUP_WAIT   Sekunden, die das initialize auf einen noch nicht laufenden
                     Server wartet (Default 120). Desktop startet die stdio-Server
                     beim App-Start -- laeuft der Docker-Stack da noch nicht, schlaegt
                     initialize fehl und Desktop versucht es NIE wieder: der Server
                     bleibt bis zum App-Neustart tot. Deshalb hier warten statt aufgeben.
  MCP_RETRY_WAIT     Sekunden, die ein normaler Request einen Neustart des Servers
                     ueberbrueckt (Default 45).

Nur Standardbibliothek, laeuft mit dem System-Python (3.9) ohne Installation.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

URL = os.environ.get('MCP_URL')
TOKEN = os.environ.get('MCP_TOKEN')
TIMEOUT = float(os.environ.get('MCP_TIMEOUT', '120'))
STARTUP_WAIT = float(os.environ.get('MCP_STARTUP_WAIT', '120'))
RETRY_WAIT = float(os.environ.get('MCP_RETRY_WAIT', '45'))

# Der Stack ist da, aber Puma noch nicht -- nginx antwortet dann mit einem Bad Gateway.
RETRYABLE_STATUS = (502, 503, 504)


def log(message):
    # Desktop schreibt stderr der stdio-Server in seine Logs.
    print(f'[mcp-http-bridge] {message}', file=sys.stderr, flush=True)


def send(message):
    print(json.dumps(message), flush=True)


def error_response(request_id, code, message):
    return {'jsonrpc': '2.0', 'id': request_id, 'error': {'code': code, 'message': message}}


def post(payload):
    """Sendet payload und liefert die Liste der enthaltenen JSON-RPC-Antworten."""
    request = urllib.request.Request(URL, data=json.dumps(payload).encode('utf-8'), method='POST')
    request.add_header('Content-Type', 'application/json')
    # Ohne text/event-stream im Accept antwortet ein Streamable-HTTP-Server mit 406.
    request.add_header('Accept', 'application/json, text/event-stream')
    if TOKEN:
        request.add_header('Authorization', f'Bearer {TOKEN}')

    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        content_type = response.headers.get('Content-Type', '')
        body = response.read().decode('utf-8', 'replace')

    if not body.strip():
        return []

    if 'text/event-stream' in content_type:
        chunks = [l[len('data:'):].strip() for l in body.splitlines() if l.startswith('data:')]
    else:
        chunks = [body]

    messages = []
    for chunk in chunks:
        if not chunk:
            continue
        try:
            messages.append(json.loads(chunk))
        except json.JSONDecodeError:
            log(f'Antwort ist kein JSON, verworfen: {chunk[:200]}')
    return messages


def post_with_retry(payload, budget):
    """Wie post(), ueberbrueckt aber einen noch nicht erreichbaren Server bis zu budget Sekunden.

    Wiederholt wird nur, was voruebergehend ist: Verbindungsfehler (Docker noch nicht oben)
    und Bad-Gateway-Antworten (nginx oben, Puma noch nicht). Ein 401 oder ein Anwendungsfehler
    wird sofort durchgereicht -- den behebt kein Warten.
    """
    deadline = time.monotonic() + budget
    delay = 1.0
    attempt = 0

    while True:
        attempt += 1
        try:
            return post(payload)
        except urllib.error.HTTPError as e:
            if e.code not in RETRYABLE_STATUS or time.monotonic() >= deadline:
                raise
            reason = f'HTTP {e.code}'
        except urllib.error.URLError as e:
            if time.monotonic() >= deadline:
                raise
            reason = f'{type(e).__name__}: {e.reason}'
        except OSError as e:
            if time.monotonic() >= deadline:
                raise
            reason = f'{type(e).__name__}: {e}'

        remaining = deadline - time.monotonic()
        if attempt == 1:
            log(f'{reason} -- Server nicht erreichbar, neuer Versuch fuer bis zu {remaining:.0f}s')
        time.sleep(min(delay, max(remaining, 0)))
        delay = min(delay * 2, 5.0)


def handle(line):
    try:
        message = json.loads(line)
    except json.JSONDecodeError:
        log(f'Eingabe ist kein JSON, verworfen: {line[:200]}')
        return

    # Notifications (ohne id) erwarten keine Antwort -- Antworten darauf wuerde der Client
    # als unaufgeforderte Nachricht sehen.
    request_id = message.get('id') if isinstance(message, dict) else None
    method = message.get('method') if isinstance(message, dict) else None

    # Scheitert initialize, ist der Server fuer Desktop dauerhaft tot -- dieser eine
    # Request bekommt deshalb das lange Budget.
    budget = STARTUP_WAIT if method == 'initialize' else RETRY_WAIT

    try:
        for response in post_with_retry(message, budget):
            send(response)
    except urllib.error.HTTPError as e:
        detail = e.read().decode('utf-8', 'replace')[:300]
        log(f'HTTP {e.code} von {URL}: {detail}')
        if request_id is not None:
            hint = ' (Token pruefen: MCP_TOKEN)' if e.code in (401, 403) else ''
            send(error_response(request_id, -32000, f'HTTP {e.code} vom MCP-Server{hint}: {detail}'))
    except Exception as e:  # noqa: BLE001 -- der Prozess darf an keinem Request sterben
        log(f'{type(e).__name__}: {e}')
        if request_id is not None:
            send(error_response(request_id, -32000, f'{type(e).__name__}: {e}'))


def main():
    if not URL:
        log('MCP_URL ist nicht gesetzt -- Abbruch.')
        return 1

    log(f'verbinde mit {URL} (Token: {"ja" if TOKEN else "nein"})')
    for line in sys.stdin:
        line = line.strip()
        if line:
            handle(line)
    return 0


if __name__ == '__main__':
    sys.exit(main())
