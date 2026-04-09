%%%-------------------------------------------------------------------
%%% @doc Unit tests for coding_agent_undo
%%%
%%% These tests start the undo gen_server on a per-test basis to
%%% exercise the full push/undo/redo/transaction lifecycle.
%%%-------------------------------------------------------------------
-module(coding_agent_undo_test).

-include_lib("eunit/include/eunit.hrl").

%% Helper: start the undo server for a test, stop it after.
with_undo_server(TestFun) ->
    {ok, Pid} = coding_agent_undo:start_link(),
    try
        TestFun()
    after
        gen_server:stop(Pid)
    end.

%% Helper: create a temp file and its backup for undo testing.
setup_backup_file() ->
    TmpDir = lists:concat(["/tmp/tarha_test_", erlang:unique_integer([positive])]),
    ok = file:make_dir(TmpDir),
    FilePath = filename:join(TmpDir, "test.txt"),
    BackupPath = filename:join(TmpDir, "test.txt.bak"),
    ok = file:write_file(FilePath, <<"original">>),
    ok = file:write_file(BackupPath, <<"backup">>),
    {FilePath, BackupPath, TmpDir}.

cleanup_dir(Dir) ->
    {ok, Files} = file:list_dir(Dir),
    lists:foreach(fun(F) -> file:delete(filename:join(Dir, F)) end, Files),
    file:del_dir(Dir).

%% ===================================================================
%% push/1
%% ===================================================================
push_basic_test() ->
    with_undo_server(fun() ->
        Result = coding_agent_undo:push(#{description => <<"test op">>}),
        ?assertMatch({ok, _}, Result),
        ?assert(coding_agent_undo:can_undo())
    end).

push_with_files_test() ->
    with_undo_server(fun() ->
        {FilePath, BackupPath, TmpDir} = setup_backup_file(),
        try
            Result = coding_agent_undo:push(#{
                description => <<"edit file">>,
                files => [{FilePath, BackupPath}]
            }),
            ?assertMatch({ok, _}, Result)
        after
            cleanup_dir(TmpDir)
        end
    end).

