defmodule TapestrySupervisor do
  use Supervisor

  def start_link(opts) do
    {:ok,pid} = Supervisor.start_link(__MODULE__, [nodes,requests], opts)
    #send(Process.whereis(:boss),{:nodes_created})
    {:ok,pid}
  end

  @impl true
  def init(nodes,requests) do
    n_list = Enum.to_list 1..nodes
    children = Enum.map(n_list, fn(x)->worker(TapestryNode, [x,nodes,requests], [id: "node#{x}"]) end)
    Supervisor.init(children, strategy: :one_for_one)
  end
end
