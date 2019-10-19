defmodule TapestryNode do
    use GenServer

    def start_link(x,_,numRequests) do
        input_srt = Integer.to_string(x)
        nodeid = Base.encode16(:crypto.hash(:sha, input_srt))
        GenServer.start_link(__MODULE__, {nodeid,numRequests}, name: String.to_atom("n#{nodeid}"))
    end

    def init({selfid,numRequests}) do
        routetable = Matrix.from_list([[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]])
        {:ok, {selfid,routetable,numRequests,0}}
    end

    def handle_cast({:intialize_routing_table},{selfid,routetable,req,num_created})do
      
    end
end
