defmodule ExInvoice.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_invoice,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "ExInvoice is an Elixir library for generating legally compliant e-invoices.",
      package: package(),

      # Docs
      name: "ExInvoice",
      source_url: "https://github.com/Lehrstuhl-BWL-EvIS/ex_invoice",
      homepage_url: "https://github.com/Lehrstuhl-BWL-EvIS/ex_invoice",
      docs: [
        # The main page in the docs
        # main: "ExInvoice",
        # logo: "path/to/logo.png",
        extras: ["README.md", "LICENSE"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExInvoice.Application, []}
    ]
  end

  defp package do
    [
      # maintainers: ["TODO"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/Lehrstuhl-BWL-EvIS/ex_invoice"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Validator for IBAN account and BIC numbers
      # https://hexdocs.pm/bankster/api-reference.html
      # https://github.com/railsmechanic/bankster
      {:bankster, "~> 0.4.0"},

      # Linter for better code consistency
      # https://hexdocs.pm/credo/overview.html
      # https://github.com/rrrene/credo
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

      # Fast HTML-to-PDF/A renderer based on Chrome & Ghostscript
      # https://hexdocs.pm/chromic_pdf/ChromicPDF.html
      # https://github.com/bitcrowd/chromic_pdf
      {:chromic_pdf, "~> 1.17"},

      # Generates the documentation for the entire project
      # https://hexdocs.pm/ex_doc/readme.html
      # https://github.com/elixir-lang/ex_doc
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},

      # Generates fake data
      # https://hexdocs.pm/faker/readme.html
      # https://github.com/elixirs/faker
      {:faker, "~> 0.18", only: :test},

      # Validate VAT identification numbers using the VIES service
      # https://hexdocs.pm/ex_vatcheck/ExVatcheck.html
      # https://github.com/taxjar/ex_vatcheck
      {:ex_vatcheck, "~> 0.3.1"}
    ]
  end
end
