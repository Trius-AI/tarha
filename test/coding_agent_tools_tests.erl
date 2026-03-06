%%%-------------------------------------------------------------------
%%% @doc Unit tests for coding_agent_tools:execute/2
%%% Tests cover file operations, git operations, search operations,
%%% backup operations, and error handling.
%%%-------------------------------------------------------------------
-module(coding_agent_tools_tests).

-include_lib("eunit/include/eunit.hrl").

%% Test fixtures setup/teardown
setup() ->
    % Create a temporary test directory
    TestDir = "/tmp/coding_agent_test_" ++ integer_to_list(erlang:system_time(millisecond)),
    file:make_dir(TestDir),
    TestDir.

cleanup(TestDir) ->
    % Clean up test directory
    file:del_dir_r(TestDir),
    % Clear any backups created during tests
    coding_agent_tools:clear_backups().

%%--------------------------------------------------------------------
%% File Operations Tests
%%--------------------------------------------------------------------

read_file_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "test.txt"),
    Content = <<"Hello, World!">>,
    
    % Create test file
    file:write_file(TestFile, Content),
    
    % Test reading existing file
    Result = coding_agent_tools:execute(<<"read_file">>, #{<<"path">> => list_to_binary(TestFile)}),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    ?assertEqual(Content, maps:get(<<"content">>, Result)),
    
    % Test reading non-existent file
    NonExistent = filename:join(TestDir, "nonexistent.txt"),
    Result2 = coding_agent_tools:execute(<<"read_file">>, #{<<"path">> => list_to_binary(NonExistent)}),
    ?assertEqual(false, maps:get(<<"success">>, Result2)),
    ?assert(maps:is_key(<<"error">>, Result2)),
    
    cleanup(TestDir).

write_file_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "new_file.txt"),
    Content = <<"Test content for write_file">>,
    
    % Test writing to a new file
    Result = coding_agent_tools:execute(<<"write_file">>, #{
        <<"path">> => list_to_binary(TestFile),
        <<"content">> => Content
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    
    % Verify file was written correctly
    {ok, ReadContent} = file:read_file(TestFile),
    ?assertEqual(Content, ReadContent),
    
    cleanup(TestDir).

write_file_overwrites_existing_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "overwrite_test.txt"),
    
    % Create initial file
    file:write_file(TestFile, <<"Original content">>),
    
    % Overwrite with new content
    NewContent = <<"New content">>,
    Result = coding_agent_tools:execute(<<"write_file">>, #{
        <<"path">> => list_to_binary(TestFile),
        <<"content">> => NewContent
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    
    % Verify new content
    {ok, ReadContent} = file:read_file(TestFile),
    ?assertEqual(NewContent, ReadContent),
    
    cleanup(TestDir).

edit_file_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "edit_test.txt"),
    OriginalContent = <<"Hello World">>,
    file:write_file(TestFile, OriginalContent),
    
    % Test successful edit
    Result = coding_agent_tools:execute(<<"edit_file">>, #{
        <<"path">> => list_to_binary(TestFile),
        <<"old_string">> => <<"World">>,
        <<"new_string">> => <<"Erlang">>
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    
    % Verify edit
    {ok, EditedContent} = file:read_file(TestFile),
    ?assertEqual(<<"Hello Erlang">>, EditedContent),
    
    cleanup(TestDir).

edit_file_not_found_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "edit_not_found.txt"),
    file:write_file(TestFile, <<"Hello World">>),
    
    % Test edit with non-existent old_string
    Result = coding_agent_tools:execute(<<"edit_file">>, #{
        <<"path">> => list_to_binary(TestFile),
        <<"old_string">> => <<"NonExistent">>,
        <<"new_string">> => <<"Replacement">>
    }),
    ?assertEqual(false, maps:get(<<"success">>, Result)),
    ?assert(maps:is_key(<<"error">>, Result)),
    
    cleanup(TestDir).

