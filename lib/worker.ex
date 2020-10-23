require Logger

defmodule Homelander.Worker do
  use GenServer

  def start_link(command) do
    GenServer.start_link(__MODULE__, command)
  end

  defp shell_command(command_str) do
    String.trim("""
    ( #{command_str} ) & PID=$!

    exec 8<&0
    (
    while read foo <&8; do
    :
    done
    kill -- -$$
    ) >/dev/null 2>&1 &

    wait $PID
    """)
  end

  @impl true
  def init(command = %{command: command_str}) do
    Logger.info("`#{command_str}` starting")

    opts = [
      :exit_status,
      :hide,
      :stderr_to_stdout,
      {:args, ["-c", shell_command(command_str)]}
    ]

    opts =
      case command do
        %{env: env} -> [{:env, env} | opts]
        _ -> opts
      end

    opts =
      case command do
        %{cd: cd} -> [{:cd, cd} | opts]
        _ -> opts
      end

    port = Port.open({:spawn_executable, "/bin/sh"}, opts)

    {:ok, {command, port}}
  end

  @impl true
  def handle_info(msg, state = {command = %{command: command_str}, port}) do
    case msg do
      {^port, {:exit_status, status}} ->
        Logger.info("`#{command_str}` worker exited with status #{status}")
        Process.exit(self(), if status == 0 do
              :normal
            else
              :error
            end)

      {^port, {:data, chunk}} ->
        chunk_str = List.to_string(chunk) |> String.trim_trailing()
        Logger.debug("`#{command_str}` said\n#{chunk_str}")

        case command do
          %{restart_on: restart_on} ->
            if Regex.match?(restart_on, chunk_str) do
              Process.exit(self(), :restart_on)
            end

          _ ->
            :ok
        end

      msg ->
        Logger.debug("`#{command_str}` worker received #{inspect(msg)}")
    end

    {:noreply, state}
  end
end
