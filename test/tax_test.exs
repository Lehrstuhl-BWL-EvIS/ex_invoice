defmodule ExInvoiceTestTax do
  use ExUnit.Case
  alias ExInvoice

  # Check Tax&Amounts

  describe "tax validation with zero tax rate" do
    test "zero tax rate with no tax amount and no justification needed" do
      invoice = %{total_amount: 100, tax_rate: 0, tax_amount: 0, justification: nil}
      assert ExInvoice.validate_tax(invoice) == {:ok, "Tax amount matches the expected amount."}
    end

    test "zero tax rate with no tax amount and unnecessary justification" do
      invoice = %{total_amount: 100, tax_rate: 0, tax_amount: 0, justification: "Not applicable"}
      assert ExInvoice.validate_tax(invoice) == {:ok, "Tax amount matches the expected amount."}
    end

    test "zero tax rate but incorrect tax amount provided" do
      invoice = %{total_amount: 100, tax_rate: 0, tax_amount: 5, justification: nil}
      assert ExInvoice.validate_tax(invoice) == {:error, "Tax amount does not match the expected amount."}
    end
  end
end
