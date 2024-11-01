unit DTFBMigrator;

interface

uses
  System.SysUtils,system.StrUtils,Winapi.ShellAPI, System.Types, Winapi.Windows, System.Classes,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdHTTP, IdSSLOpenSSL, Vcl.ComCtrls,zip;

type
  TIdHTTPProgress = class(TIdHTTP)
  private
    FProgress: Integer;
    FBytesToTransfer: Int64;
    FOnChange: TNotifyEvent;
    IOHndl: TIdSSLIOHandlerSocketOpenSSL;
    procedure HTTPWorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Int64);
    procedure HTTPWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
    procedure HTTPWorkEnd(Sender: TObject; AWorkMode: TWorkMode);
    procedure SetProgress(const Value: Integer);
    procedure SetOnChange(const Value: TNotifyEvent);
  public
    Constructor Create(AOwner: TComponent);
    procedure DownloadFile(const aFileUrl: string; const aDestinationFile: String);
  published
    property Progress: Integer read FProgress write SetProgress;
    property BytesToTransfer: Int64 read FBytesToTransfer;
    property OnChange: TNotifyEvent read FOnChange write SetOnChange;
  end;


type VerFirebirdAtual  = ( vFB21, vFV25, vFB30, vFB40,vFB50 );
type VerFirebirdMigrar = ( vmFB25, vmFB30, vmFB40, vmFB50 );

type
  TStatus = procedure(Msg:string) of object;

type
  TDTFBMigrator = class(TComponent)
  private
    FvFirebirdMigrar: VerFirebirdMigrar;
    FvFirebirdAtual: VerFirebirdAtual;
    FCaminhoDataBase: string;
    FCaminhoArquivosMigracao: string;
    fOnStatus: TStatus;
    FProgressBar: TProgressBar;
    procedure SetvFirebirdAtual(const Value: VerFirebirdAtual);
    procedure SetvFirebirdMigrar(const Value: VerFirebirdMigrar);
    procedure SetCaminhoDataBase(const Value: string);
    procedure SetCaminhoArquivosMigracao(const Value: string);
    function ShellExecuteAndWait(Operation, FileName, Parameter, Directory: String; Show: Word; bWait: Boolean): Longint;
    procedure IdHTTPProgressOnChange(Sender : TObject);
    procedure SetProgressBar(const Value: TProgressBar);
    procedure Descompactar;
  protected

  public
  VersaoFB:VerFirebirdAtual;
  IdHTTPProgress: TIdHTTPProgress;
  procedure Migrar;
  procedure DownloadFiles;

  published
  property OnMigrate               : TStatus           read fOnStatus                write fOnStatus;
  property vFirebirdAtual          : VerFirebirdAtual  read FvFirebirdAtual          write SetvFirebirdAtual;
  property vFirebirdMigrar         : VerFirebirdMigrar read FvFirebirdMigrar         write SetvFirebirdMigrar;
  property CaminhoDataBase         : string            read FCaminhoDataBase         write SetCaminhoDataBase;
  property CaminhoArquivosMigracao : string            read FCaminhoArquivosMigracao write SetCaminhoArquivosMigracao;
  property ProgressBar:TProgressBar read FProgressBar write SetProgressBar;

  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('DT Inovacao', [TDTFBMigrator]);
end;

{ TDTFBMigrator }

procedure TDTFBMigrator.Descompactar;
var
Descomp:TZipFile;
begin
       OnMigrate( timetostr(now) + ' - Descompactando arquivos na pasta: ' + FCaminhoArquivosMigracao );
       Descomp := TZipFile.Create;
       if FileExists( FCaminhoArquivosMigracao + 'migracao.zip' ) then
       begin
            Descomp.Open( FCaminhoArquivosMigracao + 'migracao.zip', zmReadWrite );
            Descomp.ExtractAll( FCaminhoArquivosMigracao );
            Descomp.close;
       end;
       Descomp.free;
       OnMigrate( timetostr(now) + ' - Arquivos descompactados com sucesso' );
end;

procedure TDTFBMigrator.DownloadFiles;
begin
    if FCaminhoArquivosMigracao = '' then
    begin
       raise Exception.Create('É necessário a informação do Caminho dos Arquivos de Migracao');
       abort;
    end;
    OnMigrate( timetostr(now) + ' - Efetuando Download dos Arquivos de migração' );
    IdHTTPProgress          := TIdHTTPProgress.Create(self);
    IdHTTPProgress.OnChange := IdHTTPProgressOnChange;
    IdHTTPProgress.DownloadFile('https://github.com/tiagopassarelladt/DTFBMigrator/raw/refs/heads/master/demo/migracao.zip', FCaminhoArquivosMigracao + 'migracao.zip');
    IdHTTPProgress.free;

    OnMigrate( timetostr(now) + ' - Download efetuado com sucesso' );

    Descompactar;
