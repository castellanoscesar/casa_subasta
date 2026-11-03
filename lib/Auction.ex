defmodule Auction do
  defstruct [
    :id,
    :product,
    :initial_price,
    :duration,
    :deadline,
    :status,
    offers: [],
    winner: nil,
    final_price: nil
  ]

def new(id, product, initial_price, duration) do
  cond do
    product == "" ->
      {:error, :invalid_product}

    initial_price <= 0 ->
      {:error, :invalid_price}

    duration <= 0 ->
      {:error, :invalid_duration}

    true ->
      deadline = System.system_time(:millisecond) + duration

      {:ok, %Auction{
        id: id,
        product: product,
        initial_price: initial_price,
        duration: duration,
        deadline: deadline,
        status: :active
      }}
  end
end



  def start(%Auction{} = auction, user, amount) do
    cond do
      auction.status != :active ->
        {:error, :auction_not_active}

      auction.deadline < System.system_time(:millisecond) ->
        {:error, :auction_closed}

      amount <= current_reference(auction) ->
        {:error, :offer_too_low}

      true ->
        offer = %Offer{
          user: user,
          amount: amount,
          timestamp: System.system_time(:millisecond)
        }

        new_auction = %Auction{
          auction
          | offers: [offer | auction.offers]
        }

        {:ok, new_auction}
    end
  end

  defp current_reference(%Auction{} = auction) do
    case auction.offers do
      [] ->
        auction.initial_price

      offers ->
        amounts = Enum.map(offers, fn offer -> offer.amount end)
        Enum.max(amounts)
    end
  end



  def close(%Auction{} = auction) do
    case auction.status do
      :closed ->
        {:error, :already_closed}

      :active ->
        case auction.offers do
          [] ->
            new_auction = %Auction{auction | status: :closed, winner: nil, final_price: nil}
            {:ok, new_auction}

          offers ->
            # mejor oferta
            best_offer = Enum.max_by(offers, fn offer -> offer.amount end)

            new_auction = %Auction{
              auction
              | status: :closed,
                winner: best_offer.user,
                final_price: best_offer.amount
            }

            {:ok, new_auction}
        end
    end
  end
end
