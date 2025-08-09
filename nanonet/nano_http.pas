(*-----------------------------------------------------------------------------
  This file is a part of the NANONET project: https://github.com/nvitya/nanonet
  Copyright (c) 2025 Viktor Nagy, nvitya

  This software is provided 'as-is', without any express or implied warranty.
  In no event will the authors be held liable for any damages arising from
  the use of this software. Permission is granted to anyone to use this
  software for any purpose, including commercial applications, and to alter
  it and redistribute it freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software in
     a product, an acknowledgment in the product documentation would be
     appreciated but is not required.

  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.

  3. This notice may not be removed or altered from any source distribution.
  ---------------------------------------------------------------------------
   file:     nano_http.pas
   brief:    HTTP Protocol handling
   date:     2025-08-08
   authors:  nvitya
*)

unit nano_http;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fgl, strparseobj, nano_sockets;

const
  HTTPDateFormat : string = 'ddd, dd mmm yyyy hh:nn:ss';

type

  { TAnsiStrMap }

  TAnsiStrMap = class(specialize TFPGMap<ansistring, ansistring>)
  public
    function KeyDataDef(const AKey: ansistring; const ADefValue : ansistring) : ansistring;
  end;


  { TSConnHttp }

  TSConnHttp = class(TSconnection)
  protected
    sp : TStrParseObj; // object, not class. allocated on the stack

    inbuf     : array of byte;
    infill    : uint32;

    outbuf    : ansistring;

    procedure ProcessInData();
    procedure AddHttpOutput();
    procedure ParseGetString();

  public
    header_length : integer;

    method   : ansistring;
    uri      : ansistring;
    url      : ansistring;
    http_ver : ansistring;
    getstr : ansistring;
    keep_alive : boolean;

    full_content_length : int64;
    file_remaining      : int64;
    file_fd : integer;
    fileinfo : TSearchRec;

    procedure CloseFileFd();

  protected
    function ParseRequestHeader() : boolean;
    procedure ParseCookies(astr : ansistring);

  public

    ucheaders  : TAnsiStrMap;  // UpperCase request headers
    getvars    : TAnsiStrMap;
    cookies    : TAnsiStrMap;

    response : ansistring;
    response_code : integer;
    response_headers : TAnsiStrMap;

    constructor Create(aserver : TNanoServer); override;
    destructor Destroy; override;

    procedure HandleInput(aobj : TObject); override;
    procedure HandleOutput(aobj : TObject); override;

    procedure SendOutput();

    procedure PrepareHeaders(); virtual;
    function ProcessRequest() : boolean; virtual;

    function HandleStaticFiles(arootdir : ansistring) : boolean;

    procedure LogError(astr : string); virtual;

  end;

  TSConnHttpClass = class of TSConnHttp;

  { TNanoHttpServer }

  TNanoHttpServer = class(TNanoServer)
  public
    server_id : ansistring;
    ct_by_ext : TAnsiStrMap;  // content type by extension

    constructor Create(aclass : TSConnHttpClass; alisten_port : uint16); reintroduce;
    destructor Destroy; override;

    procedure InitContentTypeMap;
    function ContentTypeByExt(aext : ansistring) : ansistring;
  end;

function ParseHttpDateRFC1123(const ADateStr: string) : TDateTime;

implementation

uses
  DateUtils;

const
  short_month_names : string = 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec,';

function ParseHttpDateRFC1123(const ADateStr : string) : TDateTime;
var
  sarr : array of ansistring;
  day, mon, year : integer;
begin
  result := 0;
  if ADateStr = '' then EXIT;

  // example: 'Sat, 21 Jun 2025 07:07:39 GMT'
  //             0   1   2    3        4   5

  sarr := ADateStr.Split(' ');
  if length(sarr) < 5 then EXIT;

  day := StrToIntDef(sarr[1], -1);
  if (day < 1) or (day > 31) then EXIT;

  mon := pos(sarr[2]+',', short_month_names);
  if mon < 1 then EXIT;
  mon := 1 + (mon - 1) div 4;

  year := StrToIntDef(sarr[3], -1);
  if year = -1 then EXIT;

  try
    result := StrToTime(sarr[4]) + EncodeDate(year, mon, day);
  except
    EXIT;
  end;
end;

