defmodule ExInvoiceTestDate do
  use ExUnit.Case
  alias ExInvoice

  describe "validate_dates/1" do
    test "validates successfully when both dates are valid" do
      data = %{invoice_date: "2023-01-15", delivery_date: "2023-01-16", reference: nil}
      assert {:ok, _} = ExInvoice.validate_dates(data)
    end

    test "returns an error when both dates are invalid and no reference is provided" do
      data = %{invoice_date: "not-a-date", delivery_date: "another-bad-date", reference: nil}
      assert {:error, _} = ExInvoice.validate_dates(data)
    end

    test "returns ok when both dates are invalid but a valid reference is provided" do
      data = %{invoice_date: "not-a-date", delivery_date: "another-bad-date", reference: "See Delivery Note DN12345"}
      assert {:ok, _} = ExInvoice.validate_dates(data)
    end

    test "returns an error when one date is invalid, the other is missing, and no reference is provided" do
      data = %{invoice_date: nil, delivery_date: "not-a-date", reference: nil}
      assert {:error, _} = ExInvoice.validate_dates(data)
    end

    test "returns ok when one date is valid, the other is missing, and a valid reference is provided" do
      data = %{invoice_date: "2023-01-15", delivery_date: nil, reference: "Refer to contract CT1234"}
      assert {:ok, _} = ExInvoice.validate_dates(data)
    end

    test "returns error for missing both dates and missing reference" do
      data = %{invoice_date: nil, delivery_date: nil, reference: nil}
      assert {:error, _} = ExInvoice.validate_dates(data)
    end

    test "returns error for invalid reference with invalid dates" do
      data = %{invoice_date: "2024-02-30", delivery_date: "2024-02-29", reference: ""}
      assert {:error, _} = ExInvoice.validate_dates(data)
    end
  end
end
