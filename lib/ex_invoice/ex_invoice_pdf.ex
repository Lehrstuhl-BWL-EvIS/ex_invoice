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
    css_path = Path.join([Path.expand("../../assets/css", __DIR__), "styles.css"])
    logo_path = Path.join([Path.expand("../../assets/images", __DIR__), "logo.webp"])

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
