defmodule AuctionCoordinator do
  def start do
  case Process.whereis(:auction_coordinator) do
    nil ->
      pid = spawn(fn -> loop(%{next_id: 1, auctions: %{}}) end)
      Process.register(pid, :auction_coordinator)
      pid

    pid ->
      pid
  end
  end

  defp loop(state) do
    receive do
      {:create, product, initial_price, duration, caller} ->
        case Auction.new(state.next_id, product, initial_price, duration) do
          {:ok, auction} ->
            id = auction.id
            pid = AuctionServer.start(auction)

            new_state = %{
              state
              | next_id: id + 1,
                auctions: Map.put(state.auctions, id, pid)
            }

            send(caller, {:ok, id})
            loop(new_state)

          {:error, reason} ->
            send(caller, {:error, reason})
            loop(state)
        end

      {:find, id, caller} ->
        case Map.get(state.auctions, id) do
          nil ->
            send(caller, {:error, :auction_not_found})
            loop(state)

          pid ->
            send(caller, {:ok, pid})
            loop(state)
        end

      {:list_active, caller} ->
        active =
          state.auctions
          |> Enum.map(fn {id, pid} ->
            send(pid, {:status, self()})

            receive do
              {:status, %Auction{status: :active} = auction} -> {id, auction}
              {:status, _} -> nil
            end
          end)
          # se elimina los nil y quedan las subastas activas
          |> Enum.reject(fn item -> is_nil(item) end)


        send(caller, {:ok, active})
        loop(state)
    end
  end
end
