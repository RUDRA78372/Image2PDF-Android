unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants, System.Permissions,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls, System.Sensors,
  FMX.Media,
  FMX.Objects, FMX.MediaLibrary.Actions, System.Actions, FMX.ActnList,
  FMX.Graphics,
  FMX.StdActns, FMX.Controls.Presentation, FMX.Layouts, FMX.ListBox,
  System.IOUtils;

type
  TCameraRollForm = class(TForm)
    btnPhotoLibrary: TButton;
    imgPhotoLibraryImage: TImage;
    alGetCameraRoll: TActionList;
    TakePhotoFromLibraryAction1: TTakePhotoFromLibraryAction;
    ToolBar1: TToolBar;
    Label1: TLabel;
    ListBox1: TListBox;
    Layout1: TLayout;
    Button2: TButton;
    Label2: TLabel;
    Button3: TButton;
    StyleBook1: TStyleBook;
    Button1: TButton;

    procedure TakePhotoFromLibraryAction1DidFinishTaking(Image: TBitmap);
    procedure btnPhotoLibraryClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure ListBox1ItemClick(const Sender: TCustomListBox;
      const Item: TListBoxItem);
  private
    FRawBitmap: TBitmap;
    FPermissionReadExternalStorage: string;
    FPermissionWriteExternalStorage: string;
    procedure managebitmap;
    procedure CreatePDF(Name: string);
    procedure DisplayRationale(Sender: TObject;
      const APermissions: TArray<string>; const APostRationaleProc: TProc);
    procedure LoadPicturePermissionRequestResult(Sender: TObject;
      const APermissions: TArray<string>;
      const AGrantResults: TArray<TPermissionStatus>);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  CameraRollForm: TCameraRollForm;
  Tmpdir: string;
  read: boolean;

implementation

uses
  Androidapi.Helpers,
  Androidapi.JNI.JavaTypes,
  Androidapi.JNI.Os, Androidapi.JNI.GraphicsContentViewText,
  Androidapi.JNI.Net, FMX.Helpers.android,
  FMX.surfaces,
  FMX.DialogService, FMX.DialogService.Async;

{$R *.fmx}

procedure TCameraRollForm.Button1Click(Sender: TObject);
begin
  ListBox1.Items.Clear;
  for var I := 0 to ListBox1.Items.Count - 1 do
TFile.Delete(Includetrailingbackslash(Tmpdir) + ListBox1.Items[I]
        + '.bmp');
        imgphotolibraryimage.Bitmap.Clear($FFFFFF);
end;

function FileNameToUri(const FileName: string): Jnet_Uri;
var
  JavaFile: JFile;
begin
  JavaFile := TJFile.JavaClass.init(StringToJString(FileName));
  Result := TJnet_Uri.JavaClass.fromFile(JavaFile);
end;

procedure TCameraRollForm.CreatePDF(Name: string);
var
  Document: JPdfDocument;
  PageInfo: JPdfDocument_PageInfo;
  Page: JPdfDocument_Page;
  Canvas: JCanvas;
  Paint: JPaint;
  FileName: string;
  OutputStream: JFileOutputStream;
  NativeBitmap: JBitmap;
  sBitMap: TBitmapSurface;
  ABitmap: TBitmap;
begin
  Document := TJPdfDocument.JavaClass.init;
  try
    for var I := 0 to ListBox1.Items.Count - 1 do
    begin
      ABitmap := TBitmap.Create;
      ABitmap.LoadFromFile(Includetrailingbackslash(Tmpdir) + ListBox1.Items[I]
        + '.bmp');
      PageInfo := TJPageInfo_Builder.JavaClass.init(ABitmap.Width,
        ABitmap.Height, Succ(I)).Create;
      Page := Document.startPage(PageInfo);
      Canvas := Page.getCanvas;
      Paint := TJPaint.JavaClass.init;
      NativeBitmap := TJBitmap.JavaClass.createBitmap(ABitmap.Width,
        ABitmap.Height, TJBitmap_Config.JavaClass.ARGB_8888);
      sBitMap := TBitmapSurface.Create;
      sBitMap.Assign(ABitmap);
      SurfaceToJBitmap(sBitMap, NativeBitmap);
      Canvas.drawBitmap(NativeBitmap, 0, 0, Paint);
      Document.finishPage(Page);
      TFile.Delete(Includetrailingbackslash(Tmpdir) + ListBox1.Items[I]
        + '.bmp');
      ABitmap.Free;
    end;
    if extractfileext(Name) = '.pdf' then
      FileName := TPath.Combine(TPath.GetSharedDocumentsPath, Name)
    else
      FileName := TPath.Combine(TPath.GetSharedDocumentsPath, Name + '.pdf');
    OutputStream := TJFileOutputStream.JavaClass.init
      (StringToJString(FileName));
    try
      Document.writeTo(OutputStream);
    finally
      OutputStream.close;
    end;
  finally
    Document.close;
  end;
  ShowMessage('PDF Saved to ' + FileName);
  ListBox1.Clear;
