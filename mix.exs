defmodule Granola.MixProject do
  use Mix.Project

  @repo_url "https://github.com/sgerrand/ex_granola"

  def project do
    [
      app: :granola,
      version: "0.0.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description: description(),
      source_url: @repo_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:plug, "~> 1.0", only: :test}
    ]
  end

  defp description do
    "Elixir client for the Granola API"
  end

  defp package do
    [
      licenses: ["BSD-2-Clause"],
      links: %{
        "GitHub" => @repo_url,
      },
      name: "Granola"
    ]
  end
end
