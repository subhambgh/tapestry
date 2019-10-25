defmodule Main do

  @nodeLength 8

  def main(args) do
    {numNodes, numRequests, noOfNodesToFail} = parse_args(args)
    :ets.new(:hashList, [:set, :protected, :named_table])
    createHashList(numNodes)
    hashList =
      Enum.map(1..numNodes, fn x ->
        elem(Enum.at(:ets.lookup(:hashList, Integer.to_string(x)), 0), 1)
      end)
    IO.puts "hashList=#{inspect hashList}"
    rand = Enum.random(hashList)
    _=TapestrySupervisor.start_link([numNodes, numRequests,noOfNodesToFail])
    _=GenServer.call(Tapestry.Main,{:createNodes},:infinity)
    _=GenServer.call(Tapestry.Main,{:initRoutingTables,hashList},:infinity)
    _=GenServer.call(Tapestry.Main,{:initLastNode,hashList},:infinity)
    GenServer.call(String.to_atom("n"<>rand),{:printTables})
    randomNodesToFail=GenServer.call(Tapestry.Main,{:failNodesInit,hashList},:infinity)
    _=GenServer.call(Tapestry.Main,{:killNodes,randomNodesToFail},:infinity)
    IO.puts "randomNodesToFail=#{inspect randomNodesToFail}"
    GenServer.call(String.to_atom("n"<>rand),{:printTables})
    #_=GenServer.call(Tapestry.Main,{:startMessaging},:infinity)
  end

  def parse_args(args \\ []) do
    try do
        numNodes = elem(Integer.parse(Enum.at(args,0)),0)
        if numNodes <= 0 do
          raise "oops"
        end
        noOfRequests = elem(Integer.parse(Enum.at(args,1)),0)
        if noOfRequests <= 0 do
          raise "oops"
        end
        noOfNodesToFail=
        if Enum.at(args,2) == nil do
          0
        else
          elem(Integer.parse(Enum.at(args,2)),0)
        end
        if noOfNodesToFail < 0 do
          raise "oops"
        end
          {numNodes,noOfRequests,noOfNodesToFail}
      rescue
        ArgumentError -> IO.puts "Invalid Input !! Try Again."
        RuntimeError -> IO.puts "Invalid Input !! Try Again."
        System.halt(1)
      end
  end

  def createHashList(numNodes) do
    if numNodes == 0 do
      :ok
    else
      :ets.insert(
        :hashList,
        {Integer.to_string(numNodes),
         String.slice(
           Base.encode16(:crypto.hash(:sha, Integer.to_string(numNodes))),
           0..(@nodeLength - 1)
         )}
      )

      createHashList(numNodes - 1)
    end
  end

end
