defmodule ExInvoice.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  require Logger
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: ExInvoice.Worker.start_link(arg)
      # {ExInvoice.Worker, arg}
      # {ChromicPDF,
      # chrome_args: [
      #   "--headless",
      #   "--disable-gpu",
      #   "--remote-debugging-port=9222"
      # ],
      # chrome_executable: "C:/Users/steph/AppData/Local/Chromium/Application/chrome.exe",
      # discard_stderr: false,
      # disable_scripts: true,
      # session_pool: [size: 3]},
    ]

    #   # See https://hexdocs.pm/elixir/Supervisor.html
    #   # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExInvoice.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # defp chromic_pdf_opts do
  #   [disable_scripts: true]
  # end
end
