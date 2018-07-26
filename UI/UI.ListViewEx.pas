unit UI.ListViewEx;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.ComCtrls, Vcl.Graphics,
  System.UITypes, System.Generics.Collections;

// TODO: Implement copying of selected items to clipboard

type
  TListItemEx = class;
  TListItemsEx = class;

  TListItemHolder = class
  private
    FOwner: TListItemsEx;
    FListItem: TListItemEx;
    FCaption: String;
    FChecked: Boolean;
    FData: TCustomData;
    FGroupID: Integer;
    FImageIndex: TImageIndex;
    FIndent: Integer;
    FOwnedData: TObject;
    FSubItems: TStringList;
    FColor: TColor;
    FColorEnabled: Boolean;
    FVisible: Boolean;
    procedure SetVisible(const Value: Boolean);
    function GetCaption: String;
    procedure SetCaption(const Value: String);
    function GetSubItems: TStrings;
    function GetChecked: Boolean;
    function GetColor: TColor;
    function GetColorEnabled: Boolean;
    function GetData: TCustomData;
    function GetImageIndex: TImageIndex;
    function GetIndent: Integer;
    procedure SetChecked(const Value: Boolean);
    procedure SetColor(const Value: TColor);
    procedure SetColorEnabled(const Value: Boolean);
    procedure SetData(const Value: TCustomData);
    procedure SetImageIndex(const Value: TImageIndex);
    procedure SetIndent(const Value: Integer);
    function GetGroupID: Integer;
    procedure SetGroupID(const Value: Integer);
    procedure SetOwnedData(const Value: TObject);
  protected
    procedure AssignDataToItem(Item: TListItemEx);
    procedure RefreshItemInformation;
    procedure ItemRequestedInvisibility;
    function Matches(SearchPattern: String; Column: Integer = -1): Boolean;
  public
    constructor Create(Item: TListItemEx);
    destructor Destroy; override;
    property Visible: Boolean read FVisible write SetVisible;
    property ListItemEx: TListItemEx read FListItem;
    property Caption: String read GetCaption write SetCaption;
    property Checked: Boolean read GetChecked write SetChecked;
    property Color: TColor read GetColor write SetColor;
    property ColorEnabled: Boolean read GetColorEnabled write SetColorEnabled;
    property Data: TCustomData read GetData write SetData;
    property GroupID: Integer read GetGroupID write SetGroupID;
    property ImageIndex: TImageIndex read GetImageIndex write SetImageIndex;
    property Indent: Integer read GetIndent write SetIndent;
    /// <summary> An object that is linked to the item and will be freed on it's
    ///  deletion (by <c>TListItemHolder</c>). </summary>
    property OwnedData: TObject read FOwnedData write SetOwnedData;
    property SubItems: TStrings read GetSubItems;
  end;

  TListItemEx = class(TListItem)
  private
    FColor: TColor;
    FColorEnabled: Boolean;
    FOwnedData: TObject;
    procedure SetColor(const Value: TColor);
    function GetOwnerItems: TListItemsEx;
    function GetGlobalIndex: Integer;
    procedure InheritedDelete;
    procedure SetOwnedData(const Value: TObject);
  public
    constructor Create(AOwner: TListItems); override;
    property Color: TColor read FColor write SetColor;
    property ColorEnabled: Boolean read FColorEnabled write FColorEnabled;
    property OwnedData: TObject read FOwnedData write SetOwnedData;
    property Owner: TListItemsEx read GetOwnerItems;
    property GlobalIndex: Integer read GetGlobalIndex;
    procedure Delete(OnlyMakeInvisible: Boolean = False);
  end;

  TListViewEx = class;
  TListItemsEx = class(TListItems)
  private
    FSelectionSnapshot: array of Boolean;
    FAllItems: TList<TListItemHolder>;
    function GetOwnerListView: TListViewEx;
    function GetAllItem(GlobalIndex: Integer): TListItemHolder;
    function GetAllItemsCount: Integer;
  protected
    function GetItem(Index: Integer): TListItemEx;
    procedure SetItem(Index: Integer; Value: TListItemEx);
    procedure CreateSelectionSnapshot;
    function ApplySelectionSnapshot: Boolean;
    function InheritedAddItem(Item: TListItemEx; Index: Integer = -1): TListItemEx;
  public
    constructor Create(AOwner: TCustomListView);
    destructor Destroy; override;
    function Add: TListItemEx;
    function AddItem(Item: TListItemEx; Index: Integer = -1): TListItemEx;
    function Insert(Index: Integer): TListItemEx;
    procedure Clear;
    property Item[Index: Integer]: TListItemEx read GetItem write SetItem; default;
    property Owner: TListViewEx read GetOwnerListView;
    procedure BeginUpdate(MakeSelectionSnapshot: Boolean = False);
    procedure EndUpdate(ApplySnapshot: Boolean = False);
    property AllItems[GlobalIndex: Integer]: TListItemHolder read GetAllItem;
    property AllItemsCount: Integer read GetAllItemsCount;
  end;

  TListViewEx = class(TListView)
  private
    FColoringItems: Boolean;
    function GetItems: TListItemsEx;
    procedure SetItems(const Value: TListItemsEx);
    procedure SetItemsColoring(const Value: Boolean);
    function GetSelected: TListItemEx;
    procedure SetSelected(const Value: TListItemEx);
  protected
    function CreateListItem: TListItem; override;
    function CreateListItems: TListItems; override;
    function CustomDrawItem(Item: TListItem; State: TCustomDrawState;
      Stage: TCustomDrawStage): Boolean; override;
    function IsCustomDrawn(Target: TCustomDrawTarget; Stage: TCustomDrawStage):
      Boolean; override;
  public
    property Items: TListItemsEx read GetItems write SetItems;
    procedure Clear; override;
    procedure Filter(SearchPattern: String; Column: Integer = -1);
    property Selected: TListItemEx read GetSelected write SetSelected;
  published
    property ColoringItems: Boolean read FColoringItems write SetItemsColoring default False;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Token Universe', [TListViewEx]);
