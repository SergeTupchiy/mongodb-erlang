%%%-------------------------------------------------------------------
%%% @author tihon
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 30. Дек. 2014 22:54
%%%-------------------------------------------------------------------
-module(mc_utils).
-author("tihon").

-define(ALLOWED_CHARS, {65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89,
  90, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115,
  116, 117, 118, 119, 120, 121, 122, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57}).

%% API
-export([
  get_value/2,
  get_value/3,
  value_to_binary/1,
  pw_key/3,
  pw_hash/2,
  get_timeout/0,
  encode_name/1,
  random_binary/1,
  hmac/2,
  is_proplist/1,
  to_binary/1,
  use_legacy_protocol/1,
  get_connection_pid/1]).

get_value(Key, List) -> get_value(Key, List, undefined).

get_value(Key, List, Default) ->
  case lists:keyfind(Key, 1, List) of
    {_, Value} -> Value;
    false -> Default
  end.

-spec is_proplist(list() | any()) -> boolean().
is_proplist(List) ->
  Check = fun({X, _}) when is_atom(X) -> true;(_) -> false end,
  lists:all(Check, List).

-spec encode_name(binary()) -> binary().
encode_name(Name) ->
  Comma = re:replace(Name, <<"=">>, <<"=3D">>, [{return, binary}]),
  re:replace(Comma, <<",">>, <<"=2C">>, [{return, binary}]).

-spec random_binary(integer()) -> binary().
random_binary(Length) ->
  rand:seed(exsplus, os:timestamp()),
  Chrs = ?ALLOWED_CHARS,
  ChrsSize = size(Chrs),
  F = fun(_, R) -> [element(rand:uniform(ChrsSize), Chrs) | R] end,
  list_to_binary(lists:foldl(F, "", lists:seq(1, Length))).

value_to_binary(Value) when is_integer(Value) ->
  bson:utf8(integer_to_list(Value));
value_to_binary(Value) when is_atom(Value) ->
  atom_to_binary(Value, utf8);
value_to_binary(Value) when is_binary(Value) ->
  Value;
value_to_binary(_Value) ->
  <<>>.

get_timeout() ->
  case application:get_env(mc_worker_call_timeout) of
    {ok, Time} -> Time;
    undefined -> infinity
  end.

use_legacy_protocol(Connection) ->
    %% Latest MongoDB version that supported the non-op-msg based protocol was
    %% 5.0.x (at the time of writing 5.0.14). The non-op-msg based protocol was
    %% removed in MongoDB version 5.1.0. See
    %% https://www.mongodb.com/docs/manual/legacy-opcodes/
    case mc_worker_pid_info:get_protocol_type(Connection) of
        legacy ->
            true;
        op_msg ->
            false
    end.

get_connection_pid(Connection) when is_pid(Connection) ->
    Connection;
get_connection_pid(#{connection_pid := Pid}) ->
    Pid.


hmac(One, Two) -> crypto:mac(hmac, sha, One, Two).

pw_key(Nonce, Username, Password) ->
  bson:utf8(binary_to_hexstr(crypto:hash(md5, [Nonce, Username, pw_hash(Username, Password)]))).

pw_hash(Username, Password) ->
  bson:utf8(binary_to_hexstr(crypto:hash(md5, [Username, <<":mongo:">>, unwrap(Password)]))).

-spec to_binary(string() | binary()) -> binary().
to_binary(Str) when is_list(Str) ->  list_to_binary(Str);
to_binary(Str) when is_binary(Str) ->  Str.


%% @private
binary_to_hexstr(Bin) ->
  lists:flatten([io_lib:format("~2.16.0b", [X]) || X <- binary_to_list(Bin)]).

unwrap(Term) when is_function(Term, 0) ->
    %% Handle potentially nested funs
    unwrap(Term());
unwrap(Term) ->
    Term.
