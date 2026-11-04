defmodule CliCasaSubastaTest do
  use ExUnit.Case

  setup do
    AuctionCoordinator.start()
    :ok
  end

  test "crear subasta desde CLI" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        CliCasaSubasta.exec("crear \"Teclado\" 1000 30000")
      end)

    assert output =~ "OK subasta=1"
    assert output =~ "producto=\"Teclado\""
  end

  test "error al crear con duración invalida" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        CliCasaSubasta.exec("crear \"Monitor\" 5000 0")
      end)

    assert output =~ "ERROR"
  end

  test "consultar subasta inexistente" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        CliCasaSubasta.exec("consultar 999")
      end)

    assert output =~ "ERROR subasta_inexistente"
  end
end
