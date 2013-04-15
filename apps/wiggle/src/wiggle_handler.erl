-module(wiggle_handler).

-export([
         initial_state/1,
         accepted/0,
         decode/1
        ]).

-record(state, {path, method, version, token, content, reply, obj, body}).

initial_state(Req) ->
    {Method, Req0} = cowboy_req:method(Req),
    {Version, Req1} = cowboy_req:path_info(Req0),
    {Path, Req2} = cowboy_req:path_info(Req1),
    Req3 = cowboy_req:set_resp_header(<<"access-control-allow-origin">>, <<"*">>, Req2),
    {Token, Req4} = case cowboy_req:header(<<"x-snarl-token">>, Req3) of
                        {undefined, ReqX} ->
                            {TokenX, ReqX1} = cowboy_req:cookie(<<"x-snarl-token">>, ReqX),
                            {TokenX, ReqX1};
                        {TokenX, ReqX} ->
                            ReqX1 = cowboy_req:set_resp_header(<<"x-snarl-token">>, TokenX, ReqX),
                            {TokenX, ReqX1}
                    end,
    Req5 = cowboy_req:set_resp_header(
             <<"access-control-allow-headers">>,
             <<"content-type, x-snarl-token">>, Req4),
    Req6 = cowboy_req:set_resp_header(
             <<"access-control-expose-headers">>,
             <<"x-snarl-token">>, Req5),
    Req7 = cowboy_req:set_resp_header(
             <<"allow-access-control-credentials">>,
             <<"true">>, Req6),
    State =  #state{version = Version,
                    method = Method,
                    token = Token,
                    path = Path},
    io:format("[~p] - ~p~n", [Method, Path]),
    {ok, Req7, State}.

accepted() ->
    [
     {<<"application/x-msgpack; charset=UTF-8">>, from_msgpack},
     {<<"application/x-msgpack; charset=utf-8">>, from_msgpack},
     {<<"application/x-msgpack;charset=utf-8">>, from_msgpack},
     {<<"application/x-msgpack; charset=UTF-8">>, from_msgpack},
     {<<"application/x-msgpack">>, from_msgpack},
     {<<"application/json; charset=UTF-8">>, from_json},
     {<<"application/json; charset=utf-8">>, from_json},
     {<<"application/json;charset=UTF-8">>, from_json},
     {<<"application/json;charset=utf-8">>, from_json},
     {<<"application/json">>, from_json}
    ].

decode(Req) ->
    {ContentType, Req0} =
        cowboy_req:header(<<"content-type">>, Req, {<<"application">>, <<"json">>, []}),
    {ok, Body, Req1} = cowboy_req:body(Req0),
    Decoded = case Body of
                  <<>> ->
                      [];
                  _ ->
                      case lists:keyfind(ContentType, 1, accepted()) of
                          {_, from_json} ->
                              jsxd:from_list(jsx:decode(Body));
                          {_, from_msgpack} ->
                              {ok, D} = msgpack:unpack(Body, [jsx]),
                              jsxd:from_list(D)
                      end
              end,
    {ok, Decoded, Req1}.
