program ObjectParamsCopier;

uses
 sysutils,
 ObjectFileParser;

var
  f:TObjectFile;
  object_name:string;
  cfg_name:string;
begin
  If ParamCount() < 3 then begin
    writeln('Usage:');
    writeln('ObjectParamsCopier.exe <action> <object file name> <config file name>');
    exit;
  end;

  object_name:=ParamStr(2);
  cfg_name:=ParamStr(3);

  f:=TObjectFile.Create();
  try
    if ParamStr(1)='dump' then begin
      if not f.LoadFromFile(object_name) then begin
        Writeln('Cannot load data from file '+object_name);
        exit;
      end;
      if not f.SaveSurfacesSettingsToFile(cfg_name) then begin
        Writeln('Cannot parse or save data to file '+cfg_name);
        exit;
      end;

    end else if ParamStr(1)='update' then begin
      if not f.LoadFromFile(object_name) then begin
        Writeln('Cannot load data from file '+object_name);
        exit;
      end;
      if not f.UpdateSurfacesSettingsFromFile(cfg_name) then begin
        Writeln('Cannot apply new data from file '+cfg_name);
        exit;
      end;
      if not f.SaveToFile(object_name) then begin
        Writeln('Cannot save new data to file '+object_name);
        exit;
      end;

    end else begin
      writeln('Unknown action '+ParamStr(1)+'. Supported actions: "dump", "update"');
    end;
  finally
    FreeAndNil(f);
  end;
end.