end;

procedure TCameraRollForm.Button2Click(Sender: TObject);
begin
if Listbox1.Items.Count = 0 then
Showmessage('No images available') else
  TDialogServiceAsync.InputQuery('PDF File Name', ['Insert PDF File Name'],
    ['Image2PDF.pdf'],
    procedure(const AResult: TModalResult; const AValues: array of string)
    begin
      if AResult = mrOk then
      begin
        CreatePDF(AValues[0]);
      end;
    end);
end;

procedure TCameraRollForm.Button3Click(Sender: TObject);
begin
  TakePhotoFromLibraryAction1.Execute;
end;

constructor TCameraRollForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRawBitmap := TBitmap.Create(0, 0);
  FPermissionReadExternalStorage :=
    JStringToString(TJManifest_permission.JavaClass.READ_EXTERNAL_STORAGE);
  FPermissionWriteExternalStorage :=
    JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE);
end;

destructor TCameraRollForm.Destroy;
begin
for var I := 0 to ListBox1.Items.Count - 1 do
TFile.Delete(Includetrailingbackslash(Tmpdir) + ListBox1.Items[I]
        + '.bmp');
  FreeAndNil(FRawBitmap);
  inherited Destroy;
end;

procedure TCameraRollForm.btnPhotoLibraryClick(Sender: TObject);
begin
  if read then
  begin
    managebitmap;
   Showmessage('Added to list');
  end;
  read := false;

end;

procedure TCameraRollForm.DisplayRationale(Sender: TObject;
const APermissions: TArray<string>; const APostRationaleProc: TProc);
var
  I: Integer;
  RationaleMsg: string;
begin
  for I := 0 to High(APermissions) do
  begin
    if APermissions[I] = FPermissionReadExternalStorage then
      RationaleMsg := RationaleMsg +
        'The app needs to load photo files from your device';
  end;
  TDialogService.ShowMessage
    ('The app needs to read photo files from your device',
    procedure(const AResult: TModalResult)
    begin
      APostRationaleProc;
    end)
end;

procedure TCameraRollForm.FormCreate(Sender: TObject);
begin
  Tmpdir := TPath.GetTempPath;
  PermissionsService.RequestPermissions([FPermissionReadExternalStorage,
    FPermissionWriteExternalStorage], LoadPicturePermissionRequestResult,
    DisplayRationale);

end;

procedure TCameraRollForm.ListBox1ItemClick(const Sender: TCustomListBox;
  const Item: TListBoxItem);
begin
imgPhotoLibraryImage.Bitmap.loadfromfile(Includetrailingbackslash(Tmpdir) + ListBox1.Items[listbox1.ItemIndex]
        + '.bmp');
end;

procedure TCameraRollForm.LoadPicturePermissionRequestResult(Sender: TObject;
const APermissions: TArray<string>;
const AGrantResults: TArray<TPermissionStatus>);
begin
  if (Length(AGrantResults) <> 2) and
    (AGrantResults[0] <> TPermissionStatus.Granted) and
    (AGrantResults[1] <> TPermissionStatus.Granted) then
    TDialogService.ShowMessage
      ('Cannot do anything because the required permissions are not granted');
end;

procedure TCameraRollForm.managebitmap;
var
  l: string;
  astream: TFilestream;
begin
  l := 'Image' + inttostr(ListBox1.Items.Count + 1);
  ListBox1.Items.Add(l);
  astream := TFilestream.Create(Includetrailingbackslash(Tmpdir) + l + '.bmp',
    fmcreate);
  imgPhotoLibraryImage.Bitmap.savetostream(astream);
  astream.Free;
end;

procedure TCameraRollForm.TakePhotoFromLibraryAction1DidFinishTaking
  (Image: TBitmap);
begin
  read := true;
  imgPhotoLibraryImage.Bitmap.Assign(Image);
end;

end.
