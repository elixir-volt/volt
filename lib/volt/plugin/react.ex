defmodule Volt.Plugin.React do
  @moduledoc """
  Built-in React prebundle coordination for Volt dev mode.
  """

  @behaviour Volt.Plugin

  alias Volt.JS.PrebundleEntry.{Export, Import}

  @react_exports ~w(
    Activity
    Children
    Component
    Fragment
    Profiler
    PureComponent
    StrictMode
    Suspense
    __CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE
    __COMPILER_RUNTIME
    act
    cache
    cacheSignal
    captureOwnerStack
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
    useEffectEvent
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
  def prebundle_externals do
    [
      "react",
      "react-dom/client",
      "react/jsx-runtime",
      "react/jsx-dev-runtime"
    ]
  end

  @impl true
  def prebundle_entry("react") do
    {:proxy, "react.js",
     imports: [Import.default("React", from: "react")],
     exports: [
       Export.default("React"),
       Export.members(Enum.map(@react_exports, &{&1, "React.#{&1}"})),
       Export.named_from("react-dom/client", [
         "createRoot",
         "hydrateRoot",
         {"version", "reactDomVersion"}
       ]),
       Export.named_from("react/jsx-runtime", ["jsx", "jsxs"]),
       Export.named_from("react/jsx-dev-runtime", ["jsxDEV"])
     ]}
  end

  def prebundle_entry(_specifier), do: nil
end
