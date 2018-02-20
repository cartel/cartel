defmodule Cartel.Mixfile do
  use Mix.Project

  @description """
    Elixir HTTP client forked from HTTPoison
  """

  def project do
    [
      app: :cartel_http,
      version: "0.1.0",
      elixir: "~> 1.4",
      name: "Cartel",
      description: @description,
      package: package(),
      deps: deps(),
      source_url: "https://github.com/cartel/cartel"
    ]
  end

  def application do
    [applications: [:hackney]]
  end

  defp deps do
    [
      {:hackney, "~> 1.8"},
      {:exjsx, "~> 3.1", only: :test},
      {:httparrot, "~> 1.0", only: :test},
      {:meck, "~> 0.8.2", only: :test},
      {:earmark, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.14", only: :dev},
    ]
  end

  defp package do
    [
      maintainers: ["Ryan Winchester"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/cartel/cartel"},
    ]
  end
end
