defmodule Volt.HMR.MessageTest do
  use ExUnit.Case, async: true

  alias Volt.HMR.Message

  describe "encode (dump + Jason)" do
    test "ping serializes to a JSON object with null payload" do
      json = Message.dump(%Message{type: :ping}) |> Jason.encode!()

      assert Jason.decode!(json) == %{"type" => "ping", "payload" => nil}
    end

    test "pong serializes to a JSON object with null payload" do
      json = Message.dump(%Message{type: :pong}) |> Jason.encode!()

      assert Jason.decode!(json) == %{"type" => "pong", "payload" => nil}
    end

    test "update serializes payload with atom values as strings" do
      msg = %Message{
        type: :update,
        payload: %{path: "App.vue", changes: [:template, :hmr]}
      }

      decoded = msg |> Message.dump() |> Jason.encode!() |> Jason.decode!()

      assert decoded["type"] == "update"
      assert decoded["payload"]["path"] == "App.vue"
      assert decoded["payload"]["changes"] == ["template", "hmr"]
    end
  end

  describe "decode" do
    test "decodes a ping message" do
      assert {:ok, %Message{type: :ping, payload: nil}} =
               Message.decode(~s({"type":"ping"}))
    end

    test "decodes an update message" do
      assert {:ok, %Message{type: :update, payload: payload}} =
               Message.decode(
                 ~s({"type":"update","payload":{"path":"App.vue","changes":["template"]}})
               )

      assert payload == %{"path" => "App.vue", "changes" => ["template"]}
    end

    test "rejects unknown message types" do
      assert {:error, _} = Message.decode(~s({"type":"nope"}))
    end

    test "rejects malformed JSON" do
      assert {:error, _} = Message.decode("not json")
    end
  end

  describe "round-trip" do
    for type <- [:ping, :pong] do
      test "#{type} round-trips through JSON" do
        original = %Message{type: unquote(type)}
        {:ok, decoded} = original |> Message.dump() |> Jason.encode!() |> Message.decode()
        assert decoded.type == unquote(type)
      end
    end
  end
end
