defmodule StressTest do
  use ExUnit.Case
  @tag timeout: 600_000

  test "validate invoices in increments" do
    for count <- 10..100//10 do
      invoices = generate_invoices(count)

      Enum.each(invoices, fn invoice ->
        {time_in_microseconds, _result} = :timer.tc(fn -> ExInvoice.generate_pdf(invoice) end)
        # IO.puts("Execution time: #{time_in_microseconds} microseconds")
        # assert ExInvoice.generate_pdf(invoice) == :ok
      end)
    end
  end

  # Diese Funktion generiert eine Liste von Rechnungen
  defp generate_invoices(count) do
    Enum.map(1..count, fn _ -> create_invoice() end)
  end

  # Creates a function with random values
  defp create_invoice do
    %{
      invoice_number: "2024_Q3_" <> Integer.to_string(:rand.uniform(1_000_000)),
      customer_order_number: :rand.uniform(1_000_000),
      account_reference: Faker.Commerce.department(),
      order_number: nil,
      foreign_rate: 1,
      notes1: Faker.Lorem.sentence(),
      currency_used: false,
      invoice_date: ~D[2024-08-10],
      delivery_date: ~D[2024-08-12],
      note_date: nil,
      invoice_address: %{
        title: "",
        forename: Faker.Person.first_name(),
        surname: Faker.Person.last_name(),
        company: Faker.Company.name(),
        street: Faker.Address.street_name() <> " " <> Integer.to_string(:rand.uniform(999)),
        address2: nil,
        address3: nil,
        city: Faker.Address.city(),
        postal_code: Faker.Address.postcode(),
        county: "Bayern",
        country: "DE",
        notes: nil,
        vat_number: "DE" <> Integer.to_string(:rand.uniform(999_999_999)),
        tax_number: "#{:rand.uniform(999)}/#{:rand.uniform(999)}/#{:rand.uniform(99_999)}",
        legal_court: "Amtsgericht " <> Faker.Address.city(),
        legal_HRB: Integer.to_string(:rand.uniform(1_000_000)),
        bank_name: "Sparkasse " <> Faker.Address.city(),
        bank_IBAN: Faker.Code.iban("DE"),
        bank_BIC: "TEST",
        bank_owner: Faker.Person.name(),
        contact_mail: Faker.Internet.email(),
        contact_tel: Faker.Phone.EnUs.phone(),
        contact_fax: Faker.Phone.EnUs.phone(),
        contact_web: Faker.Internet.url()
      },
      invoice_delivery_address: %{
        title: nil,
        forename: nil,
        surname: nil,
        company: Faker.Company.name(),
        street: Faker.Address.street_name() <> " " <> Integer.to_string(:rand.uniform(999)),
        address2: nil,
        address3: nil,
        city: Faker.Address.city(),
        postal_code: Faker.Address.postcode(),
        county: "Bayern",
        country: "DE",
        notes: nil
      },
      invoice_items: generate_invoice_items(),
      invoice_net: :rand.uniform(5000),
      invoice_tax: :rand.uniform(1000),
      invoice_tax_rate: 19,
      invoice_total: :rand.uniform(6000),
      invoice_skonto: %{rate: 2.0, days: 14},
      invoice_tax_note: "",
      invoice_retention_notice:
        "Sie sind gesetzlich verpflichtet, diese Rechnung mindestens 2 Jahre – als umsatzsteuerlicher Unternehmer 10 Jahre – aufzubewahren. Die Aufbewahrungsfrist beginnt mit Schluss dieses Kalenderjahres."
    }
  end

  # Creates random (invoice_items)
  defp generate_invoice_items do
    Enum.map(1..:rand.uniform(5), fn _ ->
      %{
        item_number: Faker.Commerce.product_name(),
        item_name: Faker.Commerce.product_name(),
        item_description: Faker.Lorem.sentence(),
        item_comments: Faker.Lorem.sentence(),
        item_quantity: :rand.uniform(10),
        item_price: :rand.uniform(100),
        item_discount_amount: 0,
        item_discount_percentage: 0,
        item_reference: nil,
        item_tax_rate: Enum.random([7.0, 19.0]),
        item_total_net: :rand.uniform(500),
        item_total_tax: :rand.uniform(100)
      }
    end)
  end
end