push_clears_redo_test() ->
    with_undo_server(fun() ->
        coding_agent_undo:push(#{description => <<"op1">>}),
        coding_agent_undo:push(#{description => <<"op2">>}),
        %% Undo one, then push — redo should be cleared
        coding_agent_undo:undo(),
        ?assert(coding_agent_undo:can_redo()),
        coding_agent_undo:push(#{description => <<"op3">>}),
        ?assertNot(coding_agent_undo:can_redo())
    end).

%% ===================================================================
%% push/2 — with metadata
%% ===================================================================
push_with_metadata_test() ->
    with_undo_server(fun() ->
        Result = coding_agent_undo:push(#{description => <<"meta op">>}, #{source => <<"test">>}),
        ?assertMatch({ok, _}, Result)
    end).

%% ===================================================================
%% undo/0 and undo/1
%% ===================================================================
undo_empty_stack_test() ->
    with_undo_server(fun() ->
        ?assertMatch({error, nothing_to_undo}, coding_agent_undo:undo())
    end).

undo_single_op_test() ->
    with_undo_server(fun() ->
        {FilePath, BackupPath, TmpDir} = setup_backup_file(),
        try
            coding_agent_undo:push(#{
                description => <<"edit">>,
                files => [{FilePath, BackupPath}]
            }),
            Result = coding_agent_undo:undo(),
            ?assertMatch({ok, _}, Result),
            %% File should be restored from backup
            {ok, Content} = file:read_file(FilePath),
            ?assertEqual(<<"backup">>, Content),
            ?assertNot(coding_agent_undo:can_undo()),
            ?assert(coding_agent_undo:can_redo())
        after
            cleanup_dir(TmpDir)
        end
    end).

undo_multiple_ops_test() ->
    with_undo_server(fun() ->
        coding_agent_undo:push(#{description => <<"op1">>}),
        coding_agent_undo:push(#{description => <<"op2">>}),
        coding_agent_undo:push(#{description => <<"op3">>}),
        Result = coding_agent_undo:undo(2),
        ?assertMatch({ok, _}, Result)
    end).

undo_more_than_stack_test() ->
    with_undo_server(fun() ->
        coding_agent_undo:push(#{description => <<"op1">>}),
        %% Undo more than available should undo just 1
        ?assertMatch({ok, _}, coding_agent_undo:undo(5))
    end).

%% ===================================================================
%% redo/0 and redo/1
%% ===================================================================
redo_empty_stack_test() ->
    with_undo_server(fun() ->
        ?assertMatch({error, nothing_to_redo}, coding_agent_undo:redo())
    end).

redo_after_undo_test() ->
    with_undo_server(fun() ->
        coding_agent_undo:push(#{description => <<"op1">>}),
        coding_agent_undo:undo(),
        ?assert(coding_agent_undo:can_redo()),
        Result = coding_agent_undo:redo(),
        ?assertMatch({ok, _}, Result),
        ?assertNot(coding_agent_undo:can_redo())
    end).

%% ===================================================================
%% Transaction lifecycle
%% ===================================================================
begin_transaction_test() ->
    with_undo_server(fun() ->
        Result = coding_agent_undo:begin_transaction(),
        ?assertMatch({ok, _}, Result)
    end).

begin_transaction_nested_fails_test() ->
    with_undo_server(fun() ->
        {ok, _} = coding_agent_undo:begin_transaction(),
        ?assertMatch({error, transaction_in_progress}, coding_agent_undo:begin_transaction())
    end).

end_transaction_test() ->
    with_undo_server(fun() ->
        {ok, _} = coding_agent_undo:begin_transaction(),
        coding_agent_undo:push(#{description => <<"txn op1">>}),
        coding_agent_undo:push(#{description => <<"txn op2">>}),
        Result = coding_agent_undo:end_transaction(),
        ?assertMatch({ok, _}, Result),
        %% Should now be on the undo stack
        ?assert(coding_agent_undo:can_undo())
    end).

end_transaction_empty_test() ->
    with_undo_server(fun() ->
        {ok, TxnId} = coding_agent_undo:begin_transaction(),
        %% End transaction with no ops
        Result = coding_agent_undo:end_transaction(),
        ?assertMatch({ok, TxnId}, Result),
        ?assertNot(coding_agent_undo:can_undo())
    end).

end_transaction_no_transaction_test() ->
    with_undo_server(fun() ->
        ?assertMatch({error, no_transaction}, coding_agent_undo:end_transaction())
    end).

cancel_transaction_test() ->
    with_undo_server(fun() ->
        {ok, _} = coding_agent_undo:begin_transaction(),
        coding_agent_undo:push(#{description => <<"will be cancelled">>}),
        ?assertEqual(ok, coding_agent_undo:cancel_transaction()),
        %% Cancelled ops should NOT be on the undo stack
        ?assertNot(coding_agent_undo:can_undo())
    end).

cancel_transaction_no_transaction_test() ->
    with_undo_server(fun() ->
        ?assertMatch({error, no_transaction}, coding_agent_undo:cancel_transaction())
    end).

transaction_combined_undo_test() ->
    with_undo_server(fun() ->
        {FilePath, BackupPath, TmpDir} = setup_backup_file(),
        try
            {ok, _} = coding_agent_undo:begin_transaction(),
            coding_agent_undo:push(#{
                description => <<"txn edit">>,
                files => [{FilePath, BackupPath}]
            }),
            {ok, _} = coding_agent_undo:end_transaction(),
            %% Undo the transaction
            Result = coding_agent_undo:undo(),
            ?assertMatch({ok, _}, Result),
            %% File should be restored
            {ok, Content} = file:read_file(FilePath),
            ?assertEqual(<<"backup">>, Content)
        after
            cleanup_dir(TmpDir)
        end
    end).

%% ===================================================================
%% clear/0
%% ===================================================================
clear_test() ->
    with_undo_server(fun() ->
        coding_agent_undo:push(#{description => <<"op1">>}),
        coding_agent_undo:push(#{description => <<"op2">>}),
        coding_agent_undo:undo(),
        ?assert(coding_agent_undo:can_undo()),
        ?assert(coding_agent_undo:can_redo()),
        ok = coding_agent_undo:clear(),
        ?assertNot(coding_agent_undo:can_undo()),
        ?assertNot(coding_agent_undo:can_redo())
    end).

%% ===================================================================
%% get_last_operation/0
%% ===================================================================
get_last_operation_empty_test() ->
    with_undo_server(fun() ->
        ?assertMatch({error, no_operations}, coding_agent_undo:get_last_operation())
    end).

get_last_operation_with_data_test() ->
    with_undo_server(fun() ->
        coding_agent_undo:push(#{description => <<"latest">>}),
        ?assertMatch({ok, #{description := <<"latest">>}}, coding_agent_undo:get_last_operation())
    end).

%% ===================================================================
%% get_history/1
%% ===================================================================
get_history_test() ->
    with_undo_server(fun() ->
        coding_agent_undo:push(#{description => <<"first">>}),
        coding_agent_undo:push(#{description => <<"second">>}),
        coding_agent_undo:push(#{description => <<"third">>}),
        History = coding_agent_undo:get_history(2),
        ?assertEqual(2, length(History))
    end).

get_history_more_than_available_test() ->
    with_undo_server(fun() ->
        coding_agent_undo:push(#{description => <<"only">>}),
        History = coding_agent_undo:get_history(10),
        ?assertEqual(1, length(History))
    end).

%% ===================================================================
%% get_undo_stack/0 and get_redo_stack/0
%% ===================================================================
get_stacks_test() ->
    with_undo_server(fun() ->
        ?assertEqual([], coding_agent_undo:get_undo_stack()),
        ?assertEqual([], coding_agent_undo:get_redo_stack()),
        coding_agent_undo:push(#{description => <<"op">>}),
        UndoStack = coding_agent_undo:get_undo_stack(),
        ?assertEqual(1, length(UndoStack))
    end).

%% ===================================================================
%% can_undo/0 and can_redo/0
%% ===================================================================
can_undo_redo_test() ->
    with_undo_server(fun() ->
        ?assertNot(coding_agent_undo:can_undo()),
        ?assertNot(coding_agent_undo:can_redo()),
        coding_agent_undo:push(#{description => <<"op">>}),
        ?assert(coding_agent_undo:can_undo()),
        ?assertNot(coding_agent_undo:can_redo()),
        coding_agent_undo:undo(),
        ?assertNot(coding_agent_undo:can_undo()),
        ?assert(coding_agent_undo:can_redo())
    end).

%% ===================================================================
%% format_operation — verified through get_last_operation
%% ===================================================================
format_operation_has_required_keys_test() ->
    with_undo_server(fun() ->
        coding_agent_undo:push(#{description => <<"test">>, files => [{"/tmp/f.erl", "/tmp/f.erl.bak"}]}),
        {ok, Op} = coding_agent_undo:get_last_operation(),
        ?assert(maps:is_key(id, Op)),
        ?assert(maps:is_key(type, Op)),
        ?assert(maps:is_key(timestamp, Op)),
        ?assert(maps:is_key(description, Op)),
        ?assert(maps:is_key(files, Op)),
        ?assert(maps:is_key(metadata, Op)),
        %% files should be a list of binaries (backup paths dropped)
        ?assertEqual([<<"/tmp/f.erl">>], maps:get(files, Op))
    end).

format_operation_type_test() ->
    with_undo_server(fun() ->
        coding_agent_undo:push(#{type => custom_type, description => <<"typed op">>}),
        {ok, Op} = coding_agent_undo:get_last_operation(),
        ?assertEqual(custom_type, maps:get(type, Op))
    end).