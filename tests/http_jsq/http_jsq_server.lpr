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
  nano_sockets, nano_http;

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

    constructor Create(alisten_port : uint16); reintroduce;

    procedure OpenDatabase;
    procedure Handle_sensors(sconn : TSConnHttpApp);
    procedure Handle_sensordata(sconn : TSConnHttpApp);

    procedure ReturnSqlData(sconn : TSConnHttpApp; asql : string);
  end;

var
  svrapp : THttpServerApp;

{ TSConnHttpApp }

constructor TSConnHttpApp.Create(aserver : TNanoServer);
begin
  inherited Create(aserver);
end;

procedure TSConnHttpApp.Handle_status();
//var
//  k, v : ansistring;
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

function TSConnHttpApp.ProcessRequest() : boolean;
begin
  if uri = '/' then uri := '/index.html';

  // handle internal pages

  result := true;

  if      '/data/status'  = uri then  Handle_status()
  else if '/data/counter' = uri then  Handle_counter()
  else if '/data/sensors' = uri then  svrapp.Handle_sensors(self)
  else if '/data/sensordata' = uri then  svrapp.Handle_sensordata(self)
  else
  begin
    result := HandleStaticFiles('./www');
  end;
end;

{ THttpServerApp }

constructor THttpServerApp.Create(alisten_port : uint16);
begin
  inherited Create(TSConnHttpApp, alisten_port);

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
end;

procedure THttpServerApp.Handle_sensors(sconn : TSConnHttpApp);
begin
  ReturnSqlData(sconn, 'select * from MTYPES');
end;

procedure THttpServerApp.Handle_sensordata(sconn : TSConnHttpApp);
begin
  ReturnSqlData(sconn, 'select * from MDATA limit 10');
end;

procedure THttpServerApp.ReturnSqlData(sconn : TSConnHttpApp; asql : string);
var
  jroot : TJsonNode;
  jdata: TJsonNode;
  jrow : TJsonNode;
  jfnames : TJsonNode;
  f : TField;
  fi : integer;
begin
  jroot := TJsonNode.Create;
  jroot.Add('error', 0);
  jroot.Add('errormsg', '');

  try
    lsql.SQL.Text := asql;
    lsql.Open;
    if not lsql.EOF then
    begin
      jfnames := jroot.Add('fieldnames', nkArray);
      for fi := 0 to lsql.FieldCount - 1 do
      begin
        jfnames.Add('', lsql.Fields[fi].FieldName);
      end;
    end;

    jdata := jroot.Add('data', nkArray);

    while not lsql.EOF do
    begin
      jrow := jdata.Add('', nkArray);
      for fi := 0 to lsql.FieldCount - 1 do
      begin
        f := lsql.Fields[fi];
        if f.DataType in [ftInteger, ftSmallInt, ftWord, ftAutoInc, ftLargeInt] then
        begin
          jrow.Add('', lsql.Fields[fi].AsInteger);
        end
        else if f.DataType in [ftDateTime] then
        begin
          jrow.Add('', FormatDateTime('yyyy-mm-dd hh:nn:ss', lsql.Fields[fi].AsDateTime));
        end
        else if f.DataType = ftBoolean then
        begin
          jrow.Add('', lsql.Fields[fi].AsBoolean);
        end
        else if f.DataType in [ftFloat, ftCurrency, ftBCD] then
        begin
          jrow.Add('', lsql.Fields[fi].AsFloat);
        end
        else  // fallback to string
        begin
          jrow.Add('', lsql.Fields[fi].AsString);
        end;
      end;
      lsql.Next;
    end;
    lsql.Close;
  except
    on e : Exception do
    begin
      lsql.Active := false;
      jroot.Add('data', nkNull);
      jroot.Delete('fieldnames');
      jroot.Add('error', 901);
      jroot.Add('errormsg', e.ToString);
    end;
  end;

  sconn.response := jroot.AsJson;

  jroot.Free;
end;

//--------------------------------------------------------------------------------

procedure MainProc;
begin
  writeln('NanoNet - HTTP JS Query Server');

  svrapp := THttpServerApp.Create(http_listen_port);
  svrapp.OpenDatabase;

  svrapp.InitListener;  // may raise an exception when the listener port is not available

  writeln('Server listening at port ', svrapp.listen_port);

  writeln('Entering main loop...');

  while True do
  begin
    svrapp.WaitForEvents(1000);

    // you can do something else here
  end;
end;

begin
  MainProc;
end.

