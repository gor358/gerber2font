#define AppName "gerber2font"

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppPublisher "a2e.tech"
#define AppExeName "gerber2font.exe"
#define AppReadmeName "README.md"
#define AppLicenseName "LICENSE"

#ifndef SourceDir
  #define SourceDir "."
#endif

#ifndef DistDir
  #define DistDir "dist"
#endif

#ifndef OutputDir
  #define OutputDir "output"
#endif

#ifndef IconFile
  #define IconFile ""
#endif

[Setup]
AppId={{D4A77D22-95A7-4F18-8E6E-1BE8A07E8B7C}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName} Installer
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=no
LicenseFile={#SourceDir}\{#AppLicenseName}
OutputDir={#OutputDir}
OutputBaseFilename={#AppName}-setup-{#AppVersion}-win-x64
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExeName}
ChangesEnvironment=yes

#if IconFile != ""
SetupIconFile={#IconFile}
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "addtopath"; Description: "Add application directory to PATH"; GroupDescription: "Additional tasks:"; Flags: checkedonce

[Files]
Source: "{#DistDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

#if IconFile != ""
Source: "{#IconFile}"; DestDir: "{app}"; DestName: "app.ico"; Flags: ignoreversion
#endif

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Open README"; Filename: "{app}\{#AppReadmeName}"

#if IconFile != ""
IconFilename: "{app}\app.ico"
#endif

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Run {#AppName}"; Flags: nowait postinstall skipifsilent unchecked

[Code]
function GetInstallDir(Param: string): string;
begin
  if IsAdminInstallMode then
    Result := ExpandConstant('{autopf}\{#AppName}')
  else
    Result := ExpandConstant('{localappdata}\Programs\{#AppName}');
end;

procedure InitializeWizard;
begin
  WizardForm.DirEdit.Text := GetInstallDir('');
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpSelectDir then
    WizardForm.DirEdit.Text := GetInstallDir('');
end;

function PathContainsDir(PathValue, DirValue: string): Boolean;
var
  PaddedPath: string;
  PaddedDir: string;
begin
  PaddedPath := ';' + Uppercase(PathValue) + ';';
  PaddedDir := ';' + Uppercase(DirValue) + ';';
  Result := Pos(PaddedDir, PaddedPath) > 0;
end;

function RemovePathEntry(PathValue, DirValue: string): string;
var
  WorkValue: string;
  Entry: string;
  P: Integer;
begin
  Result := '';
  WorkValue := PathValue;

  StringChangeEx(WorkValue, #13, '', True);
  StringChangeEx(WorkValue, #10, '', True);

  while Length(WorkValue) > 0 do
  begin
    P := Pos(';', WorkValue);
    if P > 0 then
    begin
      Entry := Copy(WorkValue, 1, P - 1);
      Delete(WorkValue, 1, P);
    end
    else
    begin
      Entry := WorkValue;
      WorkValue := '';
    end;

    Entry := Trim(Entry);

    if (Entry <> '') and (CompareText(Entry, DirValue) <> 0) then
    begin
      if Result <> '' then
        Result := Result + ';';
      Result := Result + Entry;
    end;
  end;
end;

procedure AddDirToPathIfNeeded(DirValue: string);
var
  PathValue: string;
begin
  if IsAdminInstallMode then
  begin
    if not RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', PathValue) then
      PathValue := '';
    if not PathContainsDir(PathValue, DirValue) then
    begin
      if (PathValue <> '') and (Copy(PathValue, Length(PathValue), 1) <> ';') then
        PathValue := PathValue + ';';
      PathValue := PathValue + DirValue;
      RegWriteStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', PathValue);
    end;
  end
  else
  begin
    if not RegQueryStringValue(HKCU, 'Environment', 'Path', PathValue) then
      PathValue := '';
    if not PathContainsDir(PathValue, DirValue) then
    begin
      if (PathValue <> '') and (Copy(PathValue, Length(PathValue), 1) <> ';') then
        PathValue := PathValue + ';';
      PathValue := PathValue + DirValue;
      RegWriteStringValue(HKCU, 'Environment', 'Path', PathValue);
    end;
  end;
end;

procedure RemoveDirFromPath(DirValue: string);
var
  PathValue: string;
begin
  if IsAdminInstallMode then
  begin
    if RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', PathValue) then
    begin
      PathValue := RemovePathEntry(PathValue, DirValue);
      RegWriteStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', PathValue);
    end;
  end
  else
  begin
    if RegQueryStringValue(HKCU, 'Environment', 'Path', PathValue) then
    begin
      PathValue := RemovePathEntry(PathValue, DirValue);
      RegWriteStringValue(HKCU, 'Environment', 'Path', PathValue);
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('addtopath') then
    AddDirToPathIfNeeded(ExpandConstant('{app}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    RemoveDirFromPath(ExpandConstant('{app}'));
end;
