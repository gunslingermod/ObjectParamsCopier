unit ObjectFileParser;

{$mode objfpc}{$H+}

interface
uses
  ChunkedFileParser,
  IniFiles;

type

  { TSurfaceDescription }

  TSurfaceDescription = class
  private
    _name:string;
    _shader_name:string;
    _shader_xrlc_name:string;
    _gamemtl_name:string;
    _texture:string;
    _vmap:string;
    _flags:cardinal;
    _fvf:cardinal;
    _reserved:cardinal;
  public
    function LoadFromFile(path:string; section:string):boolean;
    function SaveToFile(path:string; section:string):boolean;

    function Deserialize(var data:string):boolean;
    function Serialize():string;

    function GetName():string;
    procedure CopyFrom(s:TSurfaceDescription);
  end;

  { TSurfaceDescriptionsContainer }

  TSurfaceDescriptionsContainer = class
  private
    _descriptions:array of TSurfaceDescription;
    procedure _Reset();
  public
    constructor Create();
    destructor Destroy(); override;

    function LoadFromFile(path:string):boolean;
    function SaveToFile(path:string):boolean;

    function Deserialize(var data:string):boolean;
    function Serialize():string;

    function GetItemsCount():cardinal;
    function GetItem(idx:cardinal):TSurfaceDescription;
    procedure CopyItem(idx:cardinal; data:TSurfaceDescription);
  end;

  { TObjectFile }

  TObjectFile = class
  private
    _data:TChunkedMemory;
    _loaded:boolean;

    function _ParseSurfacesSettings(surfaces:TSurfaceDescriptionsContainer):boolean;
    function _UpdateSurfacesSettings(surfaces:TSurfaceDescriptionsContainer):boolean;
  public
    constructor Create();
    destructor Destroy(); override;

    function LoadFromFile(path:string):boolean;
    function SaveToFile(path:string):boolean;
    function SaveSurfacesSettingsToFile(path:string):boolean;
    function UpdateSurfacesSettingsFromFile(path:string):boolean;
  end;

implementation
uses SysUtils;

const
  EOBJ_CHUNK_OBJECT_BODY:word = $7777;
  EOBJ_CHUNK_SURFACES3:word = $0907;

function SerializeCardinal(c:cardinal):string;
begin
  result:=pchar(@c)[0]+pchar(@c)[1]+pchar(@c)[2]+pchar(@c)[3];
end;

function DeserializeCardinal(var data:string; var outdata:cardinal):boolean;
begin
  result:=false;
  if length(data) < sizeof(cardinal) then exit;
  outdata:=pcardinal(PAnsiChar(data))^;

  data:=rightstr(data, length(data)-sizeof(cardinal));
  result:=true;
end;

function DeserializePCharStr(var data:string; var outstr:string):boolean;
var
  pstr:PAnsiChar;
  tmpstr:string;
  sz_read, sz_data:integer;
begin
  result:=false;
  pstr:=PAnsiChar(data);
  sz_data:=length(data);

  tmpstr:=pstr;
  sz_read:=length(tmpstr)+1;
  if sz_read > sz_data then exit; //проверка на наличие нуль-терминатора в данных пользователя

  data:=rightstr(data, length(data)-sz_read);
  sz_data:=length(data);
  outstr:=tmpstr;
  result:=true;
end;

{ TSurfaceDescriptionsContainer }

procedure TSurfaceDescriptionsContainer._Reset();
var
  i:integer;
begin
  for i:=0 to length(_descriptions)-1 do begin
    FreeAndNil(_descriptions[i]);
  end;
  setlength(_descriptions, 0);
end;

constructor TSurfaceDescriptionsContainer.Create();
begin
  setlength(_descriptions, 0);
end;

destructor TSurfaceDescriptionsContainer.Destroy();
begin
  _reset();
  inherited Destroy();
end;

function TSurfaceDescriptionsContainer.LoadFromFile(path: string): boolean;
var
  ini:TIniFile;
  cnt, i:integer;
begin
  result:=false;
  _Reset();
  ini:=TIniFile.Create(path);
  try
    cnt:=ini.ReadInteger('main', 'surfaces_count', 0);
    if cnt > 0 then begin
      setlength(_descriptions, cnt);
      for i:=0 to cnt-1 do begin
        _descriptions[i]:=TSurfaceDescription.Create();
        if not _descriptions[i].LoadFromFile(path, 'surface_'+inttostr(i)) then break;
        if i = cnt-1 then result:=true;
      end;
    end;
  finally
    FreeAndNil(ini);
  end;
end;

function TSurfaceDescriptionsContainer.SaveToFile(path: string): boolean;
var
  i:integer;
  ini:TIniFile;
