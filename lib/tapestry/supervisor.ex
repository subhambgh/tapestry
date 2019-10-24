defmodule TapestrySupervisor do
  use Supervisor

  def start_link([nodes,requests]) do
    {:ok,pid} = Supervisor.start_link(__MODULE__, [nodes,requests])
    send(Process.whereis(:main),{:nodes_created})
    {:ok,pid}
  end

  @impl true
  def init([nodes,requests]) do
    n_list = Enum.to_list 1..nodes
    children = [ worker(Tapestry.Counter, [nodes], [id: "counter"])] ++
                Enum.map(n_list, fn(x)->worker(TapestryNode, [x,nodes,requests], [id: "node#{x}"]) end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
