defmodule WatchmanTest do
  use ExUnit.Case
  doctest Watchman

  test "split_json" do
    assert Watchman.split_json(~s/{"foo": "bar"}{"quux": "boom"}{"turing": "lovelace"}/) ==
              [
                ~s/{"foo": "bar"}/,
                ~s/{"quux": "boom"}/,
                ~s/{"turing": "lovelace"}/
              ]
  end
end
