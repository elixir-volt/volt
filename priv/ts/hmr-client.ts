const proto = location.protocol === "https:" ? "wss:" : "ws:";

let ws: WebSocket | undefined;
let reconnectTimer: ReturnType<typeof setTimeout> | undefined;

function connect() {
  ws = new WebSocket(`${proto}//${location.host}/@volt/ws`);

  ws.onopen = () => {
    console.log("[Volt] HMR connected");

    if (reconnectTimer) {
      clearTimeout(reconnectTimer);
    }
  };

  ws.onmessage = (event) => {
    const { type, payload } = JSON.parse(event.data) as {
      type: "update" | "error" | "remove";
      payload: { path?: string; changes?: string[]; reason?: unknown };
    };

    if (type === "update") {
      const path = payload.path ?? "";
      const changes = payload.changes ?? [];

      if (changes.length === 1 && changes[0] === "style") {
        updateStyles(path);
      } else {
        location.reload();
      }

      return;
    }

    if (type === "error") {
      showOverlay(payload.reason);
      return;
    }

    location.reload();
  };

  ws.onclose = () => {
    console.log("[Volt] Disconnected. Reconnecting...");
    reconnectTimer = setTimeout(connect, 1000);
  };
}

function updateStyles(path: string) {
  const links = document.querySelectorAll<HTMLLinkElement>('link[rel="stylesheet"]');
  let updated = false;

  for (const link of links) {
    const href = link.getAttribute("href");

    if (href && (href.includes(path) || path.endsWith(".css"))) {
      const url = new URL(link.href);
      url.searchParams.set("t", Date.now().toString());
      link.href = url.toString();
      updated = true;
    }
  }

  if (!updated) {
    location.reload();
  }
}

function showOverlay(reason: unknown) {
  let overlay = document.getElementById("volt-error-overlay");

  if (!overlay) {
    overlay = document.createElement("div");
    overlay.id = "volt-error-overlay";
    overlay.style.cssText =
      "position:fixed;inset:0;z-index:99999;background:rgba(0,0,0,0.85);color:#ff6b6b;font:14px/1.6 monospace;padding:2em;white-space:pre-wrap;overflow:auto;cursor:pointer";
    overlay.onclick = () => overlay?.remove();
    document.body.appendChild(overlay);
  }

  const message = typeof reason === "string" ? reason : JSON.stringify(reason, null, 2);
  overlay.textContent = `[Volt] Build error:\n\n${message}`;
}

connect();
