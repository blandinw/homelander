import Config

config :logger, :console,
  # level: :debug
  format: "$time $metadata[$level] $message\n"