function ReadFileToStr(const afilename : string) : ansistring;
var
  f : File;
  opened : boolean;
  flen : int64;
begin
  if not FileExists(afilename) then
  begin
    result := '';
    EXIT;
  end;

  try
    Assign(f, afilename);
    Reset(f, 1);
    opened := true;
    flen := FileSize(f);
    result := '';
    SetLength(result, flen);
    BlockRead(f, result[1], flen);
    close(f);
    opened := false;
  except
    if opened then close(f);
    result := '';
  end;
end;

{ TAnsiStrMap }

function TAnsiStrMap.KeyDataDef(const AKey : ansistring; const ADefValue : ansistring) : ansistring;
var
  i : integer;
begin
  i := IndexOf(AKey);
  if i >= 0 then result := GetData(i)
            else result := ADefValue;
end;

{ TSConnHttp }

constructor TSConnHttp.Create(aserver : TNanoServer);
begin
  inherited Create(aserver);

  SetLength(inbuf, 4096);  // the header must fit into this
  infill := 0;
  outbuf := '';

  ucheaders := TAnsiStrMap.Create;
  response_headers := TAnsiStrMap.Create;
  getvars := TAnsiStrMap.Create;
  cookies := TAnsiStrMap.Create;

  header_length := 0;
  uri := '';
  method := '';
  response := '';
  response_code := 200;
  file_fd := -1;
end;

destructor TSConnHttp.Destroy;
begin
  CloseFileFd();
  ucheaders.Free;
  response_headers.Free;
  getvars.Free;
  cookies.Free;
  inherited Destroy;
end;

procedure TSConnHttp.HandleInput(aobj : TObject);
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

procedure TSConnHttp.HandleOutput(aobj : TObject);
begin
  SendOutput();
end;

procedure TSConnHttp.ProcessInData;
var
  fullmsglen : uint32;

  label repeat_incheck;
begin