end;

{ TListViewEx }

procedure TListViewEx.Clear;
begin
  // HACK: Clear doesn't deselect items before deleting them
  // so we don't get OnSelectItem event.
  ClearSelection;
  inherited;
end;

function TListViewEx.CreateListItem: TListItem;
var
  LClass: TListItemClass;
begin
  LClass := TListItemEx;
  if Assigned(OnCreateItemClass) then
    OnCreateItemClass(Self, LClass);
  Result := LClass.Create(Items);
end;

function TListViewEx.CreateListItems: TListItems;
begin
  Result := TListItemsEx.Create(Self);
end;

function TListViewEx.CustomDrawItem(Item: TListItem; State: TCustomDrawState;
  Stage: TCustomDrawStage): Boolean;
begin
  if FColoringItems then
  begin
    if (Item as TListItemEx).FColorEnabled then
      Canvas.Brush.Color := (Item as TListItemEx).FColor
    else
      Canvas.Brush.Color := Color;
  end;
  Result := inherited;
end;

procedure TListViewEx.Filter(SearchPattern: String; Column: Integer = -1);
var
  g: Integer;
  GroupMatch: array of Boolean;
begin
  SearchPattern := SearchPattern.ToLower;

  if GroupView and (Column = -1) then
  begin
    SetLength(GroupMatch, Groups.Count);
    for g := 0 to High(GroupMatch) do
      GroupMatch[g] := Groups[g].Header.ToLower.Contains(SearchPattern);
  end;

  Items.BeginUpdate;
  for g := 0 to Items.FAllItems.Count - 1 do
  with Items.FAllItems[g] do
  begin
    if GroupView and (Column = -1) and (GroupID <> -1) and GroupMatch[GroupID] then
      SetVisible(True)
    else
      SetVisible(Matches(SearchPattern, Column));
  end;
  Items.EndUpdate;
end;

function TListViewEx.GetItems: TListItemsEx;
begin
  Result := inherited Items as TListItemsEx;
end;

function TListViewEx.GetSelected: TListItemEx;
begin
  Result := inherited Selected as TListItemEx;
