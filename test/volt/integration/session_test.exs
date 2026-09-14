defmodule Volt.Integration.SessionTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :tmp_dir

  test "real filesystem edits update only their session", %{tmp_dir: root} do
    sessions =
      for label <- ["first", "second"] do
        directory = Path.join(root, label)
        File.mkdir_p!(directory)
        source = Path.join(directory, "app.css")
        dependency = Path.join(directory, "theme.css")
        File.write!(source, "@import './theme.css';")
        File.write!(dependency, ".#{label} { color: red }")
        session = make_ref()

        supervisor =
          start_supervised!(
            {Volt.Dev.Session.Supervisor,
             identity: session,
             watcher: [
               root: directory,
               session: session,
               name: nil,
               tailwind: true,
               tailwind_css: source,
               tailwind_sources: [],
               tailwind_url: "/assets/site.css"
             ]},
            id: session
          )

        config = %{
          Volt.DevServer.init(
            root: directory,
            watch: false,
            session: session,
            session_supervisor: supervisor
          )
          | stylesheet_url: "/assets/site.css",
            stylesheet_source: source
        }

        {session, supervisor, dependency, config}
      end

    [{first, _, dependency, config}, {second, _, _, other_config}] = sessions
    parent = self()

    subscribers =
      for session <- [first, second] do
        spawn_link(fn ->
          Registry.register(Volt.HMR.Registry, Volt.HMR.Channel.key(session), nil)
          send(parent, {:ready, self()})

          receive do
            {:check, caller} ->
              send(caller, {:mailbox, session, Process.info(self(), :messages)})

            {:volt_hmr, type, payload} ->
              send(parent, {:notification, session, type, payload})

              receive do
                :stop -> :ok
              end
          end
        end)
      end

    on_exit(fn -> Enum.each(subscribers, &Process.exit(&1, :kill)) end)

    for pid <- subscribers do
      assert_receive {:ready, ^pid}
    end

    before_other = Plug.Test.conn(:get, "/assets/site.css") |> Volt.DevServer.call(other_config)
    File.write!(dependency, ".first { color: blue }")
    assert_receive {:notification, ^first, :update, %{changes: [:style]}}, 10_000
    response = Plug.Test.conn(:get, "/assets/site.css") |> Volt.DevServer.call(config)
    assert response.status == 200
    assert response.resp_body =~ "blue"
    after_other = Plug.Test.conn(:get, "/assets/site.css") |> Volt.DevServer.call(other_config)
    assert after_other.resp_body == before_other.resp_body
    [first_subscriber, second_subscriber] = subscribers
    send(second_subscriber, {:check, self()})
    assert_receive {:mailbox, ^second, {:messages, []}}
    refute_received {:notification, ^second, _, _}
    send(first_subscriber, :stop)
  end
end
