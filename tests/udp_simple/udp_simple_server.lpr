(*-----------------------------------------------------------------------------
  Copyright (c) 2025 Viktor Nagy, nvitya

  This code is released into the public domain.
  You may use it for any purpose, without restriction.
  ---------------------------------------------------------------------------
  file:     udp_simple_server.lpr
  brief:    Simple UDP server, use it with the udp_simple_client
*)
program udp_simple_server;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX} cthreads {$ENDIF}, baseunix, nano_sockets;

type

  TSimpleMsgRec = record
    rqid       : uint32;
    operation  : uint32;    // 0 = add, 1 = multiply
    arg1       : integer;
    arg2       : integer;
    result     : integer;
  end;
  PSimpleMsgRec = ^TSimpleMsgRec;

  { TSimpleDatagram }

  TSimpleDatagram = class(TNanoDatagram)
  public
    pmsg : PSimpleMsgRec;

    constructor Create(aserver : TNanoUdpServer); override;

    procedure ProcessInData(); override;
  end;

var
  rspmsg : TSimpleDatagram;
  svr    : TNanoUdpServer;

{ TSimpleDatagram }

constructor TSimpleDatagram.Create(aserver : TNanoUdpServer);
begin
  inherited Create(aserver);
  pmsg := PSimpleMsgRec(@rawdata[0]);
  rawdata_len := sizeof(rawdata);
end;

procedure TSimpleDatagram.ProcessInData();
var
  r : integer;
begin
  //writeln('Msg received from ',GetRemoteAddrStr(),', len = ', rawdata_len);

  rspmsg.pmsg^ := pmsg^;  // copy the request

  if pmsg^.operation = 1 then
  begin
    r := pmsg^.arg1 * pmsg^.arg2;
  end
  else
  begin
    r := pmsg^.arg1 + pmsg^.arg2;
  end;
  rspmsg.pmsg^.result := r;

  rspmsg.remote_addr := remote_addr;
  rspmsg.SendRawData();
end;

//--------------------------------------------------------------------------------

procedure MainProc;
begin
  writeln('NanoNet - UDP Simple Server');

  svr := TNanoUdpServer.Create(TSimpleDatagram, 4455);

  svr.InitListener;  // may raise an exception when the listener port is not available
  rspmsg := TSimpleDatagram(svr.CreateDatagram);

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