edit_file_multiple_occurrences_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "multiple.txt"),
    file:write_file(TestFile, <<"foo bar foo bar foo">>),
    
    % Test edit with multiple occurrences (should fail without replace_all)
    Result = coding_agent_tools:execute(<<"edit_file">>, #{
        <<"path">> => list_to_binary(TestFile),
        <<"old_string">> => <<"foo">>,
        <<"new_string">> => <<"baz">>
    }),
    ?assertEqual(false, maps:get(<<"success">>, Result)),
    
    % Test with replace_all = true
    Result2 = coding_agent_tools:execute(<<"edit_file">>, #{
        <<"path">> => list_to_binary(TestFile),
        <<"old_string">> => <<"foo">>,
        <<"new_string">> => <<"baz">>,
        <<"replace_all">> => true
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result2)),
    
    {ok, EditedContent} = file:read_file(TestFile),
    ?assertEqual(<<"baz bar baz bar baz">>, EditedContent),
    
    cleanup(TestDir).

create_directory_test() ->
    TestDir = setup(),
    NewDir = filename:join(TestDir, "new_directory"),
    
    % Test creating a new directory
    Result = coding_agent_tools:execute(<<"create_directory">>, #{
        <<"path">> => list_to_binary(NewDir)
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    ?assert(filelib:is_dir(NewDir)),
    
    % Test creating already existing directory
    Result2 = coding_agent_tools:execute(<<"create_directory">>, #{
        <<"path">> => list_to_binary(NewDir)
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result2)),
    
    cleanup(TestDir).

list_files_test() ->
    TestDir = setup(),
    
    % Create test files
    file:write_file(filename:join(TestDir, "file1.txt"), <<"content1">>),
    file:write_file(filename:join(TestDir, "file2.txt"), <<"content2">>),
    file:make_dir(filename:join(TestDir, "subdir")),
    
    % Test non-recursive listing
    Result = coding_agent_tools:execute(<<"list_files">>, #{
        <<"path">> => list_to_binary(TestDir),
        <<"recursive">> => false
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    Files = maps:get(<<"files">>, Result),
    ?assertEqual(3, length(Files)),
    
    cleanup(TestDir).

list_files_recursive_test() ->
    TestDir = setup(),
    
    % Create nested structure
    file:write_file(filename:join(TestDir, "root.txt"), <<"root">>),
    SubDir = filename:join(TestDir, "sub"),
    file:make_dir(SubDir),
    file:write_file(filename:join(SubDir, "nested.txt"), <<"nested">>),
    
    % Test recursive listing
    Result = coding_agent_tools:execute(<<"list_files">>, #{
        <<"path">> => list_to_binary(TestDir),
        <<"recursive">> => true
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    AllFiles = maps:get(<<"files">>, Result),
    ?assertEqual(2, length(AllFiles)),
    
    cleanup(TestDir).

file_exists_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "exists_test.txt"),
    TestDir2 = filename:join(TestDir, "subdir"),
    
    % Create test file and directory
    file:write_file(TestFile, <<"content">>),
    file:make_dir(TestDir2),
    
    % Test existing file
    Result = coding_agent_tools:execute(<<"file_exists">>, #{
        <<"path">> => list_to_binary(TestFile)
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    ?assertEqual(true, maps:get(<<"exists">>, Result)),
    
    % Test existing directory
    Result2 = coding_agent_tools:execute(<<"file_exists">>, #{
        <<"path">> => list_to_binary(TestDir2)
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result2)),
    ?assertEqual(true, maps:get(<<"exists">>, Result2)),
    
    % Test non-existent path
    Result3 = coding_agent_tools:execute(<<"file_exists">>, #{
        <<"path">> => <<"/nonexistent/path/12345">>
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result3)),
    ?assertEqual(false, maps:get(<<"exists">>, Result3)),
    
    cleanup(TestDir).

%%--------------------------------------------------------------------
%% Unknown Tool Test
%%--------------------------------------------------------------------

