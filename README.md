# :superhero_man: Homelander

Simple command supervision powered by OTP supervisors and the Erlang runtime.\
Run `homelander my.conf`, or just `homelander` to use `~/.homelanderrc`

```
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
```

## Features

- Self-contained standalone executable
- Dead simple configuration
- Runs commands in a shell environment, allowing easy log redirection, or recurring tasks using `sleep`
- Robustness provided by supervisor trees from Erlang/OTP
- Can match patterns in command output and trigger a restart (e.g. error message, etc.) using the `restart_on` attribute
- Reloads config file when modified and makes the necessary changes on the fly if [watchman](https://github.com/facebook/watchman) is installed
- Uses exponential backoff when supervised command keeps failing

## Installation

Standalone executables for Linux and macOS 64-bit are available in [the Releases section](https://github.com/blandinw/homelander/releases), generated using [makeself](https://makeself.io).

Or you can build it yourself
```
# to get a portable binary with no dependency on Erlang (any UNIX-compatible system)
./install-makeself.sh path/to/bin/directory

# or to get an escript that requires Erlang to run (any system with Erlang installed)
./install-escript.sh path/to/bin/directory

# then...
path/to/bin/directory/homelander my.conf
```

## Command attributes

For complex commands, these attributes can be specified

| name       | type                                                                               | description                                                                                                                                                              |
| ---------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `command`    | _string_ representing a valid shell command                                        | Command to run in `/bin/sh`                                                                                                                                                |
| `cd`         | _string_ representing a valid directory                                            | Directory to use as the current directory when running the command                                                                                                       |
| `cooldown`   | _integer_ in milliseconds                                                          | Cooldown in milliseconds between two restarts. `0` will restart the command right away. By default, Homelander uses exponential backoff                                  |
| `env`        | _string_ like `key=my value:)`                                                  | Sets one environment variable. Can be repeated multiple times                                                                                                            |
| `restart_on` | _regexp_ (PCRE described [here](https://erlang.org/doc/man/re.html#regexp_syntax)) | Pattern to match against the command's stdout. Homelander will kill and restart the command on match                                                                     |

## Development

```
mix test
mix escript.build && ./homelander config.sample
```