begin
  result:=false;
  ini:=TIniFile.Create(path);
  try
    ini.WriteInteger('main', 'surfaces_count', length(_descriptions));
    for i:=0 to length(_descriptions)-1 do begin
      if not _descriptions[i].SaveToFile(path, 'surface_'+inttostr(i)) then break;
      if i = length(_descriptions)-1 then result:=true;
    end;
  finally
    FreeAndNil(ini);
  end;
end;

function TSurfaceDescriptionsContainer.Deserialize(var data: string): boolean;
var
  i, cnt:cardinal;
begin
  result:=false;
  cnt:=0;
  _Reset();
  if not DeserializeCardinal(data, cnt) then exit;
  setlength(_descriptions, cnt);
  if cnt = 0 then exit;
  for i:=0 to cnt-1 do begin
    _descriptions[i]:=TSurfaceDescription.Create();
    if not _descriptions[i].Deserialize(data) then break;
    if i = cnt-1 then result:=true;
  end;
end;

function TSurfaceDescriptionsContainer.Serialize(): string;
var
  i:integer;
begin
  result:='';
  result:=SerializeCardinal(length(_descriptions));
  for i:=0 to length(_descriptions)-1 do begin
    result:=result+_descriptions[i].Serialize();
  end;
end;

function TSurfaceDescriptionsContainer.GetItemsCount(): cardinal;
begin
  result:=length(_descriptions);
end;

function TSurfaceDescriptionsContainer.GetItem(idx: cardinal): TSurfaceDescription;
begin
  result:=nil;
  if idx >= GetItemsCount() then exit;
  result:=_descriptions[idx];
end;

procedure TSurfaceDescriptionsContainer.CopyItem(idx: cardinal; data: TSurfaceDescription);
begin
  if idx >= GetItemsCount() then exit;
  _descriptions[idx].CopyFrom(data);
end;

{ TSurfaceDescription }

function TSurfaceDescription.LoadFromFile(path: string; section: string): boolean;
var
  ini:TIniFile;
begin
  result:=false;
  try
    ini:=TIniFile.Create(path);
    self._name:=ini.ReadString(section, 'name', '');
    if length(self._name) > 0 then begin
      self._shader_name:=ini.ReadString(section, 'shader_name', 'default');
      self._shader_xrlc_name:=ini.ReadString(section, 'shader_xrlc_name', 'default');
      self._gamemtl_name:=ini.ReadString(section, 'gamemtl_name', 'default');
      self._texture:=ini.ReadString(section, 'texture', 'default');
      self._vmap:=ini.ReadString(section, 'vmap', 'default');
      self._flags:=ini.ReadInt64(section, 'flags', 0);
      self._fvf:=ini.ReadInt64(section, 'fvf', 0);
      self._reserved:=ini.ReadInt64(section, 'reserved', 1);
      result:=true;
    end;
    FreeAndNil(ini);
  except
    result:=false;
  end;
end;

function TSurfaceDescription.SaveToFile(path: string; section: string): boolean;
var
  ini:TIniFile;
begin
  result:=false;
  try
    ini:=TIniFile.Create(path);
    ini.WriteString(section, 'name', self._name);
    ini.WriteString(section, 'shader_name', self._shader_name);
    ini.WriteString(section, 'shader_xrlc_name', self._shader_xrlc_name);
    ini.WriteString(section, 'gamemtl_name', self._gamemtl_name);
    ini.WriteString(section, 'texture', self._texture);
    ini.WriteString(section, 'vmap', self._vmap);
    ini.WriteInt64(section, 'flags', self._flags);
    ini.WriteInt64(section, 'fvf', self._fvf);
    ini.WriteInt64(section, 'reserved', self._reserved);
    result:=true;
    FreeAndNil(ini);
  except
    result:=false;
  end;
end;

function TSurfaceDescription.Deserialize(var data: string): boolean;
begin
  result:=false;

  if not DeserializePCharStr(data, self._name) then exit;
  if not DeserializePCharStr(data, self._shader_name) then exit;
  if not DeserializePCharStr(data, self._shader_xrlc_name) then exit;
  if not DeserializePCharStr(data, self._gamemtl_name) then exit;
  if not DeserializePCharStr(data, self._texture) then exit;
  if not DeserializePCharStr(data, self._vmap) then exit;
  if not DeserializeCardinal(data, self._flags) then exit;
  if not DeserializeCardinal(data, self._fvf) then exit;
  if not DeserializeCardinal(data, self._reserved) then exit;

  result:=true;
end;

