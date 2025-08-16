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
  {$IFDEF UNIX} cthreads {$ENDIF}, SysUtils, baseunix, util_generic, nano_sockets, nano_http;

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

function GetTs() : string;
begin
  result := FormatDateTime('yyyy-mm-dd hh:nn:ss', now);
end;

function TSConnHttpApp.ProcessRequest() : boolean;
var
  i : integer;
  k, v : ansistring;
  pb : PByte;
begin

  try

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

      pb := nil;
      Writeln('this causes an exception:' , pb^);

      result := true;
      EXIT;
    end;

  except
    on e : Exception do
    begin
      writeln();
      writeln(GetTs()+': ERROR at "',url,'"');
      writeln(e.ToString);

      // print stack trace with line infos
      writeln('Backtrace:');
      writeln('  '+GetLastExceptionCallStack('WaitForEvents')); // stop backtracing at nanonet/WaitForEvents
    end;
  end;

  result := false;
end;

//--------------------------------------------------------------------------------

var
  svr : TNanoHttpServer;

  console_text_buf : array[0..255] of byte;

procedure MainProc;
begin
  // disable console buffering:
  console_text_buf[0] := 0;
  SetTextBuf(output, console_text_buf[0], 1);

  InitExceptionsLineInfo;

  writeln('NanoNet - Simple Http Server');

  svr := TNanoHttpServer.Create(TSConnHttpApp, http_listen_port);

  svr.InitListener;  // may raise an exception when the listener port is not available

  writeln('Server listening at port ', svr.listen_port);
  writeln('Entering main loop...');

  while True do
  begin
    try
      svr.WaitForEvents(1000);

     // you can do something else here

    except // catch all other exceptions here to allow the server running further
      on e : Exception do
      begin
        writeln();
        writeln(GetTs()+': ERROR');
        writeln(e.ToString);

        // print stack trace with line infos
        writeln('Backtrace:');
        writeln('  '+GetLastExceptionCallStack('x'));
      end;
    end;

  end;
end;

begin
  MainProc;
end.

