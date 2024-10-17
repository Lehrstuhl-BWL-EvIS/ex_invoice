defmodule StressTest do
  use ExUnit.Case
  @tag timeout: 600_000

  test "validate invoices in increments with cumulative performance" do
    cumulative_times = []

    for count <- [10, 20, 50, 100] do
      # Feedback for every round
      new_times =
        for _ <- 1..count do
          {time_in_microseconds, _result} =
            :timer.tc(fn -> ExInvoicePDF.generate_pdf(create_invoice()) end)

          time_in_microseconds
        end

      # Add times to cumulated times
      cumulative_times = cumulative_times ++ new_times

      # Calculations
      sum = Enum.sum(cumulative_times)
      average = sum / length(cumulative_times)
      median = calculate_median(cumulative_times)
      std_dev = calculate_standard_deviation(cumulative_times, average)

      # Feedback
      IO.puts("Cumulative performance after processing #{length(cumulative_times)} invoices:")
      IO.puts("Total execution time: #{sum} microseconds")
      IO.puts("Average execution time: #{average} microseconds")
      IO.puts("Median execution time: #{median} microseconds")
      IO.puts("Standard deviation of execution times: #{std_dev} microseconds")
      IO.puts("==============================================")
    end
  end

  # Function to create a New Invoice
  defp create_invoice do
    %{
      id: "2024_Q3_" <> Integer.to_string(:rand.uniform(1_000_000)),
      typecode: 74,
      buyer_reference: "2INTER00",
      seller_order_referenced_document: nil,
      notes1: nil,
      currency_used: false,
      issue_date_time: ~D[2024-08-10],
      occurrence_date_time: ~D[2024-08-12],
      note_date: nil,
      seller_trade_party: %{
        forename: Faker.Person.first_name(),
        surname: Faker.Person.last_name(),
        trading_business_name: Faker.Company.name(),
        line_one: Faker.Address.street_name() <> " " <> Integer.to_string(:rand.uniform(999)),
        city_name: Faker.Address.city(),
        post_code_code: Faker.Address.postcode(),
        country_sub_division_name: "Bayern",
        country_id: "DE",
        notes: nil,
        vat_number: "DE" <> Integer.to_string(:rand.uniform(999_999_999)),
        tax_number: "#{:rand.uniform(999)}/#{:rand.uniform(999)}/#{:rand.uniform(99_999)}",
        legal_court: "Amtsgericht " <> Faker.Address.city(),
        legal_HRB: Integer.to_string(:rand.uniform(1_000_000)),
        bank_name: "Sparkasse " <> Faker.Address.city(),
        bank_IBAN: Faker.Code.iban("DE"),
        bank_BIC: "1234",
        bank_owner: Faker.Person.name(),
        uri_id: Faker.Internet.email(),
        contact_tel: Faker.Phone.EnUs.phone(),
        contact_fax: Faker.Phone.EnUs.phone(),
        contact_web: Faker.Internet.url()
      },
      buyertradeparty: %{
        forename: nil,
        surname: "",
        trading_business_name: "Customer " <> Faker.Company.name(),
        line_one: Faker.Address.street_name() <> " " <> Integer.to_string(:rand.uniform(999)),
        address2: nil,
        address3: nil,
        city_name: Faker.Address.city(),
        post_code_code: Faker.Address.postcode(),
        country_sub_division_name: "Bayern",
        country_id: "DE",
        notes: nil
      },
      invoice_items: generate_invoice_items(),
      invoice_net: :rand.uniform(5000),
      invoice_tax: :rand.uniform(1000),
      invoice_tax_rate: 19,
      invoice_total: :rand.uniform(6000),
      invoice_payment_skonto_rate: 2,
      invoice_payment_skonto_days: 14,
      invoice_payment_method: "Überweisung",
      invoice_tax_note: nil,
      included_note:
        "Sie sind gesetzlich verpflichtet diese Rechnung mindestens 2 Jahre – als umsatzsteuerlicher Unternehmer 10 Jahre – aufzubewahren. Die Aufbewahrungsfrist beginnt mit Schluss dieses Kalenderjahres."
    }
  end

  # Items
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

  # Median
  defp calculate_median(times) do
    sorted_times = Enum.sort(times)
    len = length(sorted_times)

    if rem(len, 2) == 1 do
      Enum.at(sorted_times, div(len, 2))
    else
      mid1 = Enum.at(sorted_times, div(len - 1, 2))
      mid2 = Enum.at(sorted_times, div(len, 2))
      (mid1 + mid2) / 2
    end
  end

  # standard deviation
  defp calculate_standard_deviation(times, average) do
    variance =
      times
      |> Enum.map(fn time -> (time - average) ** 2 end)
      |> Enum.sum()

    :math.sqrt(variance / length(times))
  end
end
