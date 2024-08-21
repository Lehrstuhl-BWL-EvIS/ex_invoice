defmodule ExInvoice do
  @moduledoc """
  A module for handling invoice-related validations
  """
#-----------------------------------------------------------------------------------
#Summary of validations

    # Starting Agent

      use Agent

      # Start agent
      def start_link do
        Agent.start_link(fn -> [] end, name: __MODULE__)
      end

      # Save results into agent
      def store_result(result) do
        Agent.update(__MODULE__, fn results -> [result | results] end)
      end

      # summary of results
      def summarize_results do
        results = Agent.get(__MODULE__, fn results -> results end)
        Enum.reduce(results, %{}, fn result, acc ->
          Map.update(acc, result, 1, &(&1 + 1))
        end)
      end

      # generate text for validations
      def generate_summary_text do
        summary = summarize_results()
        "Summary of results: #{inspect(summary)}"
      end

  #-----------------------------------------------------------------------------------
  #Validation
  #-----------------------------------------------------------------------------------

  # Validation of an address
  def validate_address(%{street: street, city: city, postal_code: postal_code}) do
    street_validation = validate_street(street)
    city_validation = validate_city(city)
    postal_code_validation = validate_postal_code(postal_code)

    result = case {street_validation, city_validation, postal_code_validation} do
      {true, true, true} -> {:ok, "Address is valid"}
      _ -> {:error, "Invalid address"}
    end

    # Saves result
    store_result(result)
    result
  end

  defp validate_street(street) when is_binary(street) and byte_size(street) > 0, do: true
  defp validate_street(_), do: false

  defp validate_city(city) when is_binary(city) and byte_size(city) > 0, do: true
  defp validate_city(_), do: false

  # German Postal Code
  defp validate_postal_code(postal_code) when is_binary(postal_code) do
    Regex.match?(~r/^\d{5}$/, postal_code)
  end
  defp validate_postal_code(_), do: false
  #-----------------------------------------------------------------------------------

  # Validation of name
  def validate_name(company_name) do
    result = cond do
      company_name == nil or company_name == "" ->
        {:error, "Company name is required"}

      byte_size(company_name) <= 2 or byte_size(company_name) > 100 ->
        {:error, "Name length"}

      not valid_characters?(company_name) ->
        {:error, "Invalid characters in company name"}

      true ->
        {:ok, "Name is valid"}
    end
    store_result(result)
    result
  end

  defp valid_characters?(company_name) do
    # allowed characters: letters, numbers, spaces, "&", ".", "-"
    valid_characters_regex = ~r/^[a-zA-Z0-9\s&.-]+$/
    Regex.match?(valid_characters_regex, company_name)
  end

  #-----------------------------------------------------------------------------------

@doc """
Validates if the tax amount matches the expected amount based on the total amount and tax rate.
If no tax is applied, checks for a justification.
Also checks if the invoice is a simplified invoice based on the total amount being under 250€.
"""
def validate_tax(%{total_amount: total, tax_rate: rate, tax_amount: tax, justification: justification}) do
  expected_tax = total * rate / 100

  result = cond do
    rate not in [7, 19] ->
      {:error, "Invalid tax rate. Only 7% or 19% are allowed."}

    tax == expected_tax ->
      if total < 250 do
        {:ok, "Tax amount matches the expected amount. This is a simplified invoice."}
      else
        {:ok, "Tax amount matches the expected amount."}
      end

    tax == 0 and is_binary(justification) and byte_size(justification) > 0 ->
      if total < 250 do
        {:ok, "No tax applied, justification provided. This is a simplified invoice."}
      else
        {:ok, "No tax applied, justification provided."}
      end

    tax == 0 and (is_nil(justification) or byte_size(justification) == 0) ->
      {:error, "No tax applied, but no justification provided."}

    total < 250 ->
      {:error, "Tax amount does not match the expected amount. This is a simplified invoice."}

    true ->
      {:error, "Tax amount does not match the expected amount."}
  end
  store_result(result)
  result
end



@doc """
  Validates the presence of invoice and delivery dates or a reference in case one is missing.
"""

  def validate_dates(%{invoice_date: invoice_date, delivery_date: delivery_date, reference: reference}) do
    invoice_date_valid = validate_date(invoice_date)
    delivery_date_valid = validate_date(delivery_date)

    result =  cond do
      # Both dates are valid
      invoice_date_valid and delivery_date_valid ->
        {:ok, "Both invoice date and delivery date are valid."}

      # No date is valid, no reference given
      (invoice_date_valid or delivery_date_valid) and is_binary(reference) and byte_size(reference) > 0 ->
        {:ok, "One date is valid, and valid reference provided."}

      # One date is valid, but not a referecen provided
      (not invoice_date_valid or not delivery_date_valid) and (is_nil(reference) or byte_size(reference) == 0) ->
        {:error, "One or both dates are invalid and no reference provided."}

      # everything else
      true ->
        {:error, "Invalid input. Ensure dates are valid and reference details are provided correctly if needed."}
    end
    store_result(result)
    result
  end

  defp validate_date(nil), do: false
  defp validate_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, _date_struct} ->
        true
      {:error, :invalid_format} ->
        IO.puts("Invalid date format detected: #{date}")
        false
      _error ->
        false
    end
  end

#-----------------------------------------------------------------------------------
#A funtction to validate German tax numbers and VAT IDs.
  def validate_tax_number(number) when is_binary(number) do
    # Pattern for a German tax number (10 or 11 digits)
    tax_number_regex = ~r/^\d{10,11}$/
    # Pattern for a german USt-IdNr. ("DE" with 9 digits)
    vat_id_regex = ~r/^DE\d{9}$/

    result =
        cond do
      Regex.match?(tax_number_regex, number) ->
        {:ok, "Valid German tax number."}

      Regex.match?(vat_id_regex, number) ->
        {:ok, "Valid German VAT ID."}

      true ->
        {:error, "Invalid tax number or VAT ID."}
    end
    store_result(result)
    result
  end


  def validate_tax_number(_), do: {:error, "Input must be a string."}

#-----------------------------------------------------------------------------------
#TBD: Verify the standard commercial description and quantity at the item level

  def validate_invoice_items(invoice_items, designations) do
    Enum.map(invoice_items, fn {invoice_designation, quantity} ->

      result = cond do
        # Überprüfung, ob die Bezeichnung in der CSV-Datei vorhanden ist
        Map.get(designations, invoice_designation) == nil ->
          {:error, "#{invoice_designation} is not valid or not found in the CSV file."}

        # Überprüfung, ob die Menge eine Ganzzahl ist
        not is_integer(quantity) ->
          {:error, "Invalid quantity for #{invoice_designation}. Quantity must be an integer."}

        # Überprüfung, ob die Menge größer als null ist
        quantity <= 0 ->
          {:error, "Invalid quantity for #{invoice_designation}. Quantity must be greater than zero."}

        # Falls alles gültig ist, wird die Übereinstimmung bestätigt
        true ->
          description = Map.get(designations, invoice_designation)
          {:ok, %{designation: invoice_designation, description: description, quantity: quantity}}
      end
      store_result(result)
      result
    end)
  end
  #-----------------------------------------------------------------------------------
   @doc """
  A funtction to validate IBAN using Bankster.
  """
  def validate_iban(iban) do
    result =
      case Bankster.iban_validate(iban) do
        :ok -> "Valid IBAN"
        {:ok, _iban} -> "Valid IBAN"
        {:error, reason} -> "Invalid IBAN: #{reason}"
      end
      store_result(result)
    result
  end



end
