require Logger

defmodule Homelander.Application do
  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Homelander.Hypervisor]
    DynamicSupervisor.start_link(opts)
  end

  @impl true
  def stop(_state) do
    Logger.info("`#{__MODULE__}` stopping")
  end
end
