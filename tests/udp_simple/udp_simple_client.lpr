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
    rq_send_microtime : int64;

    pmsg : PSimpleMsgRec;

    constructor Create(aserver : TNanoUdpServer); override;

    procedure ProcessInData(); override;

    procedure SendRequest(aop, aarg1, aarg2 : integer);
    function WaitResponse(atimeout_ms : integer) : boolean;
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
  rq_send_microtime := microtime();
end;

function TSimpleDatagram.WaitResponse(atimeout_ms : integer) : boolean;
var
  td, t : int64;
  to_ms : integer;
begin
  result := false;
  td := rq_send_microtime + atimeout_ms * 1000;
  while not response_arrived do
  begin
    t := microtime();
    to_ms := (td - t) div 1000;  // the remaining time to wait for the response
    if to_ms <= 0 then
    begin
      EXIT; // timeout elapsed
    end;
    server.WaitForEvents(to_ms);    // may receive multiple unrelated packets too
  end;
  result := true;
end;


//--------------------------------------------------------------------------------

procedure MainProc;
begin
  writeln('NanoNet - UDP Simple Client');

  svr := TNanoUdpServer.Create(TSimpleDatagram, 0);  // UDP server for receiving the responses, port=0: auto-allocate
  svr.InitListener;
  rqmsg := TSimpleDatagram(svr.CreateDatagram);
  rqmsg.SetRemoteAddr(server_address, 4455);

  writeln('Listening at port ', svr.listen_port);

  writeln('Sending request...');

  rqmsg.SendRequest(1, 3, 2);
  //writeln('Waiting for the response...');
  if not rqmsg.WaitResponse(500) then
  begin
    writeln('Response timeout!');
  end;

  rqmsg.SendRequest(0, 3, 2);
  if not rqmsg.WaitResponse(500) then
  begin
    writeln('Response timeout!');
  end;


  writeln('test finished.');
end;

begin
  MainProc;
end.

