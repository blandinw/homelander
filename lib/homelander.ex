require Logger

defmodule Homelander do
  use GenServer

  # API

  @doc """
  Start and monitor all the commands specified in the configuration file.
  This adds a Supervisor to the Homandler application supervision tree, with N children (N = number of commands in config file)
  """
  @spec supervise(Path.t()) :: DynamicSupervisor.on_start_child()
  def supervise(config) do
    DynamicSupervisor.start_child(
      Homelander.Hypervisor,
      %{id: config, start: {__MODULE__, :start_link, [config]}, shutdown: 10_000}
    )
  end

  @spec start_link(Path.t()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  # Private

  defp worker_id(command) do
    {Worker, command}
  end

  defp worker_spec(command, counter_name) do
    cooldown = case command[:cooldown] do
                 nil -> :default
                 x -> x
               end
    %{
      id: worker_id(command),
      start:
        {Homelander.Cushion, :start_link,
         [Homelander.Worker, [command], counter_name, cooldown, []]}
    }
  end

  defp read_config(config) do
    case File.read(config) do
      {:ok, binary} ->
        try do
          {:ok, Parse.parse_config!(binary)}
        catch
          kind, reason -> {kind, reason}
        end

      x ->
        x
    end
  end

  def diff_commands(a, b) do
    a = MapSet.new(a)
    b = MapSet.new(b)

    a_only = MapSet.difference(a, b) |> MapSet.to_list()
    b_only = MapSet.difference(b, a) |> MapSet.to_list()

    {a_only, b_only}
  end

  # Callbacks

  @impl true
  def init(config) do
    config = Path.expand(config)
    {:ok, commands} = read_config(config)

    counter_name = String.to_atom(config <> ".counter")

    children = [
      {Homelander.CushionCounter, [name: counter_name]},
      if Watchman.installed?() do
        {Watchman,
         [
           self(),
           config,
           Path.dirname(config),
           %Watchman.Query{
             expression: ["match", Path.basename(config), "wholename"],
             fields: ["name"]
           }
         ]}
      end
    ]

    {:ok, _} =
      Supervisor.start_link(
        Enum.filter(children, &Function.identity/1),
        strategy: :one_for_one
      )

    {:ok, pid} =
      Supervisor.start_link(
        Enum.map(commands, fn x -> worker_spec(x, counter_name) end),
        max_restarts: 100,
        max_seconds: 1,
        strategy: :one_for_one
      )

    {:ok, {config, pid, counter_name, commands}}
  end

  @impl true
  def handle_info({:modified, config, files}, state) do
    {^config, sup_pid, counter_name, old_commands} = state
    basename = Path.basename(config)
    [^basename] = files

    case read_config(config) do
      {:ok, commands} ->
        {remove, add} = diff_commands(old_commands, commands)
        Logger.info("Adding #{inspect(add)} and removing #{inspect(remove)}")

        Enum.each(remove, fn x ->
          id = worker_id(x)
          :ok = Supervisor.terminate_child(sup_pid, id)
          :ok = Supervisor.delete_child(sup_pid, id)
        end)

        Enum.each(add, fn x ->
          {:ok, _} = Supervisor.start_child(sup_pid, worker_spec(x, counter_name))
        end)

        {:noreply, {config, sup_pid, counter_name, commands}}

      _ ->
        Logger.error("could not parse #{config}")
        {:noreply, state}
    end
  end
end
