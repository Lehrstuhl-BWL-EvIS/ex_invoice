defmodule ExInvoiceTestAdress do
  use ExUnit.Case

  alias ExInvoice

  # Setup-Block, der vor jedem Test ausgeführt wird
  setup do
    # Hier kannst du `on_exit/2` sicher verwenden
    on_exit(fn ->
      # Diese Funktion wird aufgerufen, nachdem der Testprozess beendet ist
      results = ExInvoice.fetch_results()
      IO.puts("Test Results Summary:")
      Enum.each(results, fn {key, count} ->
        IO.puts("#{key}: #{count}")
      end)
    end)

    # Weitere Setup-Logik hier
    :ok
  end

  test "valid address" do
    address = %{street: "Musterstraße 1", city: "Musterstadt", postal_code: "12345"}
    assert ExInvoice.validate_address(address) == {:ok, "Address is valid"}
  end

  test "invalid address with empty street" do
    address = %{street: "", city: "Musterstadt", postal_code: "12345"}
    assert ExInvoice.validate_address(address) == {:error, "Invalid address"}
  end

  test "invalid address with wrong postal code" do
    address = %{street: "Musterstraße 1", city: "Musterstadt", postal_code: "1234"}
    assert ExInvoice.validate_address(address) == {:error, "Invalid address"}
  end
end
