%%%-------------------------------------------------------------------
%%% @doc Unit tests for coding_agent_tools pure functions
%%%-------------------------------------------------------------------
-module(coding_agent_tools_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% sanitize_path/1
%% ===================================================================
sanitize_path_binary_test() ->
    ?assertEqual("/tmp/test.txt", coding_agent_tools:sanitize_path(<<"/tmp/test.txt">>)).

sanitize_path_list_test() ->
    ?assertEqual("/tmp/test.txt", coding_agent_tools:sanitize_path("/tmp/test.txt")).

sanitize_path_empty_binary_test() ->
    ?assertEqual("", coding_agent_tools:sanitize_path(<<"">>)).

sanitize_path_unicode_binary_test() ->
    %% binary_to_list converts UTF-8 binary to byte list, not codepoint list
    Expected = binary_to_list(<<"/tmp/日本語.txt">>),
    ?assertEqual(Expected, coding_agent_tools:sanitize_path(<<"/tmp/日本語.txt">>)).

%% ===================================================================
%% safe_binary/1 and safe_binary/2
%% ===================================================================
safe_binary_small_binary_test() ->
    Small = <<"hello">>,
    ?assertEqual(Small, coding_agent_tools:safe_binary(Small)).

safe_binary_exact_limit_test() ->
    Bin = binary:copy(<<"x">>, 20000),
    ?assertEqual(Bin, coding_agent_tools:safe_binary(Bin)).

safe_binary_over_limit_test() ->
    Bin = binary:copy(<<"x">>, 20001),
    Result = coding_agent_tools:safe_binary(Bin),
    ?assertEqual(20000 + length("... (truncated)"), byte_size(Result)),
    ?assertEqual(<<"... (truncated)">>, binary:part(Result, byte_size(Result) - 15, 15)).

safe_binary_list_input_test() ->
    ?assertEqual(<<"hello world">>, coding_agent_tools:safe_binary("hello world")).

safe_binary_atom_input_test() ->
    Result = coding_agent_tools:safe_binary(hello),
    ?assert(is_binary(Result)),
    ?assert(byte_size(Result) > 0).

safe_binary_integer_input_test() ->
    Result = coding_agent_tools:safe_binary(42),
    ?assertEqual(<<"42">>, Result).

safe_binary_custom_max_test() ->
    Bin = binary:copy(<<"a">>, 100),
    Result = coding_agent_tools:safe_binary(Bin, 50),
    ?assert(byte_size(Result) > 50),
    ?assertEqual(<<"... (truncated)">>, binary:part(Result, byte_size(Result) - 15, 15)).

safe_binary_custom_max_under_test() ->
    Bin = <<"short">>,
    Result = coding_agent_tools:safe_binary(Bin, 100),
    ?assertEqual(Bin, Result).

%% ===================================================================
%% find_occurrences/2 — takes list inputs (calls list_to_binary internally)
%% ===================================================================
find_occurrences_basic_test() ->
    ?assertEqual(3, coding_agent_tools:find_occurrences("hello hello hello", "hello")).

find_occurrences_none_test() ->
    ?assertEqual(0, coding_agent_tools:find_occurrences("hello world", "xyz")).

find_occurrences_overlapping_test() ->
    %% binary:matches doesn't count overlapping, so "aaa" has 1 match of "aa"
    ?assertEqual(1, coding_agent_tools:find_occurrences("aaa", "aa")).

find_occurrences_empty_haystack_test() ->
    ?assertEqual(0, coding_agent_tools:find_occurrences("", "test")).

%% ===================================================================
%% replace_all/3 — takes list inputs (calls list_to_binary internally)
%% ===================================================================
replace_all_basic_test() ->
    ?assertEqual("hello universe", coding_agent_tools:replace_all("hello world", "world", "universe")).

replace_all_multiple_test() ->
    ?assertEqual("xxx xxx xxx", coding_agent_tools:replace_all("aaa aaa aaa", "aaa", "xxx")).

replace_all_none_test() ->
    ?assertEqual("no match here", coding_agent_tools:replace_all("no match here", "xyz", "abc")).

replace_all_replaces_all_occurrences_test() ->
    ?assertEqual("bb", coding_agent_tools:replace_all("aa", "a", "b")).

%% ===================================================================
%% contains_merge_conflict/1
%% ===================================================================
contains_merge_conflict_with_markers_test() ->
    ConflictBin = <<"<<<<<<< HEAD\nfoo\n=======\nbar\n>>>>>>> branch">>,
    ?assert(coding_agent_tools:contains_merge_conflict(ConflictBin)).

contains_merge_conflict_list_test() ->
    ?assert(coding_agent_tools:contains_merge_conflict("<<<<<<< HEAD\nfoo\n=======\nbar\n>>>>>>> branch")).

contains_merge_conflict_no_markers_test() ->
    ?assertNot(coding_agent_tools:contains_merge_conflict(<<"clean content">>)).

contains_merge_conflict_single_marker_test() ->
    %% The implementation checks for <<<<<<<, =======, and >>>>>>> independently.
    %% A single marker type IS detected as a merge conflict.
    ?assert(coding_agent_tools:contains_merge_conflict(<<"just ======= here">>)).

contains_merge_conflict_other_type_test() ->
    ?assertNot(coding_agent_tools:contains_merge_conflict(123)).

%% ===================================================================
%% resolve_conflicts / resolve_conflicts_with_strategy
%% ===================================================================
resolve_conflicts_ours_test() ->
    Content = <<"before\n<<<<<<< HEAD\nour changes\n=======\ntheir changes\n>>>>>>> branch\nafter">>,
    Result = coding_agent_tools:resolve_conflicts(Content, <<"ours">>),
    ?assertNotMatch(nomatch, binary:match(Result, <<"our changes">>)),
    ?assertMatch(nomatch, binary:match(Result, <<"their changes">>)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"before">>)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"after">>)).

