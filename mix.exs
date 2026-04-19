defmodule Granola.MixProject do
  use Mix.Project

  @repo_url "https://github.com/sgerrand/ex_granola"
  @version "0.0.0"

  def project do
    [
      app: :granola,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description: description(),
      source_url: @repo_url,

      # Docs
      name: "Granola",
      docs: docs()
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:plug, "~> 1.0", only: :test}
    ]
  end

  defp description do
    "Elixir client for the Granola API"
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @repo_url
    ]
  end

  defp package do
    [
      licenses: ["BSD-2-Clause"],
      links: %{
        "GitHub" => @repo_url,
        "Changelog" => "https://hexdocs.pm/granola/changelog.html"
      }
    ]
  end
end
