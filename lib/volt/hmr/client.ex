defmodule Volt.HMR.Client do
  @moduledoc """
  Serves the HMR client JavaScript.
  """

  @client_js """
  (() => {
    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
    const ws = new WebSocket(`${proto}//${location.host}/@volt/ws`);

    ws.onmessage = (event) => {
      const { type, payload } = JSON.parse(event.data);

      if (type === 'update') {
        const { path, changes } = payload;

        if (changes.includes('style') && changes.length === 1) {
          updateStyles(path);
        } else if (changes.includes('full') || changes.includes('script')) {
          location.reload();
        } else if (changes.includes('template')) {
          location.reload();
        }
      } else if (type === 'error') {
        showOverlay(payload.reason);
      } else if (type === 'remove') {
        location.reload();
      }
    };

    ws.onclose = () => {
      console.log('[Volt] Connection lost. Reconnecting...');
      setTimeout(() => location.reload(), 1000);
    };

    function updateStyles(path) {
      const links = document.querySelectorAll('link[rel="stylesheet"]');
      links.forEach(link => {
        if (link.href.includes(path)) {
          const url = new URL(link.href);
          url.searchParams.set('t', Date.now());
          link.href = url.toString();
        }
      });

      const styles = document.querySelectorAll('style[data-volt-path]');
      styles.forEach(style => {
        if (style.dataset.voltPath === path) {
          fetch(`${location.origin}/${path}?type=style&t=${Date.now()}`)
            .then(r => r.text())
            .then(css => { style.textContent = css; });
        }
      });

      if (links.length === 0 && styles.length === 0) {
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

    console.log('[Volt] HMR connected');
  })();
  """

  @doc "Returns the HMR client JavaScript source."
  @spec js :: String.t()
  def js, do: @client_js
end
