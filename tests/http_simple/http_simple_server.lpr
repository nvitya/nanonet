(*-----------------------------------------------------------------------------
  Copyright (c) 2025 Viktor Nagy, nvitya

  This code is released into the public domain.
  You may use it for any purpose, without restriction.
  ---------------------------------------------------------------------------
  file:     http_simple_server.lpr
  brief:    Very simple http server with dynamically generated content
            and demonstrating some get arguments processing
*)
program http_simple_server;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX} cthreads {$ENDIF}, baseunix, nano_sockets, nano_http;

const
  http_listen_port = 8080;

type

  { TSConnHttpApp }

  TSConnHttpApp = class(TSConnHttp)
  public
    constructor Create(aserver : TNanoServer); override;

    function ProcessRequest() : boolean; override;
  end;

{ TSConnHttpApp }

constructor TSConnHttpApp.Create(aserver : TNanoServer);
begin
  inherited Create(aserver);
end;

function TSConnHttpApp.ProcessRequest() : boolean;
var
  i : integer;
  k, v : ansistring;
begin
  if (uri = '/') or (uri = '/index.html') then
  begin
    response := 'This is my plain text http response.'+#13#10
      +'uri="'+uri+'"'#13#10
      +'getstr="'+getstr+'"'#13#10
    ;

    for i := 0 to qsvars.count - 1 do
    begin
      k := qsvars.Keys[i];
      v := qsvars.Data[i];
      response += 'GetVar: "'+k+'" = "'+v+'"'#13#10;
    end;

    v := QsVarStr('a', '', 32);  // limit the variable length to defend against SQL injections
    if v <> '' then response += 'Get var "a" is set to "'+v+'"'#13#10;

    v := QsVarStr('c', '', 32);
    if v <> '' then response += 'Get var "c" is set to "'+v+'"'#13#10
               else response += 'Get var "c" is not set.'#13#10;

    result := true;
  end
  else
  begin
    result := false;
  end;
end;

//--------------------------------------------------------------------------------

var
  svr : TNanoHttpServer;

procedure MainProc;
begin
  writeln('NanoNet - Simple Http Server');

  svr := TNanoHttpServer.Create(TSConnHttpApp, http_listen_port);

  svr.InitListener;  // may raise an exception when the listener port is not available

  writeln('Server listening at port ', svr.listen_port);
  writeln('Entering main loop...');

  while True do
  begin
    svr.WaitForEvents(1000);

    // you can do something else here
  end;
end;

begin
  MainProc;
end.

