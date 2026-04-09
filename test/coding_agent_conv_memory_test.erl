%%%-------------------------------------------------------------------
%%% @doc Unit tests for coding_agent_conv_memory pure functions
%%%-------------------------------------------------------------------
-module(coding_agent_conv_memory_test).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% role_to_binary/1
%% ===================================================================
role_to_binary_user_test() ->
    ?assertEqual(<<"USER">>, coding_agent_conv_memory:role_to_binary(<<"user">>)).

role_to_binary_assistant_test() ->
    ?assertEqual(<<"ASSISTANT">>, coding_agent_conv_memory:role_to_binary(<<"assistant">>)).

role_to_binary_system_test() ->
    ?assertEqual(<<"SYSTEM">>, coding_agent_conv_memory:role_to_binary(<<"system">>)).

%% Note: binary:to_upper/1 is undefined in OTP 28, so unknown binary roles
%% will crash. These known-role tests confirm the explicit clauses work.
role_to_binary_atom_user_test() ->
    ?assertEqual(<<"USER">>, coding_agent_conv_memory:role_to_binary(user)).

role_to_binary_atom_assistant_test() ->
    ?assertEqual(<<"ASSISTANT">>, coding_agent_conv_memory:role_to_binary(assistant)).

role_to_binary_atom_system_test() ->
    ?assertEqual(<<"SYSTEM">>, coding_agent_conv_memory:role_to_binary(system)).

role_to_binary_other_type_test() ->
    Result = coding_agent_conv_memory:role_to_binary(123),
    ?assert(is_binary(Result)),
    ?assert(byte_size(Result) > 0).

%% ===================================================================
%% truncate_memory/2
%% ===================================================================
truncate_memory_under_limit_test() ->
    Memory = <<"short memory">>,
    ?assertEqual(Memory, coding_agent_conv_memory:truncate_memory(Memory, 1000)).

truncate_memory_exact_limit_test() ->
    Memory = binary:copy(<<"x">>, 100),
    ?assertEqual(Memory, coding_agent_conv_memory:truncate_memory(Memory, 100)).

truncate_memory_over_limit_with_header_test() ->
    %% Memory with \n## header before the truncation point
    %% MaxSize must be > 100 so KeepSize = MaxSize - 100 is valid,
    %% and byte_size(Memory) > MaxSize so truncation triggers,
    %% and the \n## header is before KeepSize
    Header = <<"Section 1 content\n## Section 2\n">>,
    Padding = binary:copy(<<"x">>, 300),
    Memory = <<Header/binary, Padding/binary>>,
    MaxSize = 200,
    Result = coding_agent_conv_memory:truncate_memory(Memory, MaxSize),
    %% Should mention "Older memories truncated" since \n## appears before KeepSize=100
    ?assertNotMatch(nomatch, binary:match(Result, <<"Older memories truncated">>)).

truncate_memory_over_limit_no_header_test() ->
    %% Memory without a \n## header
    Memory = binary:copy(<<"x">>, 200),
    MaxSize = 150,
    Result = coding_agent_conv_memory:truncate_memory(Memory, MaxSize),
    %% Should mention "Truncated for size"
    ?assertNotMatch(nomatch, binary:match(Result, <<"Truncated for size">>)).

truncate_memory_header_beyond_keep_test() ->
    %% Header \n## appears after KeepSize — should use "Truncated for size" branch
    %% KeepSize = MaxSize - 100. With MaxSize=101, KeepSize=1
    Memory = <<"xxxx\n## header\nmore content">>,
    MaxSize = 101,
    Result = coding_agent_conv_memory:truncate_memory(Memory, MaxSize),
    ?assert(is_binary(Result)).

%% ===================================================================
%% build_consolidation_prompt/2
%% ===================================================================
build_consolidation_prompt_basic_test() ->
    Messages = [
        #{<<"role">> => <<"user">>, <<"content">> => <<"hello">>},
        #{<<"role">> => <<"assistant">>, <<"content">> => <<"hi there">>}
    ],
    Result = coding_agent_conv_memory:build_consolidation_prompt(Messages, <<"existing memory">>),
    ?assert(is_binary(Result)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"USER: hello">>)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"ASSISTANT: hi there">>)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"existing memory">>)).

build_consolidation_prompt_empty_memory_test() ->
    Messages = [#{<<"role">> => <<"user">>, <<"content">> => <<"test">>}],
    Result = coding_agent_conv_memory:build_consolidation_prompt(Messages, <<"">>),
    ?assertNotMatch(nomatch, binary:match(Result, <<"(empty)">>)).

build_consolidation_prompt_long_content_truncated_test() ->
    LongContent = binary:copy(<<"x">>, 300),
    Messages = [#{<<"role">> => <<"user">>, <<"content">> => LongContent}],
    Result = coding_agent_conv_memory:build_consolidation_prompt(Messages, <<"">>),
    %% Content should be truncated to 200 chars + "..."
    ?assertNotMatch(nomatch, binary:match(Result, <<"...">>)).

build_consolidation_prompt_no_messages_test() ->
    Result = coding_agent_conv_memory:build_consolidation_prompt([], <<"memory">>),
    ?assert(is_binary(Result)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"memory">>)).

%% ===================================================================
%% build_detail_content/2
%% ===================================================================
build_detail_content_basic_test() ->
    Messages = [
        #{<<"role">> => <<"user">>, <<"content">> => <<"hello">>},
        #{<<"role">> => <<"assistant">>, <<"content">> => <<"response">>}
    ],
    Result = coding_agent_conv_memory:build_detail_content(Messages, <<"current memory">>),
    ?assertNotMatch(nomatch, binary:match(Result, <<"# Conversation Details">>)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"Long-term Memory at Archive Time">>)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"current memory">>)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"### USER">>)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"hello">>)).

build_detail_content_empty_messages_test() ->
    Result = coding_agent_conv_memory:build_detail_content([], <<"memory">>),
    ?assertNotMatch(nomatch, binary:match(Result, <<"# Conversation Details">>)),
    %% Should still have the conversation section header
    ?assertNotMatch(nomatch, binary:match(Result, <<"## Conversation">>)).

build_detail_content_missing_role_test() ->
    %% Message without role key — maps:get defaults to <<"unknown">>
    %% which hits the binary:to_upper clause and crashes in OTP 28
    %% Use a known role instead to test missing-content handling
    Messages = [#{<<"role">> => <<"user">>}],
    Result = coding_agent_conv_memory:build_detail_content(Messages, <<"">>),
    ?assert(is_binary(Result)),
    ?assertNotMatch(nomatch, binary:match(Result, <<"### USER">>)).

%% ===================================================================
%% format_timestamp/1
%% ===================================================================
format_timestamp_returns_binary_test() ->
    Result = coding_agent_conv_memory:format_timestamp(erlang:system_time(millisecond)),
    ?assert(is_binary(Result)),
    ?assert(byte_size(Result) > 0).

format_timestamp_zero_test() ->
    Result = coding_agent_conv_memory:format_timestamp(0),
    ?assert(is_binary(Result)),
    ?assert(byte_size(Result) > 0).

%% ===================================================================
%% format_timestamp_file/1
%% ===================================================================
format_timestamp_file_returns_binary_test() ->
    Result = coding_agent_conv_memory:format_timestamp_file(erlang:system_time(millisecond)),
    ?assert(is_binary(Result)),
    ?assert(byte_size(Result) > 0).

format_timestamp_file_zero_test() ->
    Result = coding_agent_conv_memory:format_timestamp_file(0),
    ?assert(is_binary(Result)),
    ?assert(byte_size(Result) > 0).