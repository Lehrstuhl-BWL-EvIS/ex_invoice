defmodule ExInvoice do
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

    # Result for every invoice
    # IO.inspect(results, label: "Validation results for invoice #{invoice[:id]}")

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil ->
        # IO.puts("All validations passed for invoice #{invoice[:id]}.")

        ExInvoicePDF.generate_pdf(invoice)
        {:ok, "Validation successful. PDF #{invoice[:id]}.pdf is created."}

      {:error, message} ->
        # IO.puts("Validation failed for invoice #{invoice[:id]}: #{message}")
        {:error, message}
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
    with :ok <- validate_name(trading_business_name, forename, surname),
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
  defp validate_name(nil, nil, nil),
    do: {:error, "Missing field: surname or trading_business_name"}

  defp validate_name(nil, _, nil), do: {:error, "Missing field: surname or trading_business_name"}
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

  # Validierung der Steuernummer (deutsches Format)
  defp validate_tax_number(nil), do: {:error, "Invalid tax number"}

  defp validate_tax_number(number) when is_binary(number) do
    # Pattern für eine deutsche Steuernummer (10 oder 11 Ziffern)
    tax_number_regex = ~r/^\d{3}\/\d{3}\/\d{5}$/

    if Regex.match?(tax_number_regex, number) do
      {:ok, "#{number} Tax_Number_valid"}
    else
      {:error, "Invalid tax number"}
    end
  end

  # Validierung der USt-IdNr. (deutsches Format)
  defp validate_vat_number(nil), do: {:error, "No VAT number provided"}

  defp validate_vat_number(number) when is_binary(number) do
    IO.inspect(ExVatcheck.check(number), label: "ExVatcheck Result")

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
  # Checks Date
  defp validate_date(%Date{} = _date) do
    {:ok, "Valid date."}
  end

  defp validate_date(nil) do
    {:error, "No date provided"}
  end

  defp validate_date(_) do
    {:error, "Invalid date format or value"}
  end

  defp validate_date_delivery(invoice_date, delivery_date, note_date) do
    cond do
      # Check if `delivery_date` is nil and the note "Rechnungsdatum = Lieferdatum" is provided
      is_nil(delivery_date) and note_date == "Rechnungsdatum = Lieferdatum" ->
        {:ok, "Rechnungsdatum = Lieferdatum"}

      # Check if `delivery_date` is nil and the note "Rechnungsdatum = Lieferdatum" is not provided
      is_nil(delivery_date) ->
        {:error, "No delivery date and hint 'Rechnungsdatum = Lieferdatum' is missing"}

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

  # Validierung für die Skonto-Rate (z.B. 2.0 für 2%)
  defp validate_rate(rate) when is_number(rate) and rate >= 0 and rate <= 100 do
    {:ok, rate}
  end

  defp validate_rate(_), do: {:error, "Discount rate must be a number between 0 and 100."}

  # Validierung der Anzahl der Tage (muss eine positive Ganzzahl sein)
  defp validate_days(days) when is_integer(days) and days > 0 do
    {:ok, days}
  end

  defp validate_days(_), do: {:error, "Days must be a positive integer."}

  # Validierung der Zahlungsart
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
        {:error, "The calculated net price does not match the expected invoice net."}
      end
    else
      error_messages =
        errors
        |> Enum.map(fn {:error, message} -> message end)
        |> Enum.join("; ")

      {:error, error_messages}
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
  # Iban Validation with Bankster, is neede to provide feedback in the same way as other validations
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

