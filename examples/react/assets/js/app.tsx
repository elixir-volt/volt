import React, { useMemo, useState } from 'react'
import { createRoot } from 'react-dom/client'

function App() {
  const [count, setCount] = useState(0)
  const doubled = useMemo(() => count * 2, [count])

  return (
    <main className="mx-auto mt-20 max-w-3xl rounded-3xl border border-sky-200/70 bg-white/90 p-10 shadow-2xl shadow-sky-950/10">
      <p className="mb-3 text-xs font-bold uppercase tracking-[0.18em] text-sky-500">
        Plain TSX pipeline
      </p>
      <h1 className="text-5xl font-black tracking-[-0.06em] text-slate-950 sm:text-7xl">
        Volt + React
      </h1>
      <p className="mt-5 max-w-xl text-lg leading-8 text-slate-600">
        React works with packages resolved by npm_ex.
      </p>
      <button
        type="button"
        className="mt-8 rounded-full bg-sky-600 px-5 py-3 font-bold text-white shadow-lg shadow-sky-600/25 transition hover:-translate-y-0.5 hover:bg-sky-700"
        onClick={() => setCount((value) => value + 1)}
      >
        Count is {count}
      </button>
      <p className="mt-4 text-sm text-slate-500">Doubled: {doubled}</p>
    </main>
  )
}

createRoot(document.getElementById('app')!).render(<App />)
