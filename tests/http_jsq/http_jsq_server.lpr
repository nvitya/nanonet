(*-----------------------------------------------------------------------------
  Copyright (c) 2025 Viktor Nagy, nvitya

  This code is released into the public domain.
  You may use it for any purpose, without restriction.
  ---------------------------------------------------------------------------
  file:     http_jsq_server.lpr
  brief:    Simple http server example with JS data query
            from a sqlite3 local database
*)
program http_jsq_server;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX} cthreads {$ENDIF}, baseunix,
  SysUtils, DateUtils, sqlite3conn, db, sqldb, jsontools,
  util_generic, nano_sockets, nano_http, nano_jsq;

const
  http_listen_port = 8080;

type

  { TSConnHttpApp }

  TSConnHttpApp = class(TSConnHttp)
  public
    constructor Create(aserver : TNanoServer); override;

    procedure Handle_status();
    procedure Handle_counter();

    function ProcessRequest() : boolean; override;
  end;


  { THttpServerApp }

  THttpServerApp = class(TNanoHttpServer)
  public
    counter : integer;

    ldbconn   : TSQLite3Connection;
    lsql      : TSQLQuery;
    lsqltra   : TSQLTransaction;

    jsq    : TNanoJsq;

    constructor Create(alisten_port : uint16); reintroduce;

    procedure OpenDatabase;
    procedure Handle_sensors(sconn : TSConnHttpApp);
    procedure Handle_sensordata(sconn : TSConnHttpApp);
  end;

var
  svrapp : THttpServerApp;

{ TSConnHttpApp }

constructor TSConnHttpApp.Create(aserver : TNanoServer);
begin
  inherited Create(aserver);
end;

procedure TSConnHttpApp.Handle_status();
begin
  response := '{"error":0,"errormsg":"","data":{'
    +'"status": "This is some status text"'
    +'}}';

  //v := getvars.KeyDataDef('a', '');
end;

procedure TSConnHttpApp.Handle_counter();
begin
  inc(svrapp.counter);
  response := '{"error":0,"errormsg":"","data":{'
    +'"counter":'+IntToStr(svrapp.counter)
    +'}}';
end;

function GetTs() : string;
begin
  result := FormatDateTime('yyyy-mm-dd hh:nn:ss', now);
end;

function TSConnHttpApp.ProcessRequest() : boolean;
begin
  if uri = '/' then uri := '/index.html';

  result := true;

  // handle internal pages
  try

    if      '/data/status'  = uri then  Handle_status()
    else if '/data/counter' = uri then  Handle_counter()
    else if '/data/sensors' = uri then  svrapp.Handle_sensors(self)
    else if '/data/sensordata' = uri then  svrapp.Handle_sensordata(self)
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

{ THttpServerApp }

constructor THttpServerApp.Create(alisten_port : uint16);
begin
  inherited Create(TSConnHttpApp, alisten_port);

  jsq := nil;
  counter := 0;
end;

procedure THttpServerApp.OpenDatabase;
begin
  ldbconn := TSQLite3Connection.Create(nil);
  lsqltra := TSQLTransaction.Create(nil);
  lsql    := TSQLQuery.Create(nil);

  ldbconn.Transaction := lsqltra;
  lsql.DataBase := ldbconn;
  lsql.Transaction := lsqltra;

  ldbconn.DatabaseName := 'sensorlogger.db';
  ldbconn.OpenFlags := [sofReadWrite, sofFullMutex];

  ldbconn.Open;

  jsq := TNanoJsq.Create(lsql);
end;

procedure THttpServerApp.Handle_sensors(sconn : TSConnHttpApp);
begin
  jsq.ReturnSqlData(sconn, 'select * from MTYPES');
end;

procedure THttpServerApp.Handle_sensordata(sconn : TSConnHttpApp);
begin
  // example for embedding complex queries in a readable way:

  jsq.ReturnSqlData(sconn, String.Join(LineEnding,
  [
    'select '
   ,'  *'
   ,'from'
   ,'  MDATA'
   ,'limit'
   ,'  10'
  ]));
end;

//--------------------------------------------------------------------------------

var
  console_text_buf : array[0..255] of byte;

procedure MainProc;
begin
  InitExceptionsLineInfo;

  // disable console buffering:
  console_text_buf[0] := 0;
  SetTextBuf(output, console_text_buf[0], 1);

  writeln('NanoNet - HTTP JS Query Server');

  svrapp := THttpServerApp.Create(http_listen_port);
  svrapp.OpenDatabase;

  svrapp.InitListener;  // may raise an exception when the listener port is not available

  writeln('Server listening at port ', svrapp.listen_port);

  writeln('Entering main loop...');

  while True do
  begin
    try
      svrapp.WaitForEvents(1000);

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