resolve_conflicts_theirs_test() ->
    Content = <<"before\n<<<<<<< HEAD\nour changes\n=======\ntheir changes\n>>>>>>> branch\nafter">>,
    Result = coding_agent_tools:resolve_conflicts(Content, <<"theirs">>),
    ?assertNotMatch(nomatch, binary:match(Result, <<"their changes">>)),
    ?assertMatch(nomatch, binary:match(Result, <<"our changes">>)).

resolve_conflicts_both_test() ->
    Content = <<"before\n<<<<<<< HEAD\nour changes\n=======\ntheir changes\n>>>>>>> branch\nafter">>,
    Result = coding_agent_tools:resolve_conflicts(Content, <<"both">>),
    ?assertNotMatch(nomatch, binary:match(Result, <<"our changes">>)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"their changes">>)).

resolve_conflicts_smart_prefers_larger_test() ->
    Content = <<"<<<<<<< HEAD\nsmall\n=======\nmuch larger content here\n>>>>>>> branch">>,
    Result = coding_agent_tools:resolve_conflicts(Content, <<"smart">>),
    ?assertNotMatch(nomatch, binary:match(Result, <<"much larger content here">>)).

resolve_conflicts_smart_prefers_imports_test() ->
    Content = <<"<<<<<<< HEAD\nlocal code\n=======\nimport Foo\n>>>>>>> branch">>,
    Result = coding_agent_tools:resolve_conflicts(Content, <<"smart">>),
    ?assertNotMatch(nomatch, binary:match(Result, <<"import Foo">>)).

resolve_conflicts_no_conflicts_test() ->
    Content = <<"no conflicts here\njust regular content">>,
    Result = coding_agent_tools:resolve_conflicts(Content, <<"ours">>),
    ?assertEqual(Content, Result).

resolve_conflicts_default_strategy_test() ->
    Content = <<"<<<<<<< HEAD\nour code\n=======\ntheir code\n>>>>>>> branch">>,
    Result = coding_agent_tools:resolve_conflicts(Content, <<"unknown">>),
    ?assert(is_binary(Result)).

%% ===================================================================
%% detect_change_type/1
%% ===================================================================
detect_change_type_test_files_test() ->
    Diff = "diff --git a/src/foo_test.erl b/src/foo_test.erl\nnew file\n+test content",
    Result = coding_agent_tools:detect_change_type(Diff),
    ?assertMatch({test, _}, Result).

detect_change_type_docs_test() ->
    Diff = "diff --git a/README.md b/README.md\n+doc changes",
    Result = coding_agent_tools:detect_change_type(Diff),
    ?assertMatch({docs, _}, Result).

