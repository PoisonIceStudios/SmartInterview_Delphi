unit uInterviewProfile;

interface

uses
  System.SysUtils,
  uRegistryStore;

type
  TInterviewProfile = record
    Role: string;
    TechStack: string;
    JobDescription: string;
    Experience: string;
    function HasContent: Boolean;
    function ToPromptBlock: string;
  end;

function ProfileLoad: TInterviewProfile;
procedure ProfileSave(const Profile: TInterviewProfile);
function ProfileShouldOfferSetupPrompt: Boolean;
procedure ProfileMarkSetupPromptSkipped;
procedure ProfileMarkSetupPromptDone;

implementation

uses
  System.IOUtils,
  System.JSON;

const
  KeyRole = 'ProfileRole';
  KeyTechStack = 'ProfileTechStack';
  KeyJobDescription = 'ProfileJobDescription';
  KeyExperience = 'ProfileExperience';
  PromptKey = 'InterviewSetupPrompt';

function LegacyFilePath: string;
begin
  Result := TPath.Combine(
    TPath.GetDirectoryName(TPath.GetHomePath),
    'SmartInterview\profile.json');
end;

function TInterviewProfile.HasContent: Boolean;
begin
  Result := not Trim(Role).IsEmpty or not Trim(TechStack).IsEmpty or
    not Trim(JobDescription).IsEmpty or not Trim(Experience).IsEmpty;
end;

function TrimBlock(const S: string): string;
var
  T: string;
begin
  T := StringReplace(Trim(S), sLineBreak, ' ', [rfReplaceAll]);
  if Length(T) > 1200 then
    Result := Copy(T, 1, 1200) + '...'
  else
    Result := T;
end;

function TInterviewProfile.ToPromptBlock: string;
var
  SB: TStringBuilder;
begin
  if not HasContent then
    Exit('');
  SB := TStringBuilder.Create;
  try
    SB.AppendLine;
    SB.AppendLine('CANDIDATE CONTEXT (facts you may use; do NOT invent experience or skills not listed here):');
    if not Trim(Role).IsEmpty then
      SB.AppendLine(Format('- Target role: %s', [Trim(Role)]));
    if not Trim(TechStack).IsEmpty then
      SB.AppendLine(Format('- Primary tech stack: %s', [Trim(TechStack)]));
    if not Trim(JobDescription).IsEmpty then
      SB.AppendLine(Format('- Job / interview focus: %s', [TrimBlock(JobDescription)]));
    if not Trim(Experience).IsEmpty then
      SB.AppendLine(Format('- Background & experience: %s', [TrimBlock(Experience)]));
    SB.AppendLine('- Tailor answers to this profile when relevant; stay honest - if something is not in the profile, answer generically as a capable candidate without claiming specific employers, projects, or years you were not given.');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TryLoadLegacyFile(out Profile: TInterviewProfile): Boolean;
var
  JsonText: string;
  Obj: TJSONObject;
begin
  Profile := Default(TInterviewProfile);
  Result := False;
  try
    if not TFile.Exists(LegacyFilePath) then
      Exit;
    JsonText := TFile.ReadAllText(LegacyFilePath);
    Obj := TJSONObject.ParseJSONValue(JsonText) as TJSONObject;
    if Obj = nil then
      Exit;
    try
      Profile.Role := Obj.GetValue<string>('role', '');
      Profile.TechStack := Obj.GetValue<string>('techStack', '');
      Profile.JobDescription := Obj.GetValue<string>('jobDescription', '');
      Profile.Experience := Obj.GetValue<string>('experience', '');
      Result := Profile.HasContent;
    finally
      Obj.Free;
    end;
  except
    Result := False;
  end;
end;

procedure TryDeleteLegacyFile;
begin
  try
    if TFile.Exists(LegacyFilePath) then
      TFile.Delete(LegacyFilePath);
  except
  end;
end;

function ProfileLoad: TInterviewProfile;
var
  Legacy: TInterviewProfile;
begin
  Result.Role := RegistryGetString(KeyRole);
  Result.TechStack := RegistryGetString(KeyTechStack);
  Result.JobDescription := RegistryGetString(KeyJobDescription);
  Result.Experience := RegistryGetString(KeyExperience);
  if not Result.HasContent and TryLoadLegacyFile(Legacy) then
  begin
    ProfileSave(Legacy);
    TryDeleteLegacyFile;
    Result := Legacy;
  end;
end;

procedure ProfileSave(const Profile: TInterviewProfile);
begin
  RegistrySetString(KeyRole, Trim(Profile.Role));
  RegistrySetString(KeyTechStack, Trim(Profile.TechStack));
  RegistrySetString(KeyJobDescription, Trim(Profile.JobDescription));
  RegistrySetString(KeyExperience, Trim(Profile.Experience));
end;

function ProfileShouldOfferSetupPrompt: Boolean;
var
  V: string;
begin
  V := RegistryGetString(PromptKey);
  Result := (V <> 'done') and (V <> 'skipped');
end;

procedure ProfileMarkSetupPromptSkipped;
begin
  RegistrySetString(PromptKey, 'skipped');
end;

procedure ProfileMarkSetupPromptDone;
begin
  RegistrySetString(PromptKey, 'done');
end;

end.
