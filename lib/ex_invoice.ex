defmodule ExInvoice do
  @moduledoc """
  A module for handling invoice-related logic, including address and name validation.
  """
#-----------------------------------------------------------------------------------
#Zusammefassen der Validierungen
    # Startet den Agenten beim Start des Moduls
    def start_link do
      Agent.start_link(fn -> [] end, name: __MODULE__)
    end

    # Funktion zum Speichern von Ergebnissen im Agenten
    defp store_result(result) do
      Agent.update(__MODULE__, fn results -> [result | results] end)
    end

    # Funktion, die alle gespeicherten Ergebnisse abruft
    def fetch_results do
      Agent.get(__MODULE__, fn results -> results end)
    end

  # Zusammenfassungsfunktion
  def summarize_results do
    results = fetch_results()
    Enum.reduce(results, %{}, fn result, acc ->
      Map.update(acc, result, 1, &(&1 + 1))
    end)
  end
  #-----------------------------------------------------------------------------------

  #Validierungen

  # Validation of an address
  def validate_address(%{street: street, city: city, postal_code: postal_code}) do
    street_validation = validate_street(street)
    city_validation = validate_city(city)
    postal_code_validation = validate_postal_code(postal_code)

    result = case {street_validation, city_validation, postal_code_validation} do
      {true, true, true} -> {:ok, "Address is valid"}
      _ -> {:error, "Invalid address"}
    end

    # Speichere das Ergebnis
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

  # Validation of first name and last name
  def validate_name(%{first_name: first_name, last_name: last_name}) do
    first_name_validation = validate_first_name(first_name)
    last_name_validation = validate_last_name(last_name)

    case {first_name_validation, last_name_validation} do
      {true, true} -> {:ok, "Name is valid"}
      _ -> {:error, "Invalid name"}
    end
  end

  defp validate_first_name(first_name) when is_binary(first_name) and byte_size(first_name) > 0, do: true
  defp validate_first_name(_), do: false

  defp validate_last_name(last_name) when is_binary(last_name) and byte_size(last_name) > 0, do: true
  defp validate_last_name(_), do: false


    @doc """
  Validates if the tax amount matches the expected amount based on the total amount and tax rate.
  If no tax is applied, checks for a justification.
  """
def validate_tax(%{total_amount: total, tax_rate: rate, tax_amount: tax, justification: justification}) do
  expected_tax = total * rate / 100
  cond do
    rate not in [7, 19] ->
      {:error, "Invalid tax rate. Only 7% or 19% are allowed."}

    tax == expected_tax ->
      {:ok, "Tax amount matches the expected amount."}

    tax == 0 and is_binary(justification) and byte_size(justification) > 0 ->
      {:ok, "No tax applied, justification provided."}

    tax == 0 and (is_nil(justification) or byte_size(justification) == 0) ->
      {:error, "No tax applied, but no justification provided."}

    true ->
      {:error, "Tax amount does not match the expected amount."}
  end
end


   @doc """
  Validates the presence of invoice and delivery dates or a reference in case one is missing.
  """
  def validate_dates(%{invoice_date: invoice_date, delivery_date: delivery_date, reference: reference}) do
    invoice_date_valid = validate_date(invoice_date)
    delivery_date_valid = validate_date(delivery_date)

    cond do
      # Beide Daten gültig
      invoice_date_valid and delivery_date_valid ->
        {:ok, "Both invoice date and delivery date are valid."}

      # Beide Daten ungültig und kein gültiger Verweis
      (invoice_date_valid or delivery_date_valid) and is_binary(reference) and byte_size(reference) > 0 ->
        {:ok, "One date is valid, and valid reference provided."}

      # Eines der Daten ungültig und kein gültiger Verweis
      (not invoice_date_valid or not delivery_date_valid) and (is_nil(reference) or byte_size(reference) == 0) ->
        {:error, "One or both dates are invalid and no reference provided."}

      # Sonstige Fälle
      true ->
        {:error, "Invalid input. Ensure dates are valid and reference details are provided correctly if needed."}
    end
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

     @doc """
  A funtction to validate German tax numbers and VAT IDs.
  """

  def validate_tax_number(number) when is_binary(number) do
    # Pattern für eine deutsche Steuernummer (10 oder 11 Ziffern)
    tax_number_regex = ~r/^\d{10,11}$/
    # Pattern für eine deutsche USt-IdNr. (DE gefolgt von 9 Ziffern)
    vat_id_regex = ~r/^DE\d{9}$/

    cond do
      Regex.match?(tax_number_regex, number) ->
        {:ok, "Valid German tax number."}

      Regex.match?(vat_id_regex, number) ->
        {:ok, "Valid German VAT ID."}

      true ->
        {:error, "Invalid tax number or VAT ID."}
    end
  end

  def validate_tax_number(_), do: {:error, "Input must be a string."}

       @doc """
  Handelsübliche Bezeichnung und Anzahl auf Positionsebene überprüfen
  """

  def validate_invoice_items(invoice_items, designations) do
    Enum.map(invoice_items, fn {invoice_designation, quantity} ->
      cond do
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
    end)
  end


end