defmodule ExInvoicePDF do
  @moduledoc """
  Module for generating PDF invoices based on HTML templates using ChromicPDF.

  This module allows the generation of PDF files for invoices by using HTML and CSS
  to define the structure and layout of the invoice. The module leverages [ChromicPDF](https://hexdocs.pm/chromic_pdf/)
  as the backend for PDF creation.

  ## Functions

    - `generate_pdf/1`: Creates a PDF file for a given invoice and saves it in the `invoices_output` directory.
    - `create_html_invoice/1`: Converts the invoice data into an HTML template used for PDF generation.
    - `create_item/1`: Helper function that creates HTML table rows for each invoice line item.

  ## Examples

      invoice = %{
        id: "2024_Q3_234234",
        issue_date_time: ~D[2024-08-10],
        occurrence_date_time: ~D[2024-08-12],
        buyertradeparty: %{
          trading_business_name: "Customer XYZ",
          line_one: "Example Street 1",
          post_code_code: "12345",
          city_name: "Sample City"
        },
        seller_trade_party: %{
          trading_business_name: "Seller Inc.",
          line_one: "Seller Street 2",
          city_name: "Seller City",
          post_code_code: "54321",
          country_id: "DE",
          vat_number: "DE123456789",
          tax_number: "123/456/78910",
          legal_court: "District Court Seller City",
          legal_HRB: "123456",
          bank_name: "Seller Bank",
          bank_IBAN: "DE12345678901234567890",
          bank_BIC: "BANKDEFF",
          bank_owner: "Seller Inc.",
          uri_id: "info@seller.com",
          contact_tel: "0123456789",
          contact_fax: "0987654321",
          contact_web: "https://seller.com"
        },
        invoice_items: [
          %{
            item_number: "A1314",
            item_name: "Test Item",
            item_description: "Description of the item",
            item_quantity: 2,
            item_price: 100,
            item_total_net: 200,
            item_total_tax: 38
          }
        ],
        invoice_net: 200,
        invoice_tax: 38,
        invoice_tax_rate: 19,
        invoice_total: 238,
        invoice_payment_method: "Bank Transfer",
        invoice_payment_skonto_rate: 2,
        invoice_payment_skonto_days: 14,
        included_note: "Please keep this invoice for at least 10 years."
      }

      ExInvoicePDF.generate_pdf(invoice)

  ## Dependencies

  - ChromicPDF: Used to generate PDF files based on HTML/CSS.
  - CSS and image files should be placed in the `assets/css` and `assets/images` directories, respectively, for proper reference in the HTML template.

  ## Notes

  - The generated PDF file is saved in the `invoices_output` directory. If this directory does not exist,
    it will be created automatically.
  - The PDF file is saved under the name `invoice_<invoice_id>.pdf`, where `<invoice_id>` is replaced with the invoice number.

  """

  # PDF Creation via ChromicPDF

  def generate_pdf(invoice) do
    # Create a HTML File for using ChromicPDF
    invoice_html = create_html_invoice(invoice)
    # Create an output folder in case it doesnt exist
    File.mkdir_p!("invoices_output")
    # Filename of HTML=invoice number
    filename = "invoice_#{invoice[:id]}.pdf"

    [
      size: :a4,
      content: invoice_html
    ]
    |> ChromicPDF.Template.source_and_options()
    |> ChromicPDF.print_to_pdfa(output: Path.join("invoices_output", filename))
  end

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
    <title>Invoice #{invoice.id}</title>
    <link rel="stylesheet" href="file://#{css_path}">
    </head>
    <body>
    <div class="invoice-box">
       <div class="header">
          <div class="customer-details">
               <div>#{invoice.buyertradeparty.trading_business_name}</div>
               <div>#{invoice.buyertradeparty.line_one}</div>
               <div>#{invoice.buyertradeparty.post_code_code} #{invoice.buyertradeparty.city_name}</div>
          </div>
           <div class="invoice-date">
               <img src="file://#{logo_path}" alt="Company Logo"><br>
               <div>Rechnungsdatum: #{invoice.issue_date_time}</div>
               <div>Lieferdatum: #{invoice.occurrence_date_time}</div>
               <strong>#{invoice.seller_trade_party.trading_business_name}</strong><br>
               #{invoice.seller_trade_party.line_one}<br>
               #{invoice.seller_trade_party.post_code_code} #{invoice.seller_trade_party.city_name}<br>
               #{invoice.seller_trade_party.country_id}<br>
           </div>
       </div>

       <div class="invoice-title">
           Rechnung
       </div>

       <div class="invoice-details">
           <div>Rechnungsnummer: #{invoice.id}</div>
           <div>Auftrags-Nr.: #{invoice.seller_order_referenced_document || "N/A"}</div>
           <div>Kundenreferenz: #{invoice.buyer_reference}</div>
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
           <div>Rechnungsbetrag zahlbar per #{invoice.invoice_payment_method} abzüglich #{invoice.invoice_payment_skonto_rate}% Skonto innerhalb von #{invoice.invoice_payment_skonto_days} Tagen ab Rechnungsdatum.</div>
           <div>Lieferbedingungen: #{invoice.notes1 || "N/A"}</div>
           <div>Andere Hinweise: #{invoice.included_note}</div>
           <br>
           <div> Für weitere Fragen stehen wir Ihnen gerne zu Verfügung.</div>
           <br>
           <div>Mit freundlichen Grüßen</div>
       </div>
    </div>
    <footer class="footer">
       <div class="footer-column">
           <!-- Left Column: Company Address -->
           #{invoice.seller_trade_party.trading_business_name}<br>
           #{invoice.seller_trade_party.line_one}<br>
           #{invoice.seller_trade_party.city_name}, #{invoice.seller_trade_party.post_code_code}<br>
           #{invoice.seller_trade_party.country_id}
           </div>
      <div class="footer-column">
           <!-- Left Column: Company Address -->
           Mail: #{invoice.seller_trade_party.uri_id}<br>
           Telefonnummer: #{invoice.seller_trade_party.contact_tel}<br>
           Fax: #{invoice.seller_trade_party.contact_fax}<br>
           Internet: #{invoice.seller_trade_party.contact_web}
           </div>

       <div class="footer-column">
           <!-- Center Column: Bank Account Details -->
           Bank: #{invoice.seller_trade_party.bank_name}<br>
           IBAN: #{invoice.seller_trade_party.bank_IBAN}<br>
           BIC: #{invoice.seller_trade_party.bank_BIC}<br>
           Kto. Inh.: #{invoice.seller_trade_party.bank_owner}<br>
       </div>
       <div class="footer-column">
        <!-- Right Column: VAT-ID and Legal Info -->
         UST-ID: #{invoice.seller_trade_party.vat_number}<br>
         Steuernummer: #{invoice.seller_trade_party.tax_number} <br>
         Amtsgericht: #{invoice.seller_trade_party.legal_court} <br>
         Handelsregisternummer: #{invoice.seller_trade_party.legal_HRB}
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
end
