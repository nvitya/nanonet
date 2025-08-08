(*-----------------------------------------------------------------------------
  Copyright (c) 2025 Viktor Nagy, nvitya

  This code is released into the public domain.
  You may use it for any purpose, without restriction.
  ---------------------------------------------------------------------------
  file:     binecho_client.lpr
  brief:    Simple binary echo client with performance measurements
            use it with the binecho_server
*)
program binecho_client;

{$mode objfpc}{$H+}

{ Protocol:

header:
  bodylength : uint32;  // in bytes
  rqid       : uint32;
data:
  n * byte;
}

uses
  {$IFDEF UNIX} cthreads {$ENDIF}, SysUtils,
  nano_sockets, util_microtime;

const
  //tx_msg_dwords = 16;
  tx_msg_dwords = 4096 * 4;
  //tx_msg_dwords = 140000 div 4;

  client_count = 4;
  //echo_server_address = '192.168.0.87'; //'127.0.0.1';
  echo_server_address = '127.0.0.1';
  //echo_server_address = '192.168.0.140';
  //echo_server_address = '192.168.0.42';
  //echo_server_address = '192.168.0.49';

type

  TEchoHeader = record
    bodylength : uint32;
    rqid       : uint32;
  end;
  PEchoHeader = ^TEchoHeader;

  TConnectionStats = record
    tx_bytes   : uint32;
    rx_bytes   : uint32;

    tx_msg     : uint32;
    rx_msg     : uint32;
  end;
  PConnectionStats = ^TConnectionStats;

  { TCConnBinEcho }

  TCConnBinEcho = class(TCConnection)
  public

    msgdwords : uint32;
    msg_seed  : uint32;

    inbuf     : array of byte;
    outbuf    : array of byte;

    infill    : uint32;
    outfill   : uint32;

    phase     : integer;

    pstats    : PConnectionStats;

    constructor Create(amgr : TMultiClientMgr); override;

    procedure HandleInput(aobj : TObject); override;
    procedure HandleOutput(aobj : TObject); override;

    procedure SendMessage;
    procedure AddToOutput(const adata; alen : uint32);

    procedure ProcessInData();
    procedure ProcessInMsg();
    procedure SendOutput();

  end;

  { TEchoConnManager }

  TEchoConnManager = class(TMultiClientMgr)
  public
    last_stat_time : int64;

    stats      : TConnectionStats;
    prev_stats : TConnectionStats;

    constructor Create; override;

    procedure PrintStats;
  end;

constructor TEchoConnManager.Create;
begin
  inherited Create;

  last_stat_time := microtime();
end;

procedure TEchoConnManager.PrintStats;
var
  dt : TDateTime;
  mt : int64;
  v  : uint32;
begin
  mt := microtime();
  if mt - last_stat_time < 1000000 then EXIT;

  dt := now;
  write(FormatDateTime('hh:nn:ss:', dt));

  v := stats.tx_bytes - prev_stats.tx_bytes;
  if v > 0 then
  begin
    write(' TX_BYTES=', v);
  end;

  v := stats.rx_bytes - prev_stats.rx_bytes;
  if v > 0 then
  begin
    write(' RX_BYTES=', v);
  end;

  v := stats.tx_msg - prev_stats.tx_msg;
  if v > 0 then
  begin
    write(' TX_MSG=', v);
  end;

  v := stats.rx_msg - prev_stats.rx_msg;
  if v > 0 then
  begin
    write(' RX_MSG=', v);
  end;

  writeln;

  prev_stats := stats;

  last_stat_time := mt;
end;

{ TCConnBinEcho }

constructor TCConnBinEcho.Create(amgr : TMultiClientMgr);
var
  bufsize : uint32;
begin
  inherited Create(amgr);

  server_port := 4488;
  server_addr := '127.0.0.1';

  msgdwords := tx_msg_dwords;

  bufsize := 4096;
  if bufsize < 64 + 4 * msgdwords then bufsize := 4 * msgdwords + 64;

  SetLength(inbuf, bufsize);
  SetLength(outbuf, bufsize);

  infill := 0;
  outfill := 0;

  msg_seed := 1;
  phase := 0;

  pstats := @TEchoConnManager(amgr).stats;
