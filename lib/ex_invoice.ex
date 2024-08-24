defmodule ExInvoice do
  def validate_invoices(invoices) do
    Enum.each(invoices[:invoices], fn invoice ->
      # Check if its a normal invoice (>250€) or a simplfied one (<250€)

      results =
        if invoice[:invoice_net] >= 250 do
          # Normal Invoice
          [
            validate_address(invoice[:invoice_address]),
            validate_address(invoice[:invoice_delivery_address]),
            validate_tax_number(invoice[:invoice_address][:vat_number]),
            validate_tax_number(invoice[:invoice_address][:tax_number]),
            validate_date(invoice[:invoice_date]),
            validate_date_delivery(
              invoice[:invoice_date],
              invoice[:delivery_date],
              invoice[:note_date]
            ),
            validate_invoice_number(invoice[:invoice_number]),
            validate_tax(
              invoice[:invoice_tax_rate],
              invoice[:invoice_net],
              invoice[:invoice_tax],
              invoice[:invoice_tax_note]
            )
          ]
        else
          # Simplified Invoice
          [
            validate_address(invoice[:invoice_address]),
            validate_date(invoice[:invoice_date]),
            validate_tax(
              invoice[:invoice_tax_rate],
              invoice[:invoice_net],
              invoice[:invoice_tax],
              invoice[:invoice_tax_note]
            )
          ]
        end

      # Result for every invoice
      #IO.inspect(results, label: "Validation results for invoice #{invoice[:invoice_number]}")
      #TBD no IO for the result of the validations

      case Enum.find(results, fn result -> match?({:error, _}, result) end) do
        nil ->
          IO.puts("All validations passed for invoice #{invoice[:invoice_number]}.")

        {:error, message} ->
          IO.puts("Validation failed for invoice #{invoice[:invoice_number]}: #{message}")
      end
    end)
  end

  # -----------------------------------------------------------------------------------

  defp validate_address(%{
         company: company,
         forename: forename,
         surname: surname,
         street: street,
         city: city,
         postal_code: postal_code,
         country: country
       }) do
    # Check if all necessary fields are available
    if (not is_nil(company) or (not is_nil(surname) and not is_nil(forename))) and
         not is_nil(street) and street != "" and
         not is_nil(city) and city != "" and
         not is_nil(postal_code) and postal_code != "" and
         not is_nil(country) and country != "" do
      # Checks Postal Code
      case validate_postal_code(postal_code, country) do
        {:ok, _} = result -> result
        {:error, _} = error -> error
      end
    else
      {:error, "Missing field: company/surname, street, city, postal_code, country."}
    end
  end

  defp validate_address(_), do: {:error, "Address not complete."}

  defp validate_postal_code(postal_code, "DE") do
    if Regex.match?(~r/^\d{5}$/, postal_code) do
      {:ok, "Address is valid."}
    else
      {:error, "German postal code is not valid."}
    end
  end

  # Every other postal code from another country gets just confirmed. TBD? Validations for other Countries
  defp validate_postal_code(_postal_code, _country),
    do: {:ok, "Adress is valid, but postal code not checked as its not a german postal code."}

  # -----------------------------------------------------------------------------------
  # A private funtction to validate German tax numbers and VAT IDs.

  defp validate_tax_number(number) when is_binary(number) do
    # Pattern for a German tax number (10 or 11 digits)
    # https://de.wikipedia.org/wiki/Steuernummer
    # https://ec.europa.eu/taxation_customs/vies/#/vat-validation
    # https://github.com/taxjar/ex_vatcheck
    # Probably have to be more
    # IO.puts("INPUT_TAX number: #{number}")
    tax_number_regex = ~r/^\d{3}\/\d{3}\/\d{5}$/
    # Pattern for a German USt-IdNr. ("DE" with 9 digits)
    vat_id_regex = ~r/^DE\d{9}$/

    cond do
      Regex.match?(tax_number_regex, number) ->
        {:ok, "#{number} Tax_Number_valid"}

      Regex.match?(vat_id_regex, number) ->
        {:ok, "#{number} VAT_Number_valid"}

      true ->
        {:error, "#{number} Invalid tax number or VAT ID."}
    end
  end

  defp validate_tax_number(_), do: {:error, "No VAT or tax number provided"}

  # -----------------------------------------------------------------------------------
  # Checks Date
  # defp validate_date(%Date{} = _date) do
  #   {:ok, "Valid date."}
  # end

  # defp validate_date(nil) do
  #   {:error, "No date provided."}
  # end

  # defp validate_date(_) do
  #   {:error, "Invalid date format or value."}
  # end

  defp validate_date(date) do
    cond do
      is_nil(date) ->
        {:error, "No date provided."}

      is_struct(date, Date) ->
        {:ok, "Valid date."}

      true ->
        {:error, "Invalid date format or value."}
    end
  end

  defp validate_date_delivery(invoice_date, delivery_date, note_date) do
    cond do
      # Check if `delivery_date` is nil and the note "Rechnungsdatum = Lieferdatum" is provided
      is_nil(delivery_date) and note_date == "Rechnungsdatum = Lieferdatum" ->
        {:ok, "Valid: Rechnungsdatum = Lieferdatum"}

      # Check if `delivery_date` is nil and the note "Rechnungsdatum = Lieferdatum" is not provided
      is_nil(delivery_date) ->
        {:error,
         "Fehler: Kein Lieferdatum vorhanden und der Hinweis 'Rechnungsdatum = Lieferdatum' fehlt."}

      # Check if `delivery_date` and `invoice_date` are valid dates and are the same
      validate_date(delivery_date) == {:ok, "Valid date."} and delivery_date == invoice_date ->
        {:ok, "Valid: Rechnungsdatum = Lieferdatum"}

      # Check if `delivery_date` and `invoice_date` are valid dates and are different
      validate_date(delivery_date) == {:ok, "Valid date."} ->
        {:ok, "Valid: Delivery Date #{delivery_date}, Invoice Date #{invoice_date}"}

      # Fallback
      true ->
        {:error, "Date input error"}
    end
  end

  # -----------------------------------------------------------------------------------
  # Checks invoice number
  defp validate_invoice_number(nil) do
    {:error, "Invoice number not provided."}
  end

  defp validate_invoice_number(invoice_number) when is_binary(invoice_number) do
    if String.trim(invoice_number) == "" do
      {:error, "Invoice number not provided."}
    else
      {:ok, "Invoice number provided: #{invoice_number}"}
    end
  end

  # -----------------------------------------------------------------------------------
  # checks whether the tax rate has been calculated correctly and applied
  defp validate_tax(tax_rate, total_net, total_tax, tax_note) do
    cond do
      is_nil(total_net) or is_nil(total_tax) or is_nil(tax_rate) ->
        {:error, "tax: missing field"}

      total_net <= 0 or total_tax < 0 or tax_rate not in [0, 7, 19] ->
        {:error, "tax: invalid input value"}

      tax_rate == 0 and String.trim(tax_note) == "" ->
        {:error, "tax: no reason for tax exemption provided"}

      # Checks if the provided tax rate matches the calculated one.
      tax_rate != round(total_tax / total_net * 100) ->
        {:error, "tax_rate does not match the calculated tax rate"}

      true ->
        {:ok, "#{tax_rate}% tax applied correctly"}
    end
  end
  # -----------------------------------------------------------------------------------
  # -----------------------------------------------------------------------------------

end
