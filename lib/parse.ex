defmodule Parse do
  def normalize(k, v) do
    v = String.trim(v)

    case k do
      :cd ->
        String.to_charlist(v)

      :cooldown ->
        try do
          case String.to_integer(v) do
            x when x >= 0 -> x
          end
        rescue
          _ -> raise "invalid cooldown \"#{v}\" (expected a positive integer)"
        end

      :env ->
        case String.split(v, "=") do
          [k, v] -> [{String.to_charlist(k), String.to_charlist(v)}]
        end

      :restart_on ->
        try do
          Regex.compile!(v)
        rescue
          e ->
            reraise "could not parse regexp \"#{v}\" because #{Exception.message(e)}",
                    __STACKTRACE__
        end

      _ ->
        v
    end
  end

  def maybe_spaces(str = "", acc) do
    {str, acc}
  end

  def maybe_spaces(orig = <<c, str::binary>>, acc) do
    case c do
      ?\n -> maybe_spaces(str, <<acc::binary, c>>)
      ?\r -> maybe_spaces(str, <<acc::binary, c>>)
      ?\s -> maybe_spaces(str, <<acc::binary, c>>)
      ?\t -> maybe_spaces(str, <<acc::binary, c>>)
      _ -> {orig, acc}
    end
  end

  def till_newline(<<"\r\n", str::binary>>, acc) do
    {str, acc}
  end

  def till_newline(<<"\n", str::binary>>, acc) do
    {str, acc}
  end

  def till_newline(<<c, str::binary>>, acc) do
    till_newline(str, <<acc::binary, c>>)
  end

  def till_space(<<c, str::binary>>, acc) do
    case c do
      ?\n -> {str, acc}
      ?\r -> {str, acc}
      ?\s -> {str, acc}
      ?\t -> {str, acc}
      _ -> till_space(str, <<acc::binary, c>>)
    end
  end

  def paren_keyvalue(str) do
    {str, key} = till_space(str, "")
    {str, value} = till_newline(str, "")
    {str, {key, value}}
  end

  def paren_command("", _) do
    raise "unmatched parenthesis in config"
  end

  # closing paren must be on its own line
  def paren_command(<<")", str::binary>>, acc) do
    {str,
     Enum.reverse(acc)
     |> List.foldl(%{}, fn {k, v}, result ->
       Map.update(result, k, v, fn existing ->
         case k do
           :env -> Enum.concat(existing, v)
           _ -> v
         end
       end)
     end)}
  end

  def paren_command(<<"#", str::binary>>, acc) do
    {str, _} = till_newline(str, "")
    {str, _} = maybe_spaces(str, "")
    paren_command(str, acc)
  end

  def paren_command(str, acc) do
    {str, {k, v}} = paren_keyvalue(str)
    {str, _} = maybe_spaces(str, "")
    k = String.to_atom(k)
    paren_command(str, [{k, normalize(k, v)} | acc])
  end

  def one_command(<<"(", str::binary>>) do
    {str, _} = maybe_spaces(str, "")
    paren_command(str, [])
  end

  def one_command(str) do
    {str, cmd} = till_newline(str, "")
    {str, %{command: cmd}}
  end

  def one_or_more_commands(<<"#", str::binary>>, commands) do
    {str, _} = till_newline(str, "")
    {str, _} = maybe_spaces(str, "")
    one_or_more_commands(str, commands)
  end

  def one_or_more_commands("", []) do
    raise "expected at least one command"
  end

  def one_or_more_commands("", commands) do
    Enum.reverse(commands)
  end

  def one_or_more_commands(str, acc) do
    {str, command} = one_command(str)
    {str, _} = maybe_spaces(str, "")

    one_or_more_commands(str, [command | acc])
  end

  @spec parse_config!(binary()) :: [%{command: binary()}]
  def parse_config!(str) do
    {str, _} = maybe_spaces(str, "")
    one_or_more_commands(str, [])
  end
end
