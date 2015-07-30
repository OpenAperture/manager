defmodule OpenAperture.Manager.Messaging.RpcRequestsCleanupTest do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.Messaging.RpcRequestsCleanup
  alias OpenAperture.Manager.DB.Models.MessagingRpcRequest

  alias OpenAperture.Manager.Repo

  setup do
    Repo.delete_all(MessagingRpcRequest)
    :ok
  end

  test "clear expired entry" do    
    now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-(25*60*60))
    then = from_erl(lookback_time)

    _request = %MessagingRpcRequest{status: "not_started", inserted_at: then} |> Repo.insert!
    RpcRequestsCleanup.cleanup_expired_requests

    results = Repo.all(MessagingRpcRequest)
    assert results != nil
    assert length(results) == 0
  end

  test "do not clear entry" do
    now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-(23*60*60))
    then = from_erl(lookback_time)

    _request = %MessagingRpcRequest{status: "not_started", inserted_at: then} |> Repo.insert!
    _request = %MessagingRpcRequest{status: "not_started"} |> Repo.insert!
    RpcRequestsCleanup.cleanup_expired_requests

    results = Repo.all(MessagingRpcRequest)
    assert results != nil
    assert length(results) == 2
  end

  defp from_erl({{year, month, day}, {hour, min, sec}}) do
    %Ecto.DateTime{year: year, month: month, day: day,
                   hour: hour, min: min, sec: sec}
  end
end
