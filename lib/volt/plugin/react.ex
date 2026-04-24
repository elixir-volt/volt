defmodule Volt.Plugin.React do
  @moduledoc """
  Built-in React prebundle coordination for Volt dev mode.
  """

  @behaviour Volt.Plugin

  @react_exports ~w(
    Children
    Component
    Fragment
    Profiler
    PureComponent
    StrictMode
    Suspense
    cloneElement
    createContext
    createElement
    createRef
    forwardRef
    isValidElement
    lazy
    memo
    startTransition
    use
    useActionState
    useCallback
    useContext
    useDebugValue
    useDeferredValue
    useEffect
    useId
    useImperativeHandle
    useInsertionEffect
    useLayoutEffect
    useMemo
    useOptimistic
    useReducer
    useRef
    useState
    useSyncExternalStore
    useTransition
    version
  )

  @impl true
  def name, do: "react"

  @impl true
  def prebundle_alias("react-dom/client"), do: "react"
  def prebundle_alias("react/jsx-runtime"), do: "react"
  def prebundle_alias("react/jsx-dev-runtime"), do: "react"
  def prebundle_alias(_specifier), do: nil

  @impl true
  def prebundle_entry("react") do
    {:proxy, "react.js",
     imports: [%{default: "React", from: "react"}],
     exports: [
       %{default: "React"},
       %{members: Enum.map(@react_exports, &{&1, "React.#{&1}"})},
       %{
         named_from: "react-dom/client",
         names: ["createRoot", "hydrateRoot", {"version", "reactDomVersion"}]
       },
       %{named_from: "react/jsx-runtime", names: ["jsx", "jsxs"]}
     ]}
  end

  def prebundle_entry(_specifier), do: nil
end
