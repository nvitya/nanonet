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
   file:     nano_session.pas
   brief:    Simple file based session handling in JSON format
   date:     2025-08-08
   authors:  nvitya
*)

unit nano_sessions;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fgl, jsontools, nano_http;

type

  { TSessionObj }

  TSessionIdString = string[32+7];

  TSessionObj = class
  public
    id   : TSessionIdString;
    data : TJsonNode;

    constructor Create(aid : TSessionIdString);
    destructor Destroy; override;
  end;

  TSessionObjMap = specialize TFPGMapObject<TSessionIdString, TSessionObj>;

  { TSessionStore }

  TSessionStore = class
  public

    idmap : TSessionObjMap;
    max_session_age_s : integer;

    constructor Create; virtual;
    destructor Destroy; override;

    function GetOrCreateSession(asessionid : TSessionIdString) : TSessionObj;

    function GenerateNewSessionId : TSessionIdString;

    procedure LoadSession(asessionobj : TSessionObj); virtual;
    procedure SaveSession(asessionobj : TSessionObj); virtual;

    function InitSession(aconn : TSConnHttp) : TSessionObj;
  end;

  TSessionStoreClass = class of TSessionStore;

  { TJsonFileSessionStore }

  TJsonFileSessionStore = class(TSessionStore)
  public
    rootdir : string;

    constructor Create; override;
    destructor Destroy; override;

    function Init(arootdir : string; create_non_existing : boolean = false) : boolean;

    procedure SaveSession(asessionobj : TSessionObj); override;
    procedure LoadSession(asessionobj : TSessionObj); override;
  end;

const
  sessionstore : TSessionStore = nil;

function InitJsonFileSessionStore(arootdir : string; create_non_existing : boolean = false) : boolean;

implementation

uses
  DateUtils;

function InitJsonFileSessionStore(arootdir : string; create_non_existing : boolean) : boolean;
var
  jfst : TJsonFileSessionStore;
begin
  jfst := TJsonFileSessionStore.Create;
  if jfst.Init(arootdir, create_non_existing) then
  begin
    sessionstore := jfst;
    result := true;
  end
  else
  begin
    result := false;
  end;
end;

{ TSessionObj }

constructor TSessionObj.Create(aid : TSessionIdString);
begin
  id := aid;
  data := TJsonNode.Create;
end;

destructor TSessionObj.Destroy;
begin
  data.Free;
  inherited Destroy;
end;

constructor TSessionStore.Create;
begin
  idmap := TSessionObjMap.Create(true); // automatically free the objects
  max_session_age_s := 60 * 60 * 24 * 30;  // 30 days by default
end;

destructor TSessionStore.Destroy;
begin
  idmap.Clear; // automatically frees the objects
  idmap.Free;
  inherited;
end;

function TSessionStore.GetOrCreateSession(asessionid : TSessionIdString) : TSessionObj;
var
  sid : TSessionIdString;
  sobj : TSessionObj;
  newsession : boolean = false;
begin
  if (asessionid = '') or (length(asessionid) <> 32) then
  begin
    sid := GenerateNewSessionId();
    newsession := true;
  end
  else
  begin
    sid := asessionid;
  end;

 if not idmap.TryGetData(sid, sobj) then
  begin
    sobj := TSessionObj.Create(sid);
    idmap.Add(sid, sobj);
    if not newsession then
    begin
      LoadSession(sobj);  // try to load the session data from the disk
    end;
  end;

  result := sobj;
end;

function TSessionStore.GenerateNewSessionId : TSessionIdString;
var
  i: Integer;
  RandomPart    : ansistring;
  TimestampHex  : ansistring;
  UnixTime      : Int64;
begin
  // Generate 12 random hex bytes (24 hex chars)
  RandomPart := '';
  for i := 1 to 12 do
    RandomPart := RandomPart + IntToHex(Random(256), 2);

  // Get UNIX timestamp (seconds since 1970)
  UnixTime := DateTimeToUnix(Now);
  TimestampHex := IntToHex(UnixTime, 8); // 8 hex digits = 4 bytes = enough until 2106

  // Combine them
  Result := RandomPart + TimestampHex;
end;

procedure TSessionStore.LoadSession(asessionobj : TSessionObj);
begin
end;

procedure TSessionStore.SaveSession(asessionobj : TSessionObj);
begin
end;

function TSessionStore.InitSession(aconn : TSConnHttp) : TSessionObj;
var
  sid : TSessionIdString;
  s : ansistring;
  sessobj : TSessionObj;
begin
  sid := aconn.cookies.KeyDataDef('SESSIONID', '');
  sessobj := sessionstore.GetOrCreateSession(sid);

  s := 'SESSIONID='+sessobj.id
    +'; Path=/'
    //+'; HttpOnly'
  ;
  if max_session_age_s > 0 then
  begin
    s += '; Max-Age='+IntToStr(max_session_age_s);
  end;

  aconn.response_headers['Set-Cookie'] := s;

  result := sessobj;
end;

{ TJsonFileSessionStore }

constructor TJsonFileSessionStore.Create;
begin
  inherited;

  rootdir := IncludeTrailingBackslash('.');
end;

destructor TJsonFileSessionStore.Destroy;
begin
  inherited Destroy;
end;

function TJsonFileSessionStore.Init(arootdir : string; create_non_existing : boolean) : boolean;
var
  s : string;
begin
  result := false;
  s := ExpandFileName(arootdir);
  if not DirectoryExists(s) then
  begin
    if not create_non_existing then EXIT;
    ForceDirectories(s);
  end;
  rootdir := IncludeTrailingBackslash(s);
  result := true;
end;

procedure TJsonFileSessionStore.SaveSession(asessionobj : TSessionObj);
begin
  try
    asessionobj.data.SaveToFile(rootdir + asessionobj.id);
  except
    ;
  end;
end;

procedure TJsonFileSessionStore.LoadSession(asessionobj : TSessionObj);
begin
  try
    asessionobj.data.LoadFromFile(rootdir + asessionobj.id);
  except
    ;
  end;
end;

initialization
begin
  Randomize;
end;

end.

