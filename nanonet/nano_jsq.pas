unit nano_jsq;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, JsonTools, nano_http, db, sqldb;

type

  { TJsQuery }

  { TNanoJsq }

  TNanoJsq = class
  public
    keep_last_sql_result : boolean;

    jroot : TJsonNode;
    jdata : TJsonNode;

    sqlq  : TSQLQuery; // not owned, linked only

    constructor Create(asqlq : TSQLQuery);
    destructor Destroy; override;

    procedure Reset;

    procedure SetError(acode : integer; amsg : string);

    procedure ReturnSqlData(sconn : TSConnHttp; asql : string);
  end;

implementation

{ TJsQuery }

constructor TNanoJsq.Create(asqlq : TSQLQuery);
begin
  keep_last_sql_result := false;

  jroot := TJsonNode.Create;
  sqlq := asqlq;

  Reset;
end;

destructor TNanoJsq.Destroy;
begin
  jroot.Free;
  inherited Destroy;
end;

procedure TNanoJsq.Reset;
begin
  jroot.Clear;
  jroot.Add('error', 0);
  jroot.Add('errormsg', '');

  jdata := jroot.Add('data', nkNull);
end;

procedure TNanoJsq.SetError(acode : integer; amsg : string);
begin
  jroot.Add('error', acode);
  jroot.Add('errormsg', amsg);
end;

procedure TNanoJsq.ReturnSqlData(sconn : TSConnHttp; asql : string);
var
  jrow : TJsonNode;
  jfnames : TJsonNode;
  f : TField;
  fi : integer;
begin
  Reset;

  try
    sqlq.SQL.Text := asql;
    sqlq.Open;
    if not sqlq.EOF then
    begin
      jfnames := jroot.Add('fieldnames', nkArray);
      for fi := 0 to sqlq.FieldCount - 1 do
      begin
        jfnames.Add('', sqlq.Fields[fi].FieldName);
      end;
    end;

    jdata := jroot.Add('data', nkArray);

    while not sqlq.EOF do
    begin
      jrow := jdata.Add('', nkArray);
      for fi := 0 to sqlq.FieldCount - 1 do
      begin
        f := sqlq.Fields[fi];
        if f.DataType in [ftInteger, ftSmallInt, ftWord, ftAutoInc, ftLargeInt] then
        begin
          jrow.Add('', sqlq.Fields[fi].AsInteger);
        end
        else if f.DataType in [ftDateTime] then
        begin
          jrow.Add('', FormatDateTime('yyyy-mm-dd hh:nn:ss', sqlq.Fields[fi].AsDateTime));
        end
        else if f.DataType = ftBoolean then
        begin
          jrow.Add('', sqlq.Fields[fi].AsBoolean);
        end
        else if f.DataType in [ftFloat, ftCurrency, ftBCD] then
        begin
          jrow.Add('', sqlq.Fields[fi].AsFloat);
        end
        else  // fallback to string
        begin
          jrow.Add('', sqlq.Fields[fi].AsString);
        end;
      end;
      sqlq.Next;
    end;
    sqlq.Close;
  except
    on e : Exception do
    begin
      sqlq.Active := false;

      jroot.Add('data', nkNull);
      jroot.Delete('fieldnames');
      jroot.Add('error', 901);
      jroot.Add('errormsg', e.ToString);
    end;
  end;

  sconn.response := jroot.AsJson;

  if not keep_last_sql_result then Reset; // frees the JSON data
end;

end.

