import 'phoenix_html'
import { Socket } from 'phoenix'
import { LiveSocket } from 'phoenix_live_view'
import config from './config.json'
import Clock from './hooks/clock'
import EnvMode from './hooks/env-mode'

const pages = import.meta.glob('./pages/*.ts', { eager: true })
console.log(`${config.name} v${config.version}`, Object.keys(pages))

const hooks = { Clock, EnvMode }
const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
const liveSocket = new LiveSocket('/live', Socket, {
  hooks,
  params: { _csrf_token: csrfToken },
})

liveSocket.connect()

if (import.meta.hot) {
  import.meta.hot.accept()
}
