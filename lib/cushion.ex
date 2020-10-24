defmodule Homelander.Cushion do
  use GenServer

  @max_wait_ms 60_000

  def start_link(m, a, counter_name, cooldown, options) do
    GenServer.start_link(__MODULE__, [m, a, counter_name, cooldown], options)
  end

  def compute_cooldown(:default, reason, count, started_at) do
    case reason do
      :normal ->
        if count < 5 do
          1_000
        else
          60_000
        end

      _ ->
        alive_for =
          (:erlang.monotonic_time() - started_at)
          |> :erlang.convert_time_unit(:native, :millisecond)

        (Bitwise.<<<(1, count) * 1000 - alive_for) |> min(@max_wait_ms) |> max(0)
    end
  end

  def compute_cooldown(n, _, _, _) when is_integer(n) do
    n
  end

  @impl true
  def init([mod, args, counter_name, cooldown]) do
    Process.flag(:trap_exit, true)
    {:ok, pid} = apply(mod, :start_link, args)
    {:ok, {pid, mod, args, counter_name, cooldown, :erlang.monotonic_time()}}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    {^pid, mod, args, counter_name, cooldown, started_at} = state

    count = GenServer.call(counter_name, {:sadface, {mod, args}})

    cooldown_ms = compute_cooldown(cooldown, reason, count, started_at)

    receive do
    after
      cooldown_ms ->
        :ok
    end

    {:stop, reason, state}
  end
end

defmodule Homelander.CushionCounter do
  use GenServer

  @two_minutes 120_000
  @gc_threshold 10_000

  def start_link(options) do
    GenServer.start_link(__MODULE__, :erlang, options)
  end

  def start_link(time_mod, options) do
    GenServer.start_link(__MODULE__, time_mod, options)
  end

  def sadface(pid, id) do
    GenServer.call(pid, {:sadface, id})
  end

  @impl true
  def init(time_mod) do
    {:ok, {time_mod, %{}}}
  end

  @impl true
  def handle_call({:sadface, id}, _from, state) do
    {count, state} = pencil_in(state, id)
    {:reply, count, state}
  end

  def handle_call({:ledger}, _from, state = {_, ledger}) do
    {:reply, ledger, state}
  end

  def pencil_in({time_mod, ledger}, id) do
    now = apply(time_mod, :monotonic_time, [:millisecond])
    cutoff = now - @two_minutes

    {past, ledger} =
      Map.get_and_update(ledger, id, fn past ->
        xs =
          Enum.take(past || [], 10)
          |> Enum.take_while(fn x -> x > cutoff end)
          |> List.insert_at(0, now)

        {xs, xs}
      end)

    ledger =
      if Enum.count(ledger) > @gc_threshold do
        Enum.filter(ledger, fn {_, [most_recent | _]} ->
          most_recent > cutoff
        end)
        |> Map.new()
      else
        ledger
      end

    {Enum.count(past), {time_mod, ledger}}
  end
end
