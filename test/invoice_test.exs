defmodule ExInvoiceTest do
  use ExUnit.Case, async: true

  alias ExInvoice

  setup do
    ExInvoice.start_link()
    :ok
  end

  test "validates a correct address" do
    address = %{street: "Musterstraße 1", city: "Musterstadt", postal_code: "12345"}
    assert ExInvoice.validate_address(address) == {:ok, "Address is valid"}
  end

  test "validates an incorrect address" do
    address = %{street: "", city: "Musterstadt", postal_code: "12345"}
    assert ExInvoice.validate_address(address) == {:error, "Invalid address"}
  end

  test "validates a correct name" do
    name = %{first_name: "Max", last_name: "Mustermann"}
    assert ExInvoice.validate_name(name) == {:ok, "Name is valid"}
  end

  test "validates incorrect name" do
    name = %{first_name: "", last_name: "Mustermann"}
    assert ExInvoice.validate_name(name) == {:error, "Invalid name"}
  end

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
