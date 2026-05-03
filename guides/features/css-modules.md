# CSS Modules

Files ending in `.module.css` get scoped class names via LightningCSS.

## Usage

```css
/* button.module.css */
.primary { color: blue }
.large { font-size: 2em }
```

```typescript
import styles from './button.module.css'
console.log(styles.primary) // "ewq3O_primary"
console.log(styles.large)   // "ewq3O_large"
```

The generated class names are unique per file, preventing style collisions across components.

## How It Works

Volt compiles `.module.css` files into two outputs:

1. **JavaScript module** — exports a mapping of original class names to scoped names
2. **Scoped CSS** — the original CSS with class names rewritten to their scoped equivalents

Both are handled automatically during development and production builds. The scoped CSS is included in the output bundle alongside any Tailwind or regular CSS.

## Framework Examples

### React

```tsx
import styles from './Card.module.css'

export default function Card({ children }) {
  return <div className={styles.card}>{children}</div>
}
```

### Vue

```vue
<script setup>
import styles from './Card.module.css'
</script>

<template>
  <div :class="styles.card"><slot /></div>
</template>
```

### Svelte

```svelte
<script>
  import styles from './Card.module.css'
  let { children } = $props()
</script>

<div class={styles.card}>{@render children()}</div>
```