detect_change_type_new_file_test() ->
    Diff = "diff --git a/new_file.erl b/new_file.erl\nnew file\n+new content",
    Result = coding_agent_tools:detect_change_type(Diff),
    ?assertMatch({add, _}, Result).

detect_change_type_modify_test() ->
    Diff = "diff --git a/src/app.erl b/src/app.erl\n+modified",
    Result = coding_agent_tools:detect_change_type(Diff),
    ?assertMatch({modify, _}, Result).

%% ===================================================================
%% analyze_diff/1
%% ===================================================================
analyze_diff_basic_test() ->
    Diff = "diff --git a/foo.erl b/foo.erl\n+added line\n-removed line\n context line",
    Result = coding_agent_tools:analyze_diff(Diff),
    ?assertEqual(1, maps:get(<<"lines_added">>, Result)),
    ?assertEqual(1, maps:get(<<"lines_removed">>, Result)),
    ?assert(maps:get(<<"files_changed">>, Result) >= 1).

analyze_diff_empty_test() ->
    Result = coding_agent_tools:analyze_diff(""),
    ?assertEqual(0, maps:get(<<"lines_added">>, Result)),
    ?assertEqual(0, maps:get(<<"lines_removed">>, Result)).

analyze_diff_header_lines_ignored_test() ->
    Diff = "+++ a/foo.erl\n--- b/foo.erl\n+real addition",
    Result = coding_agent_tools:analyze_diff(Diff),
    ?assertEqual(1, maps:get(<<"lines_added">>, Result)).

%% ===================================================================
%% detect_issues/1
%% ===================================================================
detect_issues_todo_test() ->
    ?assertNotEqual([], coding_agent_tools:detect_issues("has a TODO in it")).

detect_issues_fixme_test() ->
    ?assertNotEqual([], coding_agent_tools:detect_issues("has a FIXME in it")).

detect_issues_console_log_test() ->
    ?assertNotEqual([], coding_agent_tools:detect_issues("console.log('debug')")).

detect_issues_debugger_test() ->
    ?assertNotEqual([], coding_agent_tools:detect_issues("debugger;")).

detect_issues_clean_test() ->
    ?assertEqual([], coding_agent_tools:detect_issues("clean code with no markers")).

detect_issues_multiple_test() ->
    Issues = coding_agent_tools:detect_issues("TODO: fix this FIXME: later"),
    ?assert(length(Issues) >= 2).

%% ===================================================================
%% generate_suggestions/1
%% ===================================================================
generate_suggestions_secrets_test() ->
    ?assertNotEqual([], coding_agent_tools:generate_suggestions("password = 'secret'")).

generate_suggestions_api_key_test() ->
    ?assertNotEqual([], coding_agent_tools:generate_suggestions("api_key = 'abc'")).

generate_suggestions_print_test() ->
    ?assertNotEqual([], coding_agent_tools:generate_suggestions("io:format(\"debug\")")).

generate_suggestions_clean_test() ->
    ?assertEqual([], coding_agent_tools:generate_suggestions("clean code here")).

%% ===================================================================
%% format_undo_results/1
%% ===================================================================
format_undo_results_ok_test() ->
    ?assertEqual(
        [#{<<"status">> => <<"ok">>, <<"operation_id">> => files_restored}],
        coding_agent_tools:format_undo_results([{ok, files_restored}])
    ).

format_undo_results_error_test() ->
    Result = coding_agent_tools:format_undo_results([{error, "/tmp/test.erl", backup_not_found}]),
    ?assertEqual(1, length(Result)),
    [Item] = Result,
    ?assertEqual(<<"error">>, maps:get(<<"status">>, Item)).

format_undo_results_empty_test() ->
    ?assertEqual([], coding_agent_tools:format_undo_results([])).

format_undo_results_non_list_test() ->
    ?assertEqual([], coding_agent_tools:format_undo_results(something)).

%% ===================================================================
%% limit_grep_output/2
%% ===================================================================
limit_grep_output_under_limit_test() ->
    Output = <<"line1\nline2\nline3">>,
    ?assertEqual(Output, coding_agent_tools:limit_grep_output(Output, 10)).

limit_grep_output_over_limit_test() ->
    Lines = lists:join(<<"\n">>, [<<"line", (integer_to_binary(I))/binary>> || I <- lists:seq(1, 20)]),
    Output = iolist_to_binary(Lines),
    Result = coding_agent_tools:limit_grep_output(Output, 5),
    ?assertNotMatch(nomatch, binary:match(Result, <<"more lines omitted">>)).

limit_grep_output_exact_limit_test() ->
    Output = <<"line1\nline2\nline3">>,
    ?assertEqual(Output, coding_agent_tools:limit_grep_output(Output, 3)).

%% ===================================================================
%% clean_output/1
%% ===================================================================
clean_output_strips_ansi_test() ->
    Input = <<"\x1b[32mgreen text\x1b[0m">>,
    Result = coding_agent_tools:clean_output(Input),
    ?assertMatch(nomatch, binary:match(Result, <<"\x1b[">>)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"green text">>)).

