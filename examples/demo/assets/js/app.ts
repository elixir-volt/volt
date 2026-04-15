import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { startClock } from "@/clock";

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content") ?? "";
const liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken } });

liveSocket.connect();

(window as any).liveSocket = liveSocket;

const clockEl = document.getElementById("volt-clock");
if (clockEl) startClock(clockEl);