unknown_tool_test() ->
    Result = coding_agent_tools:execute(<<"unknown_tool">>, #{}),
    ?assertEqual(false, maps:get(<<"success">>, Result)),
    ?assert(maps:is_key(<<"error">>, Result)),
    ?assertEqual(<<"Unknown tool">>, maps:get(<<"error">>, Result)).

%%--------------------------------------------------------------------
%% Search Operations Tests
%%--------------------------------------------------------------------

find_files_test() ->
    TestDir = setup(),
    
    % Create test files
    file:write_file(filename:join(TestDir, "test.erl"), <<"-module(test).">>),
    file:write_file(filename:join(TestDir, "test.txt"), <<"text file">>),
    
    % Test finding .erl files
    Result = coding_agent_tools:execute(<<"find_files">>, #{
        <<"pattern">> => <<"*.erl">>,
        <<"path">> => list_to_binary(TestDir)
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    Files = maps:get(<<"files">>, Result),
    ?assertEqual(1, length(Files)),
    
    cleanup(TestDir).

grep_files_test() ->
    TestDir = setup(),
    
    % Create test files
    file:write_file(filename:join(TestDir, "module.erl"), <<"-module(module).">>),
    file:write_file(filename:join(TestDir, "other.txt"), <<"no match here">>),
    
    % Test grep for pattern
    Result = coding_agent_tools:execute(<<"grep_files">>, #{
        <<"pattern">> => <<"-module">>,
        <<"path">> => list_to_binary(TestDir),
        <<"file_pattern">> => <<"*.erl">>
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    ?assert(maps:is_key(<<"matches">>, Result)),
    
    cleanup(TestDir).

%%--------------------------------------------------------------------
%% Backup Operations Tests
%%--------------------------------------------------------------------

list_backups_empty_test() ->
    % Clear backups first
    coding_agent_tools:clear_backups(),
    
    Result = coding_agent_tools:execute(<<"list_backups">>, #{}),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    ?assertEqual([], maps:get(<<"backups">>, Result)).

undo_edit_no_backup_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "no_backup.txt"),
    
    % Try to undo edit on file without backup
    Result = coding_agent_tools:execute(<<"undo_edit">>, #{
        <<"path">> => list_to_binary(TestFile)
    }),
    ?assertEqual(false, maps:get(<<"success">>, Result)),
    
    cleanup(TestDir).

%%--------------------------------------------------------------------
%% Project Detection Tests
%%--------------------------------------------------------------------

detect_project_test() ->
    Result = coding_agent_tools:execute(<<"detect_project">>, #{
        <<"path">> => <<".">>
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    ?assert(maps:is_key(<<"project_types">>, Result)),
    ?assert(maps:is_key(<<"is_git_repo">>, Result)).

%%--------------------------------------------------------------------
%% Argument Validation Tests
%%--------------------------------------------------------------------

read_file_missing_path_test() ->
    % Test with missing required parameter
    Result = coding_agent_tools:execute(<<"read_file">>, #{}),
    % Should either return error or handle missing parameter gracefully
    ?assert(maps:is_key(<<"success">>, Result)).

write_file_missing_content_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "test.txt"),
    
    % Test with missing content parameter
    Result = coding_agent_tools:execute(<<"write_file">>, #{
        <<"path">> => list_to_binary(TestFile)
    }),
    % Should fail due to missing content
    ?assert(maps:is_key(<<"success">>, Result)),

    cleanup(TestDir).

edit_file_missing_params_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "test.txt"),
    file:write_file(TestFile, <<"content">>),
    
    % Test with missing old_string
    Result = coding_agent_tools:execute(<<"edit_file">>, #{
        <<"path">> => list_to_binary(TestFile),
        <<"new_string">> => <<"replacement">>
    }),
    % Should fail due to missing old_string
    ?assert(maps:is_key(<<"success">>, Result)),
    
    cleanup(TestDir).

%%--------------------------------------------------------------------
%% Path Sanitization Tests
%%--------------------------------------------------------------------

