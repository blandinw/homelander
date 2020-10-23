defmodule TimeStub do
  def start_link do
    pid = Process.spawn(fn ->
      Process.register(self(), __MODULE__)
      loop(0)
    end, [:link])
    {:ok, pid}
  end

  def loop t do
    receive do
      {:time, from} ->
        send(from, t)
        loop(t)
      {:advance, from, more} ->
        send(from, :ok)
        loop(t + more)
    end
  end

  def monotonic_time _ do
    send(__MODULE__, {:time, self()})
    receive do
      x -> x
    end
  end

  def advance_time more do
    send(__MODULE__, {:advance, self(), more})
    receive do
      x -> x
    end
  end
end

defmodule CushionTest do
  use ExUnit.Case
  doctest Homelander.Cushion
  doctest Homelander.CushionCounter

  test "pencil_in" do
    id = :foo
    {:ok, _} = TimeStub.start_link()
    {:ok, pid} = Homelander.CushionCounter.start_link(TimeStub, [])
    1 = Homelander.CushionCounter.sadface(pid, id)
    :ok = TimeStub.advance_time(45_000)
    2 = Homelander.CushionCounter.sadface(pid, id)
    :ok = TimeStub.advance_time(45_000)
    3 = Homelander.CushionCounter.sadface(pid, id)
    :ok = TimeStub.advance_time(60_000)
    assert 3 == Homelander.CushionCounter.sadface(pid, id)
    :ok = TimeStub.advance_time(150_000)
    assert 1 == Homelander.CushionCounter.sadface(pid, id)
  end

  test "garbage collect" do
    {:ok, _} = TimeStub.start_link()
    {:ok, pid} = Homelander.CushionCounter.start_link(TimeStub, [])
    for i <- 1..10_000 do
      1 = Homelander.CushionCounter.sadface(pid, i)
    end
    assert 10_000 == Enum.count(GenServer.call(pid, {:ledger}))
    TimeStub.advance_time(300_000)
    1 = Homelander.CushionCounter.sadface(pid, :trigger_gc)
    assert 1 == Enum.count(GenServer.call(pid, {:ledger}))
  end
end
