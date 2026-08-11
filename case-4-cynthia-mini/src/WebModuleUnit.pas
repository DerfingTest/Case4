unit WebModuleUnit;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IniFiles,
  Web.HTTPApp, FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Async,
  FireDAC.Stan.Option, FireDAC.Stan.Intf, FireDAC.Phys, FireDAC.Phys.MSSQL,
  FireDAC.Phys.MSSQLDef, FireDAC.DApt;

type
  TWebModule1 = class(TWebModule)
    procedure WebModuleCreate(Sender: TObject);
    procedure WebModuleDestroy(Sender: TObject);
    procedure WebModuleDefaultHandler(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
  private
    FConnection: TFDConnection;
    FRootPath: string;
    procedure ConfigureConnection;
    procedure EnsureConnected;
    procedure JsonResponse(Response: TWebResponse; AJson: TJSONValue;
      AStatus: Integer = 200);
    procedure ErrorResponse(Response: TWebResponse; const AMessage: string;
      AStatus: Integer);
    procedure ServeFile(Response: TWebResponse; const AFileName,
      AContentType: string);
    function ParseBody(Request: TWebRequest): TJSONObject;
    function NewQuery(const ASQL: string): TFDQuery;
    procedure GetDashboard(Response: TWebResponse);
    procedure GetVacancies(Response: TWebResponse);
    procedure CreateVacancy(Request: TWebRequest; Response: TWebResponse);
    procedure GetCandidates(Response: TWebResponse);
    procedure CreateCandidate(Request: TWebRequest; Response: TWebResponse);
    procedure GetApplications(Response: TWebResponse);
    procedure CreateApplication(Request: TWebRequest; Response: TWebResponse);
    procedure UpdateApplicationStage(Request: TWebRequest;
      Response: TWebResponse; AId: Integer);
  end;

var
  WebModuleClass: TComponentClass = TWebModule1;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}
{$R *.dfm}

function JsonString(const S: string): TJSONString;
begin
  Result := TJSONString.Create(S);
end;

procedure TWebModule1.WebModuleCreate(Sender: TObject);
begin
  FRootPath := IncludeTrailingPathDelimiter(ExtractFilePath(GetModuleName(HInstance)));
  FConnection := TFDConnection.Create(nil);
  FConnection.LoginPrompt := False;
  ConfigureConnection;
end;

procedure TWebModule1.WebModuleDestroy(Sender: TObject);
begin
  FConnection.Free;
end;

procedure TWebModule1.ConfigureConnection;
var
  Ini: TIniFile;
  ConfigFile: string;
begin
  ConfigFile := FRootPath + 'config.ini';
  if not FileExists(ConfigFile) then
    raise Exception.Create('Не найден config.ini. Скопируйте config.ini.example и задайте подключение к SQL Server.');

  Ini := TIniFile.Create(ConfigFile);
  try
    FConnection.Params.Clear;
    FConnection.Params.Values['DriverID'] := 'MSSQL';
    FConnection.Params.Values['Server'] := Ini.ReadString('database', 'Server', 'localhost');
    FConnection.Params.Values['Database'] := Ini.ReadString('database', 'Database', 'CynthiaMini');
    if Ini.ReadBool('database', 'OSAuthent', True) then
      FConnection.Params.Values['OSAuthent'] := 'Yes'
    else
    begin
      FConnection.Params.Values['User_Name'] := Ini.ReadString('database', 'UserName', '');
      FConnection.Params.Values['Password'] := Ini.ReadString('database', 'Password', '');
    end;
  finally
    Ini.Free;
  end;
end;

procedure TWebModule1.EnsureConnected;
begin
  if not FConnection.Connected then
    FConnection.Connected := True;
end;

function TWebModule1.NewQuery(const ASQL: string): TFDQuery;
begin
  EnsureConnected;
  Result := TFDQuery.Create(nil);
  Result.Connection := FConnection;
  Result.SQL.Text := ASQL;
