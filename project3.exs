defmodule Tapestry do
  use Application

  @impl true
  def start(_type, args) do
    Main.main(args)
  end
end

args = System.argv()
Tapestry.start([], args)
