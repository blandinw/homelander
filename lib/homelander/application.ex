require Logger

defmodule Homelander.Application do
  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Homelander.Hypervisor]
    pid = DynamicSupervisor.start_link(opts)

    if System.fetch_env("HOMELANDER_CLI") != :error do
      Task.async(fn ->
        Homelander.CLI.main([
          if env_defined? "HOMELANDER_CHECK" do "--check" end,
          if env_defined? "HOMELANDER_HELP" do "--help" end,
          if env_defined? "HOMELANDER_VERBOSE" do "--verbose" end,
          env "HOMELANDER_CONFIG"
        ] |> Enum.filter(fn x -> x end))
      end)
    end

    pid
  end

  @impl true
  def stop(_state) do
    Logger.info("`#{__MODULE__}` stopping")
  end

  defp env_defined? v do
    System.fetch_env(v) != :error
  end

  defp env v do
    case System.fetch_env(v) do
      :error -> nil
      {:ok, x} -> x
    end
  end
end