function TSurfaceDescription.Serialize(): string;
begin
  result:='';
  result:=result+self._name+chr(0);
  result:=result+self._shader_name+chr(0);
  result:=result+self._shader_xrlc_name+chr(0);
  result:=result+self._gamemtl_name+chr(0);
  result:=result+self._texture+chr(0);
  result:=result+self._vmap+chr(0);
  result:=result+SerializeCardinal(self._flags);
  result:=result+SerializeCardinal(self._fvf);
  result:=result+SerializeCardinal(self._reserved);
end;

function TSurfaceDescription.GetName(): string;
begin
  result:=self._name;
end;

procedure TSurfaceDescription.CopyFrom(s: TSurfaceDescription);
begin
  self._name:=s._name;
  self._shader_name := s._shader_name ;
  self._shader_xrlc_name := s._shader_xrlc_name ;
  self._gamemtl_name := s._gamemtl_name ;
  self._texture := s._texture ;
  self._vmap := s._vmap ;
  self._flags := s._flags ;
  self._fvf := s._fvf ;
  self._reserved := s._reserved ;
end;

{ TObjectFile }

function TObjectFile._ParseSurfacesSettings(surfaces: TSurfaceDescriptionsContainer): boolean;
var
  ofs:TChunkedOffset;
  raw_data:string;
begin
  result:=false;
  if not _loaded then exit;

  ofs:=_data.FindSubChunk(EOBJ_CHUNK_SURFACES3);
  if not _data.EnterSubChunk(ofs) then exit;
  try
    raw_data:=_data.GetCurrentChunkRawDataAsString();
    if surfaces.Deserialize(raw_data) then begin
      result:=true;
    end;
  finally
    _data.LeaveSubChunk();
  end;
end;

function TObjectFile._UpdateSurfacesSettings(surfaces: TSurfaceDescriptionsContainer): boolean;
var
  raw_data:string;
  ofs:TChunkedOffset;
begin
  result:=false;
  if not _loaded then exit;

  ofs:=_data.FindSubChunk(EOBJ_CHUNK_SURFACES3);
  if not _data.EnterSubChunk(ofs) then exit;
  try
    raw_data:=surfaces.Serialize();
    if _data.ReplaceCurrentRawDataWithString(raw_data) then begin
      result:=true;
    end;
  finally
    _data.LeaveSubChunk();
  end;
end;

constructor TObjectFile.Create();
begin
  _data:=TChunkedMemory.Create();
  _loaded:=false;
end;

destructor TObjectFile.Destroy();
begin
  FreeAndNil(_data);
  inherited Destroy();
end;

function TObjectFile.LoadFromFile(path: string): boolean;
var
  ofs:TChunkedOffset;
begin
  _loaded:=false;
  result:=_data.LoadFromFile(path, 0);
  if result then begin
    ofs:=_data.FindSubChunk(EOBJ_CHUNK_OBJECT_BODY);
    if ofs<>INVALID_CHUNK then begin
      result:=_data.EnterSubChunk(ofs);
    end else begin
      result:=false;
    end;
  end;

  if result then begin
    _loaded:=true;
  end;
end;

function TObjectFile.SaveToFile(path: string): boolean;
begin
  result:=false;
  if not _loaded then exit;

  result:=_data.SaveToFile(path);
end;

function TObjectFile.SaveSurfacesSettingsToFile(path: string): boolean;
var
  surfaces:TSurfaceDescriptionsContainer;
begin
  result:=false;
  if not _loaded then exit;

  surfaces:=TSurfaceDescriptionsContainer.Create();
  try
    result:=_ParseSurfacesSettings(surfaces);
    if result then result:=surfaces.SaveToFile(path);
  finally
    FreeAndNil(surfaces);
  end;
end;

function TObjectFile.UpdateSurfacesSettingsFromFile(path: string): boolean;
var
  surfaces, surfaces_new:TSurfaceDescriptionsContainer;
  i, j:cardinal;
begin
  result:=false;
  if not _loaded then exit;

  surfaces:=TSurfaceDescriptionsContainer.Create();
  surfaces_new:=TSurfaceDescriptionsContainer.Create();
  try
    if _ParseSurfacesSettings(surfaces) and (surfaces.GetItemsCount() > 0) and surfaces_new.LoadFromFile(path) and (surfaces_new.GetItemsCount() > 0) then begin
      for i:=0 to surfaces.GetItemsCount()-1 do begin
        for j:=0 to surfaces_new.GetItemsCount()-1 do begin
          if surfaces.GetItem(i).GetName() = surfaces_new.GetItem(j).GetName() then begin
            surfaces.CopyItem(i, surfaces_new.GetItem(j));
          end;
        end;
      end;
      result:=_UpdateSurfacesSettings(surfaces);
    end;
  finally
    FreeAndNil(surfaces);
    FreeAndNil(surfaces_new);
  end;
end;


end.

