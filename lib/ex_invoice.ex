defmodule ExInvoice do
  def validate_invoices(invoice) do
    # Check if its a normal invoice (>250€) or a simplified one (<250€)
    results =
      if invoice.invoice_net >= 250 do
        # Normal Invoice
        [
          validate_address(invoice.invoice_address),
          validate_address(invoice.invoice_delivery_address),
          validate_tax_number(invoice.invoice_address.vat_number),
          validate_tax_number(invoice.invoice_address.tax_number),
          validate_date(invoice.invoice_date),
          validate_date_delivery(
            invoice.invoice_date,
            invoice.delivery_date,
            invoice.note_date
          ),
          validate_invoice_number(invoice[:invoice_number]),
          validate_tax(
            invoice.invoice_tax_rate,
            invoice.invoice_net,
            invoice.invoice_tax,
            invoice.invoice_tax_note
          ),
          validate_all_items(invoice.invoice_items),
          Bankster.Iban.validate(invoice.invoice_address.bank_IBAN)
        ]
      else
        # Simplified Invoice
        [
          validate_address(invoice.invoice_address),
          validate_date(invoice.invoice_date),
          validate_tax(
            invoice.invoice_tax_rate,
            invoice.invoice_net,
            invoice.invoice_tax,
            invoice.invoice_tax_note
          ),
          validate_all_items(invoice.invoice_items)
        ]
      end

    # Result for every invoice
    # IO.inspect(results, label: "Validation results for invoice #{invoice[:invoice_number]}")

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil ->
        # IO.puts("All validations passed for invoice #{invoice[:invoice_number]}.")

        generate_pdf(invoice)

      {:error, message} ->
        nil
        # IO.puts("Validation failed for invoice #{invoice[:invoice_number]}: #{message}")
    end
  end

  # -----------------------------------------------------------------------------------
  # Functions to check if an adress is complete
  defp validate_address(%{
         company: company,
         forename: forename,
         surname: surname,
         street: street,
         city: city,
         postal_code: postal_code,
         country: country
       }) do
    with :ok <- validate_name(company, forename, surname),
         :ok <- validate_required_field(street, "street"),
         :ok <- validate_required_field(city, "city"),
         :ok <- validate_required_field(postal_code, "postal_code"),
         :ok <- validate_required_field(country, "country"),
         {:ok, _} <- validate_postal_code(postal_code, country) do
      {:ok, "Address is valid."}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  defp validate_address(_), do: {:error, "Address not complete."}
  # validate_name(company, forename, surname),
  defp validate_name(nil, nil, nil), do: {:error, "Missing field: surname or company name"}
  defp validate_name(_, nil, nil), do: :ok
  defp validate_name(nil, _, _), do: :ok
  defp validate_name(_, _, _), do: :ok

  defp validate_required_field(value, field_name) do
    if is_nil(value) or value == "" do
      {:error, "Missing field: #{field_name}"}
    else
      :ok
    end
  end

  defp validate_postal_code(postal_code, "DE") do
    if Regex.match?(~r/^\d{5}$/, postal_code) do
      {:ok, "Postal code is valid."}
    else
      {:error, "German postal code is not valid."}
    end
  end

  defp validate_postal_code(nil, _country), do: {:error, "No postal code provided"}

  defp validate_postal_code(_postal_code, _country) do
    {:ok, "Address is valid, but postal code not checked as it's not a German postal code."}
  end

  # -----------------------------------------------------------------------------------
  # A private funtction to validate German tax numbers and VAT IDs.

  defp validate_tax_number(number) when is_binary(number) do
    # Pattern for a German tax number (10 or 11 digits)
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
  defp validate_date(%Date{} = _date) do
    {:ok, "Valid date."}
  end

  defp validate_date(nil) do
    {:error, "No date provided."}
  end

  defp validate_date(_) do
    {:error, "Invalid date format or value."}
  end

  defp validate_date_delivery(invoice_date, delivery_date, note_date) do
    cond do
      # Check if `delivery_date` is nil and the note "Rechnungsdatum = Lieferdatum" is provided
      is_nil(delivery_date) and note_date == "Rechnungsdatum = Lieferdatum" ->
        {:ok, "Valid: Rechnungsdatum = Lieferdatum"}

      # Check if `delivery_date` is nil and the note "Rechnungsdatum = Lieferdatum" is not provided
      is_nil(delivery_date) ->
        {:error, "Error: No delivery date and hint  'Rechnungsdatum = Lieferdatum' is missing"}

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
      {:error, "tax: invalid input value"}
    else
      :ok
    end
  end

  defp validate_tax_note_if_exempt(0, tax_note) do
    if String.trim(tax_note) == "" do
      {:error, "tax: no reason for tax exemption provided"}
    else
      :ok
    end
  end

  defp validate_tax_note_if_exempt(_, _), do: :ok

  defp validate_calculated_tax_rate(tax_rate, total_net, total_tax) do
    if tax_rate != round(total_tax / total_net * 100) do
      {:error, "tax_rate does not match the calculated tax rate"}
    else
      :ok
    end
  end

  # -----------------------------------------------------------------------------------
  # Checks items
  # Collects the results for allitems
  defp validate_all_items(items) do
    validations = Enum.map(items, &validate_item/1)

    errors =
      Enum.filter(validations, fn
        {:error, _} -> true
        :ok -> false
      end)

    if errors == [] do
      :ok
    else
      {:error, Enum.map(errors, fn {:error, message} -> message end)}
    end
  end

  defp validate_item(item) do
    missing_or_invalid_fields =
      item
      |> Enum.filter(fn
        {:item_name, nil} -> true
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
        :ok

      fields ->
        {:error, "Item has missing or invalid fields: #{Enum.join(fields, ", ")}"}
    end
  end

  # -----------------------------------------------------------------------------------
  # PDF Creation via ChromicPDF

  def generate_pdf(invoice) do
    # Create a HTML File for using ChromicPDF
    invoice_html = create_html_invoice(invoice)
    # Create an output folder in case it doesnt exist
    File.mkdir_p!("invoices_output")
    # Filename of HTML=invoice number
    filename = "invoice_#{invoice[:invoice_number]}.pdf"

    [
      size: :a4,
      content: invoice_html
    ]
    |> ChromicPDF.Template.source_and_options()
    |> ChromicPDF.print_to_pdfa(output: Path.join("invoices_output", filename))
  end

  # -----------------------------------------------------------------------------------
  # Creates a html necessary for the pdf print via chromic_pdf

  defp create_html_invoice(invoice) do
    # CSS and IMG has to be in folder assests/image or assest/css
    css_path = Path.join([Path.expand("../assets/css", __DIR__), "styles.css"])
    logo_path = Path.join([Path.expand("../assets/images", __DIR__), "logo.webp"])

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Invoice #{invoice.invoice_number}</title>
    <link rel="stylesheet" href="file://#{css_path}">
    </head>
    <body>
    <div class="invoice-box">
       <div class="header">
          <div class="customer-details">
               <div>#{invoice.invoice_delivery_address.company}</div>
               <div>#{invoice.invoice_delivery_address.street}</div>
               <div>#{invoice.invoice_delivery_address.postal_code} #{invoice.invoice_delivery_address.city}</div>
          </div>
           <div class="invoice-date">
               <img src="file://#{logo_path}" alt="Company Logo"><br>
               <div>Rechnungsdatum: #{invoice.invoice_date}</div>
               <div>Lieferdatum: #{invoice.delivery_date}</div>
               <strong>#{invoice.invoice_address.company}</strong><br>
               #{invoice.invoice_address.street}<br>
               #{invoice.invoice_address.postal_code} #{invoice.invoice_address.city}<br>
               #{invoice.invoice_address.country}<br>
           </div>
       </div>

       <div class="invoice-title">
           Rechnung
       </div>

       <div class="invoice-details">
           <div>Rechnungsnummer: #{invoice.invoice_number}</div>
           <div>Auftrags-Nr.: #{invoice.order_number || "N/A"}</div>
           <div>Kundenreferenz: #{invoice.account_reference}</div>
       </div>

       <table class="table">
           <thead>
               <tr>
                   <th>Pos.</th>
                   <th>Art-Nr.</th>
                   <th>Bezeichnung</th>
                   <th>Menge</th>
                   <th>Einheit</th>
                   <th>Preis/Einh. (€)</th>
                   <th>Gesamt (€)</th>
               </tr>
           </thead>
           <tbody>
               #{create_item(invoice.invoice_items)}
             <tr>
               <td colspan="7">&nbsp;</td>
             </tr>
               <tr>
                   <td colspan="6" style="text-align: left;">Summe Netto:</td>
                   <td style="text-align: right;">#{invoice.invoice_net} €</td>
               </tr>
               <tr>
                   <td colspan="6" style="text-align: left;">MWST (#{invoice.invoice_tax_rate}%):</td>
                   <td style="text-align: right;">#{invoice.invoice_tax} €</td>
               </tr>
               <tr>
                   <td colspan="6" style="text-align: left;"><strong>Endsumme:</strong></td>
                   <td style="text-align: right;"><strong>#{invoice.invoice_total} €</strong></td>
               </tr>

           </tbody>
       </table>
       <div class="notes">
           <div>Bitte überweisen SIe den Rechnungsbetrag innerhalb von 14 Tagen auf unser unten genanntes Konto. </div>
           <div>Rechnungsbetrag zahlbar abzüglich #{invoice.invoice_skonto.rate}% Skonto innerhalb von #{invoice.invoice_skonto.days} Tagen ab Rechnungsdatum.</div>
           <div>Lieferbedingungen: #{invoice.notes1 || "N/A"}</div>
           <div>Andere Hinweise: #{invoice.invoice_retention_notice}</div>
           <br>
           <div> Für weitere Fragen stehen wir Ihnen gerne zu Verfügung.</div>
           <br>
           <div>Mit freundlichen Grüßen</div>
       </div>
    </div>
    <footer class="footer">
       <div class="footer-column">
           <!-- Left Column: Company Address -->
           #{invoice.invoice_address.company}<br>
           #{invoice.invoice_address.street}<br>
           #{invoice.invoice_address.city}, #{invoice.invoice_address.postal_code}<br>
           #{invoice.invoice_address.country}
           </div>
      <div class="footer-column">
           <!-- Left Column: Company Address -->
           Mail: #{invoice.invoice_address.contact_mail}<br>
           Telefonnummer: #{invoice.invoice_address.contact_tel}<br>
           Fax: #{invoice.invoice_address.contact_fax}<br>
           Internet: #{invoice.invoice_address.contact_web}
           </div>

       <div class="footer-column">
           <!-- Center Column: Bank Account Details -->
           Bank: #{invoice.invoice_address.bank_name}<br>
           IBAN: #{invoice.invoice_address.bank_IBAN}<br>
           BIC: #{invoice.invoice_address.bank_BIC}<br>
           Kto. Inh.: #{invoice.invoice_address.bank_owner}<br>
       </div>
       <div class="footer-column">
        <!-- Right Column: VAT-ID and Legal Info -->
         UST-ID: #{invoice.invoice_address.vat_number}<br>
         Steuernummer: #{invoice.invoice_address.tax_number} <br>
         Amtsgericht: #{invoice.invoice_address.legal_court} <br>
         Handelsregisternummer: #{invoice.invoice_address.legal_HRB}
       </div>

    </footer>

    </body>
    </html>

    """
  end

  # For every item position a new line has to be created
  defp create_item(items) do
    Enum.map_join(items, "", fn item ->
      """
      <tr>
          <td>#{item.item_number}</td>
          <td>#{item.item_name}</td>
          <td>#{item.item_description}</td>
          <td>#{item.item_quantity}</td>
          <td>#{item.item_reference || "Stück"}</td>
          <td>#{item.item_price}</td>
          <td>#{item.item_total_net}</td>
      </tr>
      """
    end)
  end

  # -----------------------------------------------------------------------------------
end

# -----------------------------------------------------------------------------------