clean_output_binary_under_limit_test() ->
    Input = <<"hello world">>,
    ?assertEqual(Input, coding_agent_tools:clean_output(Input)).

clean_output_list_input_test() ->
    Input = "hello world",
    Result = coding_agent_tools:clean_output(Input),
    ?assert(is_binary(Result)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"hello">>)).

clean_output_other_type_test() ->
    Result = coding_agent_tools:clean_output(42),
    ?assert(is_binary(Result)).

%% ===================================================================
%% execute/2 — unknown tool
%% ===================================================================
execute_unknown_tool_test() ->
    ?assertMatch(#{<<"success">> := false}, coding_agent_tools:execute(<<"unknown_tool">>, #{})).

execute_empty_tool_name_test() ->
    ?assertMatch(#{<<"success">> := false}, coding_agent_tools:execute(<<"">>, #{})).

execute_hello_tool_test() ->
    ?assertMatch(#{<<"success">> := true, <<"message">> := <<"hello world">>},
                 coding_agent_tools:execute(<<"hello">>, #{})).

%% ===================================================================
%% Git tools — new tool dispatch
%% ===================================================================
git_stash_list_test() ->
    Result = coding_agent_tools_git:execute(<<"git_stash">>, #{<<"action">> => <<"list">>}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_stash_default_action_test() ->
    Result = coding_agent_tools_git:execute(<<"git_stash">>, #{}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_remote_list_test() ->
    Result = coding_agent_tools_git:execute(<<"git_remote">>, #{<<"action">> => <<"list">>}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_remote_default_action_test() ->
    Result = coding_agent_tools_git:execute(<<"git_remote">>, #{}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_tag_list_test() ->
    Result = coding_agent_tools_git:execute(<<"git_tag">>, #{<<"action">> => <<"list">>}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_pull_default_test() ->
    Result = coding_agent_tools_git:execute(<<"git_pull">>, #{}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_push_no_force_test() ->
    Result = coding_agent_tools_git:execute(<<"git_push">>, #{}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_push_force_blocked_test() ->
    %% Force push should be blocked when safety callback rejects it
    erlang:put(coding_agent_safety_cb, fun(_Op, _Args) -> skip end),
    Result = coding_agent_tools_git:execute(<<"git_push">>, #{<<"force">> => true}),
    erlang:erase(coding_agent_safety_cb),
    ?assertMatch(#{<<"success">> := false}, Result).

git_merge_no_branch_test() ->
    Result = coding_agent_tools_git:execute(<<"git_merge">>, #{<<"branch">> => <<"nonexistent-branch-xyz">>}),
    ?assertMatch(#{<<"success">> := true}, Result).

%% Dispatch tests — ensure new tools route through coding_agent_tools:execute/2
git_stash_dispatch_test() ->
    Result = coding_agent_tools:execute(<<"git_stash">>, #{<<"action">> => <<"list">>}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_remote_dispatch_test() ->
    Result = coding_agent_tools:execute(<<"git_remote">>, #{<<"action">> => <<"list">>}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_tag_dispatch_test() ->
    Result = coding_agent_tools:execute(<<"git_tag">>, #{<<"action">> => <<"list">>}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_pull_dispatch_test() ->
    Result = coding_agent_tools:execute(<<"git_pull">>, #{}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_push_dispatch_test() ->
    Result = coding_agent_tools:execute(<<"git_push">>, #{}),
    ?assertMatch(#{<<"success">> := true}, Result).

git_merge_dispatch_test() ->
    Result = coding_agent_tools:execute(<<"git_merge">>, #{<<"branch">> => <<"nonexistent-branch-xyz">>}),
    ?assertMatch(#{<<"success">> := true}, Result).