end;

procedure TWebModule1.JsonResponse(Response: TWebResponse; AJson: TJSONValue;
  AStatus: Integer);
begin
  try
    Response.StatusCode := AStatus;
    Response.ContentType := 'application/json; charset=utf-8';
    Response.Content := AJson.ToJSON;
  finally
    AJson.Free;
  end;
end;

procedure TWebModule1.ErrorResponse(Response: TWebResponse;
  const AMessage: string; AStatus: Integer);
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  Obj.AddPair('error', AMessage);
  JsonResponse(Response, Obj, AStatus);
end;

procedure TWebModule1.ServeFile(Response: TWebResponse;
  const AFileName, AContentType: string);
var
  FullName: string;
begin
  FullName := FRootPath + 'www\' + AFileName;
  if not FileExists(FullName) then
  begin
    ErrorResponse(Response, 'Файл не найден', 404);
    Exit;
  end;
  Response.ContentType := AContentType;
  Response.ContentStream := TFileStream.Create(FullName, fmOpenRead or fmShareDenyNone);
  Response.FreeContentStream := True;
end;

function TWebModule1.ParseBody(Request: TWebRequest): TJSONObject;
var
  Value: TJSONValue;
begin
  Value := TJSONObject.ParseJSONValue(Request.Content);
  if not (Value is TJSONObject) then
  begin
    Value.Free;
    raise Exception.Create('Ожидается JSON-объект в теле запроса');
  end;
  Result := TJSONObject(Value);
end;

procedure TWebModule1.GetDashboard(Response: TWebResponse);
var
  Q: TFDQuery;
  Obj: TJSONObject;
begin
  Q := NewQuery(
    'SELECT ' +
    '(SELECT COUNT(*) FROM dbo.Vacancies WHERE Status = ''OPEN'') AS OpenVacancies, ' +
    '(SELECT COUNT(*) FROM dbo.Candidates) AS Candidates, ' +
    '(SELECT COUNT(*) FROM dbo.Applications WHERE Stage = ''INTERVIEW'') AS Interviews, ' +
    '(SELECT COUNT(*) FROM dbo.Applications WHERE Stage = ''HIRED'') AS Hired');
  try
    Q.Open;
    Obj := TJSONObject.Create;
    Obj.AddPair('openVacancies', TJSONNumber.Create(Q.FieldByName('OpenVacancies').AsInteger));
    Obj.AddPair('candidates', TJSONNumber.Create(Q.FieldByName('Candidates').AsInteger));
    Obj.AddPair('interviews', TJSONNumber.Create(Q.FieldByName('Interviews').AsInteger));
    Obj.AddPair('hired', TJSONNumber.Create(Q.FieldByName('Hired').AsInteger));
    JsonResponse(Response, Obj);
  finally
    Q.Free;
  end;
end;

procedure TWebModule1.GetVacancies(Response: TWebResponse);
var
  Q: TFDQuery;
  Arr: TJSONArray;
  Obj: TJSONObject;
begin
  Q := NewQuery(
    'SELECT v.Id, v.Title, v.Department, v.Location, v.SalaryFrom, v.SalaryTo, ' +
    'v.Status, v.CreatedAt, COUNT(a.Id) AS CandidateCount ' +
    'FROM dbo.Vacancies v LEFT JOIN dbo.Applications a ON a.VacancyId = v.Id ' +
    'GROUP BY v.Id, v.Title, v.Department, v.Location, v.SalaryFrom, v.SalaryTo, v.Status, v.CreatedAt ' +
    'ORDER BY v.CreatedAt DESC');
  try
    Q.Open;
    Arr := TJSONArray.Create;
    while not Q.Eof do
    begin
      Obj := TJSONObject.Create;
      Obj.AddPair('id', TJSONNumber.Create(Q.FieldByName('Id').AsInteger));
      Obj.AddPair('title', JsonString(Q.FieldByName('Title').AsString));
      Obj.AddPair('department', JsonString(Q.FieldByName('Department').AsString));
      Obj.AddPair('location', JsonString(Q.FieldByName('Location').AsString));
      Obj.AddPair('salaryFrom', TJSONNumber.Create(Q.FieldByName('SalaryFrom').AsInteger));
      Obj.AddPair('salaryTo', TJSONNumber.Create(Q.FieldByName('SalaryTo').AsInteger));
      Obj.AddPair('status', JsonString(Q.FieldByName('Status').AsString));
      Obj.AddPair('candidateCount', TJSONNumber.Create(Q.FieldByName('CandidateCount').AsInteger));
      Arr.AddElement(Obj);
      Q.Next;
    end;
    JsonResponse(Response, Arr);
  finally
    Q.Free;
  end;
