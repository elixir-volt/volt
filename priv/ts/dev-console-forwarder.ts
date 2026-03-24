const endpoint = "/@volt/console";
const levels = ["log", "info", "warn", "error", "debug"] as const;

declare global {
  interface Window {
    __voltConsoleForwarderInstalled?: boolean;
  }
}

type ConsoleLevel = (typeof levels)[number];

if (!window.__voltConsoleForwarderInstalled) {
  window.__voltConsoleForwarderInstalled = true;

  const original = Object.fromEntries(
    levels.map((level) => [level, console[level].bind(console)]),
  ) as Record<ConsoleLevel, (...args: unknown[]) => void>;

  for (const level of levels) {
    console[level] = (...args: unknown[]) => {
      send(level, args);
      original[level](...args);
    };
  }

  addEventListener("error", (event) => {
    send("error", [event.message, event.filename, event.lineno, event.colno]);
  });

  addEventListener("unhandledrejection", (event) => {
    send("error", ["Unhandled rejection", serialize(event.reason)]);
  });
}

function send(level: ConsoleLevel, args: unknown[]) {
  const payload = JSON.stringify({
    level,
    source: location.pathname,
    args: args.map(serialize),
  });

  if (navigator.sendBeacon) {
    const ok = navigator.sendBeacon(endpoint, new Blob([payload], { type: "application/json" }));

    if (ok) {
      return;
    }
  }

  fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: payload,
    keepalive: true,
  }).catch(() => {});
}

function serialize(value: unknown): unknown {
  if (typeof value === "string") {
    return value;
  }

  if (value instanceof Error) {
    return {
      name: value.name,
      message: value.message,
      stack: value.stack,
    };
  }

  try {
    return JSON.parse(JSON.stringify(value));
  } catch {
    try {
      return String(value);
    } catch {
      return "[unserializable]";
    }
  }
}
