defmodule ExInvoiceTest do
  use ExUnit.Case

  # Gemeinsame Basisstruktur für die Tests name similar to EXTENDED-Profils
  @valid_invoice %{
    # invoice number
    id: "2024_Q3_234234",
    # fix code for invoice type 74 = invoice to be paid
    typecode: 74,
    # buyer_reference
    buyer_reference: "2INTER00",
    seller_order_referenced_document: nil,
    notes1: nil,
    currency_used: false,
    # Rechnungsdatum
    issue_date_time: ~D[2024-08-10],
    # DeliveryDate
    occurrence_date_time: ~D[2024-08-12],
    note_date: nil,
    seller_trade_party: %{
      forename: "Biller_forename",
      surname: "Biller_surname",
      trading_business_name: "Biller_trading_business_name_name",
      # Street
      line_one: "Biller_line_one",
      city_name: "Biller_city_name",
      post_code_code: "80333",
      country_sub_division_name: "Bayern",
      country_id: "DE",
      notes: nil,
      vat_number: "DE812526315",
      tax_number: "123/456/78910",
      legal_court: "Amtsgericht München",
      legal_HRB: "1234567",
      bank_name: "Sparkasse München",
      bank_IBAN: "DE89370400440532013000",
      bank_BIC: "1234",
      bank_owner: "biller_bank_owner",
      # Mail
      uri_id: "Biller_Mail@test.de",
      contact_tel: "1234567890",
      contact_fax: "0987654321",
      contact_web: "http://example.com"
    },
    buyertradeparty: %{
      forename: nil,
      surname: "",
      trading_business_name: "customer",
      line_one: "Customer_line_one. 345",
      address2: nil,
      address3: nil,
      city_name: "München",
      post_code_code: "80333",
      country_sub_division_name: "Bayern",
      country_id: "DE",
      notes: nil
    },
    invoice_items: [
      %{
        item_number: "A1314",
        item_name: "Test",
        item_description: "Item1_Description",
        item_comments: "",
        item_quantity: 2,
        item_price: 500,
        item_discount_amount: 0,
        item_discount_percentage: 0,
        item_reference: nil,
        item_tax_rate: 19.0,
        item_total_net: 1000,
        item_total_tax: 380
      },
      %{
        item_number: "B2324",
        item_name: "Zweite Artikel",
        item_description: "Item2_Description",
        item_comments: "",
        item_quantity: 1,
        item_price: 1000,
        item_discount_amount: 10,
        item_discount_percentage: 5,
        item_reference: nil,
        item_tax_rate: 19.0,
        item_total_net: 1000,
        item_total_tax: 190
      }
    ],
    invoice_net: 2000,
    invoice_tax: 380,
    invoice_tax_rate: 19,
    invoice_total: 4462.50,
    invoice_payment_skonto_rate: 2,
    invoice_payment_skonto_days: 14,
    invoice_payment_method: "Überweisung",
    invoice_tax_note: nil,
    included_note:
      "Sie sind gesetzlich verpflichtet diese Rechnung mindestens 2 Jahre – als umsatzsteuerlicher Unternehmer 10 Jahre – aufzubewahren. Die Aufbewahrungsfrist beginnt mit Schluss dieses Kalenderjahres."
  }

  test "Valid invoice structure" do
    # Verwende die Basisstruktur ohne Änderungen
    assert ExInvoice.validate_invoice(@valid_invoice) ==
             {:ok, "Validation successful. PDF 2024_Q3_234234.pdf is created."}
  end

  test "Invalid invoice number too long" do
    invalid_invoice = Map.put(@valid_invoice, :id, "12346789101111111111111111111111111111111111")

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Value exceeds maximum length of 20 characters."}
  end

  test "Invalid invoice number" do
    # id = nil
    invalid_invoice = Map.put(@valid_invoice, :id, nil)
    assert ExInvoice.validate_invoice(invalid_invoice) == {:error, "Invoice number not provided"}
  end

  # Test for street too long
  test "Street too long" do
    invalid_invoice =
      Map.put(
        @valid_invoice,
        :seller_trade_party,
        Map.put(
          @valid_invoice.seller_trade_party,
          :line_one,
          "TOOOOOOOOOOOOOOOOOOOOOOLONG12345645345"
        )
      )

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Value exceeds maximum length of 35 characters."}
  end

  # ADRESS
  # Test for street missing
  test "Street missing" do
    invalid_invoice =
      Map.put(
        @valid_invoice,
        :seller_trade_party,
        Map.put(@valid_invoice.seller_trade_party, :line_one, nil)
      )

    assert ExInvoice.validate_invoice(invalid_invoice) == {:error, "Missing field: line_one"}
  end

  # Test for city_name
  test "City too long" do
    invalid_invoice =
      Map.put(
        @valid_invoice,
        :seller_trade_party,
        Map.put(
          @valid_invoice.seller_trade_party,
          :city_name,
          "TOOOOOOOOOOOOOOOOOOOOOOLONG12345645345"
        )
      )

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Value exceeds maximum length of 20 characters."}
  end

  # Test for city_name
  test "City_name missing" do
    invalid_invoice =
      Map.put(
        @valid_invoice,
        :seller_trade_party,
        Map.put(@valid_invoice.seller_trade_party, :city_name, "")
      )

    assert ExInvoice.validate_invoice(invalid_invoice) == {:error, "Missing field: city_name"}
  end

  test "City_name nil" do
    invalid_invoice =
      Map.put(
        @valid_invoice,
        :seller_trade_party,
        Map.put(@valid_invoice.seller_trade_party, :city_name, nil)
      )

    assert ExInvoice.validate_invoice(invalid_invoice) == {:error, "Missing field: city_name"}
  end

  # Test for missing postal code
  test "Invalid postal code nil" do
    invalid_invoice =
      Map.put(
        @valid_invoice,
        :seller_trade_party,
        Map.put(@valid_invoice.seller_trade_party, :post_code_code, nil)
      )

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Missing field: post_code_code"}
  end

  # Test invalid postal code
  test "Invalid postal code" do
    invalid_invoice =
      Map.put(
        @valid_invoice,
        :seller_trade_party,
        Map.put(@valid_invoice.seller_trade_party, :post_code_code, "invalid")
      )

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "German postal code is not valid"}
  end

  # Test invalid postal code
  test "Invalid postal code too long" do
    invalid_invoice =
      Map.put(
        @valid_invoice,
        :seller_trade_party,
        Map.put(@valid_invoice.seller_trade_party, :post_code_code, "123456787")
      )

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "German postal code is not valid"}
  end

  # Test valid postal code
  test "Valid postal code starting with 0" do
    invalid_invoice =
      Map.put(
        @valid_invoice,
        :seller_trade_party,
        Map.put(@valid_invoice.seller_trade_party, :post_code_code, "01145")
      )

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:ok, "Validation successful. PDF 2024_Q3_234234.pdf is created."}
  end

  # Test for postal code outside of Germany
  test "Test for a Postal Code outside of Germany" do
    invalid_address =
      @valid_invoice.seller_trade_party
      |> Map.put(:post_code_code, "123456")
      |> Map.put(:country_id, "FR")

    invalid_invoice = Map.put(@valid_invoice, :seller_trade_party, invalid_address)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:ok, "Validation successful. PDF 2024_Q3_234234.pdf is created."}
  end

  # Test Nachname
  test "Invalid trading_business_name name too long" do
    invalid_invoice =
      Map.put(
        @valid_invoice,
        :seller_trade_party,
        Map.put(
          @valid_invoice.seller_trade_party,
          :trading_business_name,
          "1234567891011121314151617181920212223"
        )
      )

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Value exceeds maximum length of 35 characters."}
  end

  test "Invalid trading_business_name, forename, and surname missing" do
    invalid_address =
      @valid_invoice.seller_trade_party
      |> Map.put(:trading_business_name, nil)
      |> Map.put(:forename, nil)
      |> Map.put(:surname, nil)

    invalid_invoice = Map.put(@valid_invoice, :seller_trade_party, invalid_address)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Missing field: surname or trading_business_name"}
  end

  test "Valid trading_business_name, forename, and surname missing" do
    invalid_address =
      @valid_invoice.seller_trade_party
      |> Map.put(:trading_business_name, "trading_business_name Name")
      |> Map.put(:forename, nil)
      |> Map.put(:surname, nil)

    invalid_invoice = Map.put(@valid_invoice, :seller_trade_party, invalid_address)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:ok, "Validation successful. PDF 2024_Q3_234234.pdf is created."}
  end

  test "Invalid trading_business_name, Valid forename, and surname missing" do
    invalid_address =
      @valid_invoice.seller_trade_party
      |> Map.put(:trading_business_name, nil)
      |> Map.put(:forename, "Vorname")
      |> Map.put(:surname, nil)

    invalid_invoice = Map.put(@valid_invoice, :seller_trade_party, invalid_address)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Missing field: surname or trading_business_name"}
  end

  # TAX

  test "Invalid VAT number, tax ok" do
    # Wrong VAT
    invalid_invoice = put_in(@valid_invoice[:seller_trade_party][:vat_number], "INVALID")

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:ok, "Validation successful. PDF 2024_Q3_234234.pdf is created."}
  end

  test "Invalid payment method" do
    # Invalid Paymet method
    invalid_invoice = Map.put(@valid_invoice, :invoice_payment_method, "Bitcoin")

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Payment method must be one of Überweisung, Kreditkarte, PayPal"}
  end

  # Test invalid tax rate invoice_tax_rate
  test "Invalid tax rate" do
    invalid_invoice = Map.put(@valid_invoice, :invoice_tax_rate, 3)
    assert ExInvoice.validate_invoice(invalid_invoice) == {:error, "Tax: invalid input value"}
  end

  # Test für ungültige IBAN
  test "Invalid IBAN" do
    invalid_invoice =
      Map.put(
        @valid_invoice,
        :seller_trade_party,
        Map.put(@valid_invoice.seller_trade_party, :bank_IBAN, "INVALID_IBAN")
      )

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "IBAN validation failed: invalid_format"}
  end

  # -----------------------
  # Test for a valid German tax number (10 digits in the format xxx/xxx/xxxxx)
  test "Valid German tax number (10 digits)" do
    invalid_address =
      @valid_invoice.seller_trade_party
      |> Map.put(:tax_number, "123/456/78901")
      |> Map.put(:vat_number, nil)

    invalid_invoice = Map.put(@valid_invoice, :seller_trade_party, invalid_address)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:ok, "Validation successful. PDF 2024_Q3_234234.pdf is created."}
  end

  test "Valid German tax number (11 digits)" do
    invalid_address =
      @valid_invoice.seller_trade_party
      |> Map.put(:tax_number, "123/456/12345")
      |> Map.put(:vat_number, nil)

    invalid_invoice = Map.put(@valid_invoice, :seller_trade_party, invalid_address)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:ok, "Validation successful. PDF 2024_Q3_234234.pdf is created."}
  end

  # Test for a valid German VAT ID ("DE" followed by 9 digits)
  test "Valid German VAT ID 9 digits" do
    invalid_address =
      @valid_invoice.seller_trade_party
      |> Map.put(:tax_number, nil)
      |> Map.put(:vat_number, "DE812526315")

    invalid_invoice = Map.put(@valid_invoice, :seller_trade_party, invalid_address)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:ok, "Validation successful. PDF 2024_Q3_234234.pdf is created."}
  end

  # Test for an invalid German tax number (wrong format)
  test "InValid German VAT ID" do
    invalid_address =
      @valid_invoice.seller_trade_party
      |> Map.put(:tax_number, nil)
      |> Map.put(:vat_number, "1DE13456789")

    invalid_invoice = Map.put(@valid_invoice, :seller_trade_party, invalid_address)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Invalid tax number and invalid VAT number"}
  end

  # Test for Invalid German VAT ID too short
  test "Invalid German VAT ID too short" do
    invalid_address =
      @valid_invoice.seller_trade_party
      |> Map.put(:tax_number, nil)
      |> Map.put(:vat_number, "DE12345678")

    invalid_invoice = Map.put(@valid_invoice, :seller_trade_party, invalid_address)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Invalid tax number and invalid VAT number"}
  end

  # Test for Invalid German VAT ID (empty string)
  test "Invalid German VAT ID (empty string)" do
    invalid_address =
      @valid_invoice.seller_trade_party
      |> Map.put(:tax_number, nil)
      |> Map.put(:vat_number, "")

    invalid_invoice = Map.put(@valid_invoice, :seller_trade_party, invalid_address)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Invalid tax number and invalid VAT number"}
  end

  # Test for an invalid VAT ID (nil)
  test "Invalid German VAT ID and Tax-ID (nil)" do
    invalid_address =
      @valid_invoice.seller_trade_party
      |> Map.put(:tax_number, nil)
      |> Map.put(:vat_number, nil)

    invalid_invoice = Map.put(@valid_invoice, :seller_trade_party, invalid_address)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Invalid tax number and invalid VAT number"}
  end

  # ITEMS
  test "Invalid item name too long" do
    invalid_invoice =
      update_in(@valid_invoice[:invoice_items], fn items ->
        [%{Enum.at(items, 0) | item_name: String.duplicate("A", 51)}]
      end)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Item name exceeds maximum length of 25 characters"}
  end

  test "Invalid item quantity is nil" do
    invalid_invoice =
      update_in(@valid_invoice[:invoice_items], fn items ->
        [%{Enum.at(items, 0) | item_quantity: nil}]
      end)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Item has missing or invalid fields: quantity"}
  end

  test "Invalid item quantity is not a number" do
    invalid_invoice =
      update_in(@valid_invoice[:invoice_items], fn items ->
        [%{Enum.at(items, 0) | item_quantity: "invalid"}]
      end)

    assert ExInvoice.validate_invoice(invalid_invoice) ==
             {:error, "Item has missing or invalid fields: quantity"}
  end

  # -----------------------
end
