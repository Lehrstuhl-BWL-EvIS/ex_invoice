defmodule ExInvoiceTest do
  use ExUnit.Case, async: true

  alias ExInvoice

  setup_all do
    {:ok, _pid} = ExInvoice.start_link()

    on_exit(fn ->
      summary_text = ExInvoice.generate_summary_text()
      IO.puts("Ausgabe: " <> summary_text)
    end)

    :ok
  end


#------------------------------------------------------------------------------
#Adress
  test "validates a correct address" do
    address = %{street: "Musterstraße 1", city: "Musterstadt", postal_code: "12345"}
    assert ExInvoice.validate_address(address) == {:ok, "Address is valid"}
  end

  test "validates an incorrect address" do
    address = %{street: "", city: "Musterstadt", postal_code: "12345"}
    assert ExInvoice.validate_address(address) == {:error, "Invalid address"}
  end
#------------------------------------------------------------------------------
#Name

test "validates a correct name" do
  name = "Bratwurst GmbH & Co. KG"
  assert ExInvoice.validate_name(name) == {:ok, "Name is valid"}
end

test "validates a incorrect name" do
  name = "Bratwurst GmbH ? Co. KG"
  assert ExInvoice.validate_name(name) == {:error, "Invalid characters in company name"}
end

test "validates a incorrect lengt name: too long" do
  name = "Bratwurst GmbH & Co. KG111111111111111111111111111111111111111111111111111111111111111111111111111111111"
  assert ExInvoice.validate_name(name) == {:error, "Name length"}
end

test "validates a incorrect lengt name: too short" do
  name = "1"
  assert ExInvoice.validate_name(name) == {:error, "Name length"}
end

test "validates a NIL name" do
  name = ""
  assert ExInvoice.validate_name(name) == {:error, "Company name is required"}
end

#------------------------------------------------------------------------------
  test "validates a correct tax amount" do
    tax_details = %{total_amount: 300, tax_rate: 19, tax_amount: 57, justification: ""}
    assert ExInvoice.validate_tax(tax_details) == {:ok, "Tax amount matches the expected amount."}
  end

  test "validates a simplified invoice" do
    tax_details = %{total_amount: 100, tax_rate: 19, tax_amount: 19, justification: ""}
    assert ExInvoice.validate_tax(tax_details) == {:ok, "Tax amount matches the expected amount. This is a simplified invoice."}
  end

  test "validates a correct tax number" do
    assert ExInvoice.validate_tax_number("12345678901") == {:ok, "Valid German tax number."}
  end

  test "validates an invalid tax number" do
    assert ExInvoice.validate_tax_number("INVALID") == {:error, "Invalid tax number or VAT ID."}
  end

  test "validates a correct IBAN" do
    iban = "DE89370400440532013000"
    assert ExInvoice.validate_iban(iban) == "Valid IBAN"
  end

  test "validates incorrect IBAN" do
    iban = "INVALID_IBAN"
    assert ExInvoice.validate_iban(iban) == "Invalid IBAN: invalid_format"
  end

  test "validates invoice items" do
    invoice_items = [{"item_001", 10}, {"item_002", 5}]
    designations = %{"item_001" => "Hammer", "item_002" => "Schraubenzieher"}

    result = ExInvoice.validate_invoice_items(invoice_items, designations)

    assert Enum.all?(result, fn {:ok, _} -> true; _ -> false end)
  end


end
