import type { ViewHook } from 'phoenix_live_view'

const EnvMode: Partial<ViewHook> = {
  mounted() {
    this.el.textContent = import.meta.env.MODE
  },
}

export default EnvMode
