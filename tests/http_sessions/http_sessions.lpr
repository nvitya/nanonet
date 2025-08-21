(*-----------------------------------------------------------------------------
  Copyright (c) 2025 Viktor Nagy, nvitya

  This code is released into the public domain.
  You may use it for any purpose, without restriction.
  ---------------------------------------------------------------------------
  file:     http_sessions.lpr
  brief:    Simple http server with simple session handling
*)
program http_sessions;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX} cthreads, baseunix, {$ENDIF}
  SysUtils, DateUtils, jsontools, util_generic,
  nano_sockets, nano_http, nano_sessions;

const
  http_listen_port = 8080;

type

  { TSConnHttpApp }

  TSConnHttpApp = class(TSConnHttp)
  public
    session : TSessionObj;  // not owned by the conn (just linked to the sessionstore), so must not be freed here

    constructor Create(aserver : TNanoServer); override;

    function ProcessRequest() : boolean; override;
  end;

{ TSConnHttpApp }

constructor TSConnHttpApp.Create(aserver : TNanoServer);
begin
  session := nil;
  inherited Create(aserver);
end;

function GetTs() : string;
begin
  result := FormatDateTime('yyyy-mm-dd hh:nn:ss', now);
end;

function TSConnHttpApp.ProcessRequest() : boolean;
var
  jv : TJsonNode;
  rqcounter : integer;
begin
  //writeln('processrq(',uri,')');

  if uri = '/' then uri := '/index.html';

  try
    // handle internal pages

    if uri = '/data' then
    begin
      //writeln('processrq(',uri,'), sid=',session.id);
      session := sessionstore.InitSession(self);

      rqcounter := 0;
      if session.data.Find('RQCOUNTER', jv) then rqcounter := trunc(jv.AsNumber);

      inc(rqcounter);

      response := 'Session data: '+#13#10
        + session.data.Value;

      session.data.Add('RQCOUNTER', rqcounter);

      // only the dynamic requests can change the session data
      sessionstore.SaveSession(session);

      result := true;
    end
    else
    begin
      result := HandleStaticFiles('./www');
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
end;

//--------------------------------------------------------------------------------

var
  svr : TNanoHttpServer;
  console_text_buf : array[0..255] of byte;

procedure MainProc;
begin
  InitExceptionsLineInfo;

  // disable console buffering:
  console_text_buf[0] := 0;
  SetTextBuf(output, console_text_buf[0], 1);

  writeln('NanoNet - Http Sessions Test');

  if not InitJsonFileSessionStore('./sessions', true) then
  begin
    writeln('Error initializing the session store!');
    halt(1);
  end;

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

