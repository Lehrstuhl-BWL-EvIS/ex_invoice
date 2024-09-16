defmodule ExInvoiceTest do
  use ExUnit.Case

  test "Structure Test" do
    invoice =
      %{
        invoices: [
          %{
            invoice_number: "2024_Q3_234234",
            customer_order_number: 456,
            account_reference: "2INTER00",
            order_number: nil,
            foreign_rate: 1,
            notes1: nil,
            notes2: nil,
            notes3: nil,
            currency_used: false,
            invoice_date: ~D[2024-08-10],
            delivery_date: ~D[2024-08-12],
            note_date: nil,
            invoice_address: %{
              title: "Dr.",
              forename: "Anna",
              surname: "Müller",
              company: "Technik GmbH",
              street: "Technolstrasse 123",
              address2: nil,
              address3: nil,
              city: "München",
              postal_code: "80333",
              county: "Bayern",
              country: "DE",
              notes: nil,
              vat_number: "DE123456789",
              tax_number: "123/456/78910",
              legal_court: "Amtsgericht München",
              legal_HRB: "1234567",
              bank_name: "Sparkasse München",
              bank_IBAN: "DE89370400440532013000",
              bank_BIC: "1234",
              bank_owner: "Peter Lustig"
            },
            invoice_delivery_address: %{
              title: nil,
              forename: nil,
              surname: "",
              company: "Kunde GmbH",
              street: "Randomstr. 345",
              address2: nil,
              address3: nil,
              city: "München",
              postal_code: "80333",
              county: "Bayern",
              country: "DE",
              notes: nil
            },
            invoice_items: [
              %{
                item_number: "A1314",
                item_name: "Test",
                item_description: "Manueller Kronkorkenentfernungswerkzeug",
                item_comments: "",
                item_quantity: 2,
                item_price: 100,
                item_discount_amount: 0,
                item_discount_percentage: 0,
                item_reference: nil,
                item_tax_rate: 19.0,
                item_total_net: 200,
                item_total_tax: 38
              },
              %{
                item_number: "B1314",
                item_name: "How-To: BeerOpener 2000",
                item_description: "Buch",
                item_comments: "",
                item_quantity: 4,
                item_price: 50,
                item_discount_amount: 0,
                item_discount_percentage: 0,
                item_reference: nil,
                item_tax_rate: 7.0,
                item_total_net: 50,
                item_total_tax: 3.5
              }
            ],
            invoice_net: 3750,
            invoice_tax: 712.50,
            invoice_tax_rate: 19,
            invoice_total: 4462.50,
            invoice_skonto: %{rate: 2.0, days: 14},
            invoice_tax_note: "",
            invoice_retention_notice:
              "Sie sind gesetzlich verpflichtet diese Rechnung mindestens 2 Jahre – als umsatzsteuerlicher Unternehmer 10
Jahre – aufzubewahren. Die Aufbewahrungsfrist beginnt mit Schluss dieses Kalenderjahres. "
          }
        ]
      }

    assert ExInvoice.validate_invoices(invoice) == :ok
  end
end