end;

function TListViewEx.IsCustomDrawn(Target: TCustomDrawTarget;
  Stage: TCustomDrawStage): Boolean;
begin
  if Target = dtItem then
    Result := FColoringItems or inherited
  else
    Result := inherited;
end;

procedure TListViewEx.SetItems(const Value: TListItemsEx);
begin
  inherited Items := Value;
end;

procedure TListViewEx.SetItemsColoring(const Value: Boolean);
begin
  FColoringItems := Value;
  if FColoringItems then
    Repaint;
end;

procedure TListViewEx.SetSelected(const Value: TListItemEx);
begin
  inherited Selected := Value;
end;

{ TListItemsEx }

function TListItemsEx.Add: TListItemEx;
begin
  Result := AddItem(nil, -1);
end;

function TListItemsEx.AddItem(Item: TListItemEx; Index: Integer): TListItemEx;
var
  PreviousGloablIndex: Integer;
  FixCaption: String;
begin
  PreviousGloablIndex := -1;
  if Index <> -1 then
    PreviousGloablIndex := Self[Index].GlobalIndex;

  Result := InheritedAddItem(Item, Index);

  if Index <> -1 then
    FAllItems.Insert(PreviousGloablIndex, TListItemHolder.Create(Result))
  else
    FAllItems.Add(TListItemHolder.Create(Result));

  // HACK: For some reason it draws empty caption until it wouldn't be updated
  if Item <> nil then
  begin
    FixCaption := Result.Caption;
    Result.Caption := '';
    Result.Caption := FixCaption;
  end;
end;

function TListItemsEx.ApplySelectionSnapshot: Boolean;
var
  i: Integer;
begin
  Result := Length(FSelectionSnapshot) = Count;
  if not Result then
    Exit;

  BeginUpdate;
  for i := 0 to High(FSelectionSnapshot) do
    Item[i].Selected := FSelectionSnapshot[i];
  EndUpdate;
end;

procedure TListItemsEx.BeginUpdate(MakeSelectionSnapshot: Boolean);
begin
  if MakeSelectionSnapshot then
    CreateSelectionSnapshot;
  (Self as TListItems).BeginUpdate;
end;

procedure TListItemsEx.Clear;
var
  i: integer;
begin
  for i := 0 to FAllItems.Count - 1 do
    FAllItems[i].Free;

  FAllItems.Clear;
  inherited;
end;

constructor TListItemsEx.Create(AOwner: TCustomListView);
begin
  inherited;
  FAllItems := TList<TListItemHolder>.Create;
end;

procedure TListItemsEx.CreateSelectionSnapshot;
var
  i: integer;
begin
  SetLength(FSelectionSnapshot, Count);
  for i := 0 to High(FSelectionSnapshot) do
    FSelectionSnapshot[i] := Item[i].Selected;
end;

destructor TListItemsEx.Destroy;
var
  i: integer;
begin
  for i := 0 to FAllItems.Count - 1 do
    FAllItems[i].Free;

  FAllItems.Free;
  inherited;
end;

procedure TListItemsEx.EndUpdate(ApplySnapshot: Boolean);
begin
  if ApplySnapshot then
  begin
    ApplySelectionSnapshot;
    SetLength(FSelectionSnapshot, 0);
  end;
  (Self as TListItems).EndUpdate;
end;

function TListItemsEx.GetAllItem(GlobalIndex: Integer): TListItemHolder;
begin
  Result := FAllItems[GlobalIndex];
end;

function TListItemsEx.GetAllItemsCount: Integer;
begin
  Result := FAllItems.Count;
end;

function TListItemsEx.GetItem(Index: Integer): TListItemEx;
begin
  Result := inherited GetItem(Index) as TListItemEx;
end;

function TListItemsEx.GetOwnerListView: TListViewEx;
begin
  Result := inherited Owner as TListViewEx;
end;

function TListItemsEx.InheritedAddItem(Item: TListItemEx;
  Index: Integer): TListItemEx;
begin
  Result := (Self as TListItems).AddItem(Item, Index) as TListItemEx;
end;

