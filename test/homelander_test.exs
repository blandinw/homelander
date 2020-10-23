defmodule HomelanderTest do
  use ExUnit.Case
  doctest Homelander

  def config do
    """
    sleep 10\r\n
    spotifyd --no-daemon

    # foo
    (
      # paren comment
      command foo --bar
      foo quux
      env FOO="Bar"
      restart_on (Connection lost|Connection reset)
      cd /bin
    )
    (command erlang
    env debug=1
    restart_on this is a closing paren\\)
    env quux=meow
    cooldown 10000
    )foo
    """
  end

  test "parse config" do
    assert_raise RuntimeError, "expected at least one command", fn -> Parse.parse_config!("") end

    assert_raise RuntimeError, ~r/invalid cooldown/, fn ->
      Parse.parse_config!("(cooldown -1\n)")
    end

    assert Parse.parse_config!(config()) ==
             [
               %{command: "sleep 10"},
               %{command: "spotifyd --no-daemon"},
               %{
                 command: "foo --bar",
                 foo: "quux",
                 restart_on: ~r/(Connection lost|Connection reset)/,
                 env: [{'FOO', '\"Bar\"'}],
                 cd: '/bin',
               },
               %{
                 command: "erlang",
                 restart_on: ~r/this is a closing paren\)/,
                 env: [{'debug', '1'}, {'quux', 'meow'}],
                 cooldown: 10_000
               },
               %{command: "foo"}
             ]
  end

  test "diff_commands" do
    commands = Parse.parse_config!(config())

    assert {[], []} ==
             Homelander.diff_commands(commands, [
               %{command: "foo"},
               %{command: "sleep 10"},
               %{command: "spotifyd --no-daemon"},
               %{
                 command: "foo --bar",
                 foo: "quux",
                 restart_on: ~r/(Connection lost|Connection reset)/,
                 env: [{'FOO', '\"Bar\"'}],
                 cd: '/bin',
               },
               %{
                 command: "erlang",
                 restart_on: ~r/this is a closing paren\)/,
                 env: [{'debug', '1'}, {'quux', 'meow'}],
                 cooldown: 10_000
               }
             ])

    assert {[
              %{command: "foo"},
              %{command: "sleep 10"},
              %{command: "spotifyd --no-daemon"}
            ],
            [
              %{command: "sleep 10", foo: "bar"}
            ]} ==
             Homelander.diff_commands(commands, [
               %{command: "sleep 10", foo: "bar"},
               %{
                 command: "foo --bar",
                 foo: "quux",
                 restart_on: ~r/(Connection lost|Connection reset)/,
                 env: [{'FOO', '\"Bar\"'}],
                 cd: '/bin'
               },
               %{
                 command: "erlang",
                 restart_on: ~r/this is a closing paren\)/,
                 env: [{'debug', '1'}, {'quux', 'meow'}],
                 cooldown: 10_000
               }
             ])
  end
end