end;

procedure TCConnBinEcho.HandleInput(aobj : TObject);  // called when the socket has some input data
var
  r : integer;
begin
  // do not call inherited.

  if length(inbuf)-infill < 4096 then SetLength(inbuf, length(inbuf) * 2);  // double the inbuf

  r := sock.Recv(inbuf[infill], length(inbuf)-infill);
  if r > 0 then
  begin
    pstats^.rx_bytes += r;
    //writeln('Input chunk arrived, len=', r);
    infill += r;
    ProcessInData();
  end
  else if r = 0 then
  begin
    // the socket is closed !
    raise ENanoNet.Create('implement socket close!');
    //server.CloseConnection(self);  // this connection is scheduled for removal, safe freeing in other context
  end
  else
  begin
    // ignore errors
  end;
end;

procedure TCConnBinEcho.HandleOutput(aobj : TObject);  // called when the socket is ready to send more output
begin
  if outfill = 0 then
  begin
    SendMessage;
    EXIT;
  end;

  //writeln('continue sending, outfill=', outfill);

  SendOutput();
end;

procedure TCConnBinEcho.SendMessage;
var
  msg : array of uint32 = ();
  eh : TEchoHeader;
  n : uint32;
begin
  //writeln('Sending msg ', msg_seed);

  eh.bodylength := msgdwords * 4;
  eh.rqid := msg_seed;
  AddToOutput(eh, sizeof(eh));

  setlength(msg, msgdwords);
  for n := 0 to msgdwords - 1 do msg[n] := msg_seed + 1 + n;
  AddToOutput(msg[0], 4 * msgdwords);

  SendOutput;

  pstats^.tx_msg += 1;

  inc(msg_seed);
end;

procedure TCConnBinEcho.AddToOutput(const adata; alen : uint32);
begin
  if alen > outfill + length(outbuf) then EXIT;

  move(adata, outbuf[outfill], alen);
  outfill += alen;

  pstats^.tx_bytes += alen;
end;

procedure TCConnBinEcho.ProcessInData();
var
  ph : PEchoHeader;
  fullmsglen : uint32;

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
  //Writeln('echo arrived, id=', ph^.rqid, ', len=', ph^.bodylength);
  ProcessInMsg();

  // Remove this message from the inbuf
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

  // send another message...
{$if true}
  SendMessage;
{$else}
  if msg_seed < 5 then
  begin
    SendMessage;
  end
  else
  begin
    writeln('this is enough for now.');
    //halt(4);
  end;
{$endif}
end;

procedure TCConnBinEcho.ProcessInMsg();
begin
  pstats^.rx_msg += 1;
end;

procedure TCConnBinEcho.SendOutput();
var
  r : integer;
begin
  if outfill > 0 then
  begin
    r := sock.Send(outbuf[0], outfill);
    if r > 0 then
    begin
      //writeln('chunk sent, len=', r);
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

{ TEchoConnManager }

//--------------------------------------------------------------------------------

var
  mgr : TEchoConnManager;

procedure MainProc;
var
  c : TCConnBinEcho;
  n : integer;
begin
  writeln('NanoNet - BinEcho Multi-Client');
  mgr := TEchoConnManager.Create;

  //svr.InitListener;  // may raise an exception when the listener port is not available
  //writeln('Server listening at port ', svr.listen_port);

  writeln('client count: ', client_count);
  writeln('msg_size: ', tx_msg_dwords + sizeof(TEchoHeader));

  for n := 1 to client_count do
  begin
    c := TCConnBinEcho.Create(mgr);

    c.server_addr := echo_server_address;
    //c.server_port := 8765;
    c.Connect;
  end;

  writeln('Entering main loop...');

  //writeln('so far so good.');  halt(1);

  while True do
  begin
    mgr.WaitForEvents(250);

    // you can do something else here
    mgr.PrintStats;
  end;
end;

begin
  MainProc;
end.

