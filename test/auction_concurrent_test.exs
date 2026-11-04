defmodule AuctionConcurrentTest do
  use ExUnit.Case

  test "ofertas concurrentes iguales: solo una es aceptada" do
    {:ok, auction} = Auction.new(1, "Teclado", 1000, 60000)
    server = AuctionServer.start(auction)
    parent = self()

    for n <- 1..10 do
      spawn(fn ->
        send(server, {:offer, "user#{n}", 1200, self()})
        receive do
          :ok -> send(parent, {:result, n, :accepted})
          {:error, reason} -> send(parent, {:result, n, reason})
        end
      end)
    end

    results = collect_results(10)
    accepted = Enum.count(results, fn {_n, r} -> r == :accepted end)

    assert accepted == 1
  end

  defp collect_results(0), do: []
  defp collect_results(n) do
    receive do
      {:result, user, result} -> [{user, result} | collect_results(n - 1)]
    end
  end

 test "ofertas concurrentes distintas: la mayor oferta gana" do
  {:ok, auction} = Auction.new(1, "Teclado", 1000, 60000)
  server = AuctionServer.start(auction)
  parent = self()

  for n <- 1..10 do
    amount = 1000 + n * 100
    spawn(fn ->
      send(server, {:offer, "user#{n}", amount, self()})
      receive do
        :ok -> send(parent, {:result, n, amount, :accepted})
        {:error, reason} -> send(parent, {:result, n, amount, reason})
      end
    end)
  end

  results = collect_results_amount(10)
  accepted = Enum.filter(results, fn {_n, _a, r} -> r == :accepted end)
  max_accepted = accepted |> Enum.map(fn {_n, a, _r} -> a end) |> Enum.max()

  assert max_accepted == 2000
end

defp collect_results_amount(0), do: []
defp collect_results_amount(n) do
  receive do
    {:result, user, amount, result} -> [{user, amount, result} | collect_results_amount(n - 1)]
  end
end

test "varias subastas concurrentes con estados independientes" do
  {:ok, auction_a} = Auction.new(1, "Teclado", 1000, 60000)
  {:ok, auction_b} = Auction.new(2, "Monitor", 5000, 60000)
  server_a = AuctionServer.start(auction_a)
  server_b = AuctionServer.start(auction_b)
  parent = self()

  # Ofertas en A
  for n <- 1..5 do
    spawn(fn ->
      send(server_a, {:offer, "userA#{n}", 1000 + n * 100, self()})
      receive do
        result -> send(parent, {:a_result, n, result})
      end
    end)
  end

  # Ofertas en B
  for n <- 1..5 do
    spawn(fn ->
      send(server_b, {:offer, "userB#{n}", 5000 + n * 100, self()})
      receive do
        result -> send(parent, {:b_result, n, result})
      end
    end)
  end

  collect_multi(10)

  send(server_a, {:status, self()})
  send(server_b, {:status, self()})

  auction_a_final = receive do {:status, a} -> a end
  auction_b_final = receive do {:status, b} -> b end

  # Cada subasta tiene sus propias ofertas
  assert Enum.all?(auction_a_final.offers, fn o -> String.starts_with?(o.user, "userA") end)
  assert Enum.all?(auction_b_final.offers, fn o -> String.starts_with?(o.user, "userB") end)
  assert auction_a_final.status == :active
  assert auction_b_final.status == :active
end

defp collect_multi(0), do: :ok
defp collect_multi(n) do
  receive do
    {:a_result, _n, _r} -> collect_multi(n - 1)
    {:b_result, _n, _r} -> collect_multi(n - 1)
  end
end


test "cierre automático tras vencer el plazo" do
  {:ok, auction} = Auction.new(1, "Teclado", 1000, 100)
  server = AuctionServer.start(auction)

  send(server, {:offer, "ana", 1500, self()})
  # Espera un mensaje con timeout
  assert_receive :ok, 500

  # Esperar a que el timer cierre la subasta
  Process.sleep(200)

  send(server, {:status, self()})
  assert_receive {:status, closed}, 500

  assert closed.status == :closed
  assert closed.winner == "ana"
  assert closed.final_price == 1500
end

end
