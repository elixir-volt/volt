import { createRoot } from 'react-dom/client'
import config from './config.json'
import logo from '../images/volt.svg'
import Counter from './Counter'
import Card from './Card'

const pages = import.meta.glob('./pages/*.ts', { eager: true }) as Record<
  string,
  { title: string; description: string }
>

function App() {
  return (
    <main className="mx-auto mt-12 max-w-2xl space-y-8 px-6 pb-12">
      <header className="flex items-center gap-4">
        <img src={logo} alt="" className="h-10 w-10 text-sky-500" />
        <div>
          <h1 className="text-4xl font-black tracking-tight text-slate-950">
            {config.name}{' '}+{' '}React
          </h1>
          <p className="text-sm text-slate-500">v{config.version}</p>
        </div>
      </header>

      <Card title="Counter">
        <Counter />
      </Card>

      <Card title="Pages (glob import)">
        <ul className="space-y-2">
          {Object.entries(pages).map(([path, mod]) => (
            <li key={path} className="flex items-baseline gap-2">
              <span className="font-semibold text-slate-800">{mod.title}</span>
              <span className="text-sm text-slate-500">{mod.description}</span>
            </li>
          ))}
        </ul>
      </Card>

      <footer className="text-center text-xs text-slate-400">
        Mode: {import.meta.env.MODE}
      </footer>
    </main>
  )
}

const root =
  (import.meta.hot?.data?.root as ReturnType<typeof createRoot>) ??
  createRoot(document.getElementById('app')!)

root.render(<App />)

if (import.meta.hot) {
  import.meta.hot.dispose((data) => {
    data.root = root
  })
  import.meta.hot.accept()
}
