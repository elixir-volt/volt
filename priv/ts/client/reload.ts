const RELOAD_DELAY = 20

let timer: ReturnType<typeof setTimeout> | undefined

// One save can produce several messages that each ask for a reload, such as a
// template that is also a Tailwind source. Reloading once covers all of them.
export function pageReload() {
  if (timer) clearTimeout(timer)
  timer = setTimeout(() => location.reload(), RELOAD_DELAY)
}
