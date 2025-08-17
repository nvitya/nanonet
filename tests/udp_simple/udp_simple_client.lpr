(*-----------------------------------------------------------------------------
  Copyright (c) 2025 Viktor Nagy, nvitya

  This code is released into the public domain.
  You may use it for any purpose, without restriction.
  ---------------------------------------------------------------------------
  file:     udp_simple_client.lpr
  brief:    Simple UDP client
            use it with the simple_udp_server
*)
program udp_simple_client;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX} cthreads {$ENDIF}, SysUtils,
  nano_sockets, util_microtime;

const
  server_address = '127.0.0.1';
  //echo_server_address = '192.168.0.140';

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
    response_arrived : boolean;

    pmsg : PSimpleMsgRec;

    constructor Create(aserver : TNanoUdpServer); override;

    procedure ProcessInData(); override;

    procedure SendRequest(aop, aarg1, aarg2 : integer);
  end;

var
  rqmsg  : TSimpleDatagram;
  svr    : TNanoUdpServer;

{ TSimpleDatagram }

constructor TSimpleDatagram.Create(aserver : TNanoUdpServer);
begin
  inherited Create(aserver);
  rawdata_len := sizeof(TSimpleMsgRec);
  pmsg := PSimpleMsgRec(@rawdata[0]);
  pmsg^.rqid := 0;
  pmsg^.result := -1;
  response_arrived := false;
end;

procedure TSimpleDatagram.ProcessInData();
begin
  writeln('Response received:');
  writeln('  rqid = ', pmsg^.rqid);
  writeln('  op   = ', pmsg^.operation);
  writeln('  arg1 = ', pmsg^.arg1);
  writeln('  arg2 = ', pmsg^.arg2);
  writeln('  res. = ', pmsg^.result);

  if pmsg^.rqid = rqmsg.pmsg^.rqid then
  begin
    rqmsg.response_arrived := true;
  end;
end;

procedure TSimpleDatagram.SendRequest(aop, aarg1, aarg2 : integer);
begin
  Inc(pmsg^.rqid);
  pmsg^.operation := aop;
  pmsg^.arg1 := aarg1;
  pmsg^.arg2 := aarg2;

  response_arrived := false;

  SendRawData();
end;


//--------------------------------------------------------------------------------

procedure MainProc;
begin
  writeln('NanoNet - UDP Simple Client');

  svr := TNanoUdpServer.Create(TSimpleDatagram, 4466);  // UDP server for receiving the responses
  svr.InitListener;
  rqmsg := TSimpleDatagram(svr.CreateDatagram);
  rqmsg.SetRemoteAddr(server_address, 4455);

  writeln('Listening at port ', svr.listen_port);

  writeln('Sending request...');

  rqmsg.SendRequest(0, 3, 2);

  writeln('Waiting for the response...');

  svr.WaitForEvents(1000);

  if not rqmsg.response_arrived then
  begin
    writeln('Response timeout!');
  end;

  writeln('test finished.');
end;

begin
  MainProc;
end.

