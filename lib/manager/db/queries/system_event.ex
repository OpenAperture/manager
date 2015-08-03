require Timex.Time

defmodule OpenAperture.Manager.DB.Queries.SystemEvent do
  import Ecto.Query
  use Timex

  alias OpenAperture.Manager.DB.Models.SystemEvent

  @doc """
  Retrieves the database record for recent SystemEvents.

  ## Options

  The `lookback_hours` option defines an integer representing the number of lookback hours.  Specifying
  a negative or 0 value will default to all SystemEvents

  ## Return Value
  
  Query
  """
  @spec get_events(term) :: term
  def get_events(lookback_hours) do
    if lookback_hours > 0 do
      now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
      lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-lookback_hours*60*60)
      ecto_datetime = from_erl(lookback_time)

      from se in SystemEvent,
        where: se.inserted_at >= ^ecto_datetime,
        select: se
    else
      from se in SystemEvent,
        select: se     
    end
  end

  defp from_erl({{year, month, day}, {hour, min, sec}}) do
    %Ecto.DateTime{year: year, month: month, day: day,
                   hour: hour, min: min, sec: sec}
  end   
end