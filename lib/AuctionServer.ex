### API del server
defmodule AuctionServer do
  def start(%Auction{} = auction) do
    spawn(fn ->
      server_pid = self()

      spawn(fn ->
        Process.sleep(auction.duration)
        send(server_pid, :close)
      end)

      loop(auction)
    end)
  end

  defp loop(%Auction{} = auction) do
    receive do
      :close ->
        {:ok, new_auction} = Auction.close(auction)
        loop(new_auction)

      {:offer, user, amount, caller} ->
        case Auction.start(auction, user, amount) do
          {:ok, new_auction} ->
            send(caller, :ok)
            loop(new_auction)

          {:error, reason} ->
            send(caller, {:error, reason})
            loop(auction)
        end

      {:status, caller} ->
        cond do
          auction.status == :active and System.monotonic_time(:millisecond) >= auction.deadline ->
            {:ok, closed} = Auction.close(auction)
            send(caller, {:status, closed})
            loop(closed)

          true ->
            send(caller, {:status, auction})
            loop(auction)
        end
    end
  end
end