end;

procedure TDTFBMigrator.IdHTTPProgressOnChange(Sender: TObject);
begin
     FProgressBar.Position := TIdHTTPProgress(Sender).Progress;
end;

procedure TDTFBMigrator.Migrar;
var
   arq                          : TextFile;
   Direct                       : string;
   NomeBase,localBat : string;
   ExitCode                     : DWORD;
   I                            : integer;
   BaseRestaurada               : string;
   BaseAnterior                 : string;
   vNumberVerAtu,vNumberVerMig  : string;
begin
      if FCaminhoArquivosMigracao = '' then
      begin
         raise Exception.Create('É necessário a informação do Caminho dos Arquivos de Migracao');
         abort;
      end;

      if FCaminhoDataBase = '' then
      begin
         raise Exception.Create('É necessário informar o Caminho do DataBase');
         abort;
      end;

      if NOT DirectoryExists( FCaminhoArquivosMigracao ) then
         ForceDirectories( FCaminhoArquivosMigracao );

      case FvFirebirdAtual of
        vFB21:
        begin
        OnMigrate( timetostr(now) + ' - Migração da versão: 2.1' );
        vNumberVerAtu := '21';
        end;
        vFV25:
        begin
        OnMigrate( timetostr(now) + ' - Migração da versão: 2.5' );
        vNumberVerAtu := '25';
        end;
        vFB30:
        begin
        OnMigrate( timetostr(now) + ' - Migração da versão: 3.0' );
        vNumberVerAtu := '30';
        end;
        vFB40:
        begin
        OnMigrate( timetostr(now) + ' - Migração da versão: 4.0' );
        vNumberVerAtu := '40';
        end;
        vFB50:
        begin
        OnMigrate( timetostr(now) + ' - Migração da versão: 5.0' );
        vNumberVerAtu := '50';
        end;
      end;

      case FvFirebirdMigrar of
        vmFB25:
        begin
        OnMigrate( timetostr(now) + ' - Para versão: 2.5' );
        vNumberVerMig := '25';
        end;
        vmFB30:
        begin
        OnMigrate( timetostr(now) + ' - Para versão: 3.0' );
        vNumberVerMig := '30';
        end;
        vmFB40:
        begin
        OnMigrate( timetostr(now) + ' - Para versão: 4.0' );
        vNumberVerMig := '40';
        end;
        vmFB50:
        begin
        OnMigrate( timetostr(now) + ' - Para versão: 5.0' );
        vNumberVerMig := '50';
        end;
      end;

      OnMigrate( timetostr(now) + ' - Iniciando migração' );
      Direct            := ExtractFilePath( FCaminhoDataBase );
      NomeBase          := ExtractFileName( FCaminhoDataBase ) ;
      BaseRestaurada    := NomeBase.Replace('.FDB','') + vNumberVerMig + '.FDB';
      BaseAnterior      := 'OLD_' + NomeBase  ;
      AssignFile(arq, FCaminhoArquivosMigracao + 'Restaura.Bat');
      Rewrite(arq);
      Writeln(arq, 'CD\');
      Writeln(arq, 'CD ' + FCaminhoArquivosMigracao + 'MIGRACAO');
      Writeln(arq, 'SET ISC_USER=SYSDBA');

      Writeln(arq, '"'+ vNumberVerAtu +'\gbak.exe" -z -b -g -v -y ' + vNumberVerAtu +'.log ' + FCaminhoDataBase + ' stdout |^');
      Writeln(arq, '"'+ vNumberVerMig +'\gbak.exe" -z -c -v -st t -y ' + vNumberVerMig + '.log stdin ' + Direct + BaseRestaurada + ' -fix_fss_m WIN1252');
      CloseFile(arq);

      if FileExists(FCaminhoArquivosMigracao + 'Restaura.Bat') then
      begin
           if FileExists(FCaminhoArquivosMigracao + 'MIGRACAO\' + vNumberVerAtu + '.log') then
           begin
                 DeleteFile( pchar( FCaminhoArquivosMigracao + 'MIGRACAO\' + vNumberVerAtu + '.log' ) );
           end;
           if FileExists(FCaminhoArquivosMigracao + 'MIGRACAO\' + vNumberVerMig + '.log') then
           begin
                 DeleteFile( pchar( FCaminhoArquivosMigracao + 'MIGRACAO\' + vNumberVerMig + '.log' ) );
           end;
           if FileExists(BaseRestaurada) then
           begin
                 DeleteFile( pchar( BaseRestaurada ) );
           end;

           I := ShellExecuteAndWait('open', FCaminhoArquivosMigracao + 'Restaura.Bat', '', FCaminhoArquivosMigracao, 0, True);

           if I >= 0 then
           begin
             OnMigrate( timetostr(now) + ' - Migração concluída com sucesso' );
           end else begin
             OnMigrate( timetostr(now) + ' - Migração não concluída' );
           end;
      end;
end;

procedure TDTFBMigrator.SetCaminhoArquivosMigracao(const Value: string);
begin
  FCaminhoArquivosMigracao := Value;
end;

procedure TDTFBMigrator.SetCaminhoDataBase(const Value: string);
begin
  FCaminhoDataBase := Value;
end;

procedure TDTFBMigrator.SetProgressBar(const Value: TProgressBar);
begin
  FProgressBar := Value;
end;

procedure TDTFBMigrator.SetvFirebirdAtual(const Value: VerFirebirdAtual);
begin
  FvFirebirdAtual := Value;
end;

procedure TDTFBMigrator.SetvFirebirdMigrar(const Value: VerFirebirdMigrar);
begin
  FvFirebirdMigrar := Value;
end;

function TDTFBMigrator.ShellExecuteAndWait(Operation, FileName, Parameter,
  Directory: String; Show: Word; bWait: Boolean): Longint;
var
  bOK  : Boolean;
  Info : TShellExecuteInfo;
begin
  FillChar(Info, SizeOf(Info), Chr(0));
  Info.cbSize       := SizeOf(Info);
  Info.fMask        := SEE_MASK_NOCLOSEPROCESS;
  Info.lpVerb       := PChar(Operation);
  Info.lpFile       := PChar(FileName);
  Info.lpParameters := PChar(Parameter);
  Info.lpDirectory  := PChar(Directory);
  Info.nShow        := Show;
  bOK := Boolean(ShellExecuteEx(@Info));
  if bOK then
  begin
    if bWait then
    begin
      while WaitForSingleObject(Info.hProcess, 100) = WAIT_TIMEOUT do
      bOK := GetExitCodeProcess(Info.hProcess, DWORD(Result));
    end else
      Result := 0;
  end;
  if not bOK then
    Result := -1;
end;

constructor TIdHTTPProgress.Create(AOwner: TComponent);
begin
  inherited;
  IOHndl                      := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  Request.BasicAuthentication := True;
  HandleRedirects             := True;
  IOHandler                   := IOHndl;
  ReadTimeout                 := 30000;
  OnWork                      := HTTPWork;
  OnWorkBegin                 := HTTPWorkBegin;
  OnWorkEnd                   := HTTPWorkEnd;
end;

procedure TIdHTTPProgress.DownloadFile(const aFileUrl: string; const aDestinationFile: String);
var
  LDestStream: TFileStream;
  aPath: String;
begin
  Progress := 0;
  FBytesToTransfer := 0;
  aPath := ExtractFilePath(aDestinationFile);
  if aPath <> '' then
    ForceDirectories(aPath);

  LDestStream := TFileStream.Create(aDestinationFile, fmCreate);
  try
    Get(aFileUrl, LDestStream);
  finally
    FreeAndNil(LDestStream);
  end;
end;

procedure TIdHTTPProgress.HTTPWork(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
begin
  if BytesToTransfer = 0 then // No Update File
    Exit;

  Progress := Round((AWorkCount / BytesToTransfer) * 100);
end;

procedure TIdHTTPProgress.HTTPWorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Int64);
begin
  FBytesToTransfer := AWorkCountMax;
end;

procedure TIdHTTPProgress.HTTPWorkEnd(Sender: TObject; AWorkMode: TWorkMode);
begin
  FBytesToTransfer := 0;
  Progress         := 100;
end;

procedure TIdHTTPProgress.SetOnChange(const Value: TNotifyEvent);
begin
  FOnChange := Value;
end;

procedure TIdHTTPProgress.SetProgress(const Value: Integer);
begin
  FProgress := Value;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

end.
