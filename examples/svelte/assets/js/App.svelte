<script>
  let count = 0
</script>

<main class="mx-auto mt-20 max-w-3xl rounded-3xl border border-emerald-200 bg-white p-10 shadow-2xl shadow-emerald-950/10">
  <p class="mb-3 text-xs font-bold uppercase tracking-widest text-emerald-500">Built-in Svelte plugin</p>
  <h1 class="text-5xl font-black tracking-tight text-slate-950 sm:text-7xl">Volt + Svelte</h1>
  <p class="mt-5 max-w-xl text-lg leading-8 text-slate-600">Svelte components compile through QuickBEAM using Volt's JS runtime.</p>
  <button type="button" class="mt-8 rounded-full bg-emerald-600 px-5 py-3 font-bold text-white shadow-lg shadow-emerald-600/25 transition hover:-translate-y-0.5 hover:bg-emerald-700" on:click={() => count += 1}>Count is {count}</button>
  <p class="mt-4 text-sm text-slate-500">State updates are handled by Svelte in the browser.</p>
</main>
