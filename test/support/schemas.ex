defmodule Tempo.SQL.Test.Meeting do
  @moduledoc false
  use Ecto.Schema

  schema "meetings" do
    field :name, :string
    field :window, Tempo.Ecto.Interval
  end
end

defmodule Tempo.SQL.Test.Calendar do
  @moduledoc false
  use Ecto.Schema

  schema "calendars" do
    field :owner, :string
    field :busy_times, Tempo.Ecto.IntervalSet
  end
end

defmodule Tempo.SQL.Test.FidelityMeeting do
  @moduledoc false
  use Ecto.Schema

  schema "fidelity_meetings" do
    field :name, :string
    field :window, Tempo.Ecto.TempoRange
  end
end

defmodule Tempo.SQL.Test.FidelityCalendar do
  @moduledoc false
  use Ecto.Schema

  schema "fidelity_calendars" do
    field :owner, :string
    field :busy_times, Tempo.Ecto.TempoMultirange
  end
end
