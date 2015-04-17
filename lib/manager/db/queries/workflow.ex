require Timex.Time

defmodule OpenAperture.Manager.DB.Queries.Workflow do
  import Ecto.Query
  use Timex

  alias OpenAperture.Manager.DB.Models.Workflow

  @doc """
  Retrieves the database record for recent workflows.

  ## Options

  The `lookback_hours` option defines an integer representing the number of lookback hours.  Specifying
  a negative or 0 value will default to all workflows

  ## Return Value
  
  Query
  """
  @spec get_workflows(term) :: term
  def get_workflows(lookback_hours) do
    if lookback_hours > 0 do
      now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
      lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-lookback_hours*60*60)
      ecto_datetime = from_erl(lookback_time)

      from w in Workflow,
        where: w.inserted_at >= ^ecto_datetime,
        select: w
    else
      from w in Workflow,
        select: w      
    end
  end

  @doc """
  Retrieves the database record for recent workflows for a specific deployment repo.

  ## Options

  The `lookback_hours` option defines an integer representing the number of lookback hours.  Specifying
  a negative or 0 value will default to all workflows

  ## Return Value
  
  Query
  """
  @spec get_workflows_by_deployment_repo(String.t(), term) :: term
  def get_workflows_by_deployment_repo(deployment_repo, lookback_hours \\ 0) do
    if lookback_hours > 0 do
      now_secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
      lookback_time = :calendar.gregorian_seconds_to_datetime(now_secs-lookback_hours*60*60)
      ecto_datetime = from_erl(lookback_time)

      from w in Workflow,
        where: w.deployment_repo == ^deployment_repo and w.inserted_at >= ^ecto_datetime,
        select: w
    else
      from w in Workflow,
        where: w.deployment_repo == ^deployment_repo,
        select: w      
    end    
  end


  defp from_erl({{year, month, day}, {hour, min, sec}}) do
    %Ecto.DateTime{year: year, month: month, day: day,
                   hour: hour, min: min, sec: sec}
  end 
end