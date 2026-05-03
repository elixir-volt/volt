import type { ViewHook } from 'phoenix_live_view'

const Clock: Partial<ViewHook> = {
  mounted() {
    const el = this.el.querySelector('[data-time]') as HTMLElement
    const update = () => {
      el.textContent = new Date().toLocaleTimeString()
    }
    update()
    this.timer = setInterval(update, 1000)
  },
  destroyed() {
    clearInterval(this.timer)
  },
}

export default Clock
