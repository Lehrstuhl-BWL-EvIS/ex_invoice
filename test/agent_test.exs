defmodule ExInvoiceAgentTest do
  use ExUnit.Case

  setup_all do
    {:ok, _pid} = ExInvoice.start_link()

    on_exit(fn ->
      summary_text = ExInvoice.generate_summary_text()
      IO.puts("Ausgabe: " <> summary_text)
    end)

    :ok
  end

  test "validates a correct tax amount" do
    tax_details = %{total_amount: 300, tax_rate: 19, tax_amount: 57, justification: ""}
    assert ExInvoice.validate_tax(tax_details) == {:ok, "Tax amount matches the expected amount."}
  end

  test "Agentest" do
   # ExInvoice.store_result(:result1)

      name = "Bratwurst GmbH & Co. KG"
      #namehelp = ExInvoice.validate_name(name)
      #ExInvoice.store_result(namehelp)
      assert ExInvoice.validate_name(name) == {:ok, "Name is valid"}

    end




end
