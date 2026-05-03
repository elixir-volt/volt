import { createApp } from 'vue'
import App from './App.vue'

let app = createApp(App)
app.mount('#app')

if (import.meta.hot) {
  import.meta.hot.dispose(() => {
    app.unmount()
  })
  import.meta.hot.accept()
}