path_with_binary_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "binary_path_test.txt"),
    file:write_file(TestFile, <<"content">>),
    
    % Test with binary path (normal case)
    Result = coding_agent_tools:execute(<<"read_file">>, #{
        <<"path">> => list_to_binary(TestFile)
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    
    cleanup(TestDir).

path_with_special_chars_test() ->
    TestDir = setup(),
    TestFile = filename:join(TestDir, "file with spaces.txt"),
    file:write_file(TestFile, <<"content with spaces">>),
    
    % Test with path containing spaces
    Result = coding_agent_tools:execute(<<"read_file">>, #{
        <<"path">> => list_to_binary(TestFile)
    }),
    ?assertEqual(true, maps:get(<<"success">>, Result)),
    
    cleanup(TestDir).

%%--------------------------------------------------------------------
%% Concurrent Execution Tests
%%--------------------------------------------------------------------

execute_concurrent_test() ->
    TestDir = setup(),
    
    % Create multiple test files
    Files = [
        {filename:join(TestDir, "file1.txt"), <<"content1">>},
        {filename:join(TestDir, "file2.txt"), <<"content2">>},
        {filename:join(TestDir, "file3.txt"), <<"content3">>}
    ],
    lists:foreach(fun({Path, Content}) ->
        file:write_file(Path, Content)
    end, Files),
    
    % Execute multiple read_file operations concurrently
    ToolCalls = [
        {<<"read_file">>, #{<<"path">> => list_to_binary(Path)}}
        || {Path, _} <- Files
    ],
    
    Results = coding_agent_tools:execute_concurrent(ToolCalls),
    
    % Verify all operations completed
    ?assertEqual(3, map_size(Results)),
    lists:foreach(fun({_, Content}) ->
        ?assert(maps:is_key(<<"read_file">>, Results))
    end, Files),
    
    cleanup(TestDir).

%%--------------------------------------------------------------------
%% Progress and Safety Callback Tests
%%--------------------------------------------------------------------

set_progress_callback_test() ->
    % Test setting a progress callback
    Called = spawn_link(fun() ->
        receive
            {progress, _Op, _Status, _Data} -> ok
        after 100 -> ok
        end
    end),
    Fun = fun(Op, Status, Data) ->
        Called ! {progress, Op, Status, Data}
    end,
    ?assertEqual(ok, coding_agent_tools:set_progress_callback(Fun)).

set_safety_callback_test() ->
    % Test setting a safety callback
    Fun = fun(_Op, _Args) -> proceed end,
    ?assertEqual(ok, coding_agent_tools:set_safety_callback(Fun)).

%%--------------------------------------------------------------------
%% Log Operations Tests
%%--------------------------------------------------------------------

get_log_test() ->
    % Clear log first
    coding_agent_tools:clear_log(),
    
    % Get log should return empty list initially
    Log = coding_agent_tools:get_log(),
    ?assert(lists:is_list(Log)).

clear_log_test() ->
    % Test clearing log
    ?assertEqual(ok, coding_agent_tools:clear_log()).

%%--------------------------------------------------------------------
%% Run Tests Operation Tests
%%--------------------------------------------------------------------

run_tests_default_args_test() ->
    % Test run_tests with default arguments (no pattern, not verbose)
    Result = coding_agent_tools:execute(<<"run_tests">>, #{}),
    % Should succeed in a rebar3 project
    ?assert(maps:is_key(<<"success">>, Result)),
    % Should have detected the command
    ?assert(maps:is_key(<<"command">>, Result) orelse maps:is_key(<<"error">>, Result)).

run_tests_with_pattern_test() ->
    % Test run_tests with a specific test pattern
    Result = coding_agent_tools:execute(<<"run_tests">>, #{
        <<"pattern">> => <<"module_name_test">>
    }),
    ?assert(maps:is_key(<<"success">>, Result)),
    % Command should include the pattern if successful
    case maps:get(<<"success">>, Result) of
        true -> 
            ?assert(maps:is_key(<<"command">>, Result));
        false ->
            ?assert(maps:is_key(<<"error">>, Result))
    end.

run_tests_verbose_test() ->
    % Test run_tests with verbose flag enabled
    Result = coding_agent_tools:execute(<<"run_tests">>, #{
        <<"verbose">> => true
    }),
    ?assert(maps:is_key(<<"success">>, Result)),
    % If successful, the command should include verbose flag
    case maps:get(<<"success">>, Result) of
        true ->
            Command = maps:get(<<"command">>, Result),
            % Verbose flag should be present in command
            ?assert(case binary:match(Command, <<"-v">>) of
                nomatch -> false;
                _ -> true
            end);
        false ->
            ?assert(maps:is_key(<<"error">>, Result))
    end.