function TListItemsEx.Insert(Index: Integer): TListItemEx;
begin
  Result := AddItem(nil, Index);
end;

procedure TListItemsEx.SetItem(Index: Integer; Value: TListItemEx);
begin
  inherited SetItem(Index, Value);
end;

{ TListItemEx }

constructor TListItemEx.Create(AOwner: TListItems);
begin
  inherited;
  FColor := clWindow;
end;

procedure TListItemEx.Delete(OnlyMakeInvisible: Boolean = False);
var
  Ind: Integer;
begin
  Ind := Self.GlobalIndex;

  if OnlyMakeInvisible then
    Owner.FAllItems[Ind].ItemRequestedInvisibility
  else
  begin
    Owner.FAllItems[Ind].Free;
    Owner.FAllItems.Delete(Ind);
  end;

  InheritedDelete;
end;

function TListItemEx.GetGlobalIndex: Integer;
begin
  with GetOwnerItems do
    for Result := 0 to FAllItems.Count - 1 do
      if FAllItems[Result].FListItem = Self then
        Exit;

  Result := -1;
end;

function TListItemEx.GetOwnerItems: TListItemsEx;
begin
  Result := inherited Owner as TListItemsEx;
end;

procedure TListItemEx.InheritedDelete;
begin
  (Self as TListItem).Delete;
end;

procedure TListItemEx.SetColor(const Value: TColor);
begin
  FColorEnabled := True;
  FColor := Value;
  if Owner.Owner.ColoringItems then
    Owner.Owner.Repaint;
end;

procedure TListItemEx.SetOwnedData(const Value: TObject);
begin
  FOwnedData := Value;
  Owner.FAllItems[Self.GlobalIndex].FOwnedData := Value;
end;

{ TListItemHolder }

procedure TListItemHolder.AssignDataToItem(Item: TListItemEx);
begin
  Item.Caption := FCaption;
  Item.Checked := FChecked;
  Item.Data := FData;
  Item.GroupID := FGroupID;
  Item.ImageIndex := FImageIndex;
  Item.Indent := FIndent;
  Item.FOwnedData := FOwnedData;
  Item.SubItems.Assign(FSubItems);
  Item.Color := FColor;
  Item.ColorEnabled := FColorEnabled;
end;

constructor TListItemHolder.Create(Item: TListItemEx);
begin
  FSubItems := TStringList.Create;
  FOwner := Item.Owner;
  FListItem := Item;
  FVisible := True;
  RefreshItemInformation;
end;

destructor TListItemHolder.Destroy;
begin
  FSubItems.Free;
  FOwnedData.Free;
  inherited;
end;

function TListItemHolder.GetCaption: String;
begin
  if Assigned(FListItem) then
    Result := FListItem.Caption
  else
    Result := FCaption;
end;

function TListItemHolder.GetChecked: Boolean;
begin
  if Assigned(FListItem) then
    Result := FListItem.Checked
  else
    Result := FChecked;
end;

function TListItemHolder.GetColor: TColor;
begin
  if Assigned(FListItem) then
    Result := FListItem.Color
  else
    Result := FColor;
end;

function TListItemHolder.GetColorEnabled: Boolean;
begin
  if Assigned(FListItem) then
    Result := FListItem.ColorEnabled
  else
    Result := FColorEnabled;
end;

function TListItemHolder.GetData: TCustomData;
begin
  if Assigned(FListItem) then
    Result := FListItem.Data
  else
    Result := FData;
end;

function TListItemHolder.GetGroupID: Integer;
begin
  if Assigned(FListItem) then
    Result := FListItem.GroupID
  else
    Result := FGroupID;
end;

function TListItemHolder.GetImageIndex: TImageIndex;
begin
  if Assigned(FListItem) then
    Result := FListItem.ImageIndex
  else
    Result := FImageIndex;
end;

function TListItemHolder.GetIndent: Integer;
begin
  if Assigned(FListItem) then
    Result := FListItem.Indent
  else
    Result := FIndent;
end;

function TListItemHolder.GetSubItems: TStrings;
begin
  if Assigned(FListItem) then
    Result := FListItem.SubItems
  else
    Result := FSubItems;