end;

procedure TWebModule1.CreateVacancy(Request: TWebRequest; Response: TWebResponse);
var
  Body: TJSONObject;
  Q: TFDQuery;
begin
  Body := ParseBody(Request);
  Q := NewQuery(
    'INSERT INTO dbo.Vacancies (Title, Department, Location, SalaryFrom, SalaryTo, Description, Status, ResponsibleUserId) ' +
    'OUTPUT INSERTED.Id VALUES (:Title, :Department, :Location, :SalaryFrom, :SalaryTo, :Description, ''OPEN'', 1)');
  try
    Q.ParamByName('Title').AsString := Body.GetValue<string>('title');
    Q.ParamByName('Department').AsString := Body.GetValue<string>('department');
    Q.ParamByName('Location').AsString := Body.GetValue<string>('location');
    Q.ParamByName('SalaryFrom').AsInteger := Body.GetValue<Integer>('salaryFrom');
    Q.ParamByName('SalaryTo').AsInteger := Body.GetValue<Integer>('salaryTo');
    Q.ParamByName('Description').AsString := Body.GetValue<string>('description');
    Q.Open;
    JsonResponse(Response, TJSONObject.Create.AddPair('id',
      TJSONNumber.Create(Q.Fields[0].AsInteger)), 201);
  finally
    Q.Free;
    Body.Free;
  end;
end;

procedure TWebModule1.GetCandidates(Response: TWebResponse);
var
  Q: TFDQuery;
  Arr: TJSONArray;
  Obj: TJSONObject;
begin
  Q := NewQuery(
    'SELECT c.Id, c.FirstName, c.LastName, c.Email, c.Phone, c.City, c.Status, c.Rating, ' +
    'v.Title AS VacancyTitle, a.Stage FROM dbo.Candidates c ' +
    'OUTER APPLY (SELECT TOP 1 aa.VacancyId, aa.Stage FROM dbo.Applications aa ' +
    'WHERE aa.CandidateId = c.Id ORDER BY aa.UpdatedAt DESC) a ' +
    'LEFT JOIN dbo.Vacancies v ON v.Id = a.VacancyId ORDER BY c.CreatedAt DESC');
  try
    Q.Open;
    Arr := TJSONArray.Create;
    while not Q.Eof do
    begin
      Obj := TJSONObject.Create;
      Obj.AddPair('id', TJSONNumber.Create(Q.FieldByName('Id').AsInteger));
      Obj.AddPair('name', JsonString(Trim(Q.FieldByName('FirstName').AsString + ' ' + Q.FieldByName('LastName').AsString)));
      Obj.AddPair('email', JsonString(Q.FieldByName('Email').AsString));
      Obj.AddPair('phone', JsonString(Q.FieldByName('Phone').AsString));
      Obj.AddPair('city', JsonString(Q.FieldByName('City').AsString));
      Obj.AddPair('status', JsonString(Q.FieldByName('Status').AsString));
      Obj.AddPair('rating', TJSONNumber.Create(Q.FieldByName('Rating').AsFloat));
      Obj.AddPair('vacancyTitle', JsonString(Q.FieldByName('VacancyTitle').AsString));
      Obj.AddPair('stage', JsonString(Q.FieldByName('Stage').AsString));
      Arr.AddElement(Obj);
      Q.Next;
    end;
    JsonResponse(Response, Arr);
  finally
    Q.Free;
  end;
