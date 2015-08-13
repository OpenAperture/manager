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

  The `type` option allows an optional query filter of "type"

  ## Return Value
  
  Query
  """
  @spec get_events(term, term) :: term
  def get_events(lookback_hours, type \\ nil) do
    now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-lookback_hours*60*60)
    ecto_datetime = from_erl(lookback_time)

    cond do
      lookback_hours > 0 && type == nil ->
        from se in SystemEvent,
          where: se.inserted_at >= ^ecto_datetime,
          select: se        
      lookback_hours > 0 && type != nil ->
        from se in SystemEvent,
          where: se.inserted_at >= ^ecto_datetime and se.type == ^type,
          select: se
      type != nil -> 
        from se in SystemEvent,
          where: se.type == ^type,
          select: se            
      true ->
        from se in SystemEvent,
          select: se         
    end
  end

  @doc """
  Retrieves the database record for SystemEvents assigned to a user.

  ## Options

  The `user_id` option defines an integer representing the unique id of a User

  ## Return Value
  
  Query
  """
  @spec get_assigned_events(term) :: term
  def get_assigned_events(user_id) do
    from se in SystemEvent,
      where: se.assignee_id == ^user_id,
      select: se    
  end

  defp from_erl({{year, month, day}, {hour, min, sec}}) do
    %Ecto.DateTime{year: year, month: month, day: day,
                   hour: hour, min: min, sec: sec}
  end   
end