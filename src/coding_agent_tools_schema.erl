-module(coding_agent_tools_schema).
-export([validate/2, check_required/2, validate_types/2, validate_values/2]).
-export([get_schema/1]).

-define(ERROR_CODES, #{
    not_found => <<"not_found">>,
    permission_denied => <<"permission_denied">>,
    already_exists => <<"already_exists">>,
    invalid_input => <<"invalid_input">>,
    timeout => <<"timeout">>,
    conflict => <<"conflict">>,
    git_rejected => <<"git_rejected">>,
    git_merge_conflict => <<"git_merge_conflict">>,
    build_failed => <<"build_failed">>,
    command_failed => <<"command_failed">>,
    network_error => <<"network_error">>
}).

get_schema(<<"read_file">>) ->
    [{<<"path">>, binary, required, fun validate_path/1}];
get_schema(<<"edit_file">>) ->
    [{<<"path">>, binary, required, fun validate_path/1},
     {<<"old_string">>, binary, required, fun validate_nonempty/1},
     {<<"new_string">>, binary, required, fun validate_nonempty/1},
     {<<"replace_all">>, boolean, optional, nil}];
get_schema(<<"write_file">>) ->
    [{<<"path">>, binary, required, fun validate_path/1},
     {<<"content">>, binary, required, fun validate_nonempty/1}];
get_schema(<<"run_command">>) ->
    [{<<"command">>, binary, required, fun validate_nonempty/1},
     {<<"timeout">>, integer, optional, fun validate_positive/1},
     {<<"cwd">>, binary, optional, fun validate_path/1}];
get_schema(<<"grep_files">>) ->
    [{<<"pattern">>, binary, required, fun validate_nonempty/1},
     {<<"path">>, binary, optional, fun validate_path/1},
     {<<"case_insensitive">>, boolean, optional, nil}];
get_schema(<<"find_files">>) ->
    [{<<"path">>, binary, optional, fun validate_path/1},
     {<<"name">>, binary, optional, fun validate_nonempty/1},
     {<<"type">>, binary, optional, nil}];
get_schema(_) ->
    [].

validate(ToolName, Args) when is_binary(ToolName), is_map(Args) ->
    Schema = get_schema(ToolName),
    case check_required(Schema, Args) of
        {error, _} = Error -> Error;
        ok ->
            case validate_types(Schema, Args) of
                {error, _} = Error -> Error;
                ok -> validate_values(Schema, Args)
            end
    end.

check_required(Schema, Args) ->
    Missing = [Key || {Key, _Type, required, _Validator} <- Schema, not maps:is_key(Key, Args)],
    case Missing of
        [] -> ok;
        _ -> {error, <<"Missing required parameters: ", (list_to_binary(string:join([binary_to_list(M) || M <- Missing], ", ")))/binary>>}
    end.

validate_types(Schema, Args) ->
    Errors = lists:filtermap(fun({Key, Type, _Required, _Validator}) ->
        case maps:is_key(Key, Args) of
            false -> false;
            true ->
                Value = maps:get(Key, Args),
                case validate_type(Type, Value) of
                    true -> false;
                    false -> {true, {Key, Type}}
                end
        end
    end, Schema),
    case Errors of
        [] -> ok;
        _ -> {error, <<"Type errors: ", (list_to_binary(string:join([io_lib:format("~s expected ~p", [K, T]) || {K, T} <- Errors], ", ")))/binary>>}
    end.

validate_values(Schema, Args) ->
    Errors = lists:filtermap(fun({Key, _Type, _Required, Validator}) ->
        case Validator of
            nil -> false;
            _ ->
                case maps:is_key(Key, Args) of
                    false -> false;
                    true ->
                        Value = maps:get(Key, Args),
                        case Validator(Value) of
                            ok -> false;
                            {error, Reason} -> {true, {Key, Reason}}
                        end
                end
        end
    end, Schema),
    case Errors of
        [] -> ok;
        _ -> {error, <<"Validation errors: ", (list_to_binary(string:join([io_lib:format("~s: ~s", [K, R]) || {K, R} <- Errors], ", ")))/binary>>}
    end.

validate_type(binary, Value) -> is_binary(Value);
validate_type(integer, Value) -> is_integer(Value);
validate_type(boolean, Value) -> is_boolean(Value);
validate_type(list, Value) -> is_list(Value);
validate_type(map, Value) -> is_map(Value);
validate_type(_, _) -> true.

validate_path(Path) when is_binary(Path), byte_size(Path) > 0 -> ok;
validate_path(_) -> {error, <<"Path must be a non-empty string">>}.

validate_nonempty(Val) when is_binary(Val), byte_size(Val) > 0 -> ok;
validate_nonempty(_) -> {error, <<"Value must be a non-empty string">>}.

validate_positive(N) when is_integer(N), N > 0 -> ok;
validate_positive(_) -> {error, <<"Value must be a positive integer">>}.