end;

procedure TWebModule1.CreateCandidate(Request: TWebRequest; Response: TWebResponse);
var
  Body: TJSONObject;
  Q: TFDQuery;
begin
  Body := ParseBody(Request);
  Q := NewQuery(
    'INSERT INTO dbo.Candidates (FirstName, LastName, Email, Phone, City, Status, Rating) ' +
    'OUTPUT INSERTED.Id VALUES (:FirstName, :LastName, :Email, :Phone, :City, ''NEW'', 0)');
  try
    Q.ParamByName('FirstName').AsString := Body.GetValue<string>('firstName');
    Q.ParamByName('LastName').AsString := Body.GetValue<string>('lastName');
    Q.ParamByName('Email').AsString := Body.GetValue<string>('email');
    Q.ParamByName('Phone').AsString := Body.GetValue<string>('phone');
    Q.ParamByName('City').AsString := Body.GetValue<string>('city');
    Q.Open;
    JsonResponse(Response, TJSONObject.Create.AddPair('id',
      TJSONNumber.Create(Q.Fields[0].AsInteger)), 201);
  finally
    Q.Free;
    Body.Free;
  end;
end;

procedure TWebModule1.GetApplications(Response: TWebResponse);
var
  Q: TFDQuery;
  Arr: TJSONArray;
  Obj: TJSONObject;
begin
  Q := NewQuery(
    'SELECT a.Id, a.Stage, a.MatchPercent, a.Notes, a.UpdatedAt, ' +
    'c.FirstName, c.LastName, v.Title AS VacancyTitle ' +
    'FROM dbo.Applications a JOIN dbo.Candidates c ON c.Id = a.CandidateId ' +
    'JOIN dbo.Vacancies v ON v.Id = a.VacancyId ORDER BY a.UpdatedAt DESC');
  try
    Q.Open;
    Arr := TJSONArray.Create;
    while not Q.Eof do
    begin
      Obj := TJSONObject.Create;
      Obj.AddPair('id', TJSONNumber.Create(Q.FieldByName('Id').AsInteger));
      Obj.AddPair('stage', JsonString(Q.FieldByName('Stage').AsString));
      Obj.AddPair('matchPercent', TJSONNumber.Create(Q.FieldByName('MatchPercent').AsInteger));
      Obj.AddPair('notes', JsonString(Q.FieldByName('Notes').AsString));
      Obj.AddPair('candidate', JsonString(Trim(Q.FieldByName('FirstName').AsString + ' ' + Q.FieldByName('LastName').AsString)));
      Obj.AddPair('vacancy', JsonString(Q.FieldByName('VacancyTitle').AsString));
      Arr.AddElement(Obj);
      Q.Next;
    end;
    JsonResponse(Response, Arr);
  finally
    Q.Free;
  end;
end;

procedure TWebModule1.CreateApplication(Request: TWebRequest; Response: TWebResponse);
var
  Body: TJSONObject;
  Q: TFDQuery;
begin
  Body := ParseBody(Request);
  Q := NewQuery(
    'INSERT INTO dbo.Applications (CandidateId, VacancyId, Stage, MatchPercent, Notes) ' +
    'OUTPUT INSERTED.Id VALUES (:CandidateId, :VacancyId, ''NEW'', :MatchPercent, :Notes)');
  try
    Q.ParamByName('CandidateId').AsInteger := Body.GetValue<Integer>('candidateId');
    Q.ParamByName('VacancyId').AsInteger := Body.GetValue<Integer>('vacancyId');
    Q.ParamByName('MatchPercent').AsInteger := Body.GetValue<Integer>('matchPercent');
    Q.ParamByName('Notes').AsString := Body.GetValue<string>('notes');
    Q.Open;
    JsonResponse(Response, TJSONObject.Create.AddPair('id',
      TJSONNumber.Create(Q.Fields[0].AsInteger)), 201);
  finally
    Q.Free;
    Body.Free;
  end;
