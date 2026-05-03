<script setup lang="ts">
defineProps<{ title: string }>()
</script>

<template>
  <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
    <h2 class="mb-3 text-xs font-bold uppercase tracking-widest text-slate-400">{{ title }}</h2>
    <slot />
  </div>
</template>
