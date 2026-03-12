defmodule DemoWeb.TodoLive do
  use DemoWeb, :live_view
  use LiveVueNext

  def mount(_params, _session, socket) do
    todos = [
      %{id: 1, text: "Set up Volt", done: true},
      %{id: 2, text: "Add live_vue_next", done: true},
      %{id: 3, text: "Ship it", done: false}
    ]

    {:ok, assign(socket, todos: todos, next_id: 4, filter: "all")}
  end

  def render(assigns) do
    ~VUE"""
    <div class="space-y-6 max-w-md mx-auto mt-12">
      <h1 class="text-3xl font-bold text-center">Todo List</h1>

      <form phx-submit="add" class="flex gap-2">
        <input type="text" name="text" class="flex-1 px-3 py-2 border rounded-lg" placeholder="What needs to be done?" />
        <button type="submit" class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition">Add</button>
      </form>

      <div class="flex justify-center gap-4 text-sm">
        <button phx-click="filter" phx-value-filter="all" :class="filter === 'all' ? 'font-bold underline' : 'text-gray-400'">All</button>
        <button phx-click="filter" phx-value-filter="active" :class="filter === 'active' ? 'font-bold underline' : 'text-gray-400'">Active</button>
        <button phx-click="filter" phx-value-filter="done" :class="filter === 'done' ? 'font-bold underline' : 'text-gray-400'">Done</button>
      </div>

      <ul class="space-y-2">
        <li v-for="todo in todos" class="flex items-center gap-2 p-3 border rounded-lg">
          <input type="checkbox" phx-click="toggle" :phx-value-id="todo.id" />
          <span :class="todo.done ? 'line-through text-gray-400' : ''">{{ todo.text }}</span>
          <button phx-click="delete" :phx-value-id="todo.id" class="ml-auto text-red-400 hover:text-red-600">✕</button>
        </li>
      </ul>

      <p class="text-center text-sm text-gray-400" v-if="todos.length === 0">No todos yet!</p>

      <nav class="text-center text-sm">
        <a href="/" class="text-blue-500 hover:underline">← Counter</a>
      </nav>
    </div>
    """
  end

  def handle_event("add", %{"text" => text}, socket) when text != "" do
    todo = %{id: socket.assigns.next_id, text: text, done: false}

    {:noreply,
     socket
     |> update(:todos, &(&1 ++ [todo]))
     |> update(:next_id, &(&1 + 1))}
  end

  def handle_event("add", _, socket), do: {:noreply, socket}

  def handle_event("toggle", %{"id" => id}, socket) do
    id = String.to_integer(id)

    todos =
      Enum.map(socket.assigns.todos, fn
        %{id: ^id} = todo -> %{todo | done: !todo.done}
        todo -> todo
      end)

    {:noreply, assign(socket, todos: apply_filter(todos, socket.assigns.filter))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    id = String.to_integer(id)
    todos = Enum.reject(socket.assigns.todos, &(&1.id == id))
    {:noreply, assign(socket, todos: todos)}
  end

  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, filter: filter)}
  end

  defp apply_filter(todos, "active"), do: Enum.filter(todos, &(!&1.done))
  defp apply_filter(todos, "done"), do: Enum.filter(todos, & &1.done)
  defp apply_filter(todos, _), do: todos
end