end;

procedure TWebModule1.UpdateApplicationStage(Request: TWebRequest;
  Response: TWebResponse; AId: Integer);
var
  Body: TJSONObject;
  Q: TFDQuery;
  Stage: string;
begin
  Body := ParseBody(Request);
  Q := NewQuery(
    'UPDATE dbo.Applications SET Stage = :Stage, UpdatedAt = SYSUTCDATETIME() WHERE Id = :Id; ' +
    'INSERT INTO dbo.StatusHistory (EntityType, EntityId, OldStatus, NewStatus, ChangedByUserId) ' +
    'VALUES (''APPLICATION'', :Id, NULL, :Stage, 1)');
  try
    Stage := UpperCase(Body.GetValue<string>('stage'));
    if (Stage <> 'NEW') and (Stage <> 'SCREENING') and (Stage <> 'INTERVIEW') and
       (Stage <> 'OFFER') and (Stage <> 'HIRED') and (Stage <> 'REJECTED') then
      raise Exception.Create('Недопустимый этап подбора');
    Q.ParamByName('Stage').AsString := Stage;
    Q.ParamByName('Id').AsInteger := AId;
    Q.ExecSQL;
    JsonResponse(Response, TJSONObject.Create.AddPair('updated', TJSONBool.Create(True)));
  finally
    Q.Free;
    Body.Free;
  end;
end;

procedure TWebModule1.WebModuleDefaultHandler(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  Path, Tail: string;
  Id: Integer;
begin
  Handled := True;
  Path := LowerCase(Request.PathInfo);
  try
    if (Path = '') or (Path = '/') then
      ServeFile(Response, 'index.html', 'text/html; charset=utf-8')
    else if Path = '/styles.css' then
      ServeFile(Response, 'styles.css', 'text/css; charset=utf-8')
    else if Path = '/app.js' then
      ServeFile(Response, 'app.js', 'application/javascript; charset=utf-8')
    else if (Path = '/api/dashboard') and (Request.MethodType = mtGet) then
      GetDashboard(Response)
    else if (Path = '/api/vacancies') and (Request.MethodType = mtGet) then
      GetVacancies(Response)
    else if (Path = '/api/vacancies') and (Request.MethodType = mtPost) then
      CreateVacancy(Request, Response)
    else if (Path = '/api/candidates') and (Request.MethodType = mtGet) then
      GetCandidates(Response)
    else if (Path = '/api/candidates') and (Request.MethodType = mtPost) then
      CreateCandidate(Request, Response)
    else if (Path = '/api/applications') and (Request.MethodType = mtGet) then
      GetApplications(Response)
    else if (Path = '/api/applications') and (Request.MethodType = mtPost) then
      CreateApplication(Request, Response)
    else if (Pos('/api/applications/', Path) = 1) and
      (Pos('/stage', Path) > 0) and (Request.MethodType = mtPut) then
    begin
      Tail := Copy(Path, Length('/api/applications/') + 1, MaxInt);
      Tail := Copy(Tail, 1, Pos('/stage', Tail) - 1);
      if not TryStrToInt(Tail, Id) then
        raise Exception.Create('Некорректный идентификатор отклика');
      UpdateApplicationStage(Request, Response, Id);
    end
    else
      ErrorResponse(Response, 'Маршрут не найден', 404);
  except
    on E: EFDDBEngineException do
      ErrorResponse(Response, 'Ошибка базы данных: ' + E.Message, 500);
    on E: Exception do
      ErrorResponse(Response, E.Message, 400);
  end;
end;

end.
