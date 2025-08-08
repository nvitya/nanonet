(*-----------------------------------------------------------------------------
  Copyright (c) 2025 Viktor Nagy, nvitya

  This code is released into the public domain.
  You may use it for any purpose, without restriction.
  ---------------------------------------------------------------------------
  file:     simplebin_server.lpr
  brief:    Demo and not so useful server application
            connect to the 4444 port with telnet and the sent
            data will be printed into the console.
*)
program simplebin_server;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,
  nano_sockets;

type
  { TSConnectionSimple }

  TSConnectionSimple = class(TSConnection)  // Servers connection to client
  public
    inbuf  : ansistring;

    indata : ansistring;

    constructor Create(aserver : TNanoServer); override;
    destructor Destroy; override;

    procedure HandleInput(aobj : TObject); override;
    procedure ProcessInData; virtual;
  end;

{ TSConnectionSimple }

constructor TSConnectionSimple.Create(aserver : TNanoServer);
begin
  inherited;
  indata := '';
  SetLength(inbuf, 4096);
end;

destructor TSConnectionSimple.Destroy;
begin
  indata := '';
  SetLength(inbuf, 0);
  inherited Destroy;
end;

procedure TSConnectionSimple.HandleInput(aobj : TObject);
var
  r : integer;
begin
  r := sock.Recv(inbuf[1], length(inbuf));
  if r > 0 then
  begin
    indata := copy(inbuf, 1, r);
    ProcessInData;
  end
  else if r = 0 then
  begin
    // the socket is closed !
    server.CloseConnection(self);  // this connection is scheduled for removal, safe freeing in other context
  end
  else
  begin
    // ignore errors
  end;
end;

procedure TSConnectionSimple.ProcessInData;
begin
  // the overridden function should do something more useful with the indata...
  writeln('<- "',indata,'"');
end;

//--------------------------------------------------------------------------------------------------

var
  svr : TNanoServer;

procedure MainProc;
begin
  writeln('NanoNet - SimpleBin Server');
  svr := TNanoServer.Create(TSConnectionSimple, 4444);

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

