import { useState, useMemo } from 'react'

export default function Counter() {
  const [count, setCount] = useState(0)
  const doubled = useMemo(() => count * 2, [count])

  return (
    <div>
      <button
        type="button"
        className="rounded-full bg-sky-600 px-5 py-2.5 font-semibold text-white shadow-md shadow-sky-600/25 transition hover:-translate-y-0.5 hover:bg-sky-700"
        onClick={() => setCount((v) => v + 1)}
      >
        Count is {count}
      </button>
      <p className="mt-3 text-sm text-slate-500">Doubled: {doubled}</p>
    </div>
  )
}
