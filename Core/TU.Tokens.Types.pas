unit TU.Tokens.Types;

interface

{$MINENUMSIZE 4}
{$WARN SYMBOL_PLATFORM OFF}

{ DONE: Staring from some point of complexity the compiler starts to confuse
  record helpers for the same types even if they are declared as not alises.
  So don't use the same names for methods in helpers for types that are based
  on the same simple type. }

uses
  Winapi.WinNt, NtUtils.Security.Sid;

type
  TGroupAdjustAction = (gaResetDefault, gaEnable, gaDisable);

  TPrivilegeAdjustAction = (paEnable, paDisable, paRemove);

  TTokenTypeEx = (ttAnonymous, ttIdentification, ttImpersonation, ttDelegation,
   ttPrimary);

  TTokenTypeExHelper = record helper for TTokenTypeEx
    function ToString: String;
    function TokenTypeValue: TTokenType;
    function SecurityImpersonationLevel: TSecurityImpersonationLevel;
  end;

function FormatCurrentState: String;

{ Comparison function used by cached event handling system }
function CompareSIDs(Value1, Value2: ISid): Boolean;
function CompareCardinals(Value1, Value2: Cardinal): Boolean;
function CompareLUIDs(Value1, Value2: TLuid): Boolean;
function CompareLongBools(Value1, Value2: LongBool): Boolean;
function ComparePrivileges(Value1, Value2: TArray<TPrivilege>): Boolean;
function CompareGroups(Value1, Value2: TGroup): Boolean;
function CompareGroupArrays(Value1, Value2: TArray<TGroup>): Boolean;
function CompareStatistics(Value1, Value2: TTokenStatistics): Boolean;

implementation

uses
  System.SysUtils, Ntapi.ntpebteb, NtUtils.Lsa, NtUtils.Exceptions;

{ TTokenTypeExHelper }

function TTokenTypeExHelper.SecurityImpersonationLevel:
  TSecurityImpersonationLevel;
begin
  if Self = ttPrimary then
    Result := SecurityImpersonation
  else
    Result := TSecurityImpersonationLevel(Self);
end;

function TTokenTypeExHelper.TokenTypeValue: TTokenType;
begin
  if Self = ttPrimary then
    Result := TokenPrimary
  else
    Result := TokenImpersonation;
end;

function TTokenTypeExHelper.ToString: String;
begin
  case Self of
    ttAnonymous: Result :=  'Anonymous';
    ttIdentification: Result := 'Identification';
    ttImpersonation: Result := 'Impersonation';
    ttDelegation: Result := 'Delegation';
    ttPrimary: Result := 'Primary token';
  end
end;

function FormatCurrentState: String;
var
  User, Domain: String;
begin
  if LsaxGetUserName(Domain, User).IsSuccess  then
  begin
    if (Domain <> '') and (User <> '') then
      Result := Domain + '\' + User
    else if Domain <> '' then
      Result := Domain
    else if User <> '' then
      Result := User
    else
      Result := 'N/A';
  end
  else
    Result := 'Unknown user';

  Result := Result + ' @ ' + IntToStr(RtlGetCurrentPeb.SessionId);
end;

{ Comparison functions }

function CompareSIDs(Value1, Value2: ISid): Boolean;
begin
  Result := Value1.EqualsTo(Value2.Sid);
end;

function CompareCardinals(Value1, Value2: Cardinal): Boolean;
begin
  Result := Value1 = Value2;
end;

function CompareLUIDs(Value1, Value2: TLuid): Boolean;
begin
  Result := Value1 = Value2;
end;

function CompareGroupArrays(Value1, Value2: TArray<TGroup>): Boolean;
var
  i: integer;
begin
  Result := Length(Value1) = Length(Value2);
  if Result then
    for i := 0 to High(Value1) do
      if not Value1[i].SecurityIdentifier.EqualsTo(
        Value2[i].SecurityIdentifier.Sid)
        or (Value1[i].Attributes <> Value2[i].Attributes) then
          Exit(False);
end;

function CompareGroups(Value1, Value2: TGroup): Boolean;
begin
  Result := (Value1.SecurityIdentifier.EqualsTo(
    Value2.SecurityIdentifier.Sid)) and
    (Value1.Attributes = Value2.Attributes);
end;

function CompareLongBools(Value1, Value2: LongBool): Boolean;
begin
  Result := Value1 = Value2;
end;

function ComparePrivileges(Value1, Value2: TArray<TPrivilege>): Boolean;
var
  i: integer;
begin
  Result := Length(Value1) = Length(Value2);
  if Result then
    for i := 0 to High(Value1) do
      if (Value1[i].Attributes <> Value2[i].Attributes) or
        (Value1[i].Luid <> Value2[i].Luid) then
        Exit(False);
end;

function CompareStatistics(Value1, Value2: TTokenStatistics): Boolean;
begin
  Result := (Value1.ModifiedId = Value2.ModifiedId);
end;

end.
