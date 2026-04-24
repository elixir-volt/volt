<script setup lang="ts">
import { computed, ref } from 'vue'

const count = ref(0)
const doubled = computed(() => count.value * 2)
</script>

<template>
  <main class="mx-auto mt-20 max-w-3xl rounded-3xl border border-indigo-200/70 bg-white/90 p-10 shadow-2xl shadow-indigo-950/10">
    <p class="mb-3 text-xs font-bold uppercase tracking-[0.18em] text-indigo-500">Built-in Vue plugin</p>
    <h1 class="text-5xl font-black tracking-[-0.06em] text-slate-950 sm:text-7xl">Volt + Vue</h1>
    <p class="mt-5 max-w-xl text-lg leading-8 text-slate-600">Single-file components compile through Volt without esbuild or Vite.</p>
    <button type="button" class="mt-8 rounded-full bg-indigo-600 px-5 py-3 font-bold text-white shadow-lg shadow-indigo-600/25 transition hover:-translate-y-0.5 hover:bg-indigo-700" @click="count++">
      Count is {{ count }}
    </button>
    <p class="mt-4 text-sm text-slate-500">Doubled: {{ doubled }}</p>
  </main>
</template>