end;

procedure TListItemHolder.ItemRequestedInvisibility;
begin
  RefreshItemInformation;
  FVisible := False;
  FListItem := nil;
end;

function TListItemHolder.Matches(SearchPattern: String;
  Column: Integer): Boolean;
var
  sub: Integer;
begin
  if SearchPattern = '' then
    Exit(True);

  if Column = -1 then
  begin
    if LowerCase(Self.Caption).Contains(SearchPattern) then
      Exit(True);

    for sub := 0 to Self.SubItems.Count - 1 do
      if LowerCase(Self.SubItems[sub]).Contains(SearchPattern) then
        Exit(True);

    Result := False;
  end
  else if Column = 0 then
    Result := LowerCase(Self.Caption).Contains(SearchPattern)
  else if Self.SubItems.Count >= Column then
    Result := LowerCase(Self.SubItems[Column - 1]).Contains(SearchPattern)
  else
    Result := False;
end;

procedure TListItemHolder.RefreshItemInformation;
begin
  FCaption := FListItem.Caption;
  FChecked := FListItem.Checked;
  FData := FListItem.Data;
  FGroupID := FListItem.GroupID;
  FImageIndex := FListItem.ImageIndex;
  FIndent := FListItem.Indent;
  FOwnedData := FListItem.OwnedData;
  FSubItems.Assign(FListItem.SubItems);
  FColor := FListItem.Color;
  FColorEnabled := FListItem.ColorEnabled;
end;

procedure TListItemHolder.SetCaption(const Value: String);
begin
  if Assigned(FListItem) then
    FListItem.Caption := Value
  else
    FCaption := Value;
end;

procedure TListItemHolder.SetChecked(const Value: Boolean);
begin
  if Assigned(FListItem) then
    FListItem.Checked := Value
  else
    FChecked := Value;
end;

procedure TListItemHolder.SetColor(const Value: TColor);
begin
  if Assigned(FListItem) then
    FListItem.Color := Value
  else
    FColor := Value;
end;

procedure TListItemHolder.SetColorEnabled(const Value: Boolean);
begin
  if Assigned(FListItem) then
    FListItem.ColorEnabled := Value
  else
    FColorEnabled := Value;
end;

procedure TListItemHolder.SetData(const Value: TCustomData);
begin
  if Assigned(FListItem) then
    FListItem.Data := Value
  else
    FData := Value;
end;

procedure TListItemHolder.SetGroupID(const Value: Integer);
begin
  if Assigned(FListItem) then
    FListItem.GroupID := Value
  else
    FGroupID := Value;
end;

procedure TListItemHolder.SetImageIndex(const Value: TImageIndex);
begin
  if Assigned(FListItem) then
    FListItem.ImageIndex := Value
  else
    FImageIndex := Value;
end;

procedure TListItemHolder.SetIndent(const Value: Integer);
begin
  if Assigned(FListItem) then
    FListItem.Indent := Value
  else
    FIndent := Value;
end;

procedure TListItemHolder.SetOwnedData(const Value: TObject);
begin
  FOwnedData := Value;
  if Assigned(FListItem) then
    FListItem.FOwnedData := Value;
end;

procedure TListItemHolder.SetVisible(const Value: Boolean);
var
  g: integer;
begin
  if FVisible = Value then
    Exit;

  FVisible := Value;
  if FVisible then
  begin
    g := FOwner.FAllItems.Count;
    for g := FOwner.FAllItems.IndexOf(Self) + 1 to FOwner.FAllItems.Count - 1 do
      if FOwner.FAllItems[g].FVisible then
        Break;

    // We can't use TListViewEx's AddItem since it creates TListItemHolders
    if g = FOwner.FAllItems.Count then // not found, add to the end
      FListItem := FOwner.InheritedAddItem(nil, -1)
    else
      FListItem := FOwner.InheritedAddItem(nil,
        FOwner.FAllItems[g].FListItem.Index);

    AssignDataToItem(FListItem);
  end;
  if not FVisible then
    FListItem.Delete(True);
end;

end.
