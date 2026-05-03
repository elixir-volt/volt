<script setup lang="ts">
import { computed, ref } from 'vue'

const count = ref(0)
const doubled = computed(() => count.value * 2)
</script>

<template>
  <div>
    <button
      type="button"
      class="rounded-full bg-indigo-600 px-5 py-2.5 font-semibold text-white shadow-md shadow-indigo-600/25 transition hover:-translate-y-0.5 hover:bg-indigo-700"
      @click="count++"
    >
      Count is {{ count }}
    </button>
    <p class="mt-3 text-sm text-slate-500">Doubled: {{ doubled }}</p>
  </div>
</template>
