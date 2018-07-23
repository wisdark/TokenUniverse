unit UI.Information;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Menus,
  Vcl.ComCtrls, Vcl.Buttons, TU.Tokens, System.ImageList, Vcl.ImgList,
  UI.SessionComboBox, UI.ListViewEx, TU.WtsApi;

type
  TInfoDialog = class(TForm)
    PageControl: TPageControl;
    TabGeneral: TTabSheet;
    TabGroups: TTabSheet;
    TabPrivileges: TTabSheet;
    StaticUser: TStaticText;
    EditUser: TEdit;
    ButtonClose: TButton;
    ListViewGroups: TListViewEx;
    ListViewPrivileges: TListViewEx;
    TabRestricted: TTabSheet;
    ListViewRestricted: TListViewEx;
    StaticObjAddr: TStaticText;
    EditObjAddr: TEdit;
    StaticSession: TStaticText;
    StaticElevation: TStaticText;
    StaticVirtualization: TStaticText;
    StaticIntegrity: TStaticText;
    StaticUIAccess: TStaticText;
    StaticType: TStaticText;
    ComboSession: TSessionComboBox;
    ComboIntegrity: TComboBox;
    StaticHandle: TStaticText;
    EditHandle: TEdit;
    EditType: TEdit;
    ImageList: TImageList;
    ComboBoxView: TComboBox;
    BtnSetIntegrity: TSpeedButton;
    BtnSetSession: TSpeedButton;
    StaticAccess: TStaticText;
    EditAccess: TEdit;
    EditElevation: TEdit;
    PrivilegePopup: TPopupMenu;
    MenuPrivEnable: TMenuItem;
    MenuPrivDisable: TMenuItem;
    MenuPrivRemove: TMenuItem;
    MenuPrivSelectAll: TMenuItem;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure BtnSetIntegrityClick(Sender: TObject);
    procedure ChangedView(Sender: TObject);
    procedure BtnSetSessionClick(Sender: TObject);
    procedure DoCloseForm(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SetStaleColor(Sender: TObject);
    procedure ActionPrivilegeEnable(Sender: TObject);
    procedure ActionPrivilegeDisable(Sender: TObject);
    procedure ActionPrivilegeRemove(Sender: TObject);
    procedure ListViewPrivilegesContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure ActionPrivilegeSelectAll(Sender: TObject);
  private
    Token: TToken;
    Privileges: TPrivilegeArray;
    procedure ConfirmTokenClose(Sender: TObject);
    procedure ChangedCaption(Sender: TObject);
    procedure ChangedIntegrity(Sender: TObject);
    procedure ChangedSession(Sender: TObject);
    procedure ChangedPrivileges(Sender: TObject);
    function GetSelectedPrivileges: TPrivilegeLUIDArray;
    procedure Refresh;
  public
    constructor CreateFromToken(AOwner: TComponent; SrcToken: TToken);
  end;

implementation

uses
  System.UITypes, UI.MainForm, TU.Common;

{$R *.dfm}

const
  clStale: TColor = $F0E4E4;
  clEnabledByDefault: TColor = $C0F0C0;
  clEnabled: TColor = $E0F0E0;
  clUseForDenyOnly: TColor = $E0E0F0;
  clIntegrity: TColor = $F0E0E0;

procedure TInfoDialog.DoCloseForm(Sender: TObject);
begin
  Close;
end;

procedure TInfoDialog.BtnSetSessionClick(Sender: TObject);
begin
  ComboSession.Color := clWindow;
  try
    Token.Session := ComboSession.SelectedSession;
  except
    ChangedSession(Token);
    raise;
  end;
end;

procedure TInfoDialog.ActionPrivilegeDisable(Sender: TObject);
begin
  if ListViewPrivileges.SelCount <> 0 then
    Token.PrivilegeAdjust(GetSelectedPrivileges, paDisable);
end;

procedure TInfoDialog.ActionPrivilegeEnable(Sender: TObject);
begin
  if ListViewPrivileges.SelCount <> 0 then
    Token.PrivilegeAdjust(GetSelectedPrivileges, paEnable);
end;

procedure TInfoDialog.ActionPrivilegeRemove(Sender: TObject);
begin
  if ListViewPrivileges.SelCount <> 0 then
    Token.PrivilegeAdjust(GetSelectedPrivileges, paRemove);
end;

procedure TInfoDialog.ActionPrivilegeSelectAll(Sender: TObject);
begin
  ListViewPrivileges.SelectAll;
end;

procedure TInfoDialog.BtnSetIntegrityClick(Sender: TObject);
const
  // TODO: It doesn't work if we have an intermediate level
  IndexToIntegrity: array [0 .. 5] of TTokenIntegrityLevel = (ilUntrusted,
    ilLow, ilMedium, ilMediumPlus, ilHigh, ilSystem);
begin
  ComboIntegrity.Color := clWindow;
  try
    if ComboIntegrity.ItemIndex <> -1 then
      Token.Integrity := IndexToIntegrity[ComboIntegrity.ItemIndex]
    else
      Token.Integrity := TTokenIntegrityLevel(StrToIntEx(ComboIntegrity.Text,
        'integrity level'));
  except
    ChangedIntegrity(Token);
    raise;
  end;
end;

procedure TInfoDialog.ChangedCaption(Sender: TObject);
const
  Title = 'Token Information for "%s"';
begin
  Caption := Format(Title, [Token.Caption]);
end;

procedure TInfoDialog.ChangedIntegrity(Sender: TObject);
var
  index: integer;
begin
  ComboIntegrity.Items.BeginUpdate;
  ComboIntegrity.Clear;

  ComboIntegrity.Items.Add('Untrusted (0x0000)');
  ComboIntegrity.Items.Add('Low (0x1000)');
  ComboIntegrity.Items.Add('Medium (0x2000)');
  ComboIntegrity.Items.Add('Medium Plus (0x2100)');
  ComboIntegrity.Items.Add('High (0x3000)');
  ComboIntegrity.Items.Add('System (0x4000)');

  with Token.TryGetIntegrity do
    if IsValid then
    begin
      if not Value.Level.IsWellKnown then
      begin
        if Value.Level < ilLow then
          index := 1
        else if Value.Level < ilMedium then
          index := 2
        else if Value.Level < ilMediumPlus then
          index := 3
        else if Value.Level < ilHigh then
          index := 4
        else if Value.Level < ilSystem then
          index := 5
        else
          index := 6;

        ComboIntegrity.Items.Insert(index, Format('Itermediate (0x%.4x)',
          [Cardinal(Value.Level)]));
      end;

      if Value.Level = ilUntrusted then
        ComboIntegrity.ItemIndex := 0
      else if Value.Level <= ilLow then
        ComboIntegrity.ItemIndex := 1
      else if Value.Level <= ilMedium then
        ComboIntegrity.ItemIndex := 2
      else if Value.Level <= ilMediumPlus then
        ComboIntegrity.ItemIndex := 3
      else if Value.Level <= ilHigh then
        ComboIntegrity.ItemIndex := 4
      else if Value.Level <= ilSystem then
        ComboIntegrity.ItemIndex := 5
      else
        ComboIntegrity.ItemIndex := 6;
    end
    else
    begin
      ComboIntegrity.ItemIndex := -1;
      ComboIntegrity.Text := 'Unknown integrity';
    end;

  ComboIntegrity.Items.EndUpdate;
end;

procedure TInfoDialog.ChangedSession(Sender: TObject);
begin
  ComboSession.Items.BeginUpdate;

  with Token.TryGetSession do
    if IsValid then
      ComboSession.SelectedSession := Value
    else
    begin
      ComboSession.ItemIndex := -1;
      ComboSession.Text := 'Unknown session';
    end;

  ComboSession.Items.EndUpdate;
end;

procedure TInfoDialog.ChangedView(Sender: TObject);
var
  i: integer;
begin
  with Token.User do
    if IsValid then
    begin
      if ComboBoxView.ItemIndex = 0 then
        EditUser.Text := Value.ToString
      else
        EditUser.Text := Value.SID;
    end;

  ListViewGroups.Items.BeginUpdate(True);
  ListViewGroups.Clear;
  with Token.Groups do
    if IsValid then
    begin
      TabGroups.Caption := Format('Groups (%d)', [Length(Value)]);

      for i := 0 to High(Value) do
      with Value[i], ListViewGroups.Items.Add do
      begin
        if ComboBoxView.ItemIndex = 0 then
          Caption := SecurityIdentifier.ToString
        else
          Caption := SecurityIdentifier.SID;
        SubItems.Add(Attributes.StateToString);
        SubItems.Add(Attributes.FlagsToString);

        if Attributes.Contain(GroupEnabledByDefault) then
          Color := clEnabledByDefault
        else if Attributes.Contain(GroupEnabled) then
          Color := clEnabled
        else if Attributes.Contain(GroupUforDenyOnly) then
          Color := clUseForDenyOnly
        else if Attributes.Contain(GroupIntegrityEnabled) then
          Color := clIntegrity;
      end;
    end;
  ListViewGroups.Items.EndUpdate(True);

  ListViewRestricted.Items.BeginUpdate(True);
  ListViewRestricted.Clear;
  with Token.RestrictedSids do
    if IsValid then
    begin
      TabRestricted.Caption := Format('Restricted SIDs (%d)', [Length(Value)]);

      for i := 0 to High(Value) do
      with Value[i], ListViewRestricted.Items.Add do
      begin
        if ComboBoxView.ItemIndex = 0 then
          Caption := SecurityIdentifier.ToString
        else
          Caption := SecurityIdentifier.SID;
        SubItems.Add(Attributes.StateToString);
        SubItems.Add(Attributes.FlagsToString);

        if Attributes.Contain(GroupEnabledByDefault) then
          Color := clEnabledByDefault
        else if Attributes.Contain(GroupEnabled) then
          Color := clEnabled
        else if Attributes.Contain(GroupUforDenyOnly) then
          Color := clUseForDenyOnly;
      end;
    end;
  ListViewRestricted.Items.EndUpdate(True);
end;

procedure TInfoDialog.ChangedPrivileges(Sender: TObject);
var
  i: integer;
begin
  ListViewPrivileges.Items.BeginUpdate(True);
  ListViewPrivileges.Clear;
  with Token.Privileges do
    if IsValid then
    begin
      TabPrivileges.Caption := Format('Privileges (%d)', [Length(Value)]);
      Privileges := Value;

      for i := 0 to High(Privileges) do
      with Privileges[i], ListViewPrivileges.Items.Add do
      begin
        Caption := Name;
        SubItems.Add(Privileges[i].AttributesToString);
        SubItems.Add(Privileges[i].Description);
        SubItems.Add(Privileges[i].Luid.ToString);

        if Privileges[i].AttributesContain(SE_PRIVILEGE_ENABLED_BY_DEFAULT) then
          Color := clEnabledByDefault
        else if Privileges[i].AttributesContain(SE_PRIVILEGE_ENABLED) then
          Color := clEnabled
        else if Privileges[i].Attributes = 0 then
          Color := clUseForDenyOnly;
      end;
    end
    else
      SetLength(Privileges, 0);
  ListViewPrivileges.Items.EndUpdate(True);
end;

procedure TInfoDialog.ConfirmTokenClose(Sender: TObject);
const
  CONFIRM_CLOSE = 'This token has an opened information window. Do you want ' +
    'close it?';
begin
  // The main window should not close the token until any information windows
  // are opened for it.
  if MessageDlg(CONFIRM_CLOSE, mtConfirmation, mbYesNoCancel, 0) = IDYES then
    Close
  else
    Abort;
end;

constructor TInfoDialog.CreateFromToken(AOwner: TComponent; SrcToken: TToken);
begin
  Token := SrcToken;
  inherited Create(AOwner);
  Show;
end;

procedure TInfoDialog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Token.OnPrivilegesChange.Delete(ChangedPrivileges);
  Token.OnIntegrityChange.Delete(ChangedIntegrity);
  Token.OnSessionChange.Delete(ChangedSession);
  Token.OnCaptionChange.Delete(ChangedCaption);
  Token.OnClose.Delete(ConfirmTokenClose);
  FormMain.OnMainFormClose.Delete(DoCloseForm);
  Action := caFree;
end;

procedure TInfoDialog.FormCreate(Sender: TObject);
begin
  FormMain.OnMainFormClose.Add(DoCloseForm);
  Token.OnClose.Add(ConfirmTokenClose);
  Token.OnCaptionChange.Add(ChangedCaption);
  Token.OnSessionChange.Add(ChangedSession);
  Token.OnIntegrityChange.Add(ChangedIntegrity);
  Token.OnPrivilegesChange.Add(ChangedPrivileges);

  Refresh;
end;

procedure TInfoDialog.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_F5 then
    Refresh;
end;

function TInfoDialog.GetSelectedPrivileges: TPrivilegeLUIDArray;
var
  i, j: integer;
begin
  SetLength(Result, ListViewPrivileges.SelCount);
  j := 0;
  for i := 0 to ListViewPrivileges.Items.Count - 1 do
    if ListViewPrivileges.Items[i].Selected then
    begin
      Result[j] := Privileges[i].Luid;
      Inc(j);
    end;
end;

procedure TInfoDialog.ListViewPrivilegesContextPopup(Sender: TObject;
  MousePos: TPoint; var Handled: Boolean);
begin
  Handled := ListViewPrivileges.SelCount = 0;
end;

procedure TInfoDialog.Refresh;
begin
  ComboSession.RefreshSessionList;

  ChangedCaption(Token);
  ChangedIntegrity(Token);
  ChangedSession(Token);
  ChangedView(Token);

  EditObjAddr.Text := '0x' + IntToHex(Token.ObjAddress, 8);
  EditHandle.Text := '0x' + IntToHex(Token.Handle, -1);

  with Token.Access do
    if IsValid then
      EditAccess.Text := AccessToDetailedString(Value);

  with Token.TokenTypeInfo do
    if IsValid then
      EditType.Text := Value.ToString;

  with Token.Elevation do
    if IsValid then
      EditElevation.Text := Value.ToString;

  ChangedPrivileges(Token);
end;

procedure TInfoDialog.SetStaleColor(Sender: TObject);
begin
  (Sender as TComboBox).Color := clStale;
end;

end.
