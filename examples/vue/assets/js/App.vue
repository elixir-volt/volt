<script setup lang="ts">
import config from './config.json'
import logo from '../images/volt.svg'
import Counter from './Counter.vue'
import Card from './Card.vue'

const pages = import.meta.glob('./pages/*.ts', { eager: true }) as Record<
  string,
  { title: string; description: string }
>

const mode = import.meta.env.MODE
</script>

<template>
  <main class="mx-auto mt-12 max-w-2xl space-y-8 px-6 pb-12">
    <header class="flex items-center gap-4">
      <img :src="logo" alt="" class="h-10 w-10 text-indigo-500" />
      <div>
        <h1 class="text-4xl font-black tracking-tight text-slate-950">
          {{ config.name }} + Vue
        </h1>
        <p class="text-sm text-slate-500">v{{ config.version }}</p>
      </div>
    </header>

    <Card title="Counter">
      <Counter />
    </Card>

    <Card title="Pages (glob import)">
      <ul class="space-y-2">
        <li
          v-for="[path, mod] in Object.entries(pages)"
          :key="path"
          class="flex items-baseline gap-2"
        >
          <span class="font-semibold text-slate-800">{{ mod.title }}</span>
          <span class="text-sm text-slate-500">{{ mod.description }}</span>
        </li>
      </ul>
    </Card>

    <footer class="text-center text-xs text-slate-400">
      Mode: {{ mode }}
    </footer>
  </main>
</template>
