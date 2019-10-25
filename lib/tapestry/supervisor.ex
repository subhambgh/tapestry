defmodule TapestrySupervisor do
  use Supervisor

  def start_link([numNodes, numRequests,noOfNodesToFail]) do
    Supervisor.start_link(__MODULE__, [numNodes, numRequests,noOfNodesToFail])
  end

  @impl true
  def init([numNodes, numRequests,noOfNodesToFail]) do
    children =[
      {Tapestry.Main,[numNodes, numRequests,noOfNodesToFail]},
      {Tapestry.Counter,[numNodes]},
      {DynamicSupervisor, name: TapestryNodeSupervisor, strategy: :one_for_one}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
