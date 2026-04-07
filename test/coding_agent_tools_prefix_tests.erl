%%%-------------------------------------------------------------------
%%% @doc Unit tests for coding_agent_tools command prefix matching
%%% Tests verify that tool names are matched exactly, not by prefix.
%%%-------------------------------------------------------------------
-module(coding_agent_tools_prefix_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Helper function to check if a tool name is valid
%%--------------------------------------------------------------------
is_valid_tool_name(Name) when is_binary(Name) ->
    Tools = coding_agent_tools:tools(),
    lists:any(fun(#{<<"type">> := <<"function">>, <<"function">> := #{<<"name">> := ToolName}}) ->
        ToolName =:= Name
    end, Tools);
is_valid_tool_name(_) ->
    false.

%%--------------------------------------------------------------------
%% Test that exact tool names work correctly
%%--------------------------------------------------------------------
exact_tool_name_test() ->
    %% Test that exact tool names are properly matched
    ?assertEqual(true, is_valid_tool_name(<<"read_file">>)),
    ?assertEqual(true, is_valid_tool_name(<<"write_file">>)),
    ?assertEqual(true, is_valid_tool_name(<<"edit_file">>)),
    ?assertEqual(true, is_valid_tool_name(<<"list_files">>)),
    ?assertEqual(true, is_valid_tool_name(<<"grep_files">>)),
    ?assertEqual(true, is_valid_tool_name(<<"find_files">>)),
    ?assertEqual(true, is_valid_tool_name(<<"run_command">>)),
    ?assertEqual(true, is_valid_tool_name(<<"hello">>)),
    ?assertEqual(true, is_valid_tool_name(<<"run_tests">>)),
    ok.

%%--------------------------------------------------------------------
%% Test that partial/prefix tool names do NOT match
%%--------------------------------------------------------------------
prefix_tool_name_test() ->
    %% These should NOT match (they are prefixes, not full names)
    ?assertEqual(false, is_valid_tool_name(<<"read">>)),
    ?assertEqual(false, is_valid_tool_name(<<"write">>)),
    ?assertEqual(false, is_valid_tool_name(<<"edit">>)),
    ?assertEqual(false, is_valid_tool_name(<<"list">>)),
    ?assertEqual(false, is_valid_tool_name(<<"grep">>)),
    ?assertEqual(false, is_valid_tool_name(<<"find">>)),
    ?assertEqual(false, is_valid_tool_name(<<"run">>)),
    ?assertEqual(false, is_valid_tool_name(<<"test">>)),
    ?assertEqual(false, is_valid_tool_name(<<"hell">>)),
    ?assertEqual(false, is_valid_tool_name(<<"he">>)),
    ?assertEqual(false, is_valid_tool_name(<<"h">>)),
    ok.

%%--------------------------------------------------------------------
%% Test that suffixes do NOT match
%%--------------------------------------------------------------------
suffix_tool_name_test() ->
    ?assertEqual(false, is_valid_tool_name(<<"file">>)),
    ?assertEqual(false, is_valid_tool_name(<<"files">>)),
    ?assertEqual(false, is_valid_tool_name(<<"command">>)),
    ?assertEqual(false, is_valid_tool_name(<<"tool">>)),
    ok.

%%--------------------------------------------------------------------
%% Test case sensitivity
%%--------------------------------------------------------------------
case_sensitivity_test() ->
    %% Tool names should be case-sensitive (exact binary match)
    ?assertEqual(false, is_valid_tool_name(<<"READ_FILE">>)),
    ?assertEqual(false, is_valid_tool_name(<<"Read_File">>)),
    ?assertEqual(false, is_valid_tool_name(<<"ReadFile">>)),
    ?assertEqual(false, is_valid_tool_name(<<"readFile">>)),
    ?assertEqual(false, is_valid_tool_name(<<"Read_file">>)),
    ok.

%%--------------------------------------------------------------------
%% Test unknown tool names
%%--------------------------------------------------------------------
unknown_tool_test() ->
    %% Unknown tools should return error
    ?assertMatch(#{<<"success">> := false, <<"error">> := _}, 
                 coding_agent_tools:execute(<<"unknown_tool">>, #{})),
    ?assertMatch(#{<<"success">> := false, <<"error">> := _}, 
                 coding_agent_tools:execute(<<"nonexistent">>, #{})),
    ?assertMatch(#{<<"success">> := false, <<"error">> := _}, 
                 coding_agent_tools:execute(<<"random_command">>, #{})),
    ok.

%%--------------------------------------------------------------------
%% Test tool execution with correct names
%%--------------------------------------------------------------------
tool_execution_exact_name_test() ->
    %% Test that tools execute correctly with exact names
    Result1 = coding_agent_tools:execute(<<"hello">>, #{}),
    ?assertMatch(#{<<"success">> := true, <<"message">> := <<"hello world">>}, Result1),
    ok.

%%--------------------------------------------------------------------
%% Test tool execution with incorrect names (prefixes)
%%--------------------------------------------------------------------
tool_execution_prefix_name_test() ->
    %% These should fail because they're not exact tool names
    ?assertMatch(#{<<"success">> := false}, 
                 coding_agent_tools:execute(<<"read">>, #{<<"path">> => <<"/tmp/test">>})),
    ?assertMatch(#{<<"success">> := false}, 
                 coding_agent_tools:execute(<<"test">>, #{})),
    ?assertMatch(#{<<"success">> := false}, 
                 coding_agent_tools:execute(<<"hell">>, #{})),
    ok.

%%--------------------------------------------------------------------
%% Test all valid tool names from tools/0
%%--------------------------------------------------------------------
all_valid_tools_test() ->
    %% Valid tool names from the tools() function
    ValidTools = [
        <<"read_file">>, <<"edit_file">>, <<"write_file">>, <<"create_directory">>,
        <<"list_files">>, <<"file_exists">>, <<"git_status">>, <<"git_diff">>,
        <<"git_log">>, <<"git_add">>, <<"git_commit">>, <<"run_tests">>,
        <<"run_build">>, <<"run_linter">>, <<"grep_files">>, <<"find_files">>,
        <<"undo_edit">>, <<"list_backups">>, <<"detect_project">>, <<"run_command">>,
        <<"smart_commit">>, <<"review_changes">>, <<"generate_tests">>,
        <<"generate_docs">>, <<"fetch_docs">>, <<"rename_symbol">>,
        <<"extract_function">>, <<"load_context">>, <<"find_references">>,
        <<"get_callers">>, <<"hello">>
    ],
    
    %% All valid tools should be recognized
    lists:foreach(fun(ToolName) ->
        ?assertEqual(true, is_valid_tool_name(ToolName),
                     io_lib:format("Tool ~p should be valid", [ToolName]))
    end, ValidTools),
    ok.

%%--------------------------------------------------------------------
%% Test tool name with extra whitespace
%%--------------------------------------------------------------------
tool_name_whitespace_test() ->
    %% Tool names with whitespace should not match
    ?assertEqual(false, is_valid_tool_name(<<" read_file">>)),
    ?assertEqual(false, is_valid_tool_name(<<"read_file ">>)),
    ?assertEqual(false, is_valid_tool_name(<<"read_file\n">>)),
    ?assertEqual(false, is_valid_tool_name(<<"read\tfile">>)),
    ?assertEqual(false, is_valid_tool_name(<<" read_file ">>)),
    ok.

%%--------------------------------------------------------------------
%% Test empty tool name
%%--------------------------------------------------------------------
empty_tool_name_test() ->
    ?assertEqual(false, is_valid_tool_name(<<"">>)),
    ?assertMatch(#{<<"success">> := false}, coding_agent_tools:execute(<<"">>, #{})),
    ok.

%%--------------------------------------------------------------------
%% Test tool name with special characters
%%--------------------------------------------------------------------
special_chars_tool_name_test() ->
    ?assertEqual(false, is_valid_tool_name(<<"read_file!">>)),
    ?assertEqual(false, is_valid_tool_name(<<"read_file?">>)),
    ?assertEqual(false, is_valid_tool_name(<<"read_file@">>)),
    ?assertEqual(false, is_valid_tool_name(<<"$read_file">>)),
    ?assertEqual(false, is_valid_tool_name(<<"read-file">>)),
    ok.

%%--------------------------------------------------------------------
%% Test tool name with underscores (should work)
%%--------------------------------------------------------------------
underscore_tool_name_test() ->
    %% Tools with underscores should work
    ?assertEqual(true, is_valid_tool_name(<<"run_tests">>)),
    ?assertEqual(true, is_valid_tool_name(<<"git_status">>)),
    ?assertEqual(true, is_valid_tool_name(<<"find_files">>)),
    ?assertEqual(true, is_valid_tool_name(<<"undo_edit">>)),
    ok.

%%--------------------------------------------------------------------
%% Test tool names are returned correctly by tools/0
%%--------------------------------------------------------------------
tools_list_test() ->
    Tools = coding_agent_tools:tools(),
    ?assert(length(Tools) > 0),
    
    %% Each tool should have the correct structure
    lists:foreach(fun(Tool) ->
        ?assertMatch(#{<<"type">> := <<"function">>, <<"function">> := _}, Tool),
        #{<<"function">> := #{<<"name">> := Name}} = Tool,
        ?assert(is_binary(Name)),
        ?assert(byte_size(Name) > 0)
    end, Tools),
    ok.

%%--------------------------------------------------------------------
%% Test that tool names don't collide
%%--------------------------------------------------------------------
unique_tool_names_test() ->
    Tools = coding_agent_tools:tools(),
    Names = [begin
        #{<<"function">> := #{<<"name">> := Name}} = Tool,
        Name
    end || Tool <- Tools, is_map_key(<<"function">>, Tool)],
    
    %% All tool names should be unique
    UniqueNames = lists:usort(Names),
    ?assertEqual(length(Names), length(UniqueNames),
                 "All tool names should be unique"),
    ok.

%%--------------------------------------------------------------------
%% Test tool name length
%%--------------------------------------------------------------------
tool_name_length_test() ->
    %% Tool names should be reasonable length
    Tools = coding_agent_tools:tools(),
    lists:foreach(fun(Tool) ->
        #{<<"function">> := #{<<"name">> := Name}} = Tool,
        ?assert(byte_size(Name) >= 3, "Tool name too short"),
        ?assert(byte_size(Name) =< 50, "Tool name too long")
    end, Tools),
    ok.

%%--------------------------------------------------------------------
%% Test that tool names with prefixes are documented
%% Note: Some tool names ARE prefixes of others (e.g., "undo" is prefix of "undo_edit")
%% This is intentional and acceptable - the execute/2 function uses exact matching.
%%--------------------------------------------------------------------
no_prefix_collision_test() ->
    %% Document that prefix collisions exist but are handled by exact matching
    Tools = coding_agent_tools:tools(),
    Names = [begin
        #{<<"function">> := #{<<"name">> := Name}} = Tool,
        Name
    end || Tool <- Tools, is_map_key(<<"function">>, Tool)],
    
    %% Find all prefix collisions
    PrefixCollisions = lists:filtermap(fun(Name1) ->
        IsPrefix = lists:any(fun(Name2) ->
            Name1 =/= Name2 andalso 
            binary:longest_common_prefix([Name1, Name2]) =:= byte_size(Name1)
        end, Names),
        case IsPrefix of
            true -> {true, Name1};
            false -> false
        end
    end, Names),
    
    %% We know these collisions exist - just verify they're documented
    %% The key point is that execute/2 uses exact name matching, so collisions are OK
    ExpectedCollisions = [<<"undo">>],  % undo is prefix of undo_edit, undo_history
    ?assertEqual(lists:sort(ExpectedCollisions), lists:sort(PrefixCollisions),
                 "Only expected prefix collisions should exist"),
    ok.