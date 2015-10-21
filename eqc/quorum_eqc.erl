%%% @author Thomas Arts <thomas@ThomasComputer.local>
%%% @copyright (C) 2015, Thomas Arts
%%% @doc
%%%
%%% @end
%%% Created : 21 Oct 2015 by Thomas Arts <thomas@ThomasComputer.local>

-module(quorum_eqc).

-include_lib("eqc/include/eqc.hrl").
-include_lib("eqc/include/eqc_statem.hrl").

-compile(export_all).

%% -- State ------------------------------------------------------------------
-record(state,{procs = [], initprocs = []}).

%% not used
initial_state() ->
  #state{}.

node_names() ->
  [1, 2, 3, 4, 5].

%% -- Operations -------------------------------------------------------------

initprocs_pre(#state{procs = Procs, initprocs = Pids}) ->
  (Procs -- Pids) /= [].

initprocs_args(#state{procs = Procs, initprocs = Pids}) ->
  [elements(Procs -- Pids), Procs].

initprocs_pre(#state{initprocs = Pids}, [Pid, _]) ->
  not lists:member(Pid, Pids).

initprocs(Pid, Procs) ->
  Pid ! {quorum_pids, self(), Procs -- [Pid]},
  receive
    ack -> ack
  after 1000 ->
      timeout
  end.

initprocs_next(#state{initprocs = Pids} = S, _, [Pid, _]) ->
  S#state{initprocs = Pids ++ [Pid]}.


%% --- Operation: ask ---
ask_pre(#state{initprocs = Pids}) ->
  Pids /= [].

ask_args(#state{initprocs = Pids}) ->
  [elements(Pids)].

%% for shrinking!
ask_pre(#state{initprocs = Pids}, [Pid]) ->
  lists:member(Pid, Pids).

ask(Pid) ->
  Pid ! {ask, self()},
  receive
    Result -> Result
  after 1000 ->
      timeout
  end.

ask_post(#state{procs = _Procs, initprocs = _Pids}, _Args, Res) ->
  eq(Res, yes).

%% --- Operation: kill ---
kill_pre(#state{initprocs = Pids}) ->
  Pids /= [].

kill_args(#state{initprocs = Pids}) ->
  [elements(Pids)].

kill_pre(#state{initprocs = Pids}, [Pid]) ->
  lists:member(Pid, Pids).

kill(Pid) ->
  exit(Pid, kill).

kill_next(#state{initprocs = Pids} = S, _Value, [Pid]) ->
  S#state{initprocs = Pids -- [Pid]}.


%% -- Property ---------------------------------------------------------------

weight(_S, _Cmd) -> 1.


start(Node) when is_integer(Node) ->
  {ok, Pid} = rpc:call(node(), quorum, start, []),
  Pid.

prop_quorum_eqc() ->
  with_parameter(print_counterexample, false,
  ?FORALL(Nodes, at_least(2, sublist(node_names())),
     ?FORALL(Cmds, commands(?MODULE, #state{procs = [{var, {proc,N}} || N<-Nodes ]}),
             begin
               Procs = [ {{proc, Node}, start(Node)} || Node<-Nodes],
               {H, S, Res} = run_commands(?MODULE, Cmds, Procs),
               pretty_commands(?MODULE, Cmds, {H, S, Res},
                               measure(length, length(Cmds),
                               aggregate(command_names(Cmds),
                                         Res == ok)))
             end))).

at_least(N, ListGen) ->
  ?SUCHTHAT(List, ListGen, length(List) >= N).

