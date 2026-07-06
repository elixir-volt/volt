import { removeStyle as __volt_removeStyle, updateStyle as __volt_updateStyle } from '../hmr'

const __volt_id = $id
const __volt_css = $css

__volt_updateStyle(__volt_id, __volt_css)

if (import.meta.hot) {
  import.meta.hot.accept()
  import.meta.hot.dispose(() => __volt_removeStyle(__volt_id))
}
