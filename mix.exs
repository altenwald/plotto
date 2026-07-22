defmodule Plotto.MixProject do
  use Mix.Project

  def project do
    [
      app: :plotto,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "A 100% Elixir library for generating SVG and PNG charts, no external binaries or NIFs required",
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      files: ~w(lib fonts mix.exs README* LICENSE* .formatter.exs),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/altenwald/plotto"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      source_url: "https://github.com/altenwald/plotto"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end
end
