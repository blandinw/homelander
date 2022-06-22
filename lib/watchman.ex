require Logger

defmodule Watchman.Query do
  defstruct [:generator, expression: %{}, fields: ["name"]]
end

defmodule Watchman do
  @moduledoc """
  A file watching service.
  Watchman exists to watch files and send messages to your Erlang processes when they change.
  This modules uses [`watchman`](https://facebook.github.io/watchman/) via a Port.
  See https://facebook.github.io/watchman/docs/cmd/query.html and https://facebook.github.io/watchman/docs/cmd/subscribe.html for more details about syntax.
  """

  use GenServer

  def start_link([pid, subscription_id, root, query | options]) do
    GenServer.start_link(__MODULE__, [pid, subscription_id, root, query], options)
  end

  def installed? do
    try do
      System.cmd("watchman", ["version"])
      true
    rescue
      _ -> false
    end
  end

  @impl true
  def init([pid, subscription_id, root, query]) do
    stopword = :crypto.strong_rand_bytes(16) |> Base.encode64()

    port =
      Port.open({:spawn_executable, "/bin/sh"}, [
        :exit_status,
        :hide,
        :stream,
        {:args, ["-c", shell_command(stopword)]}
      ])

    json =
      Jason.encode!([
        "subscribe",
        root,
        subscription_id,
        Map.from_struct(query)
      ])

    nl = List.to_string(:io_lib.nl())
    true = Port.command(port, json <> nl)
    true = Port.command(port, stopword <> nl)

    {:ok, {pid, subscription_id, port}}
  end

  @impl true
  def handle_info({port, {:data, raw_chunk}}, state) do
    {pid, subscription_id, ^port} = state
    # split chunk if we got several JSON objects in one chunk
    for chunk <- List.to_string(raw_chunk) |> split_json() do
      case Jason.decode!(chunk) do
        %{"subscription" => ^subscription_id, "files" => files} ->
          send(pid, {:modified, subscription_id, files})

        %{"error" => error} ->
          Logger.error("watchman error: #{inspect(error)}")
          nil

        _ ->
          nil
      end
    end

    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, 88}}, _state) do
    raise "Cannot find executable `watchman`"
  end

  defp shell_command(stopword) do
    String.trim("""
    set -e
    command -v watchman >/dev/null 2>&1 || exit 88
    exec 8<&0
    (
      while read x <&8; do
        if [ "$x" = "#{stopword}" ]; then
          break
        fi
        echo $x
      done
    ) | watchman --persistent --json-command --server-encoding=json & PID=$!
    (
      while read foo <&8; do
        :
      done
      kill -- -$$
    ) >/dev/null 2>&1 &
    wait $PID
    """)
  end

  @spec split_json(binary()) :: [binary()]
  def split_json(s) do
    split_json(s, [])
  end

  @spec split_json(binary(), [binary()]) :: [binary()]
  def split_json(s, acc) do
    case Regex.run(~r/\}\s?\s?\{/, s, return: :index) do
      nil ->
        Enum.reverse([s | acc])

      [{idx, _}] ->
        {pre, post} = String.split_at(s, idx + 1)
        split_json(post, [pre | acc])
    end
  end
end
