%%%-------------------------------------------------------------------
%%% @doc Undo/Redo Stack Manager
%%% 
%%% This module provides a transactional undo/redo system for tracking
%%% file modifications and other operations. Each operation is recorded
%%% with enough information to reverse it.
%%%
%%% Features:
%%% - Global undo/redo stack per session
%%% - Multi-file operation tracking
%%% - Operation grouping (atomic multi-file edits)
%%% - Integration with existing backup system
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(coding_agent_undo).
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([push/1, push/2]).
-export([undo/0, undo/1]).
-export([redo/0, redo/1]).
-export([get_undo_stack/0, get_redo_stack/0]).
-export([can_undo/0, can_redo/0]).
-export([clear/0]).
-export([begin_transaction/0, end_transaction/0, cancel_transaction/0]).
-export([get_last_operation/0]).
-export([get_history/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(SERVER, ?MODULE).
-define(MAX_STACK_SIZE, 100).

-record(state, {
    undo_stack = [],
    redo_stack = [],
    transaction = undefined,
    transaction_ops = []
}).

-record(operation, {
    id :: binary(),
    type :: atom(),
    timestamp :: integer(),
    description :: binary(),
    files :: [{Path :: string(), BackupPath :: string()}],
    metadata :: map()
}).

%%%===================================================================
%%% API Functions
%%%===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

push(Operation) ->
    push(Operation, #{}).

push(Operation, Metadata) ->
    gen_server:call(?SERVER, {push, Operation, Metadata}).

undo() ->
    undo(1).

undo(Count) when Count > 0 ->
    gen_server:call(?SERVER, {undo, Count}).

redo() ->
    redo(1).

redo(Count) when Count > 0 ->
    gen_server:call(?SERVER, {redo, Count}).

get_undo_stack() ->
    gen_server:call(?SERVER, get_undo_stack).

get_redo_stack() ->
    gen_server:call(?SERVER, get_redo_stack).

can_undo() ->
    gen_server:call(?SERVER, can_undo).

can_redo() ->
    gen_server:call(?SERVER, can_redo).

clear() ->
    gen_server:call(?SERVER, clear).

begin_transaction() ->
    gen_server:call(?SERVER, begin_transaction).

end_transaction() ->
    gen_server:call(?SERVER, end_transaction).

cancel_transaction() ->
    gen_server:call(?SERVER, cancel_transaction).

get_last_operation() ->
    gen_server:call(?SERVER, get_last_operation).

get_history(Count) ->
    gen_server:call(?SERVER, {get_history, Count}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    case ets:whereis(coding_agent_operations) of
        undefined ->
            ets:new(coding_agent_operations, [named_table, public, ordered_set]);
        _ ->
            ok
    end,
    {ok, #state{}}.

handle_call({push, Operation, Metadata}, _From, State) ->
    #state{undo_stack = UndoStack, transaction = Transaction, transaction_ops = TxnOps} = State,
    Op = create_operation(Operation, Metadata),
    case Transaction of
        undefined ->
            NewUndoStack = [Op | UndoStack],
            NewState = State#state{
                undo_stack = limit_stack(NewUndoStack),
                redo_stack = []
            },
            store_operation(Op),
            {reply, {ok, Op#operation.id}, NewState};
        _ ->
            {reply, {ok, Op#operation.id}, State#state{
                transaction_ops = [Op | TxnOps]
            }}
    end;

handle_call({undo, Count}, _From, State) ->
    #state{undo_stack = UndoStack, redo_stack = RedoStack} = State,
    case lists:split(min(Count, length(UndoStack)), UndoStack) of
        {ToUndo, Remaining} when ToUndo =/= [] ->
            Results = lists:map(fun undo_operation/1, ToUndo),
            AllOk = lists:all(fun(R) -> element(1, R) == ok end, Results),
            case AllOk of
                true ->
                    NewState = State#state{
                        undo_stack = Remaining,
                        redo_stack = lists:reverse(ToUndo) ++ RedoStack
                    },
                    {reply, {ok, Results}, NewState};
                false ->
                    {reply, {error, partial_undo, Results}, State}
            end;
        _ ->
            {reply, {error, nothing_to_undo}, State}
    end;

handle_call({redo, Count}, _From, State) ->
    #state{undo_stack = UndoStack, redo_stack = RedoStack} = State,
    case lists:split(min(Count, length(RedoStack)), RedoStack) of
        {ToRedo, Remaining} when ToRedo =/= [] ->
            Results = lists:map(fun redo_operation/1, ToRedo),
            AllOk = lists:all(fun(R) -> element(1, R) == ok end, Results),
            case AllOk of
                true ->
                    NewState = State#state{
                        undo_stack = lists:reverse(ToRedo) ++ UndoStack,
                        redo_stack = Remaining
                    },
                    {reply, {ok, Results}, NewState};
                false ->
                    {reply, {error, partial_redo, Results}, State}
            end;
        _ ->
            {reply, {error, nothing_to_redo}, State}
    end;

handle_call(get_undo_stack, _From, State) ->
    {reply, format_stack(State#state.undo_stack), State};

handle_call(get_redo_stack, _From, State) ->
    {reply, format_stack(State#state.redo_stack), State};

handle_call(can_undo, _From, State) ->
    {reply, State#state.undo_stack =/= [], State};

handle_call(can_redo, _From, State) ->
    {reply, State#state.redo_stack =/= [], State};

handle_call(clear, _From, State) ->
    {reply, ok, State#state{undo_stack = [], redo_stack = []}};

handle_call(begin_transaction, _From, State) ->
    case State#state.transaction of
        undefined ->
            TxnId = generate_id(),
            {reply, {ok, TxnId}, State#state{transaction = TxnId, transaction_ops = []}};
        _ ->
            {reply, {error, transaction_in_progress}, State}
    end;

handle_call(end_transaction, _From, State) ->
    case State#state.transaction of
        undefined ->
            {reply, {error, no_transaction}, State};
        TxnId ->
            case State#state.transaction_ops of
                [] ->
                    {reply, {ok, TxnId}, State#state{transaction = undefined, transaction_ops = []}};
                Ops ->
                    CombinedOp = combine_operations(Ops, TxnId),
                    NewUndoStack = [CombinedOp | State#state.undo_stack],
                    store_operation(CombinedOp),
                    {reply, {ok, CombinedOp#operation.id}, State#state{
                        undo_stack = limit_stack(NewUndoStack),
                        redo_stack = [],
                        transaction = undefined,
                        transaction_ops = []
                    }}
            end
    end;

handle_call(cancel_transaction, _From, State) ->
    case State#state.transaction of
        undefined ->
            {reply, {error, no_transaction}, State};
        _ ->
            {reply, ok, State#state{transaction = undefined, transaction_ops = []}}
    end;

handle_call(get_last_operation, _From, State) ->
    case State#state.undo_stack of
        [Op | _] ->
            {reply, {ok, format_operation(Op)}, State};
        [] ->
            {reply, {error, no_operations}, State}
    end;

handle_call({get_history, Count}, _From, State) ->
    History = lists:sublist(format_stack(State#state.undo_stack), Count),
    {reply, History, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal Functions
%%%===================================================================

create_operation(Operation, Metadata) ->
    #operation{
        id = generate_id(),
        type = maps:get(type, Operation, edit),
        timestamp = erlang:system_time(millisecond),
        description = maps:get(description, Operation, <<>>),
        files = maps:get(files, Operation, []),
        metadata = Metadata
    }.

generate_id() ->
    Timestamp = erlang:system_time(millisecond),
    Random = rand:uniform(100000),
    iolist_to_binary(io_lib:format("op_~b_~b", [Timestamp, Random])).

limit_stack(Stack) when length(Stack) > ?MAX_STACK_SIZE ->
    lists:sublist(Stack, ?MAX_STACK_SIZE);
limit_stack(Stack) ->
    Stack.

store_operation(#operation{id = Id} = Op) ->
    ets:insert(coding_agent_operations, {Id, Op}).

undo_operation(#operation{files = Files} = _Op) ->
    Results = lists:map(fun({Path, BackupPath}) ->
        case filelib:is_file(BackupPath) of
            true ->
                case file:copy(BackupPath, Path) of
                    {ok, _} -> {ok, Path};
                    {error, Reason} -> {error, Path, Reason}
                end;
            false ->
                {error, Path, backup_not_found}
        end
    end, Files),
    AllOk = lists:all(fun(R) -> element(1, R) == ok end, Results),
    case AllOk of
        true -> {ok, files_restored};
        false -> {error, Results}
    end.

redo_operation(#operation{files = Files} = _Op) ->
    Results = lists:map(fun({Path, _BackupPath}) ->
        case filelib:is_file(Path) of
            true -> {ok, Path};
            false -> {error, Path, file_not_found}
        end
    end, Files),
    AllOk = lists:all(fun(R) -> element(1, R) == ok end, Results),
    case AllOk of
        true -> {ok, files_restored};
        false -> {error, Results}
    end.

combine_operations(Ops, TxnId) ->
    AllFiles = lists:flatmap(fun(#operation{files = Files}) -> Files end, Ops),
    FirstTimestamp = case Ops of
        [] -> erlang:system_time(millisecond);
        [#operation{timestamp = T} | _] -> T
    end,
    Descriptions = [Op#operation.description || Op <- Ops, Op#operation.description =/= <<>>],
    CombinedDesc = case Descriptions of
        [] -> <<>>;
        _ -> iolist_to_binary(lists:join(<<", ">>, Descriptions))
    end,
    #operation{
        id = TxnId,
        type = transaction,
        timestamp = FirstTimestamp,
        description = CombinedDesc,
        files = AllFiles,
        metadata = #{operation_count => length(Ops)}
    }.

format_stack(Stack) ->
    lists:map(fun format_operation/1, Stack).

format_operation(#operation{} = Op) ->
    #{
        id => Op#operation.id,
        type => Op#operation.type,
        timestamp => Op#operation.timestamp,
        description => Op#operation.description,
        files => [list_to_binary(P) || {P, _} <- Op#operation.files],
        metadata => Op#operation.metadata
    };
format_operation(_) ->
    #{error => invalid_operation}.