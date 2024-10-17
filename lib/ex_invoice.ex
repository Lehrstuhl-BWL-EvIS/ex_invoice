defmodule ExInvoice do
  @moduledoc """
  The `ExInvoice` module provides a set of functions to validate invoices according to various criteria, such as the seller and buyer addresses, tax information, dates, invoice numbers, payment terms, and item details. It supports both normal invoices (with a net amount over 250€) and simplified invoices (with a net amount under 250€).

  ## Features:

  - **Validation of Seller and Buyer Addresses**: Ensures that all required fields, such as business name, forename, surname, address, city, and postal code, are present and valid.
  - **Tax and VAT Validation**: Validates German tax numbers and VAT IDs, including checking tax rates and ensuring the proper application of tax exemptions if applicable.
  - **Date Validation**: Ensures that the invoice issue date and delivery date are valid and consistent, with special handling for the scenario where the delivery date is not provided and the invoice contains the note "Rechnungsdatum = Lieferdatum."
  - **Invoice Number Validation**: Checks the presence and length of the invoice ID.
  - **Payment Terms Validation**: Ensures that Skonto (discount) rates, Skonto days, and payment methods are valid.
  - **Item Validation**: Checks that all items in the invoice are valid, including names, quantities, and prices. Ensures the total net price of the items matches the expected invoice net.
  - **IBAN Validation**: Validates the IBAN using the `Bankster` library.

  ## Normal vs. Simplified Invoices:

  - **Normal Invoice**: Invoices with a net amount >= 250€ require a full set of validations, including the seller and buyer address, tax information, delivery and issue dates, invoice number, items, and payment terms.
  - **Simplified Invoice**: Invoices with a net amount < 250€ have fewer validation requirements, focusing on the seller's address, issue date, tax information, items, and payment details.

  ## Usage:

  To validate an invoice, the `validate_invoice/1` function processes the invoice and returns either:

  - `{:ok, "Validation successful"}` if all validations pass, and generates a PDF of the invoice.
  - `{:error, "Validation failed: [errors]"}` if one or more validations fail, providing details on the errors.

  """
  def validate_invoice(invoice) do
    # Check if its a normal invoice (>250€) or a simplified one (<250€)
    results =
      if invoice.invoice_net >= 250 do
        # Normal Invoice
        [
          validate_address(invoice.seller_trade_party),
          validate_address(invoice.buyertradeparty),
          validate_tax_information(
            invoice.seller_trade_party.vat_number,
            invoice.seller_trade_party.tax_number
          ),
          validate_date(invoice.issue_date_time),
          validate_date_delivery(
            invoice.issue_date_time,
            invoice.occurrence_date_time,
            invoice.note_date
          ),
          validate_invoice_number(invoice.id),
          validate_tax(
            invoice.invoice_tax_rate,
            invoice.invoice_net,
            invoice.invoice_tax,
            invoice.invoice_tax_note
          ),
          validate_all_items(invoice.invoice_items, invoice.invoice_net),
          validate_iban(invoice.seller_trade_party.bank_IBAN),
          validate_email(invoice.seller_trade_party.uri_id),
          validate_payment_terms(
            invoice.invoice_payment_skonto_rate,
            invoice.invoice_payment_skonto_days,
            invoice.invoice_payment_method
          )
        ]
      else
        # Simplified Invoice
        [
          validate_address(invoice.seller_trade_party),
          validate_date(invoice.issue_date_time),
          validate_address(invoice.buyertradeparty),
          validate_tax(
            invoice.invoice_tax_rate,
            invoice.invoice_net,
            invoice.invoice_tax,
            invoice.invoice_tax_note
          ),
          validate_all_items(invoice.invoice_items, invoice.invoice_net),
          validate_iban(invoice.seller_trade_party.bank_IBAN),
          validate_email(invoice.seller_trade_party.uri_id)
        ]
      end

    # Collecting all errors
    errors =
      results
      |> Enum.filter(fn result -> match?({:error, _}, result) end)
      |> Enum.map(fn {:error, message} -> message end)

    case errors do
      [] ->
        # No error occured. PDF will be printed.
        ExInvoicePDF.generate_pdf(invoice)
        {:ok, "Validation successful. PDF #{invoice.id}.pdf is created."}

      _ ->
        # Error occurre. Error feedback will be provided via a list.
        {:error, "Validation failed for invoice #{invoice.id}: #{Enum.join(errors, ", ")}"}
    end
  end

  # -----------------------------------------------------------------------------------
  defp validate_length(value, max_length) when is_binary(value) do
    if String.length(value) <= max_length do
      {:ok, value}
    else
      {:error, "Value exceeds maximum length of #{max_length} characters."}
    end
  end

  defp validate_length(nil, _max_length), do: {:ok, nil}

  # ------------------------------------------------------------------------------------
  # Functions to check if an adress is complete
  defp validate_address(%{
         trading_business_name: trading_business_name,
         forename: forename,
         surname: surname,
         line_one: line_one,
         city_name: city_name,
         post_code_code: post_code_code,
         country_id: country_id
       }) do
    with :ok <- validate_name(trading_business_name, surname),
         {:ok, _} <- validate_length(trading_business_name, 35),
         {:ok, _} <- validate_length(forename, 20),
         {:ok, _} <- validate_length(surname, 20),
         {:ok, _} <- validate_length(city_name, 20),
         {:ok, _} <- validate_length(line_one, 35),
         :ok <- validate_required_field(line_one, "line_one"),
         :ok <- validate_required_field(city_name, "city_name"),
         :ok <- validate_required_field(post_code_code, "post_code_code"),
         :ok <- validate_required_field(country_id, "country_id"),
         {:ok, _} <- validate_post_code_code(post_code_code, country_id) do
      {:ok, "Address is valid."}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  defp validate_address(_), do: {:error, "Address not complete."}
  # validate_name(trading_business_name, forename, surname),
  defp validate_name(nil, nil), do: {:error, "Missing field: surname or trading_business_name"}
  defp validate_name("", nil), do: {:error, "Missing field: surname or trading_business_name"}
  defp validate_name(nil, ""), do: {:error, "Missing field: surname or trading_business_name"}
  defp validate_name("", ""), do: {:error, "Missing field: surname or trading_business_name"}

  # If either surname or company name is valid (not nil or empty)
  defp validate_name(_, _), do: :ok

  defp validate_required_field(value, field_name) do
    if is_nil(value) or value == "" do
      {:error, "Missing field: #{field_name}"}
    else
      :ok
    end
  end

  defp validate_post_code_code(post_code_code, "DE") do
    if Regex.match?(~r/^\d{5}$/, post_code_code) do
      {:ok, "Postal code is valid"}
    else
      {:error, "German postal code is not valid"}
    end
  end

  defp validate_post_code_code(nil, _country_id), do: {:error, "No postal code provided"}

  defp validate_post_code_code(_post_code_code, _country_id) do
    {:ok, "Address is valid, but postal code not checked as it's not a German postal code."}
  end

  # -----------------------------------------------------------------------------------
  # Validate German tax numbers and VAT IDs.
  #  defp validate_tax_information(nil), do: {:error, "No VAT or tax number provided"}

  defp validate_tax_information(vat_number, tax_number) do
    case {validate_tax_number(tax_number), validate_vat_number(vat_number)} do
      {{:ok, _}, {:ok, _}} ->
        {:ok, "Tax and VAT-number correct"}

      {{:ok, _}, {:error, _}} ->
        {:ok, "Tax number correct"}

      {{:error, _}, {:ok, _}} ->
        {:ok, "VAT-number correct"}

      {{:error, _}, {:error, _}} ->
        {:error, "Invalid tax number and invalid VAT number"}
    end
  end

  # Validation of german VAT
  defp validate_tax_number(nil), do: {:error, "Invalid tax number"}

  defp validate_tax_number(number) when is_binary(number) do
    # Pattern for german tax number(10 or 11 chars)
    tax_number_regex = ~r/^\d{3}\/\d{3}\/\d{5}$/

    if Regex.match?(tax_number_regex, number) do
      {:ok, "#{number} Tax_Number_valid"}
    else
      {:error, "Invalid tax number"}
    end
  end

  # Validation USt-IdNr. (german format)
  defp validate_vat_number(nil), do: {:error, "No VAT number provided"}

  defp validate_vat_number(number) when is_binary(number) do
    case ExVatcheck.check(number) do
      %ExVatcheck.VAT{valid: true} ->
        {:ok, "#{number} VAT_Number_valid"}

      %ExVatcheck.VAT{valid: false} ->
        {:error, "Invalid VAT number"}

      _ ->
        {:error, "Unexpected response from VAT validation"}
    end
  end

  # -----------------------------------------------------------------------------------
  # -----------------------------------------------------------------------------------
  # Checks if the date is valid
  defp validate_date(%Date{} = _date) do
    {:ok, "Valid date."}
  end

  defp validate_date(nil) do
    {:error, "No date provided"}
  end

  defp validate_date(_) do
    {:error, "Invalid date format or value"}
  end

  # Invoice date equals delivery date, no delivery date provided
  defp validate_date_delivery(_invoice_date, nil, "Rechnungsdatum = Lieferdatum") do
    {:ok, "Invoice date equals delivery date"}
  end

  # No delivery date, missing hint 'Invoice date equals delivery date'
  defp validate_date_delivery(_invoice_date, nil, _note_date) do
    {:error, "No delivery date and hint 'Rechnungsdatum = Lieferdatum' is missing"}
  end

  # Valid delivery date and invoice date equals delivery date
  defp validate_date_delivery(invoice_date, delivery_date, _note_date) do
    case validate_date(delivery_date) do
      {:ok, "Valid date."} when delivery_date == invoice_date ->
        {:ok, "Valid: Invoice date equals delivery date"}

      {:ok, "Valid date."} ->
        {:ok, "Valid: Delivery Date #{delivery_date}, Invoice Date #{invoice_date}"}

      _ ->
        {:error, "Date input error"}
    end
  end

  # -----------------------------------------------------------------------------------
  # Checks invoice number
  defp validate_invoice_number(nil) do
    {:error, "Invoice number not provided"}
  end

  defp validate_invoice_number(id) when is_binary(id) do
    if String.trim(id) == "" do
      {:error, "Invoice number not provided"}
    else
      case validate_length(String.trim(id), 20) do
        {:ok, trimmed_id} ->
          {:ok, "Invoice number provided: #{trimmed_id}"}

        {:error, _} = error ->
          error
      end
    end
  end

  # -----------------------------------------------------------------------------------
  # Checks Skonto and payment method.
  defp validate_payment_terms(skonto_rate, skonto_days, payment_method) do
    with {:ok, _rate} <- validate_rate(skonto_rate),
         {:ok, _days} <- validate_days(skonto_days),
         {:ok, _payment_method} <- validate_payment_method(payment_method) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Validiaation of skonto rate in %
  defp validate_rate(rate) when is_number(rate) and rate >= 0 and rate <= 100 do
    {:ok, rate}
  end

  defp validate_rate(_), do: {:error, "Discount rate must be a number between 0 and 100."}

  # Validation skonto days
  defp validate_days(days) when is_integer(days) and days > 0 do
    {:ok, days}
  end

  defp validate_days(_), do: {:error, "Days must be a positive integer."}

  # Validation payment method
  defp validate_payment_method(payment_method) when is_binary(payment_method) do
    accepted_payment_methods = ["Überweisung", "Kreditkarte", "PayPal"]

    case payment_method in accepted_payment_methods do
      true ->
        {:ok, payment_method}

      false ->
        {:error, "Payment method must be one of #{Enum.join(accepted_payment_methods, ", ")}"}
    end
  end

  defp validate_payment_method(_), do: {:error, "Invalid payment method format."}

  # -----------------------------------------------------------------------------------
  # Checks whether the tax rate has been calculated correctly and applied
  defp validate_tax(tax_rate, total_net, total_tax, tax_note) do
    with :ok <- validate_tax_fields(tax_rate, total_net, total_tax),
         :ok <- validate_tax_values(tax_rate, total_net, total_tax),
         :ok <- validate_tax_note_if_exempt(tax_rate, tax_note),
         :ok <- validate_calculated_tax_rate(tax_rate, total_net, total_tax) do
      {:ok, "#{tax_rate}% tax applied correctly"}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  defp validate_tax_fields(nil, _, _), do: {:error, "tax: missing field"}
  defp validate_tax_fields(_, nil, _), do: {:error, "tax: missing field"}
  defp validate_tax_fields(_, _, nil), do: {:error, "tax: missing field"}
  defp validate_tax_fields(_, _, _), do: :ok

  defp validate_tax_values(tax_rate, total_net, total_tax) do
    if total_net <= 0 or total_tax < 0 or tax_rate not in [0, 7, 19] do
      {:error, "Tax: invalid input value"}
    else
      :ok
    end
  end

  defp validate_tax_note_if_exempt(0, tax_note) do
    if String.trim(tax_note) == "" do
      {:error, "Tax: no reason for tax exemption provided"}
    else
      :ok
    end
  end

  defp validate_tax_note_if_exempt(_, _), do: :ok

  defp validate_calculated_tax_rate(tax_rate, total_net, total_tax) do
    if tax_rate != round(total_tax / total_net * 100) do
      {:error, "Tax: tax_rate does not match the calculated tax rate"}
    else
      :ok
    end
  end

  # -----------------------------------------------------------------------------------
  def validate_email(email) when is_binary(email) do
    email_regex = ~r/^[A-Za-z0-9._%+-+']+@[A-Za-z0-9.-]+\.[A-Za-z]+$/

    case Regex.match?(email_regex, email) do
      true ->
        {:ok, "Mail providedd"}

      false ->
        {:error, "Invalid email format"}
    end
  end

  # -----------------------------------------------------------------------------------
  # Checks items
  # Collects the results for allitems
  defp validate_all_items(items, expected_net) do
    if Enum.empty?(items) do
      {:error, "Invoice must contain at least one item."}
    else
      validations = Enum.map(items, &validate_item/1)

      errors =
        Enum.filter(validations, fn
          {:error, _} -> true
          {:ok, _} -> false
        end)

      if errors == [] do
        net_price =
          Enum.reduce(items, 0, fn item, acc ->
            acc + item[:item_total_net]
          end)

        if net_price == expected_net do
          {:ok, "All items are valid. Net value of all items are #{net_price} €"}
        else
          {:error,
           "The calculated net price #{net_price} does not match the expected invoice net #{expected_net}."}
        end
      else
        error_messages =
          errors
          |> Enum.map(fn {:error, message} -> message end)
          |> Enum.join("; ")

        {:error, error_messages}
      end
    end
  end

  defp validate_item(item) do
    missing_or_invalid_fields =
      item
      |> Enum.filter(fn
        {:item_name, name} when is_nil(name) or not is_binary(name) -> true
        {:item_quantity, quantity} when is_nil(quantity) or not is_number(quantity) -> true
        {:item_price, price} when is_nil(price) or not is_number(price) -> true
        _ -> false
      end)
      |> Enum.map(fn
        {:item_name, _} -> "name"
        {:item_quantity, _} -> "quantity"
        {:item_price, _} -> "price"
      end)

    case missing_or_invalid_fields do
      [] ->
        # additonal check of name_length
        case Enum.find(item, fn
               {:item_name, name} ->
                 is_binary(name) and
                   case validate_length(name, 25) do
                     {:error, _msg} -> true
                     _ -> false
                   end

               _ ->
                 false
             end) do
          nil ->
            {:ok, item[:item_total_net]}

          {:item_name, _} ->
            {:error, "Item name exceeds maximum length of 25 characters"}
        end

      fields ->
        {:error, "Item has missing or invalid fields: #{Enum.join(fields, ", ")}"}
    end
  end

  # -----------------------------------------------------------------------------------
  # Iban Validation with Bankster, is needed to provide feedback in the same way as other validations
  def validate_iban(iban) do
    case Bankster.Iban.validate(iban) do
      {:ok, iban_value} ->
        {:ok, "IBAN is valid: #{iban_value}"}

      {:error, reason} ->
        {:error, "IBAN validation failed: #{reason}"}

      _ ->
        {:error, "Unexpected response from IBAN validation."}
    end
  end

  # -----------------------------------------------------------------------------------
end

# -----------------------------------------------------------------------------------