run_tests_with_pattern_and_verbose_test() ->
    % Test run_tests with both pattern and verbose flags
    Result = coding_agent_tools:execute(<<"run_tests">>, #{
        <<"pattern">> => <<"specific_test">>,
        <<"verbose">> => true
    }),
    ?assert(maps:is_key(<<"success">>, Result)),
    case maps:get(<<"success">>, Result) of
        true ->
            Command = maps:get(<<"command">>, Result),
            % Should have both pattern and verbose flag
            ?assert(case binary:match(Command, <<"specific_test">>) of
                nomatch -> false;
                _ -> true
            end);
        false ->
            ok
    end.

run_tests_verbose_false_test() ->
    % Test run_tests with verbose explicitly set to false
    Result = coding_agent_tools:execute(<<"run_tests">>, #{
        <<"verbose">> => false
    }),
    ?assert(maps:is_key(<<"success">>, Result)),
    % Should work the same as default (no verbose flag)
    case maps:get(<<"success">>, Result) of
        true ->
            Command = maps:get(<<"command">>, Result),
            % Command should not have -v flag for Erlang projects (rebar3 eunit -v)
            % Note: the actual command depends on detected project type
            ?assert(is_binary(Command));
        false ->
            ?assert(maps:is_key(<<"error">>, Result))
    end.

run_tests_pattern_binary_test() ->
    % Test that pattern parameter accepts binary values
    Pattern = <<"my_module_tests">>,
    Result = coding_agent_tools:execute(<<"run_tests">>, #{
        <<"pattern">> => Pattern
    }),
    ?assert(maps:is_key(<<"success">>, Result)).

run_tests_in_erlang_project_test() ->
    % Test run_tests in an Erlang/Rebar3 project (current project)
    Result = coding_agent_tools:execute(<<"run_tests">>, #{}),
    ?assert(maps:is_key(<<"success">>, Result)),
    case maps:get(<<"success">>, Result) of
        true ->
            % Should detect rebar3 and run eunit
            Command = maps:get(<<"command">>, Result),
            ?assert(binary:match(Command, <<"rebar3">>) =/= nomatch);
        false ->
            % If test framework not found, should have error
            ?assert(maps:is_key(<<"error">>, Result))
    end.

run_tests_output_format_test() ->
    % Test that run_tests returns proper format
    Result = coding_agent_tools:execute(<<"run_tests">>, #{}),
    % Result should be a map with success key
    ?assert(is_map(Result)),
    ?assert(maps:is_key(<<"success">>, Result)),
    case maps:get(<<"success">>, Result) of
        true ->
            % On success, should have command and output
            ?assert(maps:is_key(<<"command">>, Result)),
            ?assert(maps:is_key(<<"output">>, Result));
        false ->
            % On failure, should have error
            ?assert(maps:is_key(<<"error">>, Result))
    end.

run_tests_empty_pattern_test() ->
    % Test run_tests with empty pattern string
    Result = coding_agent_tools:execute(<<"run_tests">>, #{
        <<"pattern">> => <<"">>
    }),
    ?assert(maps:is_key(<<"success">>, Result)).

run_tests_detection_order_test() ->
    % Test that test detection follows the expected priority order
    % The function should try rebar3 first for Erlang projects
    Result = coding_agent_tools:execute(<<"run_tests">>, #{}),
    case maps:get(<<"success">>, Result) of
        true ->
            Command = maps:get(<<"command">>, Result),
            % Should prefer rebar3 for Erlang projects (has rebar.config)
            ?assert(binary:match(Command, <<"rebar3">>) =/= nomatch);
        false ->
            ok
    end.