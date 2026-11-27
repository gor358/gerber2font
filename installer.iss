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
  NormalizedPath: string;
  Needle: string;
begin
  NormalizedPath := ';' + Uppercase(PathValue) + ';';
  Needle := ';' + Uppercase(DirValue) + ';';
  Result := Pos(Needle, NormalizedPath) > 0;
end;

function RemovePathEntry(PathValue, DirValue: string): string;
var
  Parts: TArrayOfString;
  I: Integer;
  OutValue: string;
begin
  OutValue := '';
  StringChangeEx(PathValue, #13, '', True);
  StringChangeEx(PathValue, #10, '', True);

  Parts := SplitString(PathValue, ';');
  for I := 0 to GetArrayLength(Parts) - 1 do
  begin
    if (Trim(Parts[I]) <> '') and (CompareText(Trim(Parts[I]), DirValue) <> 0) then
    begin
      if OutValue <> '' then
        OutValue := OutValue + ';';
      OutValue := OutValue + Trim(Parts[I]);
    end;
  end;
  Result := OutValue;
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
