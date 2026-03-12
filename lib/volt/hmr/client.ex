defmodule Volt.HMR.Client do
  @moduledoc """
  Serves the HMR client JavaScript.
  """

  @client_js """
  (() => {
    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
    let ws;
    let reconnectTimer;

    function connect() {
      ws = new WebSocket(`${proto}//${location.host}/@volt/ws`);

      ws.onopen = () => {
        console.log('[Volt] HMR connected');
        clearTimeout(reconnectTimer);
      };

      ws.onmessage = (event) => {
        const { type, payload } = JSON.parse(event.data);

        if (type === 'update') {
          const { path, changes } = payload;

          if (changes.length === 1 && changes[0] === 'style') {
            updateStyles(path);
          } else {
            location.reload();
          }
        } else if (type === 'error') {
          showOverlay(payload.reason);
        } else if (type === 'remove') {
          location.reload();
        }
      };

      ws.onclose = () => {
        console.log('[Volt] Disconnected. Reconnecting...');
        reconnectTimer = setTimeout(connect, 1000);
      };
    }

    function updateStyles(path) {
      const links = document.querySelectorAll('link[rel="stylesheet"]');
      let updated = false;

      links.forEach(link => {
        const href = link.getAttribute('href');
        if (href && (href.includes(path) || path.endsWith('.css'))) {
          const url = new URL(link.href);
          url.searchParams.set('t', Date.now());
          link.href = url.toString();
          updated = true;
        }
      });

      if (!updated) {
        location.reload();
      }
    }

    function showOverlay(reason) {
      let overlay = document.getElementById('volt-error-overlay');
      if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'volt-error-overlay';
        overlay.style.cssText = 'position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.85);color:#ff6b6b;font:14px/1.6 monospace;padding:2em;white-space:pre-wrap;overflow:auto;cursor:pointer';
        overlay.onclick = () => overlay.remove();
        document.body.appendChild(overlay);
      }
      const msg = typeof reason === 'string' ? reason : JSON.stringify(reason, null, 2);
      overlay.textContent = '[Volt] Build error:\\n\\n' + msg;
    }

    connect();
  })();
  """

  @doc "Returns the HMR client JavaScript source."
  @spec js :: String.t()
  def js, do: @client_js
end
