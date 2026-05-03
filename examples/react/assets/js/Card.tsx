export default function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
      <h2 className="mb-3 text-xs font-bold uppercase tracking-widest text-slate-400">{title}</h2>
      {children}
    </div>
  )
}
