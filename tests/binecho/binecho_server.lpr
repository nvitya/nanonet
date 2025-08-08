(*-----------------------------------------------------------------------------
  Copyright (c) 2025 Viktor Nagy, nvitya

  This code is released into the public domain.
  You may use it for any purpose, without restriction.
  ---------------------------------------------------------------------------
  file:     binecho_server.lpr
  brief:    Simple binary echo server, use it with the binecho_client
*)
program binecho_server;

{$mode objfpc}{$H+}

{ Protocol:

header:
  bodylength : uint32;  // in bytes
  rqid       : uint32;
data:
  n * byte;
}

uses
  {$IFDEF UNIX} cthreads {$ENDIF}, baseunix, nano_sockets;

type

  TEchoHeader = record
    bodylength : uint32;
    rqid       : uint32;
  end;
  PEchoHeader = ^TEchoHeader;

  { TSConnBinEcho }

  TSConnBinEcho = class(TSConnection)
  public
    inbuf     : array of byte;
    outbuf    : array of byte;

    infill    : uint32;
    outfill   : uint32;

    constructor Create(aserver : TNanoServer); override;

    procedure HandleInput(aobj : TObject); override;
    procedure HandleOutput(aobj : TObject); override;
    procedure ProcessInData();
    procedure SendOutput();
  end;

{ TSConnectionBinEnco }

constructor TSConnBinEcho.Create(aserver : TNanoServer);
begin
  inherited Create(aserver);

  SetLength(inbuf, 65536);
  SetLength(outbuf, 65536);
  infill := 0;
  outfill := 0;
end;

procedure TSConnBinEcho.HandleInput(aobj : TObject);  // called when the socket has some input data
var
  r : integer;
begin
  // do not call inherited.

  if length(inbuf)-infill < 4096 then SetLength(inbuf, length(inbuf) * 2);  // double the inbuf

  r := sock.Recv(inbuf[infill], length(inbuf)-infill);
  if r > 0 then
  begin
    infill += r;
    ProcessInData();
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

procedure TSConnBinEcho.HandleOutput(aobj : TObject);  // called when the socket is ready to send more output
begin
  SendOutput();
end;

procedure TSConnBinEcho.ProcessInData();
var
  ph : PEchoHeader;
  fullmsglen : uint32;
  newoutsize : uint32;

  label repeat_incheck;
begin

repeat_incheck:

  if infill < sizeof(TEchoHeader) then EXIT;

  // wait a whole request before start sending
  ph := PEchoHeader(@inbuf[0]);
  fullmsglen := sizeof(TEchoHeader) + ph^.bodylength;

  if infill < fullmsglen then
  begin
    // wait until the full message received.
    // todo: handle timeout !
    EXIT;
  end;

  // a full message is present in the inbuf
  //writeln('msg arrived: id=', ph^.rqid, ', len=', ph^.bodylength);

  // 1. ensure that there is enough space in the outbuf
  newoutsize := length(outbuf);
  while newoutsize - outfill < fullmsglen do
  begin
    newoutsize *= 2;
  end;
  if newoutsize <> length(outbuf) then SetLength(outbuf, newoutsize);

  // 2. copy the response into the outbuf
  move(inbuf[0], outbuf[outfill], fullmsglen);
  outfill += fullmsglen;

  // 3. remove this message from the inbuf
  if infill > fullmsglen then
  begin
    move(inbuf[fullmsglen], inbuf[0], infill - fullmsglen);
    infill -= fullmsglen;

    // 3.b repeat the input check for the case multiple requests are present in the input buffer
    if infill > 0 then goto repeat_incheck;
  end
  else
  begin
    infill := 0;
  end;

  // 4. start the output sending
  SendOutput();
end;

procedure TSConnBinEcho.SendOutput();
var
  r : integer;
begin
  if outfill > 0 then
  begin
    r := sock.Send(outbuf[0], outfill);
    if r > 0 then
    begin
      // remove this chunk from the output
      move(outbuf[r], outbuf[0], r);
      outfill -= r;
    end;
  end;

  if outfill > 0 then
  begin
    // some data remained, request HandleOutput()
    SetOutHandler(@self.HandleOutput);
  end
  else
  begin
    // everything is sent, stop requesting HandleOutput()
    SetOutHandler(nil);
  end;
end;

//--------------------------------------------------------------------------------

var
  svr : TNanoServer;

procedure MainProc;
begin
  writeln('NanoNet - BinEcho Server');

  svr := TNanoServer.Create(TSConnBinEcho, 4488);

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

