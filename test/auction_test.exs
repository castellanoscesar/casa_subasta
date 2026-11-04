defmodule AuctionTest do
  use ExUnit.Case
  ### test start
  test "start/3 acepta oferta que supera el precio inicial" do
    {:ok, auction} = Auction.new(1, "Teclado", 1000, 30000)
    assert {:ok, updated} = Auction.start(auction, "ana", 1200)
    assert length(updated.offers) == 1
    assert hd(updated.offers).user == "ana"
    assert hd(updated.offers).amount == 1200
  end

  test "start/3 rechaza oferta igual al precio inicial" do
    {:ok, auction} = Auction.new(1, "Teclado", 1000, 30000)
    assert Auction.start(auction, "ana", 1000) == {:error, :offer_too_low}
  end

  test "start/3 rechaza oferta menor al precio inicial" do
    {:ok, auction} = Auction.new(1, "Teclado", 1000, 30000)
    assert Auction.start(auction, "ana", 500) == {:error, :offer_too_low}
  end

  test "start/3 segunda oferta debe superar la mayor" do
    {:ok, auction} = Auction.new(1, "Teclado", 1000, 30000)
    {:ok, auction} = Auction.start(auction, "ana", 1200)

    assert Auction.start(auction, "bruno", 1200) == {:error, :offer_too_low}
    assert {:ok, _} = Auction.start(auction, "bruno", 1500)
  end

  test "start/3 rechaza oferta sobre subasta cerrada" do
    {:ok, auction} = Auction.new(1, "Teclado", 1000, 30000)
    {:ok, closed} = Auction.close(auction)

    assert Auction.start(closed, "ana", 2000) == {:error, :auction_not_active}
  end

  test "start/3 rechaza oferta tras vencimiento" do
    {:ok, auction} = Auction.new(1, "Teclado", 1000, 1)
    Process.sleep(10)

    assert Auction.start(auction, "ana", 2000) == {:error, :auction_closed}
  end

  ### test close
  test "close/1 cierra subasta con ofertas y asigna ganador" do
    {:ok, auction} = Auction.new(1, "Teclado", 1000, 30000)
    {:ok, auction} = Auction.start(auction, "ana", 1200)
    {:ok, auction} = Auction.start(auction, "bruno", 1500)

    assert {:ok, closed} = Auction.close(auction)
    assert closed.status == :closed
    assert closed.winner == "bruno"
    assert closed.final_price == 1500
  end

  test "close/1 cierra subasta sin ofertas sin ganador" do
    {:ok, auction} = Auction.new(1, "Teclado", 1000, 30000)

    assert {:ok, closed} = Auction.close(auction)
    assert closed.status == :closed
    assert closed.winner == nil
    assert closed.final_price == nil
  end

  test "close/1 falla si ya está cerrada" do
    {:ok, auction} = Auction.new(1, "Teclado", 1000, 30000)
    {:ok, closed} = Auction.close(auction)

    assert Auction.close(closed) == {:error, :already_closed}
  end

  test "close/1 no modifica el resultado tras cerrar" do
    {:ok, auction} = Auction.new(1, "Teclado", 1000, 30000)
    {:ok, auction} = Auction.start(auction, "ana", 1200)
    {:ok, closed} = Auction.close(auction)

    assert closed.winner == "ana"
    assert closed.final_price == 1200

    # Intentar cerrar de nuevo no cambia nada
    assert Auction.close(closed) == {:error, :already_closed}
  end
end
