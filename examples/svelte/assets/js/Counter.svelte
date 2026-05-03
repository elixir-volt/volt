<script>
  let count = $state(0)
  let doubled = $derived(count * 2)
</script>

<div>
  <button
    type="button"
    class="rounded-full bg-emerald-600 px-5 py-2.5 font-semibold text-white shadow-md shadow-emerald-600/25 transition hover:-translate-y-0.5 hover:bg-emerald-700"
    onclick={() => count++}
  >
    Count is {count}
  </button>
  <p class="mt-3 text-sm text-slate-500">Doubled: {doubled}</p>
</div>
