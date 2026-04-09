-module(coding_agent_ansi).
-export([color/2, reset/0, strip/1]).
-export([bold/1, dim/1, underline/1]).
-export([black/1, red/1, green/1, yellow/1, blue/1, magenta/1, cyan/1, white/1]).
-export([bright_red/1, bright_green/1, bright_yellow/1, bright_blue/1, bright_magenta/1, bright_cyan/1, bright_white/1]).
-export([bg_red/1, bg_green/1, bg_yellow/1, bg_blue/1, bg_magenta/1, bg_cyan/1, bg_white/1]).
-export([clear_line/0, cursor_up/1, cursor_down/1, save_cursor/0, restore_cursor/0]).

%% ANSI escape code helpers with NO_COLOR support.
%% If NO_COLOR is set (per https://no-color.org/), all functions
%% return the text unchanged.

-define(ESC, "\e[").
-define(RESET, "\e[0m").

%% @doc Ensure Text is a list (string) so ++ concatenation works.
ensure_list(Text) when is_binary(Text) -> binary_to_list(Text);
ensure_list(Text) when is_list(Text) -> Text;
ensure_list(Text) when is_atom(Text) -> atom_to_list(Text);
ensure_list(Text) -> lists:flatten(io_lib:format("~p", [Text])).

%% @doc Check if color should be suppressed.
no_color() ->
    os:getenv("NO_COLOR") =/= false.

%% @doc Wrap Text with raw ANSI codes (Code can be e.g. "1;36").
color(Code, Text) ->
    TextList = ensure_list(Text),
    case no_color() of
        true -> TextList;
        false -> ?ESC ++ Code ++ "m" ++ TextList ++ ?RESET
    end.

%% @doc Return the ANSI reset sequence (or empty if NO_COLOR).
reset() ->
    case no_color() of
        true  -> "";
        false -> ?RESET
    end.

%% --- Cursor movement (respect NO_COLOR) -----------------------------

clear_line() ->
    case no_color() of
        true  -> "";
        false -> "\e[2K\r"
    end.

cursor_up(N) when is_integer(N), N > 0 ->
    case no_color() of
        true  -> "";
        false -> "\e[" ++ integer_to_list(N) ++ "A"
    end;
cursor_up(_) -> "".

cursor_down(N) when is_integer(N), N > 0 ->
    case no_color() of
        true  -> "";
        false -> "\e[" ++ integer_to_list(N) ++ "B"
    end;
cursor_down(_) -> "".

save_cursor() ->
    case no_color() of
        true  -> "";
        false -> "\e[s"
    end.

restore_cursor() ->
    case no_color() of
        true  -> "";
        false -> "\e[u"
    end.

%% --- Stripping ---------------------------------------------------------

%% @doc Remove all ANSI escape sequences from a binary or string.
strip(String) when is_binary(String) ->
    iolist_to_binary(strip(binary_to_list(String)));
strip(String) when is_list(String) ->
    re:replace(String, "\e\\[[0-9;]*[a-zA-Z]", "", [global, {return, list}]).

%% --- Basic styles -------------------------------------------------------

bold(Text)      -> color("1", Text).
dim(Text)       -> color("2", Text).
underline(Text) -> color("4", Text).

%% --- Standard colors (FG) -----------------------------------------------

black(Text)   -> color("30", Text).
red(Text)     -> color("31", Text).
green(Text)   -> color("32", Text).
yellow(Text)  -> color("33", Text).
blue(Text)    -> color("34", Text).
magenta(Text) -> color("35", Text).
cyan(Text)    -> color("36", Text).
white(Text)   -> color("37", Text).

%% --- Bright / bold colors (FG) ------------------------------------------

bright_red(Text)     -> color("1;31", Text).
bright_green(Text)   -> color("1;32", Text).
bright_yellow(Text)  -> color("1;33", Text).
bright_blue(Text)    -> color("1;34", Text).
bright_magenta(Text) -> color("1;35", Text).
bright_cyan(Text)    -> color("1;36", Text).
bright_white(Text)   -> color("1;37", Text).

%% --- Background colors ---------------------------------------------------

bg_red(Text)     -> color("41", Text).
bg_green(Text)   -> color("42", Text).
bg_yellow(Text)  -> color("43", Text).
bg_blue(Text)    -> color("44", Text).
bg_magenta(Text) -> color("45", Text).
bg_cyan(Text)    -> color("46", Text).
bg_white(Text)   -> color("47", Text).
