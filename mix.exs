defmodule Homelander.MixProject do
  use Mix.Project

  def undefined env_var do
    case System.fetch_env(env_var) do
      :error -> true
      _ -> false
    end
  end

  def project do
    [
      app: :homelander,
      version: "0.1.0",
      elixir: "~> 1.10",
      deps: deps(),
      escript: escript(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Homelander.Application, []}
    ]
  end

  def escript do
    [
      main_module: Homelander.CLI,
      embed_elixir: undefined("MIX_ESCRIPT_DO_NOT_EMBED_ELIXIR")
    ]
  end

  def releases do
    [
      homelander: [
        applications: [homelander: :permanent]
      ]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.2"},
    ]
  end
end