repeat_incheck:

  // check if the full header is received.
  sp.Init(inbuf[0], infill);
  if not sp.SearchPattern(#13#10#13#10) then   // header end marker
  begin
    EXIT;
  end;

  header_length := sp.readptr - sp.bufstart;
  fullmsglen := header_length;

  sp.Init(inbuf[0], header_length);
  if not ParseRequestHeader() then
  begin
    LogError('invalid request header detected. closing socket.');
    Close;
    EXIT;
  end;

  response := '';
  full_content_length := -1;
  response_code := 200;
  response_headers.Clear;
  PrepareHeaders();

  if not ProcessRequest() then
  begin
    response_code := 404;
    response_headers['Content-Type'] := 'text/html';
    response := '<h1>Not Found</h1>';
  end;

  // adding the response to the outbuf
  AddHttpOutput;

  // remove this message from the inbuf
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

function TSConnHttp.ParseRequestHeader : boolean;
var
  i : integer;
  skey : ansistring;
  sval : ansistring;
begin
  result := false;

  url := '';
  uri := '';
  keep_alive := false;
  ucheaders.Clear;
  getvars.Clear;
  cookies.Clear;

  // "GET /index.html HTTP/1.1"

  if sp.CheckSymbol('GET') then
  begin
    method := 'GET';
  end
  else if sp.CheckSymbol('POST') then
  begin
    method := 'POST';
  end
  else  // unknown method
  begin
    if not sp.ReadIdentifier() then EXIT;
    if sp.prevlen > 8 then EXIT;
    method := UpperCase(sp.PrevStr());
  end;

  sp.SkipSpaces();
  if not sp.ReadTo(' '#13#10) then EXIT;
  url := sp.PrevStr();

  i := pos('?', url);
  if i > 0 then
  begin
    uri := copy(url, 1, i-1);
    getstr := copy(url, i+1, length(url));
    ParseGetString();
  end
  else
  begin
    uri := url;
    getstr := '';
  end;

  sp.SkipSpaces();
  if not sp.CheckSymbol('HTTP/') then EXIT;
  if not sp.ReadTo(' '#13#10) then EXIT;
  http_ver := sp.PrevStr();

  sp.SkipSpaces(true);

  // parse the header fields
  while sp.readptr < sp.bufend do
  begin

    if not sp.ReadTo(':') then BREAK;
    skey := UpperCase(sp.PrevStr());
    sp.CheckSymbol(':');
    sp.SkipSpaces(false);
    if not sp.ReadTo(#13#10) then BREAK;
    sval := sp.PrevStr();

    // process the header line
    ucheaders.Add(skey, sval);

    // collect some special ucheaders
    if ('CONNECTION' = skey) and ('KEEP-ALIVE' = UpperCase(sval)) then keep_alive := true;
    if ('COOKIE' = skey) then
    begin
      ParseCookies(sval);
    end;

    sp.SkipSpaces(true);
  end;

  result := true;
end;

procedure TSConnHttp.ParseCookies(astr : ansistring);
var
  csp : TStrParseObj;
  skey : ansistring;
  sval : ansistring;
begin
  // example: "SESSIONID=abc123; theme=dark; loggedIn=true"

  csp.Init(astr);
  csp.SkipSpaces(false);
  while csp.readptr < csp.bufend do
  begin
    if not csp.ReadTo('=') then BREAK;

    skey := UpperCase(csp.PrevStr());
    csp.CheckSymbol('=');
    csp.SkipSpaces(false);
    csp.ReadTo(';');
    sval := csp.PrevStr();
    csp.CheckSymbol(';');

    cookies.Add(skey, sval);

    csp.SkipSpaces(true);
  end;
end;

procedure TSConnHttp.AddHttpOutput();
var
  s : ansistring;
  skey, sval : ansistring;
  i : integer;
begin
  s := 'HTTP/1.1 '+IntToStr(response_code)+' ';
  if      response_code = 200 then s += 'OK'
  else if response_code = 304 then s += 'NOT MODIFIED'
  else if response_code = 404 then s += 'NOT FOUND'
                              else s += 'ERROR';

  s += #13#10;

  if full_content_length > 0 then
  begin
    response_headers['Content-Length'] := IntToStr(full_content_length);
  end
  else // full response in the response string
  begin
    response_headers['Content-Length'] := IntToStr(length(response));
  end;

  for i := 0 to response_headers.Count - 1 do
  begin
    skey := response_headers.Keys[i];
    sval := response_headers.Data[i];
    s += skey + ': '+sval+#13#10
  end;

  // close the header
  s += #13#10;

  // add the content
  s += response;

  // append to output
  outbuf += s;
end;

procedure TSConnHttp.ParseGetString();
var
  sarr : array of ansistring;
  i, eqp : integer;
  s, k, v : ansistring;
begin
  sarr := getstr.Split('&');
  for i := 0 to length(sarr) - 1 do
  begin
    s := sarr[i];
    eqp := pos('=', s);
    if eqp > 0 then
    begin
      k := copy(s, 1, eqp - 1);
      v := copy(s, eqp + 1, length(s));
    end
    else
    begin
      k := s;
      v := '';
    end;
    if k <> '' then
    begin
      getvars[k] := v;
    end;
  end;
end;

procedure TSConnHttp.CloseFileFd();
begin
  if file_fd >= 0 then
  begin
    FileClose(file_fd);
    file_fd := -1;
  end;
end;

procedure TSConnHttp.SendOutput();
var
  r : integer;
  label repeat_send;
begin
repeat_send:
  if length(outbuf) > 0 then
  begin
    r := sock.Send(outbuf[1], length(outbuf));
    if r > 0 then
    begin
      if r < length(outbuf) then
      begin
        // remove this chunk from the output
        move(outbuf[r+1], outbuf[1], length(outbuf) - r);
        SetLength(outbuf, length(outbuf) - r);
      end
      else
      begin
        outbuf := '';
      end;
    end
    else  // socket sending error
    begin
      SetOutHandler(nil);
      outbuf := '';
      CloseFileFd();
      Close;  // force close the socket, even when keep-alive was requested
      EXIT;
    end;

    if length(outbuf) > 0 then
    begin
      // some data remained, request HandleOutput()
      SetOutHandler(@self.HandleOutput);
      EXIT;
    end;
  end;

  // the full outbuf was sent

  if (file_fd >= 0) and (file_remaining > 0) then
  begin
    // refill the outbuf:
    SetLength(outbuf, 65536);
    r := FileRead(file_fd, outbuf[1], length(outbuf));
    if r > 0 then
    begin
      file_remaining -= r;
      if r < length(outbuf) then SetLength(outbuf, r);

      goto repeat_send;
    end;

    // some read error happened
    outbuf := '';
    SetOutHandler(nil);
    CloseFileFd();
    Close;  // force close the socket, even when keep-alive was requested
    EXIT;
  end;

  // everything is sent, stop requesting HandleOutput()
  SetOutHandler(nil);

  CloseFileFd();

  if not keep_alive then Close;  // close the socket, requesting delayed free of this connection
end;

procedure TSConnHttp.PrepareHeaders();
var
  hsvr : TNanoHttpServer;
begin
  hsvr := TNanoHttpServer(server);
  if hsvr.server_id <> '' then response_headers['Server'] := hsvr.server_id;

  response_headers['Content-Type'] := 'text/plain';
end;

function TSConnHttp.ProcessRequest() : boolean;
begin
  result := false;
end;

function TSConnHttp.HandleStaticFiles(arootdir : ansistring) : boolean;
var
  fpath : ansistring;
  modsince_rfcdate : ansistring;
  file_rfcdate : ansistring;
  eroot : ansistring;
begin
  result := false;

  eroot := ExcludeTrailingBackslash(ExpandFileName(arootdir));
  fpath := eroot + uri;
  //writeln('Requesting "', fpath, '"');

  if fpath <> ExpandFileName(fpath) then  // traversal attack with '../' parts ?
  begin
    LogError('malicious url detected: "' + fpath + '"');
    EXIT;
  end;

  if FindFirst(fpath, faAnyFile and not faDirectory, fileinfo) <> 0 then
  begin
    EXIT;
  end;
  FindClose(fileinfo);

  file_rfcdate := FormatDateTime(HTTPDateFormat, LocalTimeToUniversal(fileinfo.Time)) + ' GMT';
  //writeln('file info: len = ', fileinfo.Size, ', time = ', file_rfcdate);
  response_headers['Last-Modified'] := file_rfcdate;
  response_headers['Content-Type'] := TNanoHttpServer(server).ContentTypeByExt(ExtractFileExt(uri));
  full_content_length := fileinfo.Size;

  // 'If-Modified-Since: Sat, 21 Jun 2025 07:07:39 GMT'
  modsince_rfcdate := ucheaders.KeyDataDef('IF-MODIFIED-SINCE', '');
  if modsince_rfcdate = file_rfcdate then
  begin
    // response with "304 NOT MODIFIED"
    response_code := 304;
    result := true;
    EXIT;
  end;

  // prepare file sending

  file_remaining := full_content_length;
  file_fd := FileOpen(fpath, fmOpenRead);
  if file_fd < 0 then EXIT;

  result := true;
end;

procedure TSConnHttp.LogError(astr : string);
begin
  writeln('ERROR: '+astr);  // you can / should override this
end;

{ TNanoHttpServer }

constructor TNanoHttpServer.Create(aclass : TSConnHttpClass; alisten_port : uint16);
begin
  inherited Create(aclass, alisten_port);

  server_id := 'NanoHttpServer';
  ct_by_ext := TAnsiStrMap.Create;

  InitContentTypeMap;
end;

destructor TNanoHttpServer.Destroy;
begin
  ct_by_ext.Free;
  inherited Destroy;
end;

procedure TNanoHttpServer.InitContentTypeMap;
begin
  ct_by_ext.Clear;

  ct_by_ext.Add('html', 'text/html');
  ct_by_ext.Add('htm',  'text/html');
  ct_by_ext.Add('css',  'text/css');
  ct_by_ext.Add('js',   'text/javascript');

  ct_by_ext.Add('jpg',  'image/jpeg');
  ct_by_ext.Add('jpeg', 'image/jpeg');
  ct_by_ext.Add('png',  'image/png');
  ct_by_ext.Add('gif',  'image/gif');
  ct_by_ext.Add('svg',  'image/svg+xml');
  ct_by_ext.Add('ico',  'image/vnd.microsoft.icon');
end;

function TNanoHttpServer.ContentTypeByExt(aext : ansistring) : ansistring;
var
  i : integer;
  fext : ansistring;
begin
  fext := LowerCase(aext);
  if copy(fext, 1, 1) = '.' then fext := fext.Remove(0, 1);
  i := ct_by_ext.IndexOf(fext);
  if i >= 0 then result := ct_by_ext.Data[i]
            else result := 'application/octet-stream';
end;

end.

