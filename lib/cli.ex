require Logger

defmodule Homelander.CLI do

  def sample do
    """
    Sample config:

    # simple command, long-running
    spotifyd --no-daemon

    # recurring command: alert if battery level low, checks every 5 minutes
    [ $(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1) -le 10 ] && say 'Battery low' ; sleep 300

    # complex command using attributes
    (
      command say "hello $name." && sleep 150
      env name=dave
      cd /bin
    )
    """
    |> String.trim()
  end

  def default_config() do
    "~/.homelanderrc"
  end

  def main(argv) do
    # catch C-c, etc.
    System.at_exit(fn status ->
      # System.stop does not trigger System.at_exit per its documentation
      # so no infinite loop
      System.stop(status)
    end)

    if "--help" in argv do
      IO.puts("""
      Run and supervise commands as specified in config.

      Usage: homelander [PATH]

        PATH  Path to config file. Defaults to `~/.homelanderrc`.

      #{sample()}
      """ |> String.trim)

      System.stop(0)
      exit(:normal)
    end

    if "--check" in argv do
      rand_b64 = :crypto.strong_rand_bytes(16) |> Base.encode64()
      IO.puts("#{rand_b64}")
      System.stop(0)
      exit(:normal)
    end

    argv = if "--verbose" in argv do
      Logger.configure_backend(:console, level: :debug)
      List.delete(argv, "--verbose")
    else
      argv
    end

    config =
      case argv do
        [path] ->
          path

        _ ->
          default_config()
      end

    case Homelander.supervise(config) do
      {:ok, pid} ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, reason} ->
            Logger.info("Homelander exited with reason #{inspect(reason)}")
        end

      err = {:error, {reason, _}} ->
        pretty_error =
          case reason do
            %RuntimeError{message: message} ->
              message

            {:badmatch, {:error, :enoent}} ->
              "could not find #{config}"

            _ ->
              inspect(err)
          end

        Logger.error(
          """
          Homelander exited with reason: #{pretty_error}

          #{sample()}
          """
          |> String.trim()
        )
        System.stop(0)
        exit(:normal)
    end
  end
end
