# Environment Variables

## `.env` Files

Create `.env` files in your project root:

```
VOLT_API_URL=https://api.example.com
VOLT_DEBUG=true
```

Only variables prefixed with `VOLT_` are exposed to client code.

## Accessing Variables

```typescript
console.log(import.meta.env.VOLT_API_URL)
console.log(import.meta.env.MODE)  // "development" or "production"
console.log(import.meta.env.DEV)   // true/false
console.log(import.meta.env.PROD)  // true/false
```

## File Loading Order

Files are loaded in order, with later files overriding earlier ones:

1. `.env`
2. `.env.local`
3. `.env.{mode}` (e.g. `.env.production`)
4. `.env.{mode}.local`

The mode defaults to `"production"` for `mix volt.build` and `"development"` for the dev server. Override with `--mode`.

> #### Security {: .warning}
>
> Environment variables are embedded into the built JavaScript at compile time. Never put secrets or API keys in `VOLT_*` variables — they will be visible in the client bundle